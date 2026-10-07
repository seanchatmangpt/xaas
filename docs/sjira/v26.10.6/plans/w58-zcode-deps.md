# W58 — zcode-cli workspace deps install + unit suite receipt

Wave-2 lane W58, v26.10.6. Closes W46's 42-of-44-failure cluster
(`Cannot find module '@earendil-works/pi-tui'` + one `cli-highlight`).

## Finding (1)

- `/Users/sac/zcode-cli` is a self-contained bun project: own `bun.lock`, own
  `package.json`, `node_modules` absent/empty at start. No parent workspace
  (no `~/package.json`, no `~/bun.lock`).
- Both missing packages are declared in zcode-cli's own `package.json`:
  `@earendil-works/pi-tui@^0.85.1` (line 97) and `cli-highlight@^2.1.11`
  (line 104). No workspace-pattern complexity.

## Action (2)

`cd /Users/sac/zcode-cli && bun install` — exit 0, 195 packages installed,
including `@earendil-works/pi-tui@0.85.1` and `cli-highlight@2.1.11`.

Lockfile: `git diff --stat bun.lock` empty — `bun.lock` unchanged by install.
No source edits, no git mutations.

## Verification (3) — after, verbatim

```
 1072 pass
 0 fail
 268359 expect() calls
Ran 1072 tests across 125 files. [90.82s]
```

Command: `ZCODE_REQUIRE_TOOLCHAINS=1 bun test test/*.test.ts` (cwd
/Users/sac/zcode-cli), 90.82s.

Before (W46 receipt, cited): 44 failures, 42 = missing `@earendil-works/pi-tui`,
1 = `cli-highlight`, remainder 1 other. After: 0 fail / 1072 pass. The entire
failure cluster is resolved by dependency install alone.

Standing: ALIVE (unit suite green on real deps, exact commands above).
