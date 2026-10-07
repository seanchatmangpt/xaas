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
