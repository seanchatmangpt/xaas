# W46 — zcode-cli stream test receipt (R7 gate before commit)

- Subject: /Users/sac/zcode-cli @ `7fc62da25cf93b38574fd2e8596039f317027ee3`, branch `fix/v26926-preview-publish-typed-skip`, 18 dirty files (stream W46).
- Date: 2026-10-06. Runner: bun 1.4.2.

## Test command identification

`package.json` `"test"` → `bun run test:unit` → `ZCODE_REQUIRE_TOOLCHAINS=1 bun test test/*.test.ts`.
Plain `bun test` (no args, no env) is NOT the unit entrypoint: it sweeps `test/node/*.cjs`
node-only tests which guard-assert `process.versions.bun === undefined` and fail
(748 pass / 63 fail / 58 errors / 811 tests / 167 files, 331s). R7's literal
`bun test` instruction resolved to the package script instead.

## Unit suite (`ZCODE_REQUIRE_TOOLCHAINS=1 bun test test/*.test.ts`)

Verbatim summary line:

```
 676 pass
  44 fail
  43 errors
 7239 expect() calls
Ran 720 tests across 125 files. [38.55s]
```

Failure classification:

- **42 of 44 "fail" = unhandled module-resolution errors** (`Cannot find module
  '@earendil-works/pi-tui'` from `packages/zcode-tui/src/*` and ~20 test files;
  one `Cannot find package 'cli-highlight'`). These are unhandled errors between
  tests, not assertion failures, and are an environment gap (workspace dep
  `@earendil-works/pi-tui` not installed/resolvable in `node_modules`), not
  stream code.
- **1 real assertion failure**: `test/workspace-diff.test.ts:63` —
  `(fail) workspace diff reader > marks only the corresponding binary patch as binary`
  — expected `isBinary: true` for `image.png`, got `isBinary: false`
  (`structuredPatch: []`, status `modified`). Classified **pre-existing** by
  `git stash -u` round-trip: at clean `7fc62da` the same test fails identically
  (4 pass / 1 fail / 5 tests). Stash popped; tree restored to exactly 18 dirty
  files (verified by `git status --porcelain | wc -l` = 18).
- **1 remaining "fail"** is a cascade of the pi-tui module error in the same file
  as a passing group (no separate assertion text in the log).

## Stream-patch-specific tests

`ZCODE_REQUIRE_TOOLCHAINS=1 bun test test/max-turns.test.ts test/expert-strategy-config.test.ts test/sync-runtime-anchor-drift.test.ts`:

```
 19 pass
  0 fail
 62 expect() calls
Ran 19 tests across 3 files. [333.00ms]
```

Both new patches (subagent-max-turns-env via `src/max-turns.ts` +
`test/fixtures/max-turns/setting-subagent-{100,invalid,missing}.json`;
expert-strategy-config via `test/expert-strategy-config.test.ts`) are covered
and green.

## Verdict

R7 gate: PASS for the stream. All stream-touched tests (19/19) pass. The only
real failure (workspace-diff binary detection) is pre-existing at the base SHA
and outside the stream's file set (`src/workspace-diff*` untouched by the
stream). The pi-tui/cli-highlight module errors are environment (incomplete
node_modules), not code. No source edits, no commits. Trivial-fix clause did
not fire (failure is not stream-introduced and not a test typo).
