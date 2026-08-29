#!/usr/bin/env python3
"""
S3 Timestamp Metadata Updater

This module processes JSONL files stored in S3 buckets to extract timestamps from records
and update S3 object metadata accordingly. It supports both single file processing and
batch processing of multiple files using S3 prefixes.

The module follows the impresso_cookbook CLI template pattern with:
- S3TimestampProcessor class for encapsulated business logic
- Template-compliant argument parsing with standard logging options
- Unified logging configuration via setup_logging()
- S3 client initialization via get_s3_client()
- Proper error handling with logging and appropriate exit codes
- Support for .bz2 compressed JSONL files
- Atomic operations with backup/restore functionality for data safety

Key Features:
- Extracts timestamps from JSONL records using configurable keys ('ts', 'cdt')
- Updates S3 object metadata with the latest or first timestamp found
- Supports both single file and batch prefix-based processing
- Creates backups before modifying files and verifies checksums
- Handles compressed (.bz2) JSONL files automatically
- Provides comprehensive logging and statistics

Usage Examples:
    # Process a single file
    python lib/s3_set_timestamp.py --s3-file s3://bucket/path/file.jsonl.bz2 \
        --metadata-key impresso-last-ts --ts-key ts --all-lines

    # Process all files with a prefix
    python lib/s3_set_timestamp.py --s3-prefix s3://bucket/data/ \
        --metadata-key impresso-last-ts --ts-key cdt --force

    # Process with custom output location
    python lib/s3_set_timestamp.py --s3-file s3://bucket/input.jsonl.bz2 \
        --output s3://bucket/output.jsonl.bz2 --log-level DEBUG
"""

import os
import json
import argparse
import tempfile
import sys
from datetime import datetime
from urllib.parse import urlparse
import logging
from dotenv import load_dotenv
from smart_open import open as smart_open

import signal
from contextlib import contextmanager
from typing import List, Optional, Iterator, Any

from impresso_cookbook import (  # type: ignore
    get_s3_client,
    get_timestamp,
    setup_logging,
    get_transport_params,
)

log = logging.getLogger(__name__)
load_dotenv()


@contextmanager
def disable_interrupts() -> Iterator[None]:
    """Context manager to temporarily disable keyboard interrupts."""
    original_handler = signal.getsignal(signal.SIGINT)
    signal.signal(signal.SIGINT, signal.SIG_IGN)
    try:
        yield
    finally:
        signal.signal(signal.SIGINT, original_handler)


def parse_arguments(args: Optional[List[str]] = None) -> argparse.Namespace:
    """
    Parse command-line arguments.

    Args:
        args: Command-line arguments (uses sys.argv if None)

    Returns:
        argparse.Namespace: Parsed arguments
    """
    parser = argparse.ArgumentParser(
        description=(
            "Update S3 object metadata with the last timestamp in .jsonl file(s)."
        )
    )

    # Template-standard logging options
    parser.add_argument(
        "--log-file", dest="log_file", help="Write log to FILE", metavar="FILE"
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: %(default)s)",
    )

    # Original arguments
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument(
        "--s3-prefix",
        help="S3 prefix to process multiple .jsonl files (e.g., s3://bucket/path/).",
    )
    group.add_argument(
        "--s3-file",
        help=(
            "S3 URI of a single .jsonl file to process (e.g.,"
            " s3://bucket/path/file.jsonl)."
        ),
    )
    parser.add_argument(
        "--metadata-key",
        default="impresso-last-ts",
        help="S3 metadata key to write (default: %(default)s).",
    )
    parser.add_argument(
        "--ts-key",
        default="ts",
        choices=["ts", "cdt"],
        help=(
            "Key to look for the timestamp in each JSONL record (default: %(default)s)."
        ),
    )
    parser.add_argument(
        "--all-lines",
        action="store_true",
        help="If set, searches all lines for the latest timestamp. Defaults to False.",
    )
    parser.add_argument(
        "--output",
        help=(
            "Optional S3 URI for the output file with updated metadata. Only valid with"
            " --s3-file."
        ),
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help=(
            "Force reprocessing even if metadata is already up-to-date (default:"
            " False)."
        ),
    )

    args_parsed = parser.parse_args(args)

    # Validation
    if args_parsed.s3_prefix and args_parsed.output:
        parser.error("The --output option is not allowed with --s3-prefix.")

    return args_parsed


