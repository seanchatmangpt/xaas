# W94 receipt — wasm4pm flake fix (algorithm-selection-with-scaling)

- **Lane**: W94 (integration), v26.10.6 convergence
- **Repo**: /Users/sac/wasm4pm (canonical checkout, no worktree)
- **Trigger**: r10 receipt — main CI red on exactly one test, float-boundary epsilon bug in the test itself
- **Subject**: test file `packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts` (CI-reported path `packages/ml/algorithm-selection-with-scaling.test.ts:407`; actual on-disk path located via find)

## Failure (before)

```
expected 0.30000000000000004 to be less than or equal to 0.3
```

Line 407: `expect(improvement).toBeLessThanOrEqual(0.30);` — `improvement = accuracyScaled - accuracyUnscaled` (float subtraction) landed on `0.30000000000000004`, which is strictly greater than the literal `0.3`.

## Fix (test-only, one line)

```diff
-      expect(improvement).toBeLessThanOrEqual(0.30); // Allow slight overage due to floating-point error
+      expect(improvement).toBeLessThanOrEqual(0.3 + 1e-9); // Allow slight overage due to floating-point error
```

No algorithm/impl changes. No other assertions touched.

## Verification (real output)

- `pnpm install --frozen-lockfile` (deps absent; install allowed per lane contract): exit 0, `Done in 6m 53.1s using pnpm v11.5.2` (one pre-existing benign WARN re `examples/node_modules/.bin/wpm` bin link). **Lockfile unchanged** — `git diff --stat pnpm-lock.yaml` empty.
- Test run (vitest v1.6.1 from `packages/ml`):
```
 ✓ src/__tests__/algorithm-selection-with-scaling.test.ts  (25 tests) 19ms
 Test Files  1 passed (1)
      Tests  25 passed (25)
```

## Boundaries

- Owned files: the test file only. No git mutations, no source/impl edits.
- Unrelated pre-existing working-tree modifications in the repo (`package.json`, `apps/wasm4pm/README.md`, `docs/explanation/prd_ard_receipt_truth_verification.md`) belong to other lanes — untouched.
- Standing: ALIVE (exact file, real run, 25/25 green locally; CI exact-head confirmation pending coordinator integration).
