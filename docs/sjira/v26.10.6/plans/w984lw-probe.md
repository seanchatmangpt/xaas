# W984lw — mutation non-vacuity probe on W984lr's env-falsifier guard

Date: 2026-10-08 · Lane: W984lw · Branch: feat/playwright-surface · NO commit

## Subject

`e2e/seed-library.exs` lines 26-32: W984lr's
`if Mix.env() == :test do ... Sandbox.mode(..., :auto) ... end` guard.
Method: W984ek-family mutation non-vacuity (remove the guard, expect the
original failure to return).

## Mutation (surgical, from cp-snapshot)

`/tmp/w984lw/seed-library.exs.bak` taken via `cp` (no git stash). Mutation:
`if Mix.env() == :test do ... end` removed, the two `Sandbox.mode(..., :auto)`
calls made unconditional — exactly the pre-W984lr behavior.

## Real runs (all from /Users/sac/xaas, asdf shims PATH, pinned toolchain
elixir 1.20.2-otp-28)

| phase | command | result |
|---|---|---|
| before (unmutated, W984lr state) | `MIX_ENV=dev mix run e2e/seed-library.exs` | W823_SEED_OK, exit 0 (per w984lr-fix.md; not rerun pre-mutation this lane) |
| during (mutated) | `MIX_ENV=dev mix run e2e/seed-library.exs` | **FAIL exit 1** — `Ecto.Adapters.SQL.Sandbox.lookup_meta!/1` raise "To use the SQL Sandbox, configure your repository pool as: pool: Ecto.Adapters.SQL.Sandbox" at e2e/seed-library.exs:30; zero `W823_SEED_OK` occurrences (grep -c = 0). Log: /tmp/w984lw/mutated-run.log |
| after (restored, cmp-verified identical) | `MIX_ENV=dev mix run e2e/seed-lbrary.exs` (actual: seed-library.exs) | **W823_SEED_OK 10 library_books seeded, exit 0**. Log: /tmp/w984lw/restored-run.log |

First mutated-run attempt reported `EXIT=0` — that was `tail`'s exit status in
a pipeline, not mix's. Caught and re-run with the exit captured directly
(`REAL_EXIT=1`). Receipt records the direct-capture numbers.

## Falsifier outcome

Removing the guard reintroduces the exact W984lp failure (Sandbox
`lookup_meta!` raise, exit 1, no W823_SEED_OK); restoring it returns
W823_SEED_OK exit 0. The guard is load-bearing. W984lr's fix is non-vacuous.

## Tree cleanliness after restore

- `cmp` snapshot vs working file: byte-identical (RESTORED_IDENTICAL).
- `git diff e2e/seed-library.exs` shows only W984fw's MIX_ENV=dev pin hunks
  (comments + webServer wiring) and W984lr's own guard/read-first hunks.
  Zero W984lw-attributable hunks remain.

## Gates

- No commit. No build root used, none owed.
- Mock gate not owed: no test files touched.
- Mutation artifacts confined to /tmp/w984lw/ (snapshot + run logs).
