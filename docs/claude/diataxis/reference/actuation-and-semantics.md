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

## Executable falsifiers

`test/xaas/actuation_test.exs` exercises real Ash resources, real Reactor, and sandboxed Postgres. It asserts:

1. provider semantic IRIs are admitted public IRIs and the projection hash is stable;
2. a direct `:actuate_status` update is refused outside Reactor context;
3. `Xaas.Actuation.run/4` performs the consequential mutation and seals a receipt;
4. replay does not repeat the mutation or create another receipt;
5. conflicting idempotency-key reuse is refused.

These tests are the repository-native qualification surface for the contract above. Documentation alone does not confer ALIVE standing.

## Admission binding modes

How a descriptor's `graph_digest` relates to its admission snapshot is declared by the trusted caller, never selected by the descriptor (`Xaas.Ultracode.SemanticWork.AdmissionBinding`). The default — no `:binding` option — is verify-when-present: a carried snapshot is verified when present, and an anchor-less descriptor is admitted with the graph digest unbound. Explicit `:snapshot` forces the graph digest to bind to a carried admission anchor; `:graph` is the explicit opt-out for a producer whose `graph_digest` is a graph-wide digest. There is deliberately no content-selected mode: `:auto` is refused as an option (`{:invalid_binding_option, :auto}`) — a guard the descriptor could switch off by deleting its own snapshot is not a guard.

`Xaas.Ultracode.SemanticWork.materialize/2` pins `:snapshot` itself (it admits with `binding: :snapshot` unless the caller declared a mode), so the materialize boundary is strict: the descriptor's graph digest must bind to its admission anchors.

## Digest forms (producer contract)

WHICH fields the snapshot digests cover is a property of the producer version, so it is an explicit, versioned part of the contract: a descriptor carrying `admitted_work_order` MUST declare `digest_form`. XaaS computes and checks exactly the declared form; it is never inferred from the snapshot's shape, and an undeclared form is refused (`:digest_form_undeclared`), not defaulted.

- `"sjira-digest/2"` (current) — the admitted snapshot EMBEDS `definition_digest`; the snapshot digest drops it with the other digest fields; the definition digest is taken over the CLOSED field whitelist (`Map.take`). The embedded digest must equal the recomputed one, else `{:admitted_definition_stale, recomputed}`.
- `"sjira-digest/1"` (historical, pre ggen_igniter `33c8e86`) — no embedded `definition_digest`; the definition digest is the snapshot minus `standing`, `dimensions` and the digest fields. Kept verifiable only for committed historical artifacts that declare it.

A snapshot whose shape is not its declared form's (an embedded `definition_digest` under `/1`, none or a malformed one under `/2`) is refused as `{:digest_form_mismatch, form, :definition_digest}` before any digest is recomputed; an unknown form is `{:unknown_digest_form, value}`. Source of truth: the `Xaas.Ultracode.SemanticWork.AdmissionBinding` moduledoc.
