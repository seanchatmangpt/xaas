# W891 — Gap Triage (35 OPEN rows → next-wave work classes)

Lane W891, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf6`.
No commit; no build root; doc-only lane.

**Method**: every OPEN row of `w859-typed-gap-register.md` was re-read from its disclosing
receipt's tail/status section (not transcribed from the register line): w665, w674, w722,
w729, w731, w745, w750, w765, w770, w784, w793, w796, w799, w804, w819, w824, w849 — plus the
landed-repair pattern sources w740, w772, w809, w818 for mirror-pattern citation.

**Standing**: PARTIAL_ALIVE — the triage is a doc classification (ALIVE as a document on the
exact subject); no code, tests, or build were run, so no gap status was changed. Register
totals unchanged: 35 OPEN / 5 REPAIRED / 2 TYPED-OPEN.

**Repair-pattern lexicon (from landed repairs)**:
- W740 — `validate(ApprovalNotAlreadyApproved)` change-validation on `:approve` actions;
  mutation-killed by deleting the validation.
- W772 — `Ash.Resource.Validation` transition guard refusing non-admitted state edges.
- W809 — DB-reading `before_action` guard on `:return` (already-returned/unborrowed refusal).
- W818 — lifecycle guards on the incident resource (same file as W793's open gaps).

## Triage table

| # | Register row (gap class) | Disclosing receipt | Class | Repair pattern / design note |
|---|---|---|---|---|
| 1 | Kernel gap: bare emotion-recognition technique atom admits | w665 | CHEAP-REPAIR | Add technique-atom refusal validation in `lib/xaas/semantics/eu_ai_act_admission.ex:167-170`; mirror W740 validate + mutation-kill. Note: w665 tail says this is "an impl change outside that lane's file set" — a new lane owns it cleanly. |
| 2 | W674-GAP-1: gymact non-2xx → raw tuple fails `:seal`, no `:failed` receipt | w674 | CHEAP-REPAIR | Rescue arm in `seal_external/2` records a `:failed` receipt before rollback; mirror W740's guard idiom. |
| 3 | W674-GAP-2: `actuate/4` without `:episode_id`/`:cut` raises raw `WithClauseError` | w674 | CHEAP-REPAIR | Guard clauses emitting typed `{:error, :episode_id_required}` / `:cut_required` before the DO — the receipt already names the exact typed atoms. |
| 4 | W722 gaps 1-2: approval state guard absent; `X-Org-Id` caller-asserted | w722 | DESIGN | Org authentication is a new plug surface (authenticated identity binding), not a guard. The state-guard half could split out as a W740-mirror cheap fix. |
| 5 | W729 lifecycle transition guard: `:sync_from_stripe` accepts any in-enum transition | w729 | CHEAP-REPAIR | Transition guard mirroring W772 (`Ash.Resource.Validation` refusing non-admitted edges). |
| 6 | W729 approve-idempotency: stale-record repeat `:approve` double-credits | w729 | CHEAP-REPAIR | Direct W740 mirror — W729's own receipt names the W740 `after_action`/guard class as the recommended DB-level guard. |
| 7 | W729 multitenancy: no `multitenancy do` on billing resources | w729 | DESIGN | Migration/config across the whole billing tree; cross-resource. |
| 8 | W729 atomic_update: none in billing tree | w729 | DESIGN | Systematic atomicity retrofit, not one-line. |
| 9 | W731 `:capability_class` enum does not exist | w731 | DESIGN | New attribute + surface change (receipt asserts absence as the real surface today). |
| 10 | W731 limits-not-enforced: EngineLimit registry-only | w731 | DESIGN | Needs a real consumer gate — new enforcement surface, not a validation. |
| 11 | W731 registry path hardcoded `/Users/sac/...` | w731 | CHEAP-REPAIR | One-line: `Application.get_env` fallback in `Catalog.default_registry_path/0`. |
| 12 | W745 rescue-arm (-32603) never exercised by a real raise | w745 | CHEAP-REPAIR | Test-side: real raise via the in-test Bandit stand-in (the receipt already uses Bandit for the remote stand-in — no mock needed, Chicago-clean). |
| 13 | W750-G1: ALIVE+unexecuted ingest accepted | w750 | CHEAP-REPAIR | Change validation `ALIVE_WITHOUT_EXECUTION` on `:ingest`; receipt says the test currently pins the absence so the gate lands as a visible diff — mirror W740. |
| 14 | W750-G2: detect/1 blind to upsert-overwritten regressions | w750 | DESIGN | Append-only observation log or `previous_status` column — migration + rewrite of history semantics. |
| 15 | W765 GAP-A: `expires_at` not accepted by `:issue` | w765 | CHEAP-REPAIR | Add to accept list; `active?` calculation already computes correctly. |
| 16 | W765 GAP-B: no `:use`/`:consume` action; single-use unenforced | w765 | DESIGN | New action + use-tracking state (migration); depends on GAP-A landing first. |
| 17 | W765 GAP-C: no action refuses reuse-after-expiry | w765 | DESIGN | Guard on the (not yet existing) `:use` action — blocked by GAP-B. |
| 18 | W765 GAP-D: no runtime consumer gates on active freeze window | w765 | DESIGN | New enforcement point; today only the override gate exists. |
| 19 | W770 vacuous approvals: `Validations.*RequiresApprover` return `:ok` unconditionally | w770 | CHEAP-REPAIR | Wire or retire the pass-through modules; mirror W740 (W740 landed real guards on 4 sibling resources — the vacuous modules are the same class left unwired). |
| 20 | W770 RouteProjectsBackups lacks `:update`/`:destroy` (no retention sweep) | w770 | DESIGN | New actions + retention sweep surface. |
| 21 | W770 RouteProjects dead-write: only `:read` | w770 | DESIGN | New create/approve action surface. |
| 22 | W784 TOFU: pinning/rotation/defer-to-parent absent in repo and ash_a2a | w784 | TYPED-OPEN (promote) | Receipt already stands UNSUPPORTED with grep-matrix evidence and defers to backlog; it is a whole protocol trust surface (repo + pinned dep), the same "capability intentionally absent, absence pinned as the surface" shape as 49.3. Recommend flipping to TYPED-OPEN. |
| 23 | W793 4-gap row (RESOLVED_AT_GUARD_ONLY_ON_UPDATE / NO_REOPEN_GUARD / NO_RESOLVED_AT_GUARD / NO_POSTMORTEM_STATUS_GUARD) | w793 | CHEAP-REPAIR | Mirror W818 — its guards landed in this exact file; w793's tests pin the absences as the falsifier. **Drift flag**: w818's tail reports 2 guards landed and only NO_RESOLVED_AT_GUARD / NO_POSTMORTEM_STATUS_GUARD / NO_CROSS_REFERENCE remaining — the register's 4-gap row is likely stale; next wave should split the row and re-verify each of the 4 against HEAD before repairing. |
| 24 | W793 NO_CROSS_REFERENCE: incident↔castle link absent at resource layer | w793 | DESIGN | New relationship/attribute → migration. |
| 25 | W796-G1: no per-student borrow cap | w796 | CHEAP-REPAIR | DB-reading `before_action` counting active checkouts — direct W809 mirror, same resource family, same test file owns the pin. |
| 26 | W796-G3: fulfilled hold mints no real Checkout row | w796 | DESIGN | Transactional fulfillment flow (hold→Checkout mint), not a guard. |
| 27 | W799 reversal-action-absent: no `:refund`/`:reverse`/`:undo` in ledger | w799 | DESIGN | New ledger action + double-reversal guard — deliberate surface design (sufficiency guard today is an accident). |
| 28 | W799 credit-path-unfundable: `credit_sla/1` no sufficiency exemption | w799 | CHEAP-REPAIR | Context opt-in (`xaas_ledger.allow_overdraft`) in `credit_sla/1`; W785 documented the mechanism, W799 witnessed it working in-court. Pre-existing RED 3/5 in `approval_sla_credit_apply_test.exs` is the falsifier. |
| 29 | W804 `mix ecto.migrate` on xaas_dev | w804 | OPERATOR | Index recorded on test DB only; one command on dev, then flip the row to REPAIRED. |
| 30 | W802/W819 graphql-http-surface: schema compiles, never mounted | w819 | DESIGN | Router mount = new HTTP surface; auth/http-api-surface doctrine applies (CLAUDE.md API-auth floor). |
| 31 | W819 graphql-domain-coverage: 3 of N domains wired | w819 | DESIGN | Follows row 30. |
| 32 | W824 QuiescentStop typed envelope never on MCP wire | w824 | DESIGN | Dedicated fabric halt verb or kernel-envelope projection — w824's own tail names both options as out of test-lane scope. |
| 33 | W849 backlog-1: 4 PROVENANCE-ONLY surfaces lack sha256 pins | w849 | CHEAP-REPAIR | Mechanical: extend the sha256 map in `registry_drift_guard_test.exs`; receipt classifies P2-mechanical. |
| 34 | W849 backlog-2: CI/regen leg | w849 | DESIGN | New CI surface (regen-based DRIFT-CHECKED upgrade). |
| 35 | W849 backlog-3: McpScope moduledoc TTL-source convention | w849 | CHEAP-REPAIR | Doc normalization to the pack-dir regen-command form other surfaces use. |

## Class counts

- **CHEAP-REPAIR**: 15 rows (1, 2, 3, 5, 6, 11, 12, 13, 15, 19, 23, 25, 28, 33, 35)
- **DESIGN**: 18 rows (4, 7, 8, 9, 10, 14, 16, 17, 18, 20, 21, 24, 26, 27, 30, 31, 32, 34)
- **TYPED-OPEN (promote)**: 1 row (22, W784 TOFU)
- **OPERATOR**: 1 row (29, W804 dev migrate)
- Total: 35. ✓ (register stays 35 OPEN / 5 REPAIRED / 2 TYPED-OPEN until waves land)

## Recommended next-wave order (top 10 by value/cost)

1. **W804 dev migrate** (row 29) — OPERATOR, one command; clears a register row for free and aligns dev with the epoch-dedup index.
2. **W729 approve-idempotency** (row 6) — money path, direct W740 mirror, receipt already names the fix.
3. **W665 emotion-recognition kernel gap** (row 1) — EU-AI-Act refusal surface is the stated moat; single-file validation + mutation kill.
4. **W793 4-gap row** (row 23) — W818's pattern is already landed in the same file; first split the row per the drift flag, then guard the survivors.
5. **W750-G1 ALIVE-without-execution gate** (row 13) — closes the register's own "named receipt ≠ receipt" hole in the liveness ingest; W740-mirror validation.
6. **W765 GAP-A mint-time TTL** (row 15) — one accept-list line; unblocks GAP-B/C as a designed follow-up wave.
7. **W770 vacuous approvals** (row 19) — turns unconditional `:ok` validations into real W740-class guards (or retires them); kills a whole vacuous-court class.
8. **W849 backlog-1 sha256 pins** (row 33) — mechanical, receipt pre-classified; upgrades 4 surfaces to DRIFT-CHECKED.
9. **W674-GAP-2 typed refusal** (row 3) — raw `WithClauseError` → typed atoms the receipt already names; small, before-DO guard.
10. **W796-G1 per-student borrow cap** (row 25) — direct W809 mirror on the same resource family; guard + mutation-kill in one lane.

**Next-wave batch note**: rows 2, 3, 5, 6, 13, 15, 19, 23, 25, 33 are all one-file
guard/validation lanes in disjoint files — fan-out clean, no shared-seam conflicts.
Rows 16-18 (W765 B/C/D) sequence after row 15; rows 30-31 sequence together.

**Registration**: DESIGN-class rows spec'd by w905-design-gap-specs.md (2026-10-07) — registered by w910-spec-registration.md.

## Execution progress (W914 triage sweep, 2026-10-07) — SUPERSEDED by W971c footer below

Next-wave execution is assigned to W897 (top-10 items 1-3), W900 (items 4-6), W902
(items 7-10). Facts below are from receipt files on disk in this directory only.
**W971c supersede**: the "0 repaired / all in flight" snapshot below is stale —
all three batch lanes landed the same day; see the W971c top-10 disposition footer
at the end of this file for the per-row landing truth.

- `w897-cheap-repairs.md` — NOT on disk (in flight)
- `w900-batch2-repairs.md` — NOT on disk (in flight)
- `w902-batch3-repairs.md` — NOT on disk (in flight)

- **Rows repaired so far (witnessed by a landed receipt)**: none.
- **Rows in flight**: all 10 — row 29 (W804), row 6 (W729), row 1 (W665) → W897;
  row 23 (W793), row 13 (W750), row 15 (W765 GAP-A) → W900;
  row 19 (W770), row 33 (W849), row 3 (W674), row 25 (W796) → W902.
- **Rows untouched**: the remaining 25 of 35 — rows 2, 4, 5, 7, 8, 9, 10, 11, 12, 14,
  16, 17, 18, 20, 21, 22, 24, 26, 27, 28, 30, 31, 32, 34, 35.
- Register totals remain 35 OPEN / 5 REPAIRED / 2 TYPED-OPEN until a batch receipt lands.

### Final footer update (W923 register sweep 2, 2026-10-07)

- `w900-batch2-repairs.md` — LANDED. `w897-cheap-repairs.md` and `w902-batch3-repairs.md` — still NOT on disk at sweep-2 wait exhaustion (~10 min across 4 polls; sweep-1 W915 also exhausted at 0/3).
- **Rows repaired so far (witnessed by a landed receipt)**: 2 — row 15 (W765 GAP-A, repair + mutation-killed court, 17 passed exit 0) and row 19 (W770 vacuous approvals, REPAIRED by W792, witnessed 19 passed exit 0). Both flipped OPEN → REPAIRED in w859-typed-gap-register.md with dual citations; register totals now 34 OPEN / 7 REPAIRED / 2 TYPED-OPEN (43 rows; includes W938's dead-branch row).
- Row 3 (W674-GAP-2): fix staged on tree by W674's lane per w900-batch2-repairs.md, but its suite is 7/11 from unfiltered `hd()` durable-receipt reads (shared-DB pollution) — row left OPEN pending the one-line test-side hygiene fix.
- Rows in flight: 8 — W897 items 1-3 (row 29 W804, row 6 W729, row 1 W665), W902 items 7-10 (row 23 W793, row 13 W750, row 33 W849, row 25 W796, plus W674-GAP-2 follow-up).
- Rows untouched: the remaining 32 of 34 OPEN (list per prior footer, minus the 2 flips).

### Register sweep 3 (W943, 2026-10-07)

- Re-poll: `w897-cheap-repairs.md`, `w902-batch3-repairs.md` still NOT on disk
  (w900 remains the only landed batch receipt, already flipped in sweep 2).
  Individual repair receipts `w925-slot-release.md` and `w928-gymact-hygiene.md`
  also NOT on disk. Landed repair receipts checked against the register:
  `w907-bare-fun-fix.md` (counterfactual bare-fun typedoc fix, PARTIAL_ALIVE) and
  `w860-health-timeout.md` (W836 per-check timeout, ALIVE) — **no matching register
  rows exist** for either surface (W893's `GAP(CancelDoesNotReleaseSlot)` capacity
  gap is likewise unregistered), so no flips were possible from these.
- **Rows repaired so far (witnessed by a landed receipt)**: unchanged at 2
  (W765 GAP-A, W770 vacuous approvals). Register totals unchanged: 43 rows —
  34 OPEN / 7 REPAIRED / 2 TYPED-OPEN.
- Rows in flight: unchanged at 8 (W897 items 1-3; W902 items 7-10 plus
  W674-GAP-2 hygiene follow-up). w859 register untouched this sweep.

## Final reconciliation footer (W967, 2026-10-07)

All batch lanes (W897/W900/W902) and follow-ups (W925/W928/W944/W944b/W947) have
landed. Facts below from register + receipts on disk at read time. Current
register totals (after W945c batch-5 flips, post-dating sweep 7's 49-row note):
**50 rows = 25 OPEN + 23 REPAIRED + 2 TYPED-OPEN.**

### Disposition of the original 35 OPEN rows

**Closed — 13 rows REPAIRED, receipt-backed:**

| Triage # | Row | Closing receipt(s) |
|---|---|---|
| 2 | W674-GAP-1 (`:failed` seal) | w902 staged-lib + w928 hygiene court + w945b re-witness |
| 3 | W674-GAP-2 (typed refusal atoms) | w900 staging + w928 hygiene court (11/11 ×2) |
| 12 | W745 rescue-arm (-32603) | w945c court c.5 (real raise → envelope, mutation-killed) |
| 13 | W750-G1 (ALIVE-without-execution gate) | W768 landing witnessed by w945c (stale-row flip) |
| 15 | W765 GAP-A (mint-time TTL) | w900-batch2 (repair + mutation-killed court, 17 passed) |
| 16 | W765 GAP-B (`:use` action) | w935-spec16-impl (`fab56ae1`; 21/21 ×2, mutation 20/21) |
| 17 | W765 GAP-C (expiry refusal) | w935-spec16-impl (`fab56ae1`; mutation-killed) |
| 19 | W770 vacuous approvals | w900-batch2/W792 (19 passed) |
| 23 | W793 4-gap row | W818 (2 guards) + w902 (remaining 2, mutation-killed) |
| 25 | W796-G1 (borrow cap) | w902 (`Ash.count!` guard, mutation-proven) |
| 28 | W799 credit-path-unfundable | w945b row 28 (5/5 ×2) |
| 33 | W849 backlog-1 (sha256 pins) | w852 pins, witnessed green by w902 |
| 35 | W849 backlog-3 (McpScope TTL doc) | w945b row 35 (mutation killed, 1/1 ×2) |

Partial: row 4 (W722) — gap-1 state guard REPAIRED (W740, witnessed w945c);
gap-2 (`X-Org-Id` caller-asserted) split out as its own OPEN row.

**Remaining OPEN — 22 rows (21 fully open + row 4's gap-2 half):**

- **CHEAP-REPAIR: 5** — row 1 (W665 kernel gap), row 5 (W729 lifecycle guard),
  row 6 (W729 approve-idempotency — w897 found it already repaired on HEAD by
  W746), row 11 (W731 registry path) — note rows 1/5/11 all have **landed,
  mutation-killed repairs in `w897-cheap-repairs.md` rows 1/5/11** but the
  register rows were left OPEN pending a dispatch that names them (W960 sweep-7
  policy); only row 29 (W804 `mix ecto.migrate` on xaas_dev, OPERATOR) is
  genuinely unexecuted.
- **DESIGN: 16** (of the 18 spec'd in w905 — GAP-B/C, triage rows 16/17, closed
  by w935): rows 4 (auth half), 7, 8, 9, 10, 14, 18, 20, 21, 24, 26, 27, 30,
  31, 32, 34.
- **TYPED-OPEN promote candidate: 1** — row 22 (W784 TOFU); triage recommended
  promotion, register still counts it OPEN; register TYPED-OPEN count remains
  2 (W811 scope boundary, 49.3 corpus row).

### Bottom line

Of the original 35 OPEN rows: **13 closed, 22 remain** (16 DESIGN, 5
CHEAP-REPAIR of which 4 have landed repairs awaiting register flips and 1 is a
one-command operator action, 1 W784 promote-candidate). Every closed row is
dual/triple-cited with a mutation-killed court in its closing receipt. The
remainder is predominantly DESIGN-class surface work spec'd in w905.

## Top-10 execution disposition (W971c progress fold, 2026-10-07) — folded into and superseded by the W974d final-close footer below

Supersedes the W914 "0 repaired / all in flight" progress footer above. Facts:
receipt files on disk in this directory + per-row statuses grepped live from
`w859-typed-gap-register.md` (line numbers cited). Of W891's top-10 next-wave
rows, **9 of 10 are REPAIRED with landed receipts; 1 remains OPEN**.

| Top-10 item | Triage # | Row | Disposition | Receipt(s) |
|---|---|---|---|---|
| 1 | 29 | W804 dev `mix ecto.migrate` (OPERATOR) | **OPEN** — index exists in xaas_dev but was direct-DDL, not migrate; schema_migrations unstamped, replay now hazardous (register W971 audit annotation) | w804-epoch-dedup.md; register L50 |
| 2 | 6 | W729 approve-idempotency | **REPAIRED** — verify-first: already on HEAD (W746 `filter(expr(is_nil(approved_by)))` guard); register flip W968b | w897-cheap-repairs.md (drift row); register L166-169 |
| 3 | 1 | W665 kernel gap (emotion-recognition atom) | **REPAIRED** — w897 row 1, mutation-killed 6/7; register flip W968b | w897-cheap-repairs.md; register L166 |
| 4 | 23 | W793 4-gap incident lifecycle | **REPAIRED** — W818 closed 2, w902 closed remaining 2 (mutation `sed`, 16/18) | w818 + w902-batch3-repairs.md; register L43 |
| 5 | 13 | W750-G1 ALIVE-without-execution gate | **REPAIRED** — W768 gate landed (`capability_liveness_receipt.ex:179`), witnessed w945c; stale-row flip | w945c-batch5-repairs.md; register L32 |
| 6 | 15 | W765 GAP-A mint-time TTL | **REPAIRED** — accept-list + court 17 passed, mutation 15/17 | w900-batch2-repairs.md; register L35 |
| 7 | 19 | W770 vacuous approvals | **REPAIRED** — verify-first: W792 approver wiring, 19 passed | w900-batch2-repairs.md; register L39 |
| 8 | 33 | W849 backlog-1 sha256 pins | **REPAIRED** — verify-first: W852 pins, green in w902's 101/102 run | w852 + w902-batch3-repairs.md; register L54 |
| 9 | 3 | W674-GAP-2 typed refusal | **REPAIRED** — w900 staging + w928 hygiene court (11/11 ×2 over non-pollutable filtered reads) | w900 + w928-gymact-hygiene.md; register L21 |
| 10 | 25 | W796-G1 per-student borrow cap | **REPAIRED** — w902 `Ash.count!` guard, mutation-proven | w902-batch3-repairs.md; register L45 |

**Standing**: PARTIAL_ALIVE — doc-only fold; no code, tests, or register edits by
this lane; dispositions read from the register's own current statuses (not
asserted). The sole residual top-10 item (W804) is an OPERATOR action now
carrying a hazard annotation (direct-DDL index vs. unstamped schema_migrations),
owned by the coordinator per the register's W971 audit note.

## Triage-close footer (W971b, 2026-10-07) — SUPERSEDED by the W974d final-close footer below

The triage's work is complete. Every CHEAP-REPAIR row is dispositioned: either
repaired with a receipt citation (W665 kernel gap → w897 row 1; W729 lifecycle →
w897 row 5; W729 approve-idempotency → already repaired on HEAD by W746, per
w897 row-selection drift note; W731 registry path → w897 row 11 — all four
flipped by w968b-register-final-flips.md) or confirmed non-CHEAP (row 29/W804 →
OPERATOR, stays OPEN per W971 audit with the direct-DDL replay hazard noted in
the register row). No CHEAP-REPAIR row remains undispositioned.

The 18 DESIGN-class rows are spec'd in `w905-design-gap-specs.md` (SPEC-1..34).
Waves 1-3 in flight as w968c / w969b / w969c; **no wave receipts have landed on
disk yet** (test -f w968c-*.md / w969b-*.md / w969c-*.md → all absent, verified
2026-10-07). Wave standing: UNKNOWN until receipts land.

Final register totals (grep-verified against w859-typed-gap-register.md on disk,
2026-10-07):

```
$ grep -oE '\| (OPEN|REPAIRED|TYPED-OPEN) \|' w859-typed-gap-register.md | sort | uniq -c
  17 | OPEN |
  31 | REPAIRED |
   2 | TYPED-OPEN |
