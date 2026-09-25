# Cleanup and Merge Plan: xaas

## Current State (as observed 2026-09-17)

Evidence gathered via `git status`, `git worktree list`, `git branch -vv`,
`git merge-base --is-ancestor <ref> origin/main`, `git rev-list --count`, and
`du -sh`, run against `/Users/sac/xaas` (canonical repo, remote
`https://github.com/seanchatmangpt/xaas.git`, default branch `main`, current
`origin/main` = `e164ee5`). "Merged" below means
`git merge-base --is-ancestor <branch> origin/main` returned true (the
branch tip is a real ancestor of `origin/main` right now) — not an assumption.

| Path | Type | Branch | Git status | Last commit (date) | Size |
|---|---|---|---|---|---|
| `/Users/sac/xaas` | canonical repo (active) | `feat/execution-actuation-fabric` | **dirty**: 32 changed/untracked paths (wave-v26.9.17 WIP: internal-api-token governance resources, `tick_health`, `docs/adr/`, `docs/target-architecture.md`, `generated/`) | `6ff1a32` 2026-09-17 | 23G (includes the 20G of nested `.claude/worktrees` below) |
| `/Users/sac/xaas/.claude/worktrees/` (20 dirs, `wf_f48be0b4-c6f-*` × 12, `wf_f6a788f1-b0f-*` × 8) | Claude-Code-managed git worktrees of the canonical repo | 20 distinct feature branches (see table below) | 19 of 20 clean; `wf_f6a788f1-b0f-8` has 1 dirty file (`mix.lock`, no committed diff) | mostly 2026-09-11 | 20G total (~1.1G each) |
| `/Users/sac/xaas-worktrees/rename-kanban-to-xaas` | git worktree of canonical repo | `rename/kanban-to-xaas` | clean | `c5f127c` 2026-09-08 | 1.1G |
| `/private/tmp/xaas-pr1` | git worktree of canonical repo | `feat/v26-9-12-substrate` | clean | `21213fc` 2026-09-13 | 1.8G |
| `/private/tmp/uzc/ep1-worktree` | git worktree of canonical repo | `feat/ep1-missed-epoch-receipt` | clean | `fd68647` 2026-09-15 | 9.0M |
| `/private/tmp/xaas-eds` | **orphaned worktree registration** (backup-copy of files; `.git` file is gone) | was `feat/executable-design-science` | not a git repo any more (`git -C ... status` → "not a git repository"); `git worktree list --porcelain` reports `prunable gitdir file points to non-existent location` | n/a (files present, no git identity) | 22M |
| `/private/tmp/xaas-finish-work` | **orphaned worktree registration** (backup-copy of files; `.git` file is gone) | was `main` | same as above — prunable, not a functioning repo | n/a | 22M |
| `/private/tmp/claude-501/.../scratchpad/xaas-docs` | **orphaned worktree registration, directory itself no longer exists** | was `docs/session-update-2026-09-01` | `git worktree list --porcelain` still lists it as `prunable gitdir file points to non-existent location`; `ls` of the parent scratchpad confirms the `xaas-docs` directory is gone | n/a | 0 (deleted already) |

This is the same failure pattern three times over: a worktree's checkout
directory was deleted by hand (the `.git` worktree-admin link is broken or
the directory is gone outright) without first running `git worktree remove`,
so the canonical repo's `.git/worktrees/` metadata is now stale. This is
almost certainly what "deleted gemma manually" refers to in kind, even
though no directory literally named `gemma` turned up anywhere under `~`,
`/Users/sac/xaas*`, or `/private/tmp` in this investigation (see Open
Questions).

### Branch merge status for every branch with a live worktree

Checked with `git merge-base --is-ancestor <branch> origin/main`
(`origin/main` = `e164ee5`, fetched fresh at investigation time):

