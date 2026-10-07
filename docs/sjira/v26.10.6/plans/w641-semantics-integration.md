# W641 — Full New-Module Integration Run (EU-AI-Act wave)

Lane: W641 · Repo: /Users/sac/xaas @ feat/playwright-surface · Build root: `_build-laneW641`
Date: 2026-10-07 · Toolchain: asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2 (pinned PATH)

## Command

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW641 \
  mix test test/xaas/semantics/ test/eu_ai_act/ \
  --include eu_ai_act --exclude eu_ai_act_open_gap
```

Note: `:eu_ai_act` is in the default `exclude` list (`test/test_helper.exs:56`);
without `--include eu_ai_act` the corpus is silently skipped (excluded 1125).
Invocation note: passing an explicit file list requires zsh `${=files}` word-splitting
(first two background runs no-oped with "Paths given to mix test did not match").

## Verdict: NOT FULL-INTEGRATION-GREEN — 1 compile blocker + 9 assertion failures (all NEW convergence defects)

### Blocker (verbatim finding)

`test/xaas/semantics/art12_chain_court_test.exs` does not compile — deterministic,
reproduced in isolation:

```
== Compilation error in file test/xaas/semantics/art12_chain_court_test.exs ==
** (ArgumentError) cannot inject attribute @checks into function/macro because cannot escape
#Function<0.53148651 in file:test/xaas/semantics/art12_chain_court_test.exs>.
The supported values are: lists, tuples, maps, atoms, numbers, bitstrings, PIDs and remote
functions in the format &Mod.fun/arity
    test/xaas/semantics/art12_chain_court_test.exs:54: Xaas.Semantics.Art12ChainCourtTest.w505_checks/0
```

Cause: `@checks` module attribute (lines 41-51) holds anonymous functions; Elixir cannot
inject funs via `@`. Fix shape (lane-owned fix, not applied here — contract is write-only
to this file): move the list into `defp checks, do: [...]` or convert entries to
`&Mod.fun/arity` remote refs. This blocks the ENTIRE run when the unfiltered command is
used (mix test aborts at compile of the combined set).

### Run results (art12_chain_court_test.exs excluded — it cannot compile)

With `--include eu_ai_act --exclude eu_ai_act_open_gap`:

```
Result: 1364/1373 passed, 1 skipped, 5 excluded
exit=2
```

- 1364 passed — the whole W500-series semantics module tree + eu_ai_act corpus
- 1 skipped, 5 excluded — the 5 excluded ARE the typed open-gaps (`eu_ai_act_open_gap`
  tag), inside the expected ~5-10 window. 2 structural assertions in-suite also
  witness the open-gap registry shape (`status: :OPEN_GAP`, right
  `:access_to_effective_remedy_authority_channel`) — matching the expected open-gap surface.
- 9 failures — all NEW convergence defects (none reproduces as known-flake: all deterministic).

## Findings (all NEW, verbatim)

1. [NEW] `test/eu_ai_act/title_i_test.exs:546` — "EUAI-ACT 3.49 — EVIDENCED (W538)":
   `assert @incident_test_count == Enum.count(Regex.scan(~r/^\s*test "/m, incident_test_body))`
   left: 6, right: 9. Stale hard-coded incident-test count witness: the W538 corpus grew
   to 9 tests; the count witness in title_i expects 6.
2. [NEW] `test/eu_ai_act/title_iii_test.exs:766` — "EUAI-ACT 15.5.s3 — EVIDENCED (W540)":
   `VulnerabilityLifecycle.respond(ticket, %{receipt: "diff w540 fix"})` returns
   `{:error, :REFUSED_LIFECYCLE_SKIP}` where the deepening expects `{:ok, :RESPONDED}`.
   The deepening drives DETECTED→RESPONDED, skipping TRIAGE; the real module refuses the
   skip. Deepening corpus vs module contract mismatch.
3. [NEW] `test/eu_ai_act/title_vi_xiii_test.exs:757` — 7 failures (73.1, 73.2, 73.2.s2,
   3, 4, 5, 6 — all "EVIDENCED (W538/W625)"):
   `assert Enum.sort(report.classification) == [:INFRINGES_UNION_LAW, :MALFUNCTION]`
   left `[:INFRINGES_UNION_LAW]`, right `[:INFRINGES_UNION_LAW, :MALFUNCTION]`.
   Two lanes assumed contradictory IncidentReport classification partitions: title_vi_xiii
   deepening expects a refused receipt to also classify MALFUNCTION; the W538
   classification is partition-exact INFRINGES_UNION_LAW-only (witnessed by the art12
   court's court (b) `refute :MALFUNCTION in report.classification`). One side must yield;
   needs coordinator resolution (W538 owner vs title_vi_xiii owner).

## Witnessed module inventory (green together, 39 files minus blocker)

27 semantics files (28 minus non-compiling art12): admission_attribution, admission_fuzz,
airo_risk_mapping, airo_vendored_pin, ash_r2rml, authority_channel,
authority_channel_incident_witness, authority_decoupling, automation_bias_countermeasure,
counterfactual, dataset_admission, declared_metrics, eu_ai_act_admission,
eu_ai_act_refusal_closed_set, incident_report, jcs, jcs_property, map_update_dual_safe,
master_equation, master_equation_stress, master_equation_soak, oversight_governance,
r2rml_refusal, registry, robust_margin, vkg_refusal_negative,
vkg_registry_nonempty_contract, vulnerability_lifecycle — all green.

12 eu_ai_act corpus files green except as listed: airo_grounding, art15_deepening,
art50_deepening, art73_chain_deepening, counterfactual, smoke, title_i, title_ii,
title_iii, title_iv_v, title_vi_xiii (+ support/).

Green includes the W500-series core: W500 EuAiActAdmission, W503 AuditChain (via chain
courts in semantics), W505/W506 Counterfactual, W536 DeclaredMetrics, W538 IncidentReport,
W539 AutomationBiasCountermeasure, W540 VulnerabilityLifecycle, W625 AuthorityChannel,
Shapley AdmissionAttribution, master-equation soak — all green together at the converged
tree.

## Logs

- /tmp/w641_run3.log (semantics-only run, no include flag: 250 passed, 1 skipped, 1125 excluded)
- /tmp/w641_run4.log (full flagged run: 1364/1373 passed, 1 skipped, 5 excluded, exit=2)
