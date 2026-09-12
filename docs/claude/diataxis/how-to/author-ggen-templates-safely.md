# How to Author ggen/ggen_igniter Templates Safely

This guide covers two real, generalizable mistakes hit during the `mix ggen_igniter.sync`
dogfood run against `priv/ggen_igniter/mcp_a2a/xaas-surface.ttl` (commit `a0ee306`,
"feat(mcp/a2a): rewrite generated pieces via real ggen_igniter dogfood run"), which
generated `XaasWeb.McpScope` and `XaasWeb.A2A.NextReadUserAgentSkills`. Both mistakes are
generalizable to any future ggen or ggen_igniter template authored in this repo or in
`ggen-marketplace` packs, not specific to MCP/A2A.

## Lesson 1: a compile-clean generated macro can still have an invalid body

### What actually happened

An early draft of `priv/ggen_igniter/mcp_a2a/templates/mcp_scope.eex` generated a
`defmacro mount do quote do ... end end` body that injected `plug
XaasWeb.Plugs.AuditMcpToolCall` directly inside the `quote do` block, intending it to expand
inside a Phoenix `scope "/mcp" do ... end` call site. `plug/1` is invalid directly inside a
`scope` block in Phoenix's router DSL — it is only valid inside a named `pipeline do ... end`
block. The generated `lib/xaas_web/mcp_scope.ex` file itself compiled cleanly on its own,
because `mix ggen_igniter.sync`'s own compile-check gate (`mix compile
--warnings-as-errors`) only compiles the macro's *definition*, never a real call site that
actually expands it — a `quote do ... end` block's contents are not type- or DSL-checked
until some other module actually calls the macro. The defect was caught only by a human/
agent manually reading the generated moduledoc against the generated macro body and noticing
they contradicted each other (the moduledoc said "mount this in your router," the macro body
would have failed to compile the moment anything actually mounted it) — not by any automated
gate in the sync pipeline.

The real fix (visible in the shipped `lib/xaas_web/mcp_scope.ex`) was to not generate the
`plug` call at all: the macro's `mount/0` body now only expands `forward("/", AshAi.Mcp.Router,
tools: [...], ...)`, and the moduledoc documents the real requirement instead — the consumer
must define their own `pipeline :audit_mcp_tool_call do plug
XaasWeb.Plugs.AuditMcpToolCall end` in their own `router.ex` (this repo's real one is wired at
`lib/xaas_web/router.ex:37`) and reference it via `pipe_through`, rather than the template
generating invalid code that pretends a macro body can inject a pipeline declaration from a
`scope` call site.

### Now-fixed: auto-formatting

Separately, generated `.ex` files were not auto-formatted by `mix ggen_igniter.sync` until
this session — the sync tool's own `mix compile --warnings-as-errors` gate does not catch
formatting drift, so hand-running `mix format` after every sync was required. This is now
fixed for real: `~/ggen_igniter/lib/ggen_igniter/reactors/reconcile_reactor.ex`'s
`format_generated_content/2` (called from `render_target/3` around line 1440, defined at
line 1486) runs every rendered `.ex`/`.exs` body through `Code.format_string!/1` before it
reaches `PendingActuation.for_file`/`for_inject`, with a rescue that falls back to the
original unformatted content on a `Code.format_string!/1` failure — so a formatting bug
never fails an otherwise-successful sync. Non-Elixir output paths are never touched. Treat
this as a real, already-landed capability of `ggen_igniter`; you do not need to re-verify it
before relying on it.

### The one real edge case the formatting fix cannot close

`Code.format_string!/1` and `mix compile --warnings-as-errors` both operate on the generated
file **standing alone**. Neither can validate what a generated macro's body actually expands
into at a real call site, because that expansion only happens when some other module invokes
the macro. This is a structural limitation, not a bug to file against `ggen_igniter` — no
purely-generated-file gate can see across the macro-expansion boundary.

**Actionable guidance:** when a ggen or ggen_igniter template's rendered output defines a
`defmacro`, do not trust the sync's own compile-check as sufficient proof the template is
correct. Manually wire the generated macro into a real call site (a real router, a real
module) and run `mix compile --warnings-as-errors` on **that** call site, not just on the
generated file in isolation, before trusting the template. `XaasWeb.McpScope.mount/0` being
actually `require`d and `import`ed at `lib/xaas_web/router.ex:113-114` and invoked inside a
real `scope "/mcp" do ... end` block is the concrete verification step that caught this
exact defect class for this template.

## Lesson 2: don't assume one ontology row serves two protocol surfaces without a discriminator

### What actually happened

An earlier draft of `ggen-marketplace/packs/elixir-mcp-a2a-pack/ontology.ttl` modeled a
single `ema:Capability` row per capability, with one `ema:capabilityId`, assumed to serve
both the generated MCP tool list and the generated A2A skill list under the same id. Real
xaas code disproved this assumption: `lib/xaas_web/mcp_scope.ex`'s real `/mcp` tools are
`[:list_books, :books_by_grade_band, :active_curations_for_grade]` (read-only Ash actions,
wired via `router.ex`'s `require XaasWeb.McpScope` / `import XaasWeb.McpScope, only:
[mount: 0]`), while `lib/xaas_web/a2a/next_read_user_agent_skills.ex`'s real A2A skills are
`["browse", "checkout", "hddl-plan"]` (persona-level tasks). These id sets are **disjoint** —
`checkout` is a real consequential mutation (borrowing a book) that is A2A-only and never
exposed as an MCP tool at all.

### The fix

`ggen-marketplace/packs/elixir-mcp-a2a-pack/ontology.ttl` (line 56) now declares
`ema:exposedVia` as a closed-vocabulary property on `ema:Capability`: `"mcp"` | `"a2a"` |
`"both"`. The pack's comment on that property states the correction explicitly and names the
two real id lists above as the falsifying evidence. Consuming templates
(`priv/ggen_igniter/mcp_a2a/templates/mcp_scope.eex` and
`priv/ggen_igniter/mcp_a2a/templates/a2a_skills.eex`, driven by
`priv/ggen_igniter/mcp_a2a/mcp_capabilities.rq` and
`priv/ggen_igniter/mcp_a2a/a2a_capabilities.rq` respectively) filter on this discriminator —
the MCP-surface query selects rows where `exposedVia` is `"mcp"` or `"both"`; the A2A-surface
query selects rows where `exposedVia` is `"a2a"` or `"both"`. A capability row matching
neither filter value is a real defect (it would silently vanish from both generated
surfaces) — the pack's own ontology comment names this as a real follow-up gate not yet
added (`gates/010`), not an accepted default.

### Generalized guidance

Before authoring an ontology/spec row that is meant to feed more than one generated surface
or protocol from a single identity, **verify against the real target code** (grep or read
the actual current lists/APIs on both sides) whether the two surfaces genuinely share
identity, rather than assuming symmetry. This is a specific instance of this repo's own
no-overclaiming/verification discipline (`~/.claude/rules/no-overclaiming-conversational.md`
— a run, not a survey), applied to ontology authoring specifically: a real grep across
`router.ex` and `next_read_user_agent_skills.ex` is what falsified the shared-identity
assumption here, and it is the correct method for anyone authoring the next multi-surface
capability row, not a one-off fix scoped only to this pack.

## See Also

- `docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md` — the closest
  existing ggen-related how-to; documents the `sh_after`-vs-`inject:` split for
  Igniter-backed Ash codegen (a related but distinct concern from this doc's macro-expansion
  and multi-surface-identity concerns).
- `lib/xaas_web/mcp_scope.ex` — the real generated macro, its moduledoc's documented
  `plug`-inside-`scope` limitation, and the real tool list.
- `lib/xaas_web/a2a/next_read_user_agent_skills.ex` — the real generated A2A skills list and
  its regeneration command.
- `lib/xaas_web/router.ex:37,113-114` — the real `pipeline :audit_mcp_tool_call` definition
  and the real macro call site that verifies `mcp_scope.eex`'s output.
- `~/ggen_igniter/lib/ggen_igniter/reactors/reconcile_reactor.ex` (`format_generated_content/2`,
  called from `render_target/3`) — the real in-process `Code.format_string!/1` auto-format
  fix.
- `~/ggen-marketplace/packs/elixir-mcp-a2a-pack/ontology.ttl` — the real `ema:exposedVia`
  and `ema:capabilityTag` discriminator properties and their falsifying-evidence comments.
- Commit `a0ee306` ("feat(mcp/a2a): rewrite generated pieces via real ggen_igniter dogfood
  run") — the real source commit for every defect and fix cited in this guide.
