# Self-digest kernel and the Capital Census

Reference for `lib/xaas/ultracode/capital_census/` — the subsystem that makes
Ultracode a work subject of itself: the fabric digests its own telemetry,
classifies its recurring residual gaps, and manufactures work orders against
itself under the same provenance laws as any other work.

Landed as GC-26926-CENSUS (`a9e3fa04`), GC-26927-SELFDIGEST (`4a2e9d11`),
and the merge-day preserve (`0a4e1a0a`); the state shapes are migration
`20260927203551_add_capital_census_self_digest` (`experience_clusters`,
`gaps`, `resolutions`, `work_orders`, `episodes`) inside the existing
`Xaas.Ultracode` domain — no new domain, no new repo. Work orders are the
new work-subject surface.

## Modules

- `Xaas.Ultracode.CapitalCensus.SelfDigest.Run` — telemetry ingest
  (GC-26927-SELFDIGEST closure #3): reads the wave loop's NDJSON telemetry
  and maps entries to episode topology. This is the ledgered handwritten
  residue (transport/ingest, see `HANDWRITTEN.md`); the disclosed ingest
  rule is `required_closure = "wave_loop_tick"`, `residual_shape` = the
  tick outcome, `context` = the telemetry step. Only shapes the ontology
  classifies become self-work orders.
- `Xaas.Ultracode.CapitalCensus.SelfDigest.Law` — the digest law over
  generated facts (`CapitalCensus.Facts`, an ontology projection) and
  generated Ash resources: `R_t = frontier / total` with `improving?/2`
  driving dR/dt < 0; equivalence is the topology triple
  (same required closure ∧ same residual shape ∧ same context,
  `topology_key/1`, `cluster/2`); classification is a hypothesis from the
  ontology's classified shapes and unknown never guesses (`classify/1`);
  provenance is admission — no falsifier, no receipt, no work order
  (`self_work_order/1`).
- `Xaas.Ultracode.CapitalCensus.WorkOrder` — the generated Ash resource
  carrying `ticket_id`, `subject`, `observed`/`expected`/`residual`,
  `classification` (`RecurrenceClass`), `candidate_repair`, `falsifier`,
  `success_criteria`, `derived_from_receipt`, `status`
  (`WorkOrderStatus`), and `gap_id`.
- `Xaas.Ultracode.CapitalCensus.Experience` — machine experience and the
  inverse-experience index (GC-26926-CENSUS): pure functions over plain
  data, no DB and no model runs.
- `Xaas.Ultracode.CapitalCensus.ExperienceCluster` — the generated Ash
  resource clustering experiences by `required_closure` (the topology
  triple from the law).
- `Xaas.Ultracode.CapitalCensus.Route` — the route lattice (GC-26926-CENSUS):
  the total order over which a residual gap is dispatched, capital first —
  `Reuse ≺ Compose ≺ Rule ≺ Plan ≺ Constraint ≺ Generate ≺ SpecializedModel ≺ LLM`.

## Boundaries

- The LAW is handwritten and ledgered; everything it CONSUMES
  (resources, enums, domain registration, facts) is manufactured.
  No classification value, threshold, or route row is hardcoded.
- A self-work order exists only with a falsifier and a derived-from
  receipt (`self_work_order/1` refuses `:unknown_class` otherwise):
  classification without provenance is never admitted.
