# CRO Loop

Conversion-rate-optimization loop for the xaas surface. This directory is the family map; behavior lives in the artifacts it points to.

## The Loop

- [`CRO-LOOP.md`](CRO-LOOP.md) — loop definition and cadence: observe → hypothesize → instrument → ship → measure, one cycle at a time.

## Evidence

- [`artifacts/`](artifacts/) — experiment manifest and measurement artifacts. Every shipped claim cites an artifact path here.

## Cycles

- [`CYCLE-LOG.md`](CYCLE-LOG.md) — per-cycle record: hypothesis, change, result, receipt path.

## Rule of the house

Every claim ships only with its receipt path; a claim with no artifact is `BLOCKED(NO_EVIDENCE_ARTIFACT)`. Evidence lives in the sjira corpus — marketing copy never cites unbacked numbers. Ship/remove lists per claim: [`artifacts/evidence-claims-index.md`](artifacts/evidence-claims-index.md).

## See Also

- [`../claude/diataxis/README.md`](../claude/diataxis/README.md) — canonical documentation map.
