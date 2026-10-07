# W446 — vault.ex strict-compile recheck post-OS-17

**Lane**: W446 · **Repo**: /Users/sac/xaas @ feat/playwright-surface (canonical checkout, no commit)
**Date**: 2026-10-06 · **Toolchain**: asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW446 mix compile --warnings-as-errors
```

Fresh build root (full dependency + app compile, ~13 min). Real tail:

```
Compiling lib/mix/tasks/xaas.ultracode.learn.ex (it's taking more than 10s)
Compiling lib/mix/tasks/xaas.autonomy.qualify.ex (it's taking more than 10s)
Compiling lib/mix/tasks/xaas.autonomic.controls.ex (it's taking more than 10s)
Generated xaas app
EXIT=0
```

## Findings

1. Exit 0 under `--warnings-as-errors`. Zero warnings mentioning `vault.ex`
   (`lib/xaas/vault.ex:30` `Mix.env() == :prod` CLOAK_KEY guard compiles clean).
2. `Mix.env()` — used in `lib/xaas/vault.ex:30` and `lib/mix/tasks/xaas.stop_court.ex:1627`
   — produced no compiler-deprecation warning under Elixir 1.20.2-otp-28.

## Verdict

**HELD-post-OS-17** — the OS-17 vault.ex guard introduces no warning under strict
compile; W335's HELD verdict survives the guard edit.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW446` — executed (see lane report for confirmation).
