# Explaining 

## Summary

 is a crate with 4 modules and 673 public items on its code surface.

## Verified snippet

<!-- Snippet slot: code facts only, copied from the code surface. -->

```rust
// Xaas.Billing.FiboRevenueProfile :: admit_source
admit_source/1
```

## Commentary

<!-- AGENT-COMMENTARY-BEGIN Xaas.Billing.FiboRevenueProfile admits a revenue source only through `admit_source`:
a `named_sources` key or a canonical FIBO IRI (`fibo_iri?`, inside `fibo_namespace`),
never a `non_revenue_sources` key (`non_revenue?`); admissions anchor on `cash_flow_iri`
and pin `fibo_revision`. Xaas.Ultracode.SbbRealization admits an SBB by recomputing
`abb_digest`, `contract_digest`, `qualification_digest`, then `realize` is the bounded
CONSTRUCT; `substitute` defers to SubstitutionCourt; `to_ocel`, `receipt_intact?` audit it.
Xaas.Ultracode.SemanticDrive `drive` runs the no-LLM loop (`no_llm_guard`, `graph_side`,
`graph_toolchain`) conserving the tuple across five `hops` (`request_digest`,
`verify_hops`, `anchor`, `conserve`; `request_fields`, `llm_variables`,
`no_llm_environment`). Xaas.Zoe.EventSimulation `simulate` dispatches on `contract_version`
between timeline and snapshot (`contract`) surfaces, staying OBSERVE/SELECT/CONSTRUCT
without DO; `digest` seals a simulation receipt; `simulation_error` carries the refusals.
Xaas.CaseStudies.WdFa.CapabilitySelector `for_case` returns capability IDENTIFIERS only
(filtered to the common WD set), reading `presentation_state` — it executes nothing and
grants no authority. Xaas.SelfDigest.Promotion `promote` is the sealed pipeline:
`Shadow.materialize`, `Admission.evaluate`, `Receipt.seal`, `Replay.verify`; any hop
failure returns `refused` (no partial promotion). Xaas.Runtime.FOND.Backoff `delay`
computes capped exponential delay (base 25ms, cap 5000ms); Xaas.Runtime.ProviderFabric.Backoff
carries `base_ms`/`cap_ms` in a struct and `delay` applies the same cap law; the
Xaas.Ultracode.ProviderMesh primitives divide the same labor: `Backoff` `delay`
(base 100ms, cap 30_000ms, attempt-1 shifted), `RetryPolicy` struct `max_attempts` with
`retry?` admitting only `transient` classes under the cap, `PrioritySelector` `select`
ordering by `priority` then `id`, and `Selector` `for_capability` filtering through
`Capability.supported?` before `PrioritySelector`. NotificationExtension.Resource.Persist
is a Spark DSL transformer: `transform` normalizes the `notification` entities and
persists them as `notification_extension_compiled` — a compile-time projection, no
runtime authority.
AGENT-COMMENTARY-END -->
