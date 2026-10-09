# How to: Using 

## Prerequisites


- Xaas.Billing.FiboRevenueProfile::account_maintenance_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::administration_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::admit_source (function)

- Xaas.Billing.FiboRevenueProfile::advertising_income (str_key)

- Xaas.Billing.FiboRevenueProfile::advisory_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::agency_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::annual_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::annuity_charge (str_key)

- Xaas.Billing.FiboRevenueProfile::api_usage_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::arrangement_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::atm_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::bid_ask_spread (str_key)

- Xaas.Billing.FiboRevenueProfile::brokerage_commission (str_key)

- Xaas.Billing.FiboRevenueProfile::carried_interest (str_key)

- Xaas.Billing.FiboRevenueProfile::cash_flow_iri (function)

- Xaas.Billing.FiboRevenueProfile::certification_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::commitment_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::commodity_sale (str_key)

- Xaas.Billing.FiboRevenueProfile::compute_usage_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::consulting_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::content_license (str_key)

- Xaas.Billing.FiboRevenueProfile::content_subscription (str_key)

- Xaas.Billing.FiboRevenueProfile::coupon_income (str_key)

- Xaas.Billing.FiboRevenueProfile::custody_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::data_license_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::data_subscription (str_key)

- Xaas.Billing.FiboRevenueProfile::discount_accretion (str_key)

- Xaas.Billing.FiboRevenueProfile::distribution_margin (str_key)

- Xaas.Billing.FiboRevenueProfile::dividend_income (str_key)

- Xaas.Billing.FiboRevenueProfile::energy_sale (str_key)

- Xaas.Billing.FiboRevenueProfile::exit_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::family (str_key)

- Xaas.Billing.FiboRevenueProfile::family (str_key)

- Xaas.Billing.FiboRevenueProfile::family (str_key)

- Xaas.Billing.FiboRevenueProfile::fibo_iri? (function)

- Xaas.Billing.FiboRevenueProfile::fibo_namespace (function)

- Xaas.Billing.FiboRevenueProfile::fibo_revision (function)

- Xaas.Billing.FiboRevenueProfile::food_service_revenue (str_key)

- Xaas.Billing.FiboRevenueProfile::foreign_exchange_fee (str_key)

- Xaas.Billing.FiboRevenueProfile::franchise_fee (str_key)


## Steps


1. Use `admit_source` from `Xaas.Billing.FiboRevenueProfile`.

2. Use `cash_flow_iri` from `Xaas.Billing.FiboRevenueProfile`.

3. Use `fibo_iri?` from `Xaas.Billing.FiboRevenueProfile`.

4. Use `fibo_namespace` from `Xaas.Billing.FiboRevenueProfile`.

5. Use `fibo_revision` from `Xaas.Billing.FiboRevenueProfile`.

6. Use `named_sources` from `Xaas.Billing.FiboRevenueProfile`.

7. Use `non_revenue?` from `Xaas.Billing.FiboRevenueProfile`.

8. Use `non_revenue_sources` from `Xaas.Billing.FiboRevenueProfile`.

9. Use `account_maintenance_fee` from `Xaas.Billing.FiboRevenueProfile`.

10. Use `administration_fee` from `Xaas.Billing.FiboRevenueProfile`.

11. Use `advertising_income` from `Xaas.Billing.FiboRevenueProfile`.

12. Use `advisory_fee` from `Xaas.Billing.FiboRevenueProfile`.


## Verified snippet

<!-- The snippet slot carries code copied from the extracted code surface -->
<!-- (doc:Claim rows whose doc:attribute is "snippet"), never agent prose. -->

```rust
// Xaas.Billing.FiboRevenueProfile :: admit_source
admit_source/1
```

<!-- AGENT-COMMENTARY-BEGIN -->
Prerequisites note: the str_key rows are the exact map keys the admission surfaces read.
Admit through `admit_source` (Xaas.Billing.FiboRevenueProfile) with a `named_sources`
key or a `fibo_iri?` IRI; `non_revenue?` refuses `non_revenue_sources` keys. For
Xaas.Ultracode.SbbRealization, `admit` first (digests must recompute), then `realize`;
`substitute` only between admitted SBBs; `to_ocel`, `receipt_intact?` audit. For
Xaas.Ultracode.SemanticDrive, `drive` runs the loop; `verify_hops` and `anchor`
replay the digest law over recorded `hops`; `no_llm_guard` fails closed. For
Xaas.Zoe.EventSimulation, `simulate` dispatches on `contract_version`; `contract`
describes the snapshot surface; `digest` seals the simulation.

Remaining surface modules, same discipline. Xaas.CaseStudies.WdFa.CapabilitySelector:
call `for_case` with the case id (and `experience_admitted?` when applicable); it returns
capability identifiers from `presentation_state` — treat the return as a selection, not
an execution. Xaas.SelfDigest.Promotion: `promote` with (work, shadow, evidence,
reducer); it returns the materialized result plus a sealed receipt, or `refused` — never
retry a `refused` promotion with the same evidence. Xaas.Runtime.FOND.Backoff:
`delay` with the attempt number (base 25ms, cap 5000ms). Xaas.Runtime.ProviderFabric.Backoff:
build the struct (`base_ms`, `cap_ms`) and call `delay` with the attempt. Provider mesh:
`Xaas.Ultracode.ProviderMesh.Selector` `for_capability` filters by
`Capability.supported?` then `PrioritySelector` `select` orders by `priority`/`id`;
`RetryPolicy` `retry?` requires the failure class to be `transient` and the attempt
below `max_attempts`; `Backoff` `delay` spaces attempts (base 100ms, cap 30_000ms).
NotificationExtension.Resource.Persist runs at compile time via `transform`, persisting
`notification_extension_compiled` — no runtime call path.
<!-- AGENT-COMMENTARY-END -->
