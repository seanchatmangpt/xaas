# W984hy — truth-pass: docs/claude/diataxis/reference/ash-configuration.md

Date: 2026-10-07. Lane W984hy, shared canonical checkout `/Users/sac/xaas`, branch
`feat/playwright-surface`, HEAD `82f7f558`. Docs-only: no commit, no build root,
no branch switch, no stash. Sibling-modified file (`git status` shows it M):
disk state read first; edits were three targeted patches + one appended dated
blockquote; no sibling edits reverted.

## Before (excerpts)

- `| tracer | [OpentelemetryAsh] |` (the `:ash` global config table).
- `custom_types` code block showed exactly 3 entries
  (`money`, `capability_class`, `interface`) with a 3-row table beneath it.
- No `default_string_length_count` row anywhere; `ash_domains` row already said
  19 domains (`config/config.exs:13-33`, re-verified 2026-10-06).
- No dated Verified blockquote.

## After (excerpts)

- `| tracer | [OpentelemetryAsh, Xaas.Telemetry.OcelAshEmitter]
  (config/config.exs:67 — the OCEL emitter needs Ash.Tracer's
  set_handled_error/set_error callbacks ...) |`
- New row `| default_string_length_count | :codepoints (config/config.exs:188) |`
  atop the `:ash` config table.
- `custom_types` block now annotates `# ... 26 further entries ...` and a prose
  paragraph enumerating all 29 registrations across Governance (17), Operations
  (3), Ultracode CapitalCensus (6) + the 3 originals.
- Appended `> **Verified 2026-10-07** (lane W984hy truth-pass, HEAD 82f7f558) ...`
  blockquote at end of file.

## Command-verified claims (real output)

- `sed -n '13,40p' config/config.exs` → `ash_domains` exactly 19 entries
  (Xaas.Library … Xaas.Witness), lines 13-33; `ash_authentication`
  `[return_error_on_invalid_magic_link_token?: true]`; `base_resources`
  `[Xaas.Resource]`. Matches doc.
- Per-domain `resource(` counts via awk over each `resources do` block:
  library 7, accounts 5, a2a 2, billing 8, conference 7, coupling 1, generation 1,
  graphlaw 2, governance 28, igniter 2, ledger 4, marketplace 3, ocel 5,
  operations 21, platform 7, security 2, temporal_memory 1, ultracode 8,
  witness 2 → 116 total. Matches doc table exactly.
- Extension columns match disk for all 19 domains (e.g. `operations.ex:4-9`
  four-element list incl. `Xaas.Operations.ProjectMeasure.Extension`;
  `generation.ex`/`temporal_memory.ex` extensions-less).
- `grep -rl "admin do" lib/xaas/*.ex | wc -l` → 17; each `admin do show?(true) end`;
  exceptions `Xaas.Generation`, `Xaas.TemporalMemory` (no AshAdmin extension).
- `sed -n '364,373p' lib/xaas_web/router.ex` → real AshAdmin.Router mount,
  dev-only (guarded by dev_routes flag), `ash_admin("/")` at line 373.
- `grep -n AshTypescript lib/xaas_web/router.ex` → `post("/rpc/run", ...)`,
  `post("/rpc/validate", ...)` at `router.ex:109-110` (token-gated
  `/internal-api` scope).
- JSON:API mounts: `forward("/internal-api", XaasWeb.InternalApiRouter)`
  (`router.ex:286`), `forward("/api", XaasWeb.ApiRouter)` (`router.ex:330`);
  both `use AshJsonApi.Router` (`lib/xaas_web/internal_api_router.ex:11`,
  `lib/xaas_web/api_router.ex:11`).
- Policy floor: `lib/xaas/library/book.ex` read policy
  (`authorize_if always()`) cited live at `router.ex:170-172` comment; MCP
  `/mcp` pipeline gates on `:require_internal_api_token` + audit plug.
- GraphQL excision: `grep -rln AshGraphql lib/ test/` → only
  `test/xaas/generated/registry_drift_guard_test.exs:77` (a comment); no graphql
  router scope; `lib/xaas/semantics/vkg.ex:66-67` is the sole live `graphql/2`
  via `AshR2RML.VKG.Consumer.GraphQL` (ash_r2rml git dep) — matches
  `plans/w984et-probe.md` hit #5. Cited where the excision affects a claim.
- Drift fixed this pass (3 items):
  1. `config :ash, :tracer` = `[OpentelemetryAsh, Xaas.Telemetry.OcelAshEmitter]`
     (`config/config.exs:67`) — doc said `[OpentelemetryAsh]` only.
  2. `default_string_length_count: :codepoints` (`config/config.exs:188`) —
     missing from doc table.
  3. `custom_types` = 29 entries (`config/config.exs:202-233`, counted via
     `sed -n '202,233p' | grep -cE '^\s+[a-z_]+: '` → 30 incl. the
     `custom_types: [` line = 29 registrations) — doc showed 3.

## Standing

PARTIAL_ALIVE — docs-only truth pass; all corrected claims verified by command
against HEAD `82f7f558`. No commit (per lane order). No falsifier run needed
(no executable claims introduced; doc-only).
