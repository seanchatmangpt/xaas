# W712 — actuation-and-semantics reference: EU-AI-Act semantics layer deepening

Subject: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface`.
Files written (only): `docs/claude/diataxis/reference/actuation-and-semantics.md`
(new section "EU-AI-Act semantics layer (v26.10.6)" inserted before "Digest forms"),
this receipt. No commit. No build root. No other page touched.

## Sections verified (pre-existing, confirmed accurate against code)

- `Xaas.Semantics.Registry` admitted public namespaces, `projection/1`, `admit/1`
  refusal, SHA-256 `hash/1` — matches `lib/xaas/semantics/registry.ex:1`.
- Consequential actuation API contract (idempotency-key requirement, admitted path,
  `normalize_transaction_result/1`, `Refusal` sealing, conflict tuple) — matches
  `lib/xaas/actuation.ex` (module present; contract text unchanged this lane).
- Provider lifecycle, receipt/replay, SA2A execute edge, Ferroplan bridge, gymact
  adapter, AshA2A mount, admission binding modes, digest forms — read in full;
  no drift found vs. code this lane's scope. Not modified.

## Sections added: "EU-AI-Act semantics layer (v26.10.6)"

Per-claim evidence (all `file:line` re-read from the tree at a0723bf6):

| Claim | Evidence |
| --- | --- |
| Eight closed Art. 5(1) refusal atoms + malformed-candidate atom; structural checks in article order, first hit wins | `lib/xaas/semantics/eu_ai_act_admission.ex:33-42` (atom list), `:106-116` (admit/1 reduce, `:REFUSED_EUAIA_MALFORMED_CANDIDATE`), `:120-138` (checks list, article order) |
| Per-article structural invariants (table rows a-h) | `eu_ai_act_admission.ex:141-189` (each `*_?/1` predicate), moduledoc table `:14-23` |
| Structural, never content inspection | moduledoc `:8-11`, `:26-30` ("never inspects free text... only the declared intent schema") |
| describe/1 maps atom → Art. 5(1) partition | `eu_ai_act_admission.ex:77-99` |
| Improper-list totality guard (W630) | `eu_ai_act_admission.ex:191-209` |
| W521 intake plug on /a2a POST before agent dispatch; 9-field atom normalization via `String.to_existing_atom/1`; no new atom minted; JSON-RPC -32600 refusal envelope, HTTP 200 | `lib/xaas_web/plugs/eu_ai_act_admission_plug.ex:1-29` (moduledoc), `:37-47` (`@schema_fields`), `:53-66` (call/2), `:155` (describe in error data); wired in `lib/xaas_web/endpoint.ex:100` |
| Semantics layer = admission/observation only, no DO authority | `eu_ai_act_admission.ex:30` ("admission surface only... never grants authority, never actuates"); module list `lib/xaas/semantics/` (23 modules, none in the actuation path) |
| AIRo mapping: deterministic Turtle graph, RiskSource/Hazard per refusal variant, RiskControl per enforcing module, AISystem/AIDeployer | `lib/xaas/semantics/airo_risk_mapping.ex:1-15`, `:218-298` |
| EuAiActAdmission registered as enforcing module; euaia atoms seed IncidentReport | `airo_risk_mapping.ex:79`; `lib/xaas/semantics/incident_report.ex:38` |
| Vendored ontology `priv/semantic/airo/airo.ttl` sha256-pinned | `test/xaas/semantics/airo_vendored_pin_test.exs:11,26-59` |
| Export endpoint `GET /internal-api/eu-ai-act/pack`, token-gated, 503 refused shape `xaas.eu_ai_act_pack_refusal/v1`, same pack as `mix xaas.eu_ai_act_pack` via `build/1` | `lib/xaas_web/router.ex:88-98`; `lib/xaas_web/controllers/eu_ai_act_export_controller.ex:1-33` (incl. `@refusal_status 503` `:18`); `lib/mix/tasks/xaas.eu_ai_act_pack.ex:141` (`def build(now \\ ...)`) |
| Pointer to sibling page `eu-ai-act-semantics.md` | exists untracked in tree (`docs/claude/diataxis/reference/eu-ai-act-semantics.md`) |

## Standing

ALIVE (documentation lane): every added claim carries a file:line re-read from the
exact subject a0723bf6; the target page verified on disk after edit (corruption-marker
grep zero hits; 9 `REFUSED_EUAIA` occurrences, section renders at line 255 onward).
One disclosed drift note: `Xaas.Semantics.EuAiActAdmission`'s own moduledoc still says
"wired into no live route" (`eu_ai_act_admission.ex:30`), but the W521 plug IS wired
in `XaasWeb.Endpoint:100` — the doc section records the plug, not the stale moduledoc.
Code untouched; falsifier for the doc-lane claim: any file:line above that fails to
resolve at a0723bf6 falsifies the receipt.
