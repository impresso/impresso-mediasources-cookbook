#!/usr/bin/env python3
"""
S3 Dataset Sampling Tool

This script samples jsonl.bz2 files from an S3 prefix using various sampling strategies.
It supports random sampling, stratified sampling by groups, and optional JQ
transformations
and filters.

Features:
- Reads JSONL.bz2 files from an S3 bucket using a specified prefix
- Supports random sampling with configurable sampling rate
- Supports stratified sampling with max samples per group (e.g., newspaper)
- Allows JQ-based filtering and transformation of records
- Memory-efficient streaming processing
- Outputs sampled data to a local file or S3 path
- Reproducible sampling with configurable random seed

Usage:
    python s3_sampler.py \
        --s3-prefix s3://bucket/path/to/dataset \
        --output s3://bucket/output/sampled_data.jsonl \
        --sampling-rate 0.1 \
        --log-level INFO

    # Stratified sampling by newspaper with max 100 samples per newspaper:
    python s3_sampler.py \
        --s3-prefix s3://bucket/path/to/dataset \
        --output sampled_data.jsonl \
        --group-by-expr '.newspaper_id' \
        --max-samples-per-group 100 \
        --filter-file filter.jq \
        --transform-file transform.jq \
        --random-seed 42

Examples:
1. Simple random sampling (10%):
    python s3_sampler.py --s3-prefix s3://bucket/data \\
        --output sample.jsonl --sampling-rate 0.1

2. Stratified sampling with filtering:
    python s3_sampler.py --s3-prefix s3://bucket/data --output sample.jsonl \
        --group-by-expr '.newspaper_id' --max-samples-per-group 50 \
        --filter-expr 'select(.type == "article")'

3. Transform and sample:
    python s3_sampler.py --s3-prefix s3://bucket/data --output sample.jsonl \
        --transform-expr '{id: .id, text: .content_text, date: .date}' \
        --sampling-rate 0.05
"""

import argparse
import json
import logging
import random
import sys
import tempfile
from collections import defaultdict
from typing import Dict, Any, Optional, List, Generator

import jq
from dotenv import load_dotenv
from smart_open import open as smart_open

try:
    from impresso_cookbook import (
        get_s3_client,
        get_timestamp,
        setup_logging,
        get_transport_params,
        yield_s3_objects,
        parse_s3_path,
    )
except ImportError:
    # Fallback for when impresso_cookbook is not available
    from common import (
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
        description="Sample JSONL.bz2 files from S3 using various sampling strategies.",
        formatter_class=argparse.RawTextHelpFormatter,
    )

    # Logging options
    parser.add_argument(
        "--log-file", dest="log_file", help="Write log to FILE", metavar="FILE"
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: %(default)s)",
    )

    # Input/Output options
    parser.add_argument(
        "--s3-prefix",
        type=str,
        required=True,
        help="S3 path prefix (e.g., s3://bucket/prefix) to read JSONL.bz2 files",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=str,
        required=True,
        help="Output path for sampled data (local or S3), JSONL format.",
    )

    # Sampling options
    parser.add_argument(
        "--sampling-rate",
        type=float,
        help=(
            "Random sampling rate (0.0 to 1.0). "
            "Mutually exclusive with max-samples-per-group."
        ),
    )
    parser.add_argument(
        "--max-samples-per-group",
        type=int,
        help=(
            "Maximum samples per group (requires --group-by-expr). "
            "Mutually exclusive with sampling-rate."
        ),
    )
    parser.add_argument(
        "--group-by-expr",
        type=str,
        help="JQ expression to extract group identifier (e.g., '.newspaper_id')",
    )
    parser.add_argument(
        "--random-seed",
        type=int,
        default=42,
        help="Random seed for reproducible sampling (default: %(default)s)",
    )

    # Processing options
    parser.add_argument(
        "--filter-expr",
        type=str,
        help="JQ expression to filter records (e.g., 'select(.type == \"article\")')",
    )
    parser.add_argument(
        "--filter-file",
        type=str,
        help="Path to file containing JQ filter expression",
    )
    parser.add_argument(
        "--transform-expr",
        type=str,
        help="JQ expression to transform records (e.g., '{id: .id, text: .content}')",
    )
    parser.add_argument(
        "--transform-file",
        type=str,
        help="Path to file containing JQ transform expression",
    )
    parser.add_argument(
        "--record-id-field",
        type=str,
        default="id",
        help="JSON property name containing the record ID (default: %(default)s)",
    )

    return parser.parse_args(args)


