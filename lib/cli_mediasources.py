#!/usr/bin/env python3
from __future__ import annotations

import argparse
import bz2
import json
import logging
import sys
import time
from collections.abc import Iterable
from typing import Any

from smart_open import open as smart_open  # type: ignore

try:
    from impresso_cookbook import get_timestamp, get_transport_params, setup_logging  # type: ignore
except ImportError:
    from common import get_timestamp, get_transport_params, setup_logging  # type: ignore
from impresso_pipelines.mediasources import MediaSourcesPipeline  # type: ignore


log = logging.getLogger(__name__)


def parse_args(args: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run Impresso media-source NER on rebuilt JSONL.")
    parser.add_argument("-i", "--input", required=True, help="Input JSONL or JSONL.BZ2 file, local or S3")
    parser.add_argument("-o", "--output", required=True, help="Output JSONL or JSONL.BZ2 file, local or S3")
    parser.add_argument("--log-file", help="Write log to FILE", metavar="FILE")
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: %(default)s)",
    )
    parser.add_argument("--hf-model", default="impresso-project/mmbert-impresso-mediasources-ner")
    parser.add_argument("--revision", default="v2.0.0")
    parser.add_argument("--batch-size", type=int, default=32, help="Model window batch size")
    parser.add_argument("--outer-batch-size", type=int, default=4096, help="Documents buffered before bucketing")
    parser.add_argument("--min-score", type=float, default=None, help="Optional post-decoding entity score threshold")
    parser.add_argument("--local-files-only", action="store_true", help="Use only cached Hugging Face model files")
    parser.add_argument("--diagnostics", action="store_true", help="Include token-level diagnostics in output rows")
    parser.add_argument(
        "--write-empty",
        action="store_true",
        help="Write rows for documents with no detected media-source entities",
    )
    return parser.parse_args(args)


def open_text(path: str, mode: str):
    transport_params = get_transport_params(path)
    if path.endswith(".bz2"):
        binary_mode = mode.replace("t", "").replace("b", "") + "b"
        raw = smart_open(path, binary_mode, transport_params=transport_params)
        return bz2.open(raw, mode, encoding="utf-8")
    return smart_open(path, mode, encoding="utf-8", transport_params=transport_params)


def batched(items: Iterable[dict[str, Any]], batch_size: int) -> Iterable[list[dict[str, Any]]]:
    batch: list[dict[str, Any]] = []
    for item in items:
        batch.append(item)
        if len(batch) >= batch_size:
            yield batch
            batch = []
    if batch:
        yield batch


