# CRO Loop

Standing GTM/RevOps engine for the 360 Challenger Pitch + RevOps pipeline.
Operator directive 2026-10-06. Loop owner: Sean. This directory is documentation
only — no code, no tests. Zero-feature discipline on the v26.10.6 closure tree
holds; this loop consumes shipped evidence, it does not manufacture features.

## Purpose

Convert the v26.10.6 refusal/audit evidence corpus into pipeline: CRO/VITO-level
conversations at accounts with (a) EU AI Act exposure, (b) Delaware Caremark
duty-of-oversight exposure, or (c) an active GCP Marketplace EDP drawdown
commitment. The moat claim: unrepresentability + zero-config compliance
(`docs/sjira/v26.10.6/plans/w322-zero-config-posture.md` — posture HELD, zero
safety-adjustable knobs).

## Cadence

Weekly cycle, Monday open / Friday close. One cycle = one pass over all 5 stages
across the active account list. Every cycle appends to `CYCLE-LOG.md` (entry
format there). Cycle closes only when every pursued account has an exit-gate
result (ADVANCE / HOLD / KILL) — no open loops across cycles.

## The 5 Stages

### S1 — Executive Provocation

- **Persona**: CRO / CRO-adjacent C-suite (VITO) at target account.
- **Channel**: LinkedIn InMail (copy verbatim below), then warm-intro email echo.
- **Psychological hook**: blame-avoid. The board's oversight duty (Delaware
  Caremark; EU AI Act Art. 14) now attaches to revenue-system AI they cannot see.
  The provocation names the personal exposure of the executive, not the company.
- **Required artifacts**:
  - InMail copy (below) — human/CRM output, versioned per cycle.
  - `docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md` — the clause-level
    map that backs every claim in the provocation.
  - `docs/sjira/v26.10.6/plans/w322-zero-config-posture.md` — the
    zero-config HELD verdict (configurable safety = liability transfer = anti-selling).
- **Exit gate**: target replies OR engages (reply, connection accept + response,
  or inbound to briefing request). No reply after 2 weekly touches → HOLD, recycle
  next cycle with variant B.
- **Falsifier**: a provocation that produces zero replies across 2 cycles with 2
  different copy variants at >=10 accounts fails the hook, not the list.

### S2 — Downward Mandate

- **Persona**: the exec's delegate — VP RevOps / Head of Sales Systems / Chief of Staff.
- **Channel**: exec-intro email + 30-min exec brief call.
- **Psychological hook**: credit-claim. The delegate gets to own the remediation
  win: "I found the unrepresentable-AI oversight gap and closed it in a quarter."
- **Required artifacts**:
  - 3-page fiduciary briefing (structure verbatim below) — human output,
    rendered per account, versioned per cycle.
  - Coverage map clause table (same as S1) with the account's named clauses highlighted.
- **Exit gate**: delegate accepts a working session with their platform/revops
  team (calendar holds, not verbal interest). Verbal interest without a calendar
  hold = HOLD.
- **Falsifier**: delegate engages socially for >=2 cycles without ever producing a
  calendar hold → the mandate did not go downward; re-aim at a second delegate.

### S3 — Technical Alibi

- **Persona**: the delegate's technical staff — platform eng / security / MLOps.
- **Channel**: working session (screen-share) + evidence pack handoff.
- **Psychological hook**: uncertainty-reduction. The engineers get a machine-
  checkable answer to "can we prove oversight?" — typed refusals, replayable
  receipts, conformance court output — instead of a vendor slide deck.
- **Required artifacts**:
  - `docs/sjira/v26.10.6/plans/w236-refusal-capstone.md` — 86 tests /
    12 files / 0 failures, delta 0, 62/62 refusal tokens.
  - `docs/sjira/v26.10.6/plans/w385-conformance-court.md` — one-command
    machine-readable conformance verdict (EXIT=0, JSON report).
  - `docs/sjira/v26.10.6/plans/w320-anti-vacuity-audit.md` — anti-vacuity
    court proof (the corpus fails when reverted; claims are non-vacuous).
  - `docs/sjira/v26.10.6/plans/w317-pw-final-tokened.md` — Playwright
    tokened surface (product actually runs end to end under real tokens).
- **Exit gate**: technical staff reproduce at least one artifact themselves
  (run the conformance report or a refusal-negative test file) in-session or on
  their own checkout. "Looks good" without reproduction = HOLD.
