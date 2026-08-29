#!/usr/bin/env python3
"""
S3 Regex Matcher

This script searches for a regular expression in files stored in an S3 bucket.
It filters files by an S3 prefix and a filename fnmatch glob pattern.
If a match is found in the file content, it prints the S3 path.

Features:
- Searches S3 files matching a glob pattern
- Applies regular expression matching to file contents
- Handles compressed files automatically (via smart_open)
- Integrated logging with impresso_cookbook standards
- Supports S3 log file output
- Optional JSON output for AWS batch deletion
- Optional filename derivation by removing custom suffix (e.g., .log.gz)

Integration with impresso_cookbook:
- Uses get_s3_client() for S3 operations
- Uses setup_logging() for standardized logging configuration
- Uses yield_s3_objects() for efficient S3 file listing
- Uses get_transport_params() for automatic S3/local file handling

Usage:
    python3 s3_regex_matcher.py --s3-prefix s3://bucket/prefix \\
        --glob "*.jsonl.bz2" --regex "pattern"

Example:
    # Basic search - print matching S3 paths
    python3 s3_regex_matcher.py \\
        --s3-prefix s3://impresso/canonical/ \\
        --glob "*/*.jsonl.bz2" \\
        --regex "GDL-.*-18[0-9]{2}" \\
        --log-level DEBUG \\
        --log-file s3://impresso/logs/regex_search.log

    # Generate AWS deletion JSON (automatically batched into 1000-key chunks)
    python3 s3_regex_matcher.py \\
        --s3-prefix s3://impresso/logs/ \\
        --glob "*.jsonl.bz2.log.gz" \\
        --regex "error|failed" \\
        --output-json delete.json \\
        --derive-stem .log.gz

    # Then delete with AWS CLI using generated shell script:
    bash delete_commands.sh
    
    # Or manually execute each batch:
    aws s3api delete-objects --bucket impresso --delete file://delete_00.json
    aws s3api delete-objects --bucket impresso --delete file://delete_01.json
"""

import argparse
import fnmatch
import json
import logging
import re
import sys
from typing import List, Optional, Sequence
from dotenv import load_dotenv

from impresso_cookbook import (  # type: ignore
    get_s3_client,
    get_timestamp,
    setup_logging,
    get_transport_params,
    yield_s3_objects,
    s3_file_exists,
)
from smart_open import open as smart_open  # type: ignore

log = logging.getLogger(__name__)

# Needed to load environment variables for S3 credentials
load_dotenv()


def parse_arguments(args: Optional[List[str]] = None) -> argparse.Namespace:
    """
    Parse command-line arguments.

    Args:
        args: Command-line arguments (uses sys.argv if None)

    Returns:
        argparse.Namespace: Parsed arguments
    """
    parser = argparse.ArgumentParser(
        description="Search for regex patterns in S3 files."
    )
    parser.add_argument(
        "--log-file", dest="log_file", help="Write log to FILE", metavar="FILE"
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: %(default)s)",
    )
    parser.add_argument(
        "--s3-prefix",
        required=True,
        help="S3 prefix (e.g., s3://bucket/prefix)",
    )
    parser.add_argument(
        "--glob",
        required=True,
        help="Filename glob pattern (e.g., *.jsonl.bz2)",
    )
    parser.add_argument(
        "--regex",
        required=True,
        help="Regular expression to search for",
    )
    parser.add_argument(
        "--output-json",
        dest="output_json",
        help="Output JSON file for AWS batch deletion (optional)",
        metavar="FILE",
    )
    parser.add_argument(
        "--derive-stem",
        dest="derive_stem",
        type=str,
        default=None,
        help="Derive base filename by removing suffix (e.g., .log.gz)",
    )
    parser.add_argument(
        "--match-on-error",
        dest="match_on_error",
        action="store_true",
        help="Treat corrupted/unreadable files as matches (for deletion)",
    )
    return parser.parse_args(args)


