# W706 — eyerun_wasi wire-contract deepening (Art. 55.1.d) (receipt)

**Standing**: ALIVE (lane-scoped). **Subject**: xaas @ a0723bf6 (feat/playwright-surface), new file `test/eu_ai_act/eyerun_wire_deepening_test.exs`. Binary subject: `/tmp/w653b-target/release/eyerun_wasi` (628,928 bytes, 2026-10-07 00:07, built per `w653b-binary-leg.md`; symlink `/tmp/w509-target/release/eyerun_wasi` present).

## Defect class

W653b's binary leg backs title_iv_v's Art 55.1.d but had no dedicated court pinning the end-to-end wire contract. W706 adds it: real `System.cmd/3` subprocess runs over real fixture files — ADMITTED wire JSON, both typed REFUSED codes, exit-code discipline, and ×3 determinism.

## Court contents (5 tests, all real subprocess, zero mocks)

| case | candidate | pinned stdout | exit |
|---|---|---|---|
| satisfying | `{"id":"W706-001"}` | exact `{"verdict":"ADMITTED"}` (trimmed-equal) | 0 |
| missing-field | `{"note":...}` | `{"verdict":"REFUSED","code":"REFUSED_REQUIRED_FIELD_MISSING"}` | 0 |
| malformed | `{"broken` | `{"verdict":"REFUSED","code":"REFUSED_INFRASTRUCTURE_FAULT"}` | 0 |
| exit discipline | all 3 | verdict key present, verdict ∈ {ADMITTED, REFUSED} | 0 |
| determinism | all 3, ×3 runs each | byte-identical (stdout+exit) across runs | 0 |

Existence guard: if the binary is absent at both known paths, tests fail with typed message `W706_EYERUN_BINARY_MISSING` naming `docs/sjira/v26.10.6/plans/w653b-binary-leg.md` and the exact cargo rebuild command — never skips silently. `@moduletag :eu_ai_act` is load-bearing: the pinned surface IS the Art. 55.1.d cybersecurity-gate wire evidence.

## Receipt (real run)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW706 \
  mix test test/eu_ai_act/eyerun_wire_deepening_test.exs --include eu_ai_act
Running ExUnit with seed: 233381, max_cases: 32
.....
Finished in 0.2 seconds (0.2s async, 0.00s sync)
Result: 5 passed
```

(First run: compile error — `|>` into `in` right-operand ArgumentError at the exit-discipline assert; fixed forward to `Map.fetch!(Jason.decode!(out), "verdict") in [...]`, rerun green. Pre-existing, unrelated: PromEx/Grafana nxdomain warnings.)

## Boundary

- No commit made; coordinator owns transitions.
- `rm -rf _build-laneW706` denied by permission system — **build dir left for coordinator** (`/Users/sac/xaas/_build-laneW706`).
- Binary consumed read/execute-only; `/tmp` fixtures created and removed per-test via `on_exit`.
