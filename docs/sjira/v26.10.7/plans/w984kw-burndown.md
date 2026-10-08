# W984kw — v26.10.7 Fleet Seal Burn-down Receipt (Seal Checklist Item 3)

Lane: W984kw, 2026-10-08. Docs-only: arithmetic over cited receipt values only,
no lib/test edits, no commit, no build root. Every number below cites the
receipt file it was re-read from at write time (paths relative to
`docs/sjira/`).

## 1. Typed-gap register (w859)

Current on-disk tally: **47 REPAIRED / 0 OPEN / 2 TYPED-OPEN / 2 OUT-OF-SCOPE**
across 51 rows (`v26.10.6/plans/w859-typed-gap-register.md`, W984kh addendum,
awk re-derived from disk; receipt `v26.10.6/plans/w984kh-w729.md`).

Burn-down arc (cited from the register's own addenda):

| State | Tally | Citation |
|---|---|---|
| Session start | 40 / 7 / 2 / 2 | footer "last verified w984aw", cited by `v26.10.6/plans/w984ff-probe.md` §Method |
| W984ff re-verify (2026-10-07) | 44 / 3 / 2 / 2 | `v26.10.6/plans/w859-typed-gap-register.md` addendum; 4 flips OPEN→REPAIRED (W770, W796-G3, W799, W804) per `v26.10.6/plans/w984ff-probe.md` |
| W784 + W902 flips | 46 / 1 / 2 / 2 | `v26.10.6/plans/w859-typed-gap-register.md` addendum; receipts `v26.10.6/plans/w984fv-w784.md`, `v26.10.6/plans/w984fs-w902.md` |
| W729 flip | **47 / 0 / 2 / 2** | `v26.10.6/plans/w984kh-w729.md` (court `atomic_retrofit_court_test.exs` 3 passed, exit 0); register row 29 flipped |

Arithmetic: 47+0+2+2 = 51 rows (register total). 40→47 REPAIRED = +7
(4 W984ff flips + W784 + W902 + W729); 7→0 OPEN.

## 2. Coverage burn-down curve (w984cj map + re-censuses)

Method-stable CamelCase-aware census (defmodule-source parsing, full-name +
last-segment alias passes, non-testable filter). Seven dated runs, one curve —
all rows cited from `v26.10.6/plans/w984cj-coverage-map.md` (baseline sections
and the W650h8 / W984du / W984fh / W984it addenda):

| Run | Lane | Files | Covered | Uncovered | NT |
|---|---|---|---|---|---|
| 1 as-written | W984cj | 825 | 629 | 193 | 15 |
| 2 re-run (+12 min) | W984cj | 826 | 629 | 194 | 15 |
| 3 | W650h8 | 829 | 634 | 176 | 19 |
| 4 | W650z8 | 829 | 639 | 171 | 19 |
| 5 | W984du | 829 | 677 | 133 | 19 |
| 6 | W984fh | 830 | 718 | 93 | 19 |
| 7 | W984it | 831 | 747 | 65 | 19 |

Arithmetic (uncovered): 194 → 176 (−18) → 171 (−5) → 133 (−38) → 93 (−40) →
65 (−28). Net −129 from the 194 re-run peak (66.5% of peak retired). Coverage
76.2% → 92.0% (747/812 testable, W984it addendum). Zero newly-uncovered
modules at every step (sorted `comm` deltas: 0 additions at runs 5, 6, 7,
disclosed in each addendum).

Retirement waves per addendum: depth-court waves (W984da–dr, W650w/y) retired
the former top of the backlog (SparqlBridge, Hddl.Mermaid, Tunnel.Submit,
AuthorityLedgerExport, Token.RevokeVerifier, SubstitutionPolicy, SpgGate);
governance thin-batch + operations incident courts retired the 24
Approval*-RequiresApprover/Valid* rows; billing gov-long-tail +
freeze-window + causal-admission + aws-adapters + retain-until courts retired
the ~26 Approval*Approve batch; landing batches #4–#8 retired the
Castle/Route-verb and research_runtime long tail (family/remainder courts
w984fj/fm/ij/ie/gx/gs/go/hi).

## 3. OS register (closure plan §4, OS-1..OS-21)

Classification: `v26.10.6/plans/w984ee-probe.md` §2 — OS-1 closed (LANDED,
W700); OS-2..OS-8, OS-12, OS-13, OS-11 operator-gated/investigation;
OS-9, OS-10 BLOCKED(law_evolution / new-code), v26.10.7+; OS-14..OS-19, OS-21
closed/partially closed (LANDED, residuals operator or v26.10.7); OS-20
in-progress, actionable-in-process.

OS-20 advance (OTP-29 Map.update hazard): xaas leg went from "12/12 sites
patched + site pins" to "12/12 patched + typed guard surface + drift-proof
re-introduction census" (`v26.10.6/plans/w984ee-probe.md` §5). Deliverables:
`lib/xaas/compat/otp29_map_update.ex` + census court
`test/xaas/compat/otp29_map_update_court_test.exs` (7/7, non-vacuity
witnessed — first run killed the guard module's own doc example). Landed in
commit `c6bf5bbc` (verified via `git log` this lane). OS-20 overall: 61/61
sites dual-safe across 4 repos, 3/4 repos committed+pushed; remains open:
ash_pplan quiet-machine full-suite capture (W610 rerun), beam4pm coordinator
commit + `bpm:HandAuthoredSource` admission, ash_pplan + xaas coordinator
commits (`docs/sjira/v26.10.6/_CLOSURE_PLAN.md` §4, W664b note; xaas
own-tree leg now committed at c6bf5bbc).

## 4. Mutation audits (non-vacuity series)

Four audits, same method (FILE-SWAP baseline, one surgical mutant at a time,
cmp-verified restore, post-restore green):

| Audit | Mutants | Killed | Survived | Citation |
|---|---|---|---|---|
| #1 W984ek | 6 | 6 | 0 | `v26.10.6/plans/w984ek-probe.md` |
| #2 W984ha | 6 single + 1 compound (M3c) | 5 + compound | 2 single | `v26.10.6/plans/w984ha-probe.md` |
| #3 W984iy | 6 | 6 | 0 | `v26.10.6/plans/w984iy-probe.md` |
| #4 W984jp | 8 single + 1 compound (M3c) | 7 + compound | 1 single | `v26.10.6/plans/w984jp-probe.md` |

Totals: 26 single mutants, 22 killed outright (84.6%), 2 survivors each killed
by their compound leg (sjira rate-limit clamp pair; OCEL self-exclusion +
dedup pair) — 26/26 non-vacuous under the compound convention.

Conventions hardened from the findings (`v26.10.6/plans/w984jl-probe.md`):
(1) compound-mutation leg required for redundant-pair guards — single-mutant
survival ≠ vacuity (W984ha M3, W984jp M3a); (2) tag-excluded courts
("0 tests, N excluded, exit 0") under bare `mix test` are false greens —
verification must pass `--include <tag>` (cross-references W984ig's
stale-assertion leg). Both appended to
`docs/sjira/v26.10.7/_INTEGRATION_RUNBOOK.md` Conventions.

## 5. Court families burned (family-probe series)

Probe receipts that returned COVERED / closed verdicts per family:

- a2a (`v26.10.6/plans/w984db-a2a-probe.md`): Agent COVERED
  (agent_identity_policy_depth, W984ak); Catalog upgraded PARTIAL →
  COVERED (deep) by direct court.
- accounts (`v26.10.6/plans/w984cw5-accounts-probe.md`): org, org_membership
  COVERED (incl. destroy-depth).
- ultracode (`v26.10.6/plans/w984cy3-ultracode-probe.md`): O-corrected true
  uncovered set = 3 modules (DurableClose, ProcessGroup, SubstitutionPolicy)
  — all since COVERED per W984cj-map W650h8 addendum
  (`test/xaas/ultracode/process_group_court_test.exs`,
  `test/xaas/generation/substitution_policy_depth_test.exs`).
- families probe (`v26.10.6/plans/w984cy2-families-probe.md`):
  ResearchRuntime's ~19 "uncovered" modules = one 16-line struct template ×
  19; disposition court-the-class-representative (closure/coordinator.ex) —
  family collapsed, not 19 courts.
- sjira (`v26.10.6/plans/w984di-sjira-probe.md`): DeliveryBatch
  alias-covered claim verified.
- ops (`v26.10.6/plans/w984cw4-ops-probe.md`), security
  (`v26.10.6/plans/w984da-security-probe.md`), vault
  (`v26.10.6/plans/w984dl-vault-probe.md`): per-family uncovered enumeration
  with direct courts landed on state-bearing slices (ops modules courted via
  W603's AuthorityLedgerExport court and the incident-lifecycle court;
  security path-ingest/policy-floor slices; vault refusal-half enumeration).

Downstream witnesses: the census curve (§2) is the aggregate receipt — 65
uncovered remaining, each individually enumerated in the 7th re-census.

## 6. Census floor

Witnessed: `v26.10.7/plans/w984gm-census-witness.md` —
`mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`
at HEAD `102c1782…`: **1388 passed, 0 failed, 1 excluded, exit 0** (floor
1388 met). w984ko: **not found on disk** in either milestone's plans/ tree at
write time — not landed as of this receipt (as-of-date).

Also witnessed: W984kh court 3/3 (§1); W984ee eu_ai_act census 1355/0/1 at its
earlier subject (`v26.10.6/plans/w984ee-probe.md` §4) — consistent with the
floor's monotone growth to 1388.

## 7. What remains OPEN (honest remainder)

- **2 TYPED-OPEN** register rows: W811 (test-scope boundary — scope
  disclosure, not a defect) and 49.3 (EU database registration — external
  Commission registry, no deployer endpoint) (`v26.10.6/plans/w984ff-probe.md`
  per-row table; both unchanged through W984kh).
- **2 OUT-OF-SCOPE** rows (removed-by-operator, 2026-10-07)
  (`v26.10.6/plans/w984kh-w729.md` tally).
- **In-flight repairs**: W984jz landed its repair (accept-list fix + repair
  pins, courts 3+21+10 passed, mock gate `[]`;
  `v26.10.6/plans/w984jz-repair.md`) — uncommitted, awaiting coordinator
  landing batch. W984kk: **no receipt on disk** (grep over both milestones'
  plans/ = 0 hits at write time) — recorded as in-flight/not-landed.
- **Coordinator/operator blockers** (from §3/§6 above): beam4pm OS-20
  coordinator commit + HandAuthoredSource admission; ash_pplan quiet-machine
  full-suite capture (W610); the 2 TYPED-OPEN + 2 OUT-OF-SCOPE rows are
  operator-class by classification.
- **Coverage long tail**: 65 uncovered modules (7th re-census), flat 2-pub
  each — platform RouteSecretsApprove batch, operations
  ApprovalCastleVerbSchedule/K8sFault batch, research_runtime template long
  tail (`v26.10.6/plans/w984cj-coverage-map.md` W984it addendum).

## 8. Standing

PARTIAL_ALIVE as a seal receipt: every number above is cited to a receipt on
disk re-read at write time (2026-10-08); the two live edges are (a) w984ko
absent, (b) kk/jz in-flight uncommitted. Arithmetic performed only over cited
values; no lib/test edits; no commit.
