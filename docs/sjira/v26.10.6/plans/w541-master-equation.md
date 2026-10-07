# W541 — Master Equation Composition Court (dissertation Ch. 9)

Lane: W541 of the EU-AI-Act wave. Repo `/Users/sac/xaas` @ `feat/playwright-surface`,
private build root `_build-laneW541`. Write scope honored: this file +
`test/xaas/semantics/master_equation_test.exs` only.

## Composition diagram — F_actuate(u), clause by clause

```
                      candidate intent map u
                               |
        +----------------------v-----------------------+
        | (a) EuAiActAdmission.admit(u)         [W500] |   Art. 5(1)(a)-(h)
        |     structural disjointness, 8 typed atoms   |   content-free
        +----------+------------------+----------------+
                   |ok               |{:error, atom}
                   v                 v
        +------------------+   REFUSED[gate: :article5_admission]
        | (b) RobustMargin |   signed refusal record
        |     .admit       |   (HMAC stand-in slot)
        |  margin-Lh*Le*eps|
        |  >= 0   [W508]   |
        |  Lh REAL via     |
        |  estimate_       |
        |  lipschitz/2     |
        +----------+-------+--------------------------+
                   |ADMITTED         |{:error, atom}
                   v                 v
        +------------------+   REFUSED[gate: :robust_margin]
        | (c) AuditChain   |   signed refusal record
        |  .append +       |
        |  verify_chain    |
        |  SHA256(JCS)     |
        |  [W503]          |
        +----------+-------+--------------------------+
                   |:ok              |{:error, {:tampered,_} | :invalid_signature}
                   v                 v
        DO-with-receipt          REFUSED[gate: :audit_ledger]
        receipt = Counterfactual(W506) decision_record
        {input, admitted?, refusal, checks}
        + signature_hex over {subject, head_hash}
```

Every refused or admitted exit carries: gate name (the "which gate refused"
traceability), typed refusal atom, ordered per-check trace, and a signature
slot in the W510 flow shape (canonical payload -> sign -> verify).

## What is real crypto vs disclosed stand-ins

| clause | module | status |
|---|---|---|
| (a) Art. 5 admission | `Xaas.Semantics.EuAiActAdmission` | REAL, landed W500 |
| (b) CBF margin | `Xaas.Semantics.RobustMargin` | REAL, landed W508; `L_h` computed via real `estimate_lipschitz/2` calibration |
| (c) ledger | `Xaas.Witness.AuditChain` | REAL SHA-256-over-JCS hashing + real link/tamper verification (landed W503) |
| refusal/DO signature | `:crypto.mac(:hmac, :sha256, ...)` | **DISCLOSED HMAC-SHA-256 stand-in** for W510's ML-DSA-65 OpenSSL flow. Same shape (JCS canonical -> sign -> stored sig + key material -> verify), same slot contract. Real ML-DSA-65 subprocess flow is witnessed in `test/xaas/witness/ml_dsa_signed_receipt_test.exs`; re-running 3 subprocess round trips per refusal across a determinism-x3 court adds no composition signal. |

## Tests (8)

1. lawful candidate traverses (a)->(b)->(c) -> DO-with-receipt; sig verifies; chain verifies.
2. DO receipt is a W506 `Counterfactual` decision_record (Art. 86 replay-compatible).
3. Art. 5(1)(a) candidate refuses at gate (a) with `:REFUSED_EUAIA_MANIPULATIVE`, never reaches (b)/(c); signed refusal; gate name present.
4. negative control: forged refusal body fails signature verification.
5. margin violation (epsilon=100) passes gate (a), refuses at gate (b) with `:REFUSED_ROBUST_MARGIN`; trace shows pass-then-fail.
6. no-calibration fail-closed at gate (b) with `:REFUSED_NO_CALIBRATION_DATA`.
7. ledger tamper: `{:error, {:tampered, 0}}` from verify_chain; court emits gate-(c) signed refusal.
8. determinism x3: lawful path identical across 3 runs; gate-(a) and gate-(b) refusal records identical across 3 runs.

## Receipt

- Subject: `feat/playwright-surface` lane W541, files above only.
- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW541 mix test test/xaas/semantics/master_equation_test.exs`
- Result: **9/9 passed** (`mix test test/xaas/semantics/master_equation_test.exs`,
  MIX_BUILD_ROOT=_build-laneW541, seed 368813 family). Strict compile:
  `MIX_ENV=test mix compile --warnings-as-errors` exit 0 (one pre-existing
  dep warning, `AshAffidavit.Signing` @envelope_domain_tag — not lane-introduced).
- Test count: 8 test blocks / 9 ExUnit cases (one describe has two determinism
  cases); 0 failures.
- Zero lib edits; composition lives entirely in the test module (`f_actuate/2` + refusal-record helpers).
