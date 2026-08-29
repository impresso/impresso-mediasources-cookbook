"""
This module, `s3_to_local_stamps.py`, is a utility for creating local stamp files that
mirror the structure of specified S3 objects.

The main class, `LocalStampCreator`, orchestrates the process of creating these stamp
files. It uses the boto3 library to interact with the S3 service and the os library to
create local directories and files.

The module uses environment variables to configure the S3 resource object. These
variables include the access key, secret key, and host URL for the S3 service.

The module can be run as a standalone script. It accepts command-line arguments for the
S3 bucket name, file prefix to match in the bucket, verbosity level for logging, and an
optional log-file.
"""

__author__ = "simon.clematide@uzh.ch"
__license__ = "GNU GPL 3.0 or later"

import argparse
import bz2
import datetime
import fnmatch
import logging
import os
import sys
import time
import traceback
from datetime import datetime, timedelta
from typing import Optional, Any

import boto3
from botocore.exceptions import ClientError

import smart_open  # type: ignore
from dotenv import load_dotenv
from impresso_cookbook import (
    get_s3_client,
    parse_s3_path,
    upload_file_to_s3,
    get_s3_resource,
    download_with_retries,
    upload_with_retries,
    setup_logging,
)

load_dotenv()
log = logging.getLogger(__name__)

SCHEMA_BASE_URI = "https://impresso.github.io/impresso-schemas/json/"


def get_last_modified(response: Any) -> datetime:
    """
    Extracts the last modified timestamp from an S3 response.

    Args:
        response: The S3 response object.

    Returns:
        datetime: The last modified timestamp.
    """
    if "Metadata" in response:
        metadata = response["Metadata"]
        if "impresso-last-ts" in metadata:
            last_ts = metadata["impresso-last-ts"]
            log.debug("Using impresso-last-ts from metadata: %s", last_ts)
            return datetime.fromisoformat(last_ts)
    if "LastModified" in response:
        log.debug("Using LastModified from response: %s", response["LastModified"])
        return response["LastModified"]
    else:
        log.warning("No LastModified field found in the S3 response.")
        return datetime.now()  # Fallback to current time if not found


class S3Compressor:
    def __init__(
        self,
        s3_path: str,
        local_path: Optional[str] = None,
        new_s3_path: Optional[str] = None,
        new_bucket: Optional[str] = None,
        strip_local_extension: Optional[str] = None,
        s3_client: Any = None,
    ):
        self.s3_path = s3_path
        self.local_path = local_path
        self.new_s3_path = new_s3_path
        self.new_bucket = new_bucket
        self.strip_local_extension = strip_local_extension
        self.s3_client = s3_client or get_s3_client()

    def compress_and_upload(self) -> None:
        """
        Downloads an S3 file, compresses it as bz2, uploads it under the same name, and verifies the MD5 checksum.
        """
        if self.new_s3_path:
            compressed_bucket, compressed_key = parse_s3_path(self.new_s3_path)
        else:
            compressed_bucket, compressed_key = parse_s3_path(self.s3_path)

        if self.local_path is None:
            if self.strip_local_extension is not None:
                if self.s3_path.endswith(self.strip_local_extension):
                    self.local_path = self.s3_path[5:][
                        : -len(self.strip_local_extension)
                    ]
                else:
                    log.error(
                        "The s3_path %s does not end with the specified extension: %s",
                        self.s3_path,
                        self.strip_local_extension,
                    )
                    sys.exit(1)
            else:
                self.local_path = self.s3_path[5:]

        if self.new_s3_path is None:
            if self.new_bucket is None:
                self.new_s3_path = self.s3_path
                log.warning(
                    "Overwriting the original file %s. Taking care to not overwrite the"
                    " original file in case of network problems.",
                    self.s3_path,
                )
            else:
                compressed_bucket = self.new_bucket
        else:
            if self.new_bucket is None:
                compressed_bucket, compressed_key = parse_s3_path(self.new_s3_path)
            else:
                log.warning("Specifying s3_path and bucket is invalid")
                sys.exit(2)
        log.warning(
            f"Compressing {self.s3_path} to {compressed_bucket}/{compressed_key}"
        )

        compressed_local_path = self.local_path + ".bz2"

        # Download the file from S3
        result = download_with_retries(self.s3_client, self.s3_path, self.local_path)
        if not result:
            log.error(
                "Failed to download %s after multiple attempts. Aborting compression.",
                self.s3_path,
            )
            return
        log.warning("Downloaded %s to %s", self.s3_path, self.local_path)
        # Check if the file is already compressed
        try:
            with bz2.open(self.local_path, "rb") as test_file:
                test_file.read(1)
            log.warning(
                f"The file {self.local_path} is already compressed. Removing local"
                " file %s",
                self.local_path,
            )
            os.remove(self.local_path)
            return
        except OSError:
            log.warning(
                f"The file {self.local_path} is not compressed. Proceeding with"
                " compression.",
            )

        # Compress the file
        with open(self.local_path, "rb") as input_file:
            with bz2.open(compressed_local_path, "wb") as output_file:
                output_file.write(input_file.read())
            log.warning("Compressed %s to %s", self.local_path, compressed_local_path)

        # Upload the compressed file to S3 (overwriting the existing file)
        result = upload_with_retries(
            self.s3_client, compressed_local_path, self.new_s3_path
        )
        if not result:
            log.error(
                "Failed to upload %s to %s after multiple attempts.",
                compressed_local_path,
                self.new_s3_path,
            )

        # Clean up local files
        os.remove(self.local_path)
        os.remove(compressed_local_path)


