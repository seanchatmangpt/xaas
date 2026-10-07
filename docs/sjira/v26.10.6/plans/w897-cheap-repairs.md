# W897 — Cheap Repairs (3 CHEAP-REPAIR rows from W891 triage)

Lane W897, 2026-10-07. Repo `/Users/sac/xaas` @ `feat/playwright-surface` (base HEAD `a0723bf6`).
No commit (lane contract: coordinator owns commits). Build root `_build-laneW897` left in
place — deletion denied by the session permission system (see Cleanup).

## Row selection (W891 triage, docs/sjira/v26.10.6/plans/w891-gap-triage.md)

Triage order: row 29 (W804) is OPERATOR, not code — skipped. **Triage drift found**: rows 6
(W729 approve-idempotency) and 13 (W750-G1) are already repaired on HEAD (W746's
`filter(expr(is_nil(approved_by)))` guard is landed at
`lib/xaas/billing/approval_sla_credit_apply.ex:133`; W768's
`CapabilityLivenessReceiptStatusGate` is wired at
`lib/xaas/operations/capability_liveness_receipt.ex:179`). Substituted the next triage rows:
**rows 1 (W665), 5 (W729 lifecycle), 11 (W731 path)** — all one-file guard/fix lanes in
disjoint files.

## Rows repaired

### Row 1 — W665 kernel gap: bare `:emotion_recognition` technique atom admits

- **Before**: `affective_in_context?/1` (`lib/xaas/semantics/eu_ai_act_admission.ex`) refused
  only the `:affective` domain + `:workplace`/`:education` conjunction; a bare
  `%{techniques: [:emotion_recognition]}` admitted. Pinned honestly by w665.
- **Repair**: the bare technique atom now also triggers
  `REFUSED_EUAIA_EMOTION_RECOGNITION`; moduledoc table row (e) updated. Pin test at
  `test/eu_ai_act/art50_deepening_test.exs` ("the bare technique atom admits") flipped to
  assert the typed refusal.
- **Court + mutation**: art50_deepening suite 7/7 with repair; mutation = deleting the
  `:emotion_recognition in techniques` trigger → 6/7 RED (`assert {:error,
  :REFUSED_EUAIA_EMOTION_RECOGNITION}` fails). Mutation-killed.

### Row 5 — W729 `UNSUPPORTED(lifecycle-state-machine)`: `:sync_from_stripe` accepts any in-enum transition

- **Before**: no transition guard; `:canceled -> :active` accepted (pinned by w729's
  "TYPED GAP" test in `test/xaas/billing_deepening_test.exs`).
- **Repair**: new `Xaas.Billing.Validations.SubscriptionStripeTransitionAllowed`
  (`lib/xaas/billing/validations/subscription_stripe_transition_allowed.ex`, house idiom
  mirror of `RunTransitionAllowed`/`ForwardOnlyTransition` per triage/W772): explicit
  allow-list (self-transitions for redelivery; incomplete→active/past_due/canceled;
  active→past_due/canceled; past_due→active/canceled), terminal-is-terminal for `:canceled`.
  Wired via `validate(...)` on `:sync_from_stripe` (`lib/xaas/billing/subscription.ex`).
  The replacement-subscription path (new `stripe_subscription_id` on a canceled row) is
  documented in the validation's moduledoc as a designed follow-up, not smuggled into the
  allow-list.
- **Court + mutation**: pin test flipped to assert the typed refusal + persisted
  `:canceled`; 13/13. Mutation = deleting the `validate(...)` line → 12/13 RED.
  Mutation-killed. Sibling consumers green: `test/xaas/billing/subscription_test.exs` +
  `test/xaas_web/controllers/stripe_webhook_controller_test.exs` 18/18 (all their real
  edges — self-transitions, active→past_due, active→canceled — are allow-listed).

### Row 11 — W731 `GAP(graphlaw-registry-path-hardcoded)`

- **Before**: `Catalog.default_registry_path/0` returned the hardcoded
  `/Users/sac/graphlaw/registry/capability-registry.json` unconditionally; ingest host-bound.
- **Repair**: `Application.get_env(:xaas, :graphlaw_registry_path, @default_registry_path)`
  (`lib/xaas/graphlaw/catalog.ex`); the literal stays as the documented local default.
- **Court + mutation**: new `Xaas.GraphlawCatalogRegistryPathTest` (appended to
  `test/xaas/graphlaw_deepening_test.exs`, `async: false`, env restored via `on_exit`):
  override honored + fallback default. 18/18. Mutation = reverting the function body to the
  bare module attribute → 17/18 RED (override court fails). Mutation-killed.

## Verification (real tails)

All runs: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW897 mix test ...`

```
# combined final pass (art50 --include eu_ai_act + billing_deepening + graphlaw_deepening
#   + subscription + stripe_webhook):
Result: 56 passed

# per-suite (pre-final, same subject):
Result: 7 passed            (art50_deepening, --include eu_ai_act)
Result: 31 passed, 7 excluded  (billing+graphlaw combined, first full run)

# mutation runs:
Result: 6/7 passed          (M1: bare-atom trigger deleted — art50 bare-atom court RED)
Result: 12/13 passed        (M2: validate line deleted — transition court RED)
Result: 17/18 passed        (M3: env fallback reverted — override court RED)
```

## Standing

- **ALIVE** for the three asserted behaviors (typed bare-atom refusal; terminal-is-terminal
  sync guard; env-overridable registry path) on the exact subject: working tree of
  `feat/playwright-surface` at base `a0723bf6`, lane W897 diff = 3 lib files + 3 test
  files (2 edited, 1 module appended, 1 new validation module).
- Register/triage row status updates (register says rows close "when a later receipt's real
  run closed it") are the coordinator's integration step; this lane does not edit the
  register.
- **Transport notes**: (1) triage rows 6/13 were stale (already repaired on HEAD by W746/W768)
  — flagged above for register hygiene; (2) during the lane, a sibling lane held the shared
  tree non-compiling for ~15 minutes (mid-write on
  `lib/xaas/governance/audit_export_token.ex` — `increment/2` arg shape, then duplicate-route
  transformer error); this lane's verification waited on real compile green rather than
  gating on their file, and the final pass above is on a compiling tree.
- Cleanup: `rm -rf _build-laneW897` was denied by the session permission system (same as
  W729's lane); `_build-laneW897` is left in place for the coordinator to delete at
  integration per the lane-lease cleanup law.
