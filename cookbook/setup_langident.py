#!/usr/bin/env python3
"""Warm Hugging Face caches for the language-identification pipeline.

This script initializes the Hugging Face-backed models used by the language
identification workflow once, serially, so later parallel workers can reuse the
local cache instead of racing on remote downloads.

It warms:

- The floret-based ``LangIdentPipeline`` model.
- Optionally the OCR QA pipeline and the latest BloomFilter for each selected
  language.

The script is intended to be called from ``make setup`` before large parallel
processing runs.
"""

from __future__ import annotations

import argparse
import inspect
import logging
import sys
from typing import Iterable, Optional

from huggingface_hub import hf_hub_download

from impresso_pipelines.langident import (  # type: ignore[import-untyped]
    LangIdentPipeline,
)

try:
    from impresso_pipelines.ocrqa import (  # type: ignore[import-untyped]
        OCRQAPipeline,
    )

    OCRQA_AVAILABLE = True
except ImportError:
    OCRQA_AVAILABLE = False
    OCRQAPipeline = None  # type: ignore[assignment]


log = logging.getLogger(__name__)

DEFAULT_LANGIDENT_REPO = "impresso-project/impresso-floret-langident"
DEFAULT_LANGIDENT_REVISION = "main"
DEFAULT_OCRQA_REPO = "impresso-project/OCR-quality-assessment-unigram"
DEFAULT_OCRQA_REVISION = "main"
DEFAULT_DUMMY_TEXT = "Dies ist un texte di prova in English pour warm the cache."


def parse_args(argv: Optional[list[str]] = None) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description=(
            "Warm the Hugging Face cache for impresso language identification models."
        )
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        choices=["DEBUG", "INFO", "WARNING", "ERROR"],
        help="Logging level (default: %(default)s)",
    )
    parser.add_argument(
        "--langident-repo",
        default=DEFAULT_LANGIDENT_REPO,
        help="Repository for LangIdentPipeline (default: %(default)s)",
    )
    parser.add_argument(
        "--langident-revision",
        default=DEFAULT_LANGIDENT_REVISION,
        help="Revision for LangIdentPipeline (default: %(default)s)",
    )
    parser.add_argument(
        "--langident-model-id",
        default=None,
        help=(
            "Optional explicit langident model filename. If omitted, the pipeline"
            " selects the latest model."
        ),
    )
    parser.add_argument(
        "--ocrqa",
        action="store_true",
        help="Also warm the OCR QA pipeline and BloomFilters.",
    )
    parser.add_argument(
        "--ocrqa-repo",
        default=DEFAULT_OCRQA_REPO,
        help="Repository for OCRQAPipeline (default: %(default)s)",
    )
    parser.add_argument(
        "--ocrqa-revision",
        default=DEFAULT_OCRQA_REVISION,
        help="Revision for OCRQAPipeline (default: %(default)s)",
    )
    parser.add_argument(
        "--ocrqa-languages",
        nargs="+",
        default=None,
        help=(
            "Warm OCR QA BloomFilters only for these languages. By default the"
            " script warms all languages supported by the selected OCRQA repo."
        ),
    )
    parser.add_argument(
        "--dummy-text",
        default=DEFAULT_DUMMY_TEXT,
        help="Sample text used to trigger lazy model initialization.",
    )
    parser.add_argument(
        "--skip-run",
        action="store_true",
        help=(
            "Instantiate the pipelines but do not run a sample inference. Useful"
            " for debugging constructor-time downloads only."
        ),
    )
    return parser.parse_args(argv)


def setup_logging(log_level: str) -> None:
    """Configure logging for the script."""
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format="%(asctime)s %(levelname)s %(message)s",
    )


def _build_kwargs(callable_obj, **kwargs: object) -> dict[str, object]:
    """Return only keyword arguments supported by the callable signature."""
    signature = inspect.signature(callable_obj)
    return {
        key: value
        for key, value in kwargs.items()
        if value is not None and key in signature.parameters
    }


