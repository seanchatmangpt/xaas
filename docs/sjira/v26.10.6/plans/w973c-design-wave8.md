# W973c — design-wave 8 receipt (SPEC-31, partial-land)

Standing: **PARTIAL_ALIVE** (implementation + court executed on the lane build root;
uncommitted, shared tree). NOT LANDED-COMMITTED — coordinator owns the commit.

## Identity

- Lane: W973c, xaas v26.10.6, checkout `/Users/sac/xaas` @ `fc14f10b` + in-flight tree.
- Spec: SPEC-31 (W819/W802-GAP-2 — wire remaining 16 of 19 domains into
  `Xaas.GraphqlSchema`), claimed in the W971a tracking table as IN-FLIGHT (w973c), now
  LANDED-UNCOMMITTED.
- Toolchain: asdf elixir 1.20.2-otp-28, `MIX_ENV=test`,
  `MIX_BUILD_ROOT=_build-laneW973c`.

## SPEC-07 collision (disclosed, not claimed)

SPEC-07's surface was NOT lane-free at claim time: `git status` showed uncommitted
W975b edits (multitenancy blocks) on `lib/xaas/billing/{subscription,
approval_sla_credit_apply,approval_patch_sla_credit_apply,revenue_recognition}.ex` plus
code comments naming lane W975b design-wave 4. No W975b receipt file existed on disk at
claim time. w973c touched zero billing multitenancy surfaces; a W969f adjudication was
subsequently appended to the SPEC-07 table row. The only other lane-free M PENDING spec
was SPEC-31 (all of SPEC-24/26/30/32 surface files are on the banned list). **One spec,
not two — collision + bans, disclosed, per stop-and-disclose.**

## What landed (SPEC-31, partial by disclosure)

- `lib/xaas/graphql_schema.ex`: `domains:` list extended 3 → 19 (all 16 remaining
  domains added; Marketplace got its Pack resource wired — it was already in the list).
  Compile gate: all 16 compile green under AshGraphql 1.12.0
  (`mix compile`, exit 0). Zero domain-level UNSUPPORTED at the schema list level.
- Discovery (falsifier-grade, from the compiled schema): adding domains alone is a
  no-op on the query surface — AshGraphql generates root fields only from resource
  `queries do` blocks. Pre-change root fields: `library_book(s)`, `project_measure_json`,
  `say_hello`. Operations/Marketplace were wired-in-name-only at the root-field level.
- 5 of 16 remaining domains exposed with real read queries (get + list each),
  one resource per domain, chosen lane-free + non-sensitive (wired count 8/19):
  - Accounts → `lib/xaas/accounts/org.ex` (`org`/`orgs`)
  - Billing → `lib/xaas/billing/approval_pricing_override.ex` (Subscription itself is
    W975b-collided; Transfer deliberately unwired — sensitive resource, no mechanical
    exposure per CLAUDE.md)
  - Conference → `lib/xaas/conference/event.ex` (`conference_event(s)`)
  - Governance → `lib/xaas/governance/freeze_window.ex` (`freeze_window(s)`)
  - Marketplace → `lib/xaas/marketplace/pack.ex` (`marketplace_pack(s)`)
  - Platform → `lib/xaas/platform/webhook.ex` (`webhook(s)`; url/secret stay cloaked and
    deny-by-default; query bindings add no bypass)
- Court: `test/xaas/graphql_domain_wiring_court_test.exs` — per-domain real
  `Absinthe.run/3` through the REAL compiled schema (no plug, no mock): field-presence
  on the compiled query type + one real query per domain + library baseline pin.
  Falsifier: dropped domain/queries block ⇒ unknown-field error ⇒ court fails.
- `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md` tracking table: SPEC-07 marked
  IN-FLIGHT (COLLISION, W975b); SPEC-31 IN-FLIGHT→LANDED-UNCOMMITTED (w973c).

## Verification ladder (real output)

- `mix compile` (lane build root, all 16 domains): exit 0.
- `mix run -e` root-field census after wiring: `approval_pricing_override(s)
  conference_event(s) freeze_window(s) library_book(s) marketplace_pack(s) org(s)
  project_measure_json say_hello webhook(s)` — 12 new root fields present.
- Court suite ×2, both green:
  `mix test test/xaas/graphql_domain_wiring_court_test.exs test/xaas/graphql_schema_test.exs`
  → `Result: 4 passed` (run 1), `Result: 4 passed` (run 2).
- Observed per-domain query outcomes (real, anonymous actor): orgs/conference_events/
  freeze_windows/marketplace_packs/webhooks resolve REAL keyset pages from the real DB;
  approval_pricing_overrides refuses through AshGraphql typed masking
  (`something_went_wrong` = masked Ash refusal, real policy floor, not a skipped query
  and not an unknown-field error). Not uniform-by-design; recorded as observed.

## UNSUPPORTED / deferred disclosures

- 11 domains (A2a, Coupling, Graphlaw, Generation, Igniter, Ledger, Ocel, Security,
  TemporalMemory, Ultracode, Witness) carry no
  resource with the `AshGraphql.Resource` extension, so query wiring = extension add +
  graphql block per resource — beyond M for this lane → **UNSUPPORTED(graphql-extension-absent)**,
  not forced.
- SPEC-30 HTTP transport leg (router.ex banned this wave): court is in-process
  Absinthe; HTTP court + `docs/claude/diataxis/reference/http-api-surface.md` "GraphQL
  surface status" flip deferred to the SPEC-30 lane (that file also has concurrent-lane
  uncommitted edits — collision avoided). Diataxis count stays "3 of 19" until the
  SPEC-30 lane flips it from real output.
- Sensitive: `Xaas.Ledger.Transfer` deliberately NOT exposed (CLAUDE.md sensitive-resource
  discipline).

## Transport failures observed

- Two transient compile breaks from another lane's mid-edit `lib/xaas/bridges/graphlaw.ex`
  (SPEC-10 surface); resolved upstream; lane retried after stabilization.
- Concurrent W975b edits landed on `approval_pricing_override.ex` mid-lane; my queries
  block survived; final compile + court runs cover the merged file.

## Replay

```
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW973c mix compile
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW973c \
  mix test test/xaas/graphql_domain_wiring_court_test.exs test/xaas/graphql_schema_test.exs
# expect: Result: 4 passed
```

## Cleanup

`_build-laneW973c` deleted at lane close per fanout cleanup law (see final section —
deleted after receipt write, before this receipt's final save).
