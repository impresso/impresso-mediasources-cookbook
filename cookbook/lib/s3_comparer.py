#!/usr/bin/env python3
"""
S3 Dataset Comparison Tool

This script compares JSONL.bz2 files from two S3 prefixes using a JQ expression
to extract unique identifiers from each JSON object. It finds the identifiers
present in both datasets and writes the common identifiers to an output file.

Features:
- Reads JSONL.bz2 files from two different S3 prefixes
- Uses a JQ expression to extract a comparison key (ID) from each JSON object
- Efficiently finds the intersection of IDs between the two datasets
- Outputs the common IDs to a local file or an S3 path
- Integrates with impresso_cookbook for consistent logging and S3 handling
- Memory-efficient processing: processes files one by one without storing large datasets

Usage:
    python s3_comparer.py \\
        --s3-prefix1 s3://bucket/path/to/first/dataset \\
        --s3-prefix2 s3://bucket/path/to/second/dataset \\
        --id-expr '.id' \\
        --output s3://bucket/output/common_ids.txt \\
        --log-level INFO

    # With transformation and comparison:
    python s3_comparer.py \\
        --s3-prefix1 s3://bucket/path/to/first/dataset \\
        --s3-prefix2 s3://bucket/path/to/second/dataset \\
        --id-expr '.id' \\
        --transform-file transform.jq \\
        --comparison-expr '.[0] == .[1]' \\
        --output s3://bucket/output/comparison_results.jsonl \\
        --log-level INFO

This will extract the 'id' field from all items in both prefixes. If only basic
comparison is needed, it writes the IDs that appear in both datasets to the output.
If transform-file and comparison-expr are provided, it applies the transformation
to matching records and evaluates the comparison expression on the tuple.
"""

import argparse
import json
import logging
import sys
from typing import List, Optional, Generator, Dict, Any

import jq
from dotenv import load_dotenv
from smart_open import open as smart_open

from impresso_cookbook import (
    get_s3_client,
    get_timestamp,
    setup_logging,
    get_transport_params,
    yield_s3_objects,
    parse_s3_path,
)

log = logging.getLogger(__name__)

# Load environment variables for S3 credentials
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
        description="Compare items from two S3 prefixes and find common IDs.",
        formatter_class=argparse.RawTextHelpFormatter,
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
        "--s3-prefix1",
        type=str,
        required=True,
        help="First S3 path prefix (e.g., s3://bucket/prefix1)",
    )
    parser.add_argument(
        "--s3-prefix2",
        type=str,
        required=True,
        help="Second S3 path prefix (e.g., s3://bucket/prefix2)",
    )
    parser.add_argument(
        "--id-expr",
        type=str,
        required=True,
        help=(
            "JQ expression to extract the identifier from each JSON object (e.g.,"
            " '.id')"
        ),
    )
    parser.add_argument(
        "--transform-file",
        type=str,
        help="Path to file containing JQ code to transform each JSON record",
    )
    parser.add_argument(
        "--comparison-expr",
        type=str,
        help="JQ expression to apply to the tuple of transformed records",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        required=True,
        help="Output path for results (local or S3), one result per line.",
    )
    return parser.parse_args(args)


