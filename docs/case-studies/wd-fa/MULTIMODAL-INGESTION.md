# Representative Multimodal Ingestion

The XaaS WD reference now includes a real repository fixture with three source modalities:

1. `build_history.csv` — structured drive/build provenance;
2. `fa_report.md` — narrative failure-analysis text;
3. `timeout_waveform.svg` — an image/plot artifact.

The ingestion module computes a source digest and creates a normalized projection while preserving the original file and modality.

This is intentionally smaller than the real WD corpus described in the prompt. It proves the architectural mechanics; it does not claim PowerPoint/Confluence/Excel production connectors are already implemented.