class LocalStampCreator(object):
    """Main application for creating local stamp files mirroring S3 objects.

    Attributes:
        args (Any): Command-line arguments object.
        s3_resource (boto3.resources.factory.s3.ServiceResource): The S3 service
            resource.

    Methods:
        run(): Orchestrates the stamp file creation process.

        create_stamp_files(bucket_name: str, prefix: str): Creates local stamp files
            based on S3 objects.

        create_local_stamp_file(s3_key: str, last_modified: datetime.datetime): Creates
            a single local stamp file.
    """

    def __init__(self, args: argparse.Namespace):
        """Initializes the application with command-line arguments.

        Args:
            args: Command-line arguments.
        """

        self.args = args
        self.s3_resource = get_s3_resource()
        self.stats = {
            "files_created": 0,
            "files_unchanged": 0,
            "files_removed": 0,
        }  # Initialize the statistics dictionary
        # Splitting the s3-path into bucket name and prefix
        self.bucket_name, self.prefix = parse_s3_path(self.args.s3_path)

    def run(self) -> None:
        """Orchestrates the stamp file creation process or uploads a file to S3."""
        if self.args.upload_file:
            if not self.args.s3_path:
                log.error(
                    "When using --upload-file, you must specify the s3_path as the"
                    " destination."
                )
                sys.exit(1)
            upload_file_to_s3(
                get_s3_client(),
                self.args.upload_file,
                self.args.s3_path,
                self.args.force_overwrite,
            )
            sys.exit(0)
        elif self.args.list_files:
            bucket = self.s3_resource.Bucket(self.bucket_name)
            glob = self.args.list_files_glob or None

            for obj in bucket.objects.filter(Prefix=self.prefix):
                if glob:
                    if not fnmatch.fnmatch(obj.key, glob):
                        continue
                print(f"s3://{self.bucket_name}/{obj.key}")
            sys.exit(0)
        elif self.args.s3_path:
            log.info("Starting stamp file creation...")
            if self.args.stamp_mode == "per-file":
                log.info("Using per-file stamp mode (exact S3 filenames)")
                self.create_stamp_files_per_file(self.bucket_name, self.prefix)
            elif self.args.stamp_mode == "per-directory":
                log.info(
                    "Using per-directory stamp mode (directory-level=%d)",
                    self.args.directory_level,
                )
                self.create_stamp_files_per_directory(self.bucket_name, self.prefix)
            log.info(
                "Stamp file creation completed. Files created: %d, "
                "Files unchanged: %d, Files removed: %d",
                self.stats["files_created"],
                self.stats["files_unchanged"],
                self.stats["files_removed"],
            )
        else:
            log.error(
                "No action specified. Provide s3_path for stamp creation or use"
                " --upload-file for uploading."
            )
            sys.exit(1)

    def create_stamp_files_per_file(self, bucket_name: str, prefix: str) -> None:
        """Creates local stamp files that mirror S3 objects with exact filenames.

        Each S3 file gets a local stamp file with the same name (no suffix).
        Stamp files are zero-byte files with timestamps matching S3 LastModified.

        Args:
            bucket_name (str): The name of the S3 bucket.
            prefix (str): The file prefix to match in the S3 bucket.
        """
        bucket = self.s3_resource.Bucket(bucket_name)
        expected_stamp_files = set()  # Track expected stamp files from S3

        for s3_object in bucket.objects.filter(Prefix=prefix):
            s3_key = s3_object.key

            # Skip directories and zero-size objects
            if s3_key.endswith("/"):
                local_dir = os.path.join(self.args.local_dir, s3_key)
                if not os.path.exists(local_dir):
                    os.makedirs(local_dir)
                    logging.info("Created local directory: '%s'", local_dir)
                continue

            # Only consider files with specified extensions
            if not any(s3_key.endswith(ext) for ext in self.args.file_extensions):
                log.debug(
                    "Skipping file '%s' - extension not in allowed list: %s",
                    s3_key,
                    self.args.file_extensions,
                )
                continue
            # Get the content of the S3 object
            content = (
                self.get_s3_object_content(s3_key) if self.args.write_content else None
            )

            # Get object metadata to check for custom timestamp
            obj = self.s3_resource.Object(self.bucket_name, s3_key)
            response = obj.meta.client.head_object(Bucket=self.bucket_name, Key=s3_key)
            log.debug("s3 metadata: %s", response.get("Metadata", {}))

            # Use the get_last_modified function to handle custom metadata
            last_modified = get_last_modified(response)

            # Create a local stamp file with exact S3 filename (no suffix)
            local_path = self.create_local_stamp_file(
                s3_key, last_modified, content, use_exact_name=True
            )
            expected_stamp_files.add(local_path)

        # Remove dangling local stamp files if requested
        if self.args.remove_dangling_stamps:
            self.remove_dangling_stamps(expected_stamp_files, use_exact_names=True)

    def create_stamp_files_per_directory(self, bucket_name: str, prefix: str) -> None:
        """Creates directory-level stamp files aggregating multiple S3 objects.

        Groups S3 files by directory (based on --directory-level) and creates
        one stamp file per directory with .stamp suffix. The stamp timestamp
        reflects the latest modification time of any file in that directory.

        Args:
            bucket_name (str): The name of the S3 bucket.
            prefix (str): The prefix within the bucket.
        """
        # Initialize the S3 client
        s3_client = get_s3_client()
        expected_stamp_files = set()  # Track expected stamp files from S3

        # Helper function to list object keys in S3
        def list_keys(bucket: str, prefix: str) -> list[str]:
            paginator = s3_client.get_paginator("list_objects_v2")
            page_iterator = paginator.paginate(Bucket=bucket, Prefix=prefix)

            keys = []  # List to store object keys
            for page in page_iterator:
                keys.extend([obj["Key"] for obj in page.get("Contents", [])])
            return keys

        # Retrieve object keys from the S3 bucket
        object_keys = list_keys(bucket_name, prefix)
        if not object_keys:
            log.warning("No objects found for prefix '%s'.", prefix)
            return

        # Dictionary to map directories to their latest LastModified timestamp
        dir_to_latest_ts: dict = {}
        local_stamp_path = ""  # Initialize local stamp path

        # Iterate over all object keys to find the latest LastModified timestamp
        # for each directory
        for key in object_keys:
            # Only consider files with specified extensions
            if not any(key.endswith(ext) for ext in self.args.file_extensions):
                log.debug(
                    "Skipping file '%s' - extension not in allowed list: %s",
                    key,
                    self.args.file_extensions,
                )
                continue

            # Retrieve the last modified timestamp of the object
            response = s3_client.head_object(Bucket=bucket_name, Key=key)
            last_modified = get_last_modified(response)
            log.debug("RESPONSE: %s", response)

            # Determine the directory based on the user-specified level
            parts = key.split("/")
            if len(parts) <= self.args.directory_level:
                log.warning(
                    "Skipping file '%s' as it does not have enough directory levels.",
                    key,
                )
                continue
            directory = "/".join(parts[: -self.args.directory_level])

            # Update the latest timestamp for the directory
            existing = dir_to_latest_ts.get(directory)
            if existing is None or last_modified > existing:
                dir_to_latest_ts[directory] = last_modified

        # Create stamp files for directories (always with .stamp suffix)
        for directory, latest_ts in dir_to_latest_ts.items():
            # Construct the local stamp file path
            logging.info(
                "Creating stamp file for directory: '%s' bucket %s ",
                directory,
                bucket_name,
            )

            if not self.args.no_bucket:
                local_stamp_path = os.path.join(bucket_name, directory)
            local_stamp_path = os.path.join(self.args.local_dir, local_stamp_path)
            # Always append .stamp for directory stamps
            local_stamp_path += ".stamp"

            # Ensure the parent directory exists
            os.makedirs(os.path.dirname(local_stamp_path), exist_ok=True)

            if self.is_local_stamp_current(local_stamp_path, latest_ts):
                self.stats["files_unchanged"] += 1
                log.debug(
                    "Stamp file '%s' already current with timestamp %s.",
                    local_stamp_path,
                    latest_ts.isoformat(),
                )
                expected_stamp_files.add(local_stamp_path)
                continue

            # Create or update the stamp file
            with open(local_stamp_path, "w", encoding="utf-8") as f:
                f.write("")  # Empty content for the stamp file

            # Set the timestamp of the stamp file
            os.utime(local_stamp_path, (latest_ts.timestamp(), latest_ts.timestamp()))
            log.info(
                "Created stamp file '%s' with timestamp %s.",
                local_stamp_path,
                latest_ts.isoformat(),
            )
            expected_stamp_files.add(local_stamp_path)

        # Remove dangling local stamp files if requested
        if self.args.remove_dangling_stamps:
            self.remove_dangling_stamps(expected_stamp_files, use_exact_names=False)

    def get_s3_object_content(self, s3_key: str) -> str:
        """Get the content of an S3 object.

        Args:
            s3_key (str): The key of the S3 object.

        Returns:
            str: The content of the S3 object.
        """

        obj = self.s3_resource.Object(self.bucket_name, s3_key)
        raw_content = obj.get()["Body"].read()
        content = raw_content
        # Decompress the content
        if s3_key.endswith(".bz2"):
            content = bz2.decompress(raw_content)

        return content.decode("utf-8")

    def create_local_stamp_file(
        self,
        s3_key: str,
        last_modified: datetime,
        content: Optional[str] = None,
        use_exact_name: bool = True,
    ) -> str:
        """Creates a local stamp file, mirroring the modification date of an S3 object.

        Args:
            s3_key (str): The key of the S3 object.
            last_modified (datetime): The last-modified timestamp of the S3 object.
            content (Optional[str]): Content to write (None for empty stamp files).
            use_exact_name (bool): If True, use exact S3 filename. If False, legacy behavior.

        Returns:
            str: The local file path of the created stamp file.
        """

        local_file_path = s3_key.replace("/", os.sep)
        # include  bucket name in local file path depending on the --no-bucket flag
        if not self.args.no_bucket:
            local_file_path = os.path.join(self.bucket_name, local_file_path)

        # Adjust the file path to include the local directory
        local_file_path = os.path.join(self.args.local_dir, local_file_path)
        # In per-file mode, stamps always match S3 filenames exactly (no suffix)
        # Content is only written if explicitly requested

        os.makedirs(os.path.dirname(local_file_path), exist_ok=True)

        if content is None and self.is_local_stamp_current(local_file_path, last_modified):
            self.stats["files_unchanged"] += 1
            log.debug(
                "Stamp file '%s' already current with timestamp %s.",
                local_file_path,
                last_modified.isoformat(),
            )
            return local_file_path

        with smart_open.open(local_file_path, "w", encoding="utf-8") as f:
            f.write(content if content is not None else "")

        os.utime(
            local_file_path, (last_modified.timestamp(), last_modified.timestamp())
        )

        self.stats["files_created"] += 1
        log.info(f"'{local_file_path}' created. Last modification: {last_modified}")
        return local_file_path

    @staticmethod
    def is_local_stamp_current(local_file_path: str, expected_mtime: datetime) -> bool:
        """Return True when an existing stamp already has the expected mtime."""
        if not os.path.exists(local_file_path):
            return False

        return abs(os.path.getmtime(local_file_path) - expected_mtime.timestamp()) < 0.001

    def remove_dangling_stamps(
        self, expected_stamp_files: set[str], use_exact_names: bool = True
    ) -> None:
        """Removes local stamp files that no longer exist in S3.

        Args:
            expected_stamp_files: Set of local stamp file paths that should exist
                based on current S3 objects.
            use_exact_names: If True, stamps match S3 names exactly.
                If False, stamps have .stamp suffix (directory mode).
        """
        log.info(
            "Checking for dangling stamp files. Expected files from S3: %d",
            len(expected_stamp_files),
        )
        # Determine the base directory to scan
        if not self.args.no_bucket:
            base_dir = os.path.join(self.args.local_dir, self.bucket_name, self.prefix)
        else:
            base_dir = os.path.join(self.args.local_dir, self.prefix)

        log.info("Scanning base directory: '%s'", base_dir)

        if not os.path.exists(base_dir):
            log.debug(
                "Base directory '%s' does not exist, nothing to clean up.", base_dir
            )
            return

        # Walk through the local directory and find all stamp files
        for root, dirs, files in os.walk(base_dir):
            for filename in files:
                file_path = os.path.join(root, filename)

                # Determine base filename based on stamp mode
                if use_exact_names:
                    # Per-file mode: stamps match S3 filenames exactly
                    base_filename = filename
                else:
                    # Per-directory mode: stamps have .stamp suffix
                    if not filename.endswith(".stamp"):
                        continue
                    base_filename = filename[:-6]  # Remove .stamp

                # Check if base filename matches any of the configured extensions
                # For directory stamps, we skip this check since directory stamps
                # don't correspond 1:1 with file extensions
                if use_exact_names:
                    matches_extension = any(
                        base_filename.endswith(ext) for ext in self.args.file_extensions
                    )
                    if not matches_extension:
                        log.debug(
                            "Skipping '%s' - doesn't match file extensions: %s",
                            file_path,
                            self.args.file_extensions,
                        )
                        continue

                # Check if file is truly a stamp (empty file)
                # 0 bytes = truly empty, 14 bytes = empty bz2 file signature
                try:
                    file_size = os.path.getsize(file_path)
                    is_stamp = file_size == 0 or (
                        file_path.endswith(".bz2") and file_size == 14
                    )
                    if not is_stamp:
                        # If file should be in expected set but isn't a stamp,
                        # it's likely leftover from --write-content or other source
                        # If it's also not in expected_stamp_files, remove it
                        if file_path not in expected_stamp_files:
                            log.warning(
                                "Removing non-stamp file '%s' (size: %d bytes) - "
                                "not in S3 expected set. Likely leftover from "
                                "previous sync with --write-content.",
                                file_path,
                                file_size,
                            )
                            try:
                                os.remove(file_path)
                                self.stats["files_removed"] += 1
                                continue
                            except OSError as e:
                                log.error(
                                    "Failed to remove non-stamp file '%s': %s",
                                    file_path,
                                    e,
                                )
                        else:
                            log.debug(
                                "Skipping '%s' - not a stamp file (size: %d bytes, "
                                "expected 0 or 14 for .bz2) but is in expected set",
                                file_path,
                                file_size,
                            )
                        continue
                except OSError as e:
                    log.warning("Error checking file size for '%s': %s", file_path, e)
                    continue

                # If this stamp file is not in the expected set, remove it
                if file_path not in expected_stamp_files:
                    try:
                        os.remove(file_path)
                        self.stats["files_removed"] += 1
                        log.info(
                            "Removed dangling stamp file: '%s' (no longer in S3)",
                            file_path,
                        )
                    except OSError as e:
                        log.error(
                            "Failed to remove dangling stamp file '%s': %s",
                            file_path,
                            e,
                        )