| Branch | Worktree path | Status vs `origin/main` |
|---|---|---|
| `feat/execution-actuation-fabric` | `/Users/sac/xaas` | **NOT merged** — 15 ahead, 0 behind (today's active work) |
| `codex/causal-admission-closure` | `.claude/worktrees/wf_f6a788f1-b0f-1` | MERGED |
| `codex/deterministic-generation-closure-impl` | `.claude/worktrees/wf_f48be0b4-c6f-13` (dup: `wf_f48be0b4-c6f-42`) | MERGED |
| `codex/formal-proposal-coupling-engine-impl` | `.claude/worktrees/wf_f48be0b4-c6f-4` | MERGED |
| `codex/object-centric-event-projection-impl` | `.claude/worktrees/wf_f48be0b4-c6f-11` (dup: `wf_f48be0b4-c6f-35` / `review-ocep`) | **NOT merged** — 1 ahead (`d57daed`), 120 behind |
| `codex/planning-regime-router-impl` | `.claude/worktrees/wf_f48be0b4-c6f-2` | MERGED |
| `codex/temporal-process-memory-impl` | `.claude/worktrees/wf_f48be0b4-c6f-8` (dup: `wf_f48be0b4-c6f-38`) | **NOT merged** — 1 ahead (`7e7a560`), 120 behind |
| `codex/unified-causal-receipt-impl` | `.claude/worktrees/wf_f48be0b4-c6f-9` (dup: `wf_f48be0b4-c6f-34`) | MERGED |
| `docs/refresh-agents-20260823` | `.claude/worktrees/wf_f6a788f1-b0f-7` | MERGED |
| `feat/ash-project-measure-extension` | `.claude/worktrees/wf_f6a788f1-b0f-9` | MERGED |
| `feat/fly-ggen-workbench` | `.claude/worktrees/wf_f6a788f1-b0f-4` | MERGED |
| `feat/frontier-release-product-surface` | `.claude/worktrees/wf_f6a788f1-b0f-2` | **NOT merged** — 5 ahead, 108 behind |
| `feat/ontology-reactor-closure` | `.claude/worktrees/wf_f6a788f1-b0f-8` | **NOT merged** — 30 ahead, 108 behind, plus 1 dirty file (`mix.lock`) |
| `fix/current-main-compile-warnings` | `.claude/worktrees/wf_f6a788f1-b0f-3` | **NOT merged** — 3 ahead, 108 behind |
| `pr34-automation-claude-daily-drain` (tracks `automation/claude-daily-drain`) | `.claude/worktrees/wf_f6a788f1-b0f-5` | MERGED |
| `agent/connect-castle-paas-20260826` | `.claude/worktrees/wf_f6a788f1-b0f-6` | **NOT merged** — 15 ahead, 108 behind |
| `rename/kanban-to-xaas` | `/Users/sac/xaas-worktrees/rename-kanban-to-xaas` | MERGED |
| `feat/v26-9-12-substrate` | `/private/tmp/xaas-pr1` | **NOT merged** — 1 ahead (`21213fc`), 33 behind |
| `feat/ep1-missed-epoch-receipt` | `/private/tmp/uzc/ep1-worktree` | **NOT merged** — 10 ahead, 0 behind (fully caught up with `origin/main` plus unique work) |
| `feat/executable-design-science` (orphaned worktree) | `/private/tmp/xaas-eds` | MERGED |
| `main` (orphaned worktree) | `/private/tmp/xaas-finish-work` | MERGED (local `main` itself is 33 behind `origin/main`, but every commit it has is already in `origin/main`) |
| `docs/session-update-2026-09-01` (orphaned worktree, dir gone) | (was) `xaas-docs` scratchpad | **NOT merged** — 1 ahead (`da1ad65`), 208 behind. Content is not lost: the branch ref still exists in the canonical repo's refs, independent of the deleted checkout. |

Also checked: 21 dangling local branches named `worktree-wf_f48be0b4-c6f-*`
and `worktree-wf_f6a788f1-b0f-*` (leftover refs from worktrees whose
directories are already gone, pointing at `8720ab1` and `e29a658`
respectively) — **both are MERGED** into `origin/main`. Safe to delete as
branch refs; no directory to remove.

## What "merged" should look like

**`/Users/sac/xaas` becomes the single canonical path going forward.**
Evidence: it is 0 commits behind `origin/main` (every other worktree lags
33-208 commits behind), it carries today's active commit (`6ff1a32`,
2026-09-17) and today's uncommitted wave-v26.9.17 work, it is the only path
with the `origin` remote wired in as the working repo (all others are
worktrees *of* this same `.git`, not independent clones), and it is the
directory the Claude Code session is actually running in.

