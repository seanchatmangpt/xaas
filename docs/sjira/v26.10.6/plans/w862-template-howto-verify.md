# W862 — template-authoring how-to verification receipt

- **Subject**: `/Users/sac/xaas` @ `a0723bf6`, branch `feat/playwright-surface` (canonical checkout, no build root, no commit)
- **Target**: `docs/claude/diataxis/how-to/author-ggen-templates-safely.md` (listed in diataxis README line 19)
- **Method**: per-claim grep/read of every cited file:line, on disk, 2026-10-07

## Per-claim table

| # | Claim in how-to | Status | Evidence |
|---|---|---|---|
| 1 | Source commit `a0ee306` exists | VERIFIED | `git log --oneline -1 a0ee306` → `a0ee3069 feat(mcp/a2a): rewrite generated pieces via real ggen_igniter dogfood run` |
| 2 | `lib/xaas_web/mcp_scope.ex` is real generated macro with `forward/3` body, tool list `[:list_books, :books_by_grade_band, :active_curations_for_grade]` | VERIFIED | `mcp_scope.ex:26` (moduledoc tool list), `:46` (`tools: [...]` in `forward`) |
| 3 | `pipeline :audit_mcp_tool_call` defined at `router.ex:49-50` | VERIFIED | `router.ex:49-50`: `pipeline :audit_mcp_tool_call do plug(XaasWeb.Plugs.AuditMcpToolCall) end` |
| 4 | Macro `require`d/`import`ed at `router.ex:173-174` | **STALE — FIXED** | actual `require XaasWeb.McpScope` / `import XaasWeb.McpScope, only: [mount: 0]` now at `router.ex:180-181` (lines 172-179 are the explanatory comment block; `scope "/mcp"` at `:182`, `mount()` at `:190`) |
| 5 | A2A skills `["browse", "checkout", "hddl-plan"]` in `next_read_user_agent_skills.ex` | VERIFIED | ids at `:20` browse, `:27` checkout, `:34` hddl-plan |
| 6 | `format_generated_content/2` at `~/ggen_igniter/.../reconcile_reactor.ex`, called from `render_target/3` ~1440, defined ~1486 | **STALE — FIXED** | actual: `defp render_target(t, manifest, base_dir)` at `:1636`, call to `format_generated_content(out_path, content)` at `:1717`, `defp format_generated_content` at `:1744`. Updated doc to 1717/1744. Semantics (rescue-fallback, `.ex`/`.exs` only) confirmed by `:1684` comment + call context |
| 7 | `ontology.ttl` declares `ema:exposedVia` closed vocab `"mcp"\|"a2a"\|"both"` | VERIFIED content | `~/ggen-marketplace/packs/elixir-mcp-a2a-pack/ontology.ttl` — `ema:exposedVia` at `:65-66`, comment names the disjoint id sets + `gates/010` named follow-up |
| 8 | `exposedVia` at ontology.ttl line 56 | **STALE — FIXED** | actual declaration at `:65`. Updated doc to 65 |
| 9 | `ema:capabilityTag` discriminator property with falsifying-evidence comment | VERIFIED | `ontology.ttl:69-70` |
| 10 | Templates + queries exist and filter on `exposedVia` (mcp: "mcp"\|"both"; a2a: "a2a"\|"both") | VERIFIED | `priv/ggen_igniter/mcp_a2a/templates/{mcp_scope,a2a_skills}.eex` exist; `mcp_capabilities.rq:7` `FILTER (?via = "mcp" \|\| ?via = "both")`; `a2a_capabilities.rq:8` `FILTER (?via = "a2a" \|\| ?via = "both")` |
| 11 | sh_after/inject convention (See-Also pointer to `fix-ash-admin-and-use-ggen-for-codegen.md`) still accurate per W841 | VERIFIED | `docs/sjira/v26.10.6/plans/w841-ashadmin-howto-verify.md` rows 7 & 10: template hook content (incl. `sh_after`) VERIFIED byte-comparable on disk; sh_after-vs-inject rationale VERIFIED unchanged at v26.10.6 |
| 12 | ggen sync state | VERIFIED | `ggen.lock` (repo root) pins exactly one pack: `xaas_castle_bridge` → `ggen-marketplace.git@518572b6...#packs/xaas-castle-bridge-pack`, blake3 `c5e128e3...`. The how-to makes no ggen.lock claim, so no edit needed |

## Edits made (4, all citation line-number drift)

1. `reconcile_reactor.ex` refs: 1440/1486 → 1717/1744 (line 44-45 of the how-to)
2. `router.ex` macro call-site refs: 173-174 → 180-181 (line 65)
3. See-Also `router.ex` refs: `49-50,173-174` → `49-50,180-181` (line 122)
4. `ontology.ttl` `exposedVia` ref: line 56 → line 65 (line 87)

## Standing

- How-to's two defect narratives (macro-invalid-at-call-site; multi-surface identity needing discriminator): **still accurate** — both examples' substance confirmed on disk against current code.
- Page standing: **PARTIAL_ALIVE → verified current** as of 2026-10-07, subject `a0723bf6` + 4 citation fixes.
- Replay: `sed -n '49,50p;180,181p' lib/xaas_web/router.ex && sed -n '65,66p;69,70p' ~/ggen-marketplace/packs/elixir-mcp-a2a-pack/ontology.ttl && grep -n format_generated_content ~/ggen_igniter/lib/ggen_igniter/reactors/reconcile_reactor.ex`
