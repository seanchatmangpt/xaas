# W705 — wasm4pm/ex4pm cross-project gap audit and fill

Lane W705, wave v26.10.6. Subject: `/Users/sac/xaas` @ `feat/playwright-surface`
(dirty tree at dispatch; lane wrote only the files listed under Diffs).
Build root: `_build-laneW705` (MIX_ENV=test), pinned toolchain via asdf shims.

## Gap table

| # | source pattern | xaas status at audit | fill | verdict |
|---|---|---|---|---|
| 1a | wasm4pm `ci.yml` emits `artifacts/ci/receipt.json` (subject_sha admission via `EXPECTED_SHA` assert per job, standing, boundaries) uploaded as artifact | xaas closure-gates.yml had an advisory `receipt` job emitting only a GITHUB_STEP_SUMMARY markdown table — no machine receipt.json, no artifact | `receipt` job now emits `artifacts/ci/receipt.json` (`repository`, `subject_sha` from SUBJECT_SHA env, `run_id`, `standing` ALIVE/PARTIAL_ALIVE from leg results, `legs`, `boundaries`, `advisory`) + `actions/upload-artifact@v4` (if-no-files-found: error, 14d retention) | FILLED |
| 1b | wasm4pm w94 epsilon-bound float flake discipline (`<= 1 + 1e-9` style bounds on computed float boundaries) | bare float `==` exists in several xaas test files (next_read_test.exs:218-224 weights + `Float.round(sum,2)==1.01`; yield_test.exs:171/227 `machinery_share == 0.0`; sa2a execute_test.exs:412 `ratio == 0.0`) | new `test/xaas/w705_float_boundary_discipline_test.exs` re-pins the top 3 site families under the `@eps 1.0e-9` bound; typed note: exact-zero integer-ratio sites (0/58, 0/1) are exact in IEEE754 and correctly use bare == | FILLED (discipline ported; existing tests not edited — lane contract) |
| 2a | ex4pm W604 dual-safe Map.update idiom + canary test pinning observed absent-key semantics | xaas lib/ had no census and no canary; w525d-class absent-key reliance unmeasured | census: **12 absent-key-reliant `Map.update/4` sites in lib/** (listed in test); none dual-safe. Canary + behavior pins for top sites via real public surfaces (FOND.Circuit, Fabric.Planes.Process) in new `test/xaas/w705_map_update_dual_safe_test.exs`. Dual-safe rewrites are lib/ changes — outside this lane's write contract, recorded as typed note | FILLED (census + pins; rewrites deferred, typed UNSUPPORTED(contract) note) |
| 2b | ex4pm w609 reference-oracle trace-language test (independent naive model cross-check) | no reference-oracle test in xaas test/ (grep: 0 hits for choice_graph/ReferenceOracle) | reference-oracle form ported inside the float test: naive machinery_share recomputation cross-checks `Xaas.Sjira.Yield.mine/2`; full trace-language oracle not portable (no choice-graph surface in xaas) | FILLED (adapted form) |

## Map.update/4 absent-key-reliant census (lib/, 12 sites)

- lib/xaas/runtime/fond/circuit.ex:4 — counter init 1
- lib/xaas_web/controllers/ocel_summary_controller.ex:52,53 — counter init 1
- lib/xaas/gall/turtle.ex:139,167,172 — list init [entry]
- lib/xaas/semantics/vkg/workspace.ex:120 — list init [annotated]
- lib/xaas/ultracode/sequenced_drain.ex:239 — counter init 1
- lib/xaas/ultracode/run_validation.ex:798,799 — list init [event]
- lib/xaas/ultracode/semantic_drive.ex:2472 — map init (object descriptor merge)
- lib/xaas/fabric/planes/process.ex:26 — list init [kind]

All are correct under documented OTP semantics ("skip fun on absent key") and
break under any flip; the canary test fails loudly on flip. `Map.update!/3`
sites are exempt (present-key-only by contract).

## CI receipt contract (closure-gates.yml)

`receipt.json` fields mirror wasm4pm `ci.yml`: `repository`, `subject_sha`
(exact-head admission already asserted per leg via `test "$(git rev-parse HEAD)" = "$SUBJECT_SHA"`),
`workflow`, `run_id`, `standing` (ALIVE iff all advisory legs success, else
PARTIAL_ALIVE), `legs` map, `boundaries`, `advisory: true`. Validated YAML-parsable
locally (`python3 -c yaml.safe_load`). Run-level verification happens on GitHub;
this lane verified parse-validity only.

## Diffs (lane contract: new test files + this receipt + closure-gates.yml edit)

- new `test/xaas/w705_map_update_dual_safe_test.exs` (canary + census + Circuit + Process-plane pins)
- new `test/xaas/w705_float_boundary_discipline_test.exs` (w94 discipline at 3 site families + Yield oracle)
- edit `.github/workflows/closure-gates.yml` (machine receipt.json emission + artifact upload; W327/W627 file — coordinated edit appended to the advisory receipt job only)

## Tails / verdicts

- Tests: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/xaas/w705_map_update_dual_safe_test.exs test/xaas/w705_float_boundary_discipline_test.exs` → **8 passed, 0 failed** (0.04s).
- YAML gate: `python3 yaml.safe_load(closure-gates.yml)` → OK.
- Pre-existing failure, not session-introduced: a cold `MIX_BUILD_ROOT=_build-laneW705`
  compile fails in dep `:ash_a2a` (`lib/ash_a2a/chicago/bench/b11_wire.ex` —
  `ArgumentError: cannot build released AgentCard: :capability_release_closure_missing`,
  strict `capability_release_mode` in config/test.exs evaluated at dep compile
  time). The canonical `_build/test` has the dep already built and runs the tests
  green; the lane root was abandoned and left on disk (`_build-laneW705` — rm was
  permission-denied in this session; coordinator should delete it).
- Outstanding: operator promotion of closure-gates legs to blocking remains the
  W327-noted reviewed transition; dual-safe Map.update rewrites remain lib/ work
  outside this lane's contract.