For every other path in the family:

- **`/Users/sac/xaas/.claude/worktrees/wf_f48be0b4-c6f-{1,2,4,9,13,34,35,38,42}` and `wf_f6a788f1-b0f-{1,5,7,9}`** (13 of 20) — branches already MERGED into `origin/main`, clean working trees. Stale Claude-Code worktrees with nothing unique left to lose. Safe to `git worktree remove` directly, no merge needed.
- **`/Users/sac/xaas/.claude/worktrees/wf_f48be0b4-c6f-11`** (branch `codex/object-centric-event-projection-impl`, dup `wf_f48be0b4-c6f-35`/`review-ocep`) — 1 unique unmerged commit `d57daed`. Before deleting either copy: cherry-pick `d57daed` onto the canonical repo's default branch (or confirm with the user it's superseded/abandoned), then remove both duplicate worktrees.
- **`/Users/sac/xaas/.claude/worktrees/wf_f48be0b4-c6f-8`** (branch `codex/temporal-process-memory-impl`, dup `wf_f48be0b4-c6f-38`) — 1 unique unmerged commit `7e7a560`. Same treatment: cherry-pick or confirm abandoned, then remove both duplicate worktrees.
- **`/Users/sac/xaas/.claude/worktrees/wf_f6a788f1-b0f-2`** (`feat/frontier-release-product-surface`, 5 unique commits), **`wf_f6a788f1-b0f-3`** (`fix/current-main-compile-warnings`, 3 unique commits), **`wf_f6a788f1-b0f-6`** (`agent/connect-castle-paas-20260826`, 15 unique commits), **`wf_f6a788f1-b0f-8`** (`feat/ontology-reactor-closure`, 30 unique commits + 1 dirty `mix.lock`) — each has real unmerged, unique work. **MANUAL REVIEW REQUIRED**: for each, review the branch's commits (`git log origin/main..<branch>`), decide land-via-PR vs. discard, and only then remove the worktree. `wf_f6a788f1-b0f-8` additionally has an uncommitted `mix.lock` diff that must be inspected (commit it or discard it) before removal.
- **`/Users/sac/xaas-worktrees/rename-kanban-to-xaas`** — branch `rename/kanban-to-xaas` is MERGED, clean. Stale worktree of the canonical repo, safe to `git worktree remove` directly.
- **`/private/tmp/xaas-pr1`** — branch `feat/v26-9-12-substrate`, 1 unique commit `21213fc` (ggen_igniter 26.9.12 upgrade), clean. Confirm whether this upgrade is still wanted; if so cherry-pick `21213fc`, otherwise discard. Not automatable without that decision.
- **`/private/tmp/uzc/ep1-worktree`** — branch `feat/ep1-missed-epoch-receipt`, 10 unique commits, clean, fully caught up with `origin/main` (0 behind). This looks like real, ready-to-land feature work (ERRC RAISE batches + a real fix). **MANUAL REVIEW REQUIRED**: review and either open a PR / merge, or explicitly decide to discard, before removing this worktree.
- **`/private/tmp/xaas-eds`** and **`/private/tmp/xaas-finish-work`** — both are orphaned worktree registrations (the `.git` worktree link is gone; `git worktree list --porcelain` reports `prunable`). Both branches (`feat/executable-design-science`, `main`) are already fully MERGED into `origin/main`, so no content is at risk. These are plain leftover file trees now, not live repos. Safe to `git worktree prune` (to clear the stale registration) and then delete the directories outright — no merge needed.
- **`/private/tmp/claude-501/.../scratchpad/xaas-docs`** — orphaned worktree registration whose directory no longer exists on disk at all. Its branch `docs/session-update-2026-09-01` has 1 unique unmerged commit (`da1ad65`), but that commit is **not at risk** — it is still reachable from the branch ref in the canonical repo's own refs, independent of the deleted checkout. Just needs `git worktree prune` to drop the stale registration; if the commit's content is wanted, cherry-pick `da1ad65` directly (no working tree needed for that).
- **21 dangling `worktree-wf_*` branch refs** (no directory exists for any of them) — all MERGED into `origin/main`. Safe to `git branch -D` directly.

