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

## Hand-authored orders SJ-010 / SJ-011 (main lineage)

Open work orders continuing the v26.9.21 cycle. Protocol unchanged from
`../v26.9.21/README.md`: real collaborators only (Chicago-style, no mocks),
work in your own worktree at the order's `base_sha`, receipts over assertions,
standing vocabulary `UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN
| UNSUPPORTED`; `ALIVE` needs an observed run of the exact subject. Semantic
Jira admits and selects WorkOrders; it grants no authority and performs no
merge/publish.

### Orders

| id | order | standing | falsifier |
|---|---|---|---|
| SJ-010 | zcode-ocel-pack gets a real consumer | UNKNOWN | emitter accepts an event type absent from the generated registry; an emitted event passes the xaas court but is rejected by the zcode-generated schema |
| SJ-011 | Audit coverage for POST /internal-api/execution/mcp tool calls | UNKNOWN | a tools/call to /internal-api/execution/mcp leaves no audit row |

- **SJ-010** — successor of v26.9.21 SJ-002 (UNSUPPORTED there). Wire
  `Xaas.Telemetry.OcelAshEmitter`
  (`lib/xaas/telemetry/ocel_ash_emitter.ex`) to the zcode-ocel-pack generated
  registry so xaas-emitted OCEL validates against the zcode-generated schema
  (today: fully disjoint vocabularies, zero cross-repo reads). Evidence: a
  differential test — an emitted ash-actions event passes the
  generated-schema validator. Dependency: `zcode-cli gall-work landed on main
  (2026-09-22)`.
- **SJ-011** — apply audit coverage to POST `/internal-api/execution/mcp` tool
  calls. Today the `AuditMcpToolCall` pipeline covers only the `/mcp` AshAi
  scope — an asymmetry (`lib/xaas_web/router.ex:80-163`). Evidence: a
  `tools/call` to the execution fabric produces an audit row queryable via
  existing audit tables.

### Receipts convention

Wave receipts go to `docs/ultracode/<wave>-receipts/`, and cycle progress is
appended to `docs/ultracode/PROGRESS.md` (existing examples:
`wave-v26.9.17-receipts/`, `wave-v26.9.19-receipts/`). A receipt carries
commands + exit codes, real output, and the standing claimed. Receipt files
are append-only evidence: historical receipts are never edited, corrections
are recorded here in the cycle README instead.

### Supply correction (2026-09-22)

> The wave-v26.9.17 receipts pin ggen_igniter feat/calver-ticket-day-pack@d018ed4; that branch no longer exists. Current ggen_igniter line: feat/zcode-ocel-pack@f81cf54 (pack content survives there; priv/ggen/calver-ticket-day-pack + priv/ggen/semantic-jira-pack present on HEAD). Re-pin future manufacturing to a live ref.

This README is the correction record. The v26.9.17 receipt files are
historical evidence and are NOT edited to match; new manufacturing re-pins to
the live ref above.

### Files

- `SJ-010-zcode-ocel-pack-consumer.md`, `SJ-011-execution-mcp-audit-coverage.md` — one WorkOrder each (JSON front matter = the admitted field set).
- `index.json` — machine index.

## Hand-authored continuation orders (main lineage)

`main` independently opened this cycle with two hand-authored orders,
kept verbatim alongside the generated graph (pass-through class, like
SJ-013 in v26.9.21): `SJ-010-zcode-ocel-pack-consumer.md` (successor of
v26.9.21 SJ-002) and `SJ-011-execution-mcp-audit-coverage.md`. They are
not (yet) individuals of `work-orders.ttl`; admit them through
`admit.exs` after adding them to the TTL. Cycle numbering restarts per
version, so these do not collide with v26.9.21's SJ-010..013.

## STOGAF / WD CS2 sub-graph (`stogaf-wd-cs2/`)

PR #62 (STOGAF WD Case Study 2) opened an independent v26.9.22 work graph
`SJ-011 → SJ-020` (ST-4 CONSTRAINED → ST-6 AUTONOMIC, repository-local).
It lives in `stogaf-wd-cs2/` with its own `README.md`, `index.json`,
`workgraph.json`, `state.json`, `closure-policy.json` and
`sa2a-capabilities.json`, so it does not overwrite the generated `index.json`
above (a `generate.py` projection) and its identities are scoped to that
directory: `stogaf-wd-cs2/SJ-011` is not the hand-authored
`SJ-011-execution-mcp-audit-coverage.md` in this directory. The Elixir
planner (`Xaas.CaseStudies.WdFa.Stogaf.WorkGraph`) reads the same
`SJ-011..SJ-020` identities.
