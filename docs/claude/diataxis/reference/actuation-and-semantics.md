# Reference: Actuation and Semantic Projection

This page defines the current contract implemented by `Xaas.Semantics.Registry`, `Xaas.Actuation`, `Xaas.Marketplace.Provider`, and the Ash-native intent/receipt resources.

## Public-ontology projection

`Xaas.Semantics.Registry` admits public namespaces including RDF/RDFS/OWL/XSD, PROV-O, DCTERMS, DCAT, SKOS, ODRL, W3C ORG, SOSA, Schema.org, and FOAF. An application-local `xaas.local` namespace is not sufficient semantic standing.

For each `Xaas.Resource`, `projection/1` records the resource name, public classes, attribute predicates, relationship predicates, and vocabulary IRIs. `admit/1` refuses the projection when any semantic IRI is outside the admitted public namespaces. `hash/1` deterministically hashes the canonical projection with SHA-256.

A semantic projection is descriptive identity only. It does not grant mutation or execution authority.

## Consequential actuation API

```elixir
Xaas.Actuation.run(resource, action, input, opts)
```

Required:

- `resource` — Ash resource module.
- `action` — action atom.
- `input` — action input map.
- `opts[:idempotency_key]` — non-empty string. Missing/empty keys return `{:error, :idempotency_key_required}`.

Optional context includes `:subject_id`, `:actor`, `:tenant`, `:authorize?`, and `:authority`.

The admitted path is:

```text
public ontology projection
  -> admission
  -> durable intent / prepared receipt
  -> synchronous Ash.Reactor DO
  -> sealed receipt
  -> deterministic replay
```

The Reactor executes synchronously (`async?: false`) within `Ash.DataLayer.transaction/4` over the target resource plus the intent/receipt resources. Reactor failure/halt rolls the transaction back.

## Provider lifecycle contract

`Xaas.Marketplace.Provider` supports public descriptive CRUD with these boundaries:

- `:create` accepts `name`, `slug`, `description`, and `org_id`; status starts from its default `:pending` value.
- public `:update` accepts only `name` and `description`.
- `:status` values are `:pending | :active | :suspended`.
- internal `:actuate_status` accepts `status`, is `public? false`, has no JSON:API route, and requires `Xaas.Actuation.Validations.ReactorContext`.
- `authorize?: false` alone does not manufacture Reactor context and cannot bypass the lifecycle fence.

## Receipt and replay semantics

A successful first actuation returns an envelope with `status: :succeeded`, `replay?: false`, and a sealed receipt. The receipt binds the ontology projection hash plus consequence/input/result evidence.

Reusing the same idempotency key for the same admitted consequence returns the prior receipt with `status: :replayed` and does not repeat the mutation or create an extra receipt.

Reusing the key for a different consequence returns:

```elixir
{:error, {:idempotency_conflict, key}}
```