## Commands to run (in order), once approved

```bash
cd /Users/sac/xaas

# 1. Clear the 3 stale/orphaned worktree registrations (files can then be deleted safely below)
git worktree prune -v

# 2. Remove the 13 fully-merged, clean .claude/worktrees (no unique work)
for wt in \
  .claude/worktrees/wf_f48be0b4-c6f-1 \
  .claude/worktrees/wf_f48be0b4-c6f-2 \
  .claude/worktrees/wf_f48be0b4-c6f-4 \
  .claude/worktrees/wf_f48be0b4-c6f-9 \
  .claude/worktrees/wf_f48be0b4-c6f-13 \
  .claude/worktrees/wf_f48be0b4-c6f-34 \
  .claude/worktrees/wf_f48be0b4-c6f-35 \
  .claude/worktrees/wf_f48be0b4-c6f-38 \
  .claude/worktrees/wf_f48be0b4-c6f-42 \
  .claude/worktrees/wf_f6a788f1-b0f-1 \
  .claude/worktrees/wf_f6a788f1-b0f-5 \
  .claude/worktrees/wf_f6a788f1-b0f-7 \
  .claude/worktrees/wf_f6a788f1-b0f-9 \
; do
  git worktree remove "$wt"
done

# NOTE: wf_f48be0b4-c6f-35 and wf_f48be0b4-c6f-38 are removed above only if
# step 3's cherry-pick decision (below) is "abandon" -- if you cherry-pick
# d57daed / 7e7a560 instead, remove the OTHER duplicate copy in step 3, not
# these two, and drop them from this list.

# 3. MANUAL REVIEW REQUIRED before any command: unique unmerged single commits
#    Review each, then either:
git log -p d57daed -1   # codex/object-centric-event-projection-impl, in wf_f48be0b4-c6f-11 (dup wf_f48be0b4-c6f-35)
git log -p 7e7a560 -1   # codex/temporal-process-memory-impl, in wf_f48be0b4-c6f-8 (dup wf_f48be0b4-c6f-38)
git log -p 21213fc -1   # feat/v26-9-12-substrate, in /private/tmp/xaas-pr1
git log -p da1ad65 -1   # docs/session-update-2026-09-01, only reachable via branch ref now
#    ... then cherry-pick the ones you want onto the branch you're targeting:
#    git cherry-pick <sha>
#    ... then remove the now-redundant worktrees:
git worktree remove .claude/worktrees/wf_f48be0b4-c6f-11
git worktree remove .claude/worktrees/wf_f48be0b4-c6f-35
git worktree remove .claude/worktrees/wf_f48be0b4-c6f-8
git worktree remove .claude/worktrees/wf_f48be0b4-c6f-38
git worktree remove /private/tmp/xaas-pr1

# 4. MANUAL REVIEW REQUIRED: real unmerged multi-commit feature work -- do
#    NOT remove until reviewed and either landed (PR/merge) or explicitly
#    discarded by the user.
#      .claude/worktrees/wf_f6a788f1-b0f-2   (feat/frontier-release-product-surface, 5 commits)
#      .claude/worktrees/wf_f6a788f1-b0f-3   (fix/current-main-compile-warnings, 3 commits)
#      .claude/worktrees/wf_f6a788f1-b0f-6   (agent/connect-castle-paas-20260826, 15 commits)
#      .claude/worktrees/wf_f6a788f1-b0f-8   (feat/ontology-reactor-closure, 30 commits + dirty mix.lock)
#      /private/tmp/uzc/ep1-worktree         (feat/ep1-missed-epoch-receipt, 10 commits)
#    Once reviewed and disposed of, remove with:
#      git worktree remove <path>

# 5. Remove the now-orphaned plain directories (branches already confirmed
#    MERGED above; step 1's prune already cleared their git registration)
rm -rf /private/tmp/xaas-eds
rm -rf /private/tmp/xaas-finish-work
# (the third orphan, .../scratchpad/xaas-docs, is already gone from disk --
# step 1's prune is all that's needed for it)

# 6. Remove the stale worktree of the canonical repo (branch already MERGED)
git worktree remove /Users/sac/xaas-worktrees/rename-kanban-to-xaas

# 7. Delete the 21 dangling merged branch refs left behind by earlier
#    worktree removals (verify each is still MERGED right before deleting --
#    origin/main may have moved since this document was written)
for b in $(git branch --list 'worktree-wf_*' | tr -d ' '); do
  git branch -D "$b"
done

# 8. Final check -- worktree list should now show only the canonical repo
#    plus any worktrees you deliberately kept in step 4
git worktree list
```

