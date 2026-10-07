# W650w — Coverage burn-down probe (SelfDigest promotion pipeline)

Date: 2026-10-07. Repo: /Users/sac/xaas, branch `feat/playwright-surface`,
lane build roots `_build-laneW650w` / `_build-laneW650w2`. Lane W650w,
v26.10.6 campaign. No commit (coordinator owns commits).

Diff: `test/xaas/self_digest/promotion_pipeline_depth_test.exs` (new,
5 tests) + this receipt. Nothing under `lib/` touched.

## Census (fresh, CamelCase word-bounded, 2026-10-07)

Targeted census on the unclaimed candidates first:

- Billing non-subscription-change: `RevenueRecognition` 3 test files,
  `FiboRevenueProfile` 1, `Revenue` 3 — covered (and W650k's audit
  remediation makes this family skip per task).
- TemporalMemory: 5 test files
  (`temporal_memory_deepening_test.exs`, `observation_witness_tie_test.exs`,
  `temporal_memory/query_and_replay_test.exs`,
  `observation_supersede_chain_depth_test.exs`, `observation_test.exs`) —
  covered, not a candidate.
- Semantics remainder: `EuAiActAdmission` 20, `Registry` 17,
  `IncidentReport` 14, `AuthorityChannel` 10, `AdmissionAttribution` 9,
  `DeclaredMetrics` 7, `VulnerabilityLifecycle` 7, `AutomationBiasCountermeasure` 6,
  `GraphlawWasm` 3, `R2RML` 3 — all covered; nothing left in the family.
- Graphlaw: `Catalog`/`Capability`/`LimitGate`/`EngineLimit` covered by
  `test/xaas/graphlaw/{catalog_test,graphlaw_deepening_test,graphlaw_limit_gate_test}.exs`
  and `test/xaas/chicago/bridges/graphlaw_assess_deepening_test.exs`.

Full-module census: all 961 `defmodule` names in `lib/` swept against
`test/**/*.exs` (word-bounded, per-module last segment). 213 zero-ref
modules; family-level follow-up eliminated most (XaasWeb HTML/controllers,
Mix tasks, Ash Changes/Validations exercised via resources, covered
families: ResearchRuntime, Trimtab, ProviderFabric, Ultracode ProviderMesh,
ProviderFabric tests). Genuine gap found:

- **`Xaas.SelfDigest.{Shadow,Promotion,Admission,Receipt,Replay,Evidence,Gap,Work,Observation}`**
  — zero direct test refs family-wide. The only test touching the family
  (`test/mix/tasks/xaas_self_digest_test.exs`) exercises the mix task's
  file output (`Xaas.Ultracode.CapitalCensus.WorkOrder` is its subject,
  a different module family); the ultracode capital-census self-digest
  tests (`test/xaas/ultracode/capital_census/self_digest_*.exs`) cover
  `Xaas.Ultracode.*`, not `Xaas.SelfDigest.*`. State-bearing pipeline:
  shadow ledger → admission gate → sealed receipt → replay/chain
  verification.

## Court

`test/xaas/self_digest/promotion_pipeline_depth_test.exs` — 5 tests, real
collaborators (the modules themselves, no doubles), final-state assertions,
typed refusals asserted as-real (`{:refused, :no_exact_subject_evidence}`,
`{:refused, :falsified}`, `{:error, :replay_mismatch}`,
`{:error, {:broken_chain, id}}`, `FunctionClauseError` on one-shot-state
violations):

1. **promote happy path** — exact-subject evidence admits; sealed receipt
   id equals an independently `Receipt.seal/5`-sealed id (determinism);
   replay through the same reducer reproduces `receipt.after`. Kills the
   promote-without-admission mutant family.
2. **cross-subject refusal** — `{:refused, :no_exact_subject_evidence}`,
   gap stays `:open`, full promotion refuses rather than sealing. Kills
   existence-only-admission mutant (dropped `same_subject?` filter).
3. **falsifier refusal** — `{:refused, :falsified}` on tampered and on
   mixed evidence. Kills dropped-falsifier-clause mutant.
4. **replay/chain integrity** — mismatch and broken-chain typed errors;
   honest replay succeeds; `chain/1` head is the last receipt's id
   (observed semantics: reduce returns the last receipt's id, fixed after
   first-run failure). Kills skip-output==after and broken-chain-blind
   mutants.
5. **receipt determinism + one-shot shadow** — identical payloads seal to
   identical 64-hex ids, any payload change changes the id; `append/2`
   and `materialize/2` on a materialized shadow raise `FunctionClauseError`;
   failing reducer → `{:error, %{status: {:refused, :boom}}}`. Kills the
   dropped-`:deterministic`-flag and dropped-`:open`-guard mutants.

## Verification (×2 fresh roots, pinned toolchain)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650w \
  mix test test/xaas/self_digest/promotion_pipeline_depth_test.exs
→ Result: 5 passed, exit 0   (fresh compile, root 1)
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650w2 \
  mix test test/xaas/self_digest/promotion_pipeline_depth_test.exs
→ Result: 5 passed, exit 0   (fresh compile, root 2)
```

Whole-dir rerun `mix test test/xaas/self_digest/` in root 1: 5 passed
(the directory contains only this lane's file).

Benign diagnostic: elixirLS-type warning at test line 155 (the
`assert_raise FunctionClauseError` closure — the compiler cannot see the
raise is intentional); tests pass on both roots.

## Standing

- `Xaas.SelfDigest` pipeline family: **ALIVE** (observed execution on
  exact subject, both fresh roots, typed refusals witnessed).
- Court: `ALIVE` (5/5 ×2 fresh roots).
- Test 4 first-run finding kept honest: `Replay.chain/1` returns the LAST
  receipt's id (not the head's); the court pins the observed semantics.

## Handoff

- Lane build roots `_build-laneW650w/`, `_build-laneW650w2/` deletion was
  denied by the permission system — **left on disk for coordinator**
  (per lane instructions: delete when done, else leave for coordinator).
- Zero-census residue: 213 zero-ref modules remain family-covered via
  resource paths (Ash Changes/Validations, XaasWeb HTML, Mix tasks) —
  next burn-down lane should census those families indirectly rather
  than court them individually.
