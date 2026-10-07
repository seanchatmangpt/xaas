# W823 — next-read-ml test-env seeding receipt

- **Subject**: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface, lane W823
- **Standing**: ALIVE
- **Failure class addressed**: `next-read-ml x3` from W752 — e2e boot under
  `MIX_ENV=test` serves `/next-read` from `xaas_test`, which had 0
  `library_books` (vs 18 in xaas_dev), so card-dependent specs found an empty
  shelf.

## Seeding approach

Repo seed convention is `Xaas.DevSeeds.run/0` (invoked by
`priv/repo/seeds.exs` in dev): real Ash actions with `authorize?: false`,
idempotent get-or-create by natural key (isbn / email / book_id), 10
`Xaas.Library.Book` rows + dev reader + 2 checkouts + 1 pinned curation. No
raw SQL fixture dumping of library rows (the one raw `users` insert is
DevSeeds' own documented schema-drift exception).

New test-env seed script `e2e/seed-library.exs`:

1. Flips the Ecto SQL Sandbox to `:auto` (config/test.exs sets `:manual`;
   a `mix run` script process owns no sandbox connection).
2. `Xaas.DevSeeds.run/0` — the app's own real seed chain.
3. Re-asserts the cartographer curation's documented pinned state (real Ash
   update) — DevSeeds is get-or-create by book_id, so a prior run's spec
   click that unpins it would otherwise silently kill the ranker's
   `curation_score` input on every later run.

Wired into BOTH entries of `e2e/global-setup.cjs` (`globalSetup()` and the
webServer-boot `catalogOnly()` mode) as a failure-tolerant step, same
pattern as the existing W55 witness seed.

## Spec fix (same failure class, one line of cause)

The pin test targeted `pin-button` `.first()`. With seeded data, the first
candidate is the pre-pinned "The Last Cartographer", so the click *unpinned*
it and the `Pinned` assertion failed against its own seed. Fixed in
`e2e/next-read-ml.spec.cjs`: target the first pin-button filtered
`hasNotText: "Pinned"`.

## Real run tail (PW_PORT=4124, MIX_ENV=test, fresh webServer boot)

```
[2/6] e2e/next-read-ml.spec.cjs:42  › ... expands grounded 'Why this one?' explainability drawer
[3/6] e2e/next-read-ml.spec.cjs:64  › ... librarian pin action dynamically updates curation
[4/6] e2e/next-read-ml.spec.cjs:97  › ... executes student checkout, updates librarian metrics
[5/6] e2e/next-read-ml.spec.cjs:133 › ... executes 'Ask the Catalog' semantic search
[6/6] e2e/next-read-ml.spec.cjs:153 › ... switches between split/student-only/librarian-only
  6 passed (2.4m)
```

First run (before the pin-button fix): 5 passed / 1 failed (pin test
unpinning its own seed) — diagnosed and fixed above; second run green.

## Replay

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW823 \
  mix run e2e/seed-library.exs          # -> W823_SEED_OK 10 library_books seeded
PW_PORT=<leased> MIX_ENV=test MIX_BUILD_ROOT=_build-laneW823 \
  npx playwright test e2e/next-read-ml.spec.cjs
```

Note: under concurrent campaign load (~40 lanes, load avg 48-68), compiles
can be SIGTERMed by memory pressure; `ERL_FLAGS="+S4"` made compiles
survive. Build root `_build-laneW823` NOT deleted — `rm -rf` denied in this
session; coordinator to reclaim per the lane-lease law.

## Files touched (not committed)

- `e2e/seed-library.exs` (new)
- `e2e/global-setup.cjs` (library seed step, both entry modes)
- `e2e/next-read-ml.spec.cjs` (pin test targets first non-pinned button)
- `docs/sjira/v26.10.6/plans/w823-nextread-seed.md` (this receipt)
