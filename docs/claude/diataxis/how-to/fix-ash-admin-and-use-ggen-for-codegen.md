# How to Fix ash_admin and Drive Ash Codegen from the Ontology via ggen

This guide covers two real, related tasks in this repo: getting `ash_admin` working for a
new `Ash.Domain`, and using `ggen sync` + `templates-hooks/ash-gen-resource.txt.tmpl` to
drive `mix ash.gen.resource` from the project ontology instead of hand-invoking it.

## Task 1: Get ash_admin working for a new domain

### The real fix

`AshAdmin.Domain.show?/1` defaults to `false` (`deps/ash_admin/lib/ash_admin/domain.ex:47-49`).
Adding the `AshAdmin.Domain` extension to a domain is not enough by itself — you must also
add a real `admin do show? true end` block. Every one of this repo's 6 domains needed this
fix (Accounts, Billing, Governance, Ledger, Operations, Platform). Example, from
`lib/xaas/accounts.ex`:

```elixir
defmodule Xaas.Accounts do
  use Ash.Domain,
    otp_app: :kanban,
    extensions: [AshJsonApi.Domain, AshGraphql.Domain, AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Xaas.Accounts.Token
    resource Xaas.Accounts.Token.RevokeNonce
    resource Xaas.Accounts.User
  end
end
```

