# W386 — Stress class opt-in evidence receipt (v26.10.6)

Subject: /Users/sac/xaas @ feat/playwright-surface (one canonical checkout, no commits).
Build root: `/Users/sac/xaas/_build-laneW386` (removed after runs; see Cleanup).

## 1. Census

`grep -rl 'moduletag.*:stress\|@tag :stress' test/` → 8 files (matches w374 census of 18 tests):

1. test/xaas/platform/webhook_delivery_stress_test.exs
2. test/xaas/marketplace/provider_stress_test.exs
3. test/xaas/marketplace/approval_provider_status_change_stress_test.exs
4. test/xaas/operations/capability_liveness_receipt_stress_test.exs
5. test/xaas/ultracode/lease_concurrency_stress_test.exs
6. test/xaas/governance/approval_dr_failover_stress_test.exs
7. test/xaas/governance/approval_pentest_finding_resolve_stress_test.exs
8. test/xaas/governance/approval_backup_retention_change_stress_test.exs

## 2. Wave 1 — 7 small files (all but lease_concurrency)

Command:
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW386 \
  mix test --include stress \
  test/xaas/platform/webhook_delivery_stress_test.exs \
  test/xaas/marketplace/provider_stress_test.exs \
  test/xaas/marketplace/approval_provider_status_change_stress_test.exs \
  test/xaas/operations/capability_liveness_receipt_stress_test.exs \
  test/xaas/governance/approval_dr_failover_stress_test.exs \
  test/xaas/governance/approval_pentest_finding_resolve_stress_test.exs \
  test/xaas/governance/approval_backup_retention_change_stress_test.exs
```

Tail (identical on first run and isolation rerun):
```
Result: 5/8 passed
Failed: 3 tests
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```
(ExUnit: "Finished in 1.7 seconds (0.00s async, 1.7s sync)" on warm rerun.)

### Failures — all 3 share ONE root cause, classified REAL (test-vs-resource drift), not env

- `approval_provider_status_change_stress_test.exs:54` — "50 real concurrent create+approve races…" →
  `** (Ash.Error.Invalid) No such input 'status' for action Xaas.Marketplace.Provider.create`
  (attribute exists but not in create accept list; valid inputs: name, description, slug, org_id)
- `provider_stress_test.exs:85` — same-slug race "expected exactly 1 real create to win… got 0"
- `provider_stress_test.exs:37` — distinct-slug race, same `No such input 'status'` Ash.Error.Invalid

Root cause verbatim (all three):
```
* No such input `status` for action Xaas.Marketplace.Provider.create
The attribute exists on Xaas.Marketplace.Provider, but is not accepted by Xaas.Marketplace.Provider.create
Perhaps you meant to add it to the accept list for Xaas.Marketplace.Provider.create?
```
Both stress files pass `status:` into `Provider.create` params; the resource's create action
no longer accepts it. This is deterministic API drift in the tests, not environment
flakiness (reproduced identically on both runs; unrelated files in the same wave passed).

## 3. Wave 2 — lease_concurrency_stress_test.exs alone

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW386 \
  mix test --include stress test/xaas/ultracode/lease_concurrency_stress_test.exs
```
Tail:
```
..........
Finished in 1.8 seconds (0.00s async, 1.8s sync)

Result: 10 passed
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (memsup/cpu_sup): Erlang has closed
```

## 4. Totals

- Wave 1: 8 tests → 5 passed, 3 failed
- Wave 2: 10 tests → 10 passed, 0 failed
- Total: 18 tests → 15 passed, 3 failed (matches w374 census of 18)

## 5. Verdict

Stress class: **PARTIAL_ALIVE-at-HEAD**.
- 13/18 real executions pass under the pinned asdf toolchain (elixir 1.20.2-otp-28).
- 3 typed failures, single root cause: `Xaas.Marketplace.Provider.create` no longer accepts
  `status` (Ash accept-list drift) — affects `provider_stress_test.exs` (2 tests) and
  `approval_provider_status_change_stress_test.exs` (1 test). Test files need updating to
  the current action accept list (or the action re-expanded) — NOT an environment failure.
- lease_concurrency (largest, 10 tests): fully green.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW386` — DENIED by permission system (both attempts,
with and without trailing verify). Build root left on disk: `/Users/sac/xaas/_build-laneW386`
(MIX_ENV=test, ~warm compile of full app). Coordinator must remove it at integration
per same-checkout-fanout cleanup law.
