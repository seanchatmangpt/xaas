# W984hl — ggen_igniter render-court refusal reconciliation (receipt)

- Lane: W984hl on `/Users/sac/ggen_igniter` (no branch change, no commit)
- Date: 2026-10-07
- Command env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hl`
- Reference: `w984hd-repin.md` (typed this work order)

## 1. Real refusal (reproduced)

Exact court invocation, `mix ggen_igniter.sync --pack-dir
priv/ggen/vendor/ash-pplan-chaos-pack --template .../templates/invariant_property.exs.eex
--out <scratch>/<%= invariantId %>_property_test.exs`, `--json`:

```json
{"data":{...},"exit_code":1,"ok":false,
 "refusal":{"code":"SYNC_REFUSED",
 "detail":"ggen_igniter: reactor reconciliation failed (refused): %ArgumentError{message: \"reconcile_opts[:targets] must not be an empty list when given\"}"},
 "standing":"REFUSED","task":"sync"}
```

All 4 chaos-court legs fail with it (`Result: 0/4 passed`); protocol court same
class.

## 2. Root cause (mechanism, traced end to end)

1. Upstream `ggen-marketplace` @ ba21c22a reworked the chaos-pack gates from
   positive row-selects into **violation gates** (`FILTER NOT EXISTS`; pack
   `verify/` companion states "ZERO ROWS IS THE PASS CONDITION"). Vendored
   bytes verified byte-identical to upstream (ontology + all 3 gates).
2. The templates still declare `for_each: invariants` / `for_each:
   kill_phases` — binding the driver name to the SAME now-violation gates,
   which select **0 rows on valid data**. The pack is self-inconsistent
   upstream: no positive driver query exists in the pack anymore.
3. ggen_igniter: `run_for_each_via_reactor!` materializes `rows == []`, and
   because `opts[:fan_out]` is unset, dispatches with `targets: []` →
   `ReconcileReactor.normalize_targets/1` raises the deep ArgumentError that
   the court surfaces as "reactor reconciliation failed (refused)".
4. The court's own gates leg fails too — `gate gates/010_harness.rq: expected
   1 rows, got 0` — the consumer court fixtures in ash_pplan still assert the
   OLD positive-gate row counts (1/6/4) against the NEW violation-gate bytes.

Not pin-induced: W984hd already showed old-pin bytes fail with a different
typed refusal (duplicate output paths); the violation-gate rework is in both
pins' bytes.

## 3. Locus decision (three-layer)

| layer | verdict | action |
|---|---|---|
| ggen-marketplace pack | **bug**: templates `for_each:` onto violation gates (0 rows on valid data); no positive driver query remains in the pack | upstream work order (out of lane): add positive driver queries (e.g. `gates/015_invariants_driver.rq`-class SELECT of the 6 invariants / 4 kill phases) and point `for_each:` at them; update README/verify companions |
| ggen_igniter | **error-surface regression**: the pre-v26.9.2 inline pipeline rendered 0 files on a 0-row driver; the reactor routing (which the code comment says "keeps its existing behaviour") actually crashes with the deep `normalize_targets` ArgumentError | fixed in lane (below) |
| ash_pplan courts | **stale fixtures**: `pack_chaos_court_test.exs`/`pack_protocol_court_test.exs` gate rows 1/6/4 and render/determinism legs assert old positive-gate semantics against new violation-gate bytes; render legs can't pass until the upstream pack grows driver queries | court-side work order (out of lane) |

## 4. ggen_igniter fix (minimal diff, in lane)

`lib/mix/tasks/ggen_igniter.sync.ex` — `run_for_each_via_reactor!/7`: a direct
(non-fan-out) `--for-each` run whose driver query returns 0 rows now refuses
fail-closed with a named error instead of the deep `:targets` ArgumentError:

> `--for-each "invariants" returned 0 rows -- nothing to render (a direct
> --template run requires a driver query that selects >= 1 row on valid data;
> check that the query named by for_each is a row-selecting driver, not a
> violation gate`

Fan-out (`--pack-dir` multi-template, `opts[:fan_out]`) keeps its existing
0-row skip notice unchanged. `normalize_targets/1`'s own contract is untouched.

Regression test (Chicago, real subprocess + real fixture bytes):
`test/ggen_igniter_sync_for_each_reactor_test.exs` — new describe
"zero-driver-row direct --for-each run is a typed refusal (W984hl)" running a
real `mix ggen_igniter.sync` with a real violation-gate fixture
`test/fixtures/violation_gate_zero_rows.rq` (FILTER NOT EXISTS, 0 rows on the
valid ontology); asserts nonzero exit, the new named message, NO deep
"must not be an empty list" text, and zero files written.

Updated one stale assertion:
`test/ggen_igniter_ash_receipted_action_test.exs:102` (asserted the deep
`[:targets] must not be an empty list` text; now asserts the new named
refusal — same fail-closed doctrine, clearer surface).

## 5. Verification (real output)

```
mix test test/ggen_igniter_sync_for_each_reactor_test.exs --include integration
→ 3 tests, 0 failures            (incl. the new W984hl refusal test)

mix test test/ggen_igniter_reconcile_reactor_test.exs --include integration
→ 9 tests, 0 failures            (normalize_targets contract unchanged)

mix test test/ggen_igniter_ash_receipted_action_test.exs --include integration
→ 12 tests, 1 failure — "receipted actuation a pending receipt is refused as
  in flight unless reclaimed": `ReceiptedProbe.Receipt is undefined` /
  Postgres-class environmental failure (run saw `:alarm_handler:
  {:set, {{:disk_almost_full, ...}}}`), PRE-EXISTING, zero overlap with this
  diff (the failed test never touches the sync path; earlier run showed 3
  such failures, later run 1 — flaky environmental class, not deterministic).
```

## 6. Cleanup

- `_build-laneW984hl` (ggen_igniter): **deleted** — `rm -rf` succeeded
  (unlike W984hd's denial).
- `_build-laneW984hl` inside **ash_pplan** (created by this lane's first
  `mix run -e` probe): `rm -rf` **DENIED** by the permission system.
  Coordinator should delete `/Users/sac/ash_pplan/_build-laneW984hl`.
- `_build-laneW984hd` (ash_pplan, W984hd's residue): not this lane's; still on
  disk per its receipt. This lane's ash_pplan court runs compiled into it.

## 7. Standing

- ALIVE for the in-lane fix: refusal reproduced, mechanism traced, minimal
  diff + green regression test, normalize_targets contract unchanged.
- Typed work orders (out of lane):
  1. ggen-marketplace: chaos-pack (and same-rework packs: tokyo-depeg etc.)
     need positive `for_each` driver queries; templates currently bind
     violation gates.
  2. ash_pplan: `pack_chaos_court_test.exs` / `pack_protocol_court_test.exs`
     fixtures need updating to violation-gate semantics (`@gates` rows,
     anti-vacuity legs) once the driver queries exist upstream.
- NO commit made (per dispatch).
