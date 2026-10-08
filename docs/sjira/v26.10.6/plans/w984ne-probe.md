# W984ne — ash_surface TESTING.md truth sweep receipt

- Subject: `/Users/sac/ash_surface` @ HEAD `154385c82` (branch untouched, no commits). Docs-only edit to `TESTING.md`.
- Scope: bring TESTING.md's Playwright/run-path claims to truth post-W984mf/mk.

## Verification (real commands)

```
cd /Users/sac/ash_surface
npm test
  tests 371 / pass 371 / fail 0 / skipped 0 / duration 2272ms
```

- W984mf receipt on disk: YES (`/Users/sac/xaas/docs/sjira/v26.10.7/plans/w984mf-ash-surface-playwright.md`) — verdict ALIVE for Playwright surface, 365/371 whole-tree with 6 stale-fixture failures.
- W984mk receipt on disk: NO — skipped citing it, per lane instructions.
- Fixture regen landed in working tree (uncommitted): `test/js/fixtures/digest_cross_language_fixtures.json` now contains `532b4a1a15df7688…`, old `db26ae10…` absent (grep-verified). With it, the 6 `digest_cross_language_v3` failures from the W984mf receipt are gone: full suite 371/371, 0 fail, 0 skipped.
- Playwright surface: accessibility suite admitted (0 skipped = runtime gate admitted) against real headless Chromium per the documented CI recipe (playwright@1.63.0, already in node_modules per W984mf install).

## Diff

`TESTING.md` "Playwright surface" section only:
- Added re-witness line: W984mf ALIVE at `154385c82`, citation to the v26.10.7 receipt.
- Added dated **Verified 2026-10-08** block: stale fixture regenerated, `npm test` 371/371 / 0 fail / 0 skipped on this tree, W984mf receipt cited, W984mk receipt explicitly noted as not-yet-on-disk with the regen verified directly from the bytes, and a disclosure that the regenerated fixture is currently uncommitted.

No other claims were stale: header counts (371 JS tests, 26 `test/js/*.test.mjs`), census floor (1257 mix), suite map, zero-config contract — all re-checked against the tree and left as-is.

## Constraints honored

No commit anywhere, no branch change, no stash, no build root created (npm test only, no MIX_BUILD_ROOT). Only file writes: `TESTING.md` (in-repo) and this receipt.
