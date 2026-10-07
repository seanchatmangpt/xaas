# W35 — autofde oracle gate receipt (v26.10.6)

Date: 2026-10-06 · Lane: W35 · Repos: /Users/sac/xaas, /Users/sac/autofde-lab · No source edits, no git.

## Subject

- xaas @ feat/playwright-surface (working tree; HEAD d1db2b03)
- autofde-lab @ /Users/sac/autofde-lab (working tree, not built — binary already present)

## Skip condition (read, test/xaas/sjira/yield_test.exs:24-26)

```elixir
@autofde System.find_executable("autofde") ||
           (File.exists?(Path.expand("~/autofde-lab/.venv/bin/autofde")) &&
              Path.expand("~/autofde-lab/.venv/bin/autofde")) || nil
```

Note: the task referenced `test/xaas/sa2a/yield_test.exs`; the real file is
`/Users/sac/xaas/test/xaas/sjira/yield_test.exs`.

## Binary provenance

`autofde` is a Python console-script entry point (`autofde = "autofde_lab.cli:main"`,
pyproject.toml:48) installed into the project venv by the autofde-lab package
(uv-managed). It is NOT a Cargo/escript binary. No new build was required:
`/Users/sac/autofde-lab/.venv/bin/autofde` already existed and
`autofde beam-bridge --help` exits 0.

## Oracle run (real)

```
cd /Users/sac/xaas && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  mix test test/xaas/sjira/yield_test.exs
→ Finished in 1.1 seconds ... Result: 8 passed   (0 skipped, 0 failures)
```

The planner differential case used the real `autofde beam-bridge` SA2A allocator
over a real Port via the `~/autofde-lab/.venv/bin/autofde` fallback path — the
skip did NOT fire (0 skips in result).

## Pre-existing blocker disclosed (not introduced by this lane)

The app compile fails tree-wide on the untracked (another lane's)
`lib/xaas_web/a2a/next_read_ash_agent.ex`: `module AshA2A.Protocol.Agent is not
loaded` — the file's own moduledoc documents it as BLOCKED pending an ash_a2a
pin bump (xaas pin `3325032d` 26.9.28 lacks `AshA2A.Protocol.*`; needs
`07180bd3` v26.10.5). To run the oracle I temporarily renamed it to
`next_read_ash_agent.ex.w35-quarantine`, ran the test, and restored it
byte-identical (verified present after run). No content touched.

## CI note for W33 (workflow not edited)

Install autofde-lab's package so the `autofde` console script lands on PATH:

```
# from a checkout of autofde-lab (or a published wheel if one exists):
pip install <autofde-lab checkout>/      # provides `autofde` on PATH
# or, if the repo is cloned to $HOME/autofde-lab on the runner, the test's
# ~/autofde-lab/.venv/bin/autofde File.exists? fallback suffices:
cd autofde-lab && uv venv && uv pip install -e .   # creates .venv/bin/autofde
```

Either satisfies the skip gate; PATH presence of `autofde` is the primary check
(`System.find_executable("autofde")`).

## Standing

ALIVE for the local oracle gate (observed execution, exact command above).
CI wiring remains UNKNOWN until W33 installs the binary on the runner.
