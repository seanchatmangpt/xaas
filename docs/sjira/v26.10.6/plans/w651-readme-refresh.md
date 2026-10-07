# W651 — EU-AI-Act README census refresh

Lane W651 · Repo `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout,
private build root `_build-laneW651`, `MIX_ENV=test`).

## Task

Refresh the stale census headline in `test/eu_ai_act/README.md` against the
current tree, and extend the README with the lanes that landed after W629:
W621 admission-gate fuzz, W628 master-equation soak, W630 OS-21 totality
fixes. Only writes: `test/eu_ai_act/README.md` and this plan file.

## Method

1. Read W629's README (baseline: gate 1100/10 excl; census 1100/1110, 10
   open gaps).
2. Re-ran the current green gate + honest census with a real run in this
   lane's private build root, PATH-pinned asdf toolchain:
   - gate: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW651 mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/`
   - census: same without `--exclude eu_ai_act_open_gap`
3. Update headline numbers + run tails verbatim; extend the file map with
   the fuzz + soak rows (they live under `test/xaas/semantics/`, outside
   `test/eu_ai_act/` — noted as such in the map); extend the
   mutation-falsification section to cover W551 (counterfactual M1–M6
   ledger) + W621 fuzz + W630 totality fixes.
4. Receipt = doc diff summary + both run tails, reported to coordinator.

## Result

Real runs, build root `_build-laneW651` (deleted at integration per the
lane-lease cleanup law):

- Green gate (run 1, pre-drift): `Result: 1112 passed, 5 excluded`, exit 0.
- Honest census: `Result: 1112/1118 passed`, `Failed: 6` — 5 typed
  open-gap failures (EUAI-ACT 4.1, 8.1, 27.1.b, 27.1.e, 27.1.f) + 1
  cross-repo drift red (EUAI-ACT 55.1.d, W509 source-text assertion broken
  by a sibling lane's serde-`rename_all` refactor of
  `/Users/sac/wasm4pm/crates/eu_gate/src/lib.rs`, outside this lane's
  write contract; recorded, not fixed).
- Gate re-run post-drift: `Result: 1112/1113 passed, 5 excluded`, exit 2,
  sole failure 55.1.d.
- Open-gap count 5 (was 10 at W629, 19 at W605).

Standing: PARTIAL_ALIVE (README verified against this subject at run
time; suite drift-coupled to the wasm4pm checkout via 55.1.d).
