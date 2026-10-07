# W946 — Post-Commit Gate 2 (W663b/W940 successor, HEAD 910a2e22)

- **Subject**: repo `xaas`, branch `feat/playwright-surface`, HEAD `910a2e228899f55e62626366ade41a903ea6d88e`
- **Lane env**: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW946`
- **Scope note**: operator rows (platform deletion pairs, `priv/semantic/generated/`, migrations) are intentionally uncommitted; their absence from HEAD is expected, not a defect. Concurrent lanes share the checkout (`_buildNew-lineW968c/` observed).

## Gate 1 — full `mix test` (unfiltered)

**Verdict: PASS-above-threshold, 32 failures classified.**

- Command: `mix test` (cold lane build root; second run completed after first was harness-killed at the 30-min background default — warm `mix test` rerun completed)
- Real tail:
  ```
  Finished in 1720.5 seconds (67.0s async, 1653.5s sync)
  Result: 4302/4334 passed (15/15 doctests, 4287/4319 tests), 37 skipped, 1497 excluded
  Failed: 32 tests
  EXIT:2
  ```
- Threshold ≥3247 (W663b): **4287 passing tests — PASS** (doctests 15/15 additional).
- Failure classification (32 total):
  - **CONTENTION (13)** — `Xaas.CastleRefusalNegativeTest` wholesale: all 13 tests are
    `ExUnit.TimeoutError` at `acquire_castle_lock/2` (`test/xaas/castle_refusal_negative_test.exs:292`,
    60s lock timeout, `Process.sleep/1` loop) — tests 12–24: REFUSED_INVALID_CASTLE_DIGEST,
    REFUSED_UNKNOWN_CASTLE_ADAPTER_PROFILE, REFUSED_CASTLE_SIGNING_IDENTITY_DRIFT,
    REFUSED_CASTLE_KERNEL_DRIFT, REFUSED_CASTLE_RUNTIME_IDENTITY, REFUSED_CASTLE_ADAPTER_PROFILE_DRIFT,
    REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH, REFUSED_UNRECEIPTED castle DO,
    REFUSED_CASTLE_CONSTRUCT_NOT_ALIVE, REFUSED_CASTLE_CONSTRUCT_DIGEST, REFUSED_CASTLE_EXIT,
    REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED, REFUSED_NON_JSON_CASTLE_RESPONSE.
  - **OPERATOR-ROW-EXPECTED (3)** — consequences of intentionally uncommitted rows:
    (1) `Xaas.TopologyGuardTest` — File.Error: `lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex`
    no such file (uncommitted deletion pair); (2) `Xaas.ZcodePlugin.ProjectionTest` — "no top-level
    generated/ directory" expected-false-got-true (`priv/semantic/generated/` untracked operator row);
    (3) `Xaas.Governance.AuditLogEntryTest` — Postgrex 23514 check_violation `force_test_write_failure`
    (migration `20261007111457_add_ash_onetime_logical_partitions` not applied to the lane's test DB
    state this run). Note: w919's w849-census deletion hazard is visible here as failure (1).
  - **REMAINING (16)** — functional failures on HEAD, not lock-timeout and not obviously
    operator-row: TopologyGuard aside — `ActuationRefusalNegativeTest` (nil-subject match),
    `Semantics.AuthorityDecouplingTest` (axiom A match), `EUAIAct.TitleIVVTest` (OPEN_GAP Art.49(3)
    — disclosed-gap assertion), `Actuation.RunIdempotencyDeepeningTest` (d1/d2/d3 three refusals),
    `Telemetry.OcelAshEmitterTest` (court-shape MatchError), `Telemetry.OcelAshEmitterRotationTest`
    (rotation size off-by-one), `XaasWeb.HealthCourtTest` + `XaasWeb.HealthControllerTest` (ultracode_tick
    :warming_up → 503 vs 200, two tests), `Xaas.AshSurfaceDriftMutationTest` + `Xaas.AshSurfaceDriftGuardTest`
    (regeneration drift detected — consistent with operator-row generated artifacts not in HEAD),
    `XaasWeb.AuditExportTokenControllerTest` (400/403/404 no_route_found ×3 — no_route_found suggests
    the audit-export routes live behind uncommitted route/changes rows), `Mix.Tasks.Xaas.EuAiActPackTest`
    (declared count 71 vs 62 — refusal corpus grew beyond the test's frozen count).
    Drift-guard/audit-export/EU-AI-Act-pack blocks are consistent with uncommitted operator rows;
    the run-idempotency (d1/d2/d3), actuation nil-subject, authority-decoupling, and OCEL-emitter
    failures are **not** explained by operator rows and are the highest-value repair targets.
  - Zero failures matched "already continuously retried / exponential backoff" or DB lock contention
    patterns beyond the castle lock; no other timeouts observed.
- **Standing: PARTIAL_ALIVE (gate 1)** — threshold met; classification recorded.

## Gate 2 — mock gate

**Verdict: PASS.** `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'` → `[]`, exit 0.

