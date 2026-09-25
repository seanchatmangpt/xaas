# P2 Lease Cycle Redispatch — first real provider=zcode epoch (Episode₁)

## Summary

DESIGN.md phase P2: one full lease cycle — `Run :create → :start → Oban tick
→ claim_next → admit_tool(Edit-class) → real bounded work in the leased
worktree → close_candidate(final_head)` — producing the wave's target receipt:
`provider=zcode, outcome=alive, head_verified=true`. The first attempt was
BLOCKED (server death, dual-witnessed) and found its named subject already
closed (`45fbbb9`). This redispatch uses a fresh real subject and the
incident's operational laws.

## Status

BLOCKED — on `op-xaas-server-restart.md`,
`op-epoch-worktree-design-cut.md`, `zombie-runs-cleanup.md`.

## Scope

1. Recreate the admission script durably (the original lived in volatile
   `/tmp/uzc/ep1_admit.exs`): commit it under the wave's receipts/docs scope
   or `scripts/ultracode/` — `Run.:create` with `provider: "zcode"`,
   `max_cycles: 1`, `epoch_timeout_seconds: 3600` (the 300s default reaped
   all 5 prior attempts), `exact_subject:` the worktree path, then `Run.:start`.
2. Pick a REAL bounded subject (no synthetic work): a queued ticket from this
   milestone scoped to a worktree-sized change is the natural pool (e.g. a
   slice of `frontier-clean-ocel-wiring.md` or the receipts-feature tests).
3. Execute as the provider through the real seam: MCP `tools/call`
   claim_next → heartbeat (30-min lease TTL) → admit_tool for Edit/Write
   classes ONLY (Bash/git_push refusals are tripwires to document, not fight)
   → commit atomically in the leased worktree → close_candidate with
   final_head.
4. Independent observer (executor ≠ verifier): same protocol as
   `ep1-observer.md` — read-only DB polling, server-log correlation, verdicts
   on receipts/admissions/head, no interference.
5. Falsifier (must be met or honestly reported): the target receipt row +
   epoch `:completed` + zero Bash-class admissions + no manual Reactor calls.

## Key Invariant(s)

- All state transitions via admitted actions / the live seam — never direct
  DB writes, never hand-forced Reactor steps.
- Mix discipline: `--no-start` + explicit Repo start or isolated worktree
  builds; never compile the shared `_build` against a live-serving tree.
- Refusal is a valid outcome: a typed `refuse` with reason beats a forced
  close.

## Relationship to Existing Work

- `DESIGN.md` P2; `ep1-driver.md` + `ep1-observer.md` (first attempt,
  BLOCKED, and its three findings); `boundary-xaas.md` (the court backing the
  seam); `zcode-connection-P0P1.md` (the installed plugin surface).

## Falsifiers / What Would Defeat This

- Receipt claimed without observer corroboration (CLAIMED-UNVERIFIED stays).
- Work done outside the leased worktree (head verifies against the wrong
  tree).
- Epoch completes with zero provider events (auto-completion leak).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | worktree feat/ep1-missed-epoch-receipt @ fd68647 (reusable base) | attempt 1: server dead pre-claim, zero DB footprint, falsifier NOT MET | gates → durable script → subject → cycle + observer |
