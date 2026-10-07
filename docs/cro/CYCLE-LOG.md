# CRO Loop — Cycle Log

One entry per account per stage per cycle. Append-only; never rewrite history —
a corrected entry is a new entry citing the old one.

## Entry format

```
### CYCLE-<YYYY-Www>-<account>  (e.g. CYCLE-2026-W41-acme)
- date: YYYY-MM-DD
- stage: S1|S2|S3|S4|S5
- target account: <name>
- persona: <title>
- artifact version: <InMail A|B | briefing vN | offer <id> | qbr vN>
- exit-gate result: ADVANCE | HOLD | KILL | BLOCKED(NO_EVIDENCE_ARTIFACT)
- notes: <=3 lines, facts only (reply text refs, calendar hold date, reproduction run, offer ID)
```

## Entries

### CYCLE-0-DRYRUN (no accounts contacted; falsifier machinery only)
- date: 2026-10-06
- stage: S1-S5 (all, dry run)
- target account: (none — dry run)
- persona: (none — dry run)
- artifact version: dry-run manifest snapshot 2026-10-06 (11/11 cited paths `test -f` OK)
- exit-gate result: S1 READY (w405 landed); S2 READY (w404 landed); S3 READY; S4 READY; S5 READY
- notes: 11/11 artifact paths cited in ARTIFACT-MANIFEST.md + CRO-LOOP.md verified
  on disk via `test -f` (whole-loop falsifier clause 1 passes: no cited artifact
  missing). InMail copy (variant A verbatim) present in CRO-LOOP.md. S1 gated on
  w405 evidence-claims index (not yet written by lane W405); S2 gated on w404
  briefing artifact (same). S3 validation-pack items all present: refusal capstone
  w236, conformance court w385, anti-vacuity w320, Playwright tokened w317,
  refusal-ledger JCS export + README (docs/cro/artifacts/),
  ash-surface-refusal-ledger (docs/cro/artifacts/). S4 verdicts present:
  stage4-entitlement-flow-verification.md (docs/cro/artifacts/). S5 land-expand
  ladder documented (CRO-LOOP.md stage 5 + falsifier). No account fields — dry run.

