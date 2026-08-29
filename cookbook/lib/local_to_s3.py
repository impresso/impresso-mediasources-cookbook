"""
This module, `local_to_s3.py`, is a utility for uploading local files to S3 with 
work-in-progress (WIP) file management and concurrent processing prevention.

It imports functionality from the `impresso_cookbook` library and provides a
comprehensive interface for uploading multiple files to S3 with pairs of local_path
s3_path arguments, including advanced features for parallel processing workflows.

Key Features:
- S3 file existence checking with exit codes for makefile integration
- Work-in-progress (WIP) file management for preventing concurrent processing
- Automatic WIP file creation with hostname, IP address, username, and timestamp tracking
- Stale WIP file detection and cleanup based on configurable age limits
- File pair uploading with dependency management (data files + log files)
- Timestamp metadata extraction and setting for JSONL and other file types
- Local file truncation with timestamp preservation for space management
- Comprehensive logging and error handling for production workflows

WIP Workflow:
1. Check file existence: --s3-file-exists --wip --create-wip creates WIP if needed
2. Process files: Standard processing occurs while WIP file indicates work in progress
3. Upload and cleanup: --remove-wip removes WIP files after successful upload

Exit Codes for --s3-file-exists:
By default, --s3-file-exists keeps traditional existence-test semantics:

- 0: The requested S3 object exists.
- 1: The requested S3 object does not exist and no WIP file was created.
- 2: A non-stale WIP file exists, so another process is already working.

When --create-wip is used and the target object is missing, a WIP file is created
and the command exits with 0. This historical behavior is used by processing
recipes that chain the preflight check with `&& process`.

Some aggregation/preflight recipes need a different convention where 0 means
"continue processing" and 2 means "skip because output already exists or WIP is
active". Those recipes must opt in with --exit-2-if-exists. In that mode:

- 0: The target is missing and processing may continue; if --create-wip was used,
     the WIP file was created.
- 2: The target already exists, or a non-stale WIP file exists.
- 1: Error, or missing target without WIP creation in legacy-compatible cases.

Do not use --exit-2-if-exists for generic existence checks. It is intended for
Make preflight recipes that explicitly inspect the exit status before deciding
whether to skip or process.

File Pairing and Dependency Logic:
The upload process intelligently pairs content files with their log files to ensure
consistency. Files are processed sequentially, with special handling for related pairs:

1. Content File Detection: A file is considered a content file if the NEXT file in the
   argument list starts with its name and ends with .log.gz
   Example: file.jsonl.bz2 is paired with file.jsonl.bz2.log.gz

2. Log File Detection: A file ending in .log.gz is considered a log file if the PREVIOUS
   file in the list is its corresponding content file (log filename starts with content
   filename, and previous file is not itself a .log.gz)

3. Dependency-Based Upload Rules:
   a) If a content file is uploaded, its log file is ALWAYS uploaded regardless of
      timestamp comparisons (forced upload)
   b) If a content file is skipped (stamp file or up-to-date), its log file is also
      skipped
   c) If a content file upload fails, its log file is not attempted
   d) Standalone files (no paired log) follow normal upload rules

4. Stamp File Detection (never uploaded with --upload-if-newer):
   - 0 bytes: Truly empty files
   - 14 bytes for .bz2 files: Empty bz2 compressed files (compression signature only)

5. Upload Decision Priority (when --upload-if-newer is set):
   - Log files: Upload if corresponding content file was uploaded (forced)
   - Stamp files: Never upload (skip)
   - Non-stamp files: Upload if local mtime > S3 impresso-last-ts metadata
   - Files without S3 metadata: Treat as outdated and upload
   - S3 file doesn't exist: Upload (unless stamp file)

This ensures that log files remain synchronized with their content files, preventing
situations where regenerated content files have outdated log files on S3.

Usage Examples:
    # Check existence and create WIP (for makefile integration)
    python3 -m impresso_cookbook.local_to_s3 --s3-file-exists s3://bucket/file.txt.gz \\
        --wip --wip-max-age 2 --create-wip \\
        local1.txt.gz s3://bucket/file1.txt.gz local1.log.gz s3://bucket/file1.log.gz

    # Preflight where Make treats 0 as process and 2 as skip
    python3 -m impresso_cookbook.local_to_s3 --exit-2-if-exists \\
        --s3-file-exists s3://bucket/file.json.bz2 \\
        --wip --wip-max-age 2 --create-wip \\
        local.json.bz2 s3://bucket/file.json.bz2 \\
        local.log.gz s3://bucket/file.log.gz

    # Upload files and remove WIP
    python3 -m impresso_cookbook.local_to_s3 --remove-wip --set-timestamp \\
        --keep-timestamp-only --ts-key __file__ \\
        local1.txt.gz s3://bucket/file1.txt.gz local1.log.gz s3://bucket/file1.log.gz

    # Simple upload without WIP management
    python3 -m impresso_cookbook.local_to_s3 \
        localpath1 s3path1 localpath2 s3path2 \
        --force-overwrite --set-timestamp --keep-timestamp-only

    # Upload only newer non-stamp files (checks impresso-last-ts metadata)
    python3 -m impresso_cookbook.local_to_s3 \
        local1.txt.gz s3://bucket/file1.txt.gz \
        --upload-if-newer --set-timestamp
"""

