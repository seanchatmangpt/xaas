# W984ce — AIRo risk graph dedup (fix of W984bj pinned defect)

Lane: W984ce, wave W984, xaas v26.10.6, branch `feat/playwright-surface`.
Date: 2026-10-07.
Files written (lane scope, no commit):

- `lib/xaas/semantics/airo_risk_mapping.ex` — dedup fix
- `test/xaas/semantics/airo_risk_mapping_depth_test.exs` — court 4 pin flipped to deduped contract
- `docs/sjira/v26.10.6/plans/w984ce-airo-dedup.md` — this receipt

## Subject

`REFUSED_EUAIA_MANIPULATIVE` is both a ledger variant and an `@euaia_atoms`
entry, so `risk_graph/0` emitted a duplicated `ex:riskSource-REFUSED_EUAIA_MANIPULATIVE`
node and a duplicated `airo:hasRisk` edge (two emissions under one RDF subject).

## Fix (fix-forward)

`risk_graph/0` now computes `ledger_locals = MapSet.new(vs, &safe_local(&1.variant))`
and:

- **nodes**: skips the `@euaia_atoms` emission for any atom whose subject the
  ledger emission already covered. Merge policy: the ledger emission is the
  attribute superset (adds `ex:enforcingModule`); the atom emission's
  attributes are a strict subset, so merge == skip. No attributes are lost.
  Generalizes beyond MANIPULATIVE: any future ledger variant that is also an
  atom dedupes the same way.
- **edges**: same subject-keyed reject on the combined edge list.

## Before/after graph shape

Before (witnessed by W984bj):
- hasRisk edges: `length(vs) + 8`, with
  `ex:xaas-system airo:hasRisk ex:riskSource-REFUSED_EUAIA_MANIPULATIVE .`
  appearing exactly 2x; two `riskSource` node blocks under the same subject.

After (this fix):
- hasRisk edges: `length(vs) + extra_atoms` where
  `extra_atoms = count(atoms not in ledger)`, i.e. 7 with the current ledger.
- exactly one `airo:hasRisk` edge per subject; edge count == uniq edge count.
- exactly one `riskSource` node per subject;
  `ex:riskSource-REFUSED_EUAIA_MANIPULATIVE` present exactly once.

## Court 4 pin (flipped)

`test 4` now asserts (all against the real graph, real ledger):

- `length(has_risk_edges) == length(Enum.uniq(has_risk_edges))` — one edge per subject
- `length(has_risk_edges) == length(vs) + extra_atoms` — count matches deduped total
- MANIPULATIVE edge frequency == 1
- riskSource node subjects all distinct; MANIPULATIVE subject present

## Verification (real tails)

- Fresh `MIX_BUILD_ROOT=_build-laneW984ce` root, full dependency compile, then:
  - `mix test test/xaas/semantics/airo_risk_mapping_depth_test.exs` → **5 passed**, exit 0
- Depth + prior suite ×2: re-run after shared-checkout
  compile interference from sibling lanes' in-flight files
  (`authority_ledger_export.ex`, `approval_causal_anatomy.ex` — compile-freeze
  SLA events, not this lane's files; observed clean compile at 12:07:xx after
  first owner fix landed). Final ×2 tails to be appended below.

## Verification addendum (final tails, 2026-10-07 ~12:14 PDT)

```
$ export PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ce
$ mix compile   # attempt 1 after owner-lane fixes: clean
$ mix test test/xaas/semantics/airo_risk_mapping_depth_test.exs \
    test/xaas/semantics/airo_risk_mapping_test.exs \
    test/xaas/semantics/airo_vendored_pin_test.exs \
    test/xaas/semantics/ferroplan_airo_pin_test.exs
run 1: Result: 27 passed, 1 skipped
run 2: Result: 27 passed, 1 skipped
```

## Standing

- Dedup fix: **ALIVE** — witnessed on this exact subject by the flipped court-4
  pin passing ×2 (count + per-subject uniqueness), plus the single-file depth
  run on the fresh lane root (5 passed).
- Prior suite: green ×2.
- Shared-checkout note: two compile-freeze events from sibling lanes'
  in-flight files; resolved by owner lanes; no files outside lane scope
  touched.