def check_wip_file(s3_client, s3_path, max_age_hours):
    """
    Check for WIP (work-in-progress) stamp file and handle based on age.

    Args:
        s3_client: Boto3 S3 client
        s3_path: S3 path to check for WIP file (will append .wip)
        max_age_hours: Maximum age in hours before WIP file is considered stale

    Returns:
        0: WIP file exists and is fresh (younger than max_age_hours)
        1: No WIP file found, can proceed
        3: WIP file was stale and removed
    """
    wip_path = s3_path + ".wip"

    # Parse S3 path
    if not wip_path.startswith("s3://"):
        logging.error("Invalid S3 path format: %s", wip_path)
        return 1

    path_parts = wip_path[5:].split("/", 1)
    if len(path_parts) != 2:
        logging.error("Invalid S3 path format: %s", wip_path)
        return 1

    bucket, key = path_parts

    try:
        # Check if WIP file exists and get its metadata
        response = s3_client.head_object(Bucket=bucket, Key=key)
        last_modified = response["LastModified"]

        # Calculate age
        now = datetime.now(last_modified.tzinfo)
        age = now - last_modified
        max_age = timedelta(hours=max_age_hours)

        if age <= max_age:
            # WIP file is fresh
            age_hours = age.total_seconds() / 3600
            print(
                f"Warning: WIP file {wip_path} exists and is {age_hours:.1f} hours old"
                f" (< {max_age_hours}h). Skipping processing.",
                file=sys.stderr,
            )
            return 0
        else:
            # WIP file is stale, remove it
            age_hours = age.total_seconds() / 3600
            logging.warning(
                "WIP file %s is stale (%.1f hours old > %dh). Removing it.",
                wip_path,
                age_hours,
                max_age_hours,
            )

            try:
                s3_client.delete_object(Bucket=bucket, Key=key)
                logging.info("Removed stale WIP file: %s", wip_path)
                return 3
            except ClientError as e:
                logging.error("Failed to remove stale WIP file %s: %s", wip_path, e)
                return 3

    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        if error_code == "404":
            # WIP file doesn't exist, can proceed
            logging.debug("No WIP file found at %s", wip_path)
            return 1
        else:
            logging.error("Error checking WIP file %s: %s", wip_path, e)
            return 1


