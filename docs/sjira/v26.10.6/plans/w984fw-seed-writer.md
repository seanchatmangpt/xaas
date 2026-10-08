# W984fw — foreign seed-row writer identified and stopped (W650h23 root cause)

Date: 2026-10-07 · Lane: W984fw · Branch: feat/playwright-surface · NO commit (coordinator owns transitions)

## Identified writer (no longer UNKNOWN)

The liveview_librarian/toggle_pin rows in `Xaas.Library.Curation` were written by the
Playwright e2e pipeline, not by any ExUnit test:

1. `e2e/next-read-ml.spec.cjs` ("librarian pin action dynamically updates curation and
   student card spotlight") clicks `[data-testid="pin-button"]`.
2. That fires `handle_event("toggle_pin", ...)` in
   `lib/xaas_web/live/next_read/reader_live.ex:167`, which runs
   `Xaas.Actuation.run(Curation, :create/:update, ...,
   authority: %{kind: "liveview_librarian", source: "toggle_pin"})` — the exact literals
   of W650h23's committed rows. These are the only occurrences of both literals in
   lib/+test/ (grep evidence).
3. Re-arm channel: when the Playwright webServer inherited `MIX_ENV=test`
   (`reuseExistingServer: true` keeps such servers alive across lanes), the server ran
   against `xaas_test` with NO sandbox checkout, so the click committed real rows. The
   sanctioned seed scripts even flipped `Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto)`
   (e2e/seed-library.exs:23-24), normalizing unsandboxed test-env commits.

Corroborating evidence:
- Live process census (ps aux | beam): the long-lived e2e server PID 37453
  (`mix run -e 'Application.put_env(:xaas, :marketplace_catalog_source, ...)' --no-halt`,
  up since 07:00, PW_PORT=4130) has NO MIX_ENV in its environment — that instance
  targeted xaas_dev. No beam with MIX_ENV=test server role was live at inspection time;
  the writer re-arms on each `MIX_ENV=test npx playwright test` launch.
- Live `xaas_test.library_curations` at inspection: 1 row, curated_by
  `dev-librarian@example.com`, inserted 2026-10-07 18:56 UTC — a DevSeeds fixture row
  from the sanctioned MIX_ENV=test seed path (also stopped by this fix). The original
  12:16/12:22 UTC toggle_pin rows no longer exist (later test runs truncated them).
- ExUnit tests are NOT the writer: all Curation writes in test/ run inside the SQL
  sandbox; W650h23's rows were COMMITTED, which only an unsandboxed process can do.

## Fix (repo-owned, minimal, 3 files)

The entire e2e path is now PINNED to MIX_ENV=dev (xaas_dev), so no Playwright boot,
seed, or spec click can ever write xaas_test again:

- `playwright.config.cjs` — webServer BOOT command now `MIX_ENV=dev` explicitly,
  overriding any inherited MIX_ENV (with W984fw comment naming the class).
- `e2e/global-setup.cjs` — both seed invocations (seed-witness.exs, seed-library.exs)
  `MIX_ENV=test` -> `MIX_ENV=dev`, so fixtures land in the same DB the server serves.
- `e2e/seed-library.exs` — stale "serves from xaas_test" header replaced with the
  W984fw pinned-dev rationale.

Nothing killed: PID 37453 left running (it is already dev-targeted; per-lane instruction
not to kill processes).

## Verification (real outputs)

- `node --check e2e/global-setup.cjs && node --check playwright.config.cjs`
  -> JS_SYNTAX_OK
- `elixir -e 'Code.string_to_quoted!(File.read!("e2e/seed-library.exs"))'`
  -> EX_SYNTAX_OK
- `grep -rn "MIX_ENV=test" e2e playwright.config.cjs` -> only the three W984fw comment
  mentions remain; zero executable test-env invocations.
- `psql xaas_test -c "select ... from library_curations order by inserted_at desc"`
  -> 1 DevSeeds row (18:56 UTC), 0 liveview_librarian rows (see evidence above).
- Mock gate: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984fw mix run -e 'IO.inspect(
  Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'` -> real output `[]`,
  exit code 0. No .ex/.exs test files touched, so no dedicated ExUnit run is warranted
  by the diff; the e2e change is JS/config only.

## Standing

- Writer identification: ALIVE (literal+call-chain evidence, only occurrences in tree).
- Fix: ALIVE at the config/JS layer (syntax-verified, grep-verified). Full e2e re-run
  under the pinned-dev boot is left to the coordinator (a fresh playwright run occupies
  a PW_PORT lease and a dev compile, which the no-dev-compile-during-campaign guard
  advises against right now).
- Falsifier for the fix: `MIX_ENV=test PW_PORT=4199 npx playwright test
  e2e/next-read-ml.spec.cjs` must produce 0 new committed rows in xaas_test
  (`inserted_at > boot time`) — the server now boots dev regardless of inherited env.

## Cleanup

Lane lease cleanup: `rm -rf _build-laneW984fw` was DENIED by the permission system in
this lane session (pretooluse denial, not a filesystem error). The lane build root
`/Users/sac/xaas/_build-laneW984fw` remains on disk for coordinator deletion at
integration.
