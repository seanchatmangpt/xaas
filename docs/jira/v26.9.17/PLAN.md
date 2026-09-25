# PLAN — v26.9.17 finish-line ticket set

Written: 2026-09-17T12:30:00-07:00, from `RELEASE-STATE-v26.9.17.md` (authoritative
predicate table; durable copy at `docs/ultracode/wave-v26.9.17-receipts/`).
Every ticket here closes a NOT-SATISFIED / PARTIAL / UNKNOWN predicate or an
operator act recorded by the 2026-09-17 20-agent qualification wave.

Ledger note (deviation, recorded): this ticket set was hand-written on explicit
operator order ("write to docs/jira/v26.9.17 all the tickets", 2026-09-17).
The lawful standing scaffold is `calver-ticket-day-pack` via
`mix ggen_igniter.sync --for-each`; its admission stays the paydown for this
hand-write (see `ledger-paydown-admission.md`).

## Phase 0 — operator gates (BLOCKED until cut; nothing else unblocks)

| Ticket | Gate | Unblocks |
|---|---|---|
| `op-release-tag-cut` | `git tag -a v26.9.17` on autofde-lab `156cb6fe` | `release-certification-final`, cap-crown 12/12 |
| `op-xaas-server-restart` | fresh dev-server cut | `p2-lease-cycle-redispatch`, live seam re-receipt |
| `op-dev-token-rotation` | rotate leaked INTERNAL_API_TOKEN | all dev sessions; prerequisite for any non-dev use |
| `op-port-55432-free` | free squatted port (Docker pid 62485) | ash_a2a full-court green (8 invalid tests) |
| `op-epoch-worktree-design-cut` | decide epoch.worktree / head_verified semantics | `p2-lease-cycle-redispatch` (target receipt otherwise unreachable) |
| `op-branch-landing-decisions` | push/PR/merge calls on 4 fix branches | landing ggen/affidavit/autofde-lab/ep2 work |

## Phase 1 — independent cleanups (parallel, no interdependency)

- `zombie-runs-cleanup` (xaas; before/at server restart)
- `xaas-receipts-feature-landing` (xaas; live author's staged work, MM hazard)
- `affidavit-buildability-d4` (affidavit; committed tip must compile from HEAD)
- `ash-a2a-testenv-strict-compile` (ash_a2a; latent 36-warning defect)

## Phase 2 — the seam and the ledger

- `p2-lease-cycle-redispatch` — Episode₁ end-to-end, provider=zcode (+ independent observer)
- `ledger-paydown-admission` — admit the three packs; 比 leaves 0%
- `ep2-certify-integration` — merge ep2 branch with certify branch (or defer, operator)

## Phase 3 — episodes and autonomy

- `frontier-clean-ocel-wiring` (autofde-lab; witness-derived frontier_clean)
- `episode2-real-replay` — k1–k11 for real (needs P2's experience-1)
- `p3-unattended-epoch-zcode` — DESIGN P3 falsifier

## Phase 4 — certification

- `affidavit-followup-binding` (needs ep1/ep2/certify/hook evidence)
- `p4-claude-routine-deletion` — the c4 crown falsifier (operator deletes the routine last)
- `release-certification-final` — `release-qualified v26-9-17` SATISFIED

## Standing snapshot at creation

Boundaries: 8/9 qualified modulo operator acts (ash_a2a port; crown tag).
Episode₁ BLOCKED (dual-witnessed); Episode₂ machinery ALIVE, unexercised.
Affidavit issued (BLAKE3 chain, tamper-proven), ep-evidence pending.
比 = 0% manufactured (honest; paydown planned).
`release-qualified v26-9-17` = NOT-SATISFIED.
