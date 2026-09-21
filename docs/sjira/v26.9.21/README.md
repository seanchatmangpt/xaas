# Semantic Jira work orders — v26.9.21

Work orders for zcode-cli agents to finish the open definition-of-done work.
Semantic Jira is `GgenIgniter.SemanticJira` (`~/ggen_igniter/lib/ggen_igniter/semantic_jira.ex`):
it admits and selects WorkOrders; it grants no authority and performs no merge/publish.

## Protocol for an agent

1. Read `index.json`. Pick the lowest-numbered order whose `standing` is not `ALIVE`
   and whose `dependencies` are all `ALIVE` (or have a sealed receipt).
2. Work in your own git worktree of the order's `repository` at `base_sha`.
3. Real collaborators only (Chicago-style): no mocks. Run the order's runnable check
   and paste real output into your receipt.
4. Commit with `git commit -F <file>`. Never rebase, force-push or `reset --hard`.
5. Report standing with the vocabulary `UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED |
   BUILD_BROKEN | UNSUPPORTED`; `ALIVE` needs an observed run of the exact subject.
6. Do not merge, publish or deploy; XaaS/BRCE own consequential DO.

## Files

- `000-survey.md` — verified baseline and references.
- `001..009-*.md` — one WorkOrder each (JSON front matter = the admitted field set).
- `index.json` — machine index.
- `generate.py` / `admit.exs` — regenerate the orders and re-admit them:
  `python3 generate.py` (set `WO_JSON`), then from `~/ggen_igniter`:
  `WO=<wo.json> mix run <path>/admit.exs`.

## References

`~/autofde-lab/docs/2026-09-21-zero-human-factory-standing.md`,
`~/gymact/docs/2026-08-13-gymact-jira-backlog.md`, `docs/jira/v26.9.19/`,
`docs/ultracode/PROGRESS.md`, `HANDWRITTEN.md`.
