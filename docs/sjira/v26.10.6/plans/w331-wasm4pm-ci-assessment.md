# W331 receipt — wasm4pm CI-exact-head assessment (DoD 6 wasm4pm leg)

- date: 2026-10-06
- subject: `/Users/sac/wasm4pm` dirty working tree at branch
  `fix/v26.9.30-ci-fmt-tsc` @ `32deb59f6` (contains main per r10; fix present
  uncommitted — `git status` shows `packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts`
  modified in working tree).
- lane: W331 (read-only + run tests; no git mutations).

## 1. The w94 flake fix

From `w94-wasm4pm-flake.md`: main CI (runs 36831796609 PR-head and 36833833486
main-head) was red on exactly one test — float-boundary epsilon bug in the
test itself:

```
expected 0.30000000000000004 to be less than or equal to 0.3
```

Fix (test-only, one line, `packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts:407`):

```diff
-      expect(improvement).toBeLessThanOrEqual(0.30);
+      expect(improvement).toBeLessThanOrEqual(0.3 + 1e-9);
```

Witnessed on disk this session: line 407 carries `0.3 + 1e-9`. The file is in
the working-tree-dirty set; the integration commit has not landed, so no pushed
head contains it and CI cannot see it yet.

## 2. Local gate at dirty head (real output)

`cd /Users/sac/wasm4pm/packages/ml && ./node_modules/.bin/vitest run
src/__tests__/algorithm-selection-with-scaling.test.ts`:

```
 ✓ src/__tests__/algorithm-selection-with-scaling.test.ts  (25 tests) 15ms

 Test Files  1 passed (1)
      Tests  25 passed (25)
   Start at  16:30:30
   Duration  279ms
```

25/25, matching the prior w94 receipt. Note: the task brief's `mix test` is
N/A — wasm4pm is a Rust/TypeScript monorepo, no mix project; the repo's own
gate for this surface is vitest under `packages/ml`.

## 3. CI-exact-head analysis (`.github/workflows/ci.yml`)

- Trigger: `pull_request:` (all) + `push: branches: [main]`. **No path
  filters** — the w94 fix file is inside trigger scope; any push to main
  containing it fires the workflow.
- Exact-head pinning: checkout at
  `ref: ${{ github.event.pull_request.head.sha || github.sha }}` with
  EXPECTED_SHA admission check ("Admit exact head and CI topology") — genuine
  exact-subject semantics, matches doctrine.
- Job "exact-subject Rust/WASM/TypeScript/CLI" steps: rustfmt check, cargo
  compile, command-projection falsifiers, cargo test, wasm-pack 0.13.1
  compile + Node bundle, cognition WASM bundles, TypeScript build
  (contracts/testing leaves first then serialized `-r build`), Python deps
  (rdflib 7.6.0, pytest 9.0.3), **`pnpm test` (TypeScript integration tests —
  the step that exercises the ml vitest suite containing the w94 fix)**,
  published CLI build + real `wpm` execution (model discover on
  data/small-example.xes, system doctor), packed artifact smoke, and an
  emitted `artifacts/ci/receipt.json` with subject SHA + standing.
- Conclusion: once the integration commit lands on main, the CI-exact-head run
  will re-exercise the fixed assertion through `pnpm test` and, on green,
  emit an ALIVE receipt bound to that exact SHA.

## 4. Verdict — proposed _FRONTIER wasm4pm row

> **PARTIAL_ALIVE** — w94 flake fix (test-only epsilon bound,
> `algorithm-selection-with-scaling.test.ts:407` `0.3 + 1e-9`) present at
> dirty head `32deb59f6`; local vitest 25/25 green (re-witnessed W331
> 2026-10-06, 279ms). CI-exact-head GATED-ON integration commit: ci.yml has
> no path filters (fix file in trigger scope), pins exact head, runs `pnpm
> test` → fixed assertion will be exercised and ALIVE receipt emitted on
> green. Confirmation run does not exist yet — do not upgrade to ALIVE until
> the post-merge CI run on the exact integration SHA is observed.

## Falsifiers / limits

- UNRUN: full `pnpm test` monorepo-wide locally (heavy; prior lanes scoped to
  the ml suite — CI `pnpm test` step covers it on the landed head).
- The dirty tree carries unrelated W72 version bumps (r10 item 4/5); landing
  the fix atomically with those is the coordinator's call.
