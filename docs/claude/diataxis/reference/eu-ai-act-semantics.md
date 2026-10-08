# EU AI Act Semantics Reference

Exact factual contracts for `lib/xaas/semantics/` — the EU-AI-Act semantics
layer. Facts only, from the code at HEAD `a0723bf6`. Corpus line ids refer to
`docs/eu_ai_act/corpus.json` (Regulation (EU) 2024/1689).

The per-module sections below are the authority. The "Module census (W864)"
block is a snapshot refreshed at its stamped date (2026-10-07) against a real
`ls lib/xaas/semantics/`; if the census and the sections disagree, the
sections and the source win.

## Xaas.Semantics.EuAiActAdmission

Typed admission profile over candidate intent maps, rendering the eight
prohibited-practice partitions of Art. 5(1)(a)-(h) as unrepresentable inputs
(structural disjointness over the declared intent schema), not content
screening. Never grants authority, never actuates, wired into no live route.

Public functions:

- `refusal_atoms() :: [refusal_atom(), ...]`
- `describe(refusal_atom()) :: String.t()`
- `admit(candidate() | term()) :: {:ok, :admitted} | {:error, refusal_atom()}`

Refusal atom set (closed, 8 atoms):

| atom | Art. 5(1) | corpus line |
|---|---|---|
| `REFUSED_EUAIA_MANIPULATIVE` | (a) | `5.1.a` |
| `REFUSED_EUAIA_VULNERABILITY_EXPLOIT` | (a) | `5.1.a` |
| `REFUSED_EUAIA_SOCIAL_SCORING` | (b) | `5.1.b` |
| `REFUSED_EUAIA_PREDICTIVE_POLICING` | (c) | `5.1.c` |
| `REFUSED_EUAIA_FACIAL_SCRAPING` | (d) | `5.1.d` |
| `REFUSED_EUAIA_EMOTION_RECOGNITION` | (e) | `5.1.e` |
| `REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` | (f) | `5.1.f` |
| `REFUSED_EUAIA_REALTIME_RBI` | (g)/(h) | `5.1.g`, `5.1.h` |

Structural invariants (field/context disjointness over the declared intent
schema):

- (a) MANIPULATIVE: no `:manipulate_behavior`/`:deceptive`/`:subliminal`
  technique class
- (a) VULNERABILITY_EXPLOIT: no cross-join of an audience slice with a
  vulnerability predicate
- (b) SOCIAL_SCORING: no join of `:social_behavior` data into an unrelated
  decision context
- (c) PREDICTIVE_POLICING: no individualized join under a
  `:predict_offending` purpose
- (d) FACIAL_SCRAPING: `:facial_images` domain admits only `:consented`
  provenance
- (e) EMOTION_RECOGNITION: no `:affective` data domain in `:workplace`/
  `:education` settings
- (f) BIOMETRIC_CATEGORIZATION: biometric match tokens are boolean-only; no
  sensitive `:inferences`
- (g)/(h) REALTIME_RBI: no `:realtime` latency goal under biometric
  identification in `:public_space`

Additional refusal: `REFUSED_EUAIA_MALFORMED_CANDIDATE` for non-map
candidates. Source: `lib/xaas/semantics/eu_ai_act_admission.ex`.

## Xaas.Semantics.DatasetAdmission

Art. 10 dataset admission gate (Theorem 3.2). Gate order, each fail-closed:
empty dataset; completeness `< 1 - eta`; sliced Wasserstein-1 proxy
`> epsilon_bias`; else admit. `epsilon_bias`, `eta`, `seed`, `projections`
are call arguments (zero-config). Sliced W1 is a documented seeded upper-bound
proxy, not the exact transport quantity.

Public functions:

- `admit([sample()], opts()) :: {:ok, %{...}} | {:error, term()}` —
  returns `:ADMITTED` verdict map or typed refusal
- `completeness([sample()], [atom() | String.t()]) :: float()`
- `sliced_w1([sample()], integer(), pos_integer()) :: float()`

