# r10 — wasm4pm survey receipt (integration lane W88, r10)

- date: 2026-10-06
- subject: `/Users/sac/wasm4pm` branch `fix/v26.9.30-ci-fmt-tsc` @ `32deb59f6`
  ("ci: install rdflib and pytest before TypeScript integration tests")
- upstream state: branch **MERGED** as PR #659 into main @ merge commit `a7352d818`
  (2026-10-01). Local head `32deb59` is on origin/main too (contains check).
- mission: v26.10.6 convergence, closure only. Read-only except this receipt.

## Standing: PARTIAL_ALIVE (real evidence, gaps typed)

Executed commands (real output):

1. `cargo fmt --check` (repo root, exact head) → exit 0, no output. The R10
   fmt-drift class (fixed in b35de2ca6) does not recur.
2. `gh run list --branch fix/v26.9.30-ci-fmt-tsc --limit 5` → PR #659 CI run
   36831796609: **failure** — sole failure is `@wasm4pm/ml` vitest
   `algorithm-selection-with-scaling.test.ts:407` AssertionError:
   `expected 0.30000000000000004 to be less than or equal to 0.3`
   (1048/1049 ml tests pass; all other packages green in that run).
   A float-boundary flake in a test's own epsilon bound, not a product defect.
   Sibling workflows on the same head: "Per-item algorithm and breed
   validation" success, "ex4pm-bindings" success.
3. `gh run list --branch main --workflow CI --limit 3` → main-head CI (run
   36833833486, merge of #659) is **also red on the same ml float test** —
   the flake persists at main head; it is the only red on main.
4. Local JS test attempt: `packages/contracts` and `packages/testing`
   `node_modules/.bin/vitest` → MODULE_NOT_FOUND (dangling pnpm symlinks;
   root `node_modules` absent). Local JS suite = **BLOCKED
   (local-deps-install)**: `pnpm install` at repo root required and excluded
   by lane rules (no heavy installs/builds).
5. `gh run list --limit 5` (default branch view) shows only dependabot-PR
   traffic; one dependabot PR CI red, InterviewAssist court green — not
   attributable to the audited head.

X5's "wasm4pm UNKNOWN — check gh if authed" is now resolved: authed `gh`
worked; main-head core CI is red for exactly one known flaky test.

## xaas consumption edges (grep, both repos)

No code dependency either direction.

- `xaas/lib/xaas/bridges/registry.ex:24` — wasm4pm is "the named successor
  engine; reachable only inside ex4pm's …" (prose note, no mix dep).
- `xaas/lib/xaas/chicago/layer.ex:19,32` — wasm4pm listed in
  `@successor_ids ~w(wasm4pm castle)a` (classifier vocabulary only).
- wasm4pm side: no xaas references in package.json deps; the only xaas edge
  is `packages/supabase`-adjacent prose docs.
- Conclusion: **typed NOT_REQUIRED** for an executable xaas→wasm4pm wiring
  edge; consumption is documentary/successor-taxonomy, satisfied as-is.

## Version skew inventory (root 26.10.6 vs workspace)

- `package.json` (root, monorepo): **26.10.6** — bumped by W72 (uncommitted,
  working-tree only).
- 26.9.28 (14 packages, not 13): packages/{agents,cognition,config,
  contracts,engine,kernel(as `wasm4pm`),ml,noun-verb,observability,planner,
  supabase,testing} (12) + `apps/wasm4pm` (@wasm4pm/cli) + `wasm4pm/`
  (@wasm4pm/core). The "13 siblings" figure undercounts by one (wasm4pm/
  core).
- 26.6.25 (6 packages): examples/web-dashboard, examples/zoe-la, playground,
  lab, tests/proof, tests/archive.
- Off-format: apps/playground-web (nuxt template, no version field),
  examples/breeds-ts-consumer 0.1.0, examples/interview-assist (0.1.0, name
  `interviewassist`).
- Skew total: root at 26.10.6, **20 of 21** versioned workspace members stale.

## Exact closure edits (for the convergence lane, not executed here)

1. Bump 14 package.json `version` fields 26.9.28 → 26.10.6 (list above).
2. Bump 6 package.json `version` fields 26.6.25 → 26.10.6 — or, if historical
   fixtures, record typed LEAVE (ggen-marketplace precedent: legacy pack
   names are provenance only).
3. Optional flake guard: widen `algorithm-selection-with-scaling.test.ts:407`
   upper bound to `0.31` (or `toBeCloseTo`) — this alone un-reds main CI
   (sole failure).
4. Commit W72's root bump together with 1–2 so root and siblings move atomically.
5. `apps/wasm4pm/README.md` + one docs file have uncommitted local
   modifications on the audited checkout — carry or discard explicitly at
   integration (they are not part of any pushed head).

## Falsifiers / limits

- FALSIFIED: "CI state UNKNOWN" (X5) — main-head CI is red on one known flake.
- UNRUN: local `pnpm install` + full `pnpm test` (BLOCKED local-deps-install);
  Rust `cargo test`/`cargo build` (excluded: heavy build rule). fmt gate only
  locally; compile/test verdicts come from CI runs 36831796609/36833833486.
- Standing is PARTIAL_ALIVE: real local fmt gate green, CI real-but-red on a
  test-owned float boundary, executable xaas edge NOT_REQUIRED, version skew
  fully inventoried with exact edits listed.
