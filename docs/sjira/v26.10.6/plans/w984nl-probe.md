# W984nl — mutation non-vacuity audit #20 over W984na's follow-on court

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (lane W984nl,
  shared canonical checkout, no branch switch, no commit, no stash).
- **Method**: W984ek/ha/iy/jp/lc file-swap idiom — `cp` snapshots to
  `/tmp/w984nl/`, one surgical mutant at a time, run ONLY
  `test/xaas_web/controllers/internal_api_followon_court_w984na_test.exs`,
  `cp` back, `cmp`-verified byte-identical after every mutant.
- **Court under audit**: `test/xaas_web/controllers/internal_api_followon_court_w984na_test
  _test.exs` (9 tests, W984na receipt
  `docs/sjira/v26.10.6/plans/w984na-probe.md`).

## Gates

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984nl \
  mix test test/xaas_web/controllers/internal_api_followon_court_w984na_test.exs
→ baseline: 9 passed, exit 0
```

## Mutant matrix

| # | Mutant (file) | Expected kill | Verdict |
|---|---|---|---|
| M1 | Drop `approval_k8s_fault_remediate_suggest` from `@system_actor_path_segments` (`lib/xaas_web/plugs/set_internal_api_system_actor.ex`) | test g (create 201 → 403) | **KILLED** (8/9, 1 failed) |
| M2 | `approved_by == requested_by ->` → `false and approved_by == requested_by ->` (self-approval allowed) (`lib/xaas/operations/validations/approval_k8s_fault_remediate_suggest_requires_approver.ex`) | test h (400 + no persist → admits self-approval) | **KILLED** (8/9) |
| M3 | `bypass action_type(:read)` → `policy action_type(:read)` on `RouteCastleRun` (reads denied by the always-forbid floor) (`lib/xaas/operations/route_castle_run.ex`) | test a (200s → 403s) | **KILLED** (8/9 each; index/read/404 all fail) |
| M4 | **Compound**: M1 (plug segment dropped) + `:create` bypass `authorize_if({SystemActor,[]})` → `authorize_if(always())` (`set_internal_api_system_actor.ex` + `lib/xaas/operations/approval_k8s_fault_ remediate_suggest.ex`) | test g should fail (SystemActor provenance lost) | **SURVIVED — 9/9 passed** |
| M5 | Plug mints `SystemAuthority.new(:webhook_dispatcher)` instead of `:internal_api` (`set_internal_api_snip…`) | test g fails (wrong service → SystemActor check refuses) | **KILLED** (8/9) |

## Finding (M4 SURVIVED — real non-vacuity gap)

Test g asserts only the positive surface (valid-token POST → 201 + row
persisted). It cannot distinguish *why* the create was authorized:
with the plug no longer setting a SystemActor at all AND the resource's
`:create` bypass widened to `authorize_if(always())`, all 9 tests still
pass. The court therefore does not pin the SystemActor carve-out's
*provenance* — a blanket-allow regression on `:create` combined with a
broken plug arm is invisible. A closing test would assert a
non-system-actor create is 403 (e.g. actor present but not a
`Xaas.SystemAuthority` of service `:internal_api`, or a bare
`always()`-bypass removal guard) so admission provenance, not just
admission outcome, is courted.

## Tree cleanliness (post-audit)

- `git diff --quiet` on all 5 mutated files → clean (no output from the
  dirty-file loop); final court run on restored tree → 9 passed.
- Mock gate: `scan_mock_usage(["test/xaas_web/controllers/…w984na_test.exs"])`
  → `[]`.

## Cleanup

- Lane build root `_build-laneW984nl` deleted at integration.
- 4/5 killed, 1 survived (disclosed above). Standing of the court:
  PARTIAL_ALIVE — kills single-leg mutants on all three subject arms
  (plug arm, RequiresApprover validation, read policies) but not the
  compound blanket-allow class on `:create`.