class S3SamplerProcessor:
    """
    A processor class that samples datasets from S3 using various sampling strategies.
    Supports both random sampling and stratified sampling by groups.
    """

    def __init__(
        self,
        s3_prefix: str,
        output_file: str,
        sampling_rate: Optional[float] = None,
        max_samples_per_group: Optional[int] = None,
        group_by_expr: Optional[str] = None,
        random_seed: int = 42,
        filter_expr: Optional[str] = None,
        filter_file: Optional[str] = None,
        transform_expr: Optional[str] = None,
        transform_file: Optional[str] = None,
        record_id_field: str = "id",
        log_level: str = "INFO",
        log_file: Optional[str] = None,
    ) -> None:
        """
        Initialize the S3SamplerProcessor.

        Args:
            s3_prefix: S3 prefix path to read from
            output_file: Path to the output file
            sampling_rate: Random sampling rate (0.0 to 1.0)
            max_samples_per_group: Maximum samples per group
            group_by_expr: JQ expression to extract group identifier
            random_seed: Random seed for reproducible sampling
            filter_expr: JQ expression for filtering
            filter_file: Path to JQ filter file
            transform_expr: JQ expression for transformation
            transform_file: Path to JQ transform file
            record_id_field: JSON property name containing the record ID
            log_level: Logging level
            log_file: Path to log file
        """
        self.s3_prefix = s3_prefix
        self.output_file = output_file
        self.sampling_rate = sampling_rate
        self.max_samples_per_group = max_samples_per_group
        self.group_by_expr = group_by_expr
        self.random_seed = random_seed
        self.filter_expr = filter_expr
        self.filter_file = filter_file
        self.transform_expr = transform_expr
        self.transform_file = transform_file
        self.record_id_field = record_id_field
        self.log_level = log_level
        self.log_file = log_file

        # Configure logging
        setup_logging(self.log_level, self.log_file, logger=log)

        # Initialize S3 client and timestamp
        self.s3_client = get_s3_client()
        self.timestamp = get_timestamp()

        # Set random seed for reproducible sampling
        random.seed(self.random_seed)

        # Validate sampling configuration
        self._validate_sampling_config()

        # Compile JQ expressions
        self._compile_jq_expressions()

        # Initialize sampling state
        self.group_sample_counts: Dict[str, int] = defaultdict(int)
        self.total_processed = 0
        self.total_sampled = 0

    def _get_record_id(self, record: Dict[str, Any]) -> str:
        """
        Extract record ID from a record using the configured field name.

        This method attempts to extract a record identifier using the configured
        record_id_field. If the specified field is not found, it falls back to
        common alternative field names before using "unknown".

        Args:
            record: JSON record (dict) from which to extract the ID

        Returns:
            str: Record ID or "unknown" if no ID field is found

        Examples:
            >>> # With record_id_field="id" (default)
            >>> processor._get_record_id({"id": "123", "content": "..."})
            "123"

            >>> # With record_id_field="ci_id"
            >>> processor._get_record_id({"ci_id": "456", "content": "..."})
            "456"

            >>> # With missing ID field
            >>> processor._get_record_id({"content": "..."})
            "unknown"
        """
        # Try the configured field first
        if self.record_id_field in record:
            return str(record[self.record_id_field])

        # Fall back to common alternative field names
        fallback_fields = ["id", "_id", "ci_id", "uuid", "identifier"]
        for field in fallback_fields:
            if field in record and field != self.record_id_field:
                return str(record[field])

        return "unknown"

    def _validate_sampling_config(self) -> None:
        """
        Validate sampling configuration parameters to ensure only one sampling strategy
        is used.

        This method performs comprehensive validation of the sampling configuration to
        ensure that the provided parameters are consistent and valid. It checks for
        mutually exclusive options and validates parameter ranges.

        Validation Rules:
        - Only one of sampling_rate or max_samples_per_group can be specified
        - At least one sampling strategy must be provided
        - sampling_rate must be between 0.0 and 1.0 (inclusive)
        - max_samples_per_group must be positive
        - max_samples_per_group requires group_by_expr to be specified

        Raises:
            SystemExit: If validation fails, the program exits with error code 1

        Examples:
            Valid configurations:
            - sampling_rate=0.1 (10% random sampling)
            - max_samples_per_group=100, group_by_expr='.newspaper_id'
              (stratified sampling)

            Invalid configurations:
            - sampling_rate=0.1, max_samples_per_group=100 (mutually exclusive)
            - sampling_rate=1.5 (out of range)
            - max_samples_per_group=100 (missing group_by_expr)
        """
        if self.sampling_rate is not None and self.max_samples_per_group is not None:
            log.error("Cannot specify both sampling-rate and max-samples-per-group")
            sys.exit(1)

        if self.sampling_rate is None and self.max_samples_per_group is None:
            log.error("Must specify either sampling-rate or max-samples-per-group")
            sys.exit(1)

        if self.sampling_rate is not None:
            if not 0.0 <= self.sampling_rate <= 1.0:
                log.error("Sampling rate must be between 0.0 and 1.0")
                sys.exit(1)

        if self.max_samples_per_group is not None:
            if self.max_samples_per_group <= 0:
                log.error("Max samples per group must be positive")
                sys.exit(1)
            if self.group_by_expr is None:
                log.error("max-samples-per-group requires group-by-expr")
                sys.exit(1)

    def _compile_jq_expressions(self) -> None:
        """
        Compile all JQ expressions into executable programs for data processing.

        This method compiles JQ expressions for group-by operations, filtering, and
        transformation. JQ compilation is done once at initialization to avoid
        recompilation overhead during data processing. Invalid expressions will
        cause the program to exit with an error.

        The method handles three types of JQ expressions:
        1. Group-by expression: Used for stratified sampling to extract group
           identifiers
        2. Filter expression: Used to filter records based on conditions
        3. Transform expression: Used to modify record structure before output

        Expression Sources:
        - Direct string expressions via command-line arguments
        - File-based expressions loaded from specified paths
        - Both local files and S3 paths are supported for expression files

        Error Handling:
        - Invalid JQ syntax causes immediate program termination
        - File loading errors are logged and cause program exit
        - All compilation errors include descriptive error messages

        Side Effects:
        - Sets self.group_by_program, self.filter_program, self.transform_program
        - Logs successful compilation of expressions
        - May call sys.exit(1) on compilation or file loading errors

        Examples:
            Group-by expressions:
            - '.newspaper_id' - Extract newspaper identifier
            - '.metadata.source' - Extract nested source field

            Filter expressions:
            - 'select(.type == "article")' - Only keep articles
            - 'select(.date >= "2020-01-01")' - Date-based filtering

            Transform expressions:
            - '{id: .id, text: .content}' - Extract specific fields
            - '. + {processed_date: now}' - Add processing timestamp
        """
        # Group-by expression
        self.group_by_program = None
        if self.group_by_expr:
            try:
                self.group_by_program = jq.compile(self.group_by_expr)
            except Exception as e:
                log.error(f"Invalid group-by JQ expression '{self.group_by_expr}': {e}")
                sys.exit(1)

        # Filter expression
        self.filter_program = None
        if self.filter_expr or self.filter_file:
            filter_code = self.filter_expr
            if self.filter_file:
                try:
                    with smart_open(
                        self.filter_file,
                        "r",
                        encoding="utf-8",
                        transport_params=get_transport_params(self.filter_file),
                    ) as f:
                        filter_code = f.read().strip()
                except Exception as e:
                    log.error(f"Failed to load filter file '{self.filter_file}': {e}")
                    sys.exit(1)

            try:
                self.filter_program = jq.compile(filter_code)
                log.info("Compiled filter JQ expression")
            except Exception as e:
                log.error(f"Invalid filter JQ expression: {e}")
                sys.exit(1)

        # Transform expression
        self.transform_program = None
        if self.transform_expr or self.transform_file:
            transform_code = self.transform_expr
            if self.transform_file:
                try:
                    with smart_open(
                        self.transform_file,
                        "r",
                        encoding="utf-8",
                        transport_params=get_transport_params(self.transform_file),
                    ) as f:
                        transform_code = f.read().strip()
                except Exception as e:
                    log.error(
                        f"Failed to load transform file '{self.transform_file}': {e}"
                    )
                    sys.exit(1)

            try:
                self.transform_program = jq.compile(transform_code)
                log.info("Compiled transform JQ expression")
            except Exception as e:
                log.error(f"Invalid transform JQ expression: {e}")
                sys.exit(1)

    def _apply_filter(self, record: Dict[str, Any]) -> bool:
        """
        Apply filter to a record using the compiled JQ filter expression.

        This method evaluates a record against the compiled filter expression to
        determine if it should be included in further processing. If no filter is
        configured, all records pass through. The filter uses JQ expressions which can
        perform complex conditional logic.

        Filter Behavior:
        - Returns True if no filter is configured (pass-through)
        - Returns True if the filter expression returns a truthy value
        - Returns False if the filter expression returns false, null, or empty
        - Returns False if the filter expression throws an error

        Common Filter Patterns:
        - Content-based: 'select(.type == "article")'
        - Date-based: 'select(.date >= "2020-01-01")'
        - Length-based: 'select(.content | length > 100)'
        - Existence-based: 'select(has("metadata"))'
        - Complex logic: 'select(.type == "article" and .lang == "en")'

        Args:
            record: JSON record (dict) to evaluate against the filter

        Returns:
            bool: True if record passes filter and should be processed further,
                  False if record should be excluded

        Examples:
            >>> # With filter 'select(.type == "article")'
            >>> processor._apply_filter({"type": "article", "content": "..."})
            True
            >>> processor._apply_filter({"type": "advertisement", "content": "..."})
            False

            >>> # With no filter configured
            >>> processor._apply_filter({"any": "record"})
            True
        """
        if self.filter_program is None:
            log.debug("No filter configured, record passes through")
            return True

        try:
            log.debug(f"Applying filter to record with keys: {list(record.keys())}")
            result = self.filter_program.input(record).all()

            if len(result) > 0 and result[0] is not False:
                log.debug(f"Filter passed: result={result[0]}")
                return True
            else:
                log.debug(f"Filter rejected: result={result if result else 'empty'}")
                return False

        except Exception as e:
            record_id = self._get_record_id(record)
            log.debug(f"Filter error for record {record_id}: {e}")
            log.debug(f"Record keys that caused filter error: {list(record.keys())}")
            return False

    def _apply_transform(self, record: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Apply transformation to a record using the compiled JQ transform expression.

        This method transforms a record using the compiled JQ transform expression. If
        no transform is configured, the original record is returned unchanged.
        Transformations can reshape data, extract specific fields, add computed values,
        or perform any structural modifications that JQ supports.

        Transform Behavior:
        - Returns original record if no transform is configured (pass-through)
        - Returns transformed record if transformation succeeds
        - Returns None if transformation fails or produces empty results
        - Logs debug messages for transformation errors

        Common Transform Patterns:
        - Field selection: '{id: .id, text: .content, date: .date}'
        - Field renaming: '{identifier: .id, body: .content}'
        - Nested extraction: '{title: .metadata.title, source: .metadata.source}'
        - Computed fields: '. + {word_count: (.content | split(" ") | length)}'
        - Flattening: '{id, title, content, author: .metadata.author}'
        - Type conversion: '{id, date: .date | strptime("%Y-%m-%d") | todate}'

        Args:
            record: JSON record (dict) to transform

        Returns:
            Optional[Dict[str, Any]]: Transformed record if successful, None if
                                      transformation fails or produces empty results

        Examples:
            >>> # With transform '{id: .id, text: .content}'
            >>> processor._apply_transform({"id": 1, "content": "Hello", "extra": "X"})
            {"id": 1, "text": "Hello"}

            >>> # With no transform configured
            >>> processor._apply_transform({"id": 1, "content": "Hello"})
            {"id": 1, "content": "Hello"}

            >>> # With failing transform (missing field)
            >>> processor._apply_transform({"id": 1})  # missing .content
            None
        """
        if self.transform_program is None:
            log.debug("No transform configured, returning original record")
            return record

        try:
            record_id = self._get_record_id(record)
            log.debug(
                f"Applying transform to record {record_id} with keys: "
                f"{list(record.keys())}"
            )

            transformed = self.transform_program.input(record).first()

            if transformed is not None:
                if isinstance(transformed, dict):
                    transformed_keys = list(transformed.keys())
                    original_keys = list(record.keys())
                    log.debug(
                        f"Transform successful for record {record_id}: "
                        f"original keys={original_keys} -> "
                        f"transformed keys={transformed_keys}"
                    )
                else:
                    log.debug(
                        f"Transform successful for record {record_id}: "
                        f"result type={type(transformed).__name__}"
                    )
                return transformed
            else:
                log.debug(f"Transform returned None for record {record_id}")
                return None

        except StopIteration:
            record_id = self._get_record_id(record)
            log.debug(f"Transform returned empty result for record {record_id}")
            return None
        except Exception as e:
            record_id = self._get_record_id(record)
            log.debug(f"Transform error for record {record_id}: {e}")
            log.debug(f"Record keys that caused transform error: {list(record.keys())}")
            # Log a sample of the record structure for debugging (first few chars)
            record_str = str(record)
            record_preview = (
                record_str[:200] + "..." if len(record_str) > 200 else record_str
            )
            log.debug(f"Record preview: {record_preview}")
            return None

    def _get_group_id(self, record: Dict[str, Any]) -> Optional[str]:
        """
        Extract group identifier from a record using the compiled group-by expression.

        This method applies the compiled JQ group-by expression to extract a group
        identifier from a JSON record. Group identifiers are used for stratified
        sampling to ensure balanced representation across different groups (e.g.,
        newspapers, sources, categories).

        Behavior:
        - Returns "default" if no group-by expression is configured
        - Extracts and stringifies the result of the group-by expression
        - Returns None if the expression fails or returns null
        - Logs debug messages for extraction errors

        Common Group-by Patterns:
        - Simple field: '.newspaper_id' - Extract newspaper identifier
        - Nested field: '.metadata.source' - Extract nested source field
        - Computed group: '.date | split("-")[0]' - Group by year
        - Conditional: 'if .type == "article" then .newspaper_id else "other" end'

        Args:
            record: JSON record (dict) from which to extract group identifier

        Returns:
            Optional[str]: String representation of the group identifier, or None if
                          extraction fails or returns null

        Examples:
            >>> # With group-by expression '.newspaper_id'
            >>> processor._get_group_id({"newspaper_id": "NYT", "content": "..."})
            "NYT"

            >>> # With nested expression '.metadata.source'
            >>> processor._get_group_id({"metadata": {"source": "Reuters"}})
            "Reuters"

            >>> # With no group-by expression
            >>> processor._get_group_id({"any": "record"})
            "default"

            >>> # With failing expression (missing field)
            >>> processor._get_group_id({"content": "..."})  # missing .newspaper_id
            None
        """
        if self.group_by_program is None:
            log.debug("No group-by expression configured, using default group")
            return "default"

        try:
            record_id = self._get_record_id(record)
            log.debug(
                f"Extracting group ID for record {record_id} with keys: "
                f"{list(record.keys())}"
            )

            result = self.group_by_program.input(record).first()

            if result is not None:
                group_id = str(result)
                log.debug(
                    f"Group extraction successful for record {record_id}: "
                    f"group_id='{group_id}'"
                )
                return group_id
            else:
                log.debug(f"Group extraction returned None for record {record_id}")
                return None

        except Exception as e:
            record_id = self._get_record_id(record)
            log.debug(f"Group-by error for record {record_id}: {e}")
            log.debug(f"Record keys that caused group-by error: {list(record.keys())}")
            return None

    def _should_sample(self, record: Dict[str, Any]) -> bool:
        """
        Determine if a record should be sampled using random sampling strategy.

        This method implements random sampling logic only, as stratified sampling
        is now handled separately in the two-pass approach.

        Args:
            record: JSON record (dict) to evaluate for sampling

        Returns:
            bool: True if record should be included in the sample, False otherwise

        Examples:
            Random sampling (sampling_rate=0.1):
            >>> # Approximately 10% of records return True
            >>> processor._should_sample({"any": "record"})  # ~10% chance of True
        """
        if self.sampling_rate is not None:
            # Random sampling
            return random.random() < self.sampling_rate

        # Should not reach here in normal operation
        return False

    def _read_and_process_file(
        self, bucket: str, file_key: str
    ) -> Generator[Dict[str, Any], None, None]:
        """
        Read and process a single JSONL.bz2 file, yielding sampled records.

        This method implements the core file processing logic, handling the complete
        pipeline from reading compressed JSONL files to yielding sampled and transformed
        records. It processes files line by line for memory efficiency and applies all
        configured filtering, sampling, and transformation operations.

        Processing Pipeline:
        1. Opens compressed JSONL.bz2 file from S3 using smart_open
        2. Reads and parses each JSON line
        3. Applies filtering (if configured) to exclude unwanted records
        4. Makes sampling decisions based on configured strategy
        5. Applies transformations (if configured) to modify record structure
        6. Yields successfully processed records

        Error Handling:
        - Malformed JSON lines are logged and skipped
        - File access errors are logged with full traceback
        - Processing errors for individual lines are logged but don't stop processing
        - Maintains processing statistics for monitoring

        Memory Efficiency:
        - Streams data line by line rather than loading entire files
        - Uses generators to avoid accumulating records in memory
        - Suitable for processing very large datasets

        Args:
            bucket: S3 bucket name containing the file
            file_key: S3 object key (path) of the JSONL.bz2 file to process

        Yields:
            Dict[str, Any]: Successfully processed and sampled records that have passed
                           all filtering, sampling, and transformation steps

        Side Effects:
            - Updates self.total_processed counter for all processed records
            - Updates self.total_sampled counter for records that pass sampling
            - Updates self.group_sample_counts for stratified sampling
            - Logs warnings for malformed lines and processing errors

        Examples:
            >>> # Process a file and collect results
            >>> records = list(processor._read_and_process_file("bucket",
            ...                                                 "data.jsonl.bz2"))
            >>> print(f"Processed {len(records)} records")

            >>> # Stream processing without collecting in memory
            >>> for record in processor._read_and_process_file("bucket",
            ...                                                "data.jsonl.bz2"):
            ...     # Process record immediately
            ...     send_to_output(record)
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
                        record = json.loads(line)
                        self.total_processed += 1

                        record_id = self._get_record_id(record)
                        log.debug(f"Processing record {record_id} (line {line_num})")

                        # Apply filter
                        if not self._apply_filter(record):
                            log.debug(f"Record {record_id} filtered out")
                            continue

                        log.debug(f"Record {record_id} passed filter")

                        # Check sampling decision
                        if not self._should_sample(record):
                            log.debug(f"Record {record_id} not selected for sampling")
                            continue

                        log.debug(f"Record {record_id} selected for sampling")

                        # Apply transformation
                        transformed_record = self._apply_transform(record)
                        if transformed_record is not None:
                            self.total_sampled += 1
                            log.debug(
                                f"Record {record_id} successfully transformed "
                                "and will be included in output"
                            )
                            yield transformed_record
                        else:
                            log.debug(
                                f"Record {record_id} transformation failed, "
                                "skipping from output"
                            )

                    except json.JSONDecodeError:
                        log.warning(f"Skipping malformed line {line_num} in {file_key}")
                    except Exception as e:
                        log.error(
                            f"Error processing line {line_num} in {file_key}: {e}"
                        )

        except Exception as e:
            log.error(f"Failed to open or read file {file_key}: {e}")

    def _run_random_sampling(self, bucket: str, prefix: str, tmpfile_path: str) -> None:
        """
        Execute random sampling strategy with single-pass processing.

        For random sampling, we can sample records directly as we process them
        since each record has an independent probability of selection.

        Args:
            bucket: S3 bucket name
            prefix: S3 prefix path
            tmpfile_path: Path to temporary output file
        """
        with smart_open(tmpfile_path, "w", encoding="utf-8") as outfile:
            processed_files = 0

            # Process each file
            for file_key in yield_s3_objects(bucket, prefix):
                if not file_key.endswith("jsonl.bz2"):
                    continue

                log.info(f"Processing file: {file_key}")
                file_sample_count = 0

                for record in self._read_and_process_file(bucket, file_key):
                    outfile.write(json.dumps(record, ensure_ascii=False) + "\n")
                    file_sample_count += 1

                processed_files += 1
                log.info(f"File {file_key}: sampled {file_sample_count} records")

    def _run_stratified_sampling(
        self, bucket: str, prefix: str, tmpfile_path: str
    ) -> None:
        """
        Execute stratified sampling strategy with two-pass processing.

        For stratified sampling, we use a two-pass approach to eliminate bias:
        1. First pass: collect all filtered and transformed records
        2. Shuffle records randomly to eliminate ordering bias
        3. Second pass: apply stratified sampling to shuffled data

        Args:
            bucket: S3 bucket name
            prefix: S3 prefix path
            tmpfile_path: Path to temporary output file
        """
        log.info("Using two-pass stratified sampling strategy")

        # First pass: collect all filtered and transformed records
        log.info("First pass: collecting and filtering records...")
        all_records = []

        for file_key in yield_s3_objects(bucket, prefix):
            if not file_key.endswith("jsonl.bz2"):
                continue

            log.info(f"Processing file: {file_key}")
            file_collected_count = 0

            # Collect filtered and transformed records (but don't apply sampling yet)
            for record in self._collect_filtered_records(bucket, file_key):
                all_records.append(record)
                file_collected_count += 1

            log.info(
                f"File {file_key}: collected {file_collected_count} filtered records"
            )

        log.info(f"First pass complete: collected {len(all_records)} total records")

        # Shuffle records to eliminate ordering bias
        log.info("Shuffling records to eliminate ordering bias...")
        random.shuffle(all_records)

        # Second pass: apply stratified sampling to shuffled data
        log.info("Second pass: applying stratified sampling...")
        self.group_sample_counts = defaultdict(int)  # Reset counters

        with smart_open(tmpfile_path, "w", encoding="utf-8") as outfile:
            for record in all_records:
                # Extract group ID and check if we should sample this record
                group_id = self._get_group_id(record)
                if group_id is None:
                    continue

                if (
                    self.max_samples_per_group is not None
                    and self.group_sample_counts[group_id] < self.max_samples_per_group
                ):
                    self.group_sample_counts[group_id] += 1
                    self.total_sampled += 1
                    outfile.write(json.dumps(record, ensure_ascii=False) + "\n")

        log.info(f"Second pass complete: sampled {self.total_sampled} records")

    def _collect_filtered_records(
        self, bucket: str, file_key: str
    ) -> Generator[Dict[str, Any], None, None]:
        """
        Read and collect filtered and transformed records without sampling.

        This method is similar to _read_and_process_file but skips the sampling
        decision. It's used in the first pass of stratified sampling to collect
        all eligible records before shuffling and sampling.

        Args:
            bucket: S3 bucket name containing the file
            file_key: S3 object key (path) of the JSONL.bz2 file to process

        Yields:
            Dict[str, Any]: Filtered and transformed records ready for sampling
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
                        record = json.loads(line)
                        self.total_processed += 1

                        record_id = self._get_record_id(record)
                        log.debug(f"Processing record {record_id} (line {line_num})")

                        # Apply filter
                        if not self._apply_filter(record):
                            log.debug(f"Record {record_id} filtered out")
                            continue

                        log.debug(f"Record {record_id} passed filter")

                        # Apply transformation
                        transformed_record = self._apply_transform(record)
                        if transformed_record is not None:
                            log.debug(
                                f"Record {record_id} successfully transformed "
                                "and collected for sampling"
                            )
                            yield transformed_record
                        else:
                            log.debug(
                                f"Record {record_id} transformation failed, "
                                "skipping from collection"
                            )

                    except json.JSONDecodeError:
                        log.warning(f"Skipping malformed line {line_num} in {file_key}")
                    except Exception as e:
                        log.error(
                            f"Error processing line {line_num} in {file_key}: {e}"
                        )

        except Exception as e:
            log.error(f"Failed to open or read file {file_key}: {e}")

    def _upload_to_s3(self, local_path: str, s3_path: str) -> None:
        """
        Upload a local file to S3.

        This method uploads a local file to an S3 location using the configured S3
        client. It uses the parse_s3_path utility to extract bucket and key from the
        S3 path, then performs the upload operation.

        Args:
            local_path: Full path to the local file to upload
            s3_path: S3 destination path in format 's3://bucket/key'

        Side Effects:
            - Uploads file to S3
            - Logs successful upload with paths

        Raises:
            Exception: If S3 upload fails (propagated from boto3)

        Examples:
            >>> processor._upload_to_s3("/tmp/sample.jsonl", "s3://bucket/output.jsonl")
            # Logs: "Uploaded /tmp/sample.jsonl to s3://bucket/output.jsonl"
        """
        bucket, key = parse_s3_path(s3_path)
        self.s3_client.upload_file(local_path, bucket, key)
        log.info(f"Uploaded {local_path} to {s3_path}")

    def run(self) -> None:
        """
        Execute the complete sampling process from S3 input to output.

        This is the main orchestrator method that coordinates all sampling operations.
        It handles the entire pipeline from reading S3 files through final output,
        including temporary file management, progress logging, and error handling.

        Processing Workflow:
        For stratified sampling (max_samples_per_group):
        1. First pass: collect all filtered and transformed records
        2. Shuffle records randomly to eliminate ordering bias
        3. Second pass: apply stratified sampling to shuffled data

        For random sampling (sampling_rate):
        1. Process files sequentially with direct sampling

        Output Handling:
        - Local paths: Uses shutil.move for efficient file transfer
        - S3 paths: Uploads using boto3 S3 client
        - Maintains original file permissions and metadata where possible

        Statistics and Monitoring:
        - Tracks total files processed
        - Counts total records processed vs. sampled
        - Reports sampling ratios and group distributions
        - Logs progress information for long-running operations

        Error Handling:
        - Catches and logs all exceptions with full tracebacks
        - Exits with status code 1 on any processing errors
        - Ensures cleanup of temporary files on failure
        - Provides detailed error context for debugging

        Side Effects:
        - Creates and manages temporary files in system temp directory
        - Updates all instance counters and statistics
        - Writes final output to specified location
        - Logs comprehensive processing statistics

        Raises:
            SystemExit: Exits with code 1 if any processing errors occur

        Examples:
            >>> processor = S3SamplerProcessor(...)
            >>> processor.run()
            # Logs: "Starting sampling from s3://bucket/prefix"
            # Logs: "Processing file: data1.jsonl.bz2"
            # Logs: "File data1.jsonl.bz2: sampled 150 records"
            # Logs: "Processing complete: 1500 records sampled from 10000 processed"
        """
        try:
            log.info(f"Starting sampling from {self.s3_prefix}")

            bucket, prefix = parse_s3_path(self.s3_prefix)

            # Create temporary file for output
            suffix = self.output_file.split(".")[-1]
            with tempfile.NamedTemporaryFile(
                delete=False, mode="w", encoding="utf-8", suffix=f".{suffix}"
            ) as tmpfile:
                tmpfile_path = tmpfile.name
                log.info(f"Temporary file created: {tmpfile_path}")

                if self.max_samples_per_group is not None:
                    # Two-pass strategy for stratified sampling
                    self._run_stratified_sampling(bucket, prefix, tmpfile_path)
                else:
                    # Single-pass strategy for random sampling
                    self._run_random_sampling(bucket, prefix, tmpfile_path)

                # Upload to S3 or move to final location
                if self.output_file.startswith("s3://"):
                    self._upload_to_s3(tmpfile_path, self.output_file)
                else:
                    import shutil

                    shutil.move(tmpfile_path, self.output_file)
                    log.info(f"Moved {tmpfile_path} to {self.output_file}")

            # Log summary statistics
            log.info("Processing complete:")
            log.info(f"  Total records processed: {self.total_processed}")
            log.info(f"  Total records sampled: {self.total_sampled}")

            if self.max_samples_per_group is not None:
                log.info(f"  Groups sampled: {len(self.group_sample_counts)}")
                for group_id, count in sorted(self.group_sample_counts.items()):
                    log.info(f"    {group_id}: {count} samples")

            if self.total_processed > 0:
                sampling_ratio = self.total_sampled / self.total_processed
                log.info(f"  Effective sampling ratio: {sampling_ratio:.4f}")

            log.info(f"Results saved to {self.output_file}")

        except Exception as e:
            log.error(f"Error during sampling process: {e}", exc_info=True)
            sys.exit(1)


def main(args: Optional[List[str]] = None) -> None:
    """
    Main function to run the S3 Sampler Processor.

    This function serves as the primary entry point for the S3 sampling tool. It handles
    argument parsing, processor initialization, and execution coordination. The function
    is designed to be called both from the command line and programmatically.

    Workflow:
    1. Parses command-line arguments using parse_arguments()
    2. Creates S3SamplerProcessor instance with parsed options
    3. Configures logging after processor initialization
    4. Logs the parsed configuration for debugging
    5. Executes the sampling process via processor.run()

    Error Handling:
    - Invalid arguments cause argparse to exit with usage message
    - Configuration errors in processor initialization cause sys.exit(1)
    - Processing errors are handled by the processor's run() method

    Args:
        args: Command-line arguments (uses sys.argv if None). Useful for testing
              and programmatic invocation with custom arguments.

    Examples:
        Command-line usage:
        >>> main()  # Uses sys.argv

        Programmatic usage:
        >>> main(['--s3-prefix', 's3://bucket/data', '--output', 'sample.jsonl',
        ...       '--sampling-rate', '0.1'])

        Testing usage:
        >>> test_args = ['--s3-prefix', 's3://test/data', '--output', 'test.jsonl',
        ...              '--sampling-rate', '0.05', '--log-level', 'DEBUG']
        >>> main(test_args)
    """
    options: argparse.Namespace = parse_arguments(args)

    processor: S3SamplerProcessor = S3SamplerProcessor(
        s3_prefix=options.s3_prefix,
        output_file=options.output,
        sampling_rate=options.sampling_rate,
        max_samples_per_group=options.max_samples_per_group,
        group_by_expr=options.group_by_expr,
        random_seed=options.random_seed,
        filter_expr=options.filter_expr,
        filter_file=options.filter_file,
        transform_expr=options.transform_expr,
        transform_file=options.transform_file,
        record_id_field=options.record_id_field,
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
