# W650t — ash_graphlaw pin-court falsifier repair (fleet seal, v26.10.7)

Lane: W650t. Date: 2026-10-07. Repo: `/Users/sac/xaas`. No commit (per lane contract);
files written: `docs/cro/artifacts/airo-wiring-ledger.md` (one row), this receipt.

## Trigger

W650s flagged: the ash_graphlaw row's falsifier cited `priv/airo_risk_description.ttl`
(vocab sha `6274d2d8…`) but no AIRo file exists anywhere in the ash_graphlaw tree —
the pin court was never executable.

## Tree grounding (real commands, ash_graphlaw @ `3ecae0e771f5448e90d8adc2a8a0786439b5b13e`)

- `git -C ~/ash_graphlaw cat-file -t 3ecae0e` → `commit` (SHA exists).
- `git -C ~/ash_graphlaw ls-tree -r --name-only 3ecae0e` → confirms cited admission
  surface IS real: `lib/ash_graphlaw/admissions.ex`, `lib/ash_graphlaw/authority.ex`,
  `lib/ash_graphlaw/evidence.ex` all present at the pinned SHA (W981e citation holds).
- `git -C ~/ash_graphlaw grep -il airo 3ecae0e --` → empty. No AIRo instance graph
  anywhere in the tree. Only graph files: `ontology.ttl`, `.sa2a/diataxis.ttl`,
  `priv/graphlaw/capability-registry.ttl`. No `*risk*` file.

Conclusion: reclassification case — the admission kernel surface is real, but the
AIRo instance-graph condition is absent. The old falsifier was a fake file citation.

## Before → after (ledger row, `docs/cro/artifacts/airo-wiring-ledger.md`)

Before (falsifier cell, excerpt):

> pin court at SHA: `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…`,
> cited paths exist, graph parses w/ RiskSource/Control/Risk triples. …

After (falsifier cell, excerpt):

> AIRo-mapping UNKNOWN — no AIRo instance graph exists in ash_graphlaw at
> `3ecae0e7` (tree-verified W650t: `git grep -il airo` empty; only `ontology.ttl`,
> `.sa2a/diataxis.ttl`, `priv/graphlaw/capability-registry.ttl`). Falsifier for
> ALIVE: repo ships an `airo_risk_description.ttl` (or equivalent AIRo instance
> graph) at the pinned SHA; pin court = commit-existence of the pinned SHA +
> cited-path existence (`admissions.ex`/`authority.ex`/`evidence.ex` — present at
> `3ecae0e7`, W650t) + graph parses w/ RiskSource/Control/Risk triples. Previously
> cited `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…` — file never
> existed; pin court was not executable (W650s finding, repaired W650t). …

Branch/HEAD, risk-dimension, cited-surface, and standing cells unchanged; the
backticked 40-hex SHA is preserved (pin_drift_check.exs parses it: any
`| repo | … | <40-hex> | …` row). Standing remains UNKNOWN (correct — the AIRo
mapping does not exist yet; the repo can satisfy the falsifier later).

## Verification (executed)

```
$ elixir docs/airo/pin_drift_check.exs
rows_checked: 21
counts: {current: 5, ancestor: 16, drift: 0, missing: 0}
ash_graphlaw row: CURRENT, recorded == head == 3ecae0e771f5448e90d8adc2a8a0786439b5b13e
```

The repaired row parses cleanly; fleet drift 0 across 21 rows.

## Standing

- ash_graphlaw AIRo row: **UNKNOWN** (unchanged; now honestly executable) —
  falsifier is a future-satisfiable condition, not an unrunnable file citation.
- This lane: PARTIAL_ALIVE receipt — falsifier repaired, drift check executed;
  ledger edit uncommitted per lane contract (coordinator owns commits).