Refusal atoms: `REFUSED_EMPTY_DATASET`, `REFUSED_INCOMPLETE_DATASET` (payload
`%{completeness:, threshold:}`), `REFUSED_BIAS_THRESHOLD` (payload
`%{w1_proxy:, epsilon_bias:}`), `REFUSED_ARITHMETIC_OVERFLOW`.
Corpus: Art. 10 lines `10.1`-`10.5`. Source:
`lib/xaas/semantics/dataset_admission.ex`.

## Xaas.Semantics.AdmissionAttribution

Exact Shapley attribution over the discrete admission-check lattice
(dissertation Ch5, Art. 13, Definition 5.2). Enumerates all 2^n coalitions;
deterministic, no sampling. Bounded by `@max_checks 20`; check names must be
unique.

Public functions:

- `shapley(term, [{term, (term -> :pass | {:refuse, atom})}]) ::
  %{optional(term) => float} | {:error, :COALITION_LIMIT}`

Refusal atom: `COALITION_LIMIT` (checks > 20). Corpus: Art. 13 lines
`13.1`-`13.3` (transparency / provision of information to deployers).
Source: `lib/xaas/semantics/admission_attribution.ex`.

## Xaas.Semantics.Counterfactual

Deterministic counterfactual evaluation over recorded admission decisions
(Art. 86 / Theorem 7.1): the outcome is in `{0,1}`, never a distribution,
because the pipeline is deterministic and the record carries the full ordered
per-check verdict log.

Public functions:

- `evaluate(decision_record(), x_prime, [check()]) ::
  {:ok, result()} | {:error, {:record_outcome_mismatch, term()}}`
- `run(term(), [check()]) ::
  %{outcome: :admitted | {:refused, atom()}, checks: [recorded_check()]}`

Typed refusal (error tuple, not atom):
`{:record_outcome_mismatch, detail}` — replaying the recorded input does not
reproduce the recorded decision, so no counterfactual claim is admitted.
Corpus: Art. 86 lines `86.1`-`86.3`. Source:
`lib/xaas/semantics/counterfactual.ex`.

## Xaas.Semantics.AutomationBiasCountermeasure

Art. 14.4.b automation-bias countermeasure: emits the operator briefing
(causal anatomy) for EVERY decision, including full admits. Pure composition
of `AdmissionAttribution` (W505) + `Counterfactual` (W506). Deterministic:
same record + attributions => byte-identical briefing.

Public functions:

- `briefing(decision_record(), attributions()) ::
  {:ok, briefing()} | {:error, {:record_outcome_mismatch, term()}}`

Typed error tuple: `{:record_outcome_mismatch, term()}` (inherited from the
`Counterfactual` record check). Corpus: Art. 14 line `14.4.b`. Source:
`lib/xaas/semantics/automation_bias_countermeasure.ex`.

## Xaas.Semantics.RobustMargin

Art. 15 adversarial-robustness gate (Theorem 5.3):
`Margin(x) = h(E(x)) - L_h * L_E * epsilon >= 0`. The Lipschitz constant is
EMPIRICAL (lower bound on true L), so the certificate is CONDITIONAL — stated
in the module doc. `epsilon` is a call argument (zero-config).

Public functions:

- `estimate_lipschitz((term() -> number()), [{x1, x2}]) ::
  float() | {:error, :REFUSED_NO_CALIBRATION_DATA}`
- `admit(margin, l_h, l_e, epsilon) ::
  :ADMITTED | {:error, :REFUSED_ROBUST_MARGIN}
  | {:error, :REFUSED_NO_CALIBRATION_DATA}
  | {:error, :REFUSED_ARITHMETIC_OVERFLOW}
  | {:error, :REFUSED_MALFORMED_MARGIN_INPUT}`

Corpus: Art. 15 lines `15.1`-`15.3`. Source:
`lib/xaas/semantics/robust_margin.ex`.

## Xaas.Semantics.DeclaredMetrics

Art. 15(3) declared-metrics surface. Declares the fleet's real
accuracy/robustness metrics as structured data, values READ from the cited
receipt files at call time; each metric carries its source receipt path
(evidence pointer, not assertion). Fails closed on missing or unparseable
sources.

Public functions:

- `declare() :: {:ok, map()} | {:error, :REFUSED_METRICS_SOURCE_MISSING}`

