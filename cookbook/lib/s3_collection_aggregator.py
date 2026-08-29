#!/usr/bin/env python3
"""
This script processes JSONL.bz2 files stored in an S3 bucket, streaming all JSON
objects to a jq filter for collection-level processing. Unlike s3_aggregator.py which
applies jq filters per-object, this aggregates all objects and applies the filter once
to the entire collection.

Features:
- Reads JSONL.bz2 files from an S3 bucket using a specified prefix
- Streams all JSON objects to a single jq filter invocation
- Supports jq filters that process collections (like compute_word_frequencies.jq)
- Outputs processed data to local files or S3 paths
- Automatic temporary file cleanup under all exit conditions
- Comprehensive logging with optional S3-compatible log files

jq Filter Requirements:
- The jq filter MUST be written to use `inputs` (not `.`) to read from stdin,
  because jq is invoked with `-n` (null input). Example: `[inputs | ...]`
- Environment variables are accessible in jq filters via `$ENV.VAR_NAME`
  (e.g., `$ENV.LANGUAGE`, `$ENV.POS_TAGS`).

Environment Variables:
- AWS credentials should be configured via standard AWS methods
- .env file support is available for configuration
- Environment variables can be passed to jq filters via $ENV (e.g., LANGUAGE, POS_TAGS)

Usage:
    python3 s3_collection_aggregator.py --s3-prefix s3://bucket/prefix \\
        --jq-filter lib/compute_lemma_PROPN_NOUN_frequencies.jq \\
        --output s3://output-bucket/output.jsonl

Examples:
1. Compute word frequencies for a collection:
    LANGUAGE=de python3 s3_collection_aggregator.py \\
        --s3-prefix s3://bucket/lingproc/ \\
        --jq-filter lib/compute_word_frequencies.jq \\
        --output frequencies.jsonl

2. Extract lemmas with custom POS tags:
    POS_TAGS="NOUN,VERB,ADJ" LANGUAGE=fr python3 s3_collection_aggregator.py \\
        --s3-prefix s3://bucket/lingproc/ \\
        --jq-filter lib/compute_lemma_PROPN_NOUN_frequencies.jq \\
        --output s3://bucket/output/lemmas.jsonl \\
        --log-file s3://bucket/logs/process.log.gz

3. Process with multiple environment variables:
    LANGUAGE=en POS_TAGS="PROPN NOUN" MIN_LENGTH=3 \\
    python3 s3_collection_aggregator.py \\
        --s3-prefix s3://bucket/prefix \\
        --jq-filter lib/compute_lemma_PROPN_NOUN_frequencies.jq \\
        --output output.jsonl
"""

import argparse
import logging
import os
import re
import subprocess
import sys
import tempfile
from typing import Optional, Sequence
from dotenv import load_dotenv

from impresso_cookbook import get_s3_client, yield_s3_objects  # type: ignore
from smart_open import open as smart_open  # type: ignore

load_dotenv()


class SmartFileHandler(logging.FileHandler):
    def _open(self):
        """Open the log file using smart_open and return a file-like object."""
        return smart_open(self.baseFilename, self.mode, encoding="utf-8")


def stream_s3_to_pipe(bucket: str, prefix: str, pipe) -> int:
    """Stream JSON objects from S3 files to a pipe (e.g., subprocess stdin).

    This writes JSON objects line-by-line without loading entire files
    into memory.

    Args:
        bucket (str): S3 bucket name.
        prefix (str): Prefix to filter files.
        pipe: File-like object to write to (e.g., process.stdin from subprocess.Popen).

    Returns:
        int: Total number of objects written.
    """
    s3 = get_s3_client()
    transport_params = {"client": s3}
    total_files = 0
    total_lines = 0

    for file_key in yield_s3_objects(bucket, prefix):
        if not file_key.endswith("jsonl.bz2"):
            continue

        total_files += 1
        logging.info("Reading file %d: %s", total_files, file_key)

        with smart_open(
            f"s3://{bucket}/{file_key}",
            "rb",
            transport_params=transport_params,
        ) as infile:
            for line in infile:
                total_lines += 1
                # Decode bytes to string (skip validation - let jq handle it)
                line_str = line.decode("utf-8") if isinstance(line, bytes) else line
                pipe.write(line_str)

                # Flush every 1000 lines to keep data flowing
                if total_lines % 1000 == 0:
                    pipe.flush()

                if total_lines % 100 == 0:
                    logging.info(
                        "Streamed %d objects from %d files",
                        total_lines,
                        total_files,
                    )

    logging.info("Total files processed: %d", total_files)
    logging.info("Total objects streamed: %d", total_lines)
    return total_lines


def upload_to_s3(local_path: str, s3_path: str, s3_client) -> None:
    """Upload a local file to an S3 path.

    Args:
        local_path (str): Path to the local file.
        s3_path (str): S3 path to upload the file to.
        s3_client: Boto3 S3 client.
    """
    match = re.match(r"s3://([^/]+)/(.+)", s3_path)
    if not match:
        raise ValueError(f"Invalid S3 path: {s3_path}")
    bucket, key = match.groups()
    s3_client.upload_file(local_path, bucket, key)
    logging.info("Uploaded %s to %s", local_path, s3_path)


