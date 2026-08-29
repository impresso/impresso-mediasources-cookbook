# AGENTS.md

## Repository Purpose

This repository is a Make-based processing cookbook for Impresso media-source
NER at corpus scale. It detects cited media sources in rebuilt newspaper content
using `impresso_pipelines.mediasources.MediaSourcesPipeline`.

The cookbook owns orchestration only: S3/local paths, stamps, streaming JSONL
I/O, outer batching, length bucketing, logging, and output upload. Model
tokenization, window batching, decoding, entity scoring, and `wkdata_qid`
enrichment belong to `impresso-pipelines`.

## Commands

Use `make` in documentation and examples.

Common targets:

- `make setup`
- `make sync-input NEWSPAPER=<paper>`
- `make processing-target NEWSPAPER=<paper>`
- `make newspaper NEWSPAPER=<paper>`

## Important Files

- `lib/cli_mediasources.py`: streaming media-source processing CLI.
- `cookbook/paths_mediasources.mk`: run identity and output path variables.
- `cookbook/processing_mediasources.mk`: rebuilt input to media-source output rule.
- `config/config_v2-0-0.mk`: default model/run configuration.

## Output

Output rows use `media_sources`, not the legacy `agencies` key. Each entity has
`surface`, `label`, `wkdata_qid`, `start`, `stop`, and `score`.