Refusal atom: `REFUSED_METRICS_SOURCE_MISSING`. Cited sources:
`docs/sjira/v26.10.6/plans/w316-tokened-full-suite.md`,
`w385-conformance-court.md`, `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`,
mutation receipts `w320`, `w382`, `w414`. Corpus: Art. 15 line `15.3`.
Source: `lib/xaas/semantics/declared_metrics.ex`.

## Xaas.Semantics.VulnerabilityLifecycle

Art. 15(5) vulnerability detect/respond/resolve lifecycle: pure forward-only
state machine `DETECTED -> TRIAGED -> RESPONDED -> RESOLVED` with typed
evidence per edge. Deterministic; wired into no live route.

Public functions:

- `states() :: [state(), ...]`
- `new(%{detector:, finding:}) :: {:ok, t()} | {:error, :REFUSED_NO_DETECTION_RECORD}`
- `triage(t(), %{analysis:}) :: {:ok, t()} | {:error, refusal()}`
- `respond(t(), %{receipt:}) :: {:ok, t()} | {:error, refusal()}`
- `resolve(t(), %{green:, run:}) :: {:ok, t()} | {:error, refusal()}`

Refusal atoms: `REFUSED_NO_DETECTION_RECORD`,
`REFUSED_LIFECYCLE_SKIP` (any non-next-edge transition: skips, repeats,
backward moves), `REFUSED_LIFECYCLE_EVIDENCE` (legal-order transition without
required typed evidence). Corpus: Art. 15 line `15.5`. Source:
`lib/xaas/semantics/vulnerability_lifecycle.ex`.

## Xaas.Semantics.IncidentReport

Art. 73 serious-incident reporting builder over the witnessed receipt corpus.
Classification is DERIVED from receipt evidence, never asserted
(`:INFRINGES_UNION_LAW` / `:HARM_TO_RIGHTS` / `:MALFUNCTION`). Transmission
channel to a market-surveillance authority is typed OPEN: `transmit/1` returns
`{:ok, %{status: :PREPARED_NOT_TRANSMITTED, ...}}` — prepared, never silently
"sent". Semantics surface only; never actuates.

Public functions:

- `build([receipt()], keyword()) :: {:ok, report()} | {:error, :REFUSED_NO_INCIDENT_EVIDENCE}`
- `transmit(report() | map()) :: {:ok, %{status: :PREPARED_NOT_TRANSMITTED, ...}}`

Refusal atom: `REFUSED_NO_INCIDENT_EVIDENCE` (empty/nil receipt list).
Corpus: Art. 73 lines `73.1`-`73.5`. Source:
`lib/xaas/semantics/incident_report.ex`.

## Xaas.Semantics.AuthorityChannel

Typed reporting-channel registry for the Art. 73 family. The largest OPEN_GAP
family (corpus 3.49 / 73.x / 27.1.f): no external authority endpoint exists,
so the authority channel is typed `:OPEN` with basis
`"corpus 73.4-73.5 — no authority endpoint exists"`; internal channels
(receipt corpus, CRO paths) are `:EVIDENCED`. `transmit/2` never opens
sockets — it returns the prepared envelope plus any operator-supplied
endpoint; the calling lane owns the transport decision.

Public functions:

- `registry([channel()]) :: [channel()]` — deterministic, sorted by id
- `with_endpoint(atom(), map(), [channel()]) ::
  {:ok, [channel()]} | {:error, :REFUSED_UNKNOWN_CHANNEL}`
- `transmit(report_input(), channel() | atom(), [channel()]) ::
  {:ok, map()} | {:error, refusal()}`

Refusal atoms: `REFUSED_UNKNOWN_CHANNEL`, `REFUSED_NO_INCIDENT_EVIDENCE`.
Corpus: `3.49` family, `73.4`-`73.5`, `27.1.f`. Source:
`lib/xaas/semantics/authority_channel.ex`.

## Xaas.Semantics.OversightGovernance

Typed governance surfaces for Art. 26.6 (log retention), Art. 26.7 (worker
notification), Art. 27 (FRIA), Art. 4 (AI literacy) over the fleet's real
machinery. Zero-config; governance description surface, never actuates.

Public functions:

- `cited_paths() :: [String.t(), ...]`
- `retention_policy() :: {:ok, map()}` — Art. 26.6: `actuation_receipts:
  :permanent_durable_rows`, `ephemeral_artifacts: :lane_lease_cleanup`
