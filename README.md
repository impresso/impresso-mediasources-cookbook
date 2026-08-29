# Impresso Media Sources Cookbook

Corpus-scale processing cookbook for Impresso media-source NER.

This repository streams rebuilt Impresso JSONL files, runs
`impresso_pipelines.mediasources.MediaSourcesPipeline`, and writes compact JSONL
output containing detected press-agency and radio-station mentions.

## Model

Default model:

```text
impresso-project/mmbert-impresso-mediasources-ner
```

Default revision:

```text
v2.0.0
```

The reusable pipeline owns annotation tokenization, 512-subtoken model windows,
window batching, BIO decoding, entity scoring, and `wkdata_qid` enrichment.

During development, `impresso-pipelines[mediasources]` is installed directly
from the `mediasourcespipeline` branch of
`https://github.com/impresso/impresso-pipelines`.

## Usage

Process locally available rebuilt files for one newspaper:

```bash
make CFG=configs/config_mediasources-ner-mmbert-impresso-mediasources-ner_v2-0-0_v1-0-0.mk processing-target NEWSPAPER=GDL
```

Full sync/process/upload workflow:

```bash
make CFG=configs/config_mediasources-ner-mmbert-impresso-mediasources-ner_v2-0-0_v1-0-0.mk newspaper NEWSPAPER=GDL
```

## CLI

The core command is:

```bash
python3 lib/cli_mediasources.py \
  --input input.jsonl.bz2 \
  --output output.jsonl.bz2 \
  --hf-model impresso-project/mmbert-impresso-mediasources-ner \
  --revision v2.0.0 \
  --batch-size 32 \
  --outer-batch-size 4096
```

`--batch-size` controls model window batch size inside
`MediaSourcesPipeline`. `--outer-batch-size` controls how many documents the
cookbook buffers before length sorting and processing.

## Output Shape

Rows are written only for documents with detected entities unless `--write-empty`
is passed.

```json
{
  "id": "doc-id",
  "ts": "2026-08-29T12:00:00",
  "media_sources": [
    {
      "surface": "Reuters",
      "label": "org.ent.pressagency.reuters",
      "wkdata_qid": "Q130879",
      "start": 120,
      "stop": 127,
      "score": 0.94
    }
  ],
  "summary": [
    {
      "uid": "org.ent.pressagency.reuters",
      "wkdata_qid": "Q130879",
      "score": 0.94
    }
  ]
}
```
