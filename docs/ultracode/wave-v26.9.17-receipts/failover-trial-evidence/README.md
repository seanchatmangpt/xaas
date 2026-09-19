# Failover trial evidence (plain-text copies)

Markdown receipts written by the GLM workers during the 2026-09-18 failover trials
(see `../FAILOVER-RUNBOOK.md` in the parent docs directory). The original
worktrees were nested git repositories under `tmp_out/` (untracked scratch); only their plain
`*.md` files are preserved here. Each is a worker's own narration of what it did; the
authoritative evidence for those trials is the Postgres receipts and git history recorded in
the runbook, not these files.

- `failover-verify-epoch1/` — dispatcher verification epoch (DISPATCH_RECEIPT.md, README.md)
- `repro2-b7d87048/` — second reproduction trial (REPRO2.md, README.md)
- `subagent-b7d87048-glm-failover/` — subagent-driven trial (README.md)