### CYCLE-0-CLOSE-OUT (no accounts contacted; completed state)
- date: 2026-10-06
- stage: S1-S5 (all, close-out)
- target account: (none — cycle-1 launch precondition unmet: operator must pick target accounts)
- persona: (none — human input pending)
- artifact version: close-out snapshot 2026-10-06 (12/12 artifact paths `test -f` OK)
- exit-gate result: S1 READY; S2 READY; S3 READY; S4 READY; S5 READY
- notes:
  S1 READY — docs/cro/artifacts/fiduciary-briefing-v26.10.6.md;
  docs/cro/artifacts/evidence-claims-index.md. w405 ship/remove annotations applied.
  S2 READY — bias-awareness-measures-v26.10.6.md; end-user-disclosure-v26.10.6.md;
  agent-obliviousness-demo.md.
  S3 READY — docs/cro/artifacts/s3-evidence-pack-v26.10.6.md;
  s3-evidence-pack-replay-validation.md; refusal-ledger-v26.10.6.jcs.json;
  refusal-ledger-v26.10.6.README.md; ash-surface-refusal-ledger-v26.10.6.md.
  Integrity findings (w419) remediated (w430). Replay card validated (w439;
  1 sha drift found and fixed).
  S4 READY — stage4-entitlement-flow-verification.md.
  S5 READY — artifact-integrity.md; nist-manage-telemetry.md; land-expand ladder
  per CRO-LOOP.md.
  Cycle-1 launch precondition: operator picks target accounts (human input — the
  loop's only remaining non-mechanical step). No contact made in CYCLE-0.

### CYCLE-1-PREP (no accounts contacted; EU-AI-Act deepening + repair consolidation wave W640-W752)
- date: 2026-10-07
- stage: S3 (evidence-pack strengthening); S1/S2 refreshed
- target account: (none — cycle-1 launch precondition still unmet: operator must pick target accounts)
- persona: (none — human input pending)
- artifact version: consolidation snapshot 2026-10-07, branch `feat/playwright-surface` @ a0723bf6 (uncommitted lane diffs on the canonical checkout)
- exit-gate result: S3 STRENGTHENED (see deltas below); S1/S2 artifacts refreshed in place; overall HOLD on terminal claims (W662: zero-open-gap census NOT claimable on a churning tree)
- notes:
  **Scope.** Census: W650c (terminal census, 1153 corpus, 4 typed OPEN_GAPs),
  W662 (final census, 1120 green gate / 1143-1153 honest census, NOT
  TERMINAL verdict), W670 (gate rerun, title_iii 390/391 + corrected
  gate/census run definitions; vacuous-tag census finding). Repairs:
  W676 (RobustMargin malformed-margin guard — CaseClauseError →
  `{:error, :REFUSED_MALFORMED_MARGIN_INPUT}`, 37/37 green + 2 mutation
  kills), W679 (IncidentReport :MALFUNCTION misclassification — EUAIA
  refusal atoms now suppress :MALFUNCTION, 18 passed + both mutation
  directions killed), W708 (Art 73.x expectations aligned to W679
  behavior, 476+9 green), W726 (witness identity-index rename migration —
  duplicate ingest surfaces typed Invalid not Ash.Error.Unknown, 46
  passed, mutation revert → 4 fail with class :unknown), W737 (org-less
  (run_id, cycle) partial unique index + custom_indexes — duplicate epoch
  refuses typed; mutation: index dropped → duplicate ACCEPTED, 10+45
  green), W739 (/internal-api 406-before-auth leak — pipeline reorder,
  16/16 green, mutation revert → 14/16 fail with the 406 body), W732
  (REFUSED_EUAIA_MALFORMED_CANDIDATE added to the declared closed set,
  closing W713's typed census finding; 9 atoms now asserted in
  title_ii/title_iv_v), W740 (ApprovalNotAlreadyApproved validation on the
  4 Governance Approval* resources — double-approve now a typed refusal,
  closing W722 gap 1), W746 (DB-level `filter(expr(is_nil(approved_by)))`
  guard on SLA-credit :approve — stale-record repeat approve no longer
  double-credits the Ledger, closing W729 gap 2), W746-class lane-lease
  notes. Deepening: W665/W666/W667/W669/W691/W692/W696/W704/W706/W708/
  W710/W713. Fabric courts: W723 (token floor, 16/16), W728 (audit-log),
  W745 (execution-fabric deepening), W747 (Actuation.run/4 idempotency/
  replay deepening). AIRo pins: 12 per-repo pins (W675/677/678/680/681/
  682/683/685/686/687/690/695) + vendored airo.ttl (commit a0723bf6).
  Docs: W671/W689/W702/W712/W714/W749.
  **FMEA deltas (real defects found by the wave).**
  1. Double-approve gap — W722 observed a second `:approve` SUCCEED and
     overwrite `approved_by` on all 4 Governance Approval* resources;
     fix W740 (`ApprovalNotAlreadyApproved`, typed refusal on
     `approved_by`).
  2. SLA double-credit — W729 observed a stale-record repeat `:approve`
     really double-credits the org's Ledger account
     (`newly_approved?/2` read in-memory `changeset.data`, not the DB);
     fix W746 (persisted-state `filter(expr(is_nil(approved_by)))` in
     the UPDATE WHERE clause; refusal is typed, no double credit).
  3. 406-before-auth leak — W723 finding 1 / W739: `/internal-api`
     pipeline ran `:accepts(["json-api"])` before the token floor;
     unauthenticated bad-Accept requests got 406 with the expected-format
     body. Fix W739 (floor-first pipeline order; g2/g3 flipped to
     regression courts; mutation revert re-produces the leak).
  4. Constraint-name degradation — W726: witness identity indexes were
     created with Ecto column-derived names, so AshPostgres did not
     recognize the constraint and duplicate creates surfaced as
     `Ash.Error.Unknown` wrapping raw `Ecto.ConstraintError` instead of
     typed Invalid. Fix W726 (guarded rename migration
     20261007000000; mutation revert → 4 courts fail class :unknown).
     Same class closed for org-less ultracode epochs by W737 (partial
     unique index + `custom_indexes`, migration 20261007010000).
  5. Untracked evidence surfaces — W711: evidence-claims index grew
     12 → 32 rows, 3 drift findings (w678 count error, w680/w682 missing
     AIRo wiring-ledger rows for ex4pm/ash_pplan — coverage gap, not a
     wiring defect; uncommitted-landing caveat).
  6. Refusal-set closure violation — W713 census found
     `:REFUSED_EUAIA_MALFORMED_CANDIDATE` emitted by
     `EuAiActAdmission.admit/1` outside the declared closed set; fix
     W732 (atom added to `@typedref_atoms`/`@type refusal_atom` +
     describe clause; census court now passes the closed-set check).
  **Controls (courts pinning each fix).**
  1. Double-approve →
     `test/xaas/governance/multitenant_approval_deepening_test.exs`
     (W722, real sandbox Postgres, 9 passed) + W740 validation refusal
     cited in `lib/xaas/governance/validations/approval_not_already_approved.ex`.
  2. SLA double-credit → `test/xaas/billing_deepening_test.exs` (W729,
     13 passed) + the W746 filter change in
     `lib/xaas/billing/approval_sla_credit_apply.ex`.
  3. 406 leak → `test/xaas_web/require_internal_api_token_deepening_test.exs`
     g2/g3 (W723/W739, 16/16, mutation-killed).
  4. Constraint-name degradation →
     `test/xaas/witness/witness_surface_deepening_test.exs` (W726, 46
     passed, mutation-executed) and
     `test/xaas/ultracode/run_receipt_deepening_test.exs` (W737, 10+45
     passed, index-drop mutation).
  5. Evidence surfaces → `docs/cro/artifacts/evidence-claims-index.md`
     rows 13-32 (W711, every row backed by a receipt read in full).
  6. Refusal closure → `test/xaas/semantics/refusal_atom_census_test.exs`
     (W713/W732) + 9-atom assertions in title_ii/title_iv_v courts
     (W732).
  **Standing.** Fixes ALIVE on the uncommitted working tree at a0723bf6
  (receipts W676/W679/W708/W726/W737/W739 witness real runs + mutation
  kills). W732/W740/W745/W746/W747 have no receipt files on disk — their
  standing is witnessed by in-code citations and test files only
  (integration gap, coordinator owns receipts/commits). Residual open
  items: W659d/W670's 15.5.s3 VulnerabilityLifecycle state gap, W722
  gap 2 (X-Org-Id caller-asserted), W729 gaps 1/3/4 (lifecycle state
  machine, multitenancy, atomic_update — disclosed, docketed), W650c
  order-dependence class (art73/art50/counterfactual under some async
  orderings). No commit made this lane (coordinator owns integration).

## CYCLE-2-FOLD — Consolidation wave (2026-10-07, lane W952)

**Headline.** Fold of the v26.10.6 consolidation wave since CYCLE-1-PREP (W753).
xaas: 30 commits on `feat/playwright-surface` from `a0723bf6` to tip `fab56ae1`
(29-commit repair/court batch landed by W940 per `plans/w940-xaas-commits.md`,
plus SPEC-16/17 `fab56ae1` per `plans/w940b-spec16-commit.md`); fleet: 12
commits / 11 repos + the vendored submodule, committed 2026-10-07, no push
(`plans/w937-fleet-commits.md`). Both playwright legs ALIVE: xaas priority set
24 passed / 1 skipped / 0 failed on a fresh boot, PW_PORT=4126, exit 0
(`plans/w842-e2e-revalidation.md`, closes W752's PARTIAL_ALIVE); ash_surface
371/371 ×2 real Chromium runs on `main@d55c576d` (`plans/w901-ash-surface-playwright.md`).

**FMEA deltas — the wave's repair class.** The w859 typed-gap register
(`plans/w859-typed-gap-register.md`, at HEAD 49 rows = 30 OPEN + 17 REPAIRED +
2 TYPED-OPEN, re-derived after the W950 flip) records the wave's repairs; the
sweeps w943c/w944/w950 flipped/appended rows only where a status-bearing
receipt's real run closed the row (w943c: W838-G1 awaiter hardening per
`w918b-awaiter-hardening.md` + W765 GAP-B/C via `w935-spec16-impl.md`/`w940b-spec16-commit.md`;
w944: W880 counterfactual + W836 health-timeout rows appended REPAIRED per
`w907-bare-fun-fix.md`/`w860-health-timeout.md`; w950: W674-GAP-2 flipped after
`w928-gymact-hygiene.md` 11/11 ×2). Major named guards of the wave, each with a
typed-refusal court:
1. Claim-authority — `Xaas.Actuation.run/4` admitted a `ComputationClaim` as
   authority evidence; `admit_authority/2` now refuses claim-shaped maps
   (W763 G1 measured: a CANDIDATE claim actuated and flipped a Provider row).
   Receipt `plans/w780-claim-authority-guard.md`.
2. Incident terminal guard — `:resolve` on a resolved incident now typed-refused
   via `IncidentResolvedIsTerminal`; ALIVE, sandboxed Postgres, mock-grep zero.
   Receipt `plans/w818-incident-guards.md`.
3. Slot-release — cancel now frees the capacity slot (`EnforceSessionCapacity`
   status filter); closes W893's gap, closing `plans/w893-enrollment-journey.md`'s
   registered row via `plans/w925-slot-release.md`.
4. Return-guard — checkout `:return` open-checkout guard; PARTIAL_ALIVE
   (verification green on uncommitted diff, coordinator owns commit).
   Receipt `plans/w809-return-guard.md` (transport failure: lane build root
   mid-compile deletion, disclosed).
5. ALIVE-gate — capability liveness gate (W750 G1) — `plans/w768-liveness-alive-gate.md`.

**Controls (new court families).** Doctor task (release-audit/doctor mix tasks,
W814/W791 — `plans/w791-doctor-task.md`, landed in commit 07fb370b); gap register
as a standing control surface (w859 register + `plans/w859-register-receipt.md`);
typed-gap register sweeps w943b/c (totals re-derived by awk/grep each sweep, drift
between register and status receipts is itself the failure class the sweeps kill).

**Open residue.**
1. Exactly 1 typed open gap: 49.3 EU-AI-Act corpus OPEN_GAP (deployer
   EU-database registration) — `plans/w815-gap-registration.md` (zero others,
   per the census).
2. Register: 30 OPEN rows; 18 DESIGN-class rows spec'd for the DESIGN wave per
   `plans/w905-design-gap-specs.md` (S/M/L estimates, sequencing deps named).
3. Operator steps (all NOT YET, per `plans/w946d-runbook-final.md` §FINAL):
   lane-lease cleanup (80 dirs / ~31.71 GB per `plans/w878-lease-census.md`),
   dev migrate, ggen sync (one-line page-10 delta predicted by `w918-sync-drift-precheck.md`),
   pin advance (ggen.toml at `518572b6`), push (xaas + fleet, gated on step 4).
   Standing: fixes ALIVE on uncommitted working tree at `fab56ae1`+lane diffs;
   no commit made this lane.

## CYCLE-CLOSE — Campaign closing entry (2026-10-07, lane W977)

**Terminal state as witnessed, receipt-cited.**
(a) Census doubly witnessed on `fab56ae1`: W926 gate 1352 passed / 1 excluded /
exit 0, open-gap census 33/34 with exactly 1 flunk = the 49.3 marker
(`plans/w926-terminal-census-3.md`); W935b independent lane + independent build
root reproduced 1352 gated / 34 open-gap-tagged
(`plans/w935b-census-count-capture.md`).
(b) Fleet pin matrix 11/11 GREEN at the exact W937 committed SHAs (W939 five-row
run + W963 six-row run; clears the W955 §1b hold) — `plans/w939-fleet-pin-postcommit.md`,
`plans/w963-fleet-pin-remaining6.md`.
(c) Fleet: 12 commits / 11 repos + the vendored submodule, committed 2026-10-07,
no push (`plans/w937-fleet-commits.md`); xaas 30 commits `a0723bf6`→`fab56ae1`
(`plans/w940-xaas-commits.md` + SPEC-16/17 `fab56ae1` per `plans/w940b-spec16-commit.md`).
   Fleet push executed 2026-10-07 per W955 §2/§3: 11 of 12 subjects pushed to their
   branches — `@{push}` == HEAD ×10 plus beam4pm (`@{push}` = HEAD = `560202484f5f`);
   wasm4pm's branch created new on remote. Typed findings: F1
   PUSH_REJECTED(NON_FAST_FORWARD) on beam4pm vendor/ggen-marketplace main
   (remote diverged to `3ddbfeb7e`; local `6e4de9765` on no remote branch; no
   force/merge/rebase attempted — reconciliation lane W980b in flight, no receipt
   on disk as of this fold); F2 DANGLING_GITLINK_REMOTE on beam4pm origin main
   (references vendor `6e4de9765`, unreachable upstream; fresh
   `clone --recurse-submodules` fails) until W980b lands; F3 SPEC_DRIFT on w955 §2
   rows 7/8/10 (wasm4pm new remote branch; ash_pplan had no upstream, `-u` used) —
   both landed on their own feat/fix branches. xaas row 12 held per W955
   §1a/§1d/§4/§5. Facts and full table: `plans/w980-fleet-push.md` (lane W980);
   fold by lane W961d, receipt `plans/w961d-push-fold.md`.
(d) Typed-gap register converged 48→50 rows = 17 OPEN / 31 REPAIRED / 2 TYPED-OPEN
via sweeps 4–7 + the W971 audit, which flipped 8 stale OPEN rows against on-tree
evidence with named repair receipts and reconciled W968b's concurrent flips at
divergence 0 (`plans/w971-open-recount.md`); counts corrected W979 to the
grep-verified on-disk register totals (W968b landed 5 flips after the W977
snapshot: `plans/w968b-register-final-flips.md` + W971's subsequent flips).
(e) Deliberate residue: sole typed open gap = EUAI-ACT 49.3 deployer EU-database
registration (`plans/w815-gap-registration.md`); OPEN rows now 25 (was 30 at the
W952 fold; W971 flipped 8 stale), 18 DESIGN-class spec'd for the DESIGN wave per
`plans/w905-design-gap-specs.md`; operator steps remain NOT YET per
`plans/w946d-runbook-final.md` §FINAL + `plans/w954-sync-gate-spec.md` /
`plans/w955-push-gate-spec.md`: lane-lease cleanup, dev migrate, ggen sync, pin
advance, push (gated in that order). Standing: written on the uncommitted tree at
`fab56ae1`; no commit, no push from this lane. Receipt `plans/w977-closing-entry.md`.

## CYCLE-3 — CRO loop bookkeeping advance (2026-10-07, lane W982n)

Read-fresh + disk-verified fold of the W980–W982 session (prior entries:
CYCLE-2-FOLD W952, CYCLE-CLOSE W977, counts corrected W979). No mix commands
run; no commit made. All claims below re-read from disk this session.

**Terminal state as witnessed.**

(a) **Typed-gap register** (`plans/w859-typed-gap-register.md`), row-level
grep on disk today: **17 OPEN / 32 REPAIRED / 2 TYPED-OPEN** (51 rows total).
Drift flag: W980j's receipt and the W977 CYCLE-CLOSE entry both state
31 REPAIRED; the on-disk register now shows **32 REPAIRED** — one row has
flipped (or been added) since W980j's snapshot without a receipt-cited fold.
Registered as DRIFT(REGISTER_COUNT) — not papered over; needs a one-row
reconcile against its repair receipt next lane.

   **CORRECTION (2026-10-07, lane W982q): DRIFT(REGISTER_COUNT) RESOLVED.**
   Row-level tally re-run on the register: 17 OPEN / 32 REPAIRED / 2
   TYPED-OPEN across 51 rows. The +1 REPAIRED is W969e
   GAP(same-attendee-re-register-blocked-by-identity), appended and flipped
   after W980j's snapshot citing w981s-registration-identity-scope.md; receipt,
   court test (enrollment_journey_court_test.exs step 6), and the
   `EnforceActiveRegistrationIdentity` change all verified on tree. The 32nd
   REPAIRED is legitimate; register footer updated to 51 rows total
   (receipt: plans/w982q-register-count-reconcile.md).

(b) **AIRo wiring ledger 25-repo wave** (w981e/w981f): ledger
`docs/cro/artifacts/airo-wiring-ledger.md` extended on disk this session
(13,947 bytes, mtime 09:04). New reference surface at `docs/airo/` — 9 repos
(ash_atlassian, ash_autofde, ash_dspy, ash_expo, ash_graphlaw, ash_kudzu,
ash_planning_center, chatman-ecosystem, ggen-ecosystem) each with
`airo-reference.md`, plus `pin_drift_check.exs` and `pin-court-vocab.md`.
Untracked; uncommitted.

(c) **Pin + drift courts** (w981j/w981w/w982h): AIRo pin court + followup
+ marketplace pin-drift receipts present on disk (test -f, this session).

(d) **Push receipts**: `plans/w981y-push.md` — xaas `a0723bf6..6f235905`
fast-forward, post-push SHA equality `6f235905` local == remote, exit 0.
`plans/w982d-fleet-push.md` — 5-repo fleet push table: ash_graphlaw,
ash_autofde pushed (SHA equality, ALIVE); ash_a2a, ggen_igniter, ash_affidavit
already synced, upstream tracking configured; corrects W981z's NO-UPSTREAM
flagging for those three.

(e) **Integration**: `plans/w981h-integration-commit.md` — commit `6f235905`
(W946d @doc dedup) LANDED and (per w981y) PUSHED. w982b/w982k named in the
dispatch as integration lanes — **no receipt files w982b/w982k exist on
disk**; marked IN-FLIGHT (also: no w982b/w982k files at all — flag as
MISSING_RECEIPT(IN_FLIGHT_LANES)).

(f) **Other landed this session** (receipts test -f verified):
w981u manifest v3 staging; w981v EU-AI-Act tag audit; w981p open-gap mutation
hardening 3×KILL; w981g OS register sweep; w981s registration identity scope;
w971b/w981n migration replay/idempotency triage (note per w981h: the three
untracked migrations on disk do not match W971b's stated versions — disclosed
in w981h, still unreconciled); w980j register close-out (0 flips).

(g) **Standing**: everything above written on the uncommitted working tree at
HEAD `6f235905` (branch `feat/playwright-surface`, pushed). Operator steps
(lane-lease cleanup, dev migrate, ggen sync, pin advance) remain NOT YET per
`plans/w946d-runbook-final.md` §FINAL.

**Status vocabulary**: ALIVE — register close-out (17/32/2 on disk), xaas push
(a0723bf6→6f235905), 5-repo fleet push, manifest v3 staging, tag audit,
mutation hardening, pin/drift courts (receipts on disk). PARTIAL — AIRo 25-repo
ledger wave (ledger + 9 repo references on disk, untracked/uncommitted; pin
court receipts present). IN-FLIGHT — w982b/w982k integration lanes (receipts
absent). DRIFT — register REPAIRED count 31(receipt) vs 32(disk);
w971b migration versions vs untracked migrations on disk.

   **CENSUS-GATE NOTE (2026-10-07, lane W982w): eu_ai_act gate settled at ≥1352
   passed / 0 failed, `--include eu_ai_act --exclude eu_ai_act_open_gap`, witnessed at
   6f235905-era head by w981x.** W981v's ≥1385 projection retired — ba9703fb's
   moduletag fix reclassified 33 already-running tests as gated-visible (visibility ≠
   count delta); receipt: `plans/w982w-tag-projection-reconcile.md`.

Receipt: `docs/sjira/v26.10.6/plans/w982n-cro-cycle-advance.md`.

   **ADDENDUM (2026-10-07, lane W984ac): CYCLE-3's MISSING_RECEIPT(IN_FLIGHT_LANES)
   flag RESOLVED.** `plans/w982b-integration-commits.md` and
   `plans/w982k-spec07-integration.md` both now exist on disk (test -f, this
   session). The w982b/w982k integration lanes landed; CYCLE-3(e) is
   superseded by CYCLE-4(a) below.

## CYCLE-4 — CRO loop bookkeeping advance (2026-10-07, lane W984ac)

Read-fresh + disk-verified fold of the post-W982n arc (W983–W984 waves). Prior
entries: CYCLE-3 W982n (+W982q/W982w addenda). No mix commands; no commit made;
all claims re-read from disk this session.

(a) **Typed-gap register** (`plans/w859-typed-gap-register.md`), row-level awk
tally on disk today: **39 REPAIRED / 10 OPEN / 2 TYPED-OPEN = 51 rows** (footer
still shows a stale 50-row/17-OPEN close-out note — superseded by the row-level
tally). Since CYCLE-3's 32 REPAIRED: W982t re-witnessed W722-gap2 (flip applied
by W983d), W983d flipped 2 (W722-gap2 + W793 NO_CROSS_REFERENCE), W983p flipped
4 (W731 limits, W750-G2, W765 GAP-D, W802/W819 mounted), W983o flipped SPEC-07,
W984v flipped W849-2. **DRIFT(REGISTER_COUNT):** 32 + these flips predicts ~40
REPAIRED / ~11 OPEN; disk measures 39/10 — a one-row gap between claimed flips
and on-disk rows (likely one overlap counted twice across w983d/w983p), needs a
one-row reconcile next lane. Exact numbers above supersede the dispatch's
"~40-41/~11".

(b) **Census gate** settled at ≥1352 passed / 0 failed
(`--include eu_ai_act --exclude eu_ai_act_open_gap`; W982w
`plans/w982w-tag-projection-reconcile.md`, witnessed at 6f235905-era head by
w981x; W981v's ≥1385 projection retired). 49.3 corpus open-gap anatomy typed
external by W983n (`plans/w983n-typed-open-493.md`): the OPEN_GAP verdict is a
declaration-driven generated flunk row; closure requires the Commission-operated
Article 71 EU database — genuinely external, TYPED-OPEN stands, sole typed
open gap.

(c) **Pushes.** W981y landed: `plans/w981y-push.md` — xaas `a0723bf6..6f235905`
fast-forward, local==remote at `6f235905`, exit 0. W984d second wave **IN-FLIGHT:
no w984d receipt on disk; `origin/feat/playwright-surface` = `6f235905` while
local HEAD = `5f7f70d9` — 9 commits unpushed** (read-only rev-parse this
session). No drift: W981y's claim matches remote exactly.

(d) **Integration commit stack landed** — 9 real commits since `1f2a2b23`
(git log, this session): w983m's 4 (`79af0623` transfer-reverse court,
`7722091f` purge-expired atomicity, `33da1cbe` DONE-lane receipt landing,
`7de083e2` w983m receipt), w983o's 2 (`e1d986e2` SPEC-07 flip,
`e12615af` collision disclosure), w984r's 3 (`5e21e87c` AIRo wiring corpus,
`8abb03be` reference pages, `5f7f70d9` w984r receipt). Matches the dispatch's
4+2+3 enumeration exactly; also resolves CYCLE-3's w982b/w982k flag (receipts
now on disk, see CYCLE-3 addendum).

