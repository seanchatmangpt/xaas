# Survey — 2026-09-21

- xaas `main` = `8e72cfc`; `mix test` = 1346 tests, 0 failures (71 excluded); no worktrees, no unmerged branches.
- All nine orders passed `GgenIgniter.SemanticJira.admit_work_order/1` (ggen_igniter `dcebc42`).
- Semantic Jira is a module in ggen_igniter, not a repo. xaas already shells to `mix semantic_jira.*`
  (`lib/xaas/ultracode/semantic_crown.ex`, `lib/mix/tasks/xaas.semantic.*`).
- `zcode-ocel-pack` has no consumer in xaas or autofde-lab. `ash_atlassian` does not exist.

| Order | Repo | Standing |
|---|---|---|
| SJ-001 e2e Semantic Jira in xaas | xaas | PARTIAL_ALIVE |
| SJ-002 zcode-ocel-pack consumer | xaas | UNSUPPORTED |
| SJ-003 HANDWRITTEN paydown | xaas | PARTIAL_ALIVE |
| SJ-004 Xaas.Resource adoption | xaas | PARTIAL_ALIVE |
| SJ-005 ZOE reconcile | xaas | PARTIAL_ALIVE |
| SJ-006 ecosystem-standing fold-in | autofde-lab | PARTIAL_ALIVE |
| SJ-007 ash_atlassian target | xaas | BLOCKED (no target package) |
| SJ-008 gymact backlog | gymact | PARTIAL_ALIVE |
| SJ-009 ash_ai retest | xaas | UNKNOWN |
