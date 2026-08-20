# Add a Real, Safe Read-Only JSON:API Route to an Ash Resource

This guide walks through the real steps to expose a read-only `GET`/`index` JSON:API route
on an existing Ash resource in this repo, using the pattern already applied to 44 of 49
resources (see `lib/kanban_web/api_router.ex`'s moduledoc) and shown concretely by
`lib/xaas/operations/capability_liveness_receipt.ex`.

## Before you start

Confirm the resource does not already have a `json_api do routes do ... end end` block —
if it does, you're done. Confirm which router will serve it:

- `lib/kanban_web/internal_api_router.ex` mounts only `Xaas.Operations`, prefixed
  `/internal-api`, guarded by `KanbanWeb.Plugs.RequireInternalApiToken`.
- `lib/kanban_web/api_router.ex` mounts all 6 domains (`Xaas.Accounts`, `Xaas.Billing`,
  `Xaas.Governance`, `Xaas.Ledger`, `Xaas.Operations`, `Xaas.Platform`), prefixed `/api`,
  also guarded by the same token plug (see `lib/kanban_web/router.ex`).

## When NOT to do this

Do not add a JSON:API route to any of these 5 resources without a real, deliberate
access-control design first (per the moduledoc of `lib/kanban_web/api_router.ex`):

- `Xaas.Ledger.Balance`, `Xaas.Ledger.Account`, `Xaas.Ledger.Transfer` — real double-entry
  financial ledger data. A generic open read exposes whose-balance-can-whom-see, which is a
  real business decision, not a mechanical one.
- `Xaas.Accounts.User`, `Xaas.Accounts.Token` — real auth/PII (`Token` holds cloaked
  `extra_data`).

These 5 were deliberately left with no `routes do ... end` block. If the resource under
change is one of these, stop here.

## Steps

### 1. Add the `routes` block inside `json_api do`

Inside the resource module, add (or extend) the `json_api do` block with a `routes do`
block naming only the read action(s):

```elixir
json_api do
  type "my_resources"

  routes do
    base "/my_resources"
    get :read
    index :read
  end
end
```

Real example, from `lib/xaas/operations/capability_liveness_receipt.ex`:

```elixir
json_api do
  type "capability_liveness_receipts"

  routes do
    base "/capability_liveness_receipts"
    get :read
    index :read
  end
end
```

Do not add `create`/`update`/`destroy` routes here — every one of the 44 mechanically
migrated resources got only `get`/`index` on `:read`; a mutating route needs a real
business decision about which action, what input validation, and what auth, which this
mechanical pattern does not make (`lib/kanban_web/api_router.ex` moduledoc).

### 2. Add the `bypass action_type(:read)` policy carve-out

The repo's floor is deny-by-default: every resource ends with a catch-all
`policy always() do forbid_if always() end`. A plain `policy` block for read access is
**not enough** to make the new route work, because of Ash's AND-of-matching-policies
semantics: when multiple policies match the same request, each one must independently
authorize it, so an `authorize_if always()` inside an ordinary `policy` block still gets
ANDed against the catch-all `forbid_if always()` below it and the request is still denied.
This was confirmed this session via a real `Ash.read/2` call that returned `{:ok, []}` with
"skipped query run due to filter being false" before switching to `bypass`.

`bypass` is different: it short-circuits. If a `bypass` block matches the request and
authorizes it, every later policy (including the catch-all) is skipped entirely for that
request. That is the real mechanism this pattern depends on:

```elixir
policies do
  bypass action_type(:read) do
    authorize_if always()
  end

  policy always() do
    forbid_if always()
  end
end
```

Place the `bypass` block before the catch-all `policy always()` block (matches the real
files under `lib/xaas/**/*.ex`).

### 3. Mount the domain in the router, if not already there

Check whether the resource's domain module is already listed in
`lib/kanban_web/api_router.ex`'s `domains:` list (`Xaas.Accounts`, `Xaas.Billing`,
`Xaas.Governance`, `Xaas.Ledger`, `Xaas.Operations`, `Xaas.Platform` are already mounted).
If the resource belongs to one of those 6 domains, no router change is needed — mounting a
domain does not itself expose anything; only resources with their own explicit
`json_api do routes do ... end end` block are served.

If the resource is internal/operational self-observability rather than customer-facing
(the `Xaas.Operations` pattern), route it through `lib/kanban_web/internal_api_router.ex`
instead (`/internal-api` prefix) rather than the customer-facing `/api` router.

### 4. Compile

```sh
cd /Users/sac/xaas
mix compile
```

Confirm 0 errors before moving on.

### 5. Verify with a real curl request

Every route under `/api` and `/internal-api` is gated by
`KanbanWeb.Plugs.RequireInternalApiToken`, which requires a `Bearer` token matching the
`INTERNAL_API_TOKEN` env var (fails closed with 503 if that var is unset, 401 if the token
is missing or wrong — see `lib/kanban_web/plugs/require_internal_api_token.ex`).

```sh
curl -s \
  -H "Authorization: Bearer $INTERNAL_API_TOKEN" \
  -H "Accept: application/vnd.api+json" \
  http://localhost:4000/api/my_resources
```

Real example against the resource used throughout this guide:

```sh
curl -s \
  -H "Authorization: Bearer $INTERNAL_API_TOKEN" \
  -H "Accept: application/vnd.api+json" \
  http://localhost:4000/internal-api/capability_liveness_receipts
```

A 200 with a JSON:API `data` array confirms the route, the policy bypass, and the router
mount are all wired correctly. A 401 means the token header is missing/wrong; a 503 means
`INTERNAL_API_TOKEN` is unset on the server; a 404 means the domain isn't mounted in the
router being hit, or the route block wasn't added.

## See Also

- `lib/xaas/operations/capability_liveness_receipt.ex` — the real resource this guide's
  code examples are drawn from
- `lib/kanban_web/api_router.ex` — customer-facing router, real list of excluded resources
  and why
- `lib/kanban_web/internal_api_router.ex` — internal-only router (`Xaas.Operations`)
- `lib/kanban_web/router.ex` — real pipeline/scope wiring, including the real ordering
  requirement that `/internal-api`'s explicit routes be declared before the catch-all
  `forward "/internal-api"`
- `lib/kanban_web/plugs/require_internal_api_token.ex` — the real auth gate
- `docs/ASH-MIGRATION-PLAN.md` — Phase 5 deny-by-default floor and the still-open
  customer-facing mutation-surface decision (Phase 5 item 2)
