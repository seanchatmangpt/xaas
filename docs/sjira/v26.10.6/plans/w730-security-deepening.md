# W730 — Security Domain Deepening (receipt)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` HEAD `a0723bf6` (uncommitted lane; no commit per lane contract)
- **Lane**: W730, v26.10.6 campaign. Files written: `test/xaas/security_deepening_test.exs` (new, this receipt).
- **Standing**: ALIVE (witnessed execution on the exact subject; 12/12 passing, exit 0).

## What was done

Read `lib/xaas/security.ex` and both resources
(`lib/xaas/security/finding.ex`, `lib/xaas/security/posture.ex`), then wrote
`test/xaas/security_deepening_test.exs`: Chicago-style courts on the real
`Ash.DataLayer.Ets` tables via real Ash actions (`ingest/1`, direct resource
creates, `Ash.read!`), asserting real row state. No mocks.

## Courts (12 tests, all real row-state assertions)

(a) **Ingest boundary (the real lifecycle)**: Finding has exactly two actions —
`:read` and the `:ingest` create. Disposition is set at ingest (`:pending`
default) and never changes; the "lifecycle" this domain enforces is typed
admission at the boundary, not a state machine. Witnessed: rows persist with
exact severity/source/disposition; `severity`/`source`/`disposition` `one_of`
refusals (`Ash.Error.Invalid`, "invalid value") leave **zero** rows; `file` and
`description` are mandatory (`allow_nil?: false`).

(b) **Posture aggregation**: crafted 7-finding set → exact counts (2 critical /
2 high / 1 medium / 1 low / 1 info; `dispositioned_count` 4; `green` false).
Empty findings list still registers a zero-count green posture. Multi-scan
`posture_summary/0` sums across postures and is green only when **every** scan
is green.

(c) **Typed gaps — read first, asserted honestly as behavior (W715 pattern)**:

- `UNSUPPORTED(no-dedup)`: no unique identity on Finding — 3 identical
  findings ingest as 3 distinct rows; the aggregate counts them 3 times.
- `UNSUPPORTED(no-lifecycle)`: **no update action exists on Finding or
  Posture** — attempting `for_update(:update, ...)` raises
  `ArgumentError` "No such update action on resource Xaas.Security.Finding:
  :update" with an empty available-actions list. Disposition is immutable
  post-ingest; there is no open→triaged→resolved state machine to test.
- `UNSUPPORTED(no-sla-clock)`: `discovered_at` is stored (verified round-trip
  `~U[2026-01-01T00:00:00Z]`) but nothing computes on it — no age, no breach
  count, no `oldest_open_finding` on the aggregate.
- `UNSUPPORTED(no-severity-ordering)`: severity is an unordered atom; there is
  no rank/top-severity calculation anywhere — Posture carries counts only
  (asserted absence of `:top_severity`/`:max_severity` fields).
- `UNSUPPORTED(counts-not-derived)`: `Posture.register` accepts arbitrary
  counts with zero Finding rows backing it; the domain trusts the ingest path,
  not the data.

(d) **Determinism**: 6 repeated `Ash.read!` projections of both Finding and
Posture tables return byte-identical projections after writes.

## Commands + exits (real tails)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW730 \
  mix test test/xaas/security_deepening_test.exs
# first run (cold lane build, ~437M, heavy concurrent lane contention): 2
# failures — both harness bugs in my own file, fixed forward: for_create on a
# record (needed for_update), create! destructure {:ok, _} mismatch; then
# raise-message regex aligned to the real message
# ("No such update action on resource Xaas.Security.Finding: :update").
# warm reruns:
............
Finished in 0.4 seconds (0.00s async, 0.4s sync)
Result: 12 passed
[exited with code 0]
```

Default-excluded ExUnit tags (`:stress`, `:kind`, `:eu_ai_act`, etc.): none
apply; no `@moduletag` on this file. Pre-existing app warnings (AshA2A
legacy-compat, PromEx/Grafana nxdomain, ash_affidavit unused-attribute) are
environmental and unrelated to this lane.

## Standing / replay

- Standing: **ALIVE** on the exact subject (uncommitted tree @ `a0723bf6` +
  this test file). Replay: the command above on that tree.
- Lane build root `_build-laneW730` (437M): deletion was attempted per the
  fanout cleanup law but **denied by the session permission system** (both
  `rm -rf` attempts refused). Left in place for the coordinator to delete.
