# W602b — Witness Check: WP-2 Witness Leg Folded into W601 (OS-18)

Date: 2026-10-07 · Lane: W602b · Repo: /Users/sac/xaas (canonical checkout, branch feat/playwright-surface)

## Verdict

**ALIVE — the fold is real, not vapor.** W601's legs are on disk and the
refusal-negative court is green at this instant.

## On-disk evidence

- `lib/xaas/actuation.ex` (~line 574–598): the tautological load-key equality
  check (W546/OS-18: "intent.id != admission.intent.id or receipt.id !=
  admission.receipt.id — a tautology") is replaced by field-by-field comparison
  of the admission-carried context against BOTH loaded rows independently.
  Comment block carries the W601 annotation including the receipt-field gap
  ("the receipt's own resource/action/subject copies were previously left
  unchecked"). Mismatch path returns `{:error, :external_admission_identity_mismatch}`.
- `test/xaas/actuation_refusal_negative_test.exs:200`: forged-pair leg present —
  "admission struct forged to a foreign but internally-consistent admission pair
  is refused :external_admission_identity_mismatch" — constructs a real foreign
  admission, splices its intent+receipt into the local struct, asserts refusal
  and that the forged checkpoint durably bound nothing.
- W601's own receipt `docs/sjira/v26.10.7/plans/w601-actuation-tautology.md`
  does NOT yet exist (W601 still mid-flight on documentation); the CODE legs,
  however, have landed on the working tree.

## Run (x1, as directed)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW602b \
  mix test test/xaas/actuation_refusal_negative_test.exs
```

Tail: `Running ExUnit with seed: 773902, max_cases: 32 ... Finished in 1.7
seconds ... Result: 10 passed` — exit 0. The forged-pair leg ran within the 10
(seed-randomized order). Note: the directive's expected atom
`REFUSED_ACTUATION_IDENTITY_MISMATCH` — the on-tree typed refusal is the
error-tuple atom `:external_admission_identity_mismatch`; same fault class,
different spelling than the directive anticipated. No
`REFUSED_ACTUATION_IDENTITY_MISMATCH` literal exists anywhere in lib/ or test/.

Pre-existing (not lane-introduced): unused-function warning
`receipt_count/0` at test file line 37; Grafana/PromEx upload warnings (nxdomain).

## Standing

- Witness fold: ALIVE (code on tree + court green, witnessed 2026-10-07).
- W601 receipt: PENDING (file absent — W601 lane still running).
- Caveat: uncommitted working-tree state; standing binds to this tree, not a SHA.

## Hygiene

`_build-laneW602b` deletion was attempted twice and denied by the permission
system — the lane build-root lease is LEFT ON DISK at `/Users/sac/xaas/_build-laneW602b`.
Coordinator should remove it at integration per the fanout cleanup law.
