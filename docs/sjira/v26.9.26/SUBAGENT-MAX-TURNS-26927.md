# SUBAGENT-MAX-TURNS-26927 — zcode-cli subagent turn cap wired into Dispatch

Date: 2026-09-27. Coordinator: zcode-cli session sess_88ed4195 (5-lane Explore
wave → single-seam write → scoped gates → atomic commit).

## Source fact (zcode-cli side, branch fix/v26926-preview-publish-typed-skip)

The vendored runtime hardcodes subagent child sessions to
`maxTurns ?? this.config.subagents?.maxTurns ?? 4` and its settings mapper drops
the `subagents` block. Fixed in zcode-cli: the launcher lowers setting.json
`subagents.maxTurns` → env `ZCODE_SUBAGENT_MAX_TURNS`, read by sync-runtime patch
`subagent-max-turns-env` at the spawn site (precedence: explicit env >
launcher-lowered setting.json > upstream 4).

Measured boundary 2026-09-27 (live cap=100, one foreground general-purpose
agent, strictly sequential echo probes): a 10-call probe completes; a 100-call
probe executed ALL 100 tool calls and was then killed — "Reached maximum number
of turns (100)." — before its report. The cap counts the worker's own turns
including the final report: budget = maxTurns − 1 sequential calls.

## Connection (this wave)

xaas workers are launched by `Xaas.Ultracode.Dispatch.spawn_and_collect/2`,
which inherits the BEAM parent environment wholesale and layers `env_added` via
`/usr/bin/env K=V`. The var therefore flowed ONLY by accident of inheritance —
zero xaas code, config, doc, or ticket knew the knob existed (whole-repo rg,
witnessed absent). This wave makes it first-class:

- `config :xaas, :ultracode_subagent_max_turns` (default `nil` = inject
  nothing; `env_added` byte-identical to the pre-lever shape).
- `Dispatch.build/2` prepends `{"ZCODE_SUBAGENT_MAX_TURNS", n}` as the
  LOWEST-precedence injected assignment: a repo `toolchain_env` pin or the
  caller's `:extra_env` (last wins under `/usr/bin/env`) still overrides per
  worker. Precedence chain for a dispatched worker:
  `:extra_env` > `toolchain_env` > this lever > inherited env / launcher
  setting.json lowering.
- anti-vacuity: reverting the lever (nil) removes the tuple (asserted in-test
  against the same subject); the exact-equality env test
  (`plain_plan.env_added == [...]`) stays green unchanged.

## Changes

- `config/config.exs` — lever declared (nil) with rationale + measured boundary
- `lib/xaas/ultracode/dispatch.ex` — `build/2` `turn_cap_env` + moduledoc
  worker-environment contract row
- `test/xaas/ultracode/dispatch_test.exs` — plan-level nil/set/`:extra_env`-wins
  test; real-subprocess arrival test (fake CLI echoes the var from its env)
- `docs/ultracode/multi-repo-run.md` — lever row next to
  `:ultracode_wave_loop_concurrency`

## Gates

| gate | command | exit | result |
|---|---|---|---|
| scoped (MIX_ENV=test, isolated build root; dev server owns shared `_build`) | `MIX_BUILD_ROOT=_build-maxturns mix test test/xaas/ultracode/dispatch_test.exs` | 0 | 34 passed (32 pre-existing incl. byte-for-byte env test + 2 new), 12.4s |

Not run (cheapest-sufficient ladder): full suite — the change is nil-default
inert outside the two new assertions; every other suite exercises `Dispatch`
with the lever unset.

## Deliberately untouched

- The concurrent lane's dirty files (`autonomic.ex` M,
  `capability_resolver*` ??) — disjoint surface, not staged.
- `Verifier.spawn_and_collect/6` (`env -i`) and no-LLM court env scrubs —
  they never launch zcode agents; their scrub posture is intentional.

## History

| ts | standing | note |
|---|---|---|
| 2026-09-27T23:20Z | UNKNOWN | 5-lane Explore wave over ~/xaas: spawn sites (Dispatch rank 1), lever pattern (flat `:ultracode_*`), zero prior maxTurns awareness, Chicago test doctrine, gall-work forwarding precedent |
| 2026-09-27T23:55Z | PARTIAL_ALIVE | lever + injection + 2 tests + docs landed; scoped gate 34/34 exit 0 |
| 2026-09-27T23:58Z | ALIVE | commit (see git log; atomic, 5 files); turn cap observable from config → argv → child env on real dispatch path |
