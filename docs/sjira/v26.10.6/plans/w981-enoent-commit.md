# W981 — enoent court commit + verification

Lane: W981, repo /Users/sac/xaas, branch feat/playwright-surface, base fc14f10b.

## Commit check (task 1)

`git status --porcelain test/xaas/release_audit_enoent_court_test.exs` → **clean**.
The W896b shape fixes are already in the committed version (last commit touching
the file: 51150f4c, W940 CG-14 blanket). Verdict: **NO-OP** — nothing to commit.

Untracked companion found: `docs/sjira/v26.10.6/plans/w896b-court-fix.md`
(W896b's own plan/receipt doc) — committed by this lane alongside this receipt.

## Task file hardening check (task 3)

`git status --porcelain lib/mix/tasks/xaas.release_audit.ex` → clean.
History: 07fb370b (W814/W845/W872-class hardening), 297da2f1, d8b21062.
No uncommitted delta. W845/W872 hardening is committed.

## Court run (task 2)

Direct run in the canonical checkout **cannot compile**: uncommitted working-tree
edits from other lanes (W975b multitenancy additions in
lib/xaas/billing/approval_sla_credit_apply.ex / approval_patch_sla_credit_apply.ex)
fail with `parse_inline_idents?/1 undefined` at the multitenancy do-block. That is
another lane's in-flight delta, not HEAD.

Court therefore run against exact HEAD via law-3 materialization:
`git archive HEAD` → scratch dir, `git init` + commit (needed because the W872
court exercises `git ls-files`, which requires a repo), `deps` symlinked,
private build root `_build-lane981`.

Result at HEAD: **4/4 passed** (exit 0), matching the w896b expectation.

```
Result: 4 passed
```

## Standing

- enoent court test file: ALIVE at HEAD (4/4, observed execution).
- release_audit task W845/W872 hardening: committed (ALIVE, no delta).
- Direct working-tree run: BLOCKED(other-lane-uncommitted-delta) — environmental,
  expected to clear when W975b's billing edits commit.
