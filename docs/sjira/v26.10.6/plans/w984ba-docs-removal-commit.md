# W984ba — graphql-removal docs corpus commit (DONE-lane receipts)

Lane: W984ba · Campaign: xaas v26.10.6 · Date: 2026-10-07

## Receipt

- Commit: `1e07a3da42a81f846dc4471f0e5c37fd329c24bd` on `feat/playwright-surface` (not pushed)
- Message: `docs: land graphql-removal docs corpus (lane W984ba)` (written via `-F` file per tools.md)

## Paths committed (7 files, +321/−96)

- `docs/claude/diataxis/reference/http-api-surface.md` — graphql section deleted, −95 lines (w984aq)
- `docs/claude/diataxis/reference/generated-castle-bridge-errc.md` — RouteCastleRun REDUCE-20 row corrected to JSON:API-only with SPEC-30/31 removal note (w984aq)
- `docs/sjira/v26.10.6/plans/w984ab-deepening-leg.md` (new)
- `docs/sjira/v26.10.6/plans/w984ap-e2e-removal.md` (new)
- `docs/sjira/v26.10.6/plans/w984aq-graphql-docs-removal.md` (new)
- `docs/sjira/v26.10.6/plans/w984aw-graphql-rows.md` (new)
- `docs/sjira/v26.10.6/plans/w984w-witness-w824.md` (new)

## Exclusions (typed)

- `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md` — SKIP per dispatch: owner lane W984ao still running; its receipt `w984ao-graphql-removal.md` absent on disk at commit time. Register edits (and the awk tally verification) wait for W984ao's lane. File remains modified-unstaged in the working tree.
- `w984ao1` / `w984as` DONE-lane receipts — no files matching those lane names exist on disk (checked `ls | grep -Ei 'w984(as|ao1|ao)'`: empty). Not staged; nothing to stage.
- Also unstaged: `lib/xaas/graphql_schema.ex`, `test/xaas/graphql_*`, `test/xaas_web/graphql_http_surface_test.exs` code deletions were found already in the shared index; restored them out of staging so this commit stays docs-only explicit-pathspec. They remain pending in the working tree for their owning lane.

## Standing

- The two reference-doc edits are observed on disk and match the w984aq diffs (verified via `git diff` before staging; commit stat confirms −95 line graphql section deletion).
- No mix commands run, per dispatch. Not pushed.
- ALIVE for the docs corpus at exact commit `1e07a3da`; UNKNOWN for register inclusion (blocked on W984ao).
