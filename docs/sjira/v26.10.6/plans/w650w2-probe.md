# W650w2 — Probe receipt (burn-down court: Xaas.Bridges.Ex4Pm)

Lane W650w2, repo /Users/sac/xaas, branch `feat/playwright-surface`, v26.10.6
campaign. Date 2026-10-07. Build root `_build-laneW650w2` (deleted at lane
close; see Verification). No commit (coordinator owns commits).

## Census (2 candidate families, real greps at 2026-10-07)

Family 1 — Semantics remainder (`lib/xaas/semantics/`): per-module case-
insensitive test-reference census over `test/`:

```
admission_attribution 3 · airo_risk_mapping 2 · authority_channel 7 ·
automation_bias_countermeasure 2 · computation 21 · counterfactual 17 ·
dataset_admission 8 · declared_metrics 6 · eu_ai_act_admission 11 ·
incident_report 10 · jcs 19 · oversight_governance 8 · r2rml 17 ·
registry 71 · robust_margin 13 · vulnerability_lifecycle 3 ·
vkg 14 · vkg/query 186 · vkg/replay 148 · vkg/witness 96 ·
vkg/workspace 5 · graphlaw_wasm 0 (by filename; dedicated files exist:
test/xaas/semantics/graphlaw_wasm_test.exs, _load_test.exs,
_load_verify_test.exs)
```

**Disposition: COVERED** — every module has a dedicated test file under
`test/xaas/semantics/` (ls-verified); no state-bearing gap. (Known W650c
open gaps at robust_margin.ex:107 / vulnerability_lifecycle.ex:98 are
implementation gaps already ledgered in `w650c-terminal-census.md`, not
test-coverage gaps.)

Family 2 — Bridges non-graphlaw (`lib/xaas/bridges/`): dedicated-test census:

| module | dedicated tests | notes |
|---|---|---|
| ferroplan.ex | test/xaas/bridges/ferroplan_test.exs (96 ln) + ferroplan_deepening (278 ln) | covered historically |
| registry.ex | test/xaas/bridges/registry_deepening_test.exs (217 ln) | covered |
| pplan.ex | test/xaas/chicago/ Bridges.PPlanTest (5 tests) | covered |
| sa2a.ex | test/aaas… typo; actual: test/xaas/chicago/bridges/s sa2a_test.exs (6 tests) | covered |
| bridges.ex | exercised via all bridge tests + head_sha unit tests | covered |
| graphlaw.ex | excluded by lane scope (graphlaw) | out of scope |
| **ex4pm.ex** | **NONE — zero direct tests of `discover_model/2` / `conform_purchase/2` anywhere in `test/`** (grep-verified) | **GAP → court** |

(The wasmex-adjacent test/support family was dropped after census: it holds
fixture/support code, no state-bearing lib module of its own.)

## Court target

**`Xaas.Bridges.Ex4Pm`** — `lib/xaas/bridges/bridges.ex` family, top
state-bearing uncovered module in the fresh census: it owns the ETS evidence
store (`ensure_store/1`), projects the sibling's real conformance verdicts,
and mints `ex4pm.receipt:`/`ex4pm.subject_hash:` evidence refs — yet had zero
direct falsifiers. State-bearing: ETS store lifecycle + receipt evidence.

## Court: test/xaas/chicago/bridges/ex4pm_test.exs (7 tests, all green)

Real engine (git-pinned :ex4pm), real inductive/DFG miner, real ETS store.
Asserts on final envelope state. Mutation rationale per test:

1. **object_type fixture** — kill `@object_type` mutation ("Purchase"→any):
   `object_type() == "Purchase"`.
2. **clean-log shape** — kill subject/object-type tag mutation in
   `purchase_log/1`: sorted activity sequence `submit→human_release→settle`,
   every event bound to the subject object.
3. **discover_model ok-path** — kill a mutation that returns a placeholder
   model: non-empty map from the real miner.
4. **malformed-OCEL refusal passthrough** — kill swallowing the sibling's
   typed `Ex4pm.Refusal` into a generic failure: `{:refused, %{code: atom,
   message: binary}}` with subject + `:refused` state preserved. As-real:
   the refusal is the sibling's own typed refusal, passed through.
   `{:refused, %{code: :sibling_error}}` (the catch-all) would NOT satisfy
   the message-presence + subject preservation contract of the mapped clause.
5. **clean self-conformance** — kill receipt-prefix / provenance mutation:
   `state == :conformed`, `authority_ceiling == :none`,
   `receipt_ref` prefixed `ex4pm.receipt:`, `evidence_ref` prefixed
   `ex4pm.subject_hash:`, `fitness == 1.0`, `deviations == %{}`,
   `deviation_count == 0`.
6. **mutation falsifier (the bridge's own docstring falsifier, now
   witnessed)** — a forged pre-settle event the discovered model never saw
   flips the verdict: `fitness < 1.0` (measured 0.667),
   `deviation_count >= 1` (measured 1, deviation `{"settle","submit"} => 1`),
   receipt still attached. Kills "always green" mutation of the conform path.
7. **subject byte round-trip** — kill subject-option mutation: explicit
   `subject:` opt lands byte-for-byte in ok-envelope and in the refusal
   envelope of a malformed conform.

## Verification (real output)

- Standalone: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW650w2 mix test
  test/xaas/chicago/bridges/ex4pm_test.exs` → **7 passed, exit 0**
  (fresh-lane-root compile, 0.3 s).
- Second witness run (whole family dir, includes my 7 + pplan 5 + sa2a 6 +
  registry):
  `mix test test/xaas/chicago/bridges/` → **44 passed, exit 0** (2.0 s).
- Two mid-court failures (assertion-shape fixes: value is a conformance map
  with `.fitness`, not a scalar; `engine` is an atom `:beam`) were repaired
  in-lane; final runs are green. Pre-existing repo state untouched; the only
  diff is the new test file + this receipt.

## Standing

**ALIVE** for `Xaas.Bridges.Ex4Pm` on this subject: real ex4pm engine
execution observed, typed refusal passthrough witnessed, mutation falsifier
(non-conforming log flips fitness 1.0 → 0.667) witnessed green.

Bridges non-graphlaw family standing after this court: **COVERED** — every
non-graphlaw bridge module now has dedicated direct tests.

Falsifiers open elsewhere (pre-existing, not this lane's): W650c's 4 typed
OPEN_GAPs (robust_margin malformed-input clauses, art15 test helper overflow,
vulnerability_lifecycle respond state-machine).