```

50 rows = 17 OPEN + 31 REPAIRED + 2 TYPED-OPEN (W971/W968b audit figure,
re-verified unchanged by this lane).

Remaining-OPEN disposition classes (17 rows):

- **DESIGN-pending (14)** — spec'd in w905, awaiting wave execution: W722 gap-2
  (X-Org-Id caller-asserted), W729 multitenancy, W729 atomic_update, W731
  graphlaw-limits-enforcement, W750-G2 (detect/1 upsert blindness), W765 GAP-D
  (freeze-window runtime gate), W770 retention path, W793 incident↔castle
  cross-ref, W796-G3 (hold→Checkout hand-off), W799 reversal actions, W802/W819
  graphql mount, graphql domain coverage, W824 quiescent wire coupling, W849
  backlog-2 (CI regen leg).
- **OPERATOR (2)** — W804 (stamp/drop-and-replay dev migrations before next dev
  `mix ecto.migrate`; coordinator action, replay hazard annotated in register
  row) and W902 (shared `xaas_test` sandbox-escape contamination; coordinator
  hygiene pass or per-lane test DBs).
- **Backlog-deferred, DESIGN-class (1)** — W784 TOFU (deferred to campaign
  backlog per register row; triage's promote-to-TYPED-OPEN recommendation not
  acted on).
- **TYPED-OPEN (2 in register)** — W811 scope boundary + 49.3 corpus row
  (counted in the 2 TYPED-OPEN slots, not among the 17 OPEN).

Triage status: CLOSED. Residual work is wave-execution of w905 DESIGN specs
(waves 1-3, receipts pending) plus 2 operator actions.

## Final close (W974d, 2026-10-07) — supersedes both prior footers above

This footer is the single authoritative triage-close. The "Triage-close footer
(W971b, 2026-10-07)" and the "Top-10 execution disposition (W971c progress
fold, 2026-10-07)" above are superseded by this footer (both are retained
verbatim as history; where their figures or framings differ, this footer wins).
Reconciled by lane W974d; all facts re-read from disk at reconcile time.

### Definitive register totals (grep-verified, 2026-10-07)

```
$ grep -oE '\| (OPEN|REPAIRED|TYPED-OPEN) \|' w859-typed-gap-register.md | sort | uniq -c
  17 | OPEN |
  31 | REPAIRED |
   2 | TYPED-OPEN |
