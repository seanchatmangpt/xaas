# Explanation: Public Ontology + Reactor Control Plane

XaaS now separates semantic identity from consequential authority.

`Xaas.Semantics.Registry` answers **what an Ash resource projects to** in public semantic terms. It maps resources, attributes, and relationships onto published vocabularies and computes a deterministic projection hash. That projection is reversible metadata: it preserves the Ash names needed for exact replay while refusing application-private semantic standing.

`Xaas.Actuation` answers **how an admitted consequence is performed**. Consequential state does not inherit authority merely because a semantic graph describes it. The control plane therefore separates projection, admission, intent, execution, receipt, and replay.

```text
Ash resource
  -> public-ontology projection
  -> admission
  -> durable intent + prepared receipt
  -> synchronous Ash.Reactor DO
  -> sealed receipt
  -> replay
```

## Why Reactor is the DO boundary

Provider lifecycle state is a useful concrete example. Provider descriptive metadata may use ordinary Ash create/update actions, but lifecycle status is consequential. The public update action cannot accept status, and the internal `:actuate_status` action requires Reactor-manufactured context.

This creates two distinct properties:

1. **No ambient actuation** — possessing a resource module or disabling policy authorization does not manufacture the context required for consequential mutation.
2. **No unreceipted commit** — Reactor executes synchronously inside the Ash data-layer transaction that also contains the intent/receipt resources. Failure or halt rolls back the transaction.

## Why receipts bind the ontology projection

The actuation receipt stores the semantic projection hash. That means the evidence for a consequence is bound not just to an action name and input but also to the semantic model used to admit that resource at the time of execution.

This preserves a correspondence between the public semantic projection and the executable Ash operation without giving the projection itself execution authority.

## Idempotency as a consequence identity

The required idempotency key is not merely a retry convenience. It names an admitted consequence. Repeating the same consequence with the same key resolves to replay; attempting to reuse the key for a different consequence is refused.

That prevents a successful prior authorization/receipt identity from being silently repurposed for a different mutation.

## Boundaries

- Public ontology identity is not authorization.
- Ontop/R2RML/read projections are not DO paths.
- Generated client/API surfaces do not make internal actions public.
- `authorize?: false` is not Reactor authority.
- Sensitive ledger/auth resources remain separate exposure decisions.

## Evidence model

The repository's Chicago-style actuation test uses real Ash resources, real Reactor, and sandboxed Postgres to falsify direct bypass, receipt omission, replay duplication, and idempotency conflicts. These executable falsifiers outrank prose descriptions of intended architecture.
