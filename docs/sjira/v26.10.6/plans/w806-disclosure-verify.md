# W806 — End-User Disclosure Artifact Verify (against landed enforcement courts)

Lane W806, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD a0723bf6.
Write scope: `docs/cro/artifacts/end-user-disclosure-v26.10.6.md` (corrections in
place) + this receipt. No code, no commit, no build root (per lane contract).

## Inputs verified

- Artifact: `docs/cro/artifacts/end-user-disclosure-v26.10.6.md` (W424, 2026-10-06)
- `docs/sjira/v26.10.6/plans/w665-art50-deepening.md` — 7 passed
- `docs/sjira/v26.10.6/plans/w703-plug-order-court.md` — 4 passed
- `docs/sjira/v26.10.6/plans/w699-a2a-v1-wire-deepening.md` — 9 passed
- `docs/sjira/v26.10.6/plans/w723-token-floor-court.md` — 16 passed
- Live-tree confirmation: `lib/xaas_web/plugs/synthetic_marking_plug.ex` and
  `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex` exist; `lib/xaas_web/endpoint.ex:99-100`
  mounts `plug(XaasWeb.Plugs.SyntheticMarkingPlug)` then
  `plug(XaasWeb.Plugs.EuAiActAdmissionPlug)` (read directly, sed 95-104).

## Per-claim dispositions

| # | Artifact claim (origin line) | Status | Evidence |
|---|---|---|---|
| 1 | "an end user ... cannot tell 'policy refused' from 'tool does not exist' from the wire alone. ... today neither is carried on the wire." (§1) | CORRECTED | Superseded on `/a2a/v1`: W665 50.2a (receipt line 27-30) pins the Art. 5 refusal body is NOT the `-32602 Tool not found` shape; W703 court (a) (receipt lines 19-22) pins the envelope is `-32600` + `REFUSED_EUAIA_MANIPULATIVE` + marked. `/mcp` ash_ai `-32602` path unchanged — correction scopes it there explicitly. |
| 2 | §2a "a policy refusal is never reported as a missing tool" (design statement) | CORRECTED (design → court-enforced on /a2a/v1, design-only on /mcp) | W665 receipt lines 27-30; W703 receipt lines 19-22. Note added under §2a naming both courts. |
| 3 | §2b long-form properties (typed refusal, marking, fail-closed) | VERIFIED as text; enforcement now witnessed | §2c subsection added citing all four courts with real pass counts (7/4/9/16) and file paths, copied verbatim from each receipt's real tail. |
| 4 | Implied substrate: marking + admission plugs mounted | ADDED | §4 note: `lib/xaas_web/endpoint.ex:99-100` confirmed in-tree this session (direct read); W703 court pins the order with a witnessed reorder kill (receipt lines 33-38). |
| 5 | OS-16 open-gap framing (§4 "Content authored only... OS-16 remains open") | VERIFIED / kept honest | No Art. 50 disclosure TEXT is mounted anywhere: no `disclosure` field on tool results, no agent-card Art. 50 field, no client banner — confirmed against the court subjects (W699 pins agent-card members, no disclosure field among them, receipt line 45-48). §4 updated to state the courts prove the enforcement substrate, not the disclosure. OS-16 stays open, v26.10.7+. |
| 6 | §3 mount points (execution_fabric_controller, agent card, ash_surface projector) | VERIFIED unchanged, no edit needed | No court superseded these recommendations; W699's card-court actually confirms point 2's mount target exists and is exercised. |

## Standing

- Disclosure artifact: PARTIAL_ALIVE — content accurate and now backed by
  court-enforced enforcement evidence (§2c); surface mount still UNBUILT;
  OS-16 open by design.
- Emotion-recognition gap disclosed by W665 (bare technique atom admits,
  conjunctive domain+setting gate) surfaced in §2c so the disclosure text's
  "typed refusal" claim stays honest about kernel scope.

## Falsifier

Re-run each court's exact command (in the four receipts); any failure flips
the §2c claims in the artifact. Drift gate: if `endpoint.ex:99-100` plug
order changes, W703 court (c) fails first.

## Verification

Real outputs this session: `ls` confirmed both plug files; `sed -n 95,104p`
`lib/xaas_web/endpoint.ex` returned the two `plug(...)` lines. Pass counts
taken from the receipts' recorded real tails (7/4/9/16), not re-run (no
build root per lane contract — disk-constrained).
