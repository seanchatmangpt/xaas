# W964 — release_audit enoent court: ownership-chain resolution + manifest row mint

Lane: W964, xaas v26.10.6, canonical checkout `/Users/sac/xaas`
(branch `feat/playwright-surface`). Date: 2026-10-07.
Trigger: manifest addendum row 5 still said IN_FLIGHT / UNCLAIMED although the
ownership trail (W896 → W896b → w873 receipt) had landed. No commit; only
files written: this receipt + the row-5 edit in
`docs/sjira/v26.10.6/_COMMIT_MANIFEST_W850.md`. No build root.

## Ownership chain (verified on disk)

1. **`plans/w873-enoent-court.md` (W873, LANDED)** — exists; names
   `test/xaas/release_audit_enoent_court_test.exs` as its sole subject
   (4 tests, Chicago-style, real `run/0` + real git fixture). Real tails:
   4 passed solo; 8 passed jointly with `test/mix/tasks/xaas_release_audit_test.exs`;
   mock gate `[]`. Standing ALIVE on `a0723bf6` worktree. This resolves the
   W889b/W898-era premise "no w873 receipt on disk" — true at their write
   times, superseded since.
2. **`plans/w896-enoent-court-owner.md` (W896)** — ownership record minted
   when w873 was still absent; its own ADDENDUM (verified, lines 3–13)
   concedes the owner slot to w873-enoent-court.md and records 2/4 with two
   court-shape defects (bare-vs-wrapped REFUSED matching; OS-19 `@version`
   scan over-reach). Provenance confirmed via internal W873 identifiers
   (moduledoc + `_build-laneW873` fixture paths).
3. **`plans/w896b-court-fix.md` (W896b)** — closed both court-shape defects
   (regex extraction of bare findings from wrapped
   `REFUSED(release_audit, detail: %{finding: "…"})` lines + provenance-
   commented OS-19/W700 `@version` exemption). Final real run: **4/4 passed**
   (`MIX_BUILD_ROOT=_build-laneW896b`, pinned toolchain), five expected
   findings witnessed in wrapped form. Standing ALIVE.

Chain: **w896 (retroactive provenance) → w873 (owner receipt, ALIVE) →
w896b (court-shape fixes, 4/4 green)**.

## Commit status (verified)

```
$ git log --oneline -- test/xaas/release_audit_enoent_court_test.exs
51150f4c docs(sjira): closure plan, integration runbook, plan updates, commit manifest + release-audit enoent court test (W700/W798/W854/W737/W777)
```

Sole commit 51150f4c — consistent with W940's CG-14 blanket commit; the file
is no longer untracked. No further commit action needed or taken.

## Manifest row state (before → after)

Row 5 of the W889b manifest addendum in `_COMMIT_MANIFEST_W850.md` (line 396):

- Before: **IN_FLIGHT / UNCLAIMED** — "no landed receipt names this path …
  no w873 claim is confirmable" (stale by three receipts).
- After (edited this lane): **COMMIT / RESOLVED (W964)** — owner =
  `plans/w873-enoent-court.md` + `plans/w896b-court-fix.md`, committed @
  51150f4c, verification YES.

## Standing

- `test/xaas/release_audit_enoent_court_test.exs`: **ALIVE** (4/4 per w896b
  receipt on the exact subject; committed @ 51150f4c).
- Manifest row 5: **CLOSED** — no residual UNCLAIMED trace for this path.
- Remaining disclosed gaps (from w873 receipt, unchanged, non-blocking):
  NOT_COVERED non-`:enoent` error arms; NOT_COVERED `check_shell/2` arm;
  FIXTURE_ONLY finding superset.

## Commands / exits

```
ls docs/sjira/v26.10.6/plans/ | grep -E 'w873|w896|w943'   # w873/w896/w896b present
git log --oneline -- test/xaas/release_audit_enoent_court_test.exs  # 51150f4c
grep -n -i enoent docs/sjira/v26.10.6/_COMMIT_MANIFEST_W850.md      # row 5 located, then edited
```
