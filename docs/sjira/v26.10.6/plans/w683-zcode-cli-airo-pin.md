# W683 — zcode-cli AIRo wiring pin (ledger CONSISTENT verification)

Lane: W683, xaas v26.10.6 campaign. Backlog: AIRo wiring extension
(`docs/cro/artifacts/airo-wiring-ledger.md`, zcode-cli row).

## Subject

- Repo: `/Users/sac/zcode-cli` (canonical checkout, untouched otherwise)
- Branch: `fix/v26926-preview-publish-typed-skip`
- HEAD: `eb97f76b96626f21e1a275b8c1d76127ca2a3c10`
- Tree: dirty from other lanes (pre-existing; disclosed, not touched by this lane)

## Per-claim verification (ledger row, w615)

| Ledger claim | Verified how | Result |
|---|---|---|
| `ontology/airo_risk_description.ttl` (8,022 B) exists | `statSync` + byte-size assert | CONFIRMED (8,022 B exactly) |
| bun structural court | prior `test/airo-risk-description.test.ts` (W615, on disk, `bun:test`) | CONFIRMED present; not re-run as gate |
| w356 contract shas recomputed in-test | recomputed sha256 in new W683 test | CONFIRMED (both pins hold) |
| 4 passed | new W683 independent court: 5 tests | PASS (see below) |

Surface check: only AIRo artifacts in repo are `ontology/airo_risk_description.ttl`
and the two test courts; grep found no other airo/risk wiring — matches ledger scope.

## New artifact

`test/airo-wiring-w683.test.ts` — 5 tests, real file reads only, no mocks:

1. ttl exists, byte size exactly 8,022 B (ledger claim), AIRo namespace present.
2. Risk-graph closure: 3 RiskSource, 2 RiskControl, Consequence(s) typed; sources
   linked via `airo:isRiskSourceFor`; `Modality_Assessed` wired.
3. Every `file:` citation resolves to a real, non-empty file (>=6 citations).
4. w356 contract sha pins recomputed in-test and hold.
5. Likelihood/hasRiskControl vocabulary wired per risk.

## Run (real output)

```
$ bun test test/airo-wiring-w683.test.ts
  5 pass
  0 fail
  43 expect() calls
Ran 5 tests across 1 file. [147.00ms]
```

(bun 1.4.2, `/opt/homebrew/bin/bun`; repo-native runner per package.json, no
global installs.)

### Disclosed notes

- First run had 1 fail: my test used `text.length` (UTF-16 char count = 8020)
  against the ledger's byte size (8022); file contains a multi-byte char. Fixed
  to `statSync().size`. This was a test-authoring bug, not surface drift.
- Coordinator TS-syntax warning (line 83) was for a defect already fixed before
  the first run; the executed file parsed clean under bun.
- Pre-existing unrelated: dirty tree (modified src/test files from other lanes)
  and untracked lane artifacts; full unit gate not run by this lane (lane scope
  is the pin test; W615's `+1076 full unit gate` stands as prior evidence).

## Standing

- Ledger row zcode-cli: **CONSISTENT confirmed** (all claims verified on disk
  and by execution).
- Standing: ALIVE (pin test passes on exact subject `eb97f76b` worktree,
  branch `fix/v26926-preview-publish-typed-skip`).
- Not committed (per lane instruction); coordinator owns integration commit.
- Falsifier for regression: `bun test test/airo-wiring-w683.test.ts` — any ttl
  edit, file-citation deletion, or contract-fixture drift fails it.