## Open Questions

- **"gemma"**: the user's request mentions having "deleted gemma manually."
  No directory, branch, worktree, or file named `gemma` (or containing that
  string) turned up anywhere under `/Users/sac/xaas*`, `/Users/sac/xaas-worktrees`,
  or `/private/tmp` during this investigation. If `gemma` refers to something
  outside the xaas git family (e.g. a model weights directory, an unrelated
  project), it is out of scope for this plan — point at the actual path if
  cleanup receipts are wanted for it too.
- **`.claude/worktrees/wf_f6a788f1-b0f-8`'s dirty `mix.lock`**: git shows it
  modified but the diff could not be attributed to intentional work vs. a
  stray `mix deps.get` run in that worktree. Needs a human look before
  deciding to commit or discard it.
- **The 4 real unmerged feature branches** (`feat/frontier-release-product-surface`,
  `fix/current-main-compile-warnings`, `agent/connect-castle-paas-20260826`,
  `feat/ontology-reactor-closure`) and **`feat/ep1-missed-epoch-receipt`** and
  **`feat/v26-9-12-substrate`**: git alone cannot tell whether this work is
  still wanted, superseded by what's already on `origin/main`, or abandoned.
  Only the user can make that call per branch.
- **Two duplicate-content worktree pairs** (`d57daed` checked out in both
  `wf_f48be0b4-c6f-11` and `wf_f48be0b4-c6f-35`/`review-ocep`; `7e7a560` in
  both `wf_f48be0b4-c6f-8` and `wf_f48be0b4-c6f-38`): both copies in each
  pair are byte-identical at the commit level, so it does not matter which
  physical directory is kept if the commit is cherry-picked — this plan
  assumes either copy is disposable once the cherry-pick decision is made,
  but did not verify the working-tree contents (build artifacts, local
  `_build/`) are identical, only the git history.
- **`/Users/sac/xaas` itself has 32 uncommitted files** (today's
  wave-v26.9.17 work: internal API token governance, `tick_health`,
  `docs/adr/`, `docs/target-architecture.md`, `generated/`). This plan
  treats that work as intentional, in-progress, and out of scope for
  cleanup/deletion — it is the reason this path is canonical, not a cleanup
  target. Confirm before running anything that touches `/Users/sac/xaas`
  itself.

## Merge Execution Log (2026-09-17)

Evaluation/merge pass executed against the state above, re-verified fresh
immediately before acting (`git status`, `git worktree list`,
`git merge-base --is-ancestor <branch> origin/main` for all 22 branches,
`git ls-remote --heads origin`) — all counts matched this doc exactly
(`origin/main` still `e164ee5`), so no state had drifted since the doc was
written. Per the task's hard constraints: **no delete, prune, worktree
remove, branch delete, reset --hard, or discard of any kind was performed.**
All actions below are additive commits and non-force pushes to the existing
`origin` remote only, in the branch's own name (no new remote, no force,
no push to `main`).

### What "evaluate and merge" meant here, concretely

