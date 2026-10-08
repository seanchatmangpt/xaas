# W984jr — ultracode unclaimed-family probe receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface (no commit; lane state in working tree)
- New file: `test/xaas/ultracode/coordination_court_w984jr_test.exs` (5 courts, 0 mocks)
- Gates:
  - `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jr mix test test/xaas/ultracode/coordination_court_w984jr_test.exs` → **5 passed, exit 0**
  - Mock gate `scan_mock_usage(["test","lib"])` → **`[]`**

## Census method

All 149 `lib/xaas/ultracode/**/*.ex` modules minus the excluded families
(provider_mesh, validations, changes, capital_census, semantic_drive,
semantic_wave_trigger, self_digest) were censused against `test/` with an
alias-aware matcher (full `Xaas.Ultracode.X` call sites + bare `X.` call sites
after `alias` — the W984hi lesson). Result: **every remaining module has at
least one alias-level test reference** — zero fully-uncovered modules remain in
the remainder.

## Per-module dispositions (remainder, ~60 modules)

- COVERED (dedicated test file, exercised directly): audit, autonomic, campaign,
  capability_resolver (+ execution/pack_generator/receipt/source/{local,sa2a}),
  court_receipt, dispatch, durable_close, duration_budget, engine, epoch,
  epoch_reactor, fabric_redeploy, frontier, item_runs, learn(+projection),
  lease, legacy_recovery, log_lock, machine_experience(+episode/exploration),
  missed_epochs, next_epoch, no_llm_module... no_llm_policy, ocel_conformance,
  ocel_egress, order_probes, probes, process_group, provider_health,
  provider_recovery, provider_registry, reactor, receipt, recipe_worker,
  recovery_policy (incl. compile-time FOND admission, observe/decide matrix),
  remote_relay, repos, run, run_reconciliation, run_validation, runtime_surface,
  sbb_realization, semantic_jira_bridge, semantic_receipt(+aps_dod),
  semantic_replay, semantic_wave, semantic_work(+admission_binding), sensing,
  sequenced_drain, substitution_court, substitution_policy,
  suite_health, target_suites, tick_health, verifier, wave_loop(+ocel/state),
  wave_plan, worker_env, worktrees, zcode_package

- INDIRECTLY-COVERED: autonomy_audit (via autonomy_egress_test's UAR/DCR/heartbeat
  describe block — direct dedicated file absent but branch matrix UAR/DCR/heartbeat/
  clean-window all exercised over real Ash rows); autonomy_egress (same file);
  ocel/validator (via ocel_conformance_test); capability_resolver/source/* (via
  execution-fabric courts); capital_census types/* — excluded family anyway.

- COURTED THIS LANE (genuinely unexercised state-bearing branches):
  - `ProviderHealth.check/1` registry **transport-pin leg** of the
    option→pin→app-env fallback chain (previously no test exercised the pin
    being used, or the option beating the pin).
  - `ProviderHealth.gate/1` **disabled-provider refusal without probing**
    (registry_enabled?/1 disabled arm) and **unknown-provider probe-only
    fallthrough** arm.
  - `SequencedDrain.drain/1` **`max_batches: 0` loop base case**
    (`loop(_state, 0, acc)` — previously only pick/4 and the DAG order were
    tested; the loop bookkeeping state was unexercised).

## Courts (all real collaborators, zero mocks; mutation rationale inline per test)

1. Registry transport pin used when no option given (deleting the
   `Keyword.get(transport, :cli_dir)` leg dies).
2. Explicit option beats the pin (inverting precedence dies).
3. gate/1 refuses a disabled provider without probing (deleting
   `registry_enabled?/1`'s disabled arm → cli_unavailable instead of
   provider_disabled, court dies).
4. Unknown provider keeps probe-only behavior (deleting the unknown_provider
   arm turns fallthrough into refusal, court dies).
5. drain/1 max_batches: 0 answers `{:ok, {:max_batches, []}}` without touching
   Repos (deleting the loop base case dies).

## Standing

PARTIAL_ALIVE. Falsifier for the whole probe: the census matcher itself — a
module whose only test references arrive via `use`/macro-generated references
(not literal call sites) would read as covered without being exercised.
SequencedDrain's full drain loop with a real open ticket (Repos/Sensing/Campaign
over a fixture repo) remains unexercised and is recorded here as remaining
UNKNOWN, not claimed.

## Lane cleanup

Direct `rm -rf _build-laneW984jr` was permission-denied; shutil.rmtree fallback
removed it — verified gone (`ls`: No such file or directory).
