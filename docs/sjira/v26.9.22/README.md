# Semantic Jira work orders — v26.9.22

The multi-repo Semantic Jira work graph for the v26.9.22 cycle: 153 work orders over 16
repositories, one `sj:WorkOrder` each, in the semantic-jira-pack vocabulary
(`~/ggen_igniter/priv/ggen/semantic-jira-pack/ontology.ttl`). Semantic Jira is
`GgenIgniter.SemanticJira` (`~/ggen_igniter/lib/ggen_igniter/semantic_jira.ex`): it admits
and selects work orders; it grants no authority and performs no merge, push or publish.

## Source and projections

- `work-orders.ttl` is the source. Edit it, never a projection.
- `project.py` projects it into `wo.json` (the admission input), `index.json` (top-level
  array `{id, path, standing, repository, dependencies}`, same shape as v26.9.21) and
  `jira/<ID>.md`. `python3 project.py --check` exits 1 when a committed projection is stale.
- Standing is `UNKNOWN` for every order in the graph. Observed standing comes from the
  TransitionLog (`GgenIgniter.SemanticJira.project/2` over append-only events) once
  GGEN_IGNITER-26922-06/07 land; until then no projection carries an observed standing, and
  none is hand-edited to carry one.
- `sj:baseSha` is the exact `release/v26.9.22` integration head of each repository when the
  graph was authored. ash_atlassian and chatman-ecosystem have no remote and use
  `local/<name>` repository slugs.

| Repository | Orders | baseSha |
|---|---|---|
| seanchatmangpt/xaas | 18 | 77887a6453e1ca5c15b8fdbf1081f6791daa9083 |
| seanchatmangpt/ggen_igniter | 14 | facdf0dbd3cd95f5b8a630dcbcacc0140d6582fc |
| seanchatmangpt/ash_a2a | 13 | 971687469ea2ac04f27a4cb2d1af40bf957c4b63 |
| seanchatmangpt/autofde-lab | 11 | d4faeff92c8000fcea53b065ef2c833b7070446b |
| seanchatmangpt/ash_surface | 11 | 9972ef6a8e105cfad0c6feb5c2ac3adf02fcb058 |
| seanchatmangpt/ggen-ecosystem | 11 | 435117fd7f419cc18b0d7b1ba3f25c2d224ac1fc |
| seanchatmangpt/zcode-cli | 10 | da178249d54b0c2f8a34977d694300c1f039e7da |
| seanchatmangpt/ggen-marketplace | 10 | 57b4d330237db0f51b17ac1991f8f5da43f085f4 |
| seanchatmangpt/gymact | 10 | a2d2b07dd51e6a4f8689e6c86a7d867293bbf473 |
| seanchatmangpt/beam4pm | 9 | 574368706e6afd804c7a13771bed3cf03da33ce0 |
| seanchatmangpt/ferroplan | 8 | 305546927ebef3b188e79b2f497f8360f998f44b |
| seanchatmangpt/gitvan | 8 | a905abdb0baad27357b7a5c46ca31253a10c1fb9 |
| seanchatmangpt/ggen | 7 | 06093e0cd679662b8c6d15eedea0973fd475dec5 |
| seanchatmangpt/frozen-duckdb | 6 | 3ebfac8c62c3fdf14275bdff737074079731234e |
| local/ash_atlassian | 4 | 36b1799381d04b50da2bececd4b201defc231333 |
| local/chatman-ecosystem | 3 | 7ac66d8c55ce4aba62cd6416e9f3eecd358700e4 |

183 typed dependency edges (`requiresReceipt`, plus one `requiresObservation` for
ZCODE-26922-04's "XAAS-26922-12 or a hand-materialized epoch"); 23 cross repositories.
Human decisions and push/publish/operator authority are modeled as order-specific
`sj:EvidenceRequirement` nodes (and `authority_preparation` receipt classes), not as
dependency edges: every order stays at authority ceiling `CONSTRUCT`, and the
consequential step is a separate BRCE DO. Each repository's release action is the
`sj:Checkpoint` its orders name as `sj:nextCheckpoint`.

## Protocol for an agent

1. Read `index.json`. Pick an order whose `standing` is not `ALIVE` and whose
   `dependencies` are all `ALIVE` (read from the TransitionLog, or a sealed receipt).
2. Work in your own git worktree of the order's repository, off `release/v26.9.22`
   descended from `base_sha`. Follow `/Users/sac/wt/v26922/COORDINATION.md` (merge lock,
   clean int worktree, receipts, court verdicts).
3. Real collaborators only (Chicago style): no mocks. Run the order's runnable check and
   put the real output in `receipts/v26.9.22/<ID>.json`.
4. Commit with `git commit -F <file>`. Never rebase, force-push or `reset --hard`.
5. Report standing with `UNKNOWN | PARTIAL_ALIVE | ALIVE | BLOCKED | BUILD_BROKEN |
   UNSUPPORTED`; `ALIVE` needs an observed run of the exact subject, a court receipt, and a
   revert-mutation that makes the check fail.
6. Do not merge, publish or deploy; XaaS/BRCE own consequential DO.

## Commands

```sh
cd docs/sjira/v26.9.22 && python3 project.py && python3 project.py --check

# Admission (kernel = ggen_igniter release/v26.9.22 facdf0d). The main ~/ggen_igniter
# checkout has no deps/ or _build/, so admission runs from the integration worktree with
# the build redirected to a scratch copy of its _build/dev (nothing written to that tree):
cd /Users/sac/wt/v26922/ggen_igniter/int && MIX_BUILD_PATH=<scratch>/gi_build_dev \
  WO=<abs>/docs/sjira/v26.9.22/wo.json mix run <abs>/docs/sjira/v26.9.22/admit.exs

# SHACL court (GgenIgniter.SemanticJira.Shacl over the pack shapes):
cd /Users/sac/wt/v26922/ggen_igniter/int && MIX_BUILD_PATH=<scratch>/gi_build_dev \
  TTL=<abs>/docs/sjira/v26.9.22/work-orders.ttl mix run <abs>/docs/sjira/v26.9.22/shacl.exs

# SA2A (plan/admit/replay only; sa2a_execute is a DO edge and is never called):
PATH=$HOME/autofde-lab/.venv/bin:$PATH SJ_IDS=<ids> mix run --no-start docs/sjira/v26.9.22/sa2a_loop.exs plan
```

## Recorded results (2026-09-22)

- Admission: 153 `ADMITTED`, 0 `REFUSED` (`receipts/admit-2026-09-22.out`; a second run
  reproduced all 153 digests byte-identically).
- SHACL (`receipts/shacl-2026-09-22.out`): 27 violations, one constraint only. `WorkOrderShape` requires `dcterms:identifier`
  to match `^[A-Z][A-Z0-9-]{1,63}$`, and the cycle's identifiers `GGEN_IGNITER-26922-NN`
  (14) and `ASH_A2A-26922-NN` (13) contain `_`. All other shapes and constraints pass over
  649 focus nodes (closed shape, uniqueness, dependency integrity, authority binding,
  ALIVE crown). Resolving this needs either a pattern widening in semantic-jira-pack or
  an identifier scheme change for those two prefixes. It is not a graph defect.

## Files

`work-orders.ttl` (source), `project.py`, `wo.json`, `index.json`, `jira/`, `admit.exs`,
`shacl.exs`, `sa2a_loop.exs`, `receipts/`, `seed/author_ttl.py` (provenance of the first
revision), `HANDWRITTEN.md`. `docs/sjira/v26.9.21` stays as the historical cycle.