Landing every unmerged branch's commits onto `main` was **not** done — that
requires a human land/discard decision per the Open Questions above, which
this pass could not make on git evidence alone. What *was* actionable
without guessing: every one of these branches' unique commits already
exists in `/Users/sac/xaas`'s own `.git` (the worktrees share one repo), so
the safe, purely-additive move was to **push each branch to `origin` under
its own name**, whether or not `origin` already had a same-named branch.
This gets every unique commit backed up on the canonical repo's remote
(satisfying "captured in the canonical repo, pushed where a remote exists")
without deciding land-vs-discard, without touching `main`, and without
removing any worktree or local branch. That decision (open a PR / merge to
`main`, or explicitly discard) remains fully open, per branch, below.

### Actions taken

1. **`wf_f6a788f1-b0f-8` dirty `mix.lock` — committed, not discarded.**
   Inspected the diff first: it was 100% additions (7 new lock entries —
   `ash_r2rml`, `json_ld`, `rdf_xml`, `saxy`, `sparql_client`, `tesla`,
   `content_type` — zero removals, zero version bumps to existing entries),
   and every added entry is a transitive dependency of `ash_r2rml`, which is
   already committed on this same branch (`8ce35bb`, `a5357f2`). This is a
   lockfile completion consistent with the branch's own already-committed
   work, not stray/unrelated state, so per the "preserve, don't discard"
   constraint it was committed as a real commit rather than left dirty or
   reset:
   - Commit **`1c792a4e61ef2b97a5eeeae350f043baf4fe4e42`** — `chore(deps):
     complete mix.lock transitive entries for ash_r2rml` — on
     `feat/ontology-reactor-closure`, in
     `/Users/sac/xaas/.claude/worktrees/wf_f6a788f1-b0f-8`.
   - Not independently `mix compile`-verified in that worktree (lockfile-only
     change, no source edits; skipped a full dependency fetch/compile there
     to stay inside this task's git-only scope) — disclosed as unverified,
     not claimed as tested.

2. **Pushed 4 branches to `origin` as fast-forwards** (`origin` already had
   an older tip for each; verified `git merge-base --is-ancestor <old-remote-tip>
   <local-tip>` before pushing, i.e. confirmed no divergence, so no force was
   needed or used):
   | Branch | origin before | origin after |
   |---|---|---|
   | `fix/current-main-compile-warnings` | `7fd7e38` | `ef23db9` |
   | `feat/ontology-reactor-closure` | `b4b399e` | `1c792a4` (includes the `mix.lock` commit above) |
   | `feat/frontier-release-product-surface` | `f2d84c5` | `9f7886b` |
   | `agent/connect-castle-paas-20260826` | `f9432c0` | `0c69c89` |

3. **Pushed 5 branches to `origin` as new branches** (no prior remote
   counterpart existed; plain additive branch creation, nothing overwritten):
   | Branch | origin tip (new) | Source worktree |
   |---|---|---|
   | `codex/object-centric-event-projection-impl` | `d57daedd05d39741d353167707a1c18673840234` | `.claude/worktrees/wf_f48be0b4-c6f-11` |
   | `codex/temporal-process-memory-impl` | `7e7a5606dcfdb13cc5d894590f9085bd181755ac` | `.claude/worktrees/wf_f48be0b4-c6f-8` |
   | `feat/v26-9-12-substrate` | `21213fcd95ebce625817f6a2a00651ad362bc727` | `/private/tmp/xaas-pr1` |
   | `feat/ep1-missed-epoch-receipt` | `fd686479e0c8c343e4f59beba3526e31f7dcf407` | `/private/tmp/uzc/ep1-worktree` |
   | `docs/session-update-2026-09-01` | `da1ad652599b81713a1e4c5a0f499c87d7f6d6b7` | (orphaned worktree; branch ref only, directory already gone) |

   `git ls-remote --heads origin` re-checked after all pushes and confirms
   all 9 branches above are present at exactly these SHAs.

4. **No `git subtree add` performed.** Re-scanned this doc and the family's
   repos for an independent-history, no-shared-ancestor scaffold (the hard
   constraint's named example: "an independent Elixir/Phoenix scaffold").
   None of the paths in this doc's table are independent clones — every one
   is a worktree of `/Users/sac/xaas`'s own `.git` (confirmed by
   `git worktree list`), so every branch shares full history with `main`
   already. No subtree-import case exists in this family; none was
   performed.

5. **No action taken** on: the 13 fully-merged clean `.claude/worktrees`
   entries, `rename-kanban-to-xaas`, `xaas-eds`, `xaas-finish-work`, or the
   21 dangling `worktree-wf_*` branch refs. All are already fully MERGED
   into `origin/main` — there is no unique content in any of them left to
   capture, only removal/pruning remains, which is explicitly out of scope
   for this pass.

6. **No action taken** on `/Users/sac/xaas` itself (the canonical repo's own
   32/49-path dirty working tree). It was re-confirmed still present and
   unchanged by this pass (`git status --short` before and after this pass's
   git operations was identical for this path). Per this doc's own Open
   Questions and the task's confidence bar, committing or pushing someone
   else's in-progress WIP without an explicit go-ahead on *that specific*
   content is not a call this pass had enough confidence to make.

### Still open (unchanged from before this pass, now with content additionally backed up on `origin`)

- **Land-vs-discard decision**, still required from the user, for each of
  (now all present on `origin`, ready for a PR/compare view or a direct
  fast-forward merge to `main` once decided):
  `codex/object-centric-event-projection-impl` (`d57daed`),
  `codex/temporal-process-memory-impl` (`7e7a560`),
  `feat/v26-9-12-substrate` (`21213fc`),
  `docs/session-update-2026-09-01` (`da1ad65`),
  `feat/frontier-release-product-surface` (5 commits),
  `fix/current-main-compile-warnings` (3 commits),
  `agent/connect-castle-paas-20260826` (15 commits),
  `feat/ontology-reactor-closure` (30 commits + the new `mix.lock` commit),
  `feat/ep1-missed-epoch-receipt` (10 commits).
- **"gemma"** — still unresolved; nothing matching turned up anywhere in
  this pass either.
- **Safe-to-delete-once-confirmed, for the separate deletion pass** (content
  risk is now fully eliminated for all of these — every branch listed above
  is on `origin`, and everything below was already MERGED before this pass
  even started):
  - The 13 fully-merged clean `.claude/worktrees` entries listed in this
    doc's "Commands to run" step 2.
  - `.claude/worktrees/wf_f48be0b4-c6f-11` and `wf_f48be0b4-c6f-35`
    (dup of `codex/object-centric-event-projection-impl`, now on `origin`)
    and `wf_f48be0b4-c6f-8` / `wf_f48be0b4-c6f-38` (dup of
    `codex/temporal-process-memory-impl`, now on `origin`) — once a
    land/discard decision is made for those two commits, both copies of
    each pair are disposable.
  - `/Users/sac/xaas-worktrees/rename-kanban-to-xaas` (MERGED, clean).
  - `/private/tmp/xaas-eds`, `/private/tmp/xaas-finish-work` (orphaned,
    MERGED, prunable).
  - `/private/tmp/claude-501/.../scratchpad/xaas-docs` (orphaned, directory
    already gone; its one commit is now safe on `origin` regardless).
  - `/private/tmp/xaas-pr1` (branch now on `origin`; worktree itself
    disposable once the land/discard decision above is made).
  - The 21 dangling `worktree-wf_*` local branch refs (all MERGED).
  - `.claude/worktrees/wf_f6a788f1-b0f-{2,3,6,8}` and
    `/private/tmp/uzc/ep1-worktree` — worktree directories only; their
    branches are now safely on `origin` independent of these checkouts, so
    once the land/discard decision is made these five working directories
    are disposable regardless of which way that decision goes.
- **`/Users/sac/xaas`'s own 32/49 uncommitted wave-v26.9.17 paths** —
  untouched by this pass; still needs the user's own explicit go-ahead
  before anything commits or pushes it.