- **Falsifier**: a session where the demo is delivered but nothing is reproduced
  by the account fails the stage — the alibi was shown, not transferred.

### S4 — Frictionless Close

- **Persona**: delegate + procurement/finance (EDP owner at the account).
- **Channel**: private offer via GCP Marketplace (EDP drawdown-eligible) —
  procurement friction is the close mechanism, not a hurdle.
- **Psychological hook**: blame-avoid + uncertainty-reduction. Marketplace
  private offer = zero new procurement cycle, spend counts against existing EDP
  commitment, and the paper trail itself is the oversight artifact.
- **Required artifacts**:
  - Private offer draft (human/CRM output, versioned per cycle).
  - `docs/sjira/v26.10.6/plans/w390-sync-output-staging.md` —
    evidence that deliverable staging is deterministic/replayable (what the
    account is buying behaves the same on replay).
- **Exit gate**: private offer issued in GCP Marketplace (offer ID exists), OR a
  signed LOI naming Marketplace as channel. Verbal "we'll fund it" = HOLD.
- **Falsifier**: a cycle that closes direct-services or PO work around the
  Marketplace path fails the stage — the frictionless channel was bypassed.

### S5 — Land-and-Expand

- **Persona**: landed account's exec sponsor + adjacent execs (2nd-division CROs
  in the sponsor's network).
- **Channel**: quarterly business review + referral motion.
- **Psychological hook**: credit-claim. The sponsor presents the compliance
  receipt to their board/peer group; the referral carries their credibility, ours.
- **Required artifacts**:
  - QBR deck (human output) anchored on cycle-over-cycle conformance receipts.
  - `CYCLE-LOG.md` entries as the standing delivery record.
- **Exit gate**: a named referral (account + person) entered into next cycle's
  S1 list, or an expansion artifact (new clause coverage, new surface) accepted
  in writing.
- **Falsifier**: a landed account that produces no referral and no expansion
  accept across 2 quarters fails the loop's expansion premise; log KILL on expand.

## InMail Copy (operator directive, verbatim)

> **Subject:** Delaware Duty of Oversight & Agentic AI Liabilities (DGCL § 102(b)(7))
> Dear [First Name],
> As corporate officers evaluate autonomous AI agent deployments, a critical
> corporate governance divide has emerged under Delaware oversight
> jurisprudence.
> Following *In re McDonald's Corp.* (289 A.3d 343) and *Marchand v.
> Barnhill*, Delaware courts have confirmed that officers owe non-exculpable
> duties of loyalty to institute active reporting and monitoring controls over
> mission-critical operational risks. Allowing autonomous systems to actuate
> enterprise databases under probabilistic prompt filters creates uninsurable
> balance-sheet liability, while issuing paper bans drives unmonitored shadow
> AI underground.
> We have engineered a deterministic governance appliance—listed natively on
> the Google Cloud Marketplace—that renders non-compliant agent actions
> mathematically unrepresentable while compiling specialist workflows into
> permanent, deterministic corporate software. Every intercepted command
> generates a post-quantum cryptographic affidavit (NIST FIPS 204 ML-DSA)
> that serves as self-authenticating legal evidence under FRE 902(14).
> Because it deploys directly inside your Google Cloud environment, it draws
> down against your existing committed cloud spend (EDP) with zero net-new
> budget authorization.
> I've prepared an executive briefing on how peer CROs are neutralizing
> specialist talent blackmail and structuring affirmative *Caremark* defenses
> for autonomous systems.
> Would you be open to reviewing the 3-page fiduciary brief, or should I
> coordinate with your VP of Infrastructure?
> Sincerely,
> [Your Name]
> Founder / Managing Director, [Company Name]

Variant B (cycle-2 recycle): swap the evidence paragraph for the direct
evidence pack (62/62 refusal tokens, 86/0 capstone, one-command conformance
court — every number a file you can run).

## 3-Page Fiduciary Briefing (operator directive, verbatim structure)

