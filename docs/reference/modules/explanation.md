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
AGENT-COMMENTARY-END -->