def main():
    parser = argparse.ArgumentParser(
        description="Check S3 file existence and manage WIP files"
    )
    parser.add_argument("--s3-file-exists", help="Check if S3 file exists")
    parser.add_argument(
        "--wip",
        action="store_true",
        help="Check for WIP stamp file in combination with --s3-file-exists",
    )
    parser.add_argument(
        "--wip-max-age",
        type=int,
        default=24,
        help=(
            "Maximum age in hours for WIP file before considering it stale"
            " (default: 24)"
        ),
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: %(default)s)",
    )

    args = parser.parse_args()

    # Set up logging
    logging.basicConfig(
        level=getattr(logging, args.log_level),
        format="%(asctime)s - %(levelname)s - %(message)s",
    )

    if not args.s3_file_exists:
        logging.error("--s3-file-exists is required")
        sys.exit(1)

    # Initialize S3 client
    try:
        s3_client = boto3.client("s3")
    except Exception as e:
        logging.error("Failed to create S3 client: %s", e)
        sys.exit(1)

    # If --wip is specified, check WIP file first
    if args.wip:
        wip_result = check_wip_file(s3_client, args.s3_file_exists, args.wip_max_age)
        if wip_result == 0:
            # Fresh WIP file exists, skip processing
            sys.exit(0)
        elif wip_result == 3:
            # Stale WIP file was removed
            sys.exit(3)
        # If wip_result == 1, continue to check main file

    # Check if main file exists
    s3_path = args.s3_file_exists
    if not s3_path.startswith("s3://"):
        logging.error("Invalid S3 path format: %s", s3_path)
        sys.exit(1)

    path_parts = s3_path[5:].split("/", 1)
    if len(path_parts) != 2:
        logging.error("Invalid S3 path format: %s", s3_path)
        sys.exit(1)

    bucket, key = path_parts

    try:
        s3_client.head_object(Bucket=bucket, Key=key)
        logging.info("File exists: %s", s3_path)
        sys.exit(0)  # File exists
    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        if error_code == "404":
            logging.debug("File does not exist: %s", s3_path)
            sys.exit(1)  # File doesn't exist
        else:
            logging.error("Error checking file %s: %s", s3_path, e)
            sys.exit(1)