- `worker_notification() :: {:ok, map()}` — Art. 26.7: receipt corpus +
  OCEL event stream ARE the notification record; the 3.49 family is typed
  `{:OPEN_GAP, details}` inside the payload
- `ai_literacy() :: {:ok, map()}` — Art. 4 measures with evidence paths
- `fria_schedule() :: {:ok, map()}` — `period: "per-wave"`, trigger
  `"corpus drift falsifier"`
- `fria_oversight_description() :: {:ok, map()}` — Art. 27.1.e description
  + controls
- `fria() :: {:ok, %{assessment_class: :deployer, rights: [map(), ...]}}` —
  Art. 27, per-right typed `:EVIDENCED`/`:OPEN_GAP` status with evidence
  citations
- `fria() :: {:ok, %{assessment_class: :deployer, rights: [map(), ...]}}` —
  Art. 27, per-right evidence citations

Corpus: `4.1`, `26.6`, `26.7`, `27.1`-`27.5`. Source:
`lib/xaas/semantics/oversight_governance.ex`.

## Xaas.Semantics.AiroRiskMapping

AIRo (AI Risk Ontology, `https://w3id.org/airo`) risk-vocabulary mapping over
the refusal ledger: one `airo:RiskSource` + `airo:Hazard` per ledger refusal
variant, one `airo:RiskControl` per enforcing module with
`airo:detectsRiskConcept` / `airo:mitigatesRiskConcept` edges, the
`airo:AISystem` + `airo:AIDeployer` nodes. All functions are pure and
deterministic.

Public functions:

- `ledger_path() :: String.t()` — the refusal ledger JCS file path
- `load_ledger() :: map()`
- `variants() :: [map()]`
- `risk_controls() :: [map()]`
- `risk_concept_for(String.t()) :: String.t()` — refusal-family to AIRo
  risk-concept mapping
- `risk_graph() :: String.t()` — full deterministic AIRo risk graph (Turtle)

AIRo concept mapping for the refusal atoms
(`lib/xaas/semantics/airo_risk_mapping.ex:23-30`):

| refusal atom | AIRo risk concept |
|---|---|
| `REFUSED_EUAIA_MANIPULATIVE` | `RISK_TO_INFORMED_CHOICE` |
| `REFUSED_EUAIA_VULNERABILITY_EXPLOIT` | `RISK_TO_VULNERABLE_PERSONS` |
| `REFUSED_EUAIA_SOCIAL_SCORING` | `CROSS_CONTEXT_RISK` |
| `REFUSED_EUAIA_PREDICTIVE_POLICING` | `DUE_PROCESS_RISK` |
| `REFUSED_EUAIA_FACIAL_SCRAPING` | `PRIVACY_RISK` |
| `REFUSED_EUAIA_EMOTION_RECOGNITION` | `MENTAL_PRIVACY_RISK` |
| `REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` | `DISCRIMINATION_RISK` |
| `REFUSED_EUAIA_REALTIME_RBI` | `SURVEILLANCE_RISK` |

Source: `lib/xaas/semantics/airo_risk_mapping.ex`.

## Xaas.Semantics.Jcs

JCS (RFC 8785) canonical JSON encoding wrapper over the `jcs` hex package.

Public functions:

- `encode(term()) :: String.t()` — delegates to `Jcs.encode/1`

Source: `lib/xaas/semantics/jcs.ex`.

## Computation artifact modules (`computation.ex`)

Runtime-neutral identity for computations that may participate in SA2A. An
artifact describes how to invoke a capability; it does not grant standing,
authority, or permission to cross the actuation boundary. Contract details:
`docs/claude/diataxis/reference/sa2a-computation-boundary.md`.

Four modules in `lib/xaas/semantics/computation.ex`:

- `ComputationArtifact.new(map()) :: {:ok, t()} | {:error, term()}`,
  `ComputationArtifact.hash(t()) :: String.t()` — runtimes:
  `ONNX NX AXON PYTORCH SCIKIT_LEARN LLM RULE SPARQL FOND HDDL NATIVE WASM
  HUMAN`
- `ComputationHash.hash(term()) :: String.t()`
- `ComputationClaim.new(map()) :: {:ok, t()} | {:error, term()}`,
  `ComputationClaim.hash(t()) :: String.t()`
