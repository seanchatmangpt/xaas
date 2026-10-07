# W841 — ash_admin/ggen how-to verification receipt

Date: 2026-10-07. Repo: /Users/sac/xaas, branch `feat/playwright-surface`, HEAD `a0723bf6`.
Subject: `docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md` verified
claim-by-claim against the v26.10.6 tree and corrected in place. Sole written surfaces:
the how-to page + this receipt. No commit (coordinator owns commits). No build root.

## Per-claim table

| # | Claim (page, pre-edit) | Verdict | Evidence |
|---|---|---|---|
| 1 | `AshAdmin.Domain.show?/1` defaults `false` at `domain.ex:47-49` | VERIFIED | `deps/ash_admin/lib/ash_admin/domain.ex:47-49` (`def show?(domain) do ... false, true)`) |
| 2 | Missing `admin do` block is the repo's root cause; upstream bug narrow | VERIFIED | `deps/ash_admin/lib/ash_admin/pages/page_live.ex:232` fallback omits `:action_type`; branches at :197/:227 assign it; `@action_type` read at :117; mechanism intact |
| 3 | "7 core domains needed this fix ... ash_domains config now lists 12+" | CORRECTED (stale counts) | 17 of 19 domains in `config/config.exs:13-33` carry the block; exceptions `Xaas.Generation`, `Xaas.TemporalMemory` (no `AshAdmin.Domain` extension). Page now states 17/19 with file cites |
| 4 | Example domain block `admin do show? true end`, unp paren `resource` calls, extensions w/o `AshTypescript.Rpc`, no Org resources | CORRECTED (stale form + content) | `lib/xaas/accounts.ex:1-16`: paren form `show?(true)`, `resource(...)`, extensions `[AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain, AshTypescript.Rpc]`, `typescript_rpc` block on `Xaas.Accounts.Org`; example replaced verbatim from disk |
| 5 | Router mounts `AshAdmin.Router` under `/admin`, dev_routes-guarded | VERIFIED | `lib/xaas_web/router.ex:339-348` inside `if Application.compile_env(:xaas, :dev_routes)` (:314) |
| 6 | curl / `mix phx.routes` verify procedure | VERIFIED (not executed — no server in lane; command forms match router/code) | router mount above; no build root allocated, no `mix phx.server` run |
| 6b | `/internal-api/capability_liveness_receipts` assertion route | VERIFIED (served via `forward` scope, `lib/xaas_web/router.ex:252` region) | `e2e/ash-admin-state-change.spec.cjs:86` still targets it; spec exists on disk with the sidebar/`.last()`/Pause-panel patterns the page cites |
| 7 | Template `templates-hooks/ash-gen-resource.txt.tmpl` content (to/skip_empty/unless_exists/for_each/sparql/sh_after) | VERIFIED | byte-comparable read of the template; page's quoted block matches on disk exactly |
| 8 | ggen sync procedure: SPARQL over `ontology.ttl` `xar:RenderTarget`, `unless_exists` receipts, `.ash-gen-receipts/*.mix.log` | VERIFIED, annotated | `ontology.ttl` declares 55 `xar:RenderTarget` individuals; `.ash-gen-receipts/` populated; `ggen.toml` binds `[ontology] source = "ontology.ttl"` + `[templates] dir = "templates-hooks"`. ADDED a v26.10.6 status note: locked `xaas_castle_bridge` pack pin `518572b6` (W636-era lock-closure state) now unions pack templates into the same sync without changing the RenderTarget projection |
| 9 | See Also "the other 5 domain modules ... all 7 core domains" | CORRECTED (stale counts) | page now cites 17 domain modules / 19 registered domains, plus a new `ggen.toml` See Also row with the pack-pin law |
| 10 | sh_after vs inject:/before:/after rationale (Igniter AST-aware vs text insertion) | VERIFIED (rationale unchanged; no code change touches it) | W749/W820 receipts updated other surfaces; neither contradicts this split. W820's "Status at v26.10.6" status-block convention applied to this page's header |

## Corrections made in place (with citations)

1. Header: added v26.10.6 status block (W749/W820 convention) naming lane W841 + receipt path.
2. Domain-count claims (7 core / 12+ / "other 5") -> 17 of 19 registered domains, two
   named exceptions, `config/config.exs:13-33` cite.
3. Example block replaced with the on-disk `lib/xaas/accounts.ex:1-16` form (paren-call
   convention, `AshTypescript.Rpc` extension, Org/typescript_rpc content).
4. `show? true` -> `show?(true)` in the two procedural sentences.
5. Task 2 "Running it": added ggen.toml W636-era state note (castle-bridge pack pin,
   55 RenderTargets, populated receipts dir).
6. See Also: corrected counts, added `ggen.toml` entry.

## What was NOT done

- No `mix phx.server`/`ggen sync` re-run (no build root in lane; page's verify commands
  are form-verified against router/config only).
- No commit; no other pages touched; standing of e2e spec and template inherited from
  their on-disk presence and cited receipts (W636/W749/W820).