> **Section 1: The Compliance Exposure Matrix.** Side-by-side mapping of the
> enterprise's current LLM/MCP tool stack against EU AI Act Articles 12, 14,
> 15, and Delaware *Caremark* prongs.
>
> **Section 2: The Two-Tier Architecture.** The qualified defense boundary:
> *Tier 1 (Deterministic Operational Design Domain):* GraphLaw and GymAct
> render out-of-bounds tool calls unrepresentable via fail-closed WebAssembly
> SHACL admission. *Tier 2 (Board Fiduciary Boundaries):* CASTLE enforces
> capital-at-risk budgets and nondelegable human gates, bounding the residual
> lawful-action risk.
>
> **Section 3: Cloud Procurement Mechanics.** How the purchase decrements
> existing Google Cloud Enterprise Discount Program (EDP) commitments,
> requiring zero procurement committee budget battles.

## Cycle Falsifier (whole-loop)

**A cycle fails if: any artifact cited to an account does not exist on disk at
the cited path (`test -f`), or the loop produces zero stage-advances (no S1
replies, no S2 calendar holds, no S3 reproductions, no S4 offer IDs, no S5
referrals) across 2 consecutive cycles with variant rotation — then the
provocation premise itself is dead, not the execution.**

## See Also

- `docs/cro/ARTIFACT-MANIFEST.md` — per-stage artifact registry.
- `docs/cro/CYCLE-LOG.md` — cycle entries.
- `docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md` — clause-level evidence base.

## Status / Changelog (pointer lines only — content lives in CYCLE-LOG.md)

- **Last cycle**: `CYCLE-5` (2026-10-07, v26.10.7 campaign open, lane W620) —
  `docs/cro/CYCLE-LOG.md`. Define stage: charter = the six v26.10.7 work
  packages with per-WP Measure baselines cited to on-disk receipts
  (statutory OS-14/15/16, OS-18, agentgateway PEP + goose fuzz, OS-20
  four-repo Map.update sweep, fixtureOnly/version-bump fleet surface).
  Prior evidence pointer: `CYCLE-1-PREP` and the CYCLE-2/3/4 + CYCLE-4
  addendum fold entries below. The v26.10.7 statute/fuzz/deepening receipts
  (w605/w608/w609/w613/w614/w610/w618) strengthen the S1/S3 evidence corpus
  consumed by this loop; no account contact was made in CYCLE-5. Receipt:
  `docs/sjira/v26.10.7/plans/w620-cro-entry.md`.
- Prior cycle: `CYCLE-1-PREP` (2026-10-07) — `docs/cro/CYCLE-LOG.md`.
  Consolidation wave W640–W780 prep: S3 evidence strengthened, S1/S2
  refreshed in place; overall HOLD on terminal claims. Headline: 8 repairs
  landed ALIVE (W676/W679/W708/W726/W732/W737/W739/W740; W746 NO_RECEIPT)
  with 6 FMEA deltas and controls per `w781-wave-ledger-refresh.md`;
  38 consolidation-wave rows tallied in §5 of `_CLOSURE_PLAN.md` per
  `w798-closure-5-refresh.md`; cycle-log entry per
  `w753-cycle-log-refresh.md`. Subject: `feat/playwright-surface` @
  `a0723bf6` (uncommitted lane diffs; coordinator owns integration).
- Next cycle open requires: operator picks target accounts (S1 precondition,
  still unmet per CYCLE-1-PREP).

## Ship/Remove Annotations (w405 evidence-claims-index, 2026-10-06)

The verbatim blocks above are operator source and are not edited in place.
Per `artifacts/evidence-claims-index.md`, the ship-list corrections that MUST
accompany any send:

- REMOVE: "<15 ms WASI gate", "FRE 902(14)" (no backing artifact).
- QUALIFY: "RFC 8785 canonical receipt, digested via BLAKE3" → actual:
  SHA-256 over RFC 8785/JCS canonical JSON — the canonical-encode + digest +
  verify path is exercised end-to-end by `mix xaas.release_snapshot.verify`
  (w418: machine verdict ALIVE, exit 0); BLAKE3 removed (w405).
- QUALIFY: "signed using NIST FIPS 204 (ML-DSA-65)" → actual: ML-DSA-65 is an
  admitted alias in the witness signing catalog; no witnessed runtime-signed
  receipt yet.
- QUALIFY: "mathematically unrepresentable" → "fail-closed deterministic
  refusal with replayable typed receipts".
- NUMBERS: cite 62/62 tokens, 86/0 capstone (w236), 26/26 conformance
  (in-repo court, not official A2A TCK), 96/0 tokened Playwright (w317).
