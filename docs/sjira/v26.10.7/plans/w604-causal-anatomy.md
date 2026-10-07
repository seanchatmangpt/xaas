# W604 — Causal anatomy on the operator authorization surface (WP-1, OS-15 / Art. 14(4)(b))

Lane W604, v26.10.7 release campaign. Date: 2026-10-07.
Subject: `/Users/sac/xaas`, branch `feat/playwright-surface`, uncommitted lane diff (coordinator commits).

## Grounding

Already-landed machinery this lane wires:

- W505 `Xaas.Semantics.AdmissionAttribution` — `lib/xaas/semantics/admission_attribution.ex` (exact Shapley over the discrete check lattice).
- W506 `Xaas.Semantics.Counterfactual` — `lib/xaas/semantics/counterfactual.ex` (Art. 86 deterministic replay).
- W984p `Xaas.Semantics.AutomationBiasCountermeasure.briefing/2` — `lib/xaas/semantics/automation_bias_countermeasure.ex`.

Operator approval surface, grounded: there are **no dedicated approval controllers** in
`lib/xaas_web/controllers/`. The approval surface IS the AshJsonApi resource route surface
(`XaasWeb.ApiRouter` forward catch-all). The `test/xaas_web/controllers/approval_*_test.exs` files
are ConnCase courts over those JSON:API routes. The `:approve` authorize action on
`Xaas.Billing.ApprovalSlaCreditApply` is `PATCH /api/approval_sla_credit_apply/:id`.

## Seam chosen

AshJsonApi **per-route `metadata:` fn/3** on `patch(:approve)` of `Xaas.Billing.ApprovalSlaCreditApply`.
The route-level `metadata` option (ash_json_api `resource.ex` schema `{:fun, 3}`) renders into the
top-level `meta` member of the JSON:API response document
(`deps/ash_json_api/lib/ash_json_api/controllers/helpers.ex` `fetch_metadata/1` →
`Serializer.serialize_one(..., meta)`), so the operator-facing approve response carries:

```json
"meta": {
  "causal_anatomy": {
    "available": true,
    "briefing": {
      "verdict": "admit",
      "per_check_causes": ["5 named checks, each with a real numeric shapley value"],
      "refusal_anatomy": [],
      "counterfactual_available": true,
      "interpretability": "counterfactual replay + exact Shapley attribution — deterministic, receipt-backed"
    },
    "counterfactual": "W506 replay on a repaired approver input; null for admits (nothing to repair)"
  }
}
```

Why this seam: read-only enrichment of the EXISTING authorize-action response. No new route, no new
authority, the mutation path (policies, `ApprovalSlaCreditApplyRequiresApprover` validation,
`filter(expr(is_nil(approved_by)))` idempotency guard, Ledger change) is byte-untouched. W603's
`Xaas.Operations.AuthorityLedgerExport` was not touched.

## Diff (4 files)

New:
- `lib/xaas/operations/approval_causal_anatomy.ex` — `Xaas.Operations.ApprovalCausalAnatomy`:
  ordered 5-check battery mirroring the REAL `:approve` predicates (approver_present,
  approver_differs/self-approval, not_already_approved, credit_amount_positive, org_bound);
  composes W505 `shapley/2` + W506 `run/evaluate` + W984p `briefing/2`; typed
  `{:missing_intent, keys}` refusal for missing-anatomy input; typed passthrough of W984p briefing
  contract refusals; `metadata/1` HTTP adapter = the disclosed degrade point (a nil-amount record
  yields a real refused briefing `amount_not_positive`, never a crash or unexplained admit).
- `test/xaas_web/controllers/approval_causal_anatomy_controller_test.exs` — the court, 4 tests.

Edited:
- `lib/xaas/billing/approval_sla_credit_apply.ex` — `patch(:approve, metadata: fn _subject, result, _request -> Xaas.Operations.ApprovalCausalAnatomy.metadata(result) end)` plus rationale comment.
- `docs/sjira/v26.10.7/plans/w604-causal-anatomy.md` — this receipt.

