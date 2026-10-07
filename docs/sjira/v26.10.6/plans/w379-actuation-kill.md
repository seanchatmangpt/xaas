# W379 — actuation `:external_admission_identity_mismatch` anti-vacuity (W320 gap 2)

Lane: W379, repo `/Users/sac/xaas` @ `feat/playwright-surface`, one canonical checkout,
no commit. Writes: `test/xaas/actuation_refusal_negative_test.exs` (append-only test),
this plan file. `lib/` untouched (mutant + revert net-zero, verified).

## Clause analysis

`verify_external_prepared/3` (lib/xaas/actuation.ex:528-552). The identity clause:

```elixir
intent.id != admission.intent.id or receipt.id != admission.receipt.id ->
  {:error, :external_admission_identity_mismatch}
```

has exactly ONE caller: `checkpoint_external/2` (lib/xaas/actuation.ex:394-397), which
loads both records BY the admission's own primary keys:

```elixir
{:ok, receipt} <- Ash.get(ActuationReceipt, admission.receipt.id, ...)
{:ok, intent}  <- Ash.get(ActuationIntent, admission.intent.id, ...)
```

so `intent.id == admission.intent.id` and `receipt.id == admission.receipt.id` are
tautologies. The clause is structurally dead via its only lawful entry point. The
forged-struct route cannot reach it either: any single-field forgery diverges earlier
(intent-only → `:external_intent_not_executing` or `:external_receipt_intent_mismatch`;
receipt-only → an earlier clause), and the only forgery that gets past every
earlier clause is the internally-consistent foreign pair — which the identity clause
admits (that IS the gap).

## What landed

No killing test is possible (unreachable clause ⇒ no executable kill). Landed instead:

1. **Witness test** ("admission struct forged to a foreign but internally-consistent
   admission pair is NOT refused by :external_admission_identity_mismatch"): forges the
   admission struct in memory to a real second admission's `{intent, receipt}` pair.
   Asserts the checkpoint is ADMITTED and durably binds the construct to the foreign
   receipt — real execution proof that the identity clause never fires and that a
   forged checkpoint is admitted against a foreign admission pair (the exact gap W320
   flagged). Also pins that the honest admission's receipt stays inert.

2. **Mutant run (typed structural evidence, zero behavioral delta)**: replaced the
   clause with `false ->` (deletion mutant). Re-ran the file: **6 passed, identical
   behavior** — a deletion of the identity check is unobservable through the public
   surface. Deletion-mutant-survives is the machine check of deadness; no forged-input
   test can fail on a mutant that is behaviorally identical to the original.

## Run receipts

- Baseline (original clause): `mix test test/xaas/actuation_refusal_negative_test.exs`
  → **6 passed** (5 pre-existing + witness test), exit 0,
  `MIX_BUILD_ROOT=_build-laneW379`, pinned asdf toolchain.
- Mutant (clause → `false`): same command → **6 passed**, exit 0 — mutant survived,
  zero delta, deadness witnessed empirically.
- Revert verified: `git diff lib/xaas/actuation.ex` shows no hunk at the identity
  clause (grep for `identity` in the diff: no match); the only remaining diff
  (line ~380 `rescue` clause) predates this session (present in session-start git
  status).

## Standing

`:external_admission_identity_mismatch` = **structurally unreachable (typed evidence,
not killed)**. The clause guards nothing at runtime; the gap W320 flagged is real but
in the opposite direction: a foreign-pair admission forgery is admitted, not refused.
Options for the coordinator: (a) accept the witness test as the gap-documentation,
(b) a later lane may delete the dead clause or tighten `checkpoint_external/2` to
compare the loaded `intent.idempotency_key`/`projection_hash` against an
admission-carried value that survives the Ash.get round-trip (e.g. re-hash the loaded
rows) — that would make the check live and the witness test would then need updating
to the refusal. Neither edit is in this lane's contract.

## Falsifier for any future "kill" claim

A real kill requires a caller that passes intent/receipt NOT loaded by admission's own
ids. If someone adds such a caller, the witness test flips: forging the admission pair
must then yield `{:error, {:external_checkpoint_failed, :external_admission_identity_mismatch}}`.