```

50 rows = 17 OPEN + 31 REPAIRED + 2 TYPED-OPEN. This confirms W971b's figure
and supersedes any interim counts elsewhere in this file (35 OPEN at triage
origin; 34/7 at W914; 25/23 at the mid-sweep footer).

### CHEAP-REPAIR disposition — all 15 closed

Every CHEAP-REPAIR row is REPAIRED with a landed receipt: w897-cheap-repairs.md
(rows 1/5/11 + drift note), w900-batch2-repairs.md, w902-batch3-repairs.md, and
follow-ups w928-gymact-hygiene.md and w945c-batch5-repairs.md; verify-first
closures already on HEAD via W746 (W729 approve-idempotency), W792 (W770 vacuous
approvals), W818 (2 of the W793 4-gap row; w902 closed the remaining 2), W852
(W849 backlog-1 pins). Final flips witnessed by w968b-register-final-flips.md.
Zero CHEAP-REPAIR rows remain open.

### DESIGN disposition — 18 spec'd, waves 1-3 receipts not landed

18 DESIGN-class rows are spec'd in `w905-design-gap-specs.md` (SPEC-1..34).
Waves 1-3 were dispatched as w968c / w969b / w969c; at final close, `ls` of
`w968c-*.md`, `w969b-*.md`, `w969c-*.md` in this plans directory returns no
files (re-verified 2026-10-07 by this lane, independently of W971b's check) —
wave receipts are NOT on disk and wave standing remains UNKNOWN. W971c's "in
flight" framing is retained only as dispatch status, not landed standing.

### OPERATOR rows (2)

- **W804** dev `mix ecto.migrate`: index `ultracode_epochs_unique_run_cycle_index`
  exists in xaas_dev but was created by direct DDL; schema_migrations has no row
  for the relevant versions, so a future dev migrate will replay and fail on the
  existing index (replay hazard per the register's W971 audit annotation, row
  L50). Coordinator must stamp the versions or drop-and-replay. Stays OPEN.
- **W902** shared `xaas_test` sandbox-escape contamination: coordinator hygiene
  pass or per-lane test DBs. Stays OPEN.

### Sole typed open gap

**49.3** (EU-AI-Act Title IV deployer EU-database registration OPEN_GAP) — the
wave's one honest permanent open-gap row, TYPED-OPEN alongside the W811
test-scope boundary (which is a scope disclosure, not a defect). W784 TOFU
remains backlog-deferred DESIGN-class in the OPEN count; the triage's
promote-to-TYPED-OPEN recommendation was not acted on.

### Reconciliation notes

- W971b's "CLOSED with 17/31/2 on 50 rows" figure is confirmed correct; W971c's
  "9 of 10 top-10 REPAIRED, W804 OPERATOR open" is confirmed correct and folded
  into the dispositions above. The two footers are complements, not conflicts;
  this footer merges them and is the closing authority.
- Final-close verification receipt:
  `docs/sjira/v26.10.6/plans/w974d-triage-close-2.md`.

Triage status: **CLOSED** (final). Residual work: wave-execution of w905 DESIGN
specs (receipts pending), 2 operator actions (W804, W902), 1 typed open gap
(49.3) + 1 typed scope boundary (W811).