- `PlanningAdvice.new(map()) :: {:ok, t()} | {:error, term()}`,
  `PlanningAdvice.order_formal(t(), [String.t()]) ::
  {:ok, [String.t()]} | {:error, term()}`,
  `PlanningAdvice.hash(t()) :: String.t()`
- `RuntimeEquivalence.qualify(reference, candidate, tolerance \\ 1.0e-6) ::
  {:ok, map()} | {:error, :invalid_runtime_equivalence_input}`

## Registry / R2RML / VKG

Semantic projection and virtual-knowledge-graph surfaces (not
EU-AI-Act-specific; listed for inventory completeness).

- `Xaas.Semantics.Registry` (`registry.ex`): `namespaces/0`,
  `projection(module)`, `admit(module) :: {:ok, map()} | {:error, term()}`,
  `hash(map)`, `public_iri?(iri)`
- `Xaas.Semantics.R2RML` (`r2rml.ex`): `mapping(module)`, `bundle(module)`,
  `render(module)`, `explore_sparql(query, opts)`, `observe_sparql(query, opts)`,
  `hash(resource_or_bundle)`, `audit([module]) ::
  %{admitted: [map()], refused: [map()]}`
- `Xaas.Semantics.VKG` (`vkg.ex`): `observe(query_or_attrs, opts)`,
  `observe_all(opts)`, `engineering(witness)`, `graphql(witness, opts)`,
  `catalog(opts)`, `catalog_snapshot(opts)`, `encode_witness!(witness)`,
  `verify(witness)`

### Xaas.Semantics.VKG.Query (`vkg/query.ex`)

Admission object for a read-only VKG request. Source/mapping identities stay
owned by the AshR2RML catalog; callers cannot override them. Enforces
`authority: :NONE` — a query carrying any other authority is refused.

Public functions:

- `new(map()) :: {:ok, t()} | {:error, Refusal.t()}`
- `admit(t()) :: {:ok, t()} | {:error, Refusal.t()}`
- `digest(t()) :: String.t()` — SHA-256 over the full query identity
- `with_contracts(t(), [String.t()]) :: {:ok, t()} | {:error, Refusal.t()}`

Admitted purposes (closed set): `:engineering_read`, `:failure_analysis`,
`:semantic_jira`, `:process_intelligence`, `:knowledge_lookup`. Refusal atom:
`REFUSED_XAAS_VKG_QUERY` (id/contract_ids/purpose/bounds/merge/capability/
authority violations). Source: `lib/xaas/semantics/vkg/query.ex:50-114`.

### Xaas.Semantics.VKG.Witness (`vkg/witness.ex`)

Evidence envelope around one canonical AshR2RML VKG session: records the
exact query admission identity and federation receipt. Standing is fixed
`:observed_not_actuated`, authority `:NONE`.

Public functions:

- `from_session(Query.t(), AshR2RML.VKG.Session.t()) ::
  {:ok, t()} | {:error, Refusal.t()}`
- `verify(t()) :: :ok | {:error, Refusal.t()}` — re-checks every cached
  SHA against the session and that authority is still `:NONE`
- `summary(t()) :: map()`

Refusal atom: `REFUSED_XAAS_VKG_WITNESS` (contract mismatch, session receipt
carrying authority, field/session drift). Source:
`lib/xaas/semantics/vkg/witness.ex:44-101`.

### Xaas.Semantics.VKG.Replay (`vkg/replay.ex`)

Replay boundary for witnesses and workspaces. Semantic result verification
delegates to AshR2RML; the XaaS envelope is verified separately; nothing is
promoted to source authority.

Public functions:

- `witness(Witness.t()) :: {:ok, map()} | {:error, Refusal.t()}`
- `workspace(Workspace.t()) :: {:ok, map()} | {:error, Refusal.t()}`
- `serialized_witness(Witness.t()) :: {:ok, map()} | {:error, Refusal.t()}`
  — fails unless the canonical JSON round-trip preserves `result.sha256`

Refusal atom: `REFUSED_XAAS_VKG_REPLAY`. Source:
`lib/xaas/semantics/vkg/replay.ex:14-96`.

