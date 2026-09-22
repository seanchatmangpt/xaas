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
