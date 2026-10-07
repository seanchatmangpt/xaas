# W984bs — DevSeeds guard vs. the e2e boot seed (root cause + fix forward)

Lane: W984bs · Repo: /Users/sac/xaas · Date: 2026-10-07 · Branch: feat/playwright-surface (uncommitted)

## Root cause

W983f's guard (`Xaas.DevSeeds.refute_non_dev_target!/0`, added after
W982r's xaas_test pollution cleanup) requires, in `Mix.env() == :test`,
a real `Ecto.Adapters.SQL.Sandbox` ownership checkout. The W823 e2e seed
(`e2e/seed-library.exs`) is exactly the *opposite* shape: a bare
`MIX_ENV=test mix run` script that deliberately flips the sandbox to
`:auto` and commits the fixture chain to the test DB the Playwright
webServer serves from. So:

- W980l's run (pre-guard): `W823_SEED_OK`.
- W984bc's run (post-guard): `REFUSED(dev_seeds, env=test)` from the
  guard, seed skipped.

Option (a) is false — the e2e seed calls `Xaas.DevSeeds.run/0` directly;
the refusal is the guard itself. The guard is doing its job correctly; a
bare unsandboxed `mix run` in :test IS the leak shape. But the e2e boot
is a legitimate sanctioned committed-write consumer, so fix is (b): an
explicit, call-site-spelled opt-in.

## Fix

- `lib/xaas/dev_seeds.ex`: `run/0` → `run/1` (default `[]`). In `:test`
  env the guard now allows `opts[:e2e] == true` (in addition to the
  existing sandbox-owner clause). The `REFUSED(dev_seeds, env=...)`
  message now documents the e2e path (`Xaas.DevSeeds.run(e2e: true)`,
  e2e/seed-library.exs, W823/W984bs). No change to :dev or bare-run
  behavior — `run()` unsandboxed in :test still refuses (court leg 1).
- `e2e/seed-library.exs`: calls `Xaas.DevSeeds.run(e2e: true)`, with the
  sanction documented in a comment. Nothing else in the script changed
  (`:auto` flip, curation re-pin, `W823_SEED_OK` marker all intact).
- `test/xaas/dev_seeds_env_guard_test.exs`: 2 new legs:
  - `run(e2e: true)` runs the real chain end-to-end (org + 10 books).
  - `run(e2e: false)` from an unsandboxed raw-spawn caller is still
    refused with `REFUSED(dev_seeds, env=test)` and the message names
    `e2e: true` — guard is not vacuous.
- `e2e/global-setup.cjs`: NOT changed — it already shells out to
  `e2e/seed-library.exs`, so the fix is entirely in the seed script.

## Runs (real tails)

1. Guard court (fresh lane build root, full compile):
   `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bs mix test test/xaas/dev_seeds_env_guard_test.exs`
   → `Result: 4 passed`, exit 0. (2 original legs + 2 new legs.)
2. Sibling DevSeeds courts: `mix test test/xaas/dev_seeds_test.exs`
   → `Result: 3 passed`, exit 0 (no regression in the pre-existing
   sandboxed-path courts).
3. Real fresh-boot internal-api spec ×1:
   `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984bs PW_PORT=4149 npx playwright test e2e/internal-api.spec.cjs`
   → boot log: `W55_SEED_OK`, `W823_SEED_OK: next-read library fixtures
   seeded` (13 packs catalog written), **no REFUSED line**; suite:
   `2 passed, 2 skipped (tokenless legs, fail-closed floor asserted per
   the spec's documented tokenless contract; INTERNAL_API_TOKEN not set
   in this session)`, exit 0, 3.1m.

## Standing

ALIVE (this branch, uncommitted). The e2e boot seeds again under the
guard; bare unsandboxed `mix run` in :test still refuses; the opt-in is
spelled at the call site, not ambient.

## Falsifiers (held)

- Existing leg 1 (bare raw-spawn run/0 in :test → REFUSED, table
  unchanged) — still passing.
- New leg: `e2e: false` → REFUSED — passing.
- Fresh boot without the fix reproduced W984bc's typed refusal (observed
  by W984bc, docs/sjira/v26.10.6/plans/w984bc-e2e-revalidate.md).

## Residuals / for coordinator

- `rm -rf _build-laneW984bs` denied by the harness (same as W984aj):
  lane build root left on disk for coordinator cleanup before the
  integration commit.
- No files committed (per lane law); 3 files changed:
  `lib/xaas/dev_seeds.ex`, `e2e/seed-library.exs`,
  `test/xaas/dev_seeds_env_guard_test.exs`.
- The e2e:true committed-write shape (:auto mix run) is not reproducible
  mid-suite (global ownership mode); its unsandboxed witness is the
  fresh-boot run above, not an in-suite court leg.