### Xaas.Semantics.VKG.Workspace (`vkg/workspace.ex`)

Immutable read model composing multiple witnesses. Preserves all source
receipts; refuses duplicate query identities; rows lacking a `_vkg` subject
get a deterministic synthetic `urn:xaas:vkg:row:<sha>` subject.

Public functions:

- `build(String.t(), [Witness.t()]) :: {:ok, t()} | {:error, Refusal.t()}`
- `subjects(t()) :: [String.t()]`
- `fetch(t(), String.t()) :: {:ok, [map()]} | {:error, Refusal.t()}`
- `provenance(t(), String.t()) :: {:ok, [map()]} | {:error, Refusal.t()}`
- `witness_index(t()) :: map()`
- `verify(t()) :: :ok | {:error, Refusal.t()}` — digest recomputation +
  authority `:NONE`

Refusal atom: `REFUSED_XAAS_VKG_WORKSPACE` (bad input, duplicate query ids,
unknown subject, digest/authority drift). Source:
`lib/xaas/semantics/vkg/workspace.ex:17-86`.

## Cross-module refusal-atom index (closed set)

Atoms prefixed `REFUSED_EUAIA_*` are the eight Art. 5(1) atoms plus
`REFUSED_EUAIA_MALFORMED_CANDIDATE`. Remaining atoms in the layer:

| atom | module |
|---|---|
| `COALITION_LIMIT` | AdmissionAttribution |
| `REFUSED_EMPTY_DATASET` | DatasetAdmission |
| `REFUSED_INCOMPLETE_DATASET` | DatasetAdmission |
| `REFUSED_BIAS_THRESHOLD` | DatasetAdmission |
| `REFUSED_ARITHMETIC_OVERFLOW` | DatasetAdmission, RobustMargin |
| `REFUSED_NO_CALIBRATION_DATA` | RobustMargin |
| `REFUSED_ROBUST_MARGIN` | RobustMargin |
| `REFUSED_MALFORMED_MARGIN_INPUT` | RobustMargin |
| `REFUSED_METRICS_SOURCE_MISSING` | DeclaredMetrics |
| `REFUSED_NO_DETECTION_RECORD` | VulnerabilityLifecycle |
| `REFUSED_LIFECYCLE_SKIP` | VulnerabilityLifecycle |
| `REFUSED_LIFECYCLE_EVIDENCE` | VulnerabilityLifecycle |
| `REFUSED_NO_INCIDENT_EVIDENCE` | IncidentReport, AuthorityChannel |
| `REFUSED_UNKNOWN_CHANNEL` | AuthorityChannel |
| `REFUSED_EUAIA_MALFORMED_CANDIDATE` | EuAiActAdmission |
| `REFUSED_XAAS_VKG_QUERY` | VKG.Query |
| `REFUSED_XAAS_VKG_WITNESS` | VKG.Witness |
| `REFUSED_XAAS_VKG_REPLAY` | VKG.Replay |
| `REFUSED_XAAS_VKG_WORKSPACE` | VKG.Workspace |

## Module census (W864, 2026-10-07)

Snapshot of `ls lib/xaas/semantics/` at 2026-10-07, HEAD `a0723bf6`
(branch `feat/playwright-surface`): 17 top-level `.ex` files + the `vkg/`
subdirectory (4 modules). `computation.ex` defines 5 modules, so the total
is 25 modules across 18 files. Per-module sections above are the authority.

