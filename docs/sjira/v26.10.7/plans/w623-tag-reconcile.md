# W623 — Tag Reconciliation Receipt (W617 false-negative vs W601q/W621)

- **Lane**: W623, v26.10.7 campaign
- **Date**: 2026-10-07
- **Subject**: /Users/sac/xaas @ cf228da6 (branch feat/playwright-surface), git read-only; no commits made
- **Claim reconciled**: W617's "tag v26.10.6 does not exist; newest tag is v26.9.29" vs W601q/W621's verified creation+push of v26.10.6
- **Hypothesis**: CONFIRMED. `git tag -l` output is alphabetical; "v26.10.6" < "v26.9.22" lexically ("1" < "9" at the minor position), so `tail` surfaces v26.9.29 while v26.10.6 sits mid-list. `tail` of tag listing is not a newest-tag probe.

## Verification outputs (real, this session)

```
$ git tag -l | head -5
archive/backup-execution-fabric-v1-1d0d81a
archive/probe-ash-ai-dependency-retest-fa744ec
archive/w5-planner-a164178
v26.10.6
v26.9.22

$ git tag -l | tail -3
v26.9.22
v26.9.24
v26.9.29          <- exactly what W617 saw as "newest"

$ git tag -l | grep v26.10
v26.10.6          <- present locally, mid-list (alphabetical)

$ git cat-file -t v26.10.6
tag               (annotated tag object exists locally)

$ git rev-parse v26.10.6^{commit}
cf228da6632829396ee3d06b860b3ea3a04b8904   (= HEAD, coordinator-verified)

$ git ls-remote --tags origin | grep v26.10.6
261b2a2ab84031c2dc3d0aecbf9e98fde2ebae82	refs/tags/v26.10.6        (tag object)
cf228da6632829396ee3d06b860b3ea3a04b8904	refs/tags/v26.10.6^{}     (peeled -> HEAD)
```

## Verdict

- Tag v26.10.6 exists **locally AND remotely**; W601q/W621 creation+push standing: **ALIVE**.
- W617's claim is a **false-negative** caused by alphabetical-order `tail` lookup, not by tag absence.

## release_audit bug note (fix-forward recommendation)

`lib/mix/tasks/xaas.release_audit.ex` `newest_release_tag/0` (lines 151-170) is **NOT affected**: it uses `Version.parse/1` + `Enum.max_by` with `Version.compare/2`, which correctly ranks v26.10.6 > v26.9.29. The alphabetical-tail defect was in W617's own ad-hoc shell lookup, not in the audit task. W612 owns the release_audit file; no edit made here (discipline held).

**Guard recommendation (for the owning lane)**: any shell-level newest-tag probe must use `git tag -l 'v[0-9]*' | sort -V | tail -1` (or the Elixir Version.compare path already in `newest_release_tag/0`) — never plain `| tail`. Candidate fix-forward: a lane rule / grep-able guard banning `tag -l | tail` patterns in campaign scripts.

## Standing

- Tag existence local+remote: **ALIVE** (observed execution of read commands on exact subject cf228da6).
- W617 claim: **REFUTED** (false-negative, root-caused to lexical sort).
- Falsifier for this reconciliation: absence of `refs/tags/v26.10.6` in `git ls-remote --tags origin` — did not fire.
