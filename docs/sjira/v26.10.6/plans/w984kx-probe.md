# W984kx — docs deepening: truth-pass of `docs/claude/diataxis/how-to/*.md`

- Date: 2026-10-08
- Subject: branch `feat/playwright-surface`, working tree at time of pass (no commit — docs-only lane)
- Scope: all 4 files in `docs/claude/diataxis/how-to/`
- Method: every actionable claim checked against live tree with real commands (grep/sed/git).
  No build root, no mix runs (docs-only).
- Sibling edits: none encountered in these 4 files mid-flight; corrections made in place are
  fix-forward only, no reverts, no restructuring.

## Per-file verification tables

### 1. fix-ash-admin-and-use-ggen-for-codegen.md

| Claim | Command evidence | Verdict |
|---|---|---|
| 19 domains in `config :xaas, ash_domains` (config.exs:13+) | sed/grep count = 19 `Xaas.` entries | OK |
| 17 domains carry `AshAdmin.Domain` + `show?(true)`; exceptions `Xaas.Generation`, `Xaas.TemporalMemory` | `grep -l AshAdmin.Domain lib/xaas/*.ex` = 17; `show?(true)` count = 17; zero AshAdmin hits in generation.ex / temporal_memory.ex | OK |
| `/admin` mount dev-only at `router.ex:364-373` | grep hits at 364/368/373 | OK |
| `ggen.toml` binds `ontology.ttl` + `templates-hooks` + locked pack `xaas_castle_bridge` | ggen.toml lines 16-25 | OK |
| Pack pin `518572b6` | ggen.toml now `version = "b58d7854142bacbd3aeffb83501646cae56c858a"` | STALE → corrected in place (2 sites: Task-2 status note + See Also) to `b58d7854`, old value retained as history |
| 55 `xar:RenderTarget` individuals | `grep -c xar:RenderTarget ontology.ttl` = 55 | OK |
| `.ash-gen-receipts/` populated (88 files) | `ls .ash-gen-receipts \| wc -l` = 88 | OK |
| `templates-hooks/ash-gen-resource.txt.tmpl` with `sh_after` | file present, 1 sh_after | OK |
| `deps/ash_admin` `show?/1` defaults `false` | domain.ex:47-48 `get_opt(..., false, true)` | OK |
| `e2e/ash-admin-state-change.spec.cjs` | present | OK |
| `accounts.ex:1-16` excerpt | matches disk | OK |
| GraphQL excision state (W984gz note) | mix.lock has zero top-level `ash_graphql`/`absinthe` entries; 2 grep hits are optional-dep metadata inside upstream `ash_money`/`prom_ex` entries; `vkg.ex:66-67` `graphql/2` still sole live residue | OK (restated in new note) |
| SpgGate / `ash-manufacture-pack` claims | none in guide | nothing to correct |

New "Verified 2026-10-08" note appended per W984gz convention.

### 2. actuate-provider-lifecycle.md

| Claim | Command evidence | Verdict |
|---|---|---|
| `Xaas.Actuation.run/4` exists | `def run(resource, action, input, opts \\ [])` at actuation.ex:26 | OK |
| Authority admission at `actuation.ex:576-582` | actual `delegated_actuation_requires_authority_evidence` block now at 635-664 | STALE → corrected to 635-664 |
| `{:idempotency_not_replayable, ...}` at `actuation.ex:677` | actual production raise sites now at 744 (`idempotency_conflict`) / 753 (`idempotency_not_replayable`); corrected to 753 | STALE → corrected |
| `:actuate_status` `public?(false)` + ReactorContext validation | provider.ex:79-84 (`public?(false)`, `validate(...ReactorContext)` at 83) | OK |
| `test/xaas/actuation_test.exs` | present | OK |
| Error tuples `:idempotency_key_required` (177), `{:idempotency_conflict, key}` unwrap (241-252) | verified | OK |
| SpgGate (landed f0321df2/W650h22) absent from refusal list | gate now part of `run/4` surface per reference docs | GAP → added `{:spg_gate_refused, reason}` bullet to "Diagnose refusals" (opt-in `:spg` key, fail-closed, grants no authority) |

New "Verified 2026-10-08" note appended.

### 3. add-a-real-json-api-route-to-an-ash-resource.md

| Claim | Command evidence | Verdict |
|---|---|---|
| 7 domains in `api_router.ex` | lines 13-19 exactly Accounts/Billing/Governance/Ledger/Marketplace/Operations/Platform | OK |
| internal_api_router mounts only `Xaas.Operations` | line 11 `domains: [Xaas.Operations]` | OK |
| Plug fail-closed 503/401 semantics | require_internal_api_token.ex (503 at 40/148, 401 at 138) | OK |
| capability_liveness_receipt.ex example block | lines 114-129 match; real file uses paren convention `get(:read)`/`index(:read)` | OK (convention noted) |
| 5 sensitive resources have no `routes do` | balance/account/transfer/user/token → 0 hits each | OK |
| "44 mechanically migrated resources" | grep counts ~71 files now carrying `json_api do routes do`; resource's own comment cites "then-49-resource surface" | STALE → left in place as historical context, flagged in new dated note (not restructured) |
| `/internal-api` explicit routes before catch-all `forward` | router.ex ordering comments at 92-96/243/261 | OK |
| SpgGate / graphql / `ash-manufacture-pack` claims | none in guide | nothing to correct |

New "Verified 2026-10-08" note appended.

### 4. author-ggen-templates-safely.md

| Claim | Command evidence | Verdict |
|---|---|---|
| `mcp_scope.ex` tools `[:list_books, :books_by_grade_band, :active_curations_for_grade]` | lines 26, 52 | OK |
| A2A skills `["browse", "checkout", "hddl-plan"]` | next_read_user_agent_skills.ex:20/27/34 | OK |
| `pipeline :audit_mcp_tool_call` at `router.ex:49-50` | actual line 57 | STALE → corrected to 57 (2 sites: body + See Also) |
| `require`/`import` at `router.ex:180-181` | actual 187-188 | STALE → corrected to 187-188 (body + See Also) |
| `scope "/mcp"` call site | router.ex:190 | OK |
| `format_generated_content/2` at reconcile_reactor.ex:1744, called from `render_target/3` at 1717 | exact grep match in `~/ggen_igniter` | OK |
| `ema:exposedVia` closed vocab at pack ontology.ttl:65 | exact match line 65-66 | OK |
| `priv/ggen_igniter/mcp_a2a/` templates + `.rq` files | all present | OK |
| Commit `a0ee306` | resolves to `a0ee3069` | OK |
| SpgGate / graphql / `ash-manufacture-pack` | none in guide | nothing to correct |

New "Verified 2026-10-08" note appended.

## Corrections summary (all fix-forward)

1. fix-ash-admin: pack pin `518572b6` → `b58d7854` (2 sites).
2. actuate-provider-lifecycle: stale line refs 576-582→635-664, 677→753; added SpgGate
   refusal bullet (W650h22 landing was the drift source).
3. add-a-real-json-api-route: "44 resources" figure flagged as stale (~71 now) in dated
   note, original text preserved.
4. author-ggen-templates: router.ex line refs 49-50→57, 180-181→187-188 (3 sites total).

## Standing

Observed execution: every verdict cell above backed by a real command run this session.
No commit made (docs-only lane, per dispatch). No build roots created.
