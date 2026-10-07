# W375 — Receipt Hygiene Audit — v26.10.6

Lane: W375 · Repo: `/Users/sac/xaas` @ `feat/playwright-surface` · Audited: 2026-10-06 17:04 local

## Method

Scripted per-file loop (find + grep + python byte scan) over all non-`_` files in
`docs/sjira/v26.10.6/plans/`. Earlier probe iterations produced false positives (zsh non-splitting
loop, shell NUL-in-variable grep, perl probe with inverted exit logic, read(0) emptiness check);
each was caught by a ground-truth re-check before any figure was recorded. Python byte scan is
authoritative for emptiness and NUL corruption.

## Totals

| metric | count |
|---|---|
| audited (non-`_` files) | 228 |
| verdict-bearing (>=1 hit of ALIVE/PASS/verdict/standing/exit/passed/failed/BLOCKED/REFUTED/RESOLVED) | 211 |
| empty (0 bytes) | 0 |
| corrupt (NUL bytes) | 0 |
| no-verdict files (finding, not rewritten) | 17 |
| undated (no `2026-10` marker; provenance-weaker, finding) | 56 |

Note: the directory was live during the audit (221 files at first pass -> 228 at final pass);
counts are a snapshot at the timestamp above. Conflict-marker scan: only hit is
`w79-gymact-dcm.md` line 62 `=======`, a pytest short-summary banner — not corruption.
No mojibake runs detected.

## No-verdict receipts (17, verbatim)

```
vector1-fenced-gates.md
vector6-docs-abi.md
w151-dev-migrate.md
w353-fenced-rows-disposition.md
w354-commit-ready-freshness.md
w355-os13-pack-markers.md
w378-vkg-kill.md
w38-igniter-credo.md
w53-ferroplan-bridge.md
w6-igniter-pack-promotion.md
w72-version-seams.md
w89-gymact-cwd-fix.md
x1-playwright-inventory.md
x1b-playwright-runner.md
x4-version-alignment.md
x6-notes.md
x7-risk-register.md
```

## Undated receipts (56, verbatim)

```
r3-igniter.md
r7-zcode-cli.md
vector2-refusal-coverage.md
vector4-gen-parity.md
vector5-limits-lints.md
w104-tag-runs.md
w106-mix-task-stragglers.md
w110-autofde-import.md
w117-pw-residuals.md
w150-auth-floor-fixes.md
w161-order-bound.md
w165-wasm4pm-bumps.md
w169-marketplace-regression.md
w174-ontop-health-typing.md
w180-seed-class.md
w188-diag-removal.md
w192-ultracode-rerun.md
w197-telemetry-suite.md
w198-sa2a-suite.md
w205-router-regression.md
w210-vacuity-sweep.md
w216-igniter-final2.md
w220-marketplace-igniter.md
w245-property-token.md
w251-final-suite.md
w283-sjira-post-w139.md
w284-accounts-operations.md
w289-final-dod-suite.md
w299-pw-run2-full.log
w311-sjira-final.md
w322-zero-config-posture.md
w327-ci-gates-draft.md
w336-digest-manifest.md
w342-e2e-coverage-map.md
w347-workbench-matrix.md
w349-cloak-key-guard.md
w362-catalog-determinism.md
w373-gymact-wpj.md
w378-vkg-kill.md
w38-igniter-credo.md
w52-beam4pm-qualification.md
w53-ferroplan-bridge.md
w58-zcode-deps.md
w6-igniter-pack-promotion.md
w61-castle-bin-gate.md
w72-version-seams.md
w74-rust4pm-wasm.md
w80-pack-repin-diff.md
w81-ggen-cargo-check.md
w83-stripe-seller-verify.md
w89-gymact-cwd-fix.md
w90-repin-verify.md
w94-wasm4pm-flake.md
w99-next-read-fix.md
x1-playwright-inventory.md
x6-notes.md
```

## Cite-integrity spot check (25 sampled `_INDEX.md` rows)

All 25 sampled rows match: each cited file exists and its first heading agrees with the index
descriptor. Six initial "mismatches" were a bug in my own comparison tokenizer (capitalized
heading words fragmented); re-inspected by eye, 25/25 OK. No title/descriptor drift in the sample.

## Findings for coordinator (no other lane's file rewritten)

1. 17 receipts carry no verdict/standing/result signal under the contract regex. Several are
   plausibly pure-audit/planning notes (e.g. `x1-playwright-inventory.md`, `x6-notes.md`,
   `x7-risk-register.md`, vector audits) where no verdict was required; coordinator should either
   accept the class exemption or require those lanes to add a standing line.
2. 56/228 receipts (24.6%) lack any `2026-10` date marker — provenance-weaker. Non-blocking:
   mtime + `_INDEX.md` rows give secondary provenance.
3. Zero empty/corrupt receipts: no exculpatory-asset integrity failures found.