| file | module(s) | purpose |
|---|---|---|
| `admission_attribution.ex` | AdmissionAttribution | exact Shapley attribution over the admission-check lattice |
| `airo_risk_mapping.ex` | AiroRiskMapping | AIRo risk-vocabulary mapping over the refusal ledger (Turtle graph) |
| `authority_channel.ex` | AuthorityChannel | typed Art. 73 reporting-channel registry; transmit prepares, never sends |
| `automation_bias_countermeasure.ex` | AutomationBiasCountermeasure | Art. 14.4.b operator briefing for every decision |
| `computation.ex` | ComputationArtifact, ComputationHash, ComputationClaim, PlanningAdvice, RuntimeEquivalence | runtime-neutral SA2A computation identity/boundary (5 modules) |
| `counterfactual.ex` | Counterfactual | deterministic counterfactual replay of recorded admission decisions |
| `dataset_admission.ex` | DatasetAdmission | Art. 10 dataset gate: completeness + sliced-W1 bias proxy |
| `declared_metrics.ex` | DeclaredMetrics | Art. 15(3) declared metrics read from cited receipt files |
| `eu_ai_act_admission.ex` | EuAiActAdmission | Art. 5(1)(a)-(h) prohibited-practice structural admission |
| `incident_report.ex` | IncidentReport | Art. 73 serious-incident report builder over receipt evidence |
| `jcs.ex` | Jcs | RFC 8785 canonical JSON wrapper |
| `oversight_governance.ex` | OversightGovernance | Art. 26.6/26.7/27/4 governance description surfaces |
| `r2rml.ex` | R2RML | R2RML semantic projection bundle surface |
| `registry.ex` | Registry | namespace/projection registry + admission + hashing |
| `robust_margin.ex` | RobustMargin | Art. 15 conditional adversarial-robustness certificate |
| `vkg.ex` | VKG | top-level VKG observe/engineering/graphql/catalog surface |
| `vulnerability_lifecycle.ex` | VulnerabilityLifecycle | Art. 15(5) forward-only vulnerability state machine |
| `vkg/query.ex` | VKG.Query | admitted read-only VKG query object, authority `:NONE` |
| `vkg/witness.ex` | VKG.Witness | evidence envelope around one canonical VKG session |
| `vkg/replay.ex` | VKG.Replay | replay verification of witnesses/workspaces |
| `vkg/workspace.ex` | VKG.Workspace | immutable multi-witness read model |

Non-atom typed errors: `{:record_outcome_mismatch, term()}` (Counterfactual,
AutomationBiasCountermeasure), `:OPEN_GAP` (OversightGovernance),
`:invalid_runtime_equivalence_input` (RuntimeEquivalence).

## Transport provenance headers (OS-16, IN FLIGHT — w605)

EU AI Act Art. 50(2) machine-generated disclosure at the transport layer.
`XaasWeb.Plugs.ProvOriginHeader` (`lib/xaas_web/plugs/prov_origin_header.ex`)
sets one machine-detectable `x-prov-o` response header whose values are
constant, config-driven application identity (`Application.get_env(:xaas,
:prov_origin, [])` keys `:agent_iri` / `:operator_iri`), never fabricated
per-request. Wired to the `/a2a` and `/api` scopes only — LiveView/`:browser`
is deliberately unwired (a human-facing page would carry a false
"machine-generated" assertion). Standing UNKNOWN: court + mutation runs
pending at record time. Receipt:
`docs/sjira/v26.10.7/plans/w605-prov-o-plug.md`.

## PEP seam: agentgateway filter spec + prompt-injection harness (WP-3, IN FLIGHT)

Fail-closed policy-enforcement-point seam between the agentgateway and the
eyerun_wasi gate (EU AI Act Art. 14/15 enforcement discipline):

- Filter spec (w613, PARTIAL_ALIVE, spec-only — no local agentgateway
  checkout, Rust skeleton deferred):
  `docs/sjira/v26.10.7/agentgateway/pep-eyerun-filter-spec.md`. UDS NDJSON
  transport to a `serve`-mode eyerun_wasi daemon, 15 ms watchdog
  (12+2+1 ms decomposition), mandatory authority lease
  (`REFUSED_LEASE_ABSENT`; fail-open structurally inexpressible), and five
  falsifier fault-injection cases (§5) owned by W614.
- Fuzz harness (w614, PARTIAL_ALIVE): `tests/goose_mutation_harness.py`
  + `tests/w614_stub_agent.py` over a real localhost HTTP socket; 10-case
  corpus, gate log `docs/sjira/v26.10.7/plans/w614-gate-log.json` shows
  10/10 `all_ok: true` (interception rate 1.0 on non-conforming
  candidates, `upstream_bytes: 0` on every refusal). Goose itself is
  GOOSE-ABSENT; the agent leg is pluggable via `AGENT_CMD`. Daemon-dependent
  §5 cases (timeout/crash/malformed) NOT RUN — daemon-absent.

Both are IN FLIGHT items, not landed capability.

## Corpus deepening courts (Landed 2026-10-07)

