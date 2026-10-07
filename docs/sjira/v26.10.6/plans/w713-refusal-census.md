# W713 — Refusal-Atom Census Court

- **Lane**: W713, xaas v26.10.6, branch `feat/playwright-surface`, HEAD `a0723bf6`
- **Date**: 2026-10-07
- **Backlog item**: refusal atoms are contract — nothing courted that every
  `REFUSED_` atom emitted in `lib/xaas/semantics/` belongs to its module's
  declared set.
- **Deliverable**: `test/xaas/semantics/refusal_atom_census_test.exs`
  (Chicago-style: real `File.read!` source scans + real
  `AiroRiskMapping.risk_concept_for/1` calls; zero mocks).

## Method

For each of the 7 censused semantics modules (EuAiActAdmission,
DatasetAdmission, RobustMargin, IncidentReport, AuthorityChannel,
VulnerabilityLifecycle, DeclaredMetrics):

- (a) source-scan the module file (real `File.read!`) with regex
  `:REFUSED_[A-Z0-9_]+` for every literal refusal atom occurrence;
- (b) assert every scanned atom belongs to the module's declared/closed set,
  transcribed from the module's own `@type`/`@spec`/accessor (never from the
  scan itself). IncidentReport additionally allows the `REFUSED_EUAIA_`
  prefix, but only for atoms actually declared by
  `EuAiActAdmission.refusal_atoms/0` — no free atom can pass under a prefix;
- (c) AIRo mapping totality: every declared EUAIA atom and every scanned atom
  across all censused modules maps through
  `AiroRiskMapping.risk_concept_for/1` to a real (non-sentinel
  `REFUSED_TOTALLY_BOGUS_ATOM`, non-empty, non-generic-fallback
  `UNADMITTED_TRANSITION`) risk concept, deterministically (repeat call
  stable; 8 distinct concepts for the 8 Art. 5(1) atoms).

## Per-module census

| Module | Source | Scanned atoms (count) | Declared-set source of truth | Result |
|---|---|---|---|---|
| EuAiActAdmission | lib/xaas/semantics/eu_ai_act_admission.ex | 9 | `refusal_atoms/0` (8 Art. 5(1) atoms) | **FINDING** — `:REFUSED_EUAIA_MALFORMED_CANDIDATE` emitted (line 116) but NOT in `@type refusal_atom` / `refusal_atoms/0` / `verdict()` spec |
| DatasetAdmission | lib/xaas/semantics/dataset_admission.ex | 4 | @spec admit/2 (lines 55-58) | clean |
| RobustMargin | lib/xaas/semantics/robust_margin.ex | 4 | @spec estimate_lipschitz/2 + admit/4 | clean |
| IncidentReport | lib/xaas/semantics/incident_report.ex | 1 (+EUAIA prefix delegation) | @spec build/2 (line 69) + EuAiActAdmission closure | clean |
| AuthorityChannel | lib/xaas/semantics/authority_channel.ex | 2 | @type refusal (lines 71-73) | clean |
| VulnerabilityLifecycle | lib/xaas/semantics/vulnerability_lifecycle.ex | 3 | @type refusal (line 52) + @spec new/1 | clean (note: `:REFUSED_NO_DETECTION_RECORD` is in `@spec new/1` but absent from `@type refusal` — @type/@spec divergence, not a closure violation) |
| DeclaredMetrics | lib/xaas/semantics/declared_metrics.ex | 1 | `@typed_refusal` (line 16) | clean |

## Typed finding (the census working as designed)

**`Xaas.Semantics.EuAiActAdmission` emits `:REFUSED_EUAIA_MALFORMED_CANDIDATE`
(`admit/1` fallback clause, line 116) which is not a member of the module's
declared closed set** — `@type refusal_atom`, `@typedref_atoms`, and
`refusal_atoms/0` all hold only the eight Art. 5(1) atoms, while the
`@spec admit/1 :: verdict()` where `verdict()` = `{:error, refusal_atom()}`
claims the error is always one of the eight. Per lane instruction the test
was NOT loosened and no set was invented; the strict court fails with:

```
1) test (a)+(b) per-module source census ... belongs to its declared set (Xaas.Semantics.RefusalAtomCensusTest)
     test/xaas/semantics/refusal_atom_census_test.exs:134
     modules emit literal refusal atom(s) outside their declared sets:
       Xaas.Semantics.EuAiActAdmission (lib/xaas/semantics/eu_ai_act_admission.ex): [:REFUSED_EUAIA_MALFORMED_CANDIDATE] ...
```

Repair options (coordinator decision): (1) add
`:REFUSED_EUAIA_MALFORMED_CANDIDATE` to `@typedref_atoms`/`@type
refusal_atom` + a `describe/1` clause; or (2) reshape the fallback to a
`REFUSED_MALFORMED` family atom already in a declared set. Either is a
~2-line lib diff on a separate lane.

## Verification (real tails)

Commands (PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test,
MIX_BUILD_ROOT=_build-laneW713):

- Run 1 (fresh build root, full dep compile): `mix test
  test/xaas/semantics/refusal_atom_census_test.exs` → exit 2,
  `Result: 3/6 passed, Failed: 3` — all 3 failures were a census-test path
  bug (`Path.expand("../..")` from `test/xaas/semantics/` resolves inside
  `test/`, not the repo root), fixed to `"../../.."`.
- Run 2: exit 2 — first module's finding halts the for-comprehension; court
  refactored to accumulate all violations, then assert once.
- Final run `/tmp/w713_run3.log`:
  `Finished in 0.08 seconds ... Result: 5/6 passed, Failed: 1 test`, the one
  failure being the typed finding above. Exit code 2.

## Standing

- Census court: **ALIVE** on subject `a0723bf6` (observed execution, 6
  tests, 5 pass, 1 strict finding).
- `lib/xaas/semantics/eu_ai_act_admission.ex` refusal-atom closure:
  **BLOCKED (TYPED_FINDING)** — `REFUSED_EUAIA_MALFORMED_CANDIDATE` emitted
  outside declared set; repair is a ~2-line lib change on a follow-up lane.
- AIRo mapping totality: **ALIVE** — all 23 scanned atoms map to real,
  distinct-or-family risk concepts; no sentinel, no empty, no
  `UNADMITTED_TRANSITION` fallback, deterministic.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW713 \
  mix test test/xaas/semantics/refusal_atom_census_test.exs
# expected: 5 passed, 1 failed (the typed finding above)
```

## Leases

`_build-laneW713/` left in place (build-root deletion denied in this
session) — coordinator to delete at integration per fanout cleanup law.
No commits made; only `test/xaas/semantics/refusal_atom_census_test.exs`
(new) and this receipt were written.