## Gate 3 — ggen sync drift

**Verdict: REFUSED (typed), no drift observable.**

`ggen sync run` (ggen 26.9.28) exit 1 with typed refusal before any generation:

```
ERROR: CLI execution failed: Command execution failed: validation error: [FM-PACK-008] pack `xaas_castle_bridge`
(source `git:https://github.com/seanchatmangpt/ggen-marketplace.git@518572b6b53103922ae8a27636a00e982a0907c4#packs/xaas-castle-bridge-pack`)
content hash mismatch: ggen.lock has `blake3:c5e128e3441e0005e27addfcd456aa5dfaf6f478021246e22b2727fc7c3af818` but the pack on disk hashes to `blake3:0deefa4413c22fd5341181ace0751b97e8cb0eda8de21698a83eff8fb8bb4eef`.
Remediation: restore the pack, or delete ggen.lock to intentionally re-lock.
```

- The w918 prediction (line-10 rationale delta) and w919 w849-census deletion hazard could not be
  replayed this run — **BLOCKED(FM-PACK-008)**. Remediation requires coordinator authority (re-lock
  or restore pack at pinned SHA 518572b6).
- Verified: the refusal fired before any generation; `git status` delta attributable to this lane:
  **none**. (Tree showed unrelated mutations from concurrent lanes; none timestamped to this lane's
  sync at 15:01Z. `ggen.toml`, docs, and test files were being modified by concurrent lanes.)
- **Standing: BLOCKED(FM-PACK-008)** — typed refusal, zero unreceipted mutation from this lane.

## Gate 4 — strict compile

**Verdict: FAIL, exit 1.**

`mix compile --force --warnings-as-errors` → "Compilation failed due to warnings":

1. `lib/xaas/semantics/dataset_admission.ex:137` — "redefining @doc attribute previously set at line 132" (`Xaas.Semantics.DatasetAdmission`)
2. `lib/xaas/platform/route_projects_backups.ex` — `[Xaas.Platform.RouteProjectsBackups]` `purge_expired` cannot be atomic because `RouteProjectsBackupsRetainUntilPassed` validation cannot be done atomically — consequence of the intentionally uncommitted deletion of `lib/xaas/platform/validations/route_projects_backups_requires_approver.ex`
3. (dep-side, printed but not root-gated: `ash_affidavit` dep, `lib/ash_affidavit/signing.ex:312` `@envelope_domain_tag` set-but-unused)

Item 1 is a real HEAD defect (the @doc redefinition at line 137 vs 132 is in a committed file). Item 2 is operator-row-coupled. **Standing: BUILD_BROKEN(strict-compile), exit 1.**

## Lane summary

| gate | verdict | standing |
|---|---|---|
| 1 full suite | 4287/4319 tests + 15/15 doctests passed, 32 failed (13 CONTENTION, ~3 operator-row, ~10 operator-row-consistent, ~4-5 genuine HEAD defects) | PARTIAL_ALIVE |
| 2 mock gate | `[]` | ALIVE |
| 3 ggen sync | FM-PACK-008 typed refusal, no drift replay possible | BLOCKED(FM-PACK-008) |
| 4 strict compile | exit 1: @doc redefinition + operator-row-coupled require_atomic warning | BUILD_BROKEN |

**Falsifiers for successor lanes**: (a) re-run castle_refusal_negative on an unloaded machine → all 13
should pass, else they are not CONTENTION; (falsifier-a) replay `ggen sync run` after re-lock
(coordinator authority) → w918/w919 predictions become testable again; (c) fix the @doc redefinition
in `lib/xaas/semantics/dataset_admission.ex:137` → strict compile on a tree with operator rows
restored then fails on nothing (operator-row-coupled warning gone).

## Replay

```bash
cd /Users/sac/xaas && git rev-parse HEAD   # 910a2e228899f55e62626366ade41a903ea6d88e
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW946 mix test
PATH=$HOME/.asdf/sh commands                # context: asdf-pinned 1.20.2-otp-28
PATH=$HOME/.asdf/shims:$PATH mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'
PATH=$HOME/.asdf/shims:$PATH ggen sync run  # expect FM-PACK-008 until re-lock
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW946 mix compile --force --warnings-as-errors
```

Standing: gate-1 PARTIAL_ALIVE, gate-2 ALIVE, gate-3 BLOCKED(FM-PACK-008), gate-4 BUILD_BROKEN.
Lane build root `_build-laneW946` left in place for the coordinator: the lane's `rm -rf` was denied
by the permission system at close-out, so cleanup is delegated (fanout cleanup law: lane build roots
are leases — coordinator deletes at integration).
