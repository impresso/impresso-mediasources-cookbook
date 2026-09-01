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

## Installation

Create the local environment with Pipenv:

```bash
pipenv install --dev
```

This installs the corpus-processing dependencies plus the development notebook
tools, including `ipykernel` and `ipython`.

If you prefer a plain virtual environment, install the runtime requirements and
then add the notebook tools:

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
pip install ipykernel ipython
```

For local development against a sibling checkout of `impresso-pipelines`, install
that checkout in editable mode with the media-source extra:

```bash
pip install -e ../impresso-pipelines[mediasources]
```

## Manual Diagnostics Notebook

The manual token-diagnostics notebook is available at:

```text
notebooks/manual_token_diagnostics.ipynb
```

Start Jupyter from the cookbook environment:

```bash
pipenv run jupyter notebook
```

Open the notebook, paste one rebuilt content-item JSON object into
`CONTENT_ITEM_JSON`, and run the cells. The notebook reads the full text from
`ft`, runs `MediaSourcesPipeline` with `diagnostics=True`, and displays entity,
summary, highlighted-text, token-diagnostics, and raw JSON views.

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
