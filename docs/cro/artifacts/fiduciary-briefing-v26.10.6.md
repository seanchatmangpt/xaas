# Fiduciary Briefing — v26.10.6 (Stage-2 Artifact, Lane W404)

Date: 2026-10-06. Subject: `/Users/sac/xaas` @ `feat/playwright-surface` @ `d1db2b03`.
Structure: operator directive, verbatim (`docs/cro/CRO-LOOP.md` § "3-Page Fiduciary Briefing").
Every claim cites a file on disk at the cited path. Typed gaps are roadmap, not delivered capability.

## Section 1 — The Compliance Exposure Matrix

Side-by-side mapping of the incumbent LLM/MCP tool stack vs. EU AI Act Arts. 12/14/15 and Delaware *Caremark*, per `docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md` (lane W319).

| Clause | Incumbent-stack gap | Our evidence path | Verdict |
|---|---|---|---|
| Art. 12(1) automatic event recording | Prose audit trails, post-hoc logs | OCEL NDJSON telemetry (`lib/xaas/telemetry/ocel_ndjson.ex`); receipts w236/w176 (`docs/sjira/v26.10.6/plans/w236-refusal-capstone.md`) | EVIDENCED |
| Art. 12(b) traceability incl. refused actuation | Refusals vanish as exceptions | Refusal atoms `lib/xaas/actuation.ex:537-547,770`; w13 pre==post state fixtures | EVIDENCED |
| Art. 12(3) authority export | No retention/export artifact | **Typed gap — roadmap:** `GAP(NO_AUTHORITY_EXPORT_SURFACE)` (coverage map §1) | PARTIAL — not claimed done |
| Art. 14(1)/(4)(a)-(e) human oversight | Threshold judgement, silent-proceed | BRCE admission before consequential DO; 62/62 typed `REFUSED_*` tokens (w236, `_CLOSURE_PLAN.md` §2); no fallback-to-proceed branch (`actuation.ex:537-547,770`) | EVIDENCED |
| Art. 14(4)(e) automation-bias doc class | Vendor slide-deck class | **Typed gap — roadmap:** `GAP(NO_BIAS_AWARENESS_DOC)` (coverage map §1) | PARTIAL — not claimed done |
| Art. 15(1)(a/c/d) robustness/cyber | Drift, open endpoints, repair-not-refuse | `REFUSED_XAAS_PROJECTION_DRIFT` (`lib/xaas/castle.ex:380`); fail-closed plug 7/7 (`test/xaas_web/plugs/require_internal_api_token_test.exs`); 62/62 refusal-first (`castle.ex:829`) | EVIDENCED |
| Art. 50 end-user disclosure | No disclosure surface | **Typed gap — roadmap:** `GAP(NO_END_USER_DISCLOSURE)` (coverage map §4) | PARTIAL — not claimed done |
| *Caremark* (good-faith oversight system) | "We take security seriously" prose | Machine-checkable receipts: 86/0 capstone + 62/62 tokens (w236); one-command conformance court 26/26 (`docs/sjira/v26.10.6/plans/w385-conformance-court.md`, EXIT=0, JSON fail=0) | EVIDENCED at receipt class |

## Section 2 — The Two-Tier Architecture

The qualified defense boundary, two tiers, both grounded in on-disk receipts.

**Tier 1 — Deterministic Operational Design Domain (unrepresentability via typed admission).**
GraphLaw/GymAct-class fail-closed WebAssembly SHACL admission renders out-of-bounds tool
calls unrepresentable: the admission kernel returns typed refusals, never prose. Evidence:
62/62 distinct `REFUSED_*` tokens carry negative fixtures — reverting any refusal branch
fails its fixture (w236 capstone: 86 tests / 12 files / 0 failures, delta 0;
`docs/sjira/v26.10.6/plans/w236-refusal-capstone.md`; delta recount `_CLOSURE_PLAN.md` §2.1).
Structurally-unreachable residue is typed with reasons per `_CLOSURE_PLAN.md` §2 (e.g.
`castle.ex:941` `BLOCKED_CASTLE_TRANSPORT` raw-string until typed; R2RML `UNKNOWN_ATTRIBUTE`
proven unreachable by call graph, w185/w208) — the gap list is itself machine-checkable.
Zero-config: no env flag weakens any refusal; category-(c) findings = **zero**, posture HELD
(`docs/sjira/v26.10.6/plans/w322-zero-config-posture.md`); OS-17 CLOAK_KEY prod-guard gap is
typed and gated on operator decision (w349 `docs/sjira/v26.10.6/plans/w349-cloak-key-guard.md`,
w393 `docs/sjira/v26.10.6/plans/w393-cloak-prod-wiring.md`).

