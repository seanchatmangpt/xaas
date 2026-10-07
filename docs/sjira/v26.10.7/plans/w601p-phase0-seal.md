# W601p — Phase 0 baseline seal (ash_pplan + wasm4pm)

Date: 2026-10-07. Lane: W601p, v26.10.7 release campaign.
Authority: operator directive — commit+push authorized in ~/ash_pplan and ~/wasm4pm;
never force, never rebase.

## ash_pplan — main advanced: YES

- Branch: `fix/ggen-verify-header` (carries `7eeaaa1` OS-20 dual-safe Map.update).
- Doctrine read: `~/ash_pplan/AGENTS.md` (ontology canonical, standing vocabulary,
  docs-only diff within scope; no generated `lib/ash_pplan/catalog|workflow|providers`
  touched).
- Pre-state: dirty `docs/demonstration.md` (9+/9-), untracked `docs/sjira/v26.10.6/plans/w20-ash-pplan-adjudication.md`; HEAD `343e52a`; `git merge-base --is-ancestor origin/main HEAD` → OK (FF possible).
- Commands/exits:
  - `git add docs/demonstration.md docs/sjira/v26.10.6 && git commit -F /tmp/w601p-app-commit.txt` → exit 0, `6dbd3b0`.
  - `git push -u origin fix/ggen-verify-header` → exit 0, `343e52a..6dbd3b0`.
  - `git push origin HEAD:main` → exit 0, `5f10c97..6dbd3b0` (pure fast-forward; no force, no merge commit).
- SHAs: branch/main head = `6dbd3b0`; prior main = `5f10c97`; OS-20 commit = `7eeaaa1`.
- Standing: seal commit pushed and observed on origin main (ALIVE at transport layer;
  CI against exact head not run in this lane → repo standing unchanged).

## wasm4pm — main advanced: BLOCKED(main-diverged)

- Branch: `fix/v26.9.30-ci-fmt-tsc`.
- Doctrine read: `~/wasm4pm/CLAUDE.md` → `AGENTS.md` (root binding `wasm4pm@da48e98c`,
  claims-may-not-exceed-evidence states).
- Pre-state: 26 tracked files dirty (workspace package.json 26.9.28→26.10.6 bumps,
  receipt-doctor docs `docs/explanation/prd_ard_receipt_truth_verification.md`,
  `packages/ml/src/__tests__/algorithm-selection-with-scaling.test.ts`); untracked
  `crates/eu_gate/` (new Rust crate — out of lane scope, LEFT UNCOMMITTED deliberately).
- Commands/exits:
  - `git add -u && git commit -F /tmp/w601p-w4p-commit.txt` → exit 0, pre-commit checks passed, `bf5d553b9` (26 files, +68/-25).
  - `git push -u origin fix/v26.9.30-ci-fmt-tsc` → exit 0, `d980a2a29..bf5d553b9`.
  - `git merge-base --is-ancestor origin/main HEAD` → non-zero → FF-NO.
- Divergence shape: merge-base = `32deb59f6`; `origin/main` = `a7352d818` ("Merge pull
  request #659 from seanchatmangpt/fix/v26.9.30-ci-fmt-tsc") — a merge commit containing
  this same branch's earlier history, so branch HEAD can never fast-forward main.
  Branch is strictly ahead in content; main carries only the extra merge commit.
- Resolution left to operator (merge or rebase-and-merge the pushed branch via PR);
  per directive, no merge, no rebase, no force performed here.
- SHAs: branch head = `bf5d553b9`; origin/main = `a7352d818`; merge-base = `32deb59f6`.

## Standing

- ash_pplan: ALIVE (seal landed on origin/main, fast-forward, exact SHA `6dbd3b0`).
- wasm4pm branch: ALIVE (pushed, exact SHA `bf5d553b9`); main advance: BLOCKED(main-diverged, merge-commit topology from PR #659).
- Falsifier for "main advanced" claims: `git merge-base --is-ancestor <sha> origin/main`
  after operator action on wasm4pm.