Dedicated corpus deepening suites in `test/eu_ai_act/` binding the
`lib/xaas/semantics/` surfaces (and their witness/actuation/telemetry
collaborators) to specific Regulation (EU) 2024/1689 lines. Each suite binds
the statute to the repo's REAL typed behavior (Chicago: real executions, no
mocks). Receipts: `docs/sjira/v26.10.6/plans/w984{fc,ev,ew,ey,fa,fb,ec}-probe.md`.

| suite | articles / lines | real repo seam (code-verified) | receipt |
|---|---|---|---|
| `art9x_risk_management_deepening_test.exs` (7 courts) | 9.1, 9.2.a–d, 9.5, 9.8 | `Xaas.Semantics.AiroRiskMapping.risk_graph/0` byte-deterministic AIRo graph over the live refusal ledger; every ledger variant as `airo:RiskSource`/`airo:Hazard` node with `ex:xaas-system airo:hasRisk` edges | `w984fc-probe.md` |
| `art10_2e_art26_4_dataset_purpose_deepening_test.exs` | 10.2.e, 26.4 | `Xaas.Semantics.DatasetAdmission.admit/2` gate order (empty → completeness → sliced-W1 bias proxy), intended-purpose binding | `w984ec-probe.md` |
| `art11_1_art12x_audit_chain_deepening_test.exs` (4 courts) | 11.1, 12.1, 12.2.a–c | `Xaas.Witness.AuditChain` deterministic hash-chain (independent head recompute `SHA256(JCS(R_last) <> H_{t-1})`, exact mid-chain tamper attribution, intact-prefix survival); `Xaas.Telemetry.OcelNdjson.validate_ndjson_file/1` driving the real `Xaas.Ultracode.Ocel.Validator` court over a real ndjson file | `w984ev-probe.md` |
| `art13x_counterfactual_deepening_test.exs` (8 courts, 4 lines) | 13.3.b.iv, 13.3.f (+ 13.x) | `Xaas.Semantics.Counterfactual` + `Xaas.Semantics.AdmissionAttribution.shapley/2` cross-surface agreement; Shapley spreading -1 over ALL failing checks; `RobustMargin` composition | `w984ew-probe.md` |
| `art14x_oversight_deepening_test.exs` (3 courts, 6 lines) | 14.1, 14.2, 14.3/14.3.a–b | `Xaas.Actuation.QuiescentStop` real Ash kernel over sandboxed Postgres (named human authority → real stop DO on `Xaas.Marketplace.Provider`, subject `:suspended`, typed receipt); `RobustMargin.admit/4` binding at the exact measured margin==penalty boundary; `OversightGovernance` surfaces | `w984ey-probe.md` |
| `art15x_robustness_deepening_test.exs` (8 courts) | 15.1, 15.4, 15.5/15.5.s2 | `Xaas.Semantics.RobustMargin` (empirical Lipschitz, conditional certificate); `Xaas.Semantics.GraphlawWasm.judge_imports/2` hard WASI allowlist (signature, not name, judging); `AuditChain` shared-subject identity | `w984fa-probe.md` |
| `art26x_postmarket_deepening_test.exs` (3 courts) | 26.12 (×73) | whole-corpus tamper evidence + independent replay + recorded-head pin (last-link limitation is the binding); `Xaas.Semantics.EuAiActAdmission.admit/1` refused payload witnessed into a real AuditChain; `Xaas.Semantics.IncidentReport.build/2` classifying exactly `[:INFRINGES_UNION_LAW]` from chain-member digest | `w984fb-probe.md` |

All receipts recorded real pass runs of each suite (plus a full
`mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`
census at 1388 passed / 1 excluded, exit 0, as of the W984ev/W984fb runs).

## See Also

- [`reference/actuation-and-semantics.md`](actuation-and-semantics.md) —
  actuation, receipts, refusal contracts
- [`reference/sa2a-computation-boundary.md`](sa2a-computation-boundary.md) —
  computation artifact boundary
- [`reference/ex4pm-ontology-pin.md`](ex4pm-ontology-pin.md) — ontology pin
- `docs/eu_ai_act/corpus.json` — corpus line-id authority
- `docs/eu_ai_act/corpus-README.md` — corpus schema and provenance
