# W132 Verify Rehearsal — `mix xaas.verify_and_commit` stage-by-stage (no commit)

- Date: 2026-10-06
- Subject: `/Users/sac/xaas` on `feat/playwright-surface` (working tree, unrehearsed-checkout state; no git operations performed)
- Toolchain: elixir 1.20.2-otp-28 / erlang 28.5.0.2 via asdf (`PATH=$HOME/.asdf/shims:$PATH`), `MIX_ENV=test` where noted
- Gate definition: `lib/mix/tasks/xaas.verify_and_commit.ex` — stages are
  `compile` (`mix compile --force --warnings-as-errors`) → `migrate` (`mix ecto.migrate`) →
  `test` (`mix test`) → `mock-grep` (in-process `scan_mock_usage(["test","lib"])`) →
  `commit` (`git add -A` + `git status --porcelain` + `git commit -F <message-file>`).
  First failing stage halts with that stage's real exit status.

## Stage results

| # | Stage | Command (as run) | Result | Exit | Evidence |
|---|-------|------------------|--------|------|----------|
| 1 | mock-grep | `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'` | **PASS** | 0 | Output: `[]` (zero banned-mock hits; warnings only: `autofde` not on PATH, Grafana/PromEx nxdomain — non-blocking) |
| 2 | compile | `MIX_ENV=test mix compile --force --warnings-as-errors` | **FAIL** | 1 | Dep compile fails: `could not compile dependency :ash_surface` |
| 3 | format | `MIX_ENV=test mix format --check-formatted` | **BLOCKED** | 1 | Same `ash_surface` dep compile failure before any formatting verdict |
| 4 | ash codegen check | `MIX_ENV=test mix ash.codegen --check` (check-only variant) | **BLOCKED** | 1 | Same `ash_surface` dep compile failure; no codegen verdict reached |
| 5 | migration state (read-only) | `MIX_ENV=test mix ecto.migrations` | **BLOCKED** | 1 | Same `ash_surface` dep compile failure; migration status unknown |
| 6 | test | `mix test` | **NOT RUN** | — | Gate order runs compile→migrate first; both blocked by stage 2 |
| 7 | squash-style checks | — | **SKIPPED (by rule)** | — | `ash_postgres.squash` is destructive (drops migration history); skipped per rehearsal rules |
| 8 | commit stage | — | **NOT REHEARSED (by rule)** | — | Rehearsal is receipt-only; commit stage untouched |

## Root blocker

`/Users/sac/ash_surface/lib/ash_a2a/resource.ex` (path dep `../ash_surface`, `mix.exs:115`)
— module `AshA2A.Argument` (file line ~46):

```elixir
@enforce_keys [:name, :type]
defstruct [:__identifier__, :__spark_metadata__]
```

`@enforce_keys` names keys (`:name`, `:type`) that are not fields of the struct →
`ArgumentError` in `Kernel.Utils.defstruct/4`. The real fields (`name`, `type`, and the
rest of the original struct) are missing — this is a truncated/broken struct definition in
the sibling repo's checkout, not a xaas-tree defect. Fix belongs in `/Users/sac/ash_surface`
(restore the full struct fields, or drop `@enforce_keys` to match). `deps.compile ash_surface --force`
will not help; the source itself is broken.

Note: the xaas root app itself compiles clean under `MIX_ENV=test` with
`--warnings-as-errors` (904 files, `Generated xaas app`) once past the dep — the failure is
solely the sibling dep's source.

## Remaining blockers to a green `mix xaas.verify_and_commit`

1. **BLOCKED — ash_surface dep source is broken.** Restore `AshA2A.Argument`'s struct
   fields in `/Users/sac/ash_surface/lib/ash_a2a/resource.ex` (or align `@enforce_keys`
   with the actual defstruct). Until then, `compile`, `ecto.migrate`, `test`, `format`,
   and `ash.codegen --check` all halt at dep compilation in every env. This is the
   single blocking hop; fixing it unblocks the rest of the ladder.
2. **UNKNOWN — migration status.** `mix ecto.migrate` stage untested; `mix ecto.migrations`
   could not list pending migrations for the same reason. Must be re-run after blocker 1.
3. **UNKNOWN — full test suite.** `mix test` never reached.
4. **Non-blocking warnings** (do not gate): `autofde` executable absent from PATH (sa2a
   bridge edges degraded); Grafana/PromEx dashboard upload nxdomain (no local Grafana).

## Falsifier for this rehearsal's conclusions

After repairing `ash_surface`'s `AshA2A.Argument` struct, re-run
`MIX_ENV=test mix compile --force --warnings-as-errors` — if the gate compiles past the
dep and later stages produce verdicts, blocker 1 is cleared; if the same
`@enforce_keys`/defstruct ArgumentError reproduces from a restored file, this diagnosis
is refuted.

## Rules honored

No commits, no git state commands, no destructive stages (`ash_postgres.squash` skipped),
`ash.codegen` run in `--check` variant only, receipt-only output.
