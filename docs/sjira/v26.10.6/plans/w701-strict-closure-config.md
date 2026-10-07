# W701 — strict capability-release closure config: RESOLVED-AT-HEAD (no repair required)

Lane W701, xaas v26.10.6, canonical checkout `/Users/sac/xaas`, branch
`feat/playwright-surface`, subject **a0723bf6**. Task (from W645c BLOCKED-B,
receipt `docs/sjira/v26.10.6/plans/w645c-euaia-aggregation-8.md`): fresh build
roots fail `deps.compile ash_a2a` with `cannot build released AgentCard:
:capability_release_closure_missing` because `config/test.exs:156` sets
`capability_release_mode: :strict` with no `capability_release_closure`
configured anywhere.

## Finding

The BLOCKED-B finding is **stale relative to the exact subject**. At HEAD
a0723bf6:

- `config/test.exs` contains **no** `capability_release_mode` key at all.
  Line 146–158 is the ash_a2a block: `security_profile: :legacy_compat`,
  `authority_broker: AshA2A.Authority.Broker.InMemory`,
  `kill_switch_class: :xaas_a2a_test`, with W701-marked comments explaining
  the legacy/strict split. It does not set `capability_release_mode`.
- `capability_release_mode: :strict` exists only in:
  - `config/runtime.exs:213` (inside `if config_env() == :prod`)
  - `config/runtime.exs:222` (inside `if config_env() == :dev`)
  - `deps/ash_a2a/config/runtime.exs:47` (the dep's own prod runtime block)

  All are runtime-exs, non-test-env, and none are loaded during
  `mix deps.compile` (dep compile subprocess loads only the dep's own
  `config/config.exs` + `config/<env>.exs`; runtime.exs is app-start-time).
- With no closure and no strict mode in the compile path, ash_a2a resolves
  `:legacy` mode (`AshA2A.CapabilityRelease.release_config/1` at
  `deps/ash_a2a/lib/ash_a2a/capability_release.ex:358-372`: strict only when
  closure opts present or `Application.get_env(:ash_a2a,
  :capability_release_mode) == :strict`), so `AshA2A.Info.agent_card/2`
  succeeds without a closure. The bench agents in
  `deps/ash_a2a/lib/ash_a2a/chicago/bench/b11_wire.ex` expand their agent
  cards in legacy mode.

## When the fix landed

Commit **cefc9050** ("chore(config): v26.10.6 config alignment (W464 G3;
runtime.exs drift absorbed)", 2026-10-07, verified ancestor of a0723bf6 via
`git merge-base --is-ancestor`) removed `capability_release_mode: :strict`
from `config/test.exs` and installed the current W701-marked legacy_compat +
authority-half block. The W645c BLOCKED-B was recorded against a
pre-cefc9050 subject.

## Falsifier (executed, fresh build root)

Fresh `_build-laneW701` (deleted entirely first), `MIX_ENV=test`,
asdf-pinned toolchain:

```
$ mix deps.compile          # full tree, dependency order
==> ash_surface
Compiling 52 files (.ex)
Generated ash_surface app
[exited with code 0]        # ash_a2a: "Generated ash_a2a app", 1054 .beam files, no AgentCard error
```

Notes: bare `mix deps.compile ash_a2a` on a cold root fails earlier with
`module Plug.Conn is not loaded` (ash_a2a's own deps not yet compiled) —
that is an unrelated compile-order artifact of invoking the task directly,
not the BLOCKED-B error. Compiling the tree in dependency order passes.

```
$ mix test test/eu_ai_act/title_iv_v_test.exs --include eu_ai_act
Finished in 0.3 seconds
Result: 65 passed
[exited with code 0]
```

## Standing

**ALIVE** for the closure-config class at subject a0723bf6: a completely
fresh build root compiles the full dep tree including ash_a2a and passes the
designated falsifier test with zero config changes. W645c BLOCKED-B can be
closed as resolved-by-cefc9050.

## Diff

None. Zero files changed by this lane (verified: `git status` clean for
`config/`). Disclosure: no other files touched. Lane build root
`_build-laneW701` deletion was **denied by the permission system** — left on
disk for the coordinator to delete per lane law.