if __name__ == "__main__":

    parser = argparse.ArgumentParser(
        description="S3 to Local Stamp File Creator",
        epilog="Utility to mirror S3 file structure locally with stamp files.",
    )

    parser.add_argument(
        "s3_path",
        help=(
            "S3 path prefix in the format s3://BUCKET_NAME/PREFIX. "
            "The prefix is used to match objects in the specified bucket."
        ),
    )
    parser.add_argument(
        "--upload-file",
        help="Path to the local file to upload to S3.",
        metavar="LOCAL_FILE",
    )
    parser.add_argument(
        "--force-overwrite",
        action="store_true",
        help="Overwrite the --upload-file on S3 even if it already exists.",
    )
    parser.add_argument(
        "--level",
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        help="Set the logging level. Default: %(default)s",
    )
    parser.add_argument("--logfile", help="Write log to FILE", metavar="FILE")

    parser.add_argument(
        "--local-dir",
        default="./",
        type=str,
        help="Local directory prefix for creating stamp files %(default)s",
    )
    parser.add_argument(
        "--no-bucket",
        help="Do not use bucket name for local files, only the key. %(default)s",
        action="store_true",
    )
    parser.add_argument(
        "--stamp-mode",
        default="per-file",
        choices=["per-file", "per-directory"],
        help=(
            "Stamp creation mode. 'per-file': Create one stamp per S3 file with "
            "exact filename (no suffix). 'per-directory': Create directory-level "
            "stamps with .stamp suffix, aggregating multiple files. "
            "Default: %(default)s"
        ),
    )
    parser.add_argument(
        "--write-content",
        action="store_true",
        help=(
            "Write the content of the S3 objects to the local stamp files. Not used for"
            " upload!"
        ),
    )
    parser.add_argument(
        "--list-files",
        action="store_true",
        help=(
            "list all files in the bucket and prefix on stdout and exit. No stamp files"
            " are created."
        ),
    )
    parser.add_argument(
        "--list-files-glob",
        help=(
            "Specify a file glob filter on the keys. Only used"
            " with option --list-files."
        ),
    )
    parser.add_argument(
        "--directory-level",
        type=int,
        default=1,
        help=(
            "Number of directory levels to consider when using per-directory mode. "
            "1 = immediate parent directory, 2 = grandparent, etc. "
            "Only used with --stamp-mode per-directory. Default: %(default)s"
        ),
    )
    parser.add_argument(
        "--file-extensions",
        nargs="+",
        default=["jsonl.bz2"],
        help=(
            "File extensions to consider for stamp creation. Multiple extensions "
            "can be specified. Default: %(default)s. "
            "Example: --file-extensions jsonl.bz2 json txt"
        ),
    )
    parser.add_argument(
        "--remove-dangling-stamps",
        action="store_true",
        help=(
            "Remove local stamp files that no longer have corresponding objects "
            "in S3. Only removes empty (0 bytes) stamp files matching configured "
            "file extensions."
        ),
    )
    arguments = parser.parse_args()

    # Configure logging using the impresso_cookbook setup_logging function
    setup_logging(arguments.level, arguments.logfile, logger=log)
    log.info("Arguments: %s", arguments)
    try:
        processor = LocalStampCreator(arguments)
        processor.run()
    except Exception as e:
        print(f"An error occurred: {e}", file=sys.stderr)
        log.error("Traceback: %s", traceback.format_exc())
        sys.exit(1)
