# W754 — generated-castle-bridge-errc.md verification receipt

- Subject: /Users/sac/xaas @ a0723bf6, branch feat/playwright-surface
- Page verified: `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`
- Generator: `ggen-marketplace/packs/xaas-castle-bridge-pack/templates/castle-errc.md.tmpl`
  + `packs/xaas-castle-bridge-pack/ontology.ttl` (xcb:ERRCDecision facts), pinned in
  `/Users/sac/xaas/ggen.toml` at `518572b6b53103922ae8a27636a00e982a0907c4`.
- No page edits made (page is a generated projection — verified only, per its header).

## Per-claim verification

| # | Page claim | Checked against | Result |
|---|---|---|---|
| 1 | 12 ERRC rows (4 CREATE, 3 ELIMINATE, 2 RAISE, 3 REDUCE) with exact decision/rationale/leverage text | `ontology.ttl` xcb:ERRCDecision facts (lines 101-112); template ORDER BY ?category ?priority | MATCH — all 12 rows byte-equal at grep grade; row order (CREATE→ELIMINATE→RAISE→REDUCE, priority asc) matches SPARQL ORDER BY |
| 2 | Header "Generated from ggen-marketplace/xaas-castle-bridge-pack; do not hand-edit" + closing prose (RouteCastleRun preserved, DO authority) | template literal text | MATCH — byte-identical |
| 3 | "69 Ash resources and seven domains" (ELIMINATE-10 rationale) | `grep -rl "use Ash.Resource" lib/xaas` → 150 files; `use Xaas.Resource` → 115 files; `use Ash.Domain` → 19 domains | DRIFT (generator input, not page) — see F1 |
| 4 | "RouteCastleRun remains read-only on JSON:API/GraphQL" | `lib/xaas/operations/route_castle_run.ex`: json_api routes = get(:read)/index(:read) only; policies = bypass read + deny-all floor; graphql type declared, no mutation routes | MATCH |
| 5 | "execute stays private behind Reactor context" | same file: `action :execute, public?(false), transaction?(true), run(Xaas.Castle.Actions.Execute)`; no web route; moduledoc: succeeds only via Xaas.Actuation | MATCH |
| 6 | "native RouteCastle capability" exists in XaaS | `lib/xaas/operations/route_castle_run.ex`, registered in `lib/xaas/operations.ex:51` | MATCH |
| 7 | Pin integrity: fresh `ggen sync` would emit identical page | ggen.toml pins pack SHA 518572b6; `git diff 518572b6..HEAD` in ggen-marketplace touches ontology.ttl only by added dcat:Dataset provenance triples; zero changes to ERRCDecision facts or castle-errc.md.tmpl | MATCH — page is fresh vs pinned generator inputs |

## Drift findings (typed)

- **F1 — STALE_GENERATOR_INPUT_COUNT** (severity: low, page is faithful to its source).
  The ELIMINATE-10 rationale "XaaS already owns 69 Ash resources and seven domains" is
  stale against lib/: observed 150 files matching `use Ash.Resource` (150 total resource
  definitions; 115 use the `Xaas.Resource` wrapper), 19 Ash domains. The drift lives in
  the upstream pack ontology (`ggen-marketplace/packs/xaas-castle-bridge-pack/ontology.ttl`,
  xcb:eliminate10 rationale), NOT in the page. Page edit prohibited and not performed.
  **Lawful fix**: edit the rationale in the pack ontology upstream, then run `ggen sync`
  from /Users/sac/xaas to re-emit the page. Command: `ggen sync`.
- **F2 — PIN_VS_WORKTREE_SKEW** (severity: informational). ggen.toml pins pack at
  518572b6; local ggen-marketplace checkout HEAD is 4bb5fbaf. Verified the delta does not
  affect the ERRC template or any ERRCDecision fact (only added DCAT provenance triples),
  so page output is pin-stable. No action.

## Standing

- Page: **ALIVE** as a projection — byte-faithful to its pinned generator inputs; no
  hand-edit required or performed.
- Generator-input currency: **PARTIAL_ALIVE** — F1 count drift in upstream ontology.
- Commands run (read-only): grep/git-diff inspections listed above; no build root
  created; no commits made.
