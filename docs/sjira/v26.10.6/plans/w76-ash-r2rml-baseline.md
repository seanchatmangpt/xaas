# W76 Integration Lane — ash_r2rml Baseline Receipt (v26.10.6)

- **Subject**: `/Users/sac/ash_r2rml` @ `0d5320f6c5e9a43bb3e8dcb0f30d301b1ebb64d7` (fix branch, equals origin/main)
- **Command**: `cd /Users/sac/ash_r2rml && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test`
- **Toolchain**: elixir 1.18.4-otp-27 via asdf (rebar3 bare compile for deps)
- **Date**: 2026-10-06

## Baseline counts (verbatim)

```
Finished in 13.1 seconds (10.9s async, 2.2s sync)
998 tests, 0 failures, 9 skipped
```

- tests: **998**, failures: **0**, skipped: **9**
- Exit: clean (no failure output; suite finished normally)
- Warnings only: `defp extract_refusals/1` never-used clauses in
  `test/negative/{identity,datatype,relationship,resource}_negative_test.exs` (pre-existing, non-fatal)

## Failures classified

None. 0 failures — nothing to classify.

## Environment repair (disclosed, non-content)

First run failed before any test executed: large parts of the tree (`priv/`,
`deps/telemetry/src`, `deps/yamerl/src`, etc.) had lost owner execute/read bits
(e.g. `deps/telemetry/src` was `drw-------`), so `mix deps.compile telemetry`
failed with "permission denied" and `git status` could not read `priv/`.
Repair: `chmod -R u+rwX /Users/sac/ash_r2rml` (owner permission bits only — no
file content, no git operations, no code change). Post-repair verification:
`find . -type d ! -perm -u+x | wc -l` → `0`. Baseline run above is on the
repaired (content-identical) tree at the same SHA.

## Standing

ALIVE — baseline is green at the exact pinned SHA xaas consumes (`0d5320f6`).
