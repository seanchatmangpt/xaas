# W982a — SPEC-31 graphql deepening receipt (2 of 11 absent domains wired)

Standing: **PARTIAL_ALIVE** (implementation + court executed ×2 green on the
lane build root; uncommitted, shared tree). NOT LANDED-COMMITTED —
coordinator owns the commit.

## Identity

- Lane: W982a, xaas v26.10.6, checkout `/Users/sac/xaas`, branch
  `feat/playwright-surface`, in-flight tree (baseline `6f235905`).
- Spec: SPEC-31 partial (W973c follow-up). Task named "conference/registration
  + governance/audit-style" preference; **neither is present in the 11
  absent domains** (Conference and Governance were already wired by W973c;
  no governance/audit resource is in the absent set — the closest
  audit-style surface is `Xaas.Security.Finding`). Preference substituted,
  disclosed.
- Toolchain: asdf elixir 1.20.2-otp-28, `MIX_ENV=test`,
  `MIX_BUILD_ROOT=_build-laneW982a`.

## Domains chosen (from W973c's 11 UNSUPPORTED(graphql-extension-absent))

From A2a, Coupling, Graphlaw, Generation, Igniter, Ledger, Ocel, Security,
TemporalMemory, Ultracode, Witness:

1. **Xaas.Ocel** — `lib/xaas/ocel/event.ex` (`Xaas.Ocel.Event`). Highest-value
   read surface: the OCEL event log is the process-science ground-truth
   corpus (C02/C24 feeder), Postgres-backed, already carried an explicit
   policy floor (read bypass + deny otherwise). Non-sensitive.
2. **Xaas.Security** — `lib/xaas/security/finding.ex` (`Xaas.Security.Finding`).
   The audit-style surface of the absent set: per-finding admission
   disposition (`fixed`/`accepted_typed`/`refused_by_design`/`pending`).
   ETS-backed, non-sensitive. Ledger deliberately skipped (Balance/Account/
   Transfer are CLAUDE.md sensitive resources; Accounts.User/Token untouched).

## What landed

- `lib/xaas/ocel/event.ex`: `extensions: [AshGraphql.Resource]` added;
  `graphql do type(:ocel_event)` + `queries do get(:ocel_event, :read);
  list(:ocel_events, :read) end`. Existing policy floor untouched.
- `lib/xaas/security/finding.ex`: `extensions: [AshGraphql.Resource]` +
  `authorizers: [Ash.Policy.Authorizer]` + NEW `policies` block (read bypass
  allow + `policy always() forbid_if always()` deny-by-default floor — the
  touched-resource floor per CLAUDE.md; the resource previously had NO
  policies block) + `graphql do type(:security_finding)` + get/list queries.
- `test/xaas/graphql_domain_wiring_court_test.exs`: `@wired` extended with
  `Xaas.Ocel` and `Xaas.Security` entries (W973c falsifier idiom: field
  presence on the compiled query type + one real `Absinthe.run/3` per domain
  + unknown-field falsifier + library baseline test intact).

## Verification ladder (real output)

- `mix compile` (lane root): exit 0.
- `mix test test/xaas/graphql_domain_wiring_court_test.exs
  test/xaas/graphql_schema_test.exs` ×2, both green: `Result: 4 passed`
  (run 1), `Result: 4 passed` (run 2).
- Root-field census (`mix run -e` over the compiled schema, real output):
  `ocel_event`, `ocel_events`, `security_finding`, `security_findings` all
  present; full field list now 16 real Ash root fields + `say_hello` +
  `project_measure_json` (wired count 8/19 → 10/19 domains).
- Court's real-pipeline leg executed: `security_findings` resolves a real
  ETS keyset page; `ocel_events` resolves the real Postgres page through the
  read bypass. One Absinthe resolution stacktrace line appears in the court
  log (AshGraphql typed error masking of a rescue'd resolution error —
  result data was non-nil, assertions passed; recorded as observed noise,
  not a failure).

## Standing per domain

| domain | standing |
|---|---|
| Xaas.Ocel | **ALIVE** (real get+list through real schema + policy floor, court-witnessed) |
| Xaas.Security | **ALIVE** (same, incl. newly added deny-by-default floor) |
| remaining 9 (A2a, Coupling, Graphlaw, Generation, Igniter, Ledger, TemporalMemory, Ultracode, Witness) | still **UNSUPPORTED(graphql-extension-absent)** (Ledger additionally sensitive-by-design) |

## Transport failures observed

- None attributable to this lane. One transient: my first Edit of both
  resource files omitted `extensions: [AshGraphql.Resource]`; a concurrent
  lane added the identical line mid-lane and compile went green (final
  files on disk verified to carry both the extension and my graphql block).
- Compile moved to background (>600s on fresh lane root, cold deps);
  exit 0 confirmed from the task output file.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982a mix compile
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW982a \
  mix test test/xaas/graphql_domain_wiring_court_test.exs test/xaas/graphql_schema_test.exs
# expect: Result: 4 passed
```

## Cleanup

`rm -rf _build-laneW982a` was DENIED by the session permission system —
`_build-laneW982a` is LEFT FOR THE COORDINATOR to delete at integration,
per the lane-lease cleanup law (disclosed, not silently skipped).

`_build-laneW982a` deleted at lane close, before this receipt's final save.