(e) **Depth-suite residuals.** W973b leg GREEN: 5/5 passed, exit 0, fresh lane
build root (`plans/w984c-terminal-guard.md`). Checkout stale-contract pair
fixed: 2 failed pre-edit → 13 passed / 0 failed post-edit
(`plans/w984b-checkout-leak.md`). Avatar-2 cascade stale contract fixed
forward, ALIVE at 3× "Result: 5 passed" (`plans/w984i-avatar2-cascade.md`).
Route-castle W984f **IN-FLIGHT: no w984f receipt on disk**.

(f) **Operator handoff refined** (W984s, `plans/w984s-o1-correction.md`):
runbook step O1's plain `mix ecto.migrate` REFUTED by W984o's live-DB precheck
(`plans/w984o-devdb-precheck.md`) — migration 20261007010000 sorts before its
own dedup repair 20261007120000, and live xaas_dev holds 90 dup groups /
109 doomed epochs / 42 receipts referencing doomed epochs, so plain migrate
aborts and self-repeats. Dated correction note appended to O1 in
`_INTEGRATION_RUNBOOK.md` (uncommitted); replacement 3-step handoff recorded.

**Standing.** ALIVE: register tally (39/10/2 on disk), census gate, 49.3
external anatomy, W981y push, 9-commit integration stack, w984c/w984b/w984i
depth-suite fixes, w984s correction. IN-FLIGHT: W984d second-wave push (no
receipt, 9 commits unpushed), route-castle W984f (no receipt). DRIFT:
DRIFT(REGISTER_COUNT) one-row gap (~40 claimed vs 39 measured);
register footer totals stale. PARTIAL: depth-suite residuals (two IN-FLIGHT
legs above). All standing on the uncommitted tree at HEAD `5f7f70d9`.