## Court (0 mocks, grep-verified)

1. HTTP: real `PATCH` through the real router + sandboxed Postgres asserts `meta.causal_anatomy`
   with `available == true`, verdict `"admit"`, 5 named per-check causes each with real numeric
   Shapley values (all zero for a full admit — the real admitted anatomy), `refusal_anatomy == []`,
   `counterfactual_available == true`, `counterfactual == null`.
2. Module, refused decision (self-approval): real nonzero exact-Shapley blame on `approver_differs`
   (φ = −1.0), refusal anatomy `[approver_differs: self_approval]`, Art. 86 counterfactual flip:
   repaired approver → `changed? == true`, explanation names `approver_differs`.
3. Module, already-approved decision: refusal anatomy names `already_approved`; counterfactual
   honestly stays refused (`changed? == false`) — no single-approver repair exists.
4. Typed degrade: `anatomy/1` on incomplete intent → `{:error, {:missing_intent, [:credit_amount_cents, :org_id]}}` (exact key list asserted); non-map → `{:error, {:missing_intent, [:not_a_map]}}`; the
   metadata adapter over a nil-amount record yields a real refused briefing, never a crash.

## Mutation rationale

- Metadata fn deleted → test 1 fails (missing `meta.causal_anatomy`).
- Check battery renamed/reordered/removed → tests 1/2 name assertions fail.
- Refusal reasons renamed → tests 2/4 reason assertions fail.
- Counterfactual replay removed → tests 2/3 `cf.*` assertions fail.
- Missing-intent typed guard removed → test 4's exact `{:missing_intent, ...}` assertion fails.
- Adapter overclaiming a clean anatomy on refused input → test 4 refuses it.

## Verification ladder (real output)

Env: `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`, `MIX_BUILD_ROOT=_build-laneW604`.

```text
mix compile  → exit 0, "Generated xaas app" (fresh lane root)
mix test test/xaas_web/controllers/approval_causal_anatomy_controller_test.exs
  → Result: 4 passed  (final state)
mix test test/xaas_web/controllers/approval_sla_credit_apply_controller_test.exs \
         test/xaas_web/controllers/approval_patch_sla_credit_apply_controller_test.exs
  → Result: 16 passed (regression on the touched resource's existing courts)
```

Second fresh root `_build-laneW604r2` (court + regression, full recompile): **completed —
`Result: 12 passed`, exit 0** (4 anatomy court + 8 `approval_sla_credit_apply` regression, from a
fully cold `_build-laneW604r2`).

## Standing

ALIVE — two independent fresh-root executions witnessed (4/4 + 16/16 on `_build-laneW604`;
12/12 on cold `_build-laneW604r2`), court kills wiring mutants per the mutation rationale above.

## Verification addendum

See the r2 result above (12 passed, cold fresh root, exit 0).

## Boundaries / disclosures

- Anatomy on the WIRE is on the admit path only: AshJsonApi error responses render no `meta`, so a
  refused/repeat-approve HTTP attempt carries no anatomy block. Refused decisions get their real
  anatomy at the module boundary (courted in tests 2–4). This is a transport property of the seam,
  disclosed, not a silent gap.
- One resource wired; the other ~33 `patch(:approve)` surfaces take the same one-line wiring and are
  deliberately outside this lane's small coherent diff.
- No approval LiveView/modal exists in the tree; the JSON:API route metadata IS the operator surface.
- Concurrent-lane note: mid-session a concurrent lane briefly broke
  `lib/mix/tasks/xaas.airo.compile_shacl.ex:278` (broken pipe into `<>`); self-fixed on disk by its
  owner within ~10 min. Not my diff; disclosed per the compile-freeze SLA.

## Falsifiers (re-runnable)

- `mix test test/xaas_web/controllers/approval_causal_anatomy_controller_test.exs` — red kills the seam.
- Repeat-approve of an already-approved record at HTTP level → typed Ash `NotFound` refusal (existing
  idempotency guard, untouched and still courted by the resource's own tests).