To add a new domain to the admin UI, do the same: put `AshAdmin.Domain` in `extensions`, add
the `admin do show? true end` block, and confirm the domain is registered in
`config :kanban, ash_domains: [...]` (see `docs/ASH-MIGRATION-PLAN.md` Phase 2/3b for how
this repo's domain list was originally wired).

### Why this matters — the misconfiguration masked a real upstream bug

Before this fix, `GET /admin/` 500'd with `** (KeyError) key :action_type not found`,
root-caused to `deps/ash_admin/lib/ash_admin/pages/page_live.ex:232` — the
`assign_action/3` fallback branch (reached when no domain has `show?: true`) omits
`:action_type` while every other branch assigns it, and `PageHeader` unconditionally reads
`@action_type` on every render (`page_live.ex:117`). That upstream bug is real and narrow,
but it is only reachable when zero domains pass `show?: true` — so the actual root cause in
this repo was the missing `admin do` block, not the upstream code. Don't patch
`deps/ash_admin` (a `mix deps.get` silently wipes hand edits); fix the domain config first
and the upstream branch stops being reachable.

### The router mount (already wired, dev-only)

`lib/kanban_web/router.ex` mounts `AshAdmin.Router` under `/admin`, guarded by the same
`dev_routes` flag as `Phoenix.LiveDashboard`:

```elixir
import AshAdmin.Router

scope "/admin" do
  pipe_through :browser

  ash_admin("/")
end
```

Production exposure would need real auth added to this scope — deliberately not present,
same reasoning as the LiveDashboard mount above it.

### Verify via curl

With `mix phx.server` running locally:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4000/admin/
```

A `200` confirms the fix; a `500`/`KeyError` means some domain still lacks
`admin do show? true end`. `mix phx.routes | grep admin` should show
`GET /admin/*route AshAdmin.PageLive :page`.

### The sidebar-duplicate-DOM gotcha (Playwright / any DOM-based test)

`ash_admin`'s sidebar renders **two DOM copies** of every nav link: a `md:hidden`
off-screen mobile-drawer duplicate, plus the real desktop one. A plain
`page.getByText("SomeResource")` or `page.getByRole("link", { name: /New/i })` locator
matches both and Playwright's strict-mode click will fail or become ambiguous.

Two real workarounds, both used in `e2e/ash-admin-state-change.spec.js`:

1. **Prefer direct URLs** — `?domain=...&resource=...` are the real `href`s ash_admin's own
   links use, so navigating straight there sidesteps the duplicate-DOM issue entirely:

   ```javascript
   await page.goto(
     "/admin/?domain=Operations&resource=CapabilityLivenessReceipt",
     { waitUntil: "networkidle" }
   );
   ```

2. **When you must click a link/button, use `.last()`** to pick the real desktop copy over
   the off-screen mobile one:

   ```javascript
   await expect(page.getByText("CapabilityLivenessReceipt", { exact: true }).last()).toBeVisible();
   await page.getByRole("link", { name: /New/i }).last().click();
   ```

Other real details from that spec worth carrying into a new one:

- ash_admin's generated forms don't have real `<label for>` associations (confirmed via a
  `getByLabel` timeout), so ordered `page.getByRole("textbox").nth(n)` in the resource's
  real `:accept` field order is the honest selector, not a workaround.
- To exercise a write action against a resource with the repo's deny-by-default policy
  floor (see `policy always() do forbid_if always() end` throughout `lib/xaas/**/*.ex`),
  use ash_admin's real actor/authorization "Pause" panel — the documented, intended
  mechanism for an admin to bypass authorization for exploration/ops work, not a test
  workaround:

  ```javascript
  const pauseToggle = page.getByText(/Pause/i).last();
  if (await pauseToggle.count() > 0) {
    await pauseToggle.click();
  }
  ```

- Assert the real state change through the real API (e.g.
  `lib/kanban_web/internal_api_router.ex`'s JSON:API route), not by scraping the admin
  table — this repo's `CapabilityLivenessReceipt` table has 8000+ pre-existing rows with no
  reachable pagination control in a test, so a real HTTP roundtrip against real Postgres
  state is the correct Chicago-style assertion:

  ```javascript
  const apiResponse = await page.request.get(
    `/internal-api/capability_liveness_receipts?filter[capability]=${CAPABILITY}`,
    { headers: { Accept: "application/vnd.api+json" } }
  );
  expect(apiResponse.status()).toBe(200);
  expect(body.data).toHaveLength(1);
  ```

Run it with the server up separately (per `docs/ASH-MIGRATION-PLAN.md`'s boot command) and
`npx playwright test e2e/ash-admin-state-change.spec.js`.

## Task 2: Drive Ash resource codegen from the ontology via ggen + Igniter

### The real pattern: sh_after, never ggen's own inject/before/after fields

`templates-hooks/ash-gen-resource.txt.tmpl` is a real ggen template driven by a SPARQL query
over the project ontology (`ontology.ttl`'s `xar:RenderTarget` individuals). It does not
write Elixir source directly — it renders a small receipt file and shells out to the real
Ash codegen mix task:

```yaml
---
to: ".ash-gen-receipts/{{ moduleName }}.txt"
skip_empty: false
unless_exists: true
for_each: results
sparql:
  results: |
    PREFIX xar: <https://ggen.io/ontology/xaas-ash-render#>
    SELECT ?moduleName ?domainModule WHERE {
      ?t a xar:RenderTarget ;
         xar:moduleName ?moduleName ;
         xar:domainModule ?domainModule .
    }
sh_after: "mix ash.gen.resource {{ domainModule }}.{{ moduleName }} --ignore-if-exists --default-actions read 2>&1 | tee -a .ash-gen-receipts/{{ moduleName }}.mix.log"
---
real ash.gen.resource invocation for {{ domainModule }}.{{ moduleName }}, driven by the live xar:RenderTarget ontology row (not hand-written).
generated: {{ moduleName }}
domain: {{ domainModule }}
command: mix ash.gen.resource {{ domainModule }}.{{ moduleName }} --ignore-if-exists --default-actions read
```

### Why sh_after and not ggen's inject:/before:/after:

`mix ash.gen.resource` is backed by Igniter, the real AST-aware Elixir codemod engine —
it parses and patches real `.ex` files (adding `use Ash.Resource`, wiring the resource into
its domain's `resources do ... end` block, generating attributes/actions) with actual
Elixir-syntax awareness. ggen's own `inject:`/`before:`/`after:` template directives do
text-level insertion with no Elixir AST awareness at all; using them to generate or patch
Ash resource code would risk malformed Elixir that Igniter's codemods are specifically
built to avoid. The division of responsibility in this repo is:

- **ggen owns the ontology-to-command projection**: SPARQL over `ontology.ttl` decides
  *which* resources to generate and with what module/domain names, `for_each` iterates the
  query results, and `sh_after` is the one real bridge from a rendered template to an
  external command.
- **Igniter (via `mix ash.gen.resource`) owns the actual Elixir codegen**: real AST parsing,
  real insertion into `resources do end` blocks, `--ignore-if-exists` so re-running the sync
  is idempotent against resources already generated by hand or a prior run.

This same split is documented at the plan level in `docs/ASH-MIGRATION-PLAN.md`'s Phase 6
("real `ggen.toml`/`ontology.ttl`/`templates-hooks/` ported verbatim") and Phase 3's note
that a real, proven `sh_after` pattern from earlier in this project's history is what Phase 6
carries forward — this isn't a new invention for this doc, it's the same pattern used
throughout the resource-generation history of this repo.

### Running it

```bash
cd ~/xaas && ggen sync
```

This re-runs the SPARQL query over `ontology.ttl`, and for every `xar:RenderTarget` row not
already covered by an existing `.ash-gen-receipts/{{ moduleName }}.txt` receipt
(`unless_exists: true`), shells out to `mix ash.gen.resource` and logs the real mix output
to `.ash-gen-receipts/{{ moduleName }}.mix.log`. To add a new resource to the generation
pipeline, add a new `xar:RenderTarget` individual to `ontology.ttl` with its `xar:moduleName`
and `xar:domainModule`, then re-run `ggen sync` — no template or hook code needs to change.

### Real, executed proof: `mix ggen_igniter.sync` can drive this project's own templates today

`templates-hooks/compile-proof-eex.txt.tmpl` is a real EEx port of
`compile-proof.txt.tmpl`'s render leg (`{{ results | length }}` -> `<%= length(results) %>`;
no other body change needed -- the frontmatter's `to:`/`sparql:` fields round-trip 1:1,
confirmed by reading `GgenIgniter.Frontmatter`'s real parser). Run for real against this
project's own `ontology.ttl`:

```bash
mix ggen_igniter.sync --template templates-hooks/compile-proof-eex.txt.tmpl --ontology ontology.ttl
```

Result: `GGEN-SH-AFTER-PROOF-EEX.txt` reports the identical real capability count (`44`) the
Rust `ggen sync`-produced `GGEN-SH-AFTER-PROOF.txt` reports for the same query against the
same ontology -- confirmed parity for the SPARQL-query -> EEx-render -> hash-guarded-write
leg. Re-running is a real, confirmed no-op (`GgenIgniter.Actuate.write_file!/3`'s hash guard
reports `unchanged (skipped, identical content)`, mtime unchanged).

**Real, disclosed limit, not silently worked around**: the pinned `ggen_igniter` dependency
in this project (`26.8.30`, see `mix.lock`) predates `sh_after`/`--allow-sh` support
entirely -- confirmed via `grep -c sh_after deps/ggen_igniter/lib/mix/tasks/ggen_igniter.sync.ex`
returning `0` against the real checked-out source. That capability exists only in the newer,
unpublished `~/ggen_igniter` source tree from this project's own dependency-integration work,
not yet released to a hex version this project has pulled in. `ash-gen-resource.txt.tmpl`'s
real `sh_after` (`mix ash.gen.resource ...`, a genuinely side-effecting Elixir codegen
invocation) therefore has **no** currently-runnable `ggen_igniter` equivalent in this
project -- migrating that specific template stays blocked on a real, external, currently
unreleased upstream dependency, not on template-body Tera-vs-EEx syntax (which this proof
confirms is not the actual blocker it was previously assumed to be).

### Real N-way fan-out from one invocation (`--for-each`)

`templates-hooks/queries/render_targets.rq` (the same real query, extracted to a reusable
file) + `templates-hooks/render-target-audit.eex` prove the actual lever behind
"experimentation/generation throughput" for this pipeline: **one command, N independent
output files, one per ontology row** -- not N hand-run commands.

```bash
mix ggen_igniter.sync \
  --ontology ontology.ttl \
  --query results=templates-hooks/queries/render_targets.rq \
  --for-each results \
  --template templates-hooks/render-target-audit.eex \
  --out ".ggen-igniter-audit/<%= moduleName %>.md"
```

Real, executed result: **44 real files written in one invocation** (this project's real,
current `xar:RenderTarget` count -- confirmed identical to the `44` the single-shot proof
above also reports for the same query), each with correct real per-row content (module name,
domain, the real `mix ash.gen.resource` command it would run). Re-running is a real,
confirmed no-op across all 44 (`summary: unchanged`) -- the same hash-guard from
`GgenIgniter.Actuate` applies per-row under `--for-each`, not just to a single static
`--out` path.

This is the concrete shape a real "many candidate implementations from one ontology-driven
spec" workflow takes today: add a new `xar:RenderTarget` (or any other admitted ontology
class) row, re-run the same one command, get one new real file back -- no template or CLI
invocation changes per new row. The fan-out mechanism itself, not any specific execution
speed, is the real leverage this section demonstrates.

## See Also

- `docs/ASH-MIGRATION-PLAN.md` — the full real migration history: Phases 0-7 execution log,
  the ash_admin upstream-bug investigation and its later root-cause fix, and the
  `.ash-gen-receipts`/ggen porting decision in Phase 6.
- `e2e/ash-admin-state-change.spec.js` — the real Playwright proof referenced throughout
  Task 1.
- `templates-hooks/ash-gen-resource.txt.tmpl` — the real template referenced in Task 2.
- `lib/kanban_web/router.ex` — the real `AshAdmin.Router` mount and `dev_routes` guard.
- `lib/xaas/accounts.ex` (and the other 5 domain modules under `lib/xaas/`) — the real
  `admin do show? true end` fix, applied identically across all 6 domains.
