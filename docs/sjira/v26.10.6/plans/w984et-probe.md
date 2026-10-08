# W984et — GraphQL excision residue sweep (non-lib)

Lane: W984et, checkout /Users/sac/xaas, branch feat/playwright-surface.
Operator order: "remove graphql code without reverting, fix forward" (W984ao removed
91 lib files). This lane: non-lib residue (docs/, config/, mix.exs, mix.lock,
.github/, e2e/, test/test_helper.exs, README*). docs/archive/ and CHANGELOGs
excluded per doctrine; docs/sjira receipts describing the removal untouched.

## Verification of current truth (pre-sweep)

- `lib/xaas_web/router.ex`: no graphql scope. Scopes present: `/`, `/webhooks`,
  `/internal-api`, `/internal-api/fabric`, `/mcp`, `/a2a`, `/api/workbench`,
  `/internal-api` (second), `/dev`, `/admin`. No `/api/graphql`, no Absinthe plug.
- `mix.exs`: zero `graphql|absinthe` hits (only `ash_r2rml` git dep, unrelated —
  it is the VKG consumer dep, not AshGraphql).
- `.github/`, `e2e/`, `test/test_helper.exs`, `README*`, `config/`: zero graphql
  hits (grep over all of the above + docs returned no non-docs, non-sjira hits
  outside mix.lock). CI workflows have no graphql steps.

## Hit matrix (command grep -rin graphql, archive/history excluded)

| # | Hit | Classification | Disposition |
|---|---|---|---|
| 1 | `docs/sjira/**` (many, incl. `_COMMIT_MANIFEST_W850.md`, `_CLOSURE_PLAN.md`, CYCLE-LOG refs) | removal-arc receipts | historical-ok — untouched per lane order |
| 2 | `docs/streams/sj004-registry.md:47` — past run cites deleted `test/xaas/graphql_schema_test.exs`, exit 0 | historical run record | historical-ok |
| 3 | `docs/claude/diataxis/explanation/ash-is-the-xaas.md:114-116` | removal note (accurate) | historical-ok — already corrected |
| 4 | `docs/claude/diataxis/explanation/errc-innovation-grid.md:1551` — asserts zero `json_api\|graphql` in event_log.ex | accurate assertion | historical-ok |
| 5 | `docs/claude/diataxis/reference/eu-ai-act-semantics.md:341,468` — `graphql(witness, opts)` / "observe/engineering/graphql/catalog surface" for `vkg.ex` | stale? checked lib | ACCURATE — `lib/xaas/semantics/vkg.ex:66-67` still exports `graphql/2` backed by `AshR2RML.VKG.Consumer.GraphQL` (ash_r2rml git dep, still in mix.exs:120). Not AshGraphql. No edit. |
| 6 | `docs/claude/diataxis/reference/generated-castle-bridge-errc.md:17` | removal note (accurate) | historical-ok |
| 7 | `docs/claude/diataxis/reference/ash-configuration.md:89-99` | removal status section (accurate) | historical-ok |
| 8 | `docs/PRD-v26.8.21.md:10,63,78` | historical PRD for a past release | historical-ok |
| 9 | `docs/innovation-exploration-v26.9.1-cycle-report.md` | historical cycle report | historical-ok |
| 10 | `docs/ultracode/wave-v26.9.17-receipts/wave1-01-domain.md`, `wave1-02-surface.md` | historical lane receipts | historical-ok |
| 11 | `docs/jira/v26.9.15/XAAS-2602-always-bypass-classification.md:15,54` | historical jira finding | historical-ok |
| 12 | `docs/rfc/REQUIREMENTS-v26.9.28.md:50` — "VKG graphql first-row order" fix note | historical reconciliation record | historical-ok |
| 13 | `docs/cro/artifacts/evidence-claims-index.md:72,81` | findings index incl. removal arc | historical-ok |
| 14 | `docs/cro/CYCLE-LOG.md:424-560` | removal-arc cycle log | historical-ok |
| 15 | `mix.lock:17,20` — `ash_graphql` entry; `absinthe`, `absinthe_plug` entries (lines 4-5) | **STALE-CONFIG** | **FIXED** — mix.exs was already clean; lock entries orphaned. `MIX_ENV=test mix deps.unlock ash_graphql absinthe absinthe_plug absinthe_phoenix` (pinned toolchain elixir 1.20.2-otp-28). Output: "Unlocked deps: ash_graphql, absinthe, absinthe_plug". Post-fix grep: zero direct entries; remaining string matches are upstream optional-dep metadata inside `ash_money` (ash_graphql optional: true) and `prom_ex` (absinthe optional: true) lock lines — not repo deps. |
| 16 | `.github/`, `e2e/`, `config/`, `test/test_helper.exs`, `README*` | — | no hits (clean) |

## Residue found OUTSIDE lane scope (lib/, informational for coordinator)

`command grep -ril graphql lib/` → 6 files, all comment-level except one live
surface that is NOT AshGraphql:

- `lib/xaas/sa2a/execution.ex:24` — docstring "No route, GraphQL or RPC surface
  exposes this resource" (accurate statement, not stale).
- `lib/xaas/library/book.ex:61` — comment mentioning API/GraphQL forms (stale
  comment candidate, harmless).
- `lib/xaas/semantics/vkg.ex:66-67` — live `graphql/2` via AshR2RML consumer;
  deliberate, distinct from the removed AshGraphql surface.
- `lib/xaas/operations/project_measure/measurement.ex:12-13,77` — "GraphQL-safe"
  projection descriptions (wording only; attribute description string is
  user-visible API description text).
- `lib/xaas/operations/route_castle_run.ex:6` — "not routed through JSON:API or
  GraphQL" (accurate).
- `lib/xaas/operations/audit_log_entry.ex:20` — "over json_api/graphql" (stale
  wording candidate).

No lib edits made (lane scope = non-lib).

## Commands / exits

- `command grep -rin graphql docs config mix.exs mix.lock .github e2e test/test_helper.exs README*` → hit matrix above (full output 101.7KB, archived in session tool-results b34bk1lfx).
- `command grep -in 'graphql\|absinthe' lib/xaas_web/router.ex mix.exs` → router: none; mix.exs: none (only ash_r2rml lines 120-121).
- `MIX_ENV=test mix deps.unlock ash_graphql absinthe absinthe_plug absinthe_phoenix` → exit 0; "Unlocked deps: * ash_graphql * absinthe * absinthe_plug"; warning "absinthe_phoenix dependency is not locked" (expected — never locked).
- Post-fix `command grep -in 'graphql\|absinthe' mix.lock` → only upstream optional-dep metadata (ash_money, prom_ex).

## Standing

PARTIAL_ALIVE. Non-lib surface clean: only change this lane is the mix.lock
unlock (fix-forward of stale-config). Docs hits are either already-corrected
removal notes or historical records — zero stale-doc edits required, verified
against live lib (vkg.ex graphql/2 is AshR2RML, kept; eu-ai-act-semantics.md
rows are accurate as-is). No commit made. No build root created.
