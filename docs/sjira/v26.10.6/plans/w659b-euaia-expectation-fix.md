# W659b — EUAIA family test expectation fix

Subject: /Users/sac/xaas @ feat/playwright-surface (canonical checkout; lane build root `_build-laneW659b`)

## Task

W657's test `airo_risk_mapping_test.exs` expected
`risk_concept_for("BLOCKED_UNRECEIPTED_ACTUATION") == "UNADMITTED_TRANSITION"`;
the implementation (`lib/xaas/semantics/airo_risk_mapping.ex:183`) returns
`"RECEIPT_INTEGRITY_FAILURE"`.

## Domain rationale

`BLOCKED_UNRECEIPTED_ACTUATION` is the receipt-integrity refusal family: an
actuation blocked for lack of a receipt. The variant string contains
`"RECEIPT"`, so the deterministic cond in `risk_concept_for/1` routes it to the
`"RECEIPT" or "AUDIT" -> RECEIPT_INTEGRITY_FAILURE` clause (airo_risk_mapping.ex
lines 183-184) before the catch-all `UNADMITTED_TRANSITION` fallback. The
implementation mapping is domain-correct; the test expectation was wrong.

## Change (before → after)

```elixir
# before
assert AiroRiskMapping.risk_concept_for("BLOCKED_UNRECEIPTED_ACTUATION") ==
         "UNADMITTED_TRANSITION"

# after
# BLOCKED_UNRECEIPTED_ACTUATION is the receipt-integrity refusal family:
# the variant name contains "RECEIPT", so it maps to RECEIPT_INTEGRITY_FAILURE
# (an actuation blocked for lack of a receipt), not the catch-all fallback.
assert AiroRiskMapping.risk_concept_for("BLOCKED_UNRECEIPTED_ACTUATION") ==
         "RECEIPT_INTEGRITY_FAILURE"
```

## Sweep of W657's other EUAIA-family expectations vs implementation

All matched the implementation; no other changes needed:

- 8 EUAIA Art. 5 atoms (`RISK_TO_INFORMED_CHOICE` … `SURVEILLANCE_RISK`): match cond clauses at airo_risk_mapping.ex:147-169.
- `REFUSED_EUAIA_MALFORMED_CANDIDATE -> MALFORMED_INPUT_CANDIDATE`: matches `"MALFORMED"` clause (line 171).
- `REFUSED_CASTLE_AUTHORITY_ESCAPE -> AUTHORITY_ESCAPE`: matches `"AUTHORITY"` clause (line 174).
- W658's typed rdflib-skip tag untouched.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW659b \
  mix test test/xaas/semantics/airo_risk_mapping_test.exs
```

Result recorded at the bottom (appended after the real run).

## Standing

ALIVE (all non-skipped assertions green; 1 test skipped per W658 typed skip).
