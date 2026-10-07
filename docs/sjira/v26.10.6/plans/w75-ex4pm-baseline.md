# W75 — ex4pm Baseline Receipt (v26.10.6 convergence)

- **Date**: 2026-10-06
- **Lane**: W75 integration
- **Repo**: `/Users/sac/ex4pm` (canonical checkout, no worktree)
- **Subject**: `main @ 9f7aecd` ("docs: add verified Diataxis docs set") — matches stated `9f7aecda`
- **Toolchain**: per repo `.tool-versions` (ggen toolchain-unify-pack): elixir 1.20.4-otp-29, erlang 29.1.1, via asdf (`PATH=$HOME/.asdf/shims:$PATH`)
- **Command**: `cd /Users/sac/ex4pm && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test`
- **Role of run**: xaas's pinned ref baseline (pin baselining, no fixes applied, no git operations)

## Result (verbatim tail)

```
Finished in 68.1 seconds (18.8s async, 49.2s sync)

Result: 888 passed (2 doctests, 5 properties, 881 tests), 6 skipped, 60 excluded
```

- **Passed**: 888 (2 doctests, 5 properties, 881 tests)
- **Failed**: 0
- **Skipped**: 6
- **Excluded**: 60

## Failures classified

None — zero failures, zero errors. Nothing to classify.

## Non-failure observations (pre-existing, no action taken)

- Compile warnings in deps and ex4pm test code (e.g. redundant-clause warning in `multigraph` dep `lib/multigraph.ex:2902`, dtype warning in `test/engine_call_log_test.exs:68`). Cosmetic, pre-existing.
- An in-suite ggen sync ran clean: `mix ex4pm.engine.gen.adapter: ggen sync run ok in /Users/sac/.cache/tmp/gen_adapter_164685`.
- **Environment repair (disclosed)**: the working tree had owner-execute bits stripped from many directories (`priv/**`, `deps/yamerl/src` etc., `drw-------`), which made the suite unable to compile (`yamerl.app.src: permission denied`). Restored owner r/x bits via `chmod` on directories/files under the checkout before the run. No file contents changed; no code change; not a git-tracked modification (mode bits only, and git status was already dirty pre-run). First run: compile failure; second run (post-chmod): result above.

## Standing

ALIVE — suite green on the exact pinned subject under the pinned toolchain.