This exact tuple is guaranteed regardless of whether the underlying mutation runs
through the direct Ash transaction path or through Ash.Reactor: `Xaas.Actuation`'s
`normalize_transaction_result/1` unwraps a single-step `Reactor.Error.Invalid` /
`Reactor.Error.Invalid.RunStepError` envelope wrapping `{:idempotency_conflict, key}`
back to the raw tuple above before returning it to the caller. Any other Reactor
failure shape is returned unchanged as `{:error, {:reactor_failed, reason}}`. Fixed
2026-09-04 (`d08699e`, PR #38) after the Reactor transaction path introduced in
commit `771cb4f` started wrapping this error and broke the contract above; see
`test/xaas/actuation_test.exs:96`.

Two further contract points, both added with the SA2A execute edge (2026-09-21):

- `{:idempotency_not_replayable, key, status}` (the key already ended `:failed` or
  `:refused`) is unwrapped from the Reactor envelope exactly like `:idempotency_conflict`.
- An action may refuse its own DO by returning a `Xaas.Actuation.Refusal` error
  (`Xaas.Actuation.Refusal.new(code, detail)`). `Xaas.Actuation.Kernel.seal/2` then seals the
  intent and receipt `:refused` (a status both ledger resources already declared) with
  `error: %{"refused" => code, "detail" => ...}`, instead of the generic `:failed`.
  `run/4` still returns `{:error, error}`; `Refusal.find/1` extracts the typed refusal.

## SA2A `sa2a_execute`: autonomic DO under a machine policy

`Xaas.Sa2a.Bridge.execute/2` is the generated edge catalog's only `do_boundary?: true`
edge (`s2b:edge40`, `port_op: "sa2a_execute"`). It is autonomic -- no human approves a
call -- but only through `Xaas.Actuation.run/4`, never by calling the bridge directly.

| Piece | Module | Role |
| --- | --- | --- |
| Entry point | `Xaas.Sa2a.Executor.execute/2`, `mix xaas.sa2a.execute <request.json \| ->` | pre-flight, key, `Actuation.run/4`, typed result |
| Machine court | `Xaas.Sa2a.Court` + `Xaas.Sa2a.ExecutionPolicy` | all admission conditions, by recomputation against the real port |
| Actuated resource | `Xaas.Sa2a.Execution` (`sa2a_executions`), private create action `:execute` | `ReactorContext` fence, `:sa2a_executor` policy, durable record |
| DO body | `Xaas.Sa2a.Changes.Execute` | court re-run, port DO, LLM-avoidance floor, replay |
| Capability | `Xaas.SystemAuthority` service `:sa2a_executor` | mapped to `{Xaas.Sa2a.Execution, :execute}` in `Xaas.Checks.SystemActor` |

Authority is granted only when ALL of these hold (`Xaas.Sa2a.Court.admit/2`; otherwise a
typed `{:error, {:refused, code, detail}}`, never a crash, and no ledger row):

1. the query matches a declared class of `config :xaas, Xaas.Sa2a.ExecutionPolicy`
   (`:exact | :prefix | :regex`, optional `bind_work_order`, `max_query_bytes`); an empty
   policy admits nothing. Shipped class: `sjira-workorder-resolution` (prefix `workorder:`,
   query must name the work order);
2. a prior `sa2a_admit` receipt exists for the same candidate and work-order digest
   (`standing` in `admitted_standings`, assertion names both) AND is reproducible:
   re-running the real `sa2a_admit` on the receipt's inputs yields the same `candidate_hash`;
3. a plan hash from `sa2a_plan` is bound AND reproducible: re-running the real `sa2a_plan`
   on the plan's candidates yields that hash and an `ADMITTED` allocation for the work
   order (`PRUNED` does not cover it);
4. idempotency key `= sha256(work_order_digest|query|plan_hash)`; the action re-checks that
   the actuation ledger key is exactly this value, so a direct `Actuation.run/4` with any
   other key is refused (`:idempotency_key_not_bound`).

Post-conditions (inside the DO): the port result must carry `llm_avoidance_ratio >=
min_llm_avoidance_ratio` (default `1.0`: an LLM-fallback result is `:llm_fallback_refused`);
a replayable manifest (`xaas.sa2a.execution.v1`: query, compiled rules, result, ratio, plan
hash, admit candidate hash, key) is hashed with `Xaas.Sa2a.Canonical` (Python-identical
canonical JSON) and `Bridge.replay(manifest, hash)` runs automatically. A mismatch
(`:replay_mismatch`) refuses: the intent/receipt are sealed `:refused` and no `Execution`
row is written. A caller may pin `expected_manifest_hash` to demand an identical
re-execution of a recorded run.

Denials and outcomes:

| Situation | Result |
| --- | --- |
| any service other than `:sa2a_executor`, or a non-system actor | `{:error, %Ash.Error.Forbidden{}}` (pre-flight: no rows; also enforced in-action) |
| court refusal (allowlist, receipt, plan) | `{:error, {:refused, code, detail}}`, no rows |
| post-condition refusal (LLM floor, replay mismatch, non-canonical manifest) | `{:error, {:refused, code, detail}}`, intent + receipt `:refused`, no `Execution` row |
| port absent / autofde not on PATH | `{:error, {:blocked, why}}` (environment, not policy) |
| same key, same input, already succeeded | `{:ok, %{status: :replayed}}`, no re-execution |
| same key, different input | `{:error, {:idempotency_conflict, key}}` |
| same key after `:failed`/`:refused` | `{:error, {:idempotency_not_replayable, key, status}}` (terminal; a new plan hash is a new key) |

`Xaas.Sa2a.Changes.Execute` runs as a `before_transaction` hook, after policy
authorization and before the insert. It must not be `before_action`: `Actuation.run/4`
already holds the Postgres transaction, and an error inside the action's joined
transaction would roll the OUTER transaction back and destroy the `:refused` receipt.

The resource has no HTTP/GraphQL/RPC surface. The only caller of `Bridge.execute/2` in
`lib/` is the `:execute` change (asserted by `test/xaas/sa2a/execute_test.exs`).
Worker use: `export PATH=$HOME/autofde-lab/.venv/bin:$PATH; mix xaas.sa2a.execute req.json`
(exit 0 for `succeeded`/`replayed`; non-zero with a JSON `status` of `refused`, `blocked`,
`forbidden` or `error`).

## Sibling bridge: Ferroplan (pinned FOND/HTN planner WASM)

`Xaas.Bridges.Ferroplan` is digest-verified access to the pinned `ferroplan-wasm`
artifact (wasm32-wasip1, `fp_alloc`/`fp_call`/`fp_dealloc` JSON ABI) at the canonical
path `../ferroplan/crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` in the ferroplan
sibling checkout. The registry lists it as a `:bridge` with standing `UNKNOWN`
(`Xaas.Bridges.Registry`).

- Digest pin: sha256 `088d9c3b0306e36123ddc1ee780ad7e9d4bd2ebb54f9726c43f40a2f6d718233`
  (pin court, W45). The artifact is read from its canonical path and hashed before
  anything else happens; a missing, unreadable, or mutated artifact is the same
  fail-closed typed refusal `:ferroplan_artifact_digest_mismatch` — never a degraded
  pass. `verify_bytes/1` is the exact gate.
- Runtime seam: wasmex is reachable transitively (via `ash_graphlaw`), not declared in
  xaas `mix.exs`. When no wasm runtime is loadable, the bridge stays digest-verified and
  metadata-only, and every invoke returns the typed refusal
  `:ferroplan_runtime_unavailable`. Other typed refusals: `:ferroplan_engine_compile_failed`
  (pinned bytes did not compile) and `:ferroplan_abi_failure` (fp ABI transaction error).
- Invoke path: the module is compiled once per verified digest (cached in
  `:persistent_term`); each invoke instantiates a fresh WASI store + instance, speaks the
  fp JSON ABI (request in, packed `(out_ptr << 32) | out_len` out, response freed via
  `fp_dealloc`), 30s call timeout, WASI store limits (512 MiB memory).
- Authority: bridges never authorize. `authority_ceiling` is `:none`, standing stays
  `"UNKNOWN"` until a receipt from observed execution backs it. Entry points:
  `metadata/0` (digest-verified metadata, no invocation), `validate/1` (the registry's
  own `fond_validate` example as a smoke call), `invoke/1` (arbitrary op), each returning
  a `Xaas.Bridges` envelope with `engine_sha256` provenance and an `evidence_ref`.

## Graphlaw bridge admission gate (`Xaas.Graphlaw.LimitGate`)

`Xaas.Bridges.Graphlaw.assess/2` gates caller-controlled claim structure against the
graphlaw engine's recorded `EngineLimit` rows BEFORE any engine dispatch
(`lib/xaas/graphlaw/limit_gate.ex`; W976 design-wave 5, SPEC-10 / W731-GAP-2 —
`docs/sjira/v26.10.6/plans/w976-design-wave5.md`):

- `LimitGate.enforce/2` reads `Catalog.limits_by_scope/1` and refuses the first measured
  exceedance with a typed `{:refused, info}` (`code: :limit_exceeded`) carrying the row's
  `refusal_name`, the limit value, and the actual. Equal-to-limit admits.
- Wire 1: `assess/2` measures the claim's real JSON nesting depth
  (`LimitGate.json_depth/1`) against the `abi`-scope `max_json_depth` (engine truth 64,
  `src/abi.rs`). A depth-65 claim refuses at the seam with the engine's `refusal_name`,
  `class: :refused_admission`, `broken_term: :mu_on_O` — the engine is never reached.
- Wire 2: `Xaas.Bridges.Registry.engine_limits/0` surfaces the real `abi`-scope rows —
  the first registry function to read an `EngineLimit` row.
- Byte-limit wires (lane W981k, `docs/sjira/v26.10.6/plans/w981k-registry-limits-seams.md`):
  `do_assess/3` renders facts/data/steps, then `gate_engine_limits/3` measures three
  rendered payloads and runs `LimitGate.enforce/2` on each before any engine dispatch —
  the first exceedance wins, all-`:ok` admits:
  - `max_request_bytes` (`abi` scope, engine truth 16 MiB, `src/abi.rs`) — `byte_size`
    of the JSON request (data + steps) rendered for `AshGraphLaw.law/3`.
  - `n3_max_term_bytes` (`n3` scope, engine truth 64 KiB, `src/law.rs`) — the largest
    single N-Triples line (terms) in the rendered facts.
  - `n3_max_total_bytes` (`n3` scope, engine truth 256 MiB, `src/law.rs`) — total bytes
    of the facts fed to the n3 step.
  Each refusal maps through the same typed envelope as the depth gate
  (`:limit_exceeded`, `class: :refused_admission`, `broken_term: :mu_on_O`, the engine's
  `refusal_name` carried verbatim).
- Fail-open semantic (disclosed design decision, NOT fail-closed): a limit read that
  *errors*, or a row that is absent, admits (`limit_gate.ex` moduledoc). Rationale: the
  gate is deliberately DB-independent at this seam — the `Xaas.Chicago.Bridges.GraphlawTest`
  dead-host court pins that its verdict is never a database verdict (`:host_not_started`
  is the host layer, not the gate), so an unreadable limit store is a monitored gap,
  not a refusal condition. A live exceedance still refuses. W981k court-pinned the same
  semantic at the new byte seams (row-absent ⇒ pass-through to the engine).
- Registry disposition: of the 15 graphlaw registry limits (15 scope+meta rows in
  `/Users/sac/graphlaw/registry/capability-registry.json`), exactly 4 are enforced with
  a true consumption seam — `max_json_depth` (W976) plus the 3 byte limits (W981k); the
  remaining 11 (plan/hooks/wasm/policy scopes) have no xaas consumer that produces their
  quantities. They stay recorded and gateable via `enforce/2`, unmeasured by design —
  no artificial plumb-through. Disclosed remaining gap: `Registry.engine_limits/0`
  still surfaces `abi`-scope rows only, not the `n3` scope.
- Court: `test/xaas/graphlaw_limit_gate_test.exs` (13 Chicago tests — real Postgres rows,
  real `Catalog.ingest/1`, real bridge calls; the W976 falsifier is verbatim: depth-65
  refuses typed, equal/below admits, and reverting the `assess/2` wiring flips the court
  red) plus `test/xaas/graphlaw_limit_seams_test.exs` (9 W981k Chicago tests — one
  exceedance + one within-limit court per byte limit, row-absent fail-open, wrong-scope
  isolation; deleting `gate_engine_limits/3` flips all three exceedance courts red).
  W981k's first wiring run was 48/51 — the courts caught a real first-defect
  (`gate_engine_limits/3` returned the first `:ok` instead of the first refusal). Standing:
  PARTIAL_ALIVE — 4 of 15 limits measured at true seams, 11 unmeasured-no-consumer.

## Gymact surface adapter (external DO, fail-closed config)

`Xaas.Operations.GymactSurface` is a thin, fail-closed HTTP adapter over gymact's FastAPI
surface:

```elixir
config :xaas, :gymact_surface, base_url: "http://127.0.0.1:8000"
```

with the bearer token from `token:` in the same config list or the `INTERNAL_API_TOKEN`
environment variable (same bearer posture as `XaasWeb.Plugs.RequireInternalApiToken`).
Every function is gated on that configuration BEFORE any HTTP call or ledger transition:
unconfigured is the typed refusal `{:error, %Xaas.Actuation.Refusal{code:
:gymact_not_configured}}`, never a best-effort default or string scraping.

- Reads go straight to gymact: `health/0` (`GET /health`), `providers/0` (`GET
  /providers`), `prepare_candidate/1` (`POST /candidates`), `open_episode/1` (`POST
  /episodes`), `capabilities/1`, `verify/2`. `submit_action/2` is the canonical gymact DO
  port (`POST /episodes/:id/actions/selected`); the payload is an opaque
  court-manufactured gymact cut — the adapter never recomputes or forges cut digests and
  never mints authority.
- Consequential DO (`actuate/4`) never runs as a bare proxy: it runs the external
  three-commit protocol — `Xaas.Actuation.prepare_external` (durable intent + prepared
  receipt) -> gymact HTTP DO -> `Xaas.Actuation.seal_external` (durable outer seal) —
  with a caller-supplied stable idempotency key (missing key →
  `:idempotency_key_required`) and explicit authority evidence. `Xaas.Actuation.run/4`
  itself is deliberately not used for the remote DO: external consequences cannot
  lawfully pretend a Postgres rollback can undo a remote side effect. Local Ash
  consequences keyed to a gymact subject route through `actuate_local/4`, a gated
  `Xaas.Actuation.run/4` passthrough. `:actuate_status` is not touched by this module.
- Transport: `Req`, bearer auth header, no retry, 15s receive timeout; non-2xx returns
  `{:error, {:gymact_http_error, status, body}}`, transport failure
  `{:error, {:gymact_transport_error, exception}}`.

## AshA2A v1 protocol surface (`/a2a/v1`)

The `/a2a` scope in `XaasWeb.Router` mounts `AshA2A.Protocol.Plug` additively at
`/a2a/v1` (registered before the hex `A2A.Plug` `/` catch-all so the catch-all cannot
shadow it), serving `XaasWeb.A2A.NextReadAshAgent` — an `AshA2A.Protocol.Agent` adapter
over the SAME real skill surface as the legacy hex agent (`NextReadUserAgent` dispatch;
generated card skills from `NextReadUserAgentSkills`). Surface: agent card at
`GET /a2a/v1/.well-known/agent-card.json`, JSON-RPC at `POST /a2a/v1`, SSE at
`POST /a2a/v1` `message/stream`. `base_url` honors `A2A_BASE_URL` (default
`http://localhost:4000/a2a/v1`).

Auth is gate-ordering: the scope's `:require_internal_api_token` stays the single auth
floor (401s unauthenticated requests upstream of every plug path including SSE;
`INTERNAL_API_TOKEN` absent config fails closed), and `AshA2A.Protocol.Plug.Auth` is
deliberately left unconfigured on the mount — Auth is opt-in middleware, and a second
auth stack would produce two different 401 shapes. The plug forwards
`context.metadata["a2a.auth"] = nil`; the agent does its own explicit `as:<user_id>`
persona-grant resolution inside message handling. (Pinned ash_a2a
`86214551de93fc8ab395f5ed0b84d32922a5d99b`, v26.10.4.)

## Executable falsifiers

`test/xaas/actuation_test.exs` exercises real Ash resources, real Reactor, and sandboxed Postgres. It asserts:

1. provider semantic IRIs are admitted public IRIs and the projection hash is stable;
2. a direct `:actuate_status` update is refused outside Reactor context;
3. `Xaas.Actuation.run/4` performs the consequential mutation and seals a receipt;
4. replay does not repeat the mutation or create another receipt;
5. conflicting idempotency-key reuse is refused.

`test/xaas/sa2a/execute_test.exs` (real Postgres sandbox + the real `autofde beam-bridge`
subprocess; a named ExUnit skip when `autofde` is not on PATH) asserts the SA2A execute
edge: admitted execute + automatic replay + intent/receipt rows; replayed key does not
re-execute; every other capability is `Forbidden`; no/forged/mismatched admit receipt,
tampered or non-covering plan hash, unknown query, LLM fallback, and a tampered replay hash
are typed refusals (the last two seal `:refused` with no `Execution` row);
`test/xaas/sa2a/execution_policy_test.exs` pins the policy and the Python-identical hash.

These tests are the repository-native qualification surface for the contract above. Documentation alone does not confer ALIVE standing.

## Admission binding modes

How a descriptor's `graph_digest` relates to its admission snapshot is declared by the trusted caller, never selected by the descriptor (`Xaas.Ultracode.SemanticWork.AdmissionBinding`). The default — no `:binding` option — is verify-when-present: a carried snapshot is verified when present, and an anchor-less descriptor is admitted with the graph digest unbound. Explicit `:snapshot` forces the graph digest to bind to a carried admission anchor; `:graph` is the explicit opt-out for a producer whose `graph_digest` is a graph-wide digest. There is deliberately no content-selected mode: `:auto` is refused as an option (`{:invalid_binding_option, :auto}`) — a guard the descriptor could switch off by deleting its own snapshot is not a guard.

`Xaas.Ultracode.SemanticWork.materialize/2` pins `:snapshot` itself (it admits with `binding: :snapshot` unless the caller declared a mode), so the materialize boundary is strict: the descriptor's graph digest must bind to its admission anchors.

## EU-AI-Act semantics layer (v26.10.6)

A typed, structural admission and evidence layer over the EU AI Act's prohibited
practices (Art. 5(1)(a)-(h)) and Article-risk vocabulary. It sits beside — never
inside — the actuation DO path: it admits, refuses, and produces evidence
artifacts, but grants no authority and performs no DO. The only mutation-authority
path remains `Xaas.Actuation.run/4` (and its external seal protocol, above).

### Admission boundary: `Xaas.Semantics.EuAiActAdmission`

`admit/1` renders the eight Art. 5(1) partitions as *unrepresentable inputs* —
structural disjointness checks over the declared intent schema, never content
inspection (no free text, model output, or user data is ever read):

| Art. 5(1) | refusal atom | structural invariant |
| --- | --- | --- |
| (a) manipulative/subliminal/deceptive | `:REFUSED_EUAIA_MANIPULATIVE` | technique class in `[:manipulate_behavior, :deceptive, :subliminal]` (`eu_ai_act_admission.ex:141`) |
| (a) vulnerability exploit | `:REFUSED_EUAIA_VULNERABILITY_EXPLOIT` | technique in `[:exploit_vulnerability, :target_vulnerable_audience]` (`eu_ai_act_admission.ex:147`) |
| (b) social scoring | `:REFUSED_EUAIA_SOCIAL_SCORING` | `:social_behavior` domain joined to `:unrelated_context_join` (`eu_ai_act_admission.ex:153`) |
| (c) predictive policing | `:REFUSED_EUAIA_PREDICTIVE_POLICING` | `:predict_offending` purpose + `:individualized_profile_join` (`eu_ai_act_admission.ex:160`) |
| (d) untargeted facial scraping | `:REFUSED_EUAIA_FACIAL_SCRAPING` | `:facial_images` domain with provenance ≠ `:consented` (`eu_ai_act_admission.ex:165`) |
| (e) emotion recognition | `:REFUSED_EUAIA_EMOTION_RECOGNITION` | `:affective` domain in `:workplace`/`:education` setting (`eu_ai_act_admission.ex:170`) |
| (f) biometric categorization | `:REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` | biometric surface with non-empty `:inferences` or non-`:boolean` match tokens (`eu_ai_act_admission.ex:175`) |
| (g)/(h) realtime RBI | `:REFUSED_EUAIA_REALTIME_RBI` | `:public_space` + `:biometric_identification` + `:realtime` latency (`eu_ai_act_admission.ex:180`) |

The refusal set is closed: the eight atoms above (declared at
`eu_ai_act_admission.ex:33`) plus `:REFUSED_EUAIA_MALFORMED_CANDIDATE` for a
non-map candidate (`eu_ai_act_admission.ex:116`). Checks run in article order and the first
violated invariant wins (`eu_ai_act_admission.ex:106`). `describe/1` maps each atom
to its Art. 5(1) partition string. `List.wrap`-based totality guards (W630) make
improper lists opaque leaves rather than crashes (`eu_ai_act_admission.ex:196`).

### Runtime intake gate: `XaasWeb.Plugs.EuAiActAdmissionPlug` (W521)

The admission is wired at the `/a2a` JSON-RPC intake, not the router: an endpoint
plug (`XaasWeb.Endpoint` immediately after `Plug.Parsers`) keyed on
`%{method: "POST", path_info: ["a2a" | _]}` runs `admit/1` over the decoded JSON-RPC
`params` BEFORE agent dispatch. Normalization atomizes ONLY the nine declared
schema fields via `String.to_existing_atom/1` — the prohibited-practice vocabulary
is precompiled into the admission module's beam, no new atom is minted, and unknown
keys/free text are never atomized or inspected (`eu_ai_act_admission_plug.ex:19-29`).
A refusal is a JSON-RPC 2.0 error envelope (HTTP 200, code -32600) with the typed
refusal atom in `error.data` plus the `describe/1` article string
(`eu_ai_act_admission_plug.ex:56-66`, `:155`). GETs (agent card), SSE, and all
non-`/a2a` paths pass untouched; `:require_internal_api_token` stays the single
auth floor and the plug grants no authority — it only refuses.

### Position relative to the actuation DO path

The semantics modules (`lib/xaas/semantics/*.ex`) are admission/observation
surfaces: they produce typed verdicts, risk graphs, incident reports, margin and
governance evidence — none of them actuates, and none of them is granted any
authority ceiling. Consequential DO remains exclusively behind `Xaas.Actuation.run/4`
and the Ash.Reactor intent/receipt path documented above. A refusal from this layer
halts the request at the intake plug; it can never mint authority or route into the
actuation ledger.

### AIRo mapping (vendored ontology + deterministic graph)

- Vendored AIRo ontology: `priv/semantic/airo/airo.ttl`, sha256-pinned by
  `test/xaas/semantics/airo_vendored_pin_test.exs` (existence, digest, and
  key-class/property presence — drift fails the pin test, not a degraded pass).
- `Xaas.Semantics.AiroRiskMapping` renders a deterministic AIRo Turtle risk graph:
  one `airo:RiskSource` + `airo:Hazard` per ledger refusal variant, one
  `airo:RiskControl` per enforcing module with `airo:detectsRiskConcept` /
  `airo:mitigatesRiskConcept` edges, the `airo:AISystem` / `airo:AIDeployer` nodes
  and `airo:hasRisk` edges (`airo_risk_mapping.ex:1-15`, graph body `:218-298`).
  `Xaas.Semantics.EuAiActAdmission` is registered as an enforcing module in the
  mapping (`airo_risk_mapping.ex:79`), and the euaia refusal strings seed
  `Xaas.Semantics.IncidentReport` (`incident_report.ex:38`).
- Fleet wiring ledger: `docs/cro/artifacts/airo-wiring-ledger.md` is the consolidated
  cross-repo AIRo wiring ledger (16 wave rows, W639). Extended 2026-10-07 to 25 repos by
  two survey waves: W981e added ash_graphlaw, ggen-ecosystem, chatman-ecosystem
  (`docs/sjira/v26.10.6/plans/w981e-airo-wiring-extension.md`) and W981f added
  ash_atlassian, ash_dspy, ash_kudzu, ash_planning_center, ash_expo, ash_autofde
  (`docs/sjira/v26.10.6/plans/w981f-airo-wiring-wave2.md`). Every added row is standing
  UNKNOWN: real `git rev-parse HEAD` per repo, on-disk `find -iname '*airo*'` returned
  zero matches (absence confirmed, nothing invented), and each row names its pin court
  falsifier. Per-repo reference stubs live at `docs/airo/<repo>/airo-reference.md`.

### Export endpoint: `GET /internal-api/eu-ai-act/pack` (OS-14)

`XaasWeb.EuAiActExportController` (router mount `router.ex:98`, inside the
`/internal-api` scope with the `:require_internal_api_token` floor) serves the SAME
pack as `mix xaas.eu_ai_act_pack` via that task's public `Mix.Tasks.Xaas.EuAiActPack.build/1`
(`lib/mix/tasks/xaas.eu_ai_act_pack.ex:141`). The build is fail-closed: missing
cited evidence path, missing coverage map, or empty typed-gaps extraction returns
`{:refused, reason}` → HTTP 503 with `schema: "xaas.eu_ai_act_pack_refusal/v1"`
(`eu_ai_act_export_controller.ex:18-33`). The pack never claims a gap closed; the
typed-gaps section is carried verbatim from the map. Artifacts are generated on
request, not persisted.

See also `docs/claude/diataxis/reference/eu-ai-act-semantics.md` for the
article-level semantics; this section records the admission/DO boundary.

### Witness verification-key semantics (key rotation)

- Two distinct key materials under the same algorithm (ES256) register distinct
  `kid`s; the catalog carries all of them.
- Each receipt carries the `verifying_key_hex` actually ingested;
  `record_verification` standing binds to that key — verifying a v1-key receipt
  leaves the v2-key receipt `verified == false`.
- An unknown algorithm is a typed skip
  (`{0, "DILITHIUM2", :algorithm_not_in_admitted_enum}` in `:skipped`), never a
  silent drop and never a row; no `:ingest_refused` error is raised.

Courted in `test/xaas/witness/catalog_durability_test.exs` (`:eu_ai_act` tag);
receipt: `docs/sjira/v26.10.6/plans/w709-witness-durability.md`.

## Digest forms (producer contract)

WHICH fields the snapshot digests cover is a property of the producer version, so it is an explicit, versioned part of the contract: a descriptor carrying `admitted_work_order` MUST declare `digest_form`. XaaS computes and checks exactly the declared form; it is never inferred from the snapshot's shape, and an undeclared form is refused (`:digest_form_undeclared`), not defaulted.

- `"sjira-digest/2"` (current) — the admitted snapshot EMBEDS `definition_digest`; the snapshot digest drops it with the other digest fields; the definition digest is taken over the CLOSED field whitelist (`Map.take`). The embedded digest must equal the recomputed one, else `{:admitted_definition_stale, recomputed}`.
- `"sjira-digest/1"` (historical, pre ggen_igniter `33c8e86`) — no embedded `definition_digest`; the definition digest is the snapshot minus `standing`, `dimensions` and the digest fields. Kept verifiable only for committed historical artifacts that declare it.

A snapshot whose shape is not its declared form's (an embedded `definition_digest` under `/1`, none or a malformed one under `/2`) is refused as `{:digest_form_mismatch, form, :definition_digest}` before any digest is recomputed; an unknown form is `{:unknown_digest_form, value}`. Source of truth: the `Xaas.Ultracode.SemanticWork.AdmissionBinding` moduledoc.
