#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import inspect
import json
import logging
import os
import random
import re
import sys
import time
from pathlib import Path
from collections.abc import Iterable
from typing import Any

DEBUG_TOKEN_CONTEXT = 2
REQUIRED_INFERENCE_STATS = {
    "documents",
    "tokens",
    "windows",
    "model_batches",
    "window_tokenize_seconds",
    "inference_seconds",
    "model_dispatch_seconds",
    "logits_to_cpu_seconds",
    "reconstruction_seconds",
    "decode_seconds",
    "viterbi_seconds",
    "postprocess_seconds",
    "pipeline_seconds",
}

from smart_open import open as smart_open  # type: ignore

COOKBOOK_LIB = Path(__file__).resolve().parents[1] / "cookbook" / "lib"
if COOKBOOK_LIB.exists():
    sys.path.insert(0, str(COOKBOOK_LIB))

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
    parser.add_argument(
        "--dtype",
        choices=["float32", "float16", "bfloat16"],
        default="float32",
        help="Model inference dtype (default: %(default)s)",
    )
    parser.add_argument(
        "--device",
        default="auto",
        help="Torch device for model inference: auto, -1/cpu, mps, cuda:0, or CUDA device index",
    )
    parser.add_argument("--outer-batch-size", type=int, default=4096, help="Documents buffered before bucketing")
    parser.add_argument(
        "--min-year",
        "--earliest-year-to-consider",
        dest="min_year",
        type=int,
        default=None,
        help="Skip processing and write an empty output when the input publication year is earlier than YEAR",
        metavar="YEAR",
    )
    parser.add_argument(
        "--sample",
        type=float,
        default=None,
        help="Randomly keep this fraction of non-empty documents before inference (0 < sample <= 1; default: 1.0)",
    )
    parser.add_argument(
        "--sample-seed",
        type=int,
        default=None,
        help="Optional random seed for --sample",
    )
    parser.add_argument("--min-score", type=float, default=None, help="Optional post-decoding entity score threshold")
    parser.add_argument(
        "--filter-anachronistic",
        action="store_true",
        help="Drop media-source entities whose configured start year is after the publication year",
    )
    parser.add_argument("--local-files-only", action="store_true", help="Use only cached Hugging Face model files")
    parser.add_argument("--diagnostics", action="store_true", help="Include token-level diagnostics in output rows")
    parser.add_argument(
        "--write-empty",
        action="store_true",
        help="Write rows for documents with no detected media-source entities",
    )
    return parser.parse_args(args)


def open_text(path: str, mode: str):
    return smart_open(path, mode, encoding="utf-8", transport_params=get_transport_params(path))


def non_empty_batches(
    items: Iterable[dict[str, Any]],
    batch_size: int,
    *,
    sample: float = 1.0,
    rng: random.Random | None = None,
) -> Iterable[tuple[list[dict[str, Any]], int, int, int]]:
    batch: list[dict[str, Any]] = []
    read_count = 0
    skipped_empty_since_batch = 0
    skipped_sampled_since_batch = 0
    for item in items:
        read_count += 1
        if not item["text"].strip():
            skipped_empty_since_batch += 1
            continue
        if sample < 1.0 and (rng or random).random() >= sample:
            skipped_sampled_since_batch += 1
            continue
        batch.append(item)
        if len(batch) >= batch_size:
            yield batch, read_count, skipped_empty_since_batch, skipped_sampled_since_batch
            skipped_empty_since_batch = 0
            skipped_sampled_since_batch = 0
            batch = []
    if batch:
        yield batch, read_count, skipped_empty_since_batch, skipped_sampled_since_batch
    elif skipped_empty_since_batch or skipped_sampled_since_batch:
        yield [], read_count, skipped_empty_since_batch, skipped_sampled_since_batch


def publication_year(value: Any) -> int | None:
    if value is None:
        return None
    match = re.search(r"(?<!\d)(1[5-9]\d{2}|20\d{2})(?!\d)", str(value))
    return int(match.group(1)) if match else None


def input_path_year(path: str) -> int | None:
    name = Path(path).name
    matches = re.findall(r"(?<!\d)(1[5-9]\d{2}|20\d{2})(?!\d)", name)
    return int(matches[-1]) if matches else None


def first_input_publication_year(path: str) -> int | None:
    for row in iter_input_rows(path):
        year = publication_year(row["publication_date"])
        if year is not None:
            return year
    return None


