# W902 — Batch 3 CHEAP-REPAIR (receipt)

- **Lane**: W902, v26.10.6 campaign (batch 3 of W891's CHEAP-REPAIR triage)
- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface` (canonical checkout,
  no worktree); session HEAD at start `a0723bf6`; no commit (per lane contract).
- **Build**: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW902`, asdf toolchain
  (`PATH=$HOME/.asdf/shims:$PATH`).
- **Standing**: PARTIAL_ALIVE — 2 of 4 assigned rows repaired + mutation-killed + suites
  green; 2 rows closed verify-first (already repaired by landed waves W852 / in-tree staged
  W674 repair); one disclosed pre-existing red and one owned-in-flight red, both out-of-lane.

## Assignment and outcome per row

| W891 order row | Gap | Outcome |
|---|---|---|
| 8 (row 33) | W849-1 sha256 pins | **CLOSED VERIFY-FIRST — already repaired by W852** (`docs/sjira/v26.10.6/plans/w852-provenance-pins.md` landed; pins present in `test/xaas/generated/registry_drift_guard_test.exs`, 10 surfaces incl. the 4 PROVENANCE-ONLY). Suite green this lane: included in the 101/102 final run. Register row should flip to REPAIRED (owner: W852). |
| 9 (row 3) | W674-GAP-2 typed refusal | **CLOSED VERIFY-FIRST — already repaired in-tree** (staged `lib/xaas/operations/gymact_surface.ex`: `external_opt/2` typed `:episode_id_required`/`:cut_required` refusals sealed as `:refused`; GAP-1 also sealed as `:failed` with json-safe error maps). Its court suite `test/xaas/operations/gymact_surface_deepening_test.exs` is RED 5/… with a missing `require Ash.Query` in that file's own `sealed_intent!/sealed_receipt!` helpers — **W928-owned in-flight file, not touched by this lane** (disclosed to coordinator). Register row flips to REPAIRED when W928 lands green. |
| 10 (row 25) | W796-G1 borrow cap | **REPAIRED** (this lane). |
| 4 (row 23) | W793-after-split | **REPAIRED — remaining 2 of 4** (this lane); other 2 already closed by W818 (verified in-tree: `IncidentResolvedRequiresResolvedAt` now on `:create` + `IncidentResolvedIsTerminal` on `:update`). |

## W793-after-split (2 guards)

Re-verified per the triage's drift flag against the tree: RESOLVED_AT_GUARD_ONLY_ON_UPDATE
and NO_REOPEN_GUARD are closed by W818's in-tree guards; the split leaves exactly two open
gaps, both closed here:

- `GAP(NO_RESOLVED_AT_GUARD)` → new
  `lib/xaas/operations/validations/incident_resolved_at_requires_resolved.ex`
  (`IncidentResolvedAtRequiresResolved`): `resolved_at != nil` while final status `:open`
  is refused on `:update`. With W818's `IncidentResolvedRequiresResolvedAt` this makes
  `status == :resolved <=> resolved_at != nil` a real invariant.
- `GAP(NO_POSTMORTEM_STATUS_GUARD)` → new
  `lib/xaas/operations/validations/incident_postmortem_final_requires_resolved.ex`
  (`IncidentPostmortemFinalRequiresResolved`): `postmortem_status == :final` requires final
  status `:resolved`; `:draft` annotation while open stays legal.
- Wired on `:update` in `lib/xaas/operations/incident.ex` (mirrors W818's wiring exactly).
- Test flips in `test/xaas/operations/incident_lifecycle_deepening_test.exs`: the two
  absence-pinning GAP tests became guard courts (refusal + row-unchanged + lawful-edge
  assertions), as w793's receipt intended ("any guard added later flips these tests").

## W796-G1 (borrow cap)

- `lib/xaas/library/checkout.ex`: `:borrow` now carries a before_action guard counting the
  student's open (`:borrowed`/`:overdue`) checkouts fresh from the DB via `Ash.count!` on
  `__MODULE__` (W809's persisted-read mirror) and refusing typed (`InvalidArgument` on
  `:user_id`) at `@max_open_checkouts_per_student = 3`, before
  `DecrementBookInventory` fires. Aggregate across books; another student unaffected;
  a return frees capacity.
- Test flips + additions in `test/xaas/library/checkout_policy_deepening_test.exs`: the two
  absence-pinning "no cap" tests became cap courts (4th-borrow refusal with inventory
  unchanged, aggregate-not-per-book, other-student unaffected, return-frees-capacity),
  moduledoc updated.
- One in-flight defect this lane hit and fixed on its own file: the bare `Checkout` alias is
  NOT expanded inside a DSL-block anonymous fn — the first cut raised
  `Expected a resource or a query in Ash.Query.new/2, got: Checkout` at runtime; fixed to
  `__MODULE__`. (A concurrent observer also reported a `^user_id` compile flag; the final
  form compiles clean under MIX_ENV=test.)

## Mutation rationale + evidence (both repairs, real runs)

- Borrow cap: `sed`-mutated the guard to `open_count >= 999_999` → suite went 11/13 with
  exactly the new cap-refusal tests failing; restored byte-identical (diff-verified).
  Deleting the guard entirely kills the same tests — the mutation proves the courts are not
  vacuous.
- Incident guards: `sed`-deleted the two `validate(...)` wiring lines → 16/18 with exactly
  the two new guard tests failing; restored byte-identical (diff-verified).

## Verification ladder (real outputs)

- Final green run (13 suites, incident + full checkout/library collateral +
  registry_drift_guard): **101/102 passed** — the 1 failure is
  `next_read_test.exs:144` "correctly scores and ranks candidate books…", proven
  **pre-existing**: reproduced with `git show HEAD:lib/xaas/library/checkout.ex` swapped in
  (parked-file technique, byte-identical restore after), i.e. it fails identically without
  this lane's diff. (It passed in an earlier same-lane run — shared-DB flake class; see
  hygiene note.)
- Incident + checkout-policy + collateral reruns before the concurrent breaks: 42/42.
- `checkout_actuation_test.exs`: green 2/2 after purging 4 stray committed rows from
  `xaas_test.library_checkouts` (cross-lane sandbox-escape contamination; failure mode was
  `Ash.count!(Checkout) == 6 != 2` from stale rows at 12:14–12:22). Disclosed as
  environmental, not a diff failure.
- Registry drift guard (W849-1/W852 verify-first): green in the final run.

## Out-of-lane observations (disclosed, not acted on)

1. `test/xaas/operations/gymact_surface_deepening_test.exs` red 5 (`require Ash.Query`
   missing in helpers) — W928-owned in-flight file.
2. `lib/xaas/governance/audit_export_token.ex:121` `change(increment(:use_count, 1))`
   broke tree-wide compile for ~15 minutes mid-lane — W935-owned (SPEC-16), landed
   compiling at poll attempt 6; two of this lane's verification runs died in that window.
3. Shared `xaas_test` DB: stray committed rows from cross-lane sandbox escape contaminate
   count assertions (`Ash.count!`-based tests). Suggest a coordinator-level hygiene pass or
   per-lane test DBs; recurrence expected under fan-out.

## Register effect

- W793 4-gap row (line 42): 2/4 already REPAIRED-by-W818 (verified), remaining 2/4 now
  REPAIRED-by-W902 — row can flip to REPAIRED (split recorded here).
- W796-G1 (line 44): REPAIRED → w902 (this receipt).
- W849-1 (line 53): REPAIRED → w852 (verify-first confirmation only).
- W674-GAP-2 (line 20): repaired in-tree (staged, unlanded); flips when W928's court lands.

## Replay

```
cd /Users/sac/xaas && git rev-parse --abbrev-ref HEAD   # feat/playwright-surface
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW902 \
  mix test test/xaas/operations/incident_lifecycle_deepening_test.exs \
          test/xaas/operations/incident_test.exs \
          test/xaas/library/checkout_policy_deepening_test.exs \
          test/xaas/library/checkout_return_test.exs \
          test/xaas/library/return_fulfills_hold_test.exs \
          test/xaas/library/checkout_concurrency_test.exs \
          test/xaas/library/checkout_actuation_test.exs \
          test/xaas/library/pubsub_test.exs \
          test/xaas/library/pubsub_publish_court_test.exs \
          test/xaas/library/hold_request_test.exs \
          test/xaas/library/next_read_test.exs \
          test/xaas_web/a2a/return_hold_cascade_avatars_test.exs \
          test/xaas/generated/registry_drift_guard_test.exs
# expected: 101/102 (the 1 = pre-existing next_read_test.exs:144 flake/contamination)
```

## Cleanup

`_build-laneW902` deletion attempted at lane end and DENIED by the permission system —
left in place as a lease for coordinator integration cleanup, same as W793's receipt
records.