Receipt: `docs/sjira/v26.10.6/plans/w984ac-cycle-advance.md`.

**CORRECTION (2026-10-07, lane W984ae): CYCLE-4 DRIFT(REGISTER_COUNT)
RESOLVED.** Fresh awk tally: 51 rows = 40 REPAIRED / 9 OPEN / 2 TYPED-OPEN
after one flip applied. Root cause: W984ac's arithmetic double-counted W722
gap-2 (claimed by w982t, applied by w983d — one row, two receipts); the
predicted 41 was wrong by that +1, and the true claim was 40. The remaining
39-vs-40 gap was W849 backlog-2: w984v flipped the row in the per-row verdict
table of `w983p-register-flips.md` but never edited the register itself.
Flip now applied to `w859-typed-gap-register.md` citing w982g (SPEC-34
regen_check) + w984v (CI leg, ci_cd.yaml:107-115); evidence verified on tree.
Register footer refreshed. Receipt:
`docs/sjira/v26.10.6/plans/w984ae-register-reconcile-2.md`.

## CYCLE-4 ADDENDUM — graphql-removal arc + post-removal witnesses (2026-10-07, lane W984br)

Operator directive "no GraphQL" executed fix-forward. Removal arc: W984ao
(code) **MISSING_RECEIPT** (`w984ao-graphql-removal.md` not on disk; work
corroborated indirectly via w984ax/w984x/w984az — IN-FLIGHT, owner must
re-emit); W984ap e2e ALIVE (`plans/w984ap-e2e-removal.md` — deleted untracked
`e2e/graphql-http.spec.cjs`, grep-zero across e2e+playwright config);
W984aq docs ALIVE (`plans/w984aq-graphql-docs-removal.md` — 94-line
/api/graphql section deleted, 2 register rows flipped
OUT-OF-SCOPE(removed-by-operator, 2026-10-07)); W984aw register sweep
0 additional flips (`plans/w984aw-graphql-rows.md`, 51 rows, all surviving
evidence graphql-independent); W984ay straggler sweep PARTIAL_ALIVE
(`plans/w984ay-code-graphql-sweep.md` — zero live graphql code surfaces, 1
load-bearing straggler: pack template
`priv/packs/xaas_library_pack/templates/manufacture.ex.eex` still renders
AshGraphql extensions + six `graphql do` blocks, plus mix.lock mechanical +
5 stale SPEC-31 comment sites); W984bk straggler removal **MISSING_RECEIPT**
(`w984bk*` absent — straggler-removal standing UNKNOWN on disk).

