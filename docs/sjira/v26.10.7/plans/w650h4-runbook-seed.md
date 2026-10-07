# W650h4 — Runbook Seed Disambiguation

Lane: W650h4 (v26.10.7 fleet seal). Executes W650h3's recorded recommendation.
No commits made; no mix commands run (per lane constraints).

## Actions

1. `docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` — added a 3-line status note
   directly under the H1 stating this file is the v26.10.7 campaign's runbook
   seed (Conventions section carries the sweep-lanes rule) and that the
   consolidated v26.10.6 campaign runbook remains at
   `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md`.
2. `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md` — appended a `## Conventions`
   section (2 lines) stating the sweep-lanes rule in the v26.10.6 receipt
   writers' context, citing W650g3 (wrong-dir miss), W650g4 (correction),
   W650h3 (codification).

Neither file deleted or merged. Both files otherwise untouched.

## Final state (re-read from disk after edits)

`docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` (full):

```markdown
# v26.10.7 Fleet Seal — Integration Runbook

> **Status**: this is the v26.10.7 campaign's runbook seed (the Conventions
> section below carries the sweep-lanes rule). The consolidated v26.10.6
> campaign runbook remains at `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md`.

## Conventions

Sweep lanes: campaign-versioned receipt dirs — v26.10.6 lanes write to `docs/sjira/v26.10.6/plans` even during later seals; enumerate all `docs/sjira/*/plans/` dirs (W650g3 wrong-dir miss, corrected by W650g4).
```

`docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md` — appended tail:

```markdown

## Conventions

Sweep lanes: receipt sweeps must enumerate all `docs/sjira/*/plans/` dirs — v26.10.6 lanes keep writing here even during later campaign seals (W650g3 wrong-dir miss, corrected by W650g4; codified by W650h3).
```

(Pre-existing content above the appended section unchanged; prior tail was the
W982b shared-index-commit standing rule section.)

## Standing

ALIVE for the seed-disambiguation edit (edits on disk, re-read and reported
verbatim above). UNCOMMITTED by design — coordinator owns the integration
commit per same-checkout fan-out law.