def warm_langident_cache(
    repo_id: str,
    revision: str,
    model_id: Optional[str],
    dummy_text: str,
    skip_run: bool,
) -> None:
    """Initialize the language-identification pipeline and its model cache."""
    kwargs = _build_kwargs(
        LangIdentPipeline,
        repo_id=repo_id,
        revision=revision,
        model_id=model_id,
        local_files_only=False,
    )

    log.info(
        "Warming LangIdentPipeline cache from repo=%s revision=%s",
        repo_id,
        revision,
    )
    pipeline = LangIdentPipeline(**kwargs)

    if not skip_run:
        result = pipeline(dummy_text)
        log.info(
            "LangIdentPipeline ready with model=%s sample_language=%s sample_score=%s",
            getattr(pipeline, "model_name", "<unknown>"),
            result.get("language"),
            result.get("score"),
        )


def _select_latest_ocrqa_version(pipeline: object, language: str) -> str:
    """Resolve the latest OCRQA BloomFilter version for a language."""
    versions = pipeline._get_available_versions(language)  # type: ignore[attr-defined]
    if not versions:
        raise ValueError(f"No OCRQA BloomFilter versions found for language {language}")
    return pipeline._select_latest_version(versions)  # type: ignore[attr-defined]


def _build_bloomfilter_filename(pipeline: object, version: str, language: str) -> str:
    """Build the OCRQA BloomFilter filename through the upstream helper."""
    return pipeline._build_bloomfilter_filename(  # type: ignore[attr-defined]
        version, language
    )


def _normalize_languages(
    requested_languages: Optional[Iterable[str]], supported_languages: Iterable[str]
) -> list[str]:
    """Return the OCRQA languages to warm in deterministic order."""
    supported = sorted(set(supported_languages))
    if requested_languages is None:
        return supported

    requested = sorted(set(requested_languages))
    missing = [lang for lang in requested if lang not in supported]
    if missing:
        raise ValueError(
            "Unsupported OCRQA languages requested: "
            f"{', '.join(missing)}. Supported: {', '.join(supported)}"
        )
    return requested


def warm_ocrqa_cache(
    repo_id: str,
    revision: str,
    languages: Optional[Iterable[str]],
    dummy_text: str,
    skip_run: bool,
) -> None:
    """Initialize OCRQA and prefetch the latest BloomFilter for each language."""
    if not OCRQA_AVAILABLE:
        raise RuntimeError(
            "impresso_pipelines.ocrqa is not installed but --ocrqa was requested"
        )

    kwargs = _build_kwargs(
        OCRQAPipeline,
        repo_id=repo_id,
        revision=revision,
        local_files_only=False,
    )

    log.info(
        "Warming OCRQAPipeline cache from repo=%s revision=%s",
        repo_id,
        revision,
    )
    pipeline = OCRQAPipeline(**kwargs)
    supported_languages = _normalize_languages(languages, pipeline.SUPPORTED_LANGUAGES)
    log.info("OCRQAPipeline supports languages: %s", ", ".join(supported_languages))

    for language in supported_languages:
        version = _select_latest_ocrqa_version(pipeline, language)
        filename = _build_bloomfilter_filename(pipeline, version, language)
        path = hf_hub_download(repo_id=repo_id, filename=filename, revision=revision)
        log.info(
            "Cached OCRQA BloomFilter language=%s version=%s path=%s",
            language,
            version,
            path,
        )
        if not skip_run:
            result = pipeline(dummy_text, language=language, version=version)
            log.info(
                "OCRQA sample ready language=%s version=%s score=%s",
                language,
                version,
                result.get("score"),
            )


def main(argv: Optional[list[str]] = None) -> int:
    """Run the cache warmup routine."""
    args = parse_args(argv)
    setup_logging(args.log_level)

    try:
        warm_langident_cache(
            repo_id=args.langident_repo,
            revision=args.langident_revision,
            model_id=args.langident_model_id,
            dummy_text=args.dummy_text,
            skip_run=args.skip_run,
        )

        if args.ocrqa:
            warm_ocrqa_cache(
                repo_id=args.ocrqa_repo,
                revision=args.ocrqa_revision,
                languages=args.ocrqa_languages,
                dummy_text=args.dummy_text,
                skip_run=args.skip_run,
            )

        log.info("Language-identification cache warmup completed successfully")
        return 0
    except Exception as exc:
        log.error("Language-identification cache warmup failed: %s", exc)
        if log.isEnabledFor(logging.DEBUG):
            log.exception("Warmup failure details")
        return 1


if __name__ == "__main__":
    sys.exit(main())
