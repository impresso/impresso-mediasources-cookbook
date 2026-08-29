#!/usr/bin/env python3
"""
List newspapers from an S3 bucket with optional size-aware ordering.

This script connects to an S3-compatible endpoint (default: Switch cloud) and lists
top-level newspaper prefixes from a specified bucket. It can optionally group newspapers
by the number of available years and order them from largest to smallest groups.

Features:
- Loads credentials from environment variables (SE_ACCESS_KEY, SE_SECRET_KEY) or .env file
- Lists newspaper identifiers as space-separated output (compatible with Makefile usage)
- Counts years per newspaper by scanning for files matching pattern: NEWSPAPER-YYYY.jsonl.bz2
- Optional size-aware grouping with configurable number of groups
- Randomization within groups for load balancing
- Pattern filtering: --prefix is stripped before --fnmatch is applied to newspaper names

Grouping behavior (--large-first):
- Newspapers are grouped by number of available years using logarithmic thresholds
- Groups are ordered from largest to smallest (e.g., newspapers with most years first)
- Within each group, newspapers are randomly shuffled
- Number of groups is configurable via --num-groups (default: 3)

Examples:
  # Simple random shuffle of all newspapers
  python list_newspapers.py --bucket 22-rebuilt-final

  # Group into 3 size categories, largest first
  python list_newspapers.py --bucket 22-rebuilt-final --large-first --seed 42

  # Group into 5 size categories with custom endpoint
  python list_newspapers.py --bucket my-bucket --large-first --num-groups 5 \\
    --endpoint https://my-s3.example.com/

  # Debug mode with detailed grouping information
  python list_newspapers.py --bucket 22-rebuilt-final --large-first \\
    --log-level DEBUG --num-groups 4

  # Filter newspapers matching a pattern (matches newspaper name only)
  python list_newspapers.py --bucket 22-rebuilt-final --fnmatch 'GDL*'

  # Filter with wildcards (e.g., all newspapers starting with 'luxwort')
  python list_newspapers.py --bucket 22-rebuilt-final --fnmatch 'luxwort*'

  # With --has-provider, fnmatch matches 'provider/newspaper' format (prefix excluded)
  python list_newspapers.py --bucket 22-rebuilt-final --has-provider \\
    --prefix 'data/' --fnmatch 'NZZ/*'
"""

import argparse
import fnmatch
import logging
import math
import random
import re
import sys
import time
from pathlib import Path
from typing import Dict, Iterable, List, Optional

from botocore.client import BaseClient

from common import get_s3_client, setup_logging, yield_s3_objects

log = logging.getLogger(__name__)

DEFAULT_ENDPOINT = "https://os.zhdk.cloud.switch.ch/"
# Compile regex patterns once at module level for better performance
# Updated regex patterns to match the actual file schemas
# Schema A: PROVIDER/NEWSPAPER/issues/NEWSPAPER-YEAR-issues.jsonl.bz2 (with provider)
ISSUES_YEAR_RE = re.compile(r".*/([A-Za-z0-9_]+)/issues/\1-(\d{4})-issues\.jsonl\.bz2$")
# Schema B: PROVIDER/NEWSPAPER/NEWSPAPER-YEAR.jsonl.bz2 (with provider)
DIRECT_YEAR_RE = re.compile(r".*/([A-Za-z0-9_]+)/\1-(\d{4})\.jsonl\.bz2$")
# Schema C: NEWSPAPER/NEWSPAPER-YEAR.jsonl.bz2 (no provider, direct newspaper folder)
NO_PROVIDER_DIRECT_RE = re.compile(r"([A-Za-z0-9_]+)/\1-(\d{4})\.jsonl\.bz2$")
# Schema D: NEWSPAPER/issues/NEWSPAPER-YEAR-issues.jsonl.bz2 (no provider, with issues)
NO_PROVIDER_ISSUES_RE = re.compile(
    r"([A-Za-z0-9_]+)/issues/\1-(\d{4})-issues\.jsonl\.bz2$"
)