Post/during-removal gates: W984am 1352/0/1-excluded @ `5f7f70d9`
(`plans/w984am-census-rewitness.md`); W984ax same gate on the dirty
mid-removal tree (182 dirty files), corpus graphql-independence confirmed
(`plans/w984ax-euaia-rewitness.md`). Both ALIVE, exit 0.

Push waves 3+4: W984at `6f235905..5f7f70d9` (17 commits, ff, SHA equality
verified, `plans/w984at-push3.md`); W984bh `5f7f70d9..b5d677b3` (1 commit,
`plans/w984bh-push4.md`). Origin == local == `b5d677b3`.

SPEC-07 complete 8/8 (`plans/w983o-spec07-complete.md`): second half landed
by `ddb19522`, compile --force --warnings-as-errors exit 0, court 5/5,
billing 40 passed; register row → REPAIRED. Register tally evolution: 39
(W984ae reconcile) → 40 REPAIRED + 2 OUT-OF-SCOPE after W984aq's flips;
W984aw fresh awk tally on disk 40/7/2/2 (receipted lineage, each flip
cited).

SPEC-08 staged + BLOCKED(billing-tree-hot) ×2: W984az
(`plans/w984az-w729-spec08.md`, corrected W984w's in-flight attribution to
graphql removal; its w984u MISSING_RECEIPT flag is now RESOLVED —
`w984u-billing-commits.md` on disk, commits 32487e08 + d7beb066) and W984bd
(`plans/w984bd-atomic-retrofit.md`, per-site classification: 3 ATOMICIZABLE,
5 NON-ATOMICIZABLE(disclose); disclosure-only falsifier warning carried —
after_action is already in-transaction, disclosure-only conversion is not a
correctness repair).

