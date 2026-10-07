# W650g2 — Straggler restage receipt (v26.10.7 fleet seal)

Date: 2026-10-07 · Lane: W650g2 · Branch: `feat/playwright-surface` @ 87dc84de (base)

## Staged table

| file | state | origin lane | standing |
|---|---|---|---|
| `lib/xaas/security.ex` | M | W984dj3 | **landed mid-flight** by W650r in `ab0f3870` before my commit — skipped, no double-land |
| `test/xaas/security/finding_lifecycle_depth_test.exs` | new | W984dj3 | **landed mid-flight** in `ab0f3870` — skipped; my 20/20 run covered the post-`ab0f3870` tree |
| `test/xaas/semantics/graphlaw_wasm_load_verify_test.exs` | new | W984dh | **landed mid-flight** in `781f7d53` (W650q Wasmex host) — skipped; covered by same green run |
| `test/xaas/actuation/spg_gate_test.exs` | new | W984dj2 | green ×1, landed in `a5f81439` |
| `test/xaas/semantics/w640_differential_shacl_test.exs` | new | W640 | green ×1 as-is, landed in `a5f81439` |
| `test/xaas/semantics/w640_differential_shacl_test.exs` | new | W640 | green ×1 as-is |
| `docs/sjira/v26.10.6/plans/w650x-spg-findings.md` | new | W650x | receipt landed |
| `docs/sjira/v26.10.6/plans/w984dj4-ultracode.md` | new | W984dj4 | receipt landed in `d01db3c5` |
| `docs/sjira/v26.10.7/plans/w984dj4-ultracode.md` | — | W984dj4 | **vanished mid-flight** (another lane's scratch audit removed it) — pathspec dropped, v26.10.6 copy landed |
| `docs/sjira/v26.10.6/plans/w984dj3-parse-dt.md` | new | W984dj3 | **landed mid-flight** in `ab0f3870` — skipped, no double-land |
| `docs/sjira/v26.10.7/plans/w650f-unification-verify.md` | new | W650f | completed-lane receipt, untracked stray → landed |
| `docs/sjira/v26.10.7/plans/w650o-ashsurface-bump.md` | new | W650o | completed-lane receipt, untracked stray → landed |
| `docs/sjira/v26.10.7/plans/w650g2-commit.md` | new | W650g2 | this receipt |

## Checked, not staged (exists and tracked already)

`w650s-pin-drift.md`, `w650t-falsifier-repair.md`, `w650u-ledger-commit.md`,
`w984cx2-pplan-gates.md`, `w984dh-gwasm-verify.md` (v26.10.7/plans) and
`w984cy4-gov-73.md`, `w984da-security-probe.md`, `w984db-a2a-probe.md`,
`w984dd-probe.md`, `w984df-jcs.md`, `w984dj2-spg-gate.md` (v26.10.6/plans) —
all TRACKED at `git ls-files` time; nothing to do.

## Missing (not on disk anywhere, both dirs)

`w650w` · `w984dg-probe` · `w984dj5` — no file found; owner lanes did not drop
receipts. UNSUPPORTED(receipt-missing), not staged.

## Dependencies

- w650f2-c0-flip receipt: **did not land within 15-min poll** (15:40–15:55).
  However `w640_differential_shacl_test.exs` passes as-is (20/20 in the combined
  run), so it was staged on the strength of the executed court, not the receipt.
  If W650f2's C0 flip lands later and flips this court's verdict, the owning
  wave must repair forward.

## Gates

- Fresh-root strict compile: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW650g2 mix compile` → **EXIT=0** (fresh root, full
  dep graph built).
- Staged tests: 4 files, one run → **20 passed, 0 failed, EXIT=0**
  (seed 300418, standard exclusion tags; Grafana/PromEx upload warnings are
  pre-existing environmental nxdomain noise).

## Standing

ALIVE for the staged set on
`feat/playwright-surface` @ (post-commit SHAs in commit manifest); observed
execution, not inspection. Lane build root `_build-laneW650g2` deleted at
integration.