class S3ComparerProcessor:
    """
    A processor class that compares datasets from two S3 prefixes and finds common IDs.
    Uses memory-efficient processing by handling files one at a time.
    """

    def __init__(
        self,
        s3_prefix1: str,
        s3_prefix2: str,
        id_expr: str,
        output_file: str,
        transform_file: Optional[str] = None,
        comparison_expr: Optional[str] = None,
        log_level: str = "INFO",
        log_file: Optional[str] = None,
    ) -> None:
        """
        Initializes the S3ComparerProcessor with explicit parameters.

        Args:
            s3_prefix1 (str): First S3 prefix path
            s3_prefix2 (str): Second S3 prefix path
            id_expr (str): JQ expression to extract IDs
            output_file (str): Path to the output file
            transform_file (Optional[str]): Path to file with JQ transformation code
            comparison_expr (Optional[str]): JQ expression for tuple comparison
            log_level (str): Logging level (default: "INFO")
            log_file (Optional[str]): Path to log file (default: None)
        """
        self.s3_prefix1 = s3_prefix1
        self.s3_prefix2 = s3_prefix2
        self.id_expr = id_expr
        self.output_file = output_file
        self.transform_file = transform_file
        self.comparison_expr = comparison_expr
        self.log_level = log_level
        self.log_file = log_file

        # Configure the module-specific logger
        setup_logging(self.log_level, self.log_file, logger=log)

        # Initialize S3 client and timestamp
        self.s3_client = get_s3_client()
        self.timestamp = get_timestamp()

        # Compile JQ expressions
        try:
            self.id_program = jq.compile(self.id_expr)
        except Exception as e:
            log.error(f"Invalid ID JQ expression '{self.id_expr}': {e}")
            sys.exit(1)

        # Load and compile transform JQ code if provided
        self.transform_program = None
        if self.transform_file:
            try:
                with smart_open(
                    self.transform_file,
                    "r",
                    encoding="utf-8",
                    transport_params=get_transport_params(self.transform_file),
                ) as f:
                    transform_code = f.read().strip()
                self.transform_program = jq.compile(transform_code)
                log.info(f"Loaded transform JQ code from {self.transform_file}")
            except Exception as e:
                log.error(f"Failed to load transform file '{self.transform_file}': {e}")
                sys.exit(1)

        # Compile comparison JQ expression if provided
        self.comparison_program = None
        if self.comparison_expr:
            try:
                self.comparison_program = jq.compile(self.comparison_expr)
            except Exception as e:
                log.error(
                    f"Invalid comparison JQ expression '{self.comparison_expr}': {e}"
                )
                sys.exit(1)

        # Initialize output file
        self.output_writer = None

    def read_jsonl_records(
        self, bucket: str, file_key: str
    ) -> Generator[Dict[str, Any], None, None]:
        """
        Generator that yields JSON records from a JSONL.bz2 file.

        Args:
            bucket (str): The S3 bucket name.
            file_key (str): The S3 file key.

        Yields:
            Dict[str, Any]: JSON records with their extracted IDs.
        """
        transport_params = get_transport_params(f"s3://{bucket}/{file_key}")

        try:
            with smart_open(
                f"s3://{bucket}/{file_key}",
                "rb",
                transport_params=transport_params,
            ) as infile:
                for line_num, line in enumerate(infile, 1):
                    try:
                        data = json.loads(line)
                        item_id = self.id_program.input(data).first()
                        if item_id is not None:
                            yield {"id": str(item_id), "record": data}
                    except (json.JSONDecodeError, StopIteration):
                        log.warning(f"Skipping malformed line {line_num} in {file_key}")
                    except Exception as e:
                        log.error(
                            f"Error processing line {line_num} in {file_key}: {e}"
                        )
        except Exception as e:
            log.error(f"Failed to open or read file {file_key}: {e}")

    def get_corresponding_file_key(
        self, file_key1: str, bucket2: str, prefix2: str
    ) -> Optional[str]:
        """
        Find the corresponding file in the second prefix based on the file key from the first prefix.

        Args:
            file_key1 (str): File key from the first prefix
            bucket2 (str): Bucket for the second prefix
            prefix2 (str): Prefix for the second dataset

        Returns:
            Optional[str]: Corresponding file key if it exists, None otherwise
        """
        # Extract the relative path from the first file key
        bucket1, prefix1 = parse_s3_path(self.s3_prefix1)

        if not file_key1.startswith(prefix1):
            log.warning(f"File key {file_key1} doesn't start with prefix {prefix1}")
            return None

        # Get the relative path after the prefix
        relative_path = file_key1[len(prefix1) :].lstrip("/")

        # Construct the corresponding file key in the second prefix
        corresponding_key = f"{prefix2.rstrip('/')}/{relative_path}"

        # Check if the file exists
        try:
            self.s3_client.head_object(Bucket=bucket2, Key=corresponding_key)
            return corresponding_key
        except Exception:
            return None

    def open_output_writer(self):
        """Open the output file for writing."""
        if self.output_writer is None:
            self.output_writer = smart_open(
                self.output_file,
                "w",
                encoding="utf-8",
                transport_params=get_transport_params(self.output_file),
            )

    def close_output_writer(self):
        """Close the output file."""
        if self.output_writer is not None:
            self.output_writer.close()
            self.output_writer = None

    def write_result(self, result: Any) -> None:
        """Write a single result to the output file."""
        if isinstance(result, (dict, list)):
            self.output_writer.write(json.dumps(result, ensure_ascii=False) + "\n")
        else:
            self.output_writer.write(str(result) + "\n")

    def process_file_pair(
        self, bucket1: str, file_key1: str, bucket2: str, file_key2: str
    ) -> int:
        """
        Process a pair of corresponding files from both prefixes.

        Args:
            bucket1 (str): Bucket for the first file
            file_key1 (str): Key for the first file
            bucket2 (str): Bucket for the second file
            file_key2 (str): Key for the second file

        Returns:
            int: Number of results written
        """
        log.debug(f"Processing file pair: {file_key1} <-> {file_key2}")

        # Read all records from the first file into a dictionary for fast lookup
        records1 = {}
        record_count1 = 0
        for record_data in self.read_jsonl_records(bucket1, file_key1):
            records1[record_data["id"]] = record_data["record"]
            record_count1 += 1

        log.debug(f"Loaded {record_count1} records from {file_key1}")

        if not records1:
            log.warning(f"No valid records found in {file_key1}")
            return 0

        # Process records from the second file and find matches
        results_written = 0
        record_count2 = 0

        for record_data2 in self.read_jsonl_records(bucket2, file_key2):
            record_count2 += 1
            item_id = record_data2["id"]
            record2 = record_data2["record"]

            # Check if this ID exists in the first dataset
            if item_id in records1:
                record1 = records1[item_id]

                if self.transform_program and self.comparison_program:
                    # Apply transformation and comparison
                    result = self._process_with_transformation_single(
                        item_id, record1, record2
                    )
                    if result is not None:
                        self.write_result(result)
                        results_written += 1
                else:
                    # Basic mode - just write the common ID
                    self.write_result(item_id)
                    results_written += 1

        log.debug(
            f"Processed {record_count2} records from {file_key2}, found"
            f" {results_written} matches"
        )
        return results_written

    def _process_with_transformation_single(
        self, item_id: str, record1: Dict[str, Any], record2: Dict[str, Any]
    ) -> Any:
        """
        Apply transformations to a single pair of matching records and evaluate comparison expression.

        Args:
            item_id (str): The ID of the records
            record1 (Dict[str, Any]): Record from the first dataset
            record2 (Dict[str, Any]): Record from the second dataset

        Returns:
            Any: Result of the comparison expression, or None if processing failed
        """
        try:
            # Apply transformation to each record
            if self.transform_program is not None:
                try:
                    transformed1 = self.transform_program.input(record1).first()
                except StopIteration:
                    log.debug(f"Transform returned empty for record1 with ID {item_id}")
                    return None
                except Exception as e:
                    log.warning(f"Transform failed for record1 with ID {item_id}: {e}")
                    return None

                try:
                    transformed2 = self.transform_program.input(record2).first()
                except StopIteration:
                    log.debug(f"Transform returned empty for record2 with ID {item_id}")
                    return None
                except Exception as e:
                    log.warning(f"Transform failed for record2 with ID {item_id}: {e}")
                    return None
            else:
                transformed1 = record1
                transformed2 = record2

            # Create tuple and apply comparison expression
            tuple_data = [transformed1, transformed2]
            if self.comparison_program is not None:
                try:
                    result = self.comparison_program.input(tuple_data).first()
                except StopIteration:
                    # JQ expression returned empty (e.g., condition was false)
                    log.debug(f"Comparison returned empty for ID {item_id}")
                    return None
                except Exception as e:
                    log.warning(f"Comparison failed for ID {item_id}: {e}")
                    return None
            else:
                result = tuple_data

            return result

        except Exception as e:
            log.warning(f"Unexpected error processing ID {item_id}: {e}", exc_info=True)
            return None

    def run(self) -> None:
        """
        Runs the S3 comparer processor using memory-efficient file-by-file processing.
        """
        try:
            log.info(
                f"Starting comparison between {self.s3_prefix1} and {self.s3_prefix2}"
            )

            bucket1, prefix1 = parse_s3_path(self.s3_prefix1)
            bucket2, prefix2 = parse_s3_path(self.s3_prefix2)

            # Open output file
            self.open_output_writer()

            total_results = 0
            processed_files = 0
            missing_files = 0

            # Process files one by one
            for file_key1 in yield_s3_objects(bucket1, prefix1):
                if not file_key1.endswith("jsonl.bz2"):
                    continue

                # Find corresponding file in the second prefix
                file_key2 = self.get_corresponding_file_key(file_key1, bucket2, prefix2)

                if file_key2 is None:
                    log.warning(
                        f"No corresponding file found for {file_key1} in"
                        f" {self.s3_prefix2}"
                    )
                    missing_files += 1
                    continue

                # Process the file pair
                try:
                    results_count = self.process_file_pair(
                        bucket1, file_key1, bucket2, file_key2
                    )
                    total_results += results_count
                    processed_files += 1
                    log.info(
                        f"Processed file pair {processed_files}: {file_key1} ->"
                        f" {results_count} results"
                    )
                except Exception as e:
                    log.error(
                        f"Error processing file pair {file_key1} <-> {file_key2}: {e}"
                    )
                    continue

            # Close output file
            self.close_output_writer()

            log.info(
                f"Processing complete. Processed {processed_files} file pairs, found"
                f" {missing_files} missing files, wrote {total_results} results to"
                f" {self.output_file}"
            )

        except Exception as e:
            log.error(f"Error during comparison process: {e}", exc_info=True)
            if self.output_writer:
                self.close_output_writer()
            sys.exit(1)


def main(args: Optional[List[str]] = None) -> None:
    """
    Main function to run the S3 Comparer Processor.

    Args:
        args: Command-line arguments (uses sys.argv if None)
    """
    options: argparse.Namespace = parse_arguments(args)

    processor: S3ComparerProcessor = S3ComparerProcessor(
        s3_prefix1=options.s3_prefix1,
        s3_prefix2=options.s3_prefix2,
        id_expr=options.id_expr,
        output_file=options.output,
        transform_file=options.transform_file,
        comparison_expr=options.comparison_expr,
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
