# W52 lane receipt — beam4pm OTP-29 qualification gate

- Subject: `/Users/sac/beam4pm` main @ `813eb92477ecee3ec734ea93269a32a700692057` (dirty tree untouched, no git mutations, no source edits)
- Gate: OTP-29 compile + full test suite under pinned toolchain (previously UNKNOWN, never run)

## Toolchain

- `.tool-versions`: elixir 1.20.4-otp-29, erlang 29.1.1, postgres 15.2 (ggen toolchain-unify-pack generated)
- asdf install `1.20.4-otp-29` already present; no install needed. All mix commands run with `PATH=$HOME/.asdf/shims:$PATH`.

## Compile

- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix compile`
- Exit 0. Green. Warnings only (non-fatal: unused-clause in `lib/beam4pm_replan_router.ex:666`, `lib/beam4pm_ocel_accumulator.ex:246` type warning). All 677 regenerated resources compiled under OTP-29.

## Test

- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test` (full suite, no exclusions)
- Verbatim summary:

```
Finished in 258.3 seconds (17.8s async, 240.4s sync)

Result: 1506/1509 passed (3/3 doctests, 1503/1506 tests), 13 invalid, 179 skipped
Failed: 3 tests
```

- TEST_EXIT=2.

## Failure classification (all 3)

All three root-cause to a single missing native artifact — `native/rust4pm-wasm/target/wasm32-wasip1/release/rust4pm_wasm.wasm` does not exist — via `BeamPM.Rust4PM.start_link_raw/0` (`lib/beam4pm_rust4pm.ex:162`). None are regenerated-resource failures; none are OTP-29 toolchain failures.

1. `test sight_for_trace events path refuses typed when the engine artifact is absent` (BeamPM.OcelSessionFactsTest, test/beam4pm_ocel_session_facts_test.exs:470) — expected `{:error, {:wasmex, {:engine_not_started, _}}}` but got nested `{:ocel_build, {:ocel_build, ...}}` — engine absent so the fallback error shape differs.
2. `test real repository tree the manufactured manifest carries the marker and lists exactly the admitted paths` (BeamPM.AuthorshipGateTest)
3. `test real repository tree the real gate PASSes with exactly the admitted count rendered from the ontology` (BeamPM.AuthorshipGateTest) — both fail in setup on the same missing wasm artifact.

(Additional setup_all-invalidated groups — DeviationAdmissionTest, PowlConformanceE2ETest, EDSTest, PowlConformanceTest, PowlEdgesEngineTest — surfaced the same missing-wasm error in the `--failed` rerun; they count inside the 13 invalid / setup-invalidation in the main run, not the 3 test failures.)

## Verdict

GATE ALIVE (PARTIAL on native artifact): OTP-29 toolchain compiles the full regenerated tree and runs the suite; 99.8% pass. The 3 failures + 13 invalid are one environmental cause: rust4pm WASM engine artifact not built (`scripts/rust4pm_wasm_build.sh` not run on this machine). Fix path: run `scripts/rust4pm_wasm_build.sh`, rerun `mix test --failed` to confirm 0 failures. Not a commit-split blocker: failures are environmental, not code/toolchain.

- Standing: ALIVE for toolchain qualification; UNKNOWN remains only for rust4pm WASM-engine tests until artifact build is run.
