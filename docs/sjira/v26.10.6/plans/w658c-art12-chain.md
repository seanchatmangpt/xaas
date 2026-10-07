# W658c — Art. 12(3) END-TO-END chain court

Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (one canonical checkout,
private build root `_build-laneW658c`).

## Court

`test/xaas/semantics/art12_chain_court_test.exs` — the master integration court
composing the landed W500-series modules in one flow, one test per stage:

```
candidate
  (a) → Xaas.Semantics.EuAiActAdmission.admit/1        (W500  typed Art 5(1) refusal)
  (b) → Xaas.Semantics.IncidentReport.build/2          (W538  Art 73 classification)
  (c) → Xaas.Semantics.AuthorityChannel.transmit/3     (W625  internal channel RECORDED)
  (d) → Xaas.Witness.AuditChain.append + verify_chain  (W503  tamper-evidence)
  (e) → AutomationBiasCountermeasure.briefing/2        (W539  Art 14.4.b anatomy)
        over W506 Counterfactual.run/2 record + W505 AdmissionAttribution.shapley/2
  (f) → DeclaredMetrics.declare/0                      (W536  cited-source metrics)
  (g) → AuditChain.martingale monotonicity over a 3-decision sequence (Thm 4.1)
  (+) → positive path: lawful candidate → admitted → receipt → chain → verify :ok
  (W540) → VulnerabilityLifecycle DETECTED→TRIAGED→RESPONDED→RESOLVED over the
            chain's own tamper probe
```

## Contract bridging (no duplication of landed surfaces)

- W505 `shapley/2` takes `:pass | {:refuse, atom}`; W506 `run/2` takes
  `:ok | {:refused, atom}` — the court bridges the two real check lists in one
  helper (`w505_checks/0`), as the landed `automation_bias_countermeasure_test`
  does.
- `AuditChain.append/2` requires a 64-hex `payload_digest`; the court derives it
  via SHA-256 over the candidate/outcome term (`payload_digest/1`).

## Findings while composing

- `IncidentReport.maybe_add_malfunction/3` classifies any receipt with
  `status: :refused` as `:MALFUNCTION` even when the refusal atom is a
  `REFUSED_EUAIA_*` atom — i.e. an Art 5(1) admission refusal + `:refused`
  status classifies as BOTH `INFRINGES_UNION_LAW` and `MALFUNCTION`, while the
  moduledoc table says MALFUNCTION is for "any OTHER refusal atom". The court
  (b) therefore omits `status` for the admission-refusal receipt and asserts the
  partition-exact single classification. Left as observed behavior, not changed
  (test-only lane).
- `DeclaredMetrics.declare/0` reads live receipt files
  (`w316-tokened-full-suite.md`: 3233/3247 passed; `w385-conformance-court.md`:
  CONFORMANT 26/26; the refusal ledger JSON) — verified present at court-authoring
  time.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW658c \
  mix test test/xaas/semantics/art12_chain_court_test.exs
```

Observed run (2026-10-07, exit 0):

```
Finished in 0.2 seconds (0.2s async, 0.00s sync)

Result: 9 passed
```

Zero compiler warnings from the new file. The (f) court reads live receipts:
w316 `Result: 3233/3247 passed`, w385 `CONFORMANT 26/26`, refusal-ledger JSON
(`62/62` coverage, 9 mutant-kill-verified / 10 runs).
