# W537 — Art. 26.6 retention / Art. 26.7 worker notification / Art. 27 FRIA

Lane: W537 · Wave: EU-AI-Act implementation · Repo: `/Users/sac/xaas` @ `feat/playwright-surface` · Build root: `_build-laneW537`

## Contract files

- `lib/xaas/semantics/oversight_governance.ex` — `Xaas.Semantics.OversightGovernance`
- `test/xaas/semantics/oversight_governance_test.exs`
- this receipt

## Mapping

| EU AI Act | duty | implementation | status |
|---|---|---|---|
| Art. 26.6 | logs preserved | `retention_policy/0` — sealed actuation receipts are durable rows (`Xaas.Actuation.run/4`, `lib/xaas/actuation.ex`) + tamper-evident witness chain (`lib/xaas/witness/*`) → `:permanent_durable_rows`; lane build roots / one-time artifacts ephemeral under recorded lease cleanup via `ash_onetime` prune/reap (`deps/ash_onetime/lib/mix/tasks/ash_onetime.{prune,reap}.ex`) → `:lane_lease_cleanup` | EVIDENCED by durable rows |
| Art. 26.7 | worker notification | `worker_notification/0` — the receipt corpus + OCEL events ARE the notification record to the operator (`Xaas.Telemetry.OcelAshEmitter`, `lib/xaas/telemetry/ocel_ash_emitter.ex`; egress: `lib/xaas/ultracode/ocel_egress.ex`, `lib/xaas/ultracode/autonomy_egress.ex`). Serious-incident reporting to authorities (3.49 family) stays typed `{:OPEN_GAP, %{item, basis, cite}}` — no incident-reporting seam (W525b) | EVIDENCED channel + honest OPEN_GAP |
| Art. 27 | FRIA | `fria/0` — deployer-class FRIA as structured data, per-right evidence citations (path + symbol + basis), status `:EVIDENCED`/`:OPEN_GAP`: non-discrimination (W502 bias gate `REFUSED_BIAS_THRESHOLD`), due process (typed refusals + exact-SHA replay via `Xaas.Actuation.run/4` + `Xaas.Witness.CertifiedReceipt` + Art. 5 profile), privacy (zero PII: Art. 5 profile inspects declared intent schema only), worker information (OCEL emitter), serious-incident authority channel `:OPEN_GAP` | structured data, doc-class like OS-15 but machine-checkable |

## Tests (Chicago, no mocks)

Every cited path verified with `File.exists?/1` against the real repo tree;
determinism by structural equality of repeated calls; honesty by requiring
OPEN_GAP entries present and typed (incident channel in both `worker_notification/0`
and `fria/0`).

## Verification

- `MIX_BUILD_ROOT=_build-laneW537 MIX_ENV=test mix compile --warnings-as-errors` — green
- `MIX_BUILD_ROOT=_build-laneW537 mix test test/xaas/semantics/oversight_governance_test.exs` — green