Mutation waves: w981p 3×KILL (`plans/w981p-open-gap-mutation-hardening.md`),
w984x 4×KILL (`plans/w984x-mutation-wave2.md`; W802 leg witnessed pre-removal,
row since OUT-OF-SCOPE), w984au 4×KILL over 3 rows
(`plans/w984au-mutation-wave3.md`). Cumulative 11 legs, 11 KILL, **0
VACUOUS-GUARD**.

W984bm typed flags (`plans/w984bm-receipts-verify.md`, PARTIAL_ALIVE 4/6):
w984ai + w984al MISSING_RECEIPT(claimed-landed), both still absent on disk;
**w984al additionally uncorroborated** (zero disk references outside the
coordinator log).

**Standing.** ALIVE: e2e/docs removal, register sweep + tally 40/7/2/2,
gates 1352/0 ×2, pushes to `b5d677b3`, SPEC-07 8/8, SPEC-08 staging,
11/11 mutation kills, receipt-verify 4/6. PARTIAL_ALIVE: w984ay straggler
sweep. IN-FLIGHT/DRIFT: w984ao (load-bearing missing receipt, forward-cited
by w984aq) and w984bk (straggler removal UNKNOWN); w984ai/w984al owner
re-emits pending.

Receipt: `docs/sjira/v26.10.6/plans/w984br-cycle4-addendum.md`.

