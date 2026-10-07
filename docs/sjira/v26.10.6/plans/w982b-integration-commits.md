# W982b — Integration commits receipt (v26.10.6)

Lane: W982b (integration commits, coordinator-delegated). Branch
`feat/playwright-surface`. Date 2026-10-07.

## Standing

- SPEC-30 GraphQL-over-HTTP: **ALIVE** (committed + court passed at HEAD).
- SPEC-31 domain wiring: **ALIVE** (committed + court passed at HEAD).
- W976 LimitGate: **ALIVE** (committed + court passed at HEAD).
- W970a SPEC-07 billing multitenancy: **ALIVE** (restored/landed after
  integration error; court files landed, full billing court run left to
  the owner lane's own receipt — see exclusions).
- Full-tree strict compile gate: **ALIVE** — `mix compile --force
  --warnings-as-errors` EXIT=0 (sole warning is the sibling path-dep
  `../ash_affidavit` `@envelope_domain_tag` unused-attribute, which does
  not inherit the app's `--warnings-as-errors` and is non-fatal,
  disclosed).

## Commits (in order)

| # | SHA | workstream | owner receipt |
|---|---|---|---|
| 1 | 691e0a93 | SPEC-30 GraphQL-over-HTTP surface | w975b-design-wave4.md |
| 2 | ddb19522 | W970a SPEC-07 billing multitenancy (restore/land after sweep) | w970a-design-wave6.md |
| 3 | 39e9d77f | SPEC-31 domain wiring | w973c-design-wave8.md |
| 4 | f9c4f090 | W976 LimitGate | w976-design-wave5.md |

## Staged paths per commit

1. `691e0a93` — lib/xaas_web/router.ex, mix.exs,
   test/xaas_web/graphql_http_surface_test.exs. **Error disclosed**: the
   commit used the shared index, which also held another lane's staged
   rollback of SPEC-07; it swept in a revert of W970a's landed billing
   multitenancy (approval_* resources, org_id migration,
   billing_multitenancy_court_test.exs deletion). No content lost —
   working tree intact — fixed forward in `ddb19522`, which commits the
   full W970a workstream.
2. `ddb19522` — lib/xaas/billing/{approval_invoice_reconciliation_approve,
   approval_patch_sla_credit_apply, approval_pricing_override,
   approval_quota_override, approval_sla_credit_apply,
   approval_tier_downgrade, revenue_recognition, subscription}.ex,
   priv/repo/migrations/20261007250000_add_org_id_to_billing_approval_tables.exs,
   test/xaas/billing/{billing_multitenancy_court_test,
   approval_lifecycle_deepening_court_test,
   approval_tier_downgrade_controller_test}.exs. The pricing_override
   SPEC-31 queries hunk rides in this commit (working-tree version
   committed wholesale), so commit 3's planned partial staging was not
   needed. All subsequent commits used explicit pathspec commits
   (`git commit -- <paths>`), immune to shared-index state.
3. `39e9d77f` — lib/xaas/graphql_schema.ex, lib/xaas/accounts/org.ex,
   lib/xaas/conference/event.ex, lib/ex.../speaker.ex (keynote?
   public?: false fix), governance/freeze_window.ex,
   marketplace/pack.ex, platform/webhook.ex,
   test/xaas/graphql_domain_wiring_court_test.exs.
4. `f9c4f090` — lib/xaas/graphlaw/limit_gate.ex,
   lib/xaas/bridges/graphlaw.ex (W976 depth gate + W981k byte-limit
   extension included with disclosure; W981k had not landed its own
   commit at integration time), lib/xaas/lib.../registry.ex
   (engine_limits/0), test/xaas/graphlaw_limit_gate_test.exs.

## Gates (real output)

- Tree-wide strict gate: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW982b mix compile --force
  --warnings-as-errors` → **EXIT=0** (log /tmp/w982b-compile-force2.log;
  an earlier run at 09:21 FAILED on W982a's then-in-flight
  registration.ex DslError — pre_check_with removal — W982a fixed it
  themselves by 09:44; gate re-run clean).
- SPEC-30 court: `mix test test/xaas_web/graphql_http_surface_test.exs`
  → **5 passed**.
- SPEC-31 court: `mix test test/xaas/graphql_domain_wiring_court_test.exs
  test/xaas/conference/keynote_graphql_surface_court_test.exs` →
  **6 passed**.
- W976 court: `mix test test/xaas/graphlaw_limit_gate_test.exs` →
  **10 passed**.

## Exclusions (lane collisions)

- `lib/xaas/ocel/event.ex`, `lib/xaas/security/finding.ex` (SPEC-31
  deepening marked "lane W982a"), `lib/xaas/conference/registration.ex`,
  `test/xaas/conference/enrollment_journey_court_test.exs`,
  `test/xaas/conference/keynote_graphql_surface_court_test.exs` — owner
  W982a; excluded while their lane was in flight. W982a's receipt
  (w982a-conference-graphql-deepening.md) landed during integration;
  their files remain uncommitted for their own landing.
- W981k graphlaw byte-limit extension: freshness check passed (file
  untouched >5 min), included in commit 4 with disclosure in the commit
  message.
- Concurrent lane `w982k` also landed integration commits on this branch
  during my run (bf9f5cb9) — no overlap with my paths.

## Cleanup

`_build-laneW982b` deleted at integration (lane-build-root lease law).
