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
