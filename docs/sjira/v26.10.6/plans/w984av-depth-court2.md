# W984av — Depth Court (batch 2): semantics non-dataset_admission pair

Lane W984av, xaas v26.10.6 campaign. Branch `feat/playwright-surface` at work-start HEAD 5f7f70d9.
No commit (lane law). Files written:

- `test/xaas/semantics/attribution_counterfactual_depth_test.exs` (new, 5 courts)
- this receipt.

## Family selection rationale

Prior depth batches re-checked on disk at session start: W984aa covered
`Xaas.Semantics.RobustMargin` (semantics, `robust_margin_depth_test.exs`);
the platform route family is heavily covered (`platform_route_deepening_test.exs`,
`route_projects_create_court_test.exs`); billing/approvals/library/conference/
ocel/graphql/sensitive excluded by task. The w984ak / w984ar receipts were NOT
on disk at session start (concurrent lanes), so overlap with those lanes is
UNKNOWN — disclosed, not assumed absent.

Selected family: `Xaas.Semantics.AdmissionAttribution` (exact Shapley over the
discrete admission check lattice, Ch5/Art.13 Def 5.2) +
`Xaas.Semantics.Counterfactual` (Art.86 / Theorem 7.1) — the two non-robust_margin,
non-dataset_admission semantics modules. Disjoint from W984aa (RobustMargin).

Why load-bearing: if the attribution kernel ever runs a check fun more than
once, or misplaces attribution across the reversed names/bitmask index mapping,
it silently mis-attributes a refusal cause — the exact Art.13 failure mode. On
`Counterfactual`, `verify_recorded_outcome/4` is the only guard between a
stale/forged decision record and a counterfactual claim (Art.86), so the
mismatch typed refusal is load-bearing.

## The 5 courts

1. **Exactness** — 3-check lattice, single refusing check: the phi map pinned
   to the exact values `%{a: 0.0, b: 0.0, c: -1.0}`. Derivation in the comment:
   the refusing check's marginal is -1 on every coalition it joins (v drops
   1 -> 0), and the n=3 pivot weights over those coalitions sum to exactly 1.
   (First-draft expectation of -5/6 was an arithmetic error in the court, not
   in the module; the corrected derivation is in the test comment.)
2. **Refusal-position invariance** — the same single refusal at list position 1
   vs 2 puts -1.0 on the refusing check's name in both cases; pins the
   reversed names / bitmask index mapping (`refusal_bit/2` uses the
   un-reversed index) against order-dependent drift.
3. **Check-once evaluation** — 5 checks over 2^5 coalitions, each fun wrapped
   in a real Agent call counter: exactly 1 call per check. The phi values
   cannot distinguish evaluate-once from re-evaluation; the call counts can.
4. **COALITION_LIMIT boundary** — 20 checks compute (all-zero phi, map size
   20); 21 checks refuse typed `{:error, :COALITION_LIMIT}`.
5. **Real recorded decision (Postgres-grounded)** — a real
   `Ash.create` of `Xaas.Accounts.Org` (`authorize?: false`) mints a real row;
   the record built from it is counterfactually evaluated: same input
   replays to the same decision (not changed), a nil-slug counterfactual
   input flips the decision to `{:refused, :slug_missing}` with the
   explanation naming exactly `slug_present` (and not `slug_unique`), and a
   record that does not replay to its recorded outcome refuses typed with
   `{:error, {:record_outcome_mismatch, {:expected, {false, :slug_taken}, :got, :admitted}}}`.

## Mutation rationale

- Zero out the marginal `v(S∪{i}) - v(S)` -> courts (1)-(2) fail on exact phi.
- Drop the evaluate-once bitmask precomputation (re-run each fun per coalition)
  -> court (3) observes >1 call per check.
- `@max_checks 20 -> 19` -> court (4)'s 20-check arm flips to
  `{:error, :COALITION_LIMIT}`; raise it -> the 21-check arm wrongly computes.
- Drop `verify_recorded_outcome/4` -> court (5) admits a counterfactual on a
  non-replaying record instead of the typed mismatch refusal.
- Flip first-refusal selection in `run_pipeline/2` to last-refusal -> the
  recorded per-check log stops being a faithful witness of the real decision.

## Real runs (x2 fresh)

Command (both runs):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984av \
  mix test test/xaas/semantics/attribution_counterfactual_depth_test.exs
```

- Run 1 (fresh sandbox checkout): `5 passed` (after fixing two court-side
  defects: an invalid `&String.to_atom("...")` capture, and the wrong
  first-draft Shapley expectation; both court bugs, not module bugs; also one
  compile-error fix pass with `Compilation error` -> corrected -> rerun).
- Run 2 (second fresh `mix test` process, new seed): `Result: 5 passed`
  (grep-filtered output: "Result: 5 passed", "0 failures").

Standing: ALIVE on subject
`test/xaas/semantics/attribution_counterfactual_depth_test.exs` @ working tree
(no commit, lane law). Excluded families per task; overlap with concurrent
lanes w984ak/w984ar UNKNOWN at write time.

Build root `_build-laneW984av` left in place for the coordinator (per lane
law: delete when done, else leave for coordinator).
