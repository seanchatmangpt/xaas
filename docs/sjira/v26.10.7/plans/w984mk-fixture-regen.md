# W984mk — ash_surface digest fixture regeneration receipt

Lane: W984mk · checkout `/Users/sac/ash_surface` (exact path, branch `feat/playwright-surface`, no commit, no stash, no branch switch)
Root-cause receipt consumed: `w984mf-ash-surface-playwright.md`

## Subject

- Fixture: test/js/fixtures/digest_cross_language_fixtures.json in ash_surface
- Generator: `AshSurface.DigestParityFixtures` (`test/support/digest_parity_fixtures.ex`), written by `AshSurface.DigestParityFixtures.write!/0`
- Second file (discovered during verification): conformance/js/known_divergences.mjs (ash_surface repo)

## Before (stale state, real outputs)

- `mix test test/ash_surface/digest_parity_fixture_test.exs` → **3/4 passed, 1 failed**
  (`on-disk fixture bytes are exactly the fresh real-pipeline encoding` — on-disk C1
  `db26ae10…` vs fresh `DigestParityFixtures.encode()` C1 `532b4a1a…`; C2 also drifted:
  on-disk `0b029bcd…` vs fresh `b9450efc…`)
- `node --test test/js/digest_cross_language_v3.test.mjs` → **6 pass / 4 fail** before regen
  (C1 digest `532b4a1a…` computed by the JS twin, matching the w984mf claim — both
  implementations agree on the new value; fixture bytes were stale)
- `npm test` (full JS suite, before any fix): **371 tests / 367 pass / 4 fail** — all 4 in
  `test/js/conformance_replay.test.mjs`, traced to one stale jsActual pin:
  `sc/lexical-integral-float` in conformance/js/known_divergences.mjs pinned
  `d9ba3544…` (captured at the v26.10.1 bump) while the current JS replay produces
  `ba9b36c3…`. The divergence itself persists; only the captured pin was stale. The
  other 3 failures cascade (FAIL is not a bucket in the by-level census; the scratch-copy
  RED test counted the unpinned FAIL alongside `rs/completed`).

## Actions

1. Regen command (real, run from `/Users/sac/ash_surface`):
   ```
   PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix run -e 'AshSurface.DigestParityFixtures.write!()'
   ```
   Deterministic canonical-JSON render (sorted keys, one trailing newline). Diff is one
   line: C1 `db26ae10… → 532b4a1a…`, C2 `0b029bcd… → b9450efc…`.
2. JS twin agreement verified BEFORE writing: `node --test test/js/digest_cross_language_v3.test.mjs`
   computed `532b4a1a…` against the stale fixture — same value the Elixir pipeline emits.
3. Re-captured the stale jsActual pin for `sc/lexical-integral-float`
   (`d9ba3544…` → `ba9b36c3…`, captured from the real JS replay output, not typed) and
   updated its reason string (v26.10.1 → v26.10.7) in conformance/js/known_divergences.mjs.

## After (verification ladder, real outputs)

- `node --test test/js/digest_cross_language_v3.test.mjs` after regen: **10/10 pass**
  (the file has 10 tests, not 6 as the dispatch estimated)
- `mix test test/ash_surface/digest_parity_fixture_test.exs` after regen: **4/4 pass**
- `npm test` (full suite): **371 tests / 371 pass / 0 fail, exit 0** — full log inspected
  (`ℹ tests 371 / ℹ pass 371 / ℹ fail 0`)

## Standing

- ALIVE on subject: current tree of `/Users/sac/ash_surface` @ `feat/playwright-surface`,
  uncommitted (per dispatch: NO commit). Lane-touched files:
  - `test/js/fixtures/digest_cross_language_fixtures.json` — regenerated fixture (1-line digest change)
  - conformance/js/known_divergences.mjs (ash_surface repo, one jsActual re-captured + reason string)

## Falsifiers (all run, all pass)

- on-disk bytes == `DigestParityFixtures.encode()` (Elixir guard, 4/4)
- JS twin recomputes every fixture digest (10/10)
- full JS suite green (371/371, exit 0)

## Cleanup

Temp logs `/tmp/w984mk-npm-test.log`, `/tmp/w984mk-npm-test2.log` deleted (`rm -f`,
no denial). No lane-local build roots created. No stash, no branch change, no commit.
