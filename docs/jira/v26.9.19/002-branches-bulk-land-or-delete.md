# xaas: triage 12 PR-less unmerged remote branches

- Standing: OPEN
- Created: 2026-09-19 (v26.9.19 gh survey wave)
- Source: origin branches not merged into `main` with no open PR
- Evidence: `git branch -r --no-merged origin/main`: codex/object-centric-event-projection-impl codex/temporal-process-memory-impl docs/session-update-2026-09-01 feat/v26-9-12-substrate fix/coupling-engine-zero-weight fix/ggen-igniter-ci-transport fix/v26.9.15-system-authority fix/v26.9.15-system-authority-exact-head-replay fix/v26.9.15-system-authority-requalify ggen/pin-manufacturing-instrument-v26.8.27 probe/ash-ai-dependency-retest verify/v26.9.15-system-authority

## Work to complete
- Triage each branch: land (open a PR) or delete (`git push origin --delete <branch>`). Work in batches; record decisions in History.

## Acceptance
- `git branch -r --no-merged origin/main` is empty after `git fetch --prune`.

## History
- 2026-09-19 | OPEN | survey found 12 PR-less branches | full list above | triage pending
