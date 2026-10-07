# W984bg — Gate-5 ALIVE Falsifier, Attempt 3

Standing: **PARTIAL_ALIVE** — full gate-5 depth suite executed for real on a
fresh lane build root; **931/938 passed, 11 excluded, 7 failures**, then a
one-file rerun classified 2 flake + 5 real. Not ALIVE (5 deterministic
failures present); not BLOCKED. Delta vs W982e (908/920, 5 residuals):
**+23 tests passed net (+30 total tests, −12 failures → 5 real tails)**.

## Exact subject

- Repo: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `b5d677b3`
  (dirty tree, sibling lanes in flight; graphql removal W984ao mid-flight in
  `lib/xaas/billing/approval_*.ex` — extensions swapped, GraphQL blocks
  removed).
- Toolchain: asdf elixir 1.20.2-otp-28 (asdf shims PATH-prefixed),
  MIX_ENV=test, `MIX_BUILD_ROOT=_build-laneW984bg` (`rm -rf` denied in lane —
  left in place; coordinator cleanup required per same-checkout-fanout
  cleanup law).

## Command (run 1, full gate-5 suite, fresh build root)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bg \
  mix test test/xaas/library/ test/xaas/conference/ test/xaas/operations/ \
  test/xaas/governance/ test/xaas_web/ \
  --include eu_ai_act --exclude eu_ai_act_open_gap
```

Exact tail (`/tmp/w984bg-gate5-run1.log`):

```
Finished in 48.7 seconds (9.0s async, 39.7s sync)
Result: 931/938 passed, 11 excluded
Failed: 7 tests
EXIT=2
```

No graphql-removal compile abort occurred (the W984ao edits compiled clean;
no wait/retry or git-archive scratch fallback needed).

## Run-1 failures (7) — classification (failing-file rerun)

Rerun command (same env, 5 files, `/tmp/w984bg-gate5-rerun.log`): EXIT=2,
**36/41 passed, 5 failed**.

Flake-class (failed run 1, passed rerun) — 2:

1. `XaasWeb.HealthCourtTest` "ultracode_tick under Oban testing:manual ...:
   typed skipped(:warming_up), aggregate stays 200"
   (`test/xaas_web/health_court_test.exs:157`) — got 503 vs expected 200;
   warming_up timing.
2. `XaasWeb.HealthControllerTest` "GET /internal-api/health real-reports
   ultracode_tick as skipped (:warming_up) ..."
   (`test/xaas_web/controllers/health_controller_test.exs:134`) — same 503
   vs 200 warming_up timing.

Real / deterministic (failed both runs) — 5:

3. `XaasWeb.ApprovalPatchSlaCreditApplyControllerTest` "POST rejects creating
   a request whose org_id does NOT match the actor's asserted org, not
   silently allowed" (`...approval_patch_sla_credit_apply_controller_test.exs:233`)
   — got 201, expected 403.
4. Same file, "PATCH rejects approving a request whose org_id does NOT match
   the actor's asserted org -- the real sixteenth-pass exploit, now closed"
   — got 201, expected 403.
5. `XaasWeb.ApprovalSlaCreditApplyControllerTest` "POST rejects creating a
   request whose org_id does NOT match the actor's asserted org ..."
   (`...approval_sla_credit_apply_controller_test.exs:239`) — got 201,
   expected 403.
6. Same file, "PATCH rejects approving ... sixteenth-pass exploit, now
   closed" — got 201, expected 403.
7. `XaasWeb.ExecutionFabricHookDepthTest` "post_tool_use and
   user_prompt_submit RECORD for a live lease (200) and are a typed 422
   without one" (`test/xaas_web/execution_fabric_hook_depth_test.exs:142`) —
   reason mismatch: expected `%{"decision" => "deny", "reason" => "no_lease"}`,
   got `"reason" => ":no_lease"` (atom-inspected string leaking `:` prefix).

## Cause notes (observed, not repaired)

- The 4 approval org-mismatch failures assert a cross-org 403 policy floor on
  `Xaas.Billing.ApprovalSlaCreditApply` / `ApprovalPatchSlaCreditApply`; the
  resource currently allows the cross-org POST/PATCH (201). On-disk sibling
  diffs to these resources are graphql-removal-only (extensions swap + graphql
  block removal), so the policy gap is not caused by the W984ao diff itself.
- The `:no_lease` string is an atom-inspection artifact in the hook's deny
  payload — a one-line classify/`to_string` fix shape, not a flake.

## Counts

| run | scope | passed | failed | excluded |
|---|---|---|---|---|
| run 1 (full gate-5, fresh root) | 938 tests | 931 | 7 | 11 |
| rerun (5 files, 41 tests) | 41 | 36 | 5 | — |

## Delta vs prior attempts

| attempt | result | failures |
|---|---|---|
| W972 | 898/908 | 10 (8 flake + 2 deterministic) |
| W982e | 908/920 | 5 residuals (since dispositioned) |
| W984bg | 931/938 | 7 (2 flake + 5 real) |

Zero overlap with W972's failure set. W972's 2 deterministic tails
(W973b terminal guard, route-castle type-only) both pass now. New real tails
are the 2 approval-controller org-mismatch files (4 tests) + 1
execution-fabric hook reason-string test — all on sibling-in-flight surfaces
modified in the working tree (billing approvals, execution fabric), not on
this lane.

## Standing & falsifier

- Gate-5 depth suite: **PARTIAL_ALIVE** (attempt 3). Still not ALIVE: 5
  deterministic failures.
- Falsifier for ALIVE (unchanged): a gate-5 rerun showing 0 failures.
- Repair map for the tails: (a) enforce cross-org 403 on the two approval
  apply resources (policy or controller validation), (b) strip the `:` from
  the hook deny reason (`to_string/1` on the atom), (c) warming_up health
  tests already pass when the tick has fired — timing-only.
- Logs preserved: `/tmp/w984bg-gate5-run1.log`, `/tmp/w984bg-gate5-rerun.log`.