class RegexMatcher:
    """
    A processor class that searches for regex patterns in S3 files.
    """

    def __init__(
        self,
        s3_prefix: str,
        file_glob: str,
        regex_pattern: str,
        log_level: str = "INFO",
        log_file: Optional[str] = None,
        output_json: Optional[str] = None,
        derive_stem: Optional[str] = None,
        match_on_error: bool = False,
    ) -> None:
        """
        Initializes the RegexMatcher with explicit parameters.

        Args:
            s3_prefix (str): S3 prefix to search (e.g., s3://bucket/prefix)
            file_glob (str): Filename glob pattern for filtering
            regex_pattern (str): Regular expression to search for
            log_level (str): Logging level (default: "INFO")
            log_file (Optional[str]): Path to log file (default: None)
            output_json (Optional[str]): Path to output JSON file for AWS
                batch deletion (default: None)
            derive_stem (Optional[str]): Suffix to remove from filenames to
                derive base files (e.g., ".log.gz") (default: None)
            match_on_error (bool): Treat corrupted/unreadable files as matches
                (default: False)
        """
        self.s3_prefix = s3_prefix
        self.file_glob = file_glob
        self.regex_pattern = regex_pattern
        self.log_level = log_level
        self.log_file = log_file
        self.output_json = output_json
        self.derive_stem = derive_stem
        self.match_on_error = match_on_error

        # Configure the module-specific logger
        setup_logging(self.log_level, self.log_file, logger=log)

        # Initialize S3 client and timestamp
        self.s3_client = get_s3_client()
        self.timestamp = get_timestamp()

        # Parse S3 path
        if not self.s3_prefix.startswith("s3://"):
            log.error("S3 prefix must start with s3://")
            sys.exit(1)

        parts = self.s3_prefix.replace("s3://", "").split("/", 1)
        self.bucket_name = parts[0]
        self.prefix = parts[1] if len(parts) > 1 else ""

        # Compile regex
        try:
            self.regex = re.compile(self.regex_pattern)
        except re.error as e:
            log.error(f"Invalid regex: {e}")
            sys.exit(1)

    def derive_filename(self, file_key: str) -> str:
        """
        Derive the base filename from a key by removing the specified suffix.

        If derive_stem is set and the key ends with that suffix,
        returns the key with the suffix removed.
        Otherwise returns the original key.

        Args:
            file_key (str): The S3 object key

        Returns:
            str: The derived filename
        """
        if self.derive_stem and file_key.endswith(self.derive_stem):
            # Remove the suffix from the end
            return file_key[: -len(self.derive_stem)]
        return file_key

    def get_batch_filename(self, base_filename: str, batch_num: int) -> str:
        """
        Generate a batch filename by inserting batch number before extension.

        Args:
            base_filename (str): Original filename (e.g., 'delete.json')
            batch_num (int): Batch number (0-indexed)

        Returns:
            str: Batch filename (e.g., 'delete_00.json')
        """
        if "." in base_filename:
            parts = base_filename.rsplit(".", 1)
            return f"{parts[0]}_{batch_num:02d}.{parts[1]}"
        return f"{base_filename}_{batch_num:02d}"

    def list_files(self) -> Sequence[str]:
        """
        List all files in S3 bucket matching the prefix and glob pattern.

        Returns:
            Sequence[str]: List of matching file keys
        """
        files = []
        for file_key in yield_s3_objects(self.bucket_name, self.prefix):
            # Apply glob to the full key. This allows matching directory
            # structures if needed.
            if fnmatch.fnmatch(file_key, self.file_glob):
                files.append(file_key)

        log.info(
            "Found %d files with prefix %s matching glob %s",
            len(files),
            self.prefix,
            self.file_glob,
        )
        return files

    def process_file(self, s3_path: str) -> bool:
        """
        Reads a file from S3 and checks if it matches the regex.
        Stops processing as soon as the first match is found.

        Args:
            s3_path (str): Full S3 path to the file

        Returns:
            bool: True if a match is found or if match_on_error is True and
                  the file is corrupted/unreadable, False otherwise
        """
        try:
            # smart_open handles compression based on extension or content
            with smart_open(
                s3_path,
                "r",
                encoding="utf-8",
                errors="ignore",
                transport_params=get_transport_params(s3_path),
            ) as f:
                for line in f:
                    if self.regex.search(line):
                        log.debug(f"Match found in {s3_path}")
                        # Stop reading immediately after first match
                        return True
        except Exception as e:
            # Log the error with full traceback
            log.error(f"Error reading {s3_path}: {e}", exc_info=True)

            # If match_on_error is True, treat this as a match
            # (useful for identifying corrupted files for deletion)
            if self.match_on_error:
                log.warning(f"Treating unreadable file as match: {s3_path}")
                return True
        return False

    def run(self) -> None:
        """
        Runs the regex matcher, processing all matching files and
        printing S3 paths of files containing the regex pattern.

        If output_json is specified, generates a JSON file for AWS
        batch deletion instead of printing to stdout.
        """
        try:
            files = self.list_files()
            total_files = len(files)

            matching_keys = []
            for idx, file_key in enumerate(files, start=1):
                s3_path = f"s3://{self.bucket_name}/{file_key}"
                if self.process_file(s3_path):
                    # Always add the original file that matched
                    matching_keys.append(file_key)

                    # If derive_stem is set, also add derived filename
                    # (but check if it exists and is different from original)
                    if self.derive_stem:
                        derived_key = self.derive_filename(file_key)
                        if derived_key != file_key:
                            # Check if derived file exists
                            derived_s3_path = f"s3://{self.bucket_name}/{derived_key}"
                            if s3_file_exists(self.s3_client, derived_s3_path):
                                matching_keys.append(derived_key)
                                log.debug(f"Including derived file: {derived_key}")
                            else:
                                log.debug(f"Derived file does not exist: {derived_key}")

                    if not self.output_json:
                        # Print to stdout if not generating JSON
                        # Show both original and derived if applicable
                        print(f"s3://{self.bucket_name}/{file_key}")
                        if self.derive_stem:
                            derived_key = self.derive_filename(file_key)
                            if derived_key != file_key:
                                print(f"s3://{self.bucket_name}/{derived_key}")
                        sys.stdout.flush()

                # Log progress every 100 files
                if idx % 100 == 0:
                    log.info(
                        "Progress: %d/%d files processed, %d matches so far",
                        idx,
                        total_files,
                        len(matching_keys),
                    )

            if self.derive_stem:
                log.info(
                    "Found %d files for deletion (includes derived files) "
                    "from pattern '%s'",
                    len(matching_keys),
                    self.regex_pattern,
                )
            else:
                log.info(
                    "Found %d files containing pattern '%s'",
                    len(matching_keys),
                    self.regex_pattern,
                )
            # Generate JSON for AWS batch deletion if requested
            if self.output_json:
                self.write_deletion_json(matching_keys)

        except Exception as e:
            log.error(f"Error processing files: {e}", exc_info=True)
            sys.exit(1)

    def write_deletion_json(self, keys: List[str]) -> None:
        """
        Write AWS batch deletion JSON files, splitting into batches of 1000 keys.
        Also generates a shell script with all deletion commands.

        Args:
            keys (List[str]): List of S3 object keys to delete
        """
        if not keys:
            log.warning("No keys to write for deletion")
            return

        # AWS S3 API limit: 1000 objects per delete-objects request
        BATCH_SIZE = 1000
        num_batches = (len(keys) + BATCH_SIZE - 1) // BATCH_SIZE

        batch_files = []
        commands = []

        try:
            base_filename = self.output_json or "delete.json"

            for batch_num in range(num_batches):
                start_idx = batch_num * BATCH_SIZE
                end_idx = min(start_idx + BATCH_SIZE, len(keys))
                batch_keys = keys[start_idx:end_idx]

                batch_filename = self.get_batch_filename(base_filename, batch_num)
                batch_files.append(batch_filename)

                deletion_data = {"Objects": [{"Key": key} for key in batch_keys]}

                with smart_open(
                    batch_filename,
                    "w",
                    encoding="utf-8",
                    transport_params=get_transport_params(batch_filename),
                ) as f:
                    json.dump(deletion_data, f, indent=2, ensure_ascii=False)

                log.info(
                    "Wrote batch %d/%d with %d keys to: %s",
                    batch_num + 1,
                    num_batches,
                    len(batch_keys),
                    batch_filename,
                )

                # Generate AWS CLI command for this batch
                cmd = (
                    f"aws s3api delete-objects --bucket {self.bucket_name} "
                    f"--delete file://{batch_filename}"
                )
                commands.append(cmd)

            # Write shell script with all commands
            script_filename = base_filename.replace(".json", "_commands.sh")

            with open(script_filename, "w", encoding="utf-8") as f:
                f.write("#!/bin/bash\n")
                f.write("# Auto-generated deletion commands\n")
                f.write(f"# Total keys: {len(keys)}\n")
                f.write(f"# Batches: {num_batches}\n\n")
                f.write("set -e\n\n")
                for i, cmd in enumerate(commands, 1):
                    f.write(f"echo 'Executing batch {i}/{num_batches}...'\n")
                    f.write(f"{cmd}\n")
                    if i < len(commands):
                        f.write("\n")

            log.info(
                "\n"
                + "=" * 70
                + "\n"
                "Wrote %d keys across %d batch file(s):\n  %s\n\n"
                "Generated deletion script: %s\n\n"
                "Execute with:\n  bash %s\n\n"
                "Or run individual commands:\n  %s\n"
                + "=" * 70,
                len(keys),
                num_batches,
                "\n  ".join(batch_files),
                script_filename,
                script_filename,
                "\n  ".join(commands[:3]) + ("\n  ..." if len(commands) > 3 else ""),
            )

        except Exception as e:
            log.error(f"Error writing deletion files: {e}", exc_info=True)
            sys.exit(1)


def main(args: Optional[List[str]] = None) -> None:
    """
    Main function to run the Regex Matcher.

    Args:
        args: Command-line arguments (uses sys.argv if None)
    """
    options: argparse.Namespace = parse_arguments(args)

    matcher: RegexMatcher = RegexMatcher(
        s3_prefix=options.s3_prefix,
        file_glob=options.glob,
        regex_pattern=options.regex,
        log_level=options.log_level,
        log_file=options.log_file,
        output_json=options.output_json,
        derive_stem=options.derive_stem,
        match_on_error=options.match_on_error,
    )

    # Log the parsed options after logger is configured
    log.info("%s", options)

    matcher.run()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log.error(f"Processing error: {e}", exc_info=True)
        sys.exit(2)
