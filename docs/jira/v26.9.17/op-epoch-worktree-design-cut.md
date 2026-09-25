# OP Epoch Worktree Design Cut — make head_verified receipts reachable (operator decision + implementation)

## Summary

The P2 target receipt — `Receipt(provider=zcode, outcome=alive,
head_verified=true)` — is structurally unreachable in production: nothing
ever sets `epoch.worktree`. `bind_lease` (lease.ex:91-110),
`CreateFirstEpoch` (changes/create_first_epoch.ex:32-49), and `NextEpoch`
(next_epoch.ex:96-121) all pass `none`; lease.ex:290 encodes
worktree-from-epoch-row; post-claim epoch `:lease` is refused by
`LeaseAvailable`. All 7 production epochs have `worktree=nil`, and every close
downgrades to `:partial_alive` with `verifier_unavailable=:no_worktree`.
Client-supplied worktrees at claim time were assessed by the wave as
"reversing an encoded decision — a design change for the operator."

## Status

BLOCKED — awaiting operator design decision.

## Scope

1. Operator picks one (or a better, explicitly-recorded alternative):
   - **A. Admission-time binding**: `Run.:create`/`:start` carries the
     worktree path (e.g. via `exact_subject` or a dedicated attribute);
     `CreateFirstEpoch`/`NextEpoch` propagate it onto epochs; lease binds it.
   - **B. Claim-time binding**: `claim_next` accepts a provider worktree,
     writes it to the epoch before admission (schema + lease semantics).
   - **C. Redefine `head_verified`** for provider epochs that legitimately
     have no worktree (explicit typed outcome, not a silent downgrade).
2. Implementation slice (agent, xaas, `feat/execution-actuation-fabric`,
   local commits): the chosen wiring + tests proving a claimed epoch carries a
   non-nil worktree and a close with a real commit yields
   `head_verified=true`; forged-head downgrade (`:build_broken`) must still
   fire (existing tripwire in `lease_test.exs`).
3. Update `HANDWRITTEN.md` rows for any new lease-surface file
   (owner pack `ultracode-actuation-lease-pack`).

## Key Invariant(s)

- `verified ≠ claimed`: the server must verify `final_head` against the
  epoch's worktree itself — provider assertions never upgrade standing.
- No path may auto-complete provider epochs regardless of this change
  (epoch_reactor.ex:113-117 invariant stays).

## Relationship to Existing Work

- `ep1-driver.md` intel (Finding B) is the canonical evidence.
- Prerequisite for `p2-lease-cycle-redispatch.md` (falsifier unreachable
  without it).

## Falsifiers / What Would Defeat This

- An epoch reaches `head_verified=true` with `worktree=nil` (lying verifier).
- Worktree binding lets a provider point at a repo it doesn't lease (head
  verified against the wrong tree).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | xaas feat/execution-actuation-fabric @ 6ff1a32 | 7/7 production epochs worktree=nil; closes → :partial_alive/:no_worktree | operator choice A/B/C → implement → tripwires |