__author__ = "simon.clematide@uzh.ch"
__license__ = "GNU GPL 3.0 or later"

import argparse
import logging
import os
import sys
import time
import traceback
import socket
import json
import getpass
from datetime import datetime
from dotenv import load_dotenv

from impresso_cookbook import (
    get_s3_client,
    upload_with_retries,
    keep_timestamp_only,
    parse_s3_path,
    setup_logging,
    S3TimestampProcessor,
    s3_file_exists,
)

log = logging.getLogger(__name__)

load_dotenv()


def main():
    """Main function for uploading local files to S3."""
    parser = argparse.ArgumentParser(
        description=(
            "Upload local files to S3 with WIP management and concurrent processing"
            " prevention"
        ),
        epilog=(
            "Utility for uploading files to S3 with work-in-progress tracking, "
            "timestamp management, and makefile integration support."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "files",
        nargs="*",
        help="Pairs of local_path s3_path. Must be an even number of arguments.",
        metavar="PATH",
    )
    parser.add_argument(
        "--s3-file-exists",
        help="Check if S3 file exists and exit with code 0 if it does, 1 if not.",
        metavar="S3_PATH",
    )
    parser.add_argument(
        "--exit-2-if-exists",
        action="store_true",
        help=(
            "With --s3-file-exists, exit with code 2 when the S3 file already "
            "exists. This preserves the default existence-check behavior unless "
            "explicitly requested by processing preflight recipes."
        ),
    )
    parser.add_argument(
        "--wip",
        action="store_true",
        help="Enable work-in-progress file checking.",
    )
    parser.add_argument(
        "--wip-max-age",
        type=float,
        default=24,
        help=(
            "Maximum age in hours for WIP files (default: %(default)s). "
            "Can be fractional (e.g., 0.1 for 6 minutes)."
        ),
    )
    parser.add_argument(
        "--force-overwrite",
        action="store_true",
        help="Overwrite files on S3 even if they already exist.",
    )
    parser.add_argument(
        "--upload-if-newer",
        action="store_true",
        help=(
            "Upload only if local file is non-empty (not a stamp file) and newer "
            "than S3 file's impresso-last-ts metadata timestamp. Empty files "
            "(stamp files from sync) are never uploaded. If --force-overwrite is "
            "also set, it takes precedence."
        ),
    )
    parser.add_argument(
        "--keep-timestamp-only",
        action="store_true",
        help=(
            "Truncate all uploaded files to zero length (stamp files) and keep only "
            "timestamp after successful upload. Converts data files, log files, and "
            "statistics files into zero-byte stamps for efficient storage."
        ),
    )
    parser.add_argument(
        "--set-timestamp",
        action="store_true",
        help=(
            "Automatically set impresso timestamp metadata after successful upload "
            "of *.jsonl.bz2 files."
        ),
    )
    parser.add_argument(
        "--ts-key",
        default="ts",
        choices=["ts", "cdt", "__file__"],
        help=(
            "Timestamp key to extract from JSONL records or '__file__' to use file"
            " modification date (default: %(default)s)."
        ),
    )
    parser.add_argument(
        "--metadata-key",
        default="impresso-last-ts",
        help="S3 metadata key for timestamp (default: %(default)s).",
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
        "--create-wip",
        action="store_true",
        help="Create a WIP file before processing to prevent concurrent execution.",
    )
    parser.add_argument(
        "--remove-wip",
        action="store_true",
        help="Remove WIP files after successful upload.",
    )
    parser.add_argument(
        "--forbid-extensions",
        nargs="+",
        default=[".stamp", ".last_synced"],
        help=(
            "File extensions that should never be uploaded to S3 "
            "(default: %(default)s). Prevents accidental stamp file uploads."
        ),
    )

    args = parser.parse_args()

    # If --create-wip is set, automatically enable --wip
    if args.create_wip:
        args.wip = True

    # Set up logging using common.py
    setup_logging(args.log_level, args.log_file, logger=log)

    # Handle --s3-file-exists option
    if args.s3_file_exists:
        try:
            s3_client = get_s3_client()
            # Use s3_file_exists from common.py
            exists = s3_file_exists(s3_client, args.s3_file_exists)
            if exists:
                log.info("S3 file exists: %s", args.s3_file_exists)
                sys.exit(2 if args.exit_2_if_exists else 0)
            # WIP file management (still needs direct S3 ops, but use parse_s3_path)
            if args.wip:
                wip_path = args.s3_file_exists + ".wip"
                bucket, key = parse_s3_path(wip_path)
                try:
                    response = s3_client.head_object(Bucket=bucket, Key=key)
                    wip_modified = response["LastModified"]
                    from datetime import timezone

                    now = datetime.now(timezone.utc)
                    age_hours = (now - wip_modified).total_seconds() / 3600
                    if age_hours > args.wip_max_age:
                        log.info(
                            "Stale WIP file found (%.1f hours old), removing: %s",
                            age_hours,
                            wip_path,
                        )
                        s3_client.delete_object(Bucket=bucket, Key=key)
                        log.info("S3 file does not exist: %s", args.s3_file_exists)
                    else:
                        log.info(
                            "WIP file in progress (%.1f hours old): %s",
                            age_hours,
                            wip_path,
                        )
                        try:
                            wip_obj = s3_client.get_object(Bucket=bucket, Key=key)
                            wip_content = wip_obj["Body"].read().decode("utf-8")
                            wip_info = json.loads(wip_content)
                            log.info(
                                "WIP file being processed by user: %s on host: %s (%s)",
                                wip_info.get("username", "unknown"),
                                wip_info.get("hostname", "unknown"),
                                wip_info.get("ip_address", "unknown"),
                            )
                        except Exception as e:
                            log.debug("Could not read WIP file content: %s", e)
                        # Exit 2 to signal WIP exists - Make should skip processing
                        sys.exit(2)
                except s3_client.exceptions.NoSuchKey:
                    # No WIP file exists - this is normal, continue
                    log.debug(
                        "No WIP file found at %s, processing can proceed", wip_path
                    )
                except Exception as e:
                    # Only log warning for unexpected errors (not 404/NoSuchKey)
                    if "404" not in str(e) and "NoSuchKey" not in str(e):
                        log.warning("Error checking WIP file %s: %s", wip_path, e)
                    else:
                        log.debug(
                            "No WIP file found at %s (404), processing can proceed",
                            wip_path,
                        )
            # If --create-wip is used during file existence check, create WIP
            # and exit 1 to proceed
            if args.create_wip and args.files:
                hostname = socket.gethostname()
                try:
                    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                    s.connect(("8.8.8.8", 80))
                    ip_address = s.getsockname()[0]
                    s.close()
                except Exception:
                    ip_address = "127.0.0.1"
                wip_info = {
                    "hostname": hostname,
                    "ip_address": ip_address,
                    "username": getpass.getuser(),
                    "start_time": datetime.now().isoformat(),
                    "pid": os.getpid(),
                    "files": args.files,
                }
                file_pairs = [
                    (args.files[i], args.files[i + 1])
                    for i in range(0, len(args.files), 2)
                ]
                for local_path, s3_path in file_pairs:
                    if local_path.endswith((".txt.gz", ".jsonl.bz2", ".json.bz2")):
                        wip_path = s3_path + ".wip"
                        wip_content = json.dumps(wip_info, indent=2)
                        bucket, key = parse_s3_path(wip_path)
                        try:
                            s3_client.put_object(
                                Bucket=bucket,
                                Key=key,
                                Body=wip_content.encode("utf-8"),
                                ContentType="application/json",
                            )
                            log.info(
                                "Created WIP file during existence check: %s (host: %s,"
                                " IP: %s, user: %s)",
                                wip_path,
                                hostname,
                                ip_address,
                                getpass.getuser(),
                            )
                        except Exception as e:
                            log.error("Failed to create WIP file %s: %s", wip_path, e)
                # When WIP is created successfully, exit 0 to allow make to continue
                log.info(
                    "S3 file does not exist: %s, WIP created, continuing",
                    args.s3_file_exists,
                )
                sys.exit(0)
            # S3 file doesn't exist and no WIP was created
            log.info("S3 file does not exist: %s", args.s3_file_exists)
            sys.exit(0 if args.exit_2_if_exists else 1)
        except Exception as e:
            log.error("Error checking S3 file existence: %s", e)
            sys.exit(1)

    # When --s3-file-exists is not provided, we proceed to upload files
    # Validate that we have pairs of arguments
    if not args.files:
        log.error("No file pairs provided for upload")
        sys.exit(1)

    if len(args.files) % 2 != 0:
        log.error(
            "Arguments must be pairs of local_path s3_path. Got %d arguments.",
            len(args.files),
        )
        sys.exit(1)

    log.info("Arguments: %s", args)

    try:
        s3_client = get_s3_client()
        # Create WIP files if requested (only when NOT doing existence check)
        if args.create_wip and args.files and not args.s3_file_exists:
            hostname = socket.gethostname()
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
                s.connect(("8.8.8.8", 80))
                ip_address = s.getsockname()[0]
                s.close()
            except Exception:
                ip_address = "127.0.0.1"
            wip_info = {
                "hostname": hostname,
                "ip_address": ip_address,
                "username": getpass.getuser(),
                "start_time": datetime.now().isoformat(),
                "pid": os.getpid(),
                "files": args.files,
            }
            file_pairs = [
                (args.files[i], args.files[i + 1]) for i in range(0, len(args.files), 2)
            ]
            for local_path, s3_path in file_pairs:
                if local_path.endswith((".txt.gz", ".jsonl.bz2", ".json.bz2")):
                    wip_path = s3_path + ".wip"
                    wip_content = json.dumps(wip_info, indent=2)
                    bucket, key = parse_s3_path(wip_path)
                    try:
                        s3_client.put_object(
                            Bucket=bucket,
                            Key=key,
                            Body=wip_content.encode("utf-8"),
                            ContentType="application/json",
                        )
                        log.info(
                            "Created WIP file: %s (host: %s, IP: %s, user: %s)",
                            wip_path,
                            hostname,
                            ip_address,
                            getpass.getuser(),
                        )
                    except Exception as e:
                        log.error("Failed to create WIP file %s: %s", wip_path, e)
        file_pairs = [
            (args.files[i], args.files[i + 1]) for i in range(0, len(args.files), 2)
        ]
        log.info("Uploading %d file pair(s) to S3", len(file_pairs))
        # Track successfully uploaded files for timestamp setting
        uploaded_files = []

        # Statistics tracking for final summary
        stats = {
            "uploaded": [],
            "skipped_existing": [],
            "skipped_stamp": [],
            "skipped_uptodate": [],
            "skipped_paired": [],
            "failed": [],
        }

        # Process files in pairs: content file and its log file
        # If content file is skipped/fails, log file is also skipped
        # Track which content files were uploaded to force upload their log files
        uploaded_content_files = set()

        pair_idx = 0
        while pair_idx < len(file_pairs):
            local_path, s3_path = file_pairs[pair_idx]

            # Determine if this is a content file (should have a log pair after it)
            is_content_file = (
                pair_idx + 1 < len(file_pairs)
                and file_pairs[pair_idx + 1][0].startswith(local_path)
                and file_pairs[pair_idx + 1][0].endswith(".log.gz")
            )

            # Determine if this is a log file for a content file
            is_log_file = local_path.endswith(".log.gz")
            corresponding_content_file = None
            if is_log_file:
                # Check if previous file was the corresponding content file
                if pair_idx > 0:
                    prev_local, prev_s3 = file_pairs[pair_idx - 1]
                    is_prev_content = not prev_local.endswith(".log.gz")
                    if local_path.startswith(prev_local) and is_prev_content:
                        corresponding_content_file = prev_local

            # Check for forbidden file extensions (stamp files, sync markers)
            if any(local_path.endswith(ext) for ext in args.forbid_extensions):
                log.error(
                    "FATAL: Attempted to upload forbidden file type: %s "
                    "(matches forbidden extensions: %s). "
                    "Stamp files and sync markers should never be uploaded to S3.",
                    local_path,
                    args.forbid_extensions,
                )
                sys.exit(1)

            # Check file existence and size before upload
            if not os.path.exists(local_path):
                log.error(
                    "FATAL: File not found: %s. Cannot proceed with upload.",
                    local_path,
                )
                sys.exit(1)
            if os.path.getsize(local_path) == 0:
                log.error(
                    "FATAL: File is empty (0 bytes): %s. "
                    "Empty files indicate a processing failure and should not be "
                    "uploaded.",
                    local_path,
                )
                sys.exit(1)
            log.info("Uploading file: %s to %s", local_path, s3_path)

            # Check if file exists if not force_overwrite
            skip_this_pair = False

            # If this is a log file and its content file was uploaded, force upload
            skip_reason = None
            if is_log_file and corresponding_content_file in uploaded_content_files:
                log.info(
                    "Forcing upload of log file %s (content file %s was uploaded)",
                    local_path,
                    corresponding_content_file,
                )
                skip_this_pair = False
            elif not args.force_overwrite:
                bucket, key = parse_s3_path(s3_path)
                if s3_file_exists(s3_client, bucket, key):
                    # If --upload-if-newer is set, check if local file
                    # should be uploaded
                    if args.upload_if_newer:
                        local_size = os.path.getsize(local_path)
                        # Empty files are stamp files - never upload them
                        # 0 bytes = truly empty, 14 bytes = empty bz2 file
                        is_stamp = local_size == 0 or (
                            local_path.endswith(".bz2") and local_size == 14
                        )
                        if is_stamp:
                            log.info(
                                "Skipping stamp file: %s (%d bytes)",
                                local_path,
                                local_size,
                            )
                            skip_this_pair = True
                            skip_reason = "stamp file"
                        else:
                            # Non-empty file - check if newer than S3 metadata
                            try:
                                s3_head = s3_client.head_object(Bucket=bucket, Key=key)
                                s3_metadata = s3_head.get("Metadata", {})
                                s3_timestamp_str = s3_metadata.get(args.metadata_key)

                                if s3_timestamp_str:
                                    # Parse S3 metadata timestamp
                                    s3_timestamp = datetime.fromisoformat(
                                        s3_timestamp_str.replace("Z", "+00:00")
                                    )
                                    # Get local file modification time as timezone-aware
                                    from datetime import timezone

                                    local_mtime = datetime.fromtimestamp(
                                        os.path.getmtime(local_path), tz=timezone.utc
                                    )

                                    if local_mtime > s3_timestamp:
                                        log.info(
                                            "Local file %s is newer "
                                            "(local: %s, S3: %s). Uploading.",
                                            local_path,
                                            local_mtime.isoformat(),
                                            s3_timestamp.isoformat(),
                                        )
                                        skip_this_pair = False
                                    else:
                                        log.info(
                                            "S3 file %s is up-to-date or newer "
                                            "(local: %s, S3: %s). Skipping.",
                                            s3_path,
                                            local_mtime.isoformat(),
                                            s3_timestamp.isoformat(),
                                        )
                                        skip_this_pair = True
                                        skip_reason = "up-to-date"
                                else:
                                    # No metadata timestamp - treat S3 file as outdated
                                    log.info(
                                        "S3 file %s has no %s metadata. "
                                        "Treating as outdated. Uploading.",
                                        s3_path,
                                        args.metadata_key,
                                    )
                                    skip_this_pair = False
                            except Exception as e:
                                log.warning(
                                    "Error checking S3 metadata for %s: %s. "
                                    "Uploading to be safe.",
                                    s3_path,
                                    e,
                                )
                                skip_this_pair = False
                    else:
                        # --upload-if-newer not set, use old behavior
                        log.warning(
                            "File %s already exists and --force-overwrite not set."
                            " Skipping.",
                            s3_path,
                        )
                        skip_this_pair = True
                        skip_reason = "already exists"
                else:
                    # S3 file doesn't exist - always upload
                    # (if not empty when using --upload-if-newer)
                    if args.upload_if_newer:
                        local_size = os.path.getsize(local_path)
                        # Check if it's a stamp file (0 bytes or 14-byte bz2)
                        is_stamp = local_size == 0 or (
                            local_path.endswith(".bz2") and local_size == 14
                        )
                        if is_stamp:
                            log.info(
                                "Skipping stamp file: %s (%d bytes)",
                                local_path,
                                local_size,
                            )
                            skip_this_pair = True
                            skip_reason = "stamp file"

            if skip_this_pair:
                # Track skip reason
                if skip_reason == "stamp file":
                    stats["skipped_stamp"].append((local_path, s3_path))
                elif skip_reason == "up-to-date":
                    stats["skipped_uptodate"].append((local_path, s3_path))
                elif skip_reason == "already exists":
                    stats["skipped_existing"].append((local_path, s3_path))

                # If content file is skipped, also skip its log file
                if is_content_file:
                    log_local, log_s3 = file_pairs[pair_idx + 1]
                    log.info("Skipping log file %s (content file was skipped)", log_s3)
                    stats["skipped_paired"].append((log_local, log_s3))
                    pair_idx += 2  # Skip both content and log
                else:
                    pair_idx += 1
                continue

            # Use upload_with_retries for robust uploads
            uploaded = upload_with_retries(
                s3_client,
                local_path,
                s3_path,
            )
            if not uploaded:
                log.error(
                    f"Upload failed for {local_path} to {s3_path}. Skipping"
                    " further actions for this file."
                )
                stats["failed"].append((local_path, s3_path))
                # If content file upload fails, skip its log file too
                if is_content_file:
                    log_local, log_s3 = file_pairs[pair_idx + 1]
                    log.info(
                        "Skipping log file %s (content file upload failed)", log_s3
                    )
                    stats["skipped_paired"].append((log_local, log_s3))
                    pair_idx += 2
                else:
                    pair_idx += 1
                continue

            # Track successfully uploaded file
            uploaded_files.append((local_path, s3_path))
            stats["uploaded"].append((local_path, s3_path))

            # Track content files that were uploaded (for forcing log file uploads)
            if not is_log_file:
                uploaded_content_files.add(local_path)

            # Truncate all uploaded files to stamps if requested
            if args.keep_timestamp_only:
                log.info(
                    "Truncating %s and keeping only timestamp after upload",
                    local_path,
                )
                keep_timestamp_only(local_path)

            pair_idx += 1

        # Print comprehensive upload statistics
        log.info("=" * 80)
        log.info("UPLOAD STATISTICS SUMMARY")
        log.info("=" * 80)
        log.info("Total files processed: %d", len(file_pairs))
        log.info("")

        if stats["uploaded"]:
            log.info("✓ Successfully uploaded: %d file(s)", len(stats["uploaded"]))
            for local_path, s3_path in stats["uploaded"]:
                log.info("  - %s → %s", os.path.basename(local_path), s3_path)
        else:
            log.info("✓ Successfully uploaded: 0 files")
        log.info("")

        if stats["skipped_stamp"]:
            log.info(
                "⊘ Skipped (stamp files): %d file(s)",
                len(stats["skipped_stamp"]),
            )
            for local_path, s3_path in stats["skipped_stamp"]:
                log.info(
                    "  - %s (stamp file, %d bytes)",
                    os.path.basename(local_path),
                    os.path.getsize(local_path),
                )

        if stats["skipped_uptodate"]:
            log.info(
                "⊘ Skipped (up-to-date): %d file(s)",
                len(stats["skipped_uptodate"]),
            )
            for local_path, s3_path in stats["skipped_uptodate"]:
                log.info(
                    "  - %s (S3 version is current)",
                    os.path.basename(local_path),
                )

        if stats["skipped_existing"]:
            log.info(
                "⊘ Skipped (already exists): %d file(s)",
                len(stats["skipped_existing"]),
            )
            for local_path, s3_path in stats["skipped_existing"]:
                log.info(
                    "  - %s (use --force-overwrite to replace)",
                    os.path.basename(local_path),
                )

        if stats["skipped_paired"]:
            log.info(
                "⊘ Skipped (paired with skipped/failed file): %d file(s)",
                len(stats["skipped_paired"]),
            )
            for local_path, s3_path in stats["skipped_paired"]:
                log.info("  - %s", os.path.basename(local_path))

        if stats["failed"]:
            log.error("✗ Failed uploads: %d file(s)", len(stats["failed"]))
            for local_path, s3_path in stats["failed"]:
                log.error("  - %s → %s", os.path.basename(local_path), s3_path)

        log.info("=" * 80)

        # Clean up WIP files after successful upload
        if args.remove_wip:
            for local_path, s3_path in uploaded_files:
                if local_path.endswith((".txt.gz", ".jsonl.bz2", ".json.bz2")):
                    wip_path = s3_path + ".wip"
                    bucket, key = parse_s3_path(wip_path)
                    try:
                        s3_client.delete_object(Bucket=bucket, Key=key)
                        log.info("Removed WIP file: %s", wip_path)
                    except Exception as e:
                        log.warning("Failed to remove WIP file %s: %s", wip_path, e)
        # Set timestamps on S3 files if requested
        if args.set_timestamp:
            if uploaded_files:
                log.info(
                    "Setting timestamps on %d uploaded file(s)", len(uploaded_files)
                )
                file_mtimes = {}
                for local_path, s3_path in uploaded_files:
                    if os.path.exists(local_path):
                        file_mtimes[local_path] = os.path.getmtime(local_path)
                for local_path, s3_path in uploaded_files:
                    log.info("Processing timestamp for: %s", s3_path)
                    try:
                        if (
                            local_path.endswith((".jsonl.bz2", ".json"))
                            and args.ts_key != "__file__"
                        ):
                            timestamp_processor = S3TimestampProcessor(
                                s3_file=s3_path,
                                metadata_key=args.metadata_key,
                                ts_key=args.ts_key,
                                all_lines=False,
                                force=True,
                                log_level=args.log_level,
                                log_file=args.log_file,
                            )
                            timestamp_processor.update_metadata_for_file()
                            log.info("Successfully set timestamp for %s", s3_path)
                        else:
                            if local_path in file_mtimes:
                                file_mtime = file_mtimes[local_path]
                            else:
                                file_mtime = time.time()
                            file_timestamp = datetime.fromtimestamp(
                                file_mtime
                            ).strftime("%Y-%m-%dT%H:%M:%SZ")
                            log.info(
                                "Using file modification date %s for %s",
                                file_timestamp,
                                s3_path,
                            )
                            bucket, key = parse_s3_path(s3_path)
                            try:
                                existing_obj = s3_client.head_object(
                                    Bucket=bucket, Key=key
                                )
                                existing_metadata = existing_obj.get("Metadata", {})
                            except Exception:
                                existing_metadata = {}
                            new_metadata = existing_metadata.copy()
                            new_metadata[args.metadata_key] = file_timestamp
                            s3_client.copy_object(
                                Bucket=bucket,
                                Key=key,
                                CopySource={"Bucket": bucket, "Key": key},
                                Metadata=new_metadata,
                                MetadataDirective="REPLACE",
                            )
                            try:
                                updated_obj = s3_client.head_object(
                                    Bucket=bucket, Key=key
                                )
                                updated_metadata = updated_obj.get("Metadata", {})
                                if args.metadata_key in updated_metadata:
                                    log.info(
                                        "Successfully set file timestamp metadata for"
                                        " %s: %s = %s",
                                        s3_path,
                                        args.metadata_key,
                                        updated_metadata[args.metadata_key],
                                    )
                                else:
                                    log.error(
                                        "Metadata key %s not found after setting"
                                        " for %s",
                                        args.metadata_key,
                                        s3_path,
                                    )
                            except Exception as e:
                                log.error(
                                    "Could not verify metadata for %s: %s", s3_path, e
                                )
                    except Exception as e:
                        log.error("Failed to set timestamp for %s: %s", s3_path, e)
                log.info("Timestamp setting completed")
            else:
                log.info("No files were uploaded, skipping timestamp setting")
    except Exception as e:
        log.error("An error occurred: %s", e)
        log.error("Traceback: %s", traceback.format_exc())
        sys.exit(1)


if __name__ == "__main__":
    main()