def text_preview(text: str, *, max_chars: int = 80) -> str:
    collapsed = " ".join(text.split())
    return collapsed if len(collapsed) <= max_chars else collapsed[: max_chars - 1] + "..."


def text_sha256(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def text_context(text: str, start: int | None, stop: int | None, *, radius: int = 40) -> str:
    if start is None or stop is None:
        return ""
    left = max(0, int(start) - radius)
    right = min(len(text), int(stop) + radius)
    return text[left:right].replace("\n", "\\n")


def debug_non_o_tokens(result: dict[str, Any]) -> list[dict[str, Any]]:
    tokens = result.get("tokens", [])
    starts = result.get("token_start_offsets", [])
    stops = result.get("token_end_offsets", [])
    labels = result.get("token_labels", [])
    scores = result.get("token_scores", [])
    rows: list[dict[str, Any]] = []
    for index, label in enumerate(labels):
        if label == "O":
            continue
        left = max(0, index - DEBUG_TOKEN_CONTEXT)
        right = min(len(tokens), index + DEBUG_TOKEN_CONTEXT + 1)
        rows.append(
            {
                "i": index,
                "token": tokens[index] if index < len(tokens) else "",
                "start": starts[index] if index < len(starts) else None,
                "stop": stops[index] if index < len(stops) else None,
                "label": label,
                "score": scores[index] if index < len(scores) else None,
                "context": " ".join(str(token) for token in tokens[left:right]),
            }
        )
    return rows


def entity_to_nel(entity: dict[str, Any]) -> dict[str, Any]:
    fine_grained_type = str(entity["label"])
    coarse_type = fine_grained_type.split(".", 1)[0] if "." in fine_grained_type else fine_grained_type
    return {
        "type": coarse_type,
        "fine_grained_type": fine_grained_type,
        "surface": entity["surface"],
        "lOffset": entity["start"],
        "rOffset": entity["stop"],
        "confidence_ner": entity["score"],
        "confidence_nel": entity["score"],
        "wkdata_qid": entity.get("wkdata_qid"),
        "wkpedia_lg": None,
        "wkpedia_pagename": None,
        "start_year": entity.get("start_year"),
    }


def model_dtype(model: Any) -> str:
    dtype = getattr(model, "dtype", None)
    if dtype is not None:
        return str(dtype)

    parameters = getattr(model, "parameters", None)
    if callable(parameters):
        try:
            return str(next(parameters()).dtype)
        except StopIteration:
            return "no parameters"
        except Exception as exc:
            return f"unavailable ({exc})"

    return "unavailable"


def length_summary(lengths: list[int]) -> str:
    if not lengths:
        return "[]"
    sorted_lengths = sorted(lengths)
    count = len(sorted_lengths)

    def percentile(percent: float) -> int:
        if count == 1:
            return sorted_lengths[0]
        position = (count - 1) * percent
        lower = int(position)
        upper = min(lower + 1, count - 1)
        fraction = position - lower
        return int(round(sorted_lengths[lower] * (1.0 - fraction) + sorted_lengths[upper] * fraction))

    mean = sum(sorted_lengths) / count
    return (
        f"count={count} min={sorted_lengths[0]} p25={percentile(0.25)} "
        f"median={percentile(0.50)} p75={percentile(0.75)} "
        f"p95={percentile(0.95)} max={sorted_lengths[-1]} mean={mean:.1f}"
    )


def fmt_int(value: int | float) -> str:
    return f"{value:,.0f}"


def fmt_seconds(value: float) -> str:
    return f"{value:.2f}s"


def fmt_seconds_percent(value: float, total: float) -> str:
    percent = (100.0 * value / total) if total else 0.0
    return f"{value:.1f}s ({percent:.1f}% pipeline)"


def validate_inference_stats(stats: dict[str, Any], pipeline: Any) -> None:
    missing_stats = REQUIRED_INFERENCE_STATS - stats.keys()
    if missing_stats:
        raise RuntimeError(
            "MediaSourcesPipeline returned incomplete inference diagnostics; "
            f"missing={sorted(missing_stats)} "
            f"pipeline_class={type(pipeline).__module__}.{type(pipeline).__qualname__} "
            f"pipeline_source={inspect.getfile(type(pipeline))}"
        )


def write_empty_output(path: str) -> None:
    with open_text(path, "wt"):
        pass


def env_int(name: str) -> int | None:
    value = os.environ.get(name)
    if value is None or not value.strip():
        return None
    return int(value)


def env_float(name: str) -> float | None:
    value = os.environ.get(name)
    if value is None or not value.strip():
        return None
    return float(value)


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
            content_id = row.get("ci_id", row.get("id", row.get("c_id", "")))
            publication_date = row.get("date", row.get("d", row.get("year", row.get("publication_date"))))
            yield {
                "ci_id": content_id,
                "publication_date": publication_date,
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
        dtype: str,
        batch_size: int,
        outer_batch_size: int,
        sample: float,
        sample_seed: int | None,
        device: str | int | None,
        min_score: float | None,
        filter_anachronistic: bool,
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
        if not 0.0 < sample <= 1.0:
            raise ValueError("sample must be greater than 0 and less than or equal to 1")
        if dtype == "float16" and str(device).lower() in {"-1", "cpu"}:
            raise ValueError("float16 dtype is not supported for CPU inference; use float32 or a CUDA device")

        self.input_file = input_file
        self.output_file = output_file
        self.hf_model = hf_model
        self.revision = revision
        self.requested_dtype = dtype
        self.batch_size = batch_size
        self.outer_batch_size = outer_batch_size
        self.sample = sample
        self.sample_seed = sample_seed
        self.min_score = min_score
        self.filter_anachronistic = filter_anachronistic
        self.diagnostics = diagnostics
        self.write_empty = write_empty
        self.timestamp = get_timestamp()

        setup_logging(log_level, log_file, logger=log)
        log.info("Initializing MediaSourcesPipeline model=%s revision=%s dtype=%s", hf_model, revision, dtype)
        log.info("Configured batch sizes: model_window_batch_size=%s outer_batch_size=%s", batch_size, outer_batch_size)
        log.info("Configured sampling: sample=%s sample_seed=%s", sample, sample_seed)
        log.info(
            "Threading environment: TOKENIZERS_PARALLELISM=%r RAYON_NUM_THREADS=%r "
            "OMP_NUM_THREADS=%r MKL_NUM_THREADS=%r",
            os.environ.get("TOKENIZERS_PARALLELISM"),
            os.environ.get("RAYON_NUM_THREADS"),
            os.environ.get("OMP_NUM_THREADS"),
            os.environ.get("MKL_NUM_THREADS"),
        )
        try:
            import impresso_pipelines  # type: ignore
            import torch  # type: ignore
            import transformers  # type: ignore

            log.info(
                "Runtime imports: impresso_pipelines=%s path=%s MediaSourcesPipeline=%s "
                "transformers=%s torch=%s cuda=%s",
                getattr(impresso_pipelines, "__version__", "unknown"),
                getattr(impresso_pipelines, "__file__", "unknown"),
                inspect.getfile(MediaSourcesPipeline),
                getattr(transformers, "__version__", "unknown"),
                getattr(torch, "__version__", "unknown"),
                getattr(torch.version, "cuda", None),
            )
        except Exception as exc:
            log.warning("Runtime import diagnostics unavailable: %s", exc)
        self.pipeline = MediaSourcesPipeline(
            model=hf_model,
            revision=revision,
            dtype=dtype,
            batch_size=batch_size,
            device=device,
            min_score=min_score,
            local_files_only=local_files_only,
        )
        model_config = getattr(getattr(self.pipeline, "model", None), "config", None)
        self.model_commit_hash = getattr(model_config, "_commit_hash", "unknown")
        self.observed_dtype = model_dtype(getattr(self.pipeline, "model", None))
        log.info("Model commit hash: %s", self.model_commit_hash)
        log.info("Model dtype: %s", self.observed_dtype)
        log.info(
            "Tokenizer runtime: class=%s is_fast=%s",
            type(getattr(self.pipeline, "tokenizer", None)).__name__,
            getattr(getattr(self.pipeline, "tokenizer", None), "is_fast", None),
        )
        self.model_id = f"{hf_model}@{revision}#{dtype}"
        log.debug(
            "Processor settings: input=%s output=%s batch_size=%s outer_batch_size=%s sample=%s sample_seed=%s "
            "min_score=%s device=%s filter_anachronistic=%s diagnostics=%s write_empty=%s local_files_only=%s",
            input_file,
            output_file,
            batch_size,
            outer_batch_size,
            sample,
            sample_seed,
            min_score,
            device,
            filter_anachronistic,
            diagnostics,
            write_empty,
            local_files_only,
        )
        log.debug(
            "Pipeline protocol: decoder=%s max_sequence_len=%s max_annotation_tokens=%s stride=%s device=%s",
            getattr(self.pipeline, "decoder", "unknown"),
            getattr(self.pipeline, "max_sequence_len", "unknown"),
            getattr(self.pipeline, "max_annotation_tokens", "unknown"),
            getattr(self.pipeline, "stride", "unknown"),
            getattr(self.pipeline, "device", "unknown"),
        )

    def run(self) -> None:
        started = time.perf_counter()
        read_count = 0
        processed_count = 0
        processed_chars = 0
        processed_tokens = 0
        processed_windows = 0
        model_batches = 0
        pipeline_seconds = 0.0
        tokenize_seconds = 0.0
        inference_seconds = 0.0
        window_tokenize_seconds = 0.0
        model_dispatch_seconds = 0.0
        logits_to_cpu_seconds = 0.0
        reconstruction_seconds = 0.0
        decode_seconds = 0.0
        viterbi_seconds = 0.0
        postprocess_seconds = 0.0
        written_count = 0
        skipped_empty_count = 0
        skipped_sampled_count = 0
        entity_counts: dict[str, int] = {}
        rng = random.Random(self.sample_seed) if self.sample_seed is not None else None

        with open_text(self.output_file, "wt") as output_stream:
            for outer_batch_index, (
                batch,
                latest_read_count,
                skipped_empty_since_batch,
                skipped_sampled_since_batch,
            ) in enumerate(
                non_empty_batches(iter_input_rows(self.input_file), self.outer_batch_size, sample=self.sample, rng=rng),
                start=1,
            ):
                read_count = latest_read_count
                skipped_empty_count += skipped_empty_since_batch
                skipped_sampled_count += skipped_sampled_since_batch
                if log.isEnabledFor(logging.DEBUG):
                    log.debug(
                        "Outer batch %s non-empty rows: %s",
                        outer_batch_index,
                        [
                            {
                                "ci_id": item["ci_id"],
                                "publication_date": item["publication_date"],
                                "length": item["length"],
                                "sha256": text_sha256(item["text"]),
                                "preview": text_preview(item["text"]),
                            }
                            for item in batch
                        ],
                    )
                if not batch:
                    log.info(
                        "Outer batch %s: docs=0 read_rows=%s skipped_empty_docs_since_previous=%s "
                        "skipped_sampled_docs_since_previous=%s",
                        outer_batch_index,
                        read_count,
                        skipped_empty_since_batch,
                        skipped_sampled_since_batch,
                    )
                    continue

                # Reorder only inside the outer batch. Results are joined back by
                # stable item IDs, so corpus-level output identity is unaffected.
                sorted_items = sorted(batch, key=lambda item: item["length"])
                batch_chars = sum(item["length"] for item in sorted_items)
                doc_lengths = [item["length"] for item in sorted_items]
                log.info(
                    "Outer batch %s: docs=%s read_rows=%s skipped_empty_docs_since_previous=%s "
                    "skipped_sampled_docs_since_previous=%s chars=%s model_window_batch_size=%s "
                    "outer_batch_size=%s sample=%s doc_lengths=%s",
                    outer_batch_index,
                    len(sorted_items),
                    read_count,
                    skipped_empty_since_batch,
                    skipped_sampled_since_batch,
                    fmt_int(batch_chars),
                    self.batch_size,
                    self.outer_batch_size,
                    self.sample,
                    length_summary(doc_lengths),
                )
                if log.isEnabledFor(logging.DEBUG):
                    log.debug("Outer batch %s sorted doc lengths: %s", outer_batch_index, sorted(doc_lengths))
                    log.debug(
                        "Outer batch %s sorted order: %s",
                        outer_batch_index,
                        [
                            {
                                "ci_id": item["ci_id"],
                                "publication_date": item["publication_date"],
                                "length": item["length"],
                                "sha256": text_sha256(item["text"]),
                            }
                            for item in sorted_items
                        ],
                    )
                texts = [item["text"] for item in sorted_items]
                publication_dates = [item["publication_date"] for item in sorted_items]

                batch_started = time.perf_counter()
                results = self.pipeline(
                    texts,
                    publication_date=publication_dates,
                    filter_anachronistic=self.filter_anachronistic,
                    diagnostics=self.diagnostics,
                )
                if not isinstance(results, list):
                    results = [results]
                duration = max(time.perf_counter() - batch_started, 1e-9)
                stats = getattr(self.pipeline, "last_inference_stats", {}) or {}
                validate_inference_stats(stats, self.pipeline)
                batch_tokens = int(stats.get("tokens") or 0)
                batch_windows = int(stats.get("windows") or 0)
                batch_model_batches = int(stats.get("model_batches") or 0)
                batch_pipeline_seconds = float(stats.get("pipeline_seconds") or duration)
                batch_tokenize_seconds = float(stats.get("tokenize_seconds") or 0.0)
                batch_inference_seconds = float(stats.get("inference_seconds") or 0.0)
                batch_window_tokenize_seconds = float(stats.get("window_tokenize_seconds") or 0.0)
                batch_model_dispatch_seconds = float(stats.get("model_dispatch_seconds") or 0.0)
                batch_logits_to_cpu_seconds = float(stats.get("logits_to_cpu_seconds") or 0.0)
                batch_reconstruction_seconds = float(stats.get("reconstruction_seconds") or 0.0)
                batch_decode_seconds = float(stats.get("decode_seconds") or 0.0)
                batch_viterbi_seconds = float(stats.get("viterbi_seconds") or 0.0)
                batch_postprocess_seconds = float(stats.get("postprocess_seconds") or 0.0)
                processed_count += len(sorted_items)
                processed_chars += batch_chars
                processed_tokens += batch_tokens
                processed_windows += batch_windows
                model_batches += batch_model_batches
                pipeline_seconds += batch_pipeline_seconds
                tokenize_seconds += batch_tokenize_seconds
                inference_seconds += batch_inference_seconds
                window_tokenize_seconds += batch_window_tokenize_seconds
                model_dispatch_seconds += batch_model_dispatch_seconds
                logits_to_cpu_seconds += batch_logits_to_cpu_seconds
                reconstruction_seconds += batch_reconstruction_seconds
                decode_seconds += batch_decode_seconds
                viterbi_seconds += batch_viterbi_seconds
                postprocess_seconds += batch_postprocess_seconds

                log.info(
                    "Processed outer batch %s: duration=%s docs=%s docs/s=%.1f chars=%s kchars/s=%.1f "
                    "tokens=%s windows=%s windows/s=%.1f model_batches=%s inference=%s model_dispatch=%s",
                    outer_batch_index,
                    fmt_seconds(duration),
                    len(sorted_items),
                    len(sorted_items) / duration,
                    fmt_int(batch_chars),
                    (batch_chars / 1000.0) / duration,
                    fmt_int(batch_tokens),
                    fmt_int(batch_windows),
                    batch_windows / duration if batch_windows else 0.0,
                    batch_model_batches,
                    fmt_seconds(batch_inference_seconds),
                    fmt_seconds(batch_model_dispatch_seconds),
                )
                if log.isEnabledFor(logging.DEBUG):
                    log.debug("Outer batch %s inference stats: %s", outer_batch_index, stats)
                    log.debug(
                        "Outer batch %s window detail: primary_windows=%s rescue_windows=%s model_batch_sizes=%s",
                        outer_batch_index,
                        int(stats.get("primary_windows") or 0),
                        max(0, batch_windows - int(stats.get("primary_windows") or 0)),
                        stats.get("model_batch_sizes"),
                    )
                    log.debug(
                        "Outer batch %s timing detail: tokenize=%s inference=%s window_tokenize=%s "
                        "model_dispatch=%s logits_to_cpu=%s reconstruction=%s decode=%s "
                        "viterbi=%s postprocess=%s pipeline=%s",
                        outer_batch_index,
                        fmt_seconds(batch_tokenize_seconds),
                        fmt_seconds(batch_inference_seconds),
                        fmt_seconds(batch_window_tokenize_seconds),
                        fmt_seconds(batch_model_dispatch_seconds),
                        fmt_seconds(batch_logits_to_cpu_seconds),
                        fmt_seconds(batch_reconstruction_seconds),
                        fmt_seconds(batch_decode_seconds),
                        fmt_seconds(batch_viterbi_seconds),
                        fmt_seconds(batch_postprocess_seconds),
                        fmt_seconds(batch_pipeline_seconds),
                    )

                for item, result in zip(sorted_items, results, strict=True):
                    entities = result.get("entities", [])
                    if log.isEnabledFor(logging.DEBUG):
                        text_hash = text_sha256(item["text"])
                        log.debug(
                            "Document result: ci_id=%s publication_date=%s length=%s sha256=%s "
                            "entities=%s inference_diagnostics=%s",
                            item["ci_id"],
                            item["publication_date"],
                            item["length"],
                            text_hash,
                            [
                                {
                                    "surface": entity.get("surface"),
                                    "label": entity.get("label"),
                                    "start": entity.get("start"),
                                    "stop": entity.get("stop"),
                                    "score": entity.get("score"),
                                    "wkdata_qid": entity.get("wkdata_qid"),
                                    "start_year": entity.get("start_year"),
                                    "context": text_context(
                                        item["text"],
                                        entity.get("start"),
                                        entity.get("stop"),
                                    ),
                                }
                                for entity in entities
                            ],
                            result.get("inference_diagnostics"),
                        )
                        if self.diagnostics:
                            log.debug(
                                "Document non-O tokens: ci_id=%s tokens=%s",
                                item["ci_id"],
                                debug_non_o_tokens(result),
                            )
                    if not entities and not self.write_empty:
                        continue
                    for entity in entities:
                        entity_counts[entity.get("label", "unknown")] = (
                            entity_counts.get(entity.get("label", "unknown"), 0) + 1
                        )
                    output_row = {
                        "ci_id": item["ci_id"],
                        "ts": self.timestamp,
                        "model_id": self.model_id,
                        "nes": [entity_to_nel(entity) for entity in entities],
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

        total_duration = max(time.perf_counter() - started, 1e-9)
        log.info("Completed media-source processing")
        log.info("Read rows: %s", read_count)
        log.info("Processed non-empty docs: %s", processed_count)
        log.info("Skipped empty docs: %s", skipped_empty_count)
        log.info("Skipped sampled-out non-empty docs: %s", skipped_sampled_count)
        sample_eligible_count = processed_count + skipped_sampled_count
        if self.sample < 1.0:
            kept_percent = 100.0 * processed_count / sample_eligible_count if sample_eligible_count else 0.0
            excluded_percent = 100.0 * skipped_sampled_count / sample_eligible_count if sample_eligible_count else 0.0
            log.info(
                "Sampling summary: sample=%s seed=%s eligible_non_empty_docs=%s "
                "processed_docs=%s sampled_out_docs=%s kept=%.1f%% excluded=%.1f%%",
                self.sample,
                self.sample_seed,
                sample_eligible_count,
                processed_count,
                skipped_sampled_count,
                kept_percent,
                excluded_percent,
            )
        else:
            log.info(
                "Sampling summary: disabled sample=%s eligible_non_empty_docs=%s sampled_out_docs=0",
                self.sample,
                sample_eligible_count,
            )
        log.info("Written rows: %s", written_count)
        log.info("Recognized media-source entities: %s", sum(entity_counts.values()))
        log.info("Inference configuration:")
        log.info("  model: %s", self.hf_model)
        log.info("  revision: %s", self.revision)
        log.info("  commit: %s", self.model_commit_hash)
        log.info("  requested_dtype: %s", self.requested_dtype)
        log.info("  observed_dtype: %s", self.observed_dtype)
        log.info("  device: %s", getattr(self.pipeline, "device", "unknown"))
        log.info("  model_window_batch_size: %s", self.batch_size)
        log.info("  outer_batch_size: %s", self.outer_batch_size)
        log.info("  sample: %s", self.sample)
        log.info("  sample_seed: %s", self.sample_seed)
        log.info("Workload:")
        log.info("  Characters: %s", fmt_int(processed_chars))
        log.info("  Tokens: %s", fmt_int(processed_tokens))
        log.info("  Model windows: %s", fmt_int(processed_windows))
        log.info("  Model batches: %s", fmt_int(model_batches))
        if model_batches:
            log.info("  Mean windows per batch: %.1f", processed_windows / model_batches)
            log.info("  Batch fill: %.1f%%", 100.0 * processed_windows / (model_batches * self.batch_size))
        accounted_pipeline_seconds = tokenize_seconds + inference_seconds + decode_seconds
        unaccounted_pipeline_seconds = max(0.0, pipeline_seconds - accounted_pipeline_seconds)
        log.info("Timing:")
        log.info("  Total: %.1fs", total_duration)
        log.info("  Pipeline: %.1fs", pipeline_seconds)
        log.info("    Annotation tokenizing: %s", fmt_seconds_percent(tokenize_seconds, pipeline_seconds))
        log.info("    Inference/windowing: %s", fmt_seconds_percent(inference_seconds, pipeline_seconds))
        log.info("      HF window tokenizing: %s", fmt_seconds_percent(window_tokenize_seconds, pipeline_seconds))
        log.info("      Model dispatch: %s (async)", fmt_seconds_percent(model_dispatch_seconds, pipeline_seconds))
        log.info("      Logits -> CPU: %s", fmt_seconds_percent(logits_to_cpu_seconds, pipeline_seconds))
        log.info("      Reconstruction: %s", fmt_seconds_percent(reconstruction_seconds, pipeline_seconds))
        log.info("    Decode: %s", fmt_seconds_percent(decode_seconds, pipeline_seconds))
        log.info("      Viterbi: %s", fmt_seconds_percent(viterbi_seconds, pipeline_seconds))
        log.info("      Post-processing: %s", fmt_seconds_percent(postprocess_seconds, pipeline_seconds))
        log.info("    Unaccounted: %s", fmt_seconds_percent(unaccounted_pipeline_seconds, pipeline_seconds))
        log.info("Throughput:")
        log.info("  %.1f docs/s", processed_count / total_duration)
        if processed_chars:
            log.info("  %.1f kchars/s", (processed_chars / 1000.0) / total_duration)
        if processed_windows:
            log.info("  %.1f windows/s end-to-end", processed_windows / total_duration)
        if processed_windows and inference_seconds:
            log.info("  %.1f windows/s inference", processed_windows / inference_seconds)
        if processed_windows and model_dispatch_seconds:
            log.info("  %.1f windows/s model-dispatch async", processed_windows / model_dispatch_seconds)
        if entity_counts:
            log.info("Entity type summary:")
            for label, count in sorted(entity_counts.items(), key=lambda item: item[1], reverse=True):
                log.info("  %s: %s", label, count)


def main(args: list[str] | None = None) -> None:
    options = parse_args(args)
    if options.min_year is None:
        options.min_year = env_int("MIN_YEAR_MEDIASOURCES")
    if options.sample is None:
        env_sample = env_float("SAMPLE_MEDIASOURCES")
        options.sample = 1.0 if env_sample is None else env_sample
    if options.sample_seed is None:
        options.sample_seed = env_int("SAMPLE_SEED_MEDIASOURCES")

    # Configure logging before model initialization so CLI arguments are captured
    # even if pipeline construction fails.
    setup_logging(options.log_level, options.log_file, logger=log)
    log.info("%s", options)
    if not 0.0 < options.sample <= 1.0:
        raise ValueError("--sample must be greater than 0 and less than or equal to 1")

    if options.min_year is not None:
        input_year = input_path_year(options.input)
        year_source = "input path"
        if input_year is None:
            input_year = first_input_publication_year(options.input)
            year_source = "first input row"
        if input_year is None:
            log.warning(
                "Could not determine input publication year for --min-year=%s; processing normally",
                options.min_year,
            )
        elif input_year < options.min_year:
            log.info(
                "Skipping media-source processing for input_year=%s from %s because it is earlier than "
                "--min-year=%s; writing empty output %s",
                input_year,
                year_source,
                options.min_year,
                options.output,
            )
            write_empty_output(options.output)
            return
        else:
            log.info(
                "Input year check passed: input_year=%s from %s >= min_year=%s",
                input_year,
                year_source,
                options.min_year,
            )

    device = None if str(options.device).lower() == "auto" else options.device
    if isinstance(device, str) and device.lstrip("-").isdigit():
        device = int(device)
    processor = MediaSourcesProcessor(
        input_file=options.input,
        output_file=options.output,
        hf_model=options.hf_model,
        revision=options.revision,
        dtype=options.dtype,
        batch_size=options.batch_size,
        outer_batch_size=options.outer_batch_size,
        sample=options.sample,
        sample_seed=options.sample_seed,
        device=device,
        min_score=options.min_score,
        local_files_only=options.local_files_only,
        filter_anachronistic=options.filter_anachronistic,
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
