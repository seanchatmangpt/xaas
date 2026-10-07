# W982l — spec-ledger reconciliation pass — receipt

- Lane W982l, xaas v26.10.6, repo `/Users/sac/xaas`, branch `feat/playwright-surface`
  (HEAD `6f235905` + dirty campaign tree). Doc-only lane: 2 files edited, 1 receipt
  minted, zero lib/test edits, zero build roots, no commit (coordinator owns commits).
- Task: re-verify each W905 DESIGN/L spec's true landed state from disk evidence
  (receipt files present, commit SHAs real via `git log`, implementation surfaces
  grepped on tree), flip statuses in
  `docs/sjira/v26.10.6/plans/w905-design-gap-specs.md`, do the SPEC-30 diataxis flip
  in `docs/claude/diataxis/reference/http-api-surface.md` (verified NOT already done
  by W981m: zero graphql mentions in that file before this lane; ash-configuration.md
  still reads `UNSUPPORTED(graphql-http-surface)`).

## Spec → evidence table (all evidence re-read from disk this session)

| spec | status | evidence (all verified W982l) |
|---|---|---|
| SPEC-04 | LANDED-COMMITTED | commit `5a853130` real (`git log`); receipt `w969b-design-wave2.md` on disk; `lib/xaas_web/plugs/authenticate_org.ex` on tree |
| SPEC-18 | LANDED-COMMITTED | same commit `5a853130`; same receipt (check + wiring + court) |
| SPEC-14 | LANDED-COMMITTED | commit `fd471722` real; receipt `w968c-design-wave1.md` NOW ON DISK (corrects W971a's "receipt absent" note) |
| SPEC-27 | LANDED-COMMITTED | commit `352cc34c` real; same receipt; `lib/xaas/ledger/changes/reverse_transfer.ex` on tree |
| SPEC-16 | LANDED-COMMITTED | commits `fab56ae1` + `c3df69a8` real; receipt `w935-spec16-impl.md` on disk |
| SPEC-17 | LANDED-COMMITTED | `fab56ae1` (closed in-lane per receipt §SPEC-17 disposition; `c3df69a8` adjacent hardening) |
| SPEC-21 | LANDED-COMMITTED | commits `b2758300` + `fc14f10b` real; receipt `w969c-design-wave3.md`; `route_projects_create_court_test.exs` in `b2758300` diff stat |
| SPEC-09 | LANDED-COMMITTED | commit `aa2b4022` real (pre-wave, W912) |
| SPEC-20 | LANDED-COMMITTED | commit `b2758300`; receipt `w970b-open-sweep.md` row 1; disclosed shape deviation: `destroy :purge_expired` + retain_until validation, not generic `:update`/`:destroy` |
| SPEC-24 | LANDED-COMMITTED | commit `b2758300`; receipt `w970b-open-sweep.md` row 2; Incident-side `castle_run_id` + migration (spec's predicted landing shape) |
| SPEC-26 | LANDED-COMMITTED | commit `b2758300`; receipt `w970b-open-sweep.md` row 3; hold `:fulfill` mints real Checkout in-transaction |
| SPEC-10 | LANDED-UNCOMMITTED | receipt `w976-design-wave5.md` on disk; `lib/xaas/graphlaw/limit_gate.ex` + 2 consumer wires on tree |
| SPEC-30 | LANDED-UNCOMMITTED | receipt `w975b-design-wave4.md` §SPEC-30; `lib/xaas_web/router.ex:302-313` Absinthe.Plug forward, `mix.exs:148` absinthe_plug dep, `test/xaas_web/graphql_http_surface_test.exs` all on tree |
| SPEC-31 | LANDED-UNCOMMITTED | receipt `w973c-design-wave8.md`; `graphql_schema.ex` 19 domains (grep-verified); court `test/xaas/graphql_domain_wiring_court_test.exs` on tree |
| SPEC-07 | STILL-PENDING (PARTIAL, regression) | W970a's 4 resources wired UNCOMMITTED (multitenancy blocks at `approval_pricing_override.ex:97`, `approval_quota_override.ex:91`, `approval_tier_downgrade.ex:144`, `approval_invoice_reconciliation_approve.ex:91`; court `test/xaas/billing/billing_multitenancy_court_test.exs`). W975b's other half (subscription, approval_sla_credit_apply, approval_patch_sla_credit_apply, revenue_recognition) ABSENT from tree — no multitenancy block in any of the 4. Missing hop: W975b half reverted-or-never-integrated; `w975b-retroactive-mint.md` cites line ranges (`subscription.ex:121-134`) that no longer exist and court filename `multitenancy_deepening_test.exs` that does not exist on disk (real file is `billing_multitenancy_court_test.exs`) — the retro mint does NOT evidence SPEC-07 landing. |
| SPEC-08 | STILL-PENDING | no lane, no receipt, no atomic_update diff in `lib/xaas/billing/changes/` |
| SPEC-32 | STILL-PENDING | banned surface per `w969c-design-wave3.md`; no receipt |
| SPEC-34 | STILL-PENDING | no CI leg, no regen-check task, no receipt |

W982g: running — no receipt on disk; its spec attribution left IN-FLIGHT.

## Verification commands (real, this lane)

```
git log --oneline -1 5a853130|fd471722|352cc34c|b2758300|fc14f10b|aa2b4022|fab56ae1|c3df69a8  # all 8 real
ls docs/sjira/v26.10.6/plans/ | grep -E 'w969b|w968c|w935|w970|w973c|w975b|w976'              # receipts present
ls lib/xaas_web/plugs/authenticate_org.ex lib/xaas/graphlaw/limit_gate.ex \
   lib/xaas/ledger/changes/reverse_transfer.ex lib/xaas/operations/changes/set_previous_status.ex \
   test/xaas_web/graphql_http_surface_test.exs test/xaas/graphql_domain_wiring_court_test.exs   # all present
grep -n 'multitenancy do' lib/xaas/billing/*.ex   # 4 blocks (W970a half only)
git diff --stat lib/xaas/billing/                 # 4 W970a files, +115/-4
grep -in absinthe lib/xaas_web/router.ex          # :302-313 graphql scope
grep -n absinthe mix.exs                          # :148
```

## Flips performed

1. `w905-design-gap-specs.md`: W971a tracking table replaced by W982l verified table
   (13 flips to LANDED, 3 confirmed STILL-PENDING, SPEC-07 downgraded to
   STILL-PENDING/PARTIAL-regression with the missing hop named). Superseded W971a
   body deleted; git history preserves it.
2. `docs/claude/diataxis/reference/http-api-surface.md`: new `/api/graphql` section
   (SPEC-30 flip), citing the W975b receipt, the real router lines, the court, and the
   LANDED-UNCOMMITTED standing with the integration-commit condition named.
   `docs/claude/diataxis/reference/ash-configuration.md` GraphQL-status subsection
   still reads UNSUPPORTED — NOT flipped by this lane (outside the lane's write set);
   flagged for the integration lane.

## Standing

- Flips: 13 specs LANDED (10 committed, 3 uncommitted pending W982k integration);
  SPEC-07/08/32/34 STILL-PENDING; W982g IN-FLIGHT.
- Standing of this receipt: ALIVE for the verification acts (every check executed
  this session, outputs quoted above); doc edits on tree uncommitted.
- Falsifier: any cited receipt absent from disk, any cited SHA failing `git log`,
  or any cited file/grep absent from tree — all re-runnable from the command block
  above.