def parse_arguments(args: Optional[List[str]] = None) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="List newspapers from S3 with optional size-aware shuffling."
    )
    parser.add_argument(
        "--output-file",
        dest="output_file",
        help="Write the newspaper list to FILE instead of stdout",
        metavar="FILE",
    )
    parser.add_argument(
        "--log-file", dest="log_file", help="Write log to FILE", metavar="FILE"
    )
    parser.add_argument(
        "--log-level",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        default="INFO",
        help="Logging level (default: %(default)s)",
    )
    parser.add_argument(
        "--bucket", required=True, help="S3 bucket name (e.g., 22-rebuilt-final)"
    )
    parser.add_argument(
        "--prefix",
        default="",
        help=(
            "Optional root prefix under the bucket, stripped before matching (default:"
            " empty)"
        ),
    )
    parser.add_argument(
        "--endpoint",
        default=DEFAULT_ENDPOINT,
        help=f"S3 endpoint URL (default: {DEFAULT_ENDPOINT})",
    )
    parser.add_argument(
        "--large-first",
        action="store_true",
        help="Shuffle within size groups (large→medium→small)",
    )
    parser.add_argument(
        "--num-groups",
        type=int,
        default=3,
        help="Number of size groups when using --large-first (default: %(default)s)",
    )
    parser.add_argument(
        "--has-provider",
        action="store_true",
        help="Newspapers are organized as PROVIDER/newspaper-year.jsonl.bz2",
    )
    parser.add_argument(
        "--seed", type=int, default=None, help="Random seed for reproducibility"
    )
    parser.add_argument(
        "--fnmatch",
        default=None,
        help=(
            "Pattern to filter newspaper names only, excluding prefix (e.g., 'GDL*',"
            " '*wort*')"
        ),
    )
    return parser.parse_args(args)


