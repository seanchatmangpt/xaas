# W650h27 — Commit Receipt (lane, v26.10.7 fleet seal)

**Lane**: W650h27 · **Repo**: /Users/sac/xaas · **Branch**: feat/playwright-surface · **Date**: 2026-10-07
**Subject**: third-registration-status-transition-court check — W650y4 file-state analysis + disposition.

## File-state analysis

| question | finding |
|---|---|
| File path | `test/xaas/conference/registration_status_transition_court_w650y4_test.exs` |
| Tracked? | **Tracked**, clean (`git ls-files` hit; `git status --porcelain test/xaas/conference/` empty) |
| Untracked/second file? | **No.** No second registration-status-transition file exists anywhere in the tree; the only hit is the single tracked path. |
| Landed by | commit **bdc6d823** "test(courts): W650h16 landing batch — … W650y4 status-transition court" — the only commit touching the path. |
| vs W650h16 | Same file W650h16 landed. The "landed-untracked copy" from the W650y4 receipt is the *same path*; nothing orphaned remains on disk. |

## Disposition

Case (4) of the dispatch: file is tracked → no rm, no landing commit needed. Ran the
post-landing witness.

## Verification (witness, ×1)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/conference/registration_status_transition_court_w650y4_test.exs
# … Finished in 0.7 seconds
# Result: 5 passed   (exit normal)
```

Grafana/PromEx nxdomain warnings are ambient dev noise, unrelated to the court.

## Standing

- W650y4 status-transition court: **ALIVE** (tracked at HEAD via bdc6d823, 5/5 green on
  exact subject).
- Third-court concern: **REFUTED** — there is exactly one registration-status-transition
  court file; no duplicate, no complementary second file, no untracked residue.
- Landing commit for this lane: **none required** (read-only lane; receipt only).

## Replay

```bash
cd /Users/sac/xaas
git ls-files | grep w650y4                                  # → test/xaas/conference/registration_status_transition_court_w650y4_test.exs
git log --oneline -- test/xaas/conference/registration_status_transition_court_w650y4_test.exs  # → bdc6d823
git status --porcelain test/xaas/conference/                # → (empty, clean)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test \
  test/xaas/conference/registration_status_transition_court_w650y4_test.exs   # 5 passed
```