def process_collection(
    bucket: str,
    prefix: str,
    jq_filter_path: str,
    output_path: str,
) -> None:
    """Process all JSONL.bz2 files in an S3 bucket.

    Stream to jq filter and write output.

    Args:
        bucket (str): S3 bucket name.
        prefix (str): Prefix to filter files.
        jq_filter_path (str): Path to jq filter file. The filter must use
            `inputs` to read from stdin (jq is invoked with `-n`).
        output_path (str): Path to the output file (local or S3). The file
            extension determines compression: `.gz` → gzip, `.bz2` → bzip2,
            `.jsonl` → uncompressed. Any other extension also produces gzip.
    """
    s3 = get_s3_client()
    suffix = output_path.split(".")[-1]
    if suffix not in ["gz", "bz2", "jsonl"]:
        suffix = "gz"  # Default to gzip compression

    output_tmpfile = None

    try:
        # Create temporary output file
        with tempfile.NamedTemporaryFile(
            delete=False, mode="w", suffix=f".{suffix}"
        ) as tmp_out:
            output_tmpfile = tmp_out.name

        logging.info("Temporary output file: %s", output_tmpfile)
        logging.info("Streaming S3 data through jq filter...")

        # Start jq subprocess with -n flag for streaming
        cmd = ["jq", "-n", "-f", jq_filter_path]
        logging.info("Executing: %s", " ".join(cmd))

        with smart_open(output_tmpfile, "w", encoding="utf-8") as outfile:
            process = subprocess.Popen(
                cmd,
                stdin=subprocess.PIPE,
                stdout=outfile,
                stderr=subprocess.PIPE,
                text=True,
            )

            # Stream S3 data to jq's stdin
            total_objects = 0
            try:
                if process.stdin:
                    total_objects = stream_s3_to_pipe(bucket, prefix, process.stdin)
                    process.stdin.close()

                # Wait for jq to finish processing
                if process.stderr:
                    stderr_output = process.stderr.read()
                else:
                    stderr_output = ""
                return_code = process.wait()

                if return_code != 0:
                    logging.error("jq error: %s", stderr_output)
                    raise RuntimeError(f"jq failed with code {return_code}")

                logging.info(
                    "jq processing complete. Processed %d objects", total_objects
                )
            except Exception as e:
                process.kill()
                raise e

        # Upload or move output file
        if output_path.startswith("s3://"):
            upload_to_s3(output_tmpfile, output_path, s3)
            logging.info("Uploaded to S3: %s", output_path)
        else:
            import shutil

            shutil.move(output_tmpfile, output_path)
            output_tmpfile = None  # Don't delete in finally
            logging.info("Moved to: %s", output_path)

    except Exception as e:
        logging.error("Error during collection processing: %s", e)
        raise
    finally:
        # Clean up temporary file
        if output_tmpfile and os.path.exists(output_tmpfile):
            try:
                os.unlink(output_tmpfile)
                logging.debug("Cleaned up: %s", output_tmpfile)
            except Exception as e:
                logging.warning("Failed to clean up %s: %s", output_tmpfile, e)


def parse_arguments(args: Optional[Sequence[str]] = None) -> argparse.Namespace:
    """Parse command-line arguments.

    Args:
        args (Optional[Sequence[str]]): Command-line arguments.

    Returns:
        argparse.Namespace: Parsed argument namespace.
    """
    parser = argparse.ArgumentParser(
        description="Process JSONL.bz2 collections from S3 with jq filter",
        epilog=(
            "Stream all JSONL.bz2 files from S3 and apply a jq filter to the entire "
            "collection. Useful for collection-level aggregations like frequency "
            "counts. Environment variables (e.g., LANGUAGE, POS_TAGS) are passed "
            "to jq filters."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )

    parser.add_argument(
        "-o",
        "--output",
        type=str,
        required=True,
        help=(
            "Path to store the output file (local or S3). Example: "
            "s3://your-bucket/output-prefix/output.jsonl"
        ),
    )

    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: INFO)",
    )

    parser.add_argument("--log-file", type=str, help="Log file path (local or S3)")

    parser.add_argument(
        "--s3-prefix",
        type=str,
        required=True,
        help="S3 path prefix (s3://BUCKET/PREFIX) to read JSONL.bz2 files",
    )

    parser.add_argument(
        "--jq-filter",
        type=str,
        required=True,
        help="Path to a jq filter file to apply to the collection",
    )

    return parser.parse_args(args)


def main(args: Optional[Sequence[str]] = None) -> None:
    """Main function to run the collection aggregation process.

    Args:
        args (Optional[Sequence[str]]): Command-line arguments.
    """
    if args is None:
        args = sys.argv[1:]
    options = parse_arguments(args)

    handlers = [logging.StreamHandler()]
    if options.log_file:
        handlers.append(SmartFileHandler(options.log_file, mode="w"))
    logging.basicConfig(
        level=options.log_level,
        format="%(asctime)-15s %(filename)s:%(lineno)d %(levelname)s: %(message)s",
        handlers=handlers,
        force=True,
    )

    logging.info("Arguments: %s", options)
    logging.info("Processing S3 prefix: %s", options.s3_prefix)

    match = re.match(r"s3://([^/]+)/(.+)", options.s3_prefix)
    if not match:
        logging.error("Invalid S3 prefix format. Expected s3://BUCKET/PREFIX")
        sys.exit(1)
    bucket, prefix = match.groups()

    # Verify jq filter file exists
    if not os.path.exists(options.jq_filter):
        logging.error("jq filter file not found: %s", options.jq_filter)
        sys.exit(1)

    logging.info("Using jq filter: %s", options.jq_filter)

    process_collection(bucket, prefix, options.jq_filter, options.output)

    logging.info("Processing complete. Results saved to %s", options.output)


if __name__ == "__main__":
    main()
