# docs/sjira/v26.9.22 — the multi-repo Semantic Jira graph

Hosts the v26.9.22 wave's work orders for ten repositories as one admitted RDF
graph. This cycle replaces the v26.9.21 `generate.py` literal pattern: the
source of truth is `work-orders.ttl` (sj: vocabulary, one `sj:WorkOrder` per
lane work order, `sj:repository` as owner/name slugs), and standing is a
**projected observation**, never a literal in the generator.

## Layout

- `work-orders.ttl` — hand-authored source of truth (96 orders: xaas 18,
  autofde-lab 11, gymact 10, ash_atlassian 4, beam4pm 9, ash_surface 11,
  ferroplan 8, gitvan 8, ggen 7, ggen-marketplace 10). Edit this file, never a
  projection.
- `generate.py` — deterministic projection of the TTL into `wo.json`,
  `index.json` and `jira/<identity>.md`. `--check` asserts the committed
  projections reproduce byte-identically.
- `transition-log.jsonl` — the standing input: append-only events
  `{identity, seq, from, to, evidence}`. The latest event per identity by `seq`
  wins — the same projection `GgenIgniter.SemanticJira.project/2` performs over
  a TransitionLog. Orders with no event read `standing/<identity>.json`
  (recorded observation inputs); otherwise the vocabulary default `UNKNOWN`.
  The v26.9.21 defect (standings hard-coded as literals; regeneration
  clobbering promoted `index.json` entries that consumer lanes read) is closed
  structurally: there are no per-order standings in the generator to clobber.
- `wo.json` — the admitted input for `admit.exs` (the `WO_JSON` projection).
- `index.json` — top-level array consumer lanes read
  (`id, path, standing, repository, dependencies`).
- `admit.exs` — admission through the GgenIgniter kernel:
  `cd ~/ggen_igniter && WO=$PWD/wo.json mix run $PWD/admit.exs`; prints
  `ADMITTED <identity> <digest>` or `REFUSED <identity> <reason>` per order.
- `sa2a_loop.exs` — SA2A driver (plan / admit / replay only; `sa2a_execute` is
  a DO edge and is never called here).
- `receipts/` — SA2A plan/admit/replay artifacts and cycle receipts.
- `jira/` — generated ticket projections.

## Standing discipline

`ALIVE` requires observed execution against the exact subject with the required
verifier, receipted in `receipts/` (or the repo-root `receipts/v26.9.22/`).
Orders awaiting a producer release or an operator decision are recorded
`BLOCKED` with the awaited ref in the transition log's `evidence` field.

## Provenance

Order identities are the wave lane work-order IDs (e.g. `XAAS-26922-01`);
dependencies are typed `requiresReceipt` edges over those identities, including
cross-repo edges to producer orders (`GGEN_IGNITER-26922-13`,
`ASH_A2A-26922-12`, ...). ggen_igniter's own orders are not hosted here — it is
the admitting kernel's repo. The pack-based projection of this graph
(`semantic-jira-pack` via ggen sync) remains queued on
`GGEN_IGNITER-26922-08`; `generate.py` is the deterministic in-repo projection
used for admission this cycle.

`docs/sjira/v26.9.21` stays as the historical cycle.