**Tier 2 — Board Fiduciary Boundaries (CASTLE budgets + human gates).**
CASTLE enforces capital-at-risk budgets and nondelegable human gates, bounding residual
lawful-action risk: authority gate `REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED` (`lib/xaas/castle.ex:829`),
runtime identity gate (`castle.ex:862`), checkpoint digest/evidence-path gates
(`castle.ex:436-460`). Refusal families with negative fixtures per `_CLOSURE_PLAN.md` §2:
castle engine (44 fixtures), outer intent/receipt gate (13 tokens, batch6 18 tests, w208),
required-field gate, actuation atoms (5), VKG (3), R2RML (2), fail-closed plug + body limit
(10), token revocation (4). Product runs end-to-end under real tokens: Playwright tokened
browser rung 96 passed / 0 failed (`docs/sjira/v26.10.6/plans/w317-pw-final-tokened.md`,
HEAD `d1db2b03`, PW_PORT=4017, webServer via BOOT readiness gate).

## Section 3 — Cloud Procurement Mechanics

Per operator directive (`docs/cro/CRO-LOOP.md`, § S4):
purchase decrements existing Google Cloud EDP commitments via private offer — zero
procurement-committee budget battles.

- **EDP drawdown**: marketplace private offer counts against the account's existing EDP
  commitment; the paper trail is itself the oversight artifact (CRO-LOOP S4, hook =
  blame-avoid + uncertainty-reduction).
- **Private offer**: EVIDENCED-BY-PROCESS — S4 defines it as human/CRM output with exit
  gate = offer ID in GCP Marketplace (`docs/cro/CRO-LOOP.md` § S4); correctly outside the repo.
- **EULA subsumption**: **PENDING-VERIFICATION / GAP(unevidenced)** — zero hits for EULA in
  ggen-marketplace `scripts/` and `k8s/` (real grep, exit 1; no `lib/` directory exists there)
  per the W402 Stage-4 verification receipt
  (`docs/cro/artifacts/stage4-entitlement-flow-verification.md`). Note: tasking referenced a
  w398 companion receipt; **no w398 file exists on disk** under
  `docs/sjira/v26.10.6/plans/` — the 86/0 + 62/62 numbers are receipted at w236 only.
- **W402 Stage-4 verdicts (receipt on disk, cited inline)**: entitlement activation
  transition EVIDENCED (sim, one-step approve→`ENTITLEMENT_ACTIVE`,
  ggen-marketplace `k8s/gcp-marketplace-sim/server.py:168-217`); "via Pub/Sub" transition
  **GAP(unevidenced)** (envelope minted into HTTP response, no subscriber/state machine,
  `server.py:201-216`); usage admission entitlement-gated 403 `ENTITLEMENT_REQUIRED`
  (`server.py:249-303`); typed `decide()` seam with real-rail fence `REFUSED_REAL_NOT_PERMITTED`
  (`ggen-marketplace/scripts/entitlement.py:266-285`). Stage-4 standing: **PARTIAL**
  (`docs/cro/artifacts/stage4-entitlement-flow-verification.md`).

Standing of this briefing: artifact-complete, evidence-cited; typed gaps (Art. 12(3), 14(4)(e),
50 end-user disclosure, EULA/Pub/Sub Stage-4 gaps) presented as roadmap, never claimed done.
