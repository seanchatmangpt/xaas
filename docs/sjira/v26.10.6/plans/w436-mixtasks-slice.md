# W436 — final-tree mix-tasks test slice receipt

Date: 2026-10-06 · Repo: /Users/sac/xaas @ feat/playwright-surface (no commits made)

## Command

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW436 mix test test/mix/
```

## Real tail (verbatim)

```
.*..................
Finished in 21.8 seconds (0.9s async, 20.9s sync)

Result: 48 passed, 1 skipped, 15 excluded
[os_mon] memory supervisor port (memsup): Erlang has closed
[os_mon] cpu supervisor port (cpu_sup): Erlang has closed
```

Exit code 0. Slice covers test/mix/tasks/ incl. xaas_self_digest_test.exs (w399 G9).

## Verdict

mix-tasks slice **green-at-final-tree** — 48 passed / 1 skipped / 15 excluded, 0 failures. No isolation needed.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW436` was **denied** by the permission system (twice, incl. unsandboxed). Build root (~437 MB) remains on disk at `/Users/sac/xaas/_build-laneW436` — coordinator must delete at integration.
