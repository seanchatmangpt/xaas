# Ontology-first Ash resources and Reactor actuation

## Status

This document describes the control-plane architecture introduced in v26.8.22.
It is an explanation of the executable invariants in the codebase, not a second
source of truth.

## The inversion

XAAS does not define a private business ontology and then publish selected
fields from it. Public ontologies supply semantic identity; Ash supplies the
executable application projection.

Every resource that uses `Xaas.Resource` exposes a reversible projection through
`ontology_projection/0` and a deterministic semantic identity through
`ontology_projection_hash/0`. `Xaas.Semantics.Registry` admits only classes and
predicates in public namespaces such as PROV-O, DCTERMS, DCAT, SKOS, ODRL,
W3C ORG, SOSA, FOAF, RDF/RDFS/OWL/XSD, and Schema.org.

A resource without a defensible narrower class is conservatively projected as a
`prov:Entity`. That is deliberate. The system preserves the exact Ash resource,
attribute, type, relationship, and join identity alongside the public semantic
projection rather than inventing stronger ontology claims than the application
can prove.

## Instance identity is not ontology identity

Concrete XAAS records may use XAAS-owned identifiers such as
`urn:xaas:resource:provider:...`. Those identifiers name instances. They do not
define classes or predicates and do not become an application-private ontology.

The Ontop R2RML projection follows the same boundary: subject templates use XAAS
instance URNs while `rr:class` and `rr:predicate` values come from public
vocabularies. Ontop is read interoperability only. It has no Ash actor, policy,
authority, or Reactor receipt and therefore has no DO authority.

## SELECT, CONSTRUCT, DO

The control plane separates reversible construction from consequential
actuation.

- **SELECT** chooses an admitted resource, action, subject, input, actor, tenant,
  idempotency key, and authority evidence.
- **CONSTRUCT** manufactures the public-ontology projection, semantic hash,
  input fingerprint, `ActuationIntent`, and prepared `ActuationReceipt`.
- **DO** is performed only by `Xaas.Actuation.Reactor` after those objects exist.

Ordinary Ash reads and descriptive CRUD remain Ash operations. An action is
consequential when its resource explicitly fences it with
`Xaas.Actuation.Validations.ReactorContext`. Such an action cannot be invoked
merely by passing `authorize?: false`; the action also requires an admitted
Reactor context containing the intent ID, prepared receipt ID, and exact semantic
projection hash.

This makes the authority relationship structural:

    public ontology projection
      -> semantic admission
      -> authority admission
      -> ActuationIntent
      -> prepared ActuationReceipt
      -> Ash.Reactor ash_step DO
      -> sealed receipt
      -> replay standing

## Ash.Reactor is the exclusive DO fabric

`Xaas.Actuation.Reactor` uses the `Ash.Reactor` extension and synchronous
`ash_step` stages for admission, execution, and receipt sealing. The public
entry point is `Xaas.Actuation.run/4`.

The participating resource plus `ActuationIntent` and `ActuationReceipt` are
wrapped in one Ash data-layer transaction. Reactor infrastructure failure or
halt triggers `Ash.DataLayer.rollback/2`. A successful target mutation therefore
cannot commit while its receipt construction fails later.

A domain-level target action failure is different: no successful consequence has
standing, so the Reactor seals a failed receipt and commits that evidence. This
preserves failure observability without manufacturing a false successful receipt.

## Authority

There are two authority modes.

When normal Ash authorization is enabled, the supplied actor and tenant pass
through the target resource's Ash policies. When a trusted internal workflow
must delegate with `authorize?: false`, the Reactor admission step requires a
non-empty authority evidence map. `authorize?: false` is therefore not treated
as authority by itself.

Maker-checker approval is the first migrated consequential path. Approving a
provider status change no longer mutates the provider directly from an
`Ash.Resource.Change`. The hook supplies approval authority evidence and calls
`Xaas.Actuation.run/4`; Reactor performs the actual provider lifecycle
transition.

## Receipts and deterministic replay

Every admitted intent binds:

- idempotency key
- resource module and action
- subject identity
- public ontology class
- complete ontology projection hash
- canonical input hash
- actor and tenant references
- authority evidence
- canonical input snapshot

Before DO, Reactor creates a prepared receipt. On success it seals the receipt
with the result snapshot, result hash, and completion time. On target failure it
seals the error instead.

Reusing an idempotency key with the exact same subject, action, input, and
semantic projection replays the original successful receipt without repeating
the mutation. Reusing the key for a different consequence is refused as an
idempotency conflict.

## Public projections remain projections

R2RML, SPARQL, generated APIs, TypeScript bindings, future ggen artifacts, and
other serialization surfaces are projections of the canonical Ash/public-
ontology correspondence. They do not acquire execution authority from their
ability to describe an action or resource.

The rule is intentionally asymmetric:

**description can manufacture an intent; only the Reactor path can manufacture a
consequence with standing.**

## Qualification

`test/xaas/semantics/registry_test.exs` enumerates every resource in every Ash
domain configured under `:kanban, :ash_domains`. It fails if any configured
resource lacks the `Xaas.Resource` projection contract, emits a non-public
semantic IRI, or produces a non-deterministic projection hash.

`test/xaas/actuation_test.exs` exercises the real Ash resources, real Reactor,
and real sandboxed Postgres data layer. It proves that a fenced target action
refuses direct invocation, Reactor performs the consequence, the receipt binds
the semantic projection, and replay does not repeat the mutation.

The repository CI remains the executable qualification surface for environments
without a local BEAM toolchain: compile with warnings as errors, real tests,
format, Dialyzer, and unused dependency checks must all pass on the exact head.

## Falsifiers

This architecture is falsified by any observed case in which one of the
following is true:

1. a configured Ash resource has no admitted public-ontology projection;
2. a class or predicate emitted as semantic vocabulary belongs only to an XAAS
   private namespace;
3. a fenced consequential Ash action succeeds without a Reactor-manufactured
   intent/receipt context;
4. a successful consequential mutation commits without a sealed receipt;
5. the same idempotency key can manufacture two different consequences;
6. replay repeats a previously successful mutation rather than returning its
   existing receipt;
7. a read projection such as Ontop can directly actuate the system.

Any such observation is a failed invariant, not a documentation discrepancy.
