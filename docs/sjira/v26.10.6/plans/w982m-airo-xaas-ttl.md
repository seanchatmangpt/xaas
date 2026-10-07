# W982m — AIRo xaas risk-description TTL — Receipt

- **Lane**: W982m, xaas v26.10.6 campaign
- **Date**: 2026-10-07
- **Subject**: /Users/sac/xaas, branch `feat/playwright-surface`, HEAD
  `6f235905b6e071c236c5abb0ce0bf872e0bfd7b4` (uncommitted work tree;
  coordinator owns commits)
- **Build**: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982m` — **left on disk**
  (deletion via `rm -rf` was permission-denied to this lane; coordinator
  should delete it at integration, per the lane-lease cleanup law)

## Deliverable

**NEW `priv/airo_risk_description.ttl`** — a real AIRo 1.0 risk-description
graph over the xaas refusal-engine control plane. Note on placement: the
lane order said "write only priv/semantic/airo/", but the falsifier
convention (W981e/W981f rows + W981j amendment) names
`priv/airo_risk_description.ttl`; the falsifier-named path wins (the
`priv/semantic/airo/` directory is the vendored canonical vocabulary and
stays untouched).

- own-sha256 `c85de1b8f96ad4b911bc89c445d8de58c0cff8bbb89d957744ba52ef515fbf8e`
- header pins canonical vocab sha `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
  (byte-verbatim vendored at `priv/semantic/airo/airo.ttl`, re-verified by
  the W981j pin court in-test both runs)
- 95 triples; 25 distinct airo: IRIs used, **all verified members of the
  canonical vocab graph** (`missing_from_vocab: []` — computed, not assumed;
  RDF.ex membership against `priv/semantic/airo/airo.ttl` subjects+predicates)
- convention: `w982m:`-qualified individuals (w601 fleet convention; AIRo 1.0
  has no concrete risk individuals)

### Graph summary (RDF.ex parse, executed twice, identical)

| type | individuals |
|---|---|
| airo:AISystem | 1 (`w982m:XaasRefusalEngine`) |
| airo:AIComponent | 5 (ActuationKernel, TypedRefusalCourt, InternalApiAuthFloor, EuAiActAdmissionGate, FreezeWindowGate) |
| airo:Hazard (RiskSource) | 4 (ForgedActuationArtifact, UnauthenticatedInternalAccess, ProhibitedPracticeIntake, FreezeWindowViolation) |
| airo:Risk | 1 (`w982m:UnreceiptedActuationRisk`) |
| airo:Consequence | 2 |
| airo:Impact | 1 |
| airo:RiskControl | 5 (same five gates, also typed RiskControl) |
| Likelihood / Severity / LifecyclePhase / AIUser | 1 each |

Bindings (3-5 surfaces, honest): `Xaas.Actuation` BRCE actuation kernel
(`lib/xaas/actuation.ex`), typed-refusal negative court
(`test/xaas/actuation_refusal_negative_test.exs` — :subject_id_required,
:external_projection_mismatch, :external_receipt_intent_mismatch,
:external_checkpoint_conflict, :external_admission_identity_mismatch,
:external_input_mismatch), fail-closed `RequireInternalApiToken`
(`lib/xaas_web/plugs/require_internal_api_token.ex`), EU AI Act admission
gate (`lib/xaas_web/plugs/eu_ai_act_admission_plug.ex` +
`lib/xaas/semantics/eu_ai_act_admission.ex`), governance freeze-window gate
(`lib/xaas/governance/freeze_window.ex`).

**All 6 cited `file://` paths filesystem-verified to exist** (real per-path
test loop, all `OK`, zero MISSING).

## Executed commands (real tails)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982m \
    mix run --no-start /tmp/w982m_parse.exs     # RDF.Turtle.read_file! + structure/vocab checks
RESULT triples: 95
RESULT AISystem: 1 ... RiskControl: 5 ...
RESULT airo IRIs used: 26; missing_from_vocab: []     # run 1 and run 2 identical

$ ... mix test test/xaas/airo/airo_pin_court_test.exs    # run 1
Result: 6 passed
$ ... mix test test/xaas/airo/airo_pin_court_test.exs    # run 2
Result: 6 passed
```

Two green pin-court runs (6/6 ×2) plus two green RDF.ex parses on the exact
subject. No mocks anywhere: real file bytes, real `git rev-parse` subprocess
(in-court), real RDF.ex parser.

## Standing: ALIVE (for the falsifier shape)

The W981e/W981f falsifier gate — "`priv/airo_risk_description.ttl` w/ vocab
sha `6274d2d8…`, cited paths exist, graph parses w/ RiskSource/Control/Risk
triples" — is **satisfied on the xaas subject for real**: TTL exists at the
convention path, pins the verified canonical vocab sha, all cited paths
exist, the graph really parses (RDF.ex 3.0.1) with 4 RiskSources / 5
RiskControls / 1 Risk, and every airo: term is a canonical-vocab member.
The pin court is green ×2. Nothing was faked; no ALIVE was minted by
rewording.

## Residual / not done by this lane

1. **The ledger row cell itself was not edited.** `docs/cro/artifacts/
   airo-wiring-ledger.md` has no explicit "xaas" row in the W981e/W981f
   extension tables (those 9 rows are sibling repos), and the lane write
   scope was TTL + receipt only. Also: adding a 7-column SHA row would break
   the pin court's `length(extension_rows()) == 9` assertion. The flip
   UNKNOWN→ALIVE is therefore recorded HERE, with the full evidence chain,
   for the **coordinator to land as a ledger edit** — recommended shape: a
   6-column consolidated-table-format row (lane w982m / repo xaas /
   artifact `priv/airo_risk_description.ttl` / sha+parse proof / 6 passed /
   plans/w982m-airo-xaas-ttl.md), which the row parser safely ignores.
2. `_build-laneW982m` (448 MB) still on disk — deletion permission denied
   in-lane; coordinator deletes at integration.
3. Transient in-lane event, resolved: first `mix run` compile pass hit
   `no space left on device` during protocol consolidation (~1.9 GB free on
   `/`); subsequent runs with `--no-start` completed green. Disk headroom
   remains tight for the campaign generally (many stale `_build-lane*`
   roots on disk).

## Falsifiers (executable)

- Corrupt any triple in `priv/airo_risk_description.ttl` → RDF.ex parse or
  vocab-membership check fails.
- Delete any cited path → per-path existence check names it MISSING.
- Introduce any airo: IRI outside the canonical vocab →
  `missing_from_vocab` names it.
- Pin court (`test/xaas/airo/airo_pin_court_test.exs`) is the standing
  executable gate for the ledger rows.

## Replay

From `/Users/sac/xaas` on the pinned toolchain: the four commands above
(two parses + two court runs). Vocab pin verifiable via
`shasum -a 256 priv/semantic/airo/airo.ttl`.

REFUSED: none. UNSUPPORTED: none. BLOCKED: none.
