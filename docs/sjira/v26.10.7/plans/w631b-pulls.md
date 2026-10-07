# W631b — BLOCKED-repo pull resolution (v26.10.7 campaign)

Date: 2026-10-07. Resolves W631's 2 BLOCKED repos (ash_expo, ash_atlassian) per
`w631-gitignore-sweep.md`. Protocol: fetch → `git pull --no-rebase` (merge, never
rebase/force) → resolve .gitignore conflicts only → push → verify SHA equality +
`git check-ignore` probes.

## Note on W631 receipt staleness

W631 recorded "remote ahead by 1" for both repos. Re-observed at resolution time:
both were **ahead 1 / behind 2** (ash_expo: 7d48e13, eef8240; ash_atlassian:
b67e6bc, 0c6a519). No incoming commit touched `.gitignore` in either repo, so the
merge introduced no conflicts — union resolution was not needed; both merges were
conflict-free.

## Per-repo record

| repo | branch | local gitignore commit | merge commit | pre-push remote head | post-push local == remote | push |
|---|---|---|---|---|---|---|
| ash_expo | test/end-to-end-codegen | 2d661b0 | 6f876f5 (6f876f5c5482167dcb838205bdd6eb82b58f55b1) | 7d48e13 | Y (6f876f5 both) | OK |
| ash_atlassian | main | 0a186c2 | 0e210ef (0e210efb6237824af2b690f1f50986480207b226) | b67e6bc | Y (0e210ef both) | OK |

### ash_expo

- `git pull --no-rebase` exit 0, conflict-free merge. Incoming: hardening/bench
  codegen commits (11 files, no .gitignore).
- Post-push: `## test/end-to-end-codegen...origin/test/end-to-end-codegen` (no
  ahead/behind). Untracked `docs/`, `mix.lock` pre-existing, untouched.

### ash_atlassian

- First pull attempt refused: local uncommitted README.md edit (dependency-floor
  note, EEF-CVE-2026-93477) would be overwritten — incoming commits also touch
  README.md. Resolution per no-stash rule: `git diff README.md > /tmp/w631b-readme.patch`
  → `git checkout -- README.md` → `git pull --no-rebase` (conflict-free) →
  `git apply --3way` re-applied the lane's edit cleanly. The README edit remains
  **uncommitted working-tree state** owned by its lane — intentionally not committed
  or pushed by W631b.
- Post-push: `## main...origin/main` (no ahead/behind).

## check-ignore probes (W631 method)

Both repos, after merge, dirs created and probed (`git check-ignore -v`):

- `_build/prod` → matched (`/_build/`)
- `target/debug` → matched (`target/`)
- `node_modules/x` → matched (`node_modules/`)
- `.DS_Store` → matched (`.DS_Store`)
- `_build-lane1` → matched (`_build-lane*/`)
- `target-lane1` → matched (`target-lane*/`)

All 6 patterns live in both merged .gitignore files; the lane-lease block
(`# lane-lease build roots (fan-out campaign)` + `_build-lane*/`, `target-lane*/`)
is present at HEAD in both (ash_expo lines 8–13, ash_atlassian lines 10–15).
Probe dirs were removed after verification.

## Standing

- ash_expo: ALIVE (merge commit 6f876f5 pushed, SHA equality verified, all probes pass)
- ash_atlassian: ALIVE (merge commit 0e210ef pushed, SHA equality verified, all
  probes pass; dirty README.md disclosed as retained lane state)
- W631 sweep: 21/21 repos now resolved (19 direct push + 2 via this lane).

## Receipt fields

- Commands/exits: `git fetch` 0; `git pull --no-rebase` 0 (ash_expo), refuse→
  patch-swap→pull 0 (ash_atlassian); `git push` 0 both; `git rev-parse HEAD @{u}`
  equal both; `git check-ignore -v` 6/6 both.
- Replay: `git -C ~/ash_expo rev-parse HEAD @{u}` → 6f876f5…/6f876f5…;
  `git -C ~/ash_atlassian rev-parse HEAD @{u}` → 0e210ef…/0e210ef…;
  `git -C ~/ash_atlassian diff README.md` shows the preserved lane edit.
- Falsifiers: none remaining — both former BLOCKED states eliminated.