class S3TimestampProcessor:
    """
    A processor class that updates S3 object metadata with timestamps from JSONL files.

    This class encapsulates all the business logic for processing JSONL files stored in S3,
    extracting timestamps from records, and updating object metadata. It supports both
    single file processing and batch processing of multiple files using S3 prefixes.

    The processor handles:
    - Downloading and parsing JSONL files (compressed or uncompressed)
    - Extracting timestamps using configurable keys ('ts', 'cdt', 'timestamp')
    - Creating atomic backups before modifications
    - Verifying checksums for data integrity
    - Updating S3 object metadata with extracted timestamps
    - Providing comprehensive statistics and logging

    Follows the impresso_cookbook template pattern with explicit initialization
    parameters and unified logging configuration.
    """

    def __init__(
        self,
        s3_file: Optional[str] = None,
        s3_prefix: Optional[str] = None,
        metadata_key: str = "impresso-last-ts",
        ts_key: str = "ts",
        all_lines: bool = False,
        output: Optional[str] = None,
        force: bool = False,
        log_level: str = "INFO",
        log_file: Optional[str] = None,
    ) -> None:
        """
        Initializes the S3TimestampProcessor with explicit parameters.

        Args:
            s3_file: S3 URI of a single .jsonl file to process
            s3_prefix: S3 prefix to process multiple .jsonl files
            metadata_key: The metadata key to update with the latest timestamp
            ts_key: The key in the JSONL records to extract the timestamp from
            all_lines: If False, only the first timestamp is considered
            output: Optional S3 URI for the output file with updated metadata
            force: Force reprocessing even if metadata is already up-to-date
            log_level: Logging level (default: "INFO")
            log_file: Path to log file (default: None)
        """
        self.s3_file = s3_file
        self.s3_prefix = s3_prefix
        self.metadata_key = metadata_key
        self.ts_key = ts_key
        self.all_lines = all_lines
        self.output = output
        self.force = force
        self.log_level = log_level
        self.log_file = log_file

        # Configure the module-specific logger
        setup_logging(self.log_level, self.log_file, logger=log)

        # Initialize S3 client and timestamp
        self.s3_client: Any = get_s3_client()  # boto3.client type
        self.timestamp: str = get_timestamp()

    def run(self) -> None:
        """
        Runs the S3 timestamp processor, updating metadata for files or prefixes.

        This method orchestrates the processing workflow by determining whether to
        process a single file or multiple files based on a prefix. It handles
        errors gracefully with appropriate logging and exits with proper codes.

        Raises:
            SystemExit: With code 1 if processing fails
        """
        try:
            if self.s3_prefix:
                self.update_metadata_for_prefix()
            elif self.s3_file:
                self.update_metadata_for_file()
        except Exception as e:
            log.error(f"Error processing S3 objects: {e}", exc_info=True)
            sys.exit(1)

    def update_metadata_for_file(self) -> None:
        """
        Updates metadata for a single S3 file.

        This method processes a single file specified by self.s3_file, extracting
        timestamps and updating the object's metadata. It handles cases where
        metadata already exists gracefully by logging and continuing.

        Raises:
            ValueError: If s3_file is not provided or processing fails
        """
        if not self.s3_file:
            raise ValueError("s3_file must be provided")

        try:
            self.update_metadata_if_needed(
                self.s3_file,
                self.metadata_key,
                self.ts_key,
                self.all_lines,
                self.output,
                self.force,
            )
        except ValueError as e:
            if "already exists" in str(e):
                log.info("File skipped: %s", self.s3_file)
            else:
                log.error("Error processing file: %s", e)
                raise

    def update_metadata_for_prefix(self) -> None:
        """
        Updates metadata for all S3 objects matching a given prefix.

        This method lists all .jsonl.bz2 files under the specified S3 prefix and
        processes each one to extract timestamps and update metadata. It uses
        pagination to handle large numbers of objects efficiently and provides
        comprehensive statistics on processed and skipped files.

        Raises:
            ValueError: If s3_prefix is not provided
        """
        if not self.s3_prefix:
            raise ValueError("s3_prefix must be provided")

        parsed = urlparse(self.s3_prefix)
        bucket = parsed.netloc
        prefix = parsed.path.lstrip("/")

        log.debug("Fetching S3 objects with prefix: %s", self.s3_prefix)

        # Use a paginator to handle S3 object listing with paging
        paginator = self.s3_client.get_paginator("list_objects_v2")
        page_iterator = paginator.paginate(Bucket=bucket, Prefix=prefix)

        skipped = 0
        processed = 0

        for page in page_iterator:
            for obj in page.get("Contents", []):
                key = obj["Key"]
                # Handle both compressed and uncompressed JSONL files
                if key.endswith((".jsonl", ".jsonl.bz2", ".jsonl.gz")):
                    log.info("Processing file: %s", key)
                    s3_uri = f"s3://{bucket}/{key}"
                    try:
                        self.update_metadata_if_needed(
                            s3_uri,
                            self.metadata_key,
                            self.ts_key,
                            self.all_lines,
                            None,
                            self.force,
                        )
                        processed += 1
                    except ValueError as e:
                        if "already exists" in str(e):
                            log.info("File skipped: %s", key)
                            skipped += 1
                        else:
                            log.warning("Skipping file due to error: %s", e)
                            skipped += 1

        self.compute_statistics(skipped, processed)

    def compute_statistics(self, skipped: int, processed: int) -> None:
        """
        Computes and logs overall processing statistics.

        This method calculates and logs comprehensive statistics about the batch
        processing operation, including total files encountered, files processed
        successfully, and files skipped due to existing metadata or errors.

        Args:
            skipped: Number of files skipped during processing
            processed: Number of files successfully processed
        """
        overall = skipped + processed
        log.info("Overall statistics:")
        log.info("Total files: %d", overall)
        log.info("Skipped files: %d", skipped)
        log.info("Processed files: %d", processed)

    def get_last_timestamp(self, fileobj: str, ts_key: str, all_lines: bool) -> str:
        """
        Extracts the latest or first timestamp from a JSONL file.

        This method processes a .jsonl file (with optional compression) to extract
        timestamps from individual records based on a configurable key. It supports
        multiple timestamp formats and can either return the first timestamp found
        or scan all records to find the latest one.

        Args:
            fileobj: Path to the .jsonl file to process (may be compressed)
            ts_key: The key in JSONL records to extract timestamps from
            all_lines: If False, returns first timestamp found

        Returns:
            str: The timestamp in ISO 8601 format (e.g., '2023-01-01T12:00:00Z')

        Raises:
            ValueError: If no valid timestamp is found or the key format is unknown
        """
        latest_ts = None
        known_formats = {
            "ts": "%Y-%m-%dT%H:%M:%SZ",
            "cdt": "%Y-%m-%d %H:%M:%S",
            "timestamp": "%Y-%m-%dT%H:%M:%SZ",
        }
        skipped_records = 0

        try:
            fmt = known_formats.get(ts_key)
            if not fmt:
                raise ValueError(f"Unknown timestamp format for key: {ts_key}")

            log.debug("Processing file for timestamps with key '%s'", ts_key)

            # Use smart_open to handle compressed/uncompressed files automatically
            with smart_open(fileobj, "rt") as f:
                for line in f:
                    try:
                        record = json.loads(line.strip())
                        ts_str = (
                            record.get(ts_key)
                            or record.get("cdt")
                            or record.get("timestamp")
                        )
                        if ts_str:
                            # Determine the correct format for parsing
                            for key, format_str in known_formats.items():
                                try:
                                    parsed = datetime.strptime(ts_str, format_str)
                                    ts_str = parsed.strftime("%Y-%m-%dT%H:%M:%SZ")
                                    break
                                except ValueError:
                                    continue
                            else:
                                raise ValueError(
                                    f"Timestamp format not recognized: {ts_str}"
                                )

                            if not all_lines:
                                log.debug("Taking the first timestamp: %s", ts_str)
                                return ts_str
                            if latest_ts is None or parsed > latest_ts:
                                latest_ts = parsed
                                log.debug("Updated latest timestamp to: %s", latest_ts)
                    except (ValueError, TypeError, json.JSONDecodeError) as e:
                        skipped_records += 1
                        log.warning(
                            "Skipping invalid record: %s. Line content: %s",
                            e,
                            line[:100],
                        )
                        continue

            if not latest_ts:
                log.warning(
                    "No valid timestamp found in records. Using file modification date."
                )
                mod_time = datetime.utcfromtimestamp(os.path.getmtime(fileobj))
                return mod_time.strftime("%Y-%m-%dT%H:%M:%SZ")

        except Exception as e:
            log.error("Error processing timestamps: %s", e)
            raise ValueError(f"Error processing timestamps: {e}")

        log.debug(
            "Final latest timestamp: %s. Total skipped records: %d",
            latest_ts,
            skipped_records,
        )
        return latest_ts.strftime("%Y-%m-%dT%H:%M:%SZ")

    def update_metadata_if_needed(
        self,
        s3_uri: str,
        metadata_key: str,
        ts_key: str,
        all_lines: bool,
        output_s3_uri: Optional[str] = None,
        force: bool = False,
    ) -> None:
        """
        Updates the metadata of an S3 object with the latest timestamp from a JSONL file.

        This method performs atomic metadata updates by:
        1. Checking if metadata already exists (skipping if not forced)
        2. Downloading the file to extract timestamps
        3. Creating a backup before modification
        4. Verifying checksums for data integrity
        5. Updating object metadata with the extracted timestamp
        6. Cleaning up backup files on successful completion

        Args:
            s3_uri: The S3 URI of the .jsonl file to process
            metadata_key: The metadata key to update with the latest timestamp
            ts_key: The key in the JSONL records to extract the timestamp from
            all_lines: If False, only the first timestamp is considered
            output_s3_uri: Optional S3 URI for the output file with updated metadata
            force: Force reprocessing even if metadata is already up-to-date

        Raises:
            ValueError: If the timestamp extraction or metadata update fails
        """
        parsed = urlparse(s3_uri)
        bucket = parsed.netloc
        key = parsed.path.lstrip("/")

        log.debug("Fetching S3 object metadata for: %s", s3_uri)

        # Check if the metadata key exists before downloading the file
        head = self.s3_client.head_object(Bucket=bucket, Key=key)
        existing_metadata = head.get("Metadata", {})

        if metadata_key in existing_metadata and not force:
            log.info("[SKIP] Metadata key '%s' already exists.", metadata_key)
            raise ValueError("Metadata key already exists.")

        # Proceed with downloading the file only if the metadata key does not exist
        # Extract file extension to preserve compression format detection
        if key.endswith(".jsonl.bz2"):
            file_suffix = ".jsonl.bz2"
        elif key.endswith(".jsonl.gz"):
            file_suffix = ".jsonl.gz"
        else:
            file_suffix = ".jsonl"

        with tempfile.NamedTemporaryFile(
            mode="w+b", delete=True, suffix=file_suffix
        ) as tmp:
            log.debug("Downloading S3 object to temporary file")
            self.s3_client.download_fileobj(bucket, key, tmp)
            tmp.seek(0)
            latest_ts = self.get_last_timestamp(
                tmp.name, ts_key, all_lines
            )  # Pass the file path

        log.debug("Latest timestamp extracted: %s", latest_ts)

        # Create a backup of the original file
        backup_key = f"{key}.backup"
        log.debug("Creating backup of the original file: %s", backup_key)
        with disable_interrupts():
            self.s3_client.copy_object(
                Bucket=bucket,
                Key=backup_key,
                CopySource={"Bucket": bucket, "Key": key},
            )

        # Verify the checksum of the backup matches the original file
        original_head = self.s3_client.head_object(Bucket=bucket, Key=key)
        backup_head = self.s3_client.head_object(Bucket=bucket, Key=backup_key)

        if original_head.get("ETag") != backup_head.get("ETag"):
            log.error("Backup checksum mismatch! Aborting process.")
            raise ValueError(
                "Backup checksum mismatch. The backup file is not identical to the "
                "original."
            )

        log.debug("Backup checksum verified successfully.")

        updated_metadata = existing_metadata.copy()
        updated_metadata[metadata_key] = latest_ts

        log.debug("[UPDATE] Setting %s=%s on %s", metadata_key, latest_ts, s3_uri)

        destination_bucket = bucket
        destination_key = key

        if output_s3_uri:
            output_parsed = urlparse(output_s3_uri)
            destination_bucket = output_parsed.netloc
            destination_key = output_parsed.path.lstrip("/")

        with disable_interrupts():
            self.s3_client.copy_object(
                Bucket=destination_bucket,
                Key=destination_key,
                CopySource={"Bucket": bucket, "Key": key},
                Metadata=updated_metadata,
                MetadataDirective="REPLACE",
                ContentType=head.get("ContentType", "application/octet-stream"),
            )

        # Compare checksums of the updated file and the backup
        updated_head = self.s3_client.head_object(Bucket=bucket, Key=key)

        if updated_head.get("ETag") == backup_head.get("ETag"):
            log.debug("Checksum match confirmed. Deleting backup file: %s", backup_key)
            try:
                with disable_interrupts():
                    self.s3_client.delete_object(Bucket=bucket, Key=backup_key)
                log.debug("Backup file deleted successfully: %s", backup_key)
            except Exception as e:
                log.warning(
                    "Failed to delete backup file: %s. Error: %s", backup_key, e
                )
        else:
            log.error("Checksum mismatch! Backup file retained: %s", backup_key)
            raise ValueError("Checksum mismatch between updated file and backup.")

        log.debug("[DONE] Metadata updated.")


def main(args: Optional[List[str]] = None) -> None:
    """
    Main function to run the S3 Timestamp Processor.

    This function follows the impresso_cookbook CLI template pattern by:
    1. Parsing command-line arguments using parse_arguments()
    2. Initializing the S3TimestampProcessor with parsed options
    3. Logging the configuration for transparency
    4. Running the processor to perform the actual work

    Args:
        args: Command-line arguments (uses sys.argv if None)
    """
    options: argparse.Namespace = parse_arguments(args)

    processor: S3TimestampProcessor = S3TimestampProcessor(
        s3_file=options.s3_file,
        s3_prefix=options.s3_prefix,
        metadata_key=options.metadata_key,
        ts_key=options.ts_key,
        all_lines=options.all_lines,
        output=options.output,
        force=options.force,
        log_level=options.log_level,
        log_file=options.log_file,
    )

    # Log the parsed options after logger is configured
    log.info("%s", options)

    processor.run()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log.error(f"Processing error: {e}", exc_info=True)
        sys.exit(2)