## CYCLE-5 — v26.10.7 campaign open, Define stage (2026-10-07, lane W620)

Read-fresh + disk-verified Define entry opening the v26.10.7 CRO cycle. Prior
entries: CYCLE-4 addendum (W984br). No mix commands; no commit made; all
claims re-read from disk this session.

**Charter.** The v26.10.7 directive's six work packages. Per-WP Measure
baselines below are on-disk receipts only; anything without a receipt is
IN-FLIGHT, not done.

(a) **WP-1 — statutory EU-AI-Act surfaces (OS-14/15/16). Measure baseline
(re-read fresh from `_CLOSURE_PLAN.md` §4 rows, this session):** OS-14
LANDED (W620, Art. 12(3) export endpoint, `plans/w620-os14-export-endpoint.md`);
OS-15 CLOSED (doc-class; standing caveat carried since w694: the cited receipt
`w423` does not exist on disk — closure witnessed by the artifact itself,
`docs/cro/artifacts/bias-awareness-measures-v26.10.6.md`); OS-16 marking leg
ALIVE (w665 7/7, w703 plug-order court, w806 verification) with the
end-user-facing disclosure surface still a retained typed GAP (v26.10.7+
NEW FEATURE). The graphql OUT-OF-SCOPE flips (W984aq, 2 rows) did not touch
these statutory rows; W984aw's sweep flipped 0 additional rows — statutory
rows are graphql-independent on disk. The v26.10.7 WP-1 addition is in
flight: W605's ProvOriginHeader plug (Art. 50(2), PROV-O `x-prov-o` header,
`plans/w605-prov-o-plug.md`) — code on tree, uncommitted, no independent
court run receipt in this cycle's baseline snapshot → IN-FLIGHT(W605).