def iter_input_rows(path: str) -> Iterable[dict[str, Any]]:
    with open_text(path, "rt") as stream:
        for line_number, line in enumerate(stream, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{line_number}: invalid JSON") from exc
            if not isinstance(row, dict):
                raise ValueError(f"{path}:{line_number}: expected JSON object")
            text = row.get("ft", "")
            content_id = row.get("id", row.get("c_id", ""))
            yield {
                "id": content_id,
                "text": text if isinstance(text, str) else "",
                "length": len(text) if isinstance(text, str) else 0,
            }


class MediaSourcesProcessor:
    def __init__(
        self,
        *,
        input_file: str,
        output_file: str,
        hf_model: str,
        revision: str,
        batch_size: int,
        outer_batch_size: int,
        min_score: float | None,
        local_files_only: bool,
        diagnostics: bool,
        write_empty: bool,
        log_level: str,
        log_file: str | None,
    ) -> None:
        if batch_size <= 0:
            raise ValueError("batch_size must be positive")
        if outer_batch_size <= 0:
            raise ValueError("outer_batch_size must be positive")

        self.input_file = input_file
        self.output_file = output_file
        self.batch_size = batch_size
        self.outer_batch_size = outer_batch_size
        self.min_score = min_score
        self.diagnostics = diagnostics
        self.write_empty = write_empty
        self.timestamp = get_timestamp()

        setup_logging(log_level, log_file, logger=log)
        log.info("Initializing MediaSourcesPipeline model=%s revision=%s", hf_model, revision)
        self.pipeline = MediaSourcesPipeline(
            model=hf_model,
            revision=revision,
            batch_size=batch_size,
            min_score=min_score,
            local_files_only=local_files_only,
        )
        commit_hash = getattr(self.pipeline.model.config, "_commit_hash", "unknown")
        log.info("Model commit hash: %s", commit_hash)

    def run(self) -> None:
        started = time.time()
        read_count = 0
        processed_count = 0
        written_count = 0
        skipped_empty_count = 0
        entity_counts: dict[str, int] = {}

        with open_text(self.output_file, "wt") as output_stream:
            for outer_batch_index, batch in enumerate(
                batched(iter_input_rows(self.input_file), self.outer_batch_size),
                start=1,
            ):
                read_count += len(batch)
                non_empty = [item for item in batch if item["text"].strip()]
                skipped_empty_count += len(batch) - len(non_empty)
                if not non_empty:
                    continue

                # Reorder only inside the outer batch. Results are joined back by
                # stable item IDs, so corpus-level output identity is unaffected.
                sorted_items = sorted(non_empty, key=lambda item: item["length"])
                texts = [item["text"] for item in sorted_items]

                batch_started = time.time()
                results = self.pipeline(texts, diagnostics=self.diagnostics)
                if not isinstance(results, list):
                    results = [results]
                duration = max(time.time() - batch_started, 1e-9)
                processed_count += len(sorted_items)

                log.info(
                    "Processed outer batch %s: %s docs in %.2fs (%.1f docs/s)",
                    outer_batch_index,
                    len(sorted_items),
                    duration,
                    len(sorted_items) / duration,
                )

                for item, result in zip(sorted_items, results, strict=True):
                    entities = result.get("entities", [])
                    if not entities and not self.write_empty:
                        continue
                    for entity in entities:
                        entity_counts[entity.get("label", "unknown")] = (
                            entity_counts.get(entity.get("label", "unknown"), 0) + 1
                        )
                    output_row = {
                        "id": item["id"],
                        "ts": self.timestamp,
                        "media_sources": entities,
                        "summary": result.get("summary", []),
                    }
                    if self.diagnostics:
                        output_row["diagnostics"] = {
                            key: result[key]
                            for key in (
                                "tokens",
                                "token_start_offsets",
                                "token_end_offsets",
                                "token_labels",
                                "token_scores",
                            )
                            if key in result
                        }
                    output_stream.write(json.dumps(output_row, ensure_ascii=False) + "\n")
                    written_count += 1

        total_duration = max(time.time() - started, 1e-9)
        log.info("Completed media-source processing")
        log.info("Read rows: %s", read_count)
        log.info("Processed non-empty docs: %s", processed_count)
        log.info("Skipped empty docs: %s", skipped_empty_count)
        log.info("Written rows: %s", written_count)
        log.info("Throughput: %.1f docs/s", processed_count / total_duration)
        if entity_counts:
            log.info("Entity type summary:")
            for label, count in sorted(entity_counts.items(), key=lambda item: item[1], reverse=True):
                log.info("  %s: %s", label, count)


def main(args: list[str] | None = None) -> None:
    options = parse_args(args)
    processor = MediaSourcesProcessor(
        input_file=options.input,
        output_file=options.output,
        hf_model=options.hf_model,
        revision=options.revision,
        batch_size=options.batch_size,
        outer_batch_size=options.outer_batch_size,
        min_score=options.min_score,
        local_files_only=options.local_files_only,
        diagnostics=options.diagnostics,
        write_empty=options.write_empty,
        log_level=options.log_level,
        log_file=options.log_file,
    )
    processor.run()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        log.error("Processing error: %s", exc, exc_info=True)
        sys.exit(2)