class NewspaperLister:
    """
    A processor class that lists newspapers from S3 with optional size-aware ordering.

    This class follows the CLI template pattern for the Impresso project, providing
    consistent logging, S3 integration, and error handling. It discovers newspaper
    identifiers from S3 bucket structure and optionally orders them by size.
    """

    def __init__(
        self,
        bucket: str,
        prefix: str = "",
        endpoint: str = DEFAULT_ENDPOINT,
        large_first: bool = False,
        num_groups: int = 3,
        has_provider: bool = False,
        seed: Optional[int] = None,
        log_level: str = "INFO",
        log_file: Optional[str] = None,
        output_file: Optional[str] = None,
        fnmatch_pattern: Optional[str] = None,
    ) -> None:
        """Initialize the NewspaperLister with configuration parameters."""
        self.bucket = bucket
        self.prefix = prefix
        self.endpoint = endpoint
        self.large_first = large_first
        self.num_groups = max(1, num_groups)  # Ensure num_groups is at least 1
        self.has_provider = has_provider
        self.seed = seed
        self.log_level = log_level
        self.log_file = log_file
        self.output_file = output_file
        self.fnmatch_pattern = fnmatch_pattern

        # Configure the module-specific logger
        setup_logging(self.log_level, self.log_file, logger=log)

        # Initialize S3 client and random number generator
        self.s3_client = get_s3_client()
        self.rng = random.Random(self.seed)

    def extract_year_from_object(
        self, obj_key: str, has_provider: bool = True
    ) -> Optional[int]:
        """Extract year from a single object key, optimized for performance."""
        if has_provider:
            # Try Schema A first (issues format) as it's more specific
            m = ISSUES_YEAR_RE.search(obj_key)
            if m:
                year = int(m.group(2))
                if 1500 <= year <= 2100:
                    log.debug(
                        "Found year %d in provider issues file: %s", year, obj_key
                    )
                    return year
                return None

            # Try Schema B (direct format)
            m = DIRECT_YEAR_RE.search(obj_key)
            if m:
                year = int(m.group(2))
                if 1500 <= year <= 2100:
                    log.debug(
                        "Found year %d in provider direct file: %s", year, obj_key
                    )
                    return year
                return None
        else:
            # No provider patterns - try issues first as it's more specific
            m = NO_PROVIDER_ISSUES_RE.search(obj_key)
            if m:
                year = int(m.group(2))
                if 1500 <= year <= 2100:
                    log.debug(
                        "Found year %d in no-provider issues file: %s", year, obj_key
                    )
                    return year
                return None

            # Try no-provider direct format
            m = NO_PROVIDER_DIRECT_RE.search(obj_key)
            if m:
                year = int(m.group(2))
                if 1500 <= year <= 2100:
                    log.debug(
                        "Found year %d in no-provider direct file: %s", year, obj_key
                    )
                    return year
                return None

        return None

    def list_common_prefixes(self, prefix: str = "", delimiter: str = "/") -> List[str]:
        """List immediate child 'directories' (CommonPrefixes) under the given prefix."""
        prefixes: List[str] = []
        kwargs = {"Bucket": self.bucket, "Delimiter": delimiter}
        if prefix:
            kwargs["Prefix"] = prefix

        while True:
            resp = self.s3_client.list_objects_v2(**kwargs)
            prefixes.extend(p["Prefix"] for p in resp.get("CommonPrefixes", []))
            if not resp.get("IsTruncated"):
                break
            kwargs["ContinuationToken"] = resp.get("NextContinuationToken")
        return prefixes

    def extract_years_from_objects(self, objects: Iterable[str]) -> List[int]:
        """Extract 4-digit years from a list of S3 object keys (files)."""
        years: List[int] = []

        for obj_key in objects:
            year_found = None

            # Try Schema A: issues format
            m = ISSUES_YEAR_RE.search(obj_key)
            if m:
                year_found = int(m.group(2))
                log.debug("Found year %d in issues file: %s", year_found, obj_key)
            else:
                # Try Schema B: direct format
                m = DIRECT_YEAR_RE.search(obj_key)
                if m:
                    year_found = int(m.group(2))
                    log.debug("Found year %d in direct file: %s", year_found, obj_key)

            if year_found and 1500 <= year_found <= 2100:
                years.append(year_found)
            elif year_found:
                log.debug(
                    "Year %d outside valid range, ignoring: %s", year_found, obj_key
                )

        return years

    def count_year_files(self, newspaper_prefix: str) -> int:
        """Count files that look like newspaper-year.jsonl.bz2 under a newspaper."""
        # Use set for O(1) lookups instead of list
        years: set[int] = set()
        object_count = 0
        jsonl_bz2_count = 0
        sample_objects: List[str] = []

        # Schema detection - determine from first matching file
        detected_schema = (
            None  # 'issues', 'direct', 'no_provider_issues', 'no_provider_direct'
        )

        log.debug("Searching for files under prefix: %s", newspaper_prefix)

        try:
            for obj_key in yield_s3_objects(self.bucket, newspaper_prefix):
                object_count += 1

                # Early filter for .jsonl.bz2 extension
                if not obj_key.endswith(".jsonl.bz2"):
                    continue

                jsonl_bz2_count += 1

                # Collect limited samples for debugging
                if len(sample_objects) < 5:  # Reduced sample size
                    sample_objects.append(obj_key)

                # Schema detection and year extraction
                year = None

                if detected_schema is None:
                    # Try to detect schema from first file
                    if self.has_provider:
                        if ISSUES_YEAR_RE.search(obj_key):
                            detected_schema = "issues"
                            log.debug("Detected 'issues' schema from file: %s", obj_key)
                        elif DIRECT_YEAR_RE.search(obj_key):
                            detected_schema = "direct"
                            log.debug("Detected 'direct' schema from file: %s", obj_key)
                    else:
                        if NO_PROVIDER_ISSUES_RE.search(obj_key):
                            detected_schema = "no_provider_issues"
                            log.debug(
                                "Detected 'no_provider_issues' schema from file: %s",
                                obj_key,
                            )
                        elif NO_PROVIDER_DIRECT_RE.search(obj_key):
                            detected_schema = "no_provider_direct"
                            log.debug(
                                "Detected 'no_provider_direct' schema from file: %s",
                                obj_key,
                            )

                # Apply detected schema for faster processing
                if detected_schema == "issues":
                    m = ISSUES_YEAR_RE.search(obj_key)
                    if m:
                        year = int(m.group(2))
                elif detected_schema == "direct":
                    m = DIRECT_YEAR_RE.search(obj_key)
                    if m:
                        year = int(m.group(2))
                elif detected_schema == "no_provider_issues":
                    m = NO_PROVIDER_ISSUES_RE.search(obj_key)
                    if m:
                        year = int(m.group(2))
                elif detected_schema == "no_provider_direct":
                    m = NO_PROVIDER_DIRECT_RE.search(obj_key)
                    if m:
                        year = int(m.group(2))
                else:
                    # Fallback: try all patterns if schema not yet detected
                    year = self.extract_year_from_object(obj_key, self.has_provider)

                # Validate and add year
                if year and 1500 <= year <= 2100:
                    years.add(year)
                    log.debug(
                        "Found year %d in %s file: %s",
                        year,
                        detected_schema or "unknown",
                        obj_key,
                    )

        except Exception as e:
            log.error("Error listing objects for %s: %s", newspaper_prefix, e)
            return 0

        log.debug(
            "Found %d total objects, %d .jsonl.bz2 objects, %d unique years"
            " (schema: %s)",
            object_count,
            jsonl_bz2_count,
            len(years),
            detected_schema or "none",
        )

        if log.isEnabledFor(logging.DEBUG):
            log.debug("Sample .jsonl.bz2 objects: %s", sample_objects)
            log.debug("Years found: %s", sorted(years))

        # Improved diagnostics
        if jsonl_bz2_count == 0:
            log.warning("No .jsonl.bz2 objects found under prefix %s", newspaper_prefix)
        elif len(years) == 0 and jsonl_bz2_count > 0:
            log.warning(
                "Found %d .jsonl.bz2 objects under %s but none matched year pattern"
                " (detected schema: %s)",
                jsonl_bz2_count,
                newspaper_prefix,
                detected_schema or "none",
            )
            # Show pattern analysis for first few files
            for obj in sample_objects[:3]:
                log.warning("Pattern analysis for %s:", obj)
                if self.has_provider:
                    log.warning("  Issues match: %s", bool(ISSUES_YEAR_RE.search(obj)))
                    log.warning("  Direct match: %s", bool(DIRECT_YEAR_RE.search(obj)))
                else:
                    log.warning(
                        "  No-provider issues match: %s",
                        bool(NO_PROVIDER_ISSUES_RE.search(obj)),
                    )
                    log.warning(
                        "  No-provider direct match: %s",
                        bool(NO_PROVIDER_DIRECT_RE.search(obj)),
                    )

        return len(years)

    def discover_newspapers(self) -> List[str]:
        """Discover newspaper identifiers from S3 bucket structure."""
        log.info("Connected to S3 endpoint: %s", self.endpoint)

        if self.has_provider:
            # First, list provider prefixes
            provider_prefixes = self.list_common_prefixes(
                prefix=self.prefix, delimiter="/"
            )
            log.info(
                "Found %d provider prefixes in bucket %s",
                len(provider_prefixes),
                self.bucket,
            )
            log.debug("Provider prefixes: %s", provider_prefixes[:10])

            # Then list newspapers under each provider
            newspapers: List[str] = []
            for provider_prefix in provider_prefixes:
                log.debug("Examining provider prefix: %s", provider_prefix)

                newspaper_prefixes = self.list_common_prefixes(
                    prefix=provider_prefix, delimiter="/"
                )
                log.debug(
                    "Newspaper prefixes under %s: %s",
                    provider_prefix,
                    newspaper_prefixes,
                )

                for np_prefix in newspaper_prefixes:
                    # Extract provider/newspaper format
                    leaf = (
                        np_prefix[len(self.prefix) :]
                        if self.prefix and np_prefix.startswith(self.prefix)
                        else np_prefix
                    )
                    leaf = leaf[:-1] if leaf.endswith("/") else leaf
                    if leaf and "/" in leaf:  # Ensure we have provider/newspaper format
                        newspapers.append(leaf)
                        log.debug(
                            "Added newspaper: %s (from prefix: %s)", leaf, np_prefix
                        )
        else:
            # Original logic for newspapers without providers
            root_prefixes = self.list_common_prefixes(prefix=self.prefix, delimiter="/")
            log.info(
                "Found %d top-level prefixes in bucket %s",
                len(root_prefixes),
                self.bucket,
            )

            newspapers: List[str] = []
            for p in root_prefixes:
                leaf = (
                    p[len(self.prefix) :]
                    if self.prefix and p.startswith(self.prefix)
                    else p
                )
                leaf = leaf[:-1] if leaf.endswith("/") else leaf
                if leaf:  # avoid empty strings
                    newspapers.append(leaf)

        log.info(
            "Extracted %d newspaper identifiers: %s",
            len(newspapers),
            "… ".join(newspapers[::10]) if len(newspapers) > 10 else [],
        )

        # Apply fnmatch filtering if pattern is provided
        # Note: newspapers list contains names with prefix already stripped,
        # so fnmatch matches against newspaper names only (e.g., 'GDL' or 'NZZ/newspaper')
        if self.fnmatch_pattern:
            original_count = len(newspapers)
            newspapers = [
                n for n in newspapers if fnmatch.fnmatch(n, self.fnmatch_pattern)
            ]
            log.info(
                "Applied fnmatch pattern '%s': %d/%d newspapers match",
                self.fnmatch_pattern,
                len(newspapers),
                original_count,
            )

        return newspapers

    def count_years_per_newspaper(self, newspapers: List[str]) -> Dict[str, int]:
        """Count years available for each newspaper with progress tracking."""
        years_per_np: Dict[str, int] = {}
        total_newspapers = len(newspapers)

        log.info("Counting years for %d newspapers...", total_newspapers)

        for i, n in enumerate(newspapers, 1):
            np_prefix = f"{self.prefix}{n}/" if self.prefix else f"{n}/"

            # Progress logging for large datasets
            if total_newspapers > 50 and i % 20 == 0:
                log.info("Progress: %d/%d newspapers processed", i, total_newspapers)

            log.debug("Processing newspaper %s with prefix %s", n, np_prefix)

            try:
                year_count = self.count_year_files(np_prefix)
                years_per_np[n] = year_count

                if year_count > 0:
                    log.info("Newspaper %s: %d years", n, year_count)
                else:
                    log.warning("Newspaper %s: 0 years", n)

            except Exception as e:
                log.error("Failed to count years for %s: %s", n, e)
                years_per_np[n] = 0

        # Summary statistics
        total_years = sum(years_per_np.values())
        newspapers_with_data = sum(1 for count in years_per_np.values() if count > 0)
        avg_years = (
            total_years / newspapers_with_data if newspapers_with_data > 0 else 0
        )

        log.info(
            "Summary: %d newspapers total, %d with data (%.1f%%), %d total years, %.1f"
            " avg years",
            len(newspapers),
            newspapers_with_data,
            100 * newspapers_with_data / len(newspapers) if newspapers else 0,
            total_years,
            avg_years,
        )

        if newspapers_with_data == 0:
            log.error(
                "No newspapers found with any year data! Check file patterns and S3"
                " structure."
            )

        return years_per_np

    def compute_group_thresholds(self, counts: List[int]) -> List[int]:
        """Compute log-spaced thresholds to split counts into num_groups groups."""
        if not counts or self.num_groups <= 1:
            return []

        min_count = min(counts)
        max_count = max(counts)
        if min_count == max_count:
            return []

        min_shifted = min_count + 1
        max_shifted = max_count + 1
        log_min = math.log(min_shifted)
        log_max = math.log(max_shifted)
        thresholds: List[int] = []

        for i in range(1, self.num_groups):
            fraction = i / self.num_groups
            raw_threshold = math.exp(log_min + (log_max - log_min) * fraction) - 1
            threshold = max(min_count, min(max_count, int(round(raw_threshold))))
            if thresholds and threshold <= thresholds[-1]:
                threshold = min(max_count, thresholds[-1] + 1)
            thresholds.append(threshold)

        while thresholds and thresholds[-1] >= max_count:
            thresholds.pop()

        return thresholds

    def order_newspapers(
        self, newspapers: List[str], years_per_np: Dict[str, int]
    ) -> List[str]:
        """Order newspapers based on configuration (random or size-grouped)."""
        if not self.large_first:
            shuffled = newspapers[:]
            self.rng.shuffle(shuffled)
            return shuffled

        # Group by size using quantiles
        counts = [years_per_np.get(n, 0) for n in newspapers]
        thresholds = self.compute_group_thresholds(counts)

        # Create groups (largest to smallest)
        groups: List[List[str]] = [[] for _ in range(self.num_groups)]

        for n in newspapers:
            c = years_per_np.get(n, 0)
            group_idx = self.num_groups - 1  # Default to largest group

            # Find which group this newspaper belongs to
            for i, threshold in enumerate(thresholds):
                if c <= threshold:
                    group_idx = i
                    break

            groups[group_idx].append(n)

        # Shuffle within each group and concatenate (largest first)
        result = []
        for group in reversed(groups):  # Reverse to get largest first
            self.rng.shuffle(group)
            result.extend(group)

        return result

    def log_grouping_diagnostics(
        self, newspapers: List[str], years_per_np: Dict[str, int]
    ) -> None:
        """Log detailed grouping diagnostics when large_first is enabled."""
        if not self.large_first:
            return

        counts = [years_per_np.get(n, 0) for n in newspapers]
        thresholds = self.compute_group_thresholds(counts)
        log.info(
            "Year count distribution: min=%d, max=%d, thresholds=%s",
            min(counts) if counts else 0,
            max(counts) if counts else 0,
            thresholds,
        )

        # Count newspapers in each group for diagnostics
        groups: List[List[str]] = [[] for _ in range(self.num_groups)]
        for n in newspapers:
            c = years_per_np.get(n, 0)
            group_idx = self.num_groups - 1
            for i, threshold in enumerate(thresholds):
                if c <= threshold:
                    group_idx = i
                    break
            groups[group_idx].append(n)

        for i, group in enumerate(groups):
            group_name = (
                f"Group {i+1}" if i < self.num_groups - 1 else f"Group {i+1} (largest)"
            )
            if thresholds:
                if i == 0:
                    range_desc = f"≤{thresholds[0]} years"
                elif i == len(thresholds):
                    range_desc = f">{thresholds[-1]} years"
                else:
                    range_desc = f"{thresholds[i-1]+1}-{thresholds[i]} years"
            else:
                range_desc = "all years"
            log.info(
                "%s (%s): %d newspapers: %s",
                group_name,
                range_desc,
                len(group),
                group,
            )

    def run(self) -> None:
        """Main processing logic to discover, count, and order newspapers."""
        start_time = time.time()

        try:
            if self.log_file:
                log.info("Writing execution log to %s", self.log_file)

            if self.output_file:
                log.info("Writing newspaper list to %s", self.output_file)
            else:
                log.info("Writing newspaper list to stdout")

            # Discover newspapers from S3 structure
            log.info("Starting newspaper discovery...")
            newspapers = self.discover_newspapers()

            if not newspapers:
                log.warning("No newspapers found")
                self.write_output([])
                return

            # Count years for each newspaper
            log.info("Starting year counting for %d newspapers...", len(newspapers))
            years_per_np = self.count_years_per_newspaper(newspapers)

            # Log grouping diagnostics if enabled
            if self.large_first:
                log.info("Computing size-based groupings...")
                self.log_grouping_diagnostics(newspapers, years_per_np)

            # Order newspapers based on configuration
            log.info("Ordering newspapers...")
            ordered = self.order_newspapers(newspapers, years_per_np)

            elapsed_time = time.time() - start_time
            log.info("Processing completed in %.2f seconds", elapsed_time)
            log.info(
                "Final order (%d newspapers): %s",
                len(ordered),
                ordered if len(ordered) <= 20 else ordered[:20] + ["..."],
            )

            self.write_output(ordered)

        except Exception as e:
            log.error("Error during processing: %s", e, exc_info=True)
            sys.exit(1)

    def write_output(self, newspapers: List[str]) -> None:
        """Write the resulting newspaper list to the configured destination."""
        output = " ".join(newspapers)

        if self.output_file:
            output_path = Path(self.output_file)
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(output, encoding="utf-8")
            log.info("Wrote %d newspapers to %s", len(newspapers), self.output_file)
            return

        print(output, end="")


def main(args: Optional[List[str]] = None) -> None:
    """Main function to run the Newspaper Lister."""
    options: argparse.Namespace = parse_arguments(args)

    if options.num_groups < 1:
        log.error("--num-groups must be at least 1")
        sys.exit(1)

    processor: NewspaperLister = NewspaperLister(
        bucket=options.bucket,
        prefix=options.prefix,
        endpoint=options.endpoint,
        large_first=options.large_first,
        num_groups=options.num_groups,
        has_provider=options.has_provider,
        seed=options.seed,
        log_level=options.log_level,
        log_file=options.log_file,
        output_file=options.output_file,
        fnmatch_pattern=options.fnmatch,
    )

    log.info("Configuration: %s", options)

    processor.run()


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        log.error("Processing error: %s", e, exc_info=True)
        sys.exit(2)
