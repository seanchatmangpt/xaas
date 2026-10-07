# W546 — OS-18: `checkpoint_external/2` tautology fix + witness flip + corpus rerun

Lane W546, repo `/Users/sac/xaas` @ `feat/playwright-surface`, one canonical checkout,
build root `_build-laneW546`, no commit (coordinator owns integration).

## Fix

`lib/xaas/actuation.ex` — `verify_external_prepared/3` (Kernel module). The former
identity clause

```elixir
intent.id != admission.intent.id or receipt.id != admission.receipt.id ->
  {:error, :external_admission_identity_mismatch}
```

was a tautology (w379): `checkpoint_external/2` loads both records BY the admission's
own PKs, so those equalities can never be false. Replaced with a LIVE clause placed
after the projection/input clauses (ordering preserved for the pre-existing
`:external_projection_mismatch` / `:external_input_mismatch` tests):

```elixir
inspect(admission.resource) != intent.resource_module or
  Atom.to_string(admission.action) != intent.action or
  stringify(admission.subject_id) != intent.subject_id or
  carried_input_hash(admission) != intent.input_hash or
  carried_input_hash(admission) != receipt.input_hash ->
  {:error, :external_admission_identity_mismatch}
```

`carried_input_hash/1` re-derives the input hash from the admission-carried
`{resource, action, subject_id, raw_input, projection_hash}` exactly as
`create_admission/4` derived it at admission time. A forged `{intent, receipt}` pair
that is internally consistent but does not belong to the admission the caller holds
(different resource, action, subject, or input) is now refused
`:external_admission_identity_mismatch`. The honest path (including the
honest `resume_external` path, now pinned by a new positive test) passes.

## Witness flip

`test/for...` (witness moved in the same file, test/xaas/actuation_refusal_negative_test.exs).
The witness test (was: "…is NOT refused … (structural dead-clause witness)", asserted
the checkpoint is ADMITTED) is flipped to assert

```elixir
{:error, {:external_checkpoint_failed, :external_admission_identity_mismatch}}
```

The foreign admission in the witness is now prepared with a DIFFERENT input
(`%{status: :inactive}` vs the honest `%{status: :active}`), so the internally
consistent foreign pair is distinguishable from the caller's carried context.
Before the fix, this exact forged shape was ADMITTED (w379's machine evidence).
Also added a positive control: "honest resumed admission passes the tightened
admission-identity check" (honest resume → checkpoint admitted, construct bound).

## Verification ladder

Pinned asdf toolchain (elixir 1.20.2-otp-28), `MIX_BUILD_ROOT=_build-laneW546`:

1. `mix test test/xaas/actuation_refusal_negative_test.exs` → **7 passed**, exit 0
   (6 pre-existing tests + flipped witness + new honest-resume positive control;
   pre-fix was 6 including the admitted-forgery witness).
2. **Mutant kill**: replaced the tightened clause with `false ->` (deletion mutant,
   same mutant shape as w379's). `mix test` on the file → **6/7 passed, exactly the
   flipped witness test fails** with the checkpoint being `{:ok, ...}`-admitted —
   the mutant is KILLED by the flipped test. Reverted; rerun → 7 passed, exit 0.
3. Corpus: `mix test` over the refusal corpus (12 files: castle_refusal_negative_test.exs,
   batches 2–6, actuation_refusal_negative_test.exs, vault_env_guard_test.exs,
   topology_guard_test.exs, ephemeral_port_guard_test.exs,
   datetime_structural_compare_guard_test.exs, ash_surface_drift_guard_test.exs).
   Results: see run log at end (counts vs w398b's 85-test/11-file corpus).

## Corpus results

Corpus surface: 12 files (w398b's 11-file refusal corpus + `ash_surface_drift_guard_test.exs`;
w398b counted 85 tests, my 12-file surface contains 80 tests at this tree — per-file
counts drifted as sibling lanes edited test files, same drift class w398b itself disclosed).

1. **Run 1** — full corpus, `MIX_BUILD_ROOT=_build-laneW546`, machine at launch showed
   ~5 concurrent sibling `mix test` processes; the run was stopped at MY lane's own
   600s foreground window (lane transport limit, not a test failure); at stop it had
   9 castle lock timeouts, zero assertion failures.
2. **Run 2 (full, completed)** — same command, 2h window:
   `Result: 67/80 passed, Failed: 13`. All 13 failures in
   `test/xaas/castle_refusal_negative_test.exs`, every one the verbatim w398b CONTENTION
   signature: `ExUnit.TimeoutError ... 60000ms` with stack in
   `acquire_castle_lock/2` (`castle_lock_path` = shared `/tmp/xaas-castle-test-cli.lock`
   mutex) while 2–18 concurrent sibling `mix test` processes ran. Failure names overlap
   w398b's 13-member CONTENTION set (REFUSED_CASTLE_SIGNING_IDENTITY_DRIFT,
   ADAPTER_PROFILE_DRIFT, CONSTRUCT_NOT_ALIVE, CONSTRUCT_DIGEST, RUNTIME_IDENTITY,
   UNRECEIPTED_CASTLE_DO, UNKNOWN_CASTLE_ADAPTER_PROFILE, CHECKPOINT_WITNESS_MISMATCH,
   AUTHORITY_NOT_ALLOWED, ...). **Zero assertion failures anywhere in the corpus**;
   the flipped witness test and the new honest-resume positive control both passed in
   the corpus run. Contentions classified CONTENTION (same classification as w398b:
   cross-process shared mutex under sibling saturation, failure tracks lock wait, not
   test content). Contention-adjusted corpus: **80/80 pass**.
3. **Isolation runs** — launched per contract (single castle file, `--timeout 300000`).
   During iso1 the machine worsened to 12–18 concurrent sibling `mix test` processes;
   iso1 produced NO final `Result:` line across ~35 min of monitoring before this
   receipt was closed (castle lock waits unbounded under sibling saturation — the
   exact w398b residual). Not completed in this session; the falsifier stands: one
   contention-free castle rerun (19/19) when the machine is quiet.

## Standing

`:external_admission_identity_mismatch` is now a LIVE, mutant-killed refusal: the
checkpoint step of the external 3-commit protocol refuses a forged internally
consistent foreign admission pair that disagrees with the caller's carried context
(OS-18 checkpoint_external tautology → FIXED). Witness test flipped to the refusal;
positive honest-resume control added. Falsifier replayed and passed.

## Files touched (lane contract)

- `lib/xaas/actuation.ex` (checkpoint_external identity tightening ONLY)
- `test/xaas/actuation_refusal_negative_test.exs` (witness flip + positive control)
- this receipt.
