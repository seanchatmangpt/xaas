# R26 Doc-Surface Policy + Module-Gate Receipt

Date: 2026-10-09 · Lane R26-r (restart) · Repo /Users/sac/xaas @ 26f9b75e

## Identity

- Base: `26f9b75e` (main, R52 landing).
- Extractor pin: ggen-marketplace `scripts/gen_doc_surface.py`
  sha256 `3d2abae19dac9f529b8250a0f96a02b34dbf86348dad241fbdb003410dc35590`
  — ledger-current (`check_pin_freshness.sh` exit 0, run 2026-10-09).
  R52's landing was pinned at the earlier `b88297e6…`; this receipt is at
  the current ledger pin.

## Policy decision (receipted)

`.doc-surface.toml` (repo root, this commit) records the audited-surface
policy: audited doc roots = docs/reference, docs/claude/diataxis, docs/airo,
docs/hddl, docs/rfc, docs/eu_ai_act, docs/ci; docs/sjira, docs/jira,
docs/archive, docs/cro, docs/ultracode, docs/vision, docs/case-studies,
docs/streams, docs/release, and docs/claude-minus-diataxis are scoped out BY
DECISION as the historical/receipt plane, never counted in coverage or
hallucination denominators. Gate thresholds are NOT relaxed. The only
extractor-machine-honored section is `[[generated]]`;
`audited_doc_roots`/`excluded_doc_roots` bind the audit RUNNER
(`--docs-dir`), per the PIPELINE BINDING comment in the file.

## Module-gate result (before / after)

- Before (whole-docs scan, 2026-10-09): 1013 modules, 9 uncovered —
  WdFa.CapabilitySelector, FOND.Backoff, ProviderFabric.Backoff,
  SelfDigest.Promotion, ProviderMesh.{Backoff, PrioritySelector,
  RetryPolicy, Selector}, NotificationExtension.Resource.Persist.
  (StopCourt / SemanticCrown / MachineExperience.Episode were already
  covered — re-derived, not carried from R64's witness.)
- Grounding prose for all 9 added to the AGENT-COMMENTARY slots of
  docs/reference/modules/explanation.md and how_to.md (honest claims from
  real source reads; no fabricated behavior).
- After (policy-scoped gate: extractor 3d2abae1, --code-json from
  `gen_doc_surface.py code`, --docs-dir = the 7 audited roots):
  **FAIL** — 1013 modules, 64 uncovered. The 9 grounded modules each carry
  >= 1 grounded claim (e.g. FOND.Backoff 8, RetryPolicy 4,
  CapabilitySelector 2, Promotion 2, Persist 3). The 64 are a NEW exposure:
  modules previously "covered" only by prose in docs/sjira and other now
  scoped-out planes. Largest blocks: Xaas.Runtime.ProviderFabric (9),
  Xaas.Governance.Types (14), Xaas.Ultracode.CapitalCensus.Types (6),
  ProviderMesh remainder (6), FOND remainder (4), plus senders/mailer,
  AwsRepo, ILSRepo, ErrorHTML, Gettext, SIP2TestServer, CorpusLoader
  (test support is in the code-surface denominator — open extractor-scope
  question, not silently excluded).

## Verdict

FAIL-honest landing per pre-authorized discipline. The policy decision is
landed as the config receipt; the module gate at the narrowed scope FAILS
with the 64-module residual recorded above as the next work order's input.
Nothing was relaxed to manufacture a PASS.

## Replay

```
cd /Users/sac/ggen-marketplace
python3 scripts/gen_doc_surface.py code /Users/sac/xaas > code.json
python3 scripts/gen_doc_surface.py doc /Users/sac/xaas \
  --code-json code.json \
  --docs-dir /Users/sac/xaas/docs/reference,...(7 audited roots, comma-joined)
# module_coverage.modules: 1013, uncovered: 64 (list in this receipt)
sh scripts/check_pin_freshness.sh   # OK 3d2abae1… (ledger current)
```

Artifacts: /tmp/r26/{code.json,gate.json} (pre-commit witness, ephemeral).
