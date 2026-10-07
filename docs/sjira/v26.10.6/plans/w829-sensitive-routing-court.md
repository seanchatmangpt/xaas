# W829 — Sensitive-Resources Routing Court

**Repo**: /Users/sac/xaas (canonical checkout, branch `feat/playwright-surface`, HEAD `a0723bf6`)
**Lane**: W829, v26.10.6 campaign
**Status**: PARTIAL_ALIVE (court ALIVE on exact subject; one typed gap, see Gaps)

## Subject

- New file: `test/xaas_web/sensitive_resources_routing_court_test.exs` (handwritten,
  no generator path exists for routing-court tests — irreplaceable residue)
- Receipt: this file. No commits (per lane contract; coordinator owns transitions).

## What the court pins

Doctrine (CLAUDE.md "Sensitive resources") says Ledger.Balance/Account/Transfer and
Accounts.User/Token are "deliberately unwired from /api" but it was uncourted as a
routing fact. This court converts it to a real assertion over the real, compiled
route tables:

- (a) No route path segment or helper/label in any of `XaasWeb.Router`
  (`Phoenix.Router.routes/1`), `XaasWeb.ApiRouter` /
  `XaasWeb.InternalApiRouter` (`AshJsonApi.Router.formatted_routes/1` — these are
  Plug.Router catch-alls; `Phoenix.Router.routes/1`/`__routes__/0` is undefined on
  them, which is itself a documented finding) references the sensitive segments
  `balances | accounts | transfers | users | tokens` (exact segment equality —
  deliberately not substring, so `audit_export_tokens` (Governance, wired) does not
  false-positive).
  - Vacuity guard: every introspection asserts a non-empty route table.
  - `/internal-api` in the parent router registers only capability/fabric/rpc
    controller routes; sensitive segments absent.
- (b) Deliberately-wired exceptions ARE present: `POST /orgs` (Org.create),
  `PATCH /orgs/:id` (Org.update), `GET /orgs` (Org.read) in the ApiRouter table
  (`formatted_routes/1` paths exclude the `/api` mount prefix; verbs are lowercase
  atoms; placeholder segment is `":id"`).
- (c) W813 typescript_rpc pin: `rpc_action/2` declarations are extracted live from
  `lib/xaas/*.ex` domain sources and asserted (1) free of sensitive tokens
  (user/token/balance/transfer/ledger_account) and (2) equal to the pinned
  allow-list `list_marketplace_providers, list_accounts_orgs,
  list_billing_subscriptions, measure_project`. Drift in either direction fails.
- (d) Determinism: introspection asserted equal across repeated in-test calls, and
  the file was run twice (default seed + seed 987654).

## Verification (real output)

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW829 \
    mix test test/xaas_web/sensitive_resources_routing_court_test.exs
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 5 passed

$ ... mix test test/xaas_web/sensitive_resources_routing_court_test.exs --seed 987654
Result: 5 passed
```

Mock gate: no mocks/stubs; real module introspection only (Chicago-style).

## Standing

- Court: **ALIVE** on exact subject (both real runs green on HEAD a0723bf6).
- Sensitive-resources routing doctrine: **courted** (was UNKNOWN/uncourted).

## Typed gaps

- GAP(environment): the court asserts compiled route tables, not live-HTTP
  dispatch. A runtime misconfiguration that bypasses the routers entirely (e.g. a
  new `forward` around them) on a path not matching sensitive segments would not
  be seen. Narrow falsifier would be a ConnCase dispatch probe (out of lane scope,
  HTTP-level).
- GAP(sibling-drift): the rpc pin reads `lib/xaas/*.ex` source text by regex, not
  the compiled Ash domain DSL; a semantically-equivalent but textually different
  rpc declaration form would read as drift. Accepted (grep-grade pin was the
  order).
- Note (transport): `rm -rf _build-laneW829` was denied by the session permission
  system; the lane build root is left in place for coordinator cleanup per the
  fanout cleanup law.
