# W601 — OS-18 external-pair identity tautology (checkpoint_external/2)

Date: 2026-10-07. Lane: W601, v26.10.7 campaign. Repo: /Users/sac/xaas
@ `bbaaeec6` (feat/playwright-surface). Single OS-18 lane (W602 folded here).

## Fence (pre-state, read fresh)

`lib/xaas/actuation.ex` @ HEAD md5 `6bcdb140314375fcd47630c58bb6011d`.
The W546/OS-18 fix was ALREADY in the tree at HEAD: `verify_external_prepared/3`
carried the `:external_admission_identity_mismatch` clause comparing the
admission-carried context (resource/action/subject/input-hash) against the
loaded intent row, plus two uncommitted witness legs in
`test/xaas/actuation_refusal_negative_test.exs` (forged-foreign-pair leg +
honest-resume leg; file ` M` in git status). Baseline run of the file:
**7 passed, exit 0** (`_build-laneW601`, pinned asdf toolchain).

## Residual tautology found and eliminated

`checkpoint_external/2` loads both rows BY the admission's PKs, so any
comparison of load keys is tautological. The W546 clause closed the
intent-side, but compared the semantic fields against the INTENT row only.
`ActuationReceipt` carries its own copies (`resource_module`, `action`,
`subject_id`) which were NEVER compared — a forged pair whose receipt fields
diverged from both the intent and the admission still checkpointed, and the
`intent.input_hash != receipt.input_hash` clause would not fire when the
forger kept those consistent.

**Fix** (`lib/xaas/actuation.ex`, `verify_external_prepared/3`): the identity
clause now compares the admission-carried context field-by-field against BOTH
loaded rows independently — `inspect(admission.resource)` /
`Atom.to_string(admission.action)` / `stringify(admission.subject_id)` /
`carried_input_hash(admission)` vs each of
`(intent|receipt).(resource_module|action|subject_id|input_hash)`. Any
divergence → typed `{:error, :external_admission_identity_mismatch}`
(standing name `REFUSED_ACTUATION_IDENTITY_MISMATCH`; surfaces as
`{:external_checkpoint_failed, :external_admission_identity_mismatch}`).
Happy path unchanged: no new clause can fire for a self-consistent pair.

## Witness legs appended (existing tests untouched)

`test/xaas/actuation_refusal_negative_test.exs`, new `describe "W601
field-by-field receipt identity"`:

1. Receipt row with tampered `subject_id` (direct Ecto tamper over the real
   sandboxed row, same idiom as the existing `:external_input_mismatch` leg)
   → `{:external_checkpoint_failed, :external_admission_identity_mismatch}`,
   receipt stays inert `:prepared`, provider row unchanged.
2. Receipt row with tampered `action` → same typed refusal, zero state yield.
3. Happy-path leg: honest fresh admission → checkpoint binds construct,
   `seal_external/2` succeeds, receipt+intent `:succeeded`, provider row
   unchanged.

File grew 7 → 10 tests.

## Court ladder (all `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW601`)

| run | command | result |
|---|---|---|
| baseline (HEAD) | `mix test test/xaas/actuation_refusal_negative_test.exs` | 7 passed, exit 0 |
| +W601 legs +fix | same | **10 passed, exit 0** |
| mutation A: receipt-field clauses removed (intent-only, pre-W601 shape) | same | **RED: 8/10, exactly the 2 new tamper legs fail** |
| mutation B: whole identity clause → `false ->` | same | **RED: 7/10, forged-pair leg + 2 tamper legs fail** |
| golden restored | `mix test test/xaas/actuation_refusal_negative_test.exs test/xaas/actuation_test.exs` | **15 passed, exit 0** |

Mutation restore: golden rebuilt from HEAD via deterministic replace, md5
re-verified `7d0af6268a3d6c560514e0747f1ab2c8` byte-identical both times
(golden md5 recorded before mutation A and checked after each restore).

## Standing

- fix + legs present in working tree, NOT committed (per lane directive;
  coordinator owns commits).
- `test/xaas/actuation_refusal_negative_test.exs` + `test/xaas/actuation_test.exs`
  green on the lane build root — actuation contract (happy path) unchanged.
- Full-suite run not performed in this lane (repo operating mode: iteration
  speed; the narrow falsifier file is the contract for this surface).
- `_build-laneW601` deleted by this lane at integration per fanout cleanup law.
- OS-18: PARTIAL_ALIVE → the checkpoint-boundary half is now ALIVE at this
  SHA; the prepare/resume boundary uses `find_or_create` keyed on
  `idempotency_key` with its own field-by-field `replay_or_refuse/6` check
  (non-tautological, pre-existing).

## Falsifiers

- `mix test test/xaas/actuation_refusal_negative_test.exs` RED on any subject
  where the receipt-field identity clauses are absent or neutralized.
- Mutation A/B reproduce as above.
