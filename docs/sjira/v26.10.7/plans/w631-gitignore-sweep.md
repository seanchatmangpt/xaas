# W631 — .gitignore lane-lease sweep (v26.10.7 campaign)

Date: 2026-10-07. Directive: operator "update all the .gitignores then git add commit push".
Scope: .gitignore only, pathspec-limited commit, current branch, never force.

## Method

1. `git check-ignore -q` probe paths (`_build/prod`, `target/debug`, `node_modules/x`,
   `.DS_Store`, `_build-lane1`, `target-lane1`) per repo — authoritative, not grep.
2. Append commented block: `# lane-lease build roots (fan-out campaign)` + missing patterns
   (`_build/`, `target/`, `node_modules/`, `.DS_Store`, `_build-lane*/`, `target-lane*/`).
3. `git add .gitignore` only; `git commit -F /tmp/w631-msg.txt`; push current branch
   (upstream, else `-u origin <branch>`).

## Per-repo table

All 21 repos were missing `_build-lane*/` and `target-lane*/` — block added in every repo.
Extra missing patterns are noted; commit SHA is the lane commit; push = fast-forward to
current branch's remote (no force used anywhere).

| repo | branch | ignore block | extra patterns added | commit | push |
|---|---|---|---|---|---|
| xaas | feat/playwright-surface | Y | `_build/`, `target/` | cab79623 | OK |
| ash_surface | main | Y | `_build/`, `target/` | 8e4c0e73d | OK |
| ash_pplan | fix/ggen-verify-header | Y | `_build/`, `target/`, `node_modules/`, `.DS_Store` | 110f5d6 | OK |
| ash_a2a | feat/tck-vuln-hardening | Y | `_build/`, `target/`, `node_modules/`, `.DS_Store` | f56c06d0 | OK |
| gymact | v26926/gymact-land-aloop-execution-kernel | Y | `_build/`, `target/` | f1c6fd04 | OK |
| ferroplan | main | Y | `_build/`, `node_modules/`, `.DS_Store` | 7808b7a | OK |
| ggen | feat/v26.10.5-release-cut | Y | `_build/` | 6d91b811b | OK (GitHub vuln banner on default branch — pre-existing, informational) |
| ggen_igniter | feat/adr-0010-gate-convention | Y | `node_modules/`, `.DS_Store` | f932056 | OK |
| ggen-marketplace | feat/aaif-gcp-roadmap-v26.10.5 | Y | `_build/`, `node_modules/` | 1258729a1 | OK |
| wasm4pm | fix/v26.9.30-ci-fmt-tsc | Y | `_build/` | 5925d4726 | OK |
| zcode-cli | fix/v26926-preview-publish-typed-skip | Y | `_build/`, `target/` | 8926518 | OK |
| autofde-lab | feat/doctrine-lab | Y | `_build/`, `target/` | 6d70e17a | OK |
| ash_graphlaw | main | Y | `_build/`, `target/`, `node_modules/`, `.DS_Store` | 94da31a | OK |
| ash_dspy | feat/v26926-ashdspy-abb-sbb-seed | Y | `_build/`, `target/`, `.DS_Store` | e3dcc4f | OK |
| ash_kudzu | main | Y | `_build/`, `target/`, `node_modules/`, `.DS_Store` | 257589d | OK |
| ash_planning_center | main | Y | `_build/`, `target/`, `node_modules/`, `.DS_Store` | f555e86 | OK |
| ash_expo | test/end-to-end-codegen | Y | `_build/`, `target/`, `node_modules/`, `.DS_Store` | 2d661b0 | BLOCKED — remote ahead by 1 (non-fast-forward); never force; local commit 2d661b0 retained |
| ash_autofde | main | Y | `_build/`, `target/`, `node_modules/`, `.DS_Store` | 6c68715 | OK |
| ash_atlassian | main | Y | `_build/`, `target/`, `node_modules/`, `.DS_Store` | 0a186c2 | BLOCKED — remote ahead by 1; never force; local commit 0a186c2 retained |
| ash_r2rml | fix/v26.9.29-from-source-head | Y | `target/`, `node_modules/`, `.DS_Store` | dc5e364 | OK |
| ash_affidavit | feat/signing-surface | Y | `target/`, `node_modules/`, `.DS_Store` | a7e1c1b | OK |

(ash_atlassian commit corrected above: 0a186c2. No NO-OP repos — every repo lacked lane patterns.)

## In-flight work preservation

xaas post-commit: `git status --porcelain` still shows 159 dirty/untracked entries;
lane commit `cab79623` touches only `.gitignore` (5 insertions, verified via
`git show --stat`). Pathspec-limited staging kept all other lanes untouched in every repo.

## Standing

- 19/21 repos: committed + pushed, standing ALIVE.
- 2/21 (ash_expo, ash_atlassian): commit landed locally, push BLOCKED
  (NON_FAST_FORWARD; remote 1 ahead each). Resolution is a merge/pull decision
  belonging to the coordinator — not taken unilaterally.

## Receipt fields

- Subject: 21 repos, exact SHAs in table above.
- μ/diff: `.gitignore` append-only per repo (5–8 lines each); zero other files touched.
- Commands/exits: check-ignore probes; append; `git add .gitignore`; `git commit -F`;
  `git push` / `git push -u origin <branch>`; 19 exit 0.
- Replay: `git -C ~/ash_expo push` / `git -C ~/ash_atlassian push` reproduce the two
  non-fast-forward refusals (they are the BLOCKED falsifiers).