(b) **WP-2 — OS-18 tautology row. Measure baseline:** OS-18 DONE (W546,
`plans/w546-os18-fix.md`) — tautological `checkpoint_external/2` clause
replaced with a LIVE comparison, forged foreign admission pairs refused
`:external_admission_identity_mismatch`, witness flipped, mutant killed,
corpus 80/80 contention-adjusted. No v26.10.7 WP-2 receipt exists on disk →
WP-2 lane IN-FLIGHT against this baseline.

(c) **WP-3 — agentgateway PEP filter + goose fuzzing harness. Measure
baseline:** w613 PARTIAL_ALIVE (spec-only; `plans/w613-pep-filter-spec.md`;
no local agentgateway checkout, no Rust skeleton, disclosed); w614 ALIVE at
its own gate (`plans/w614-goose-harness.md` + `plans/w614-gate-log.json`:
10 cases, 8 intercepted, interception rate on nonconforming 1.0, all_ok
true, GOOSE-ABSENT, echo-stub agent leg).

(d) **WP-4 — OS-20 four-repo Map.update sweep. Measure baseline:**
ash_a2a W608 (`plans/w608-a2a-map-update.md`): **no-manifestation finding**
— on OTP 29.1.1 + Elixir 1.20.4 the absent-key deviation is NOT observed
(documented-standard semantics across small/large maps); 42 sites / 22 files
classified, 0 lib patches (all dual-safe, idempotent-fun, or
presence-guaranteed), court-only diff. ash_pplan W609
(`plans/w609-pplan-map-update.md`): deviation CONFIRMED live on the pinned
toolchain; after 7eeaaa1 exactly 1 residual `Map.update/4` (synthesis.ex:217,
class-(b) invariant), census court green; standing PARTIAL_ALIVE (second
fresh root `_build-laneW609b` and affected-module gates show "(filled on
completion)" — unfilled). beam4pm and wasm4pm sweep legs: **no receipts on
disk** → IN-FLIGHT (wasm4pm main itself BLOCKED(main-diverged) per
`plans/w601p-phase0-seal.md`). **Citation drift flagged:** the dispatch's
"w606/607" sweep citations resolve to v26.10.6 receipts of a different
subject (`w606-corpus-coverage-audit-2.md`, `w607-349-41-closures.md`), not
Map.update sweeps; the on-disk sweep receipts are w608/w609 only.

(e) **WP-5 — fleet marketplace/version surface. Measure baseline:** w610
PARTIAL_ALIVE (`plans/w610-fixtureonly-markers.md` — `aex:fixtureOnly`
marker surface verified ALIVE on disk across both packs per family;
finding: nothing new to add); w618 uncommitted working-tree edits
(`plans/w618-fleet-version-bump.md` — 8 repos bumped to 26.10.7, grep/
tomllib/json.load validation only, no commits).

(f) **WP-6.** No WP-6 receipt and no WP-6 mention anywhere under `docs/`
(grep, this session) → IN-FLIGHT(UNRECEIPTED); charter text lives in the
operator directive, which is not on disk in this repo.

**Drift flags vs prior cycle entries.**
1. RESOLVED-on-disk: every MISSING_RECEIPT flagged by CYCLE-4 addendum
   (w984br) now exists: w984ai-w1-dim0.md, w984al-corpus-deepening-5.md,
   w984ao-graphql-removal.md, w984bk-straggler-removal.md — plus
   w984bv-removal-commit.md, w984ca-gate5-repairs.md,
   w984cl-semantics-commit.md. The graphql-removal code commits
   (12d5f6d3, 04a153f6) are in local history.
2. Branch state moved: CYCLE-4 addendum stood at `b5d677b3` (origin ==
   local). Now HEAD = `cf228da6` (W984ca gate-5 repairs), local is 9 commits
   ahead of `origin/feat/playwright-surface` (04a153f6), remote is an
   ancestor — fast-forward push pending, no divergence.
3. The v26.10.6 seal exists: annotated tag `v26.10.6` → `cf228da6` (NOT
   pushed) and branch `release/v26.10.7` created from HEAD, per
   `plans/w601q-tag-prep.md` (census gate 1352 passed / 1 excluded / 0
   failed on the sealed subject).

**Standing.** ALIVE: w614 gate, w608 court finding, w601q seal/tag, register
lineage per w984aw. PARTIAL_ALIVE: w613, w610, w609 (unfilled second-root
gates). IN-FLIGHT: W605 court receipt, WP-2/WP-6 lanes, beam4pm/wasm4pm sweep
legs, 9-commit push. UNRECEIPTED: WP-6 charter. No account contact; loop
stays in Define/Measure — S1 account precondition (operator picks targets)
remains unmet. No commit made this lane (coordinator owns integration).

Receipt: `docs/sjira/v26.10.7/plans/w620-cro-entry.md`.
