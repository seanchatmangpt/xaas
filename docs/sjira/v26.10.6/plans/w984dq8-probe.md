# W984dq8 — coverage burn-down probe (runtime + chicago courts)

- **Lane**: W984dq8, xaas v26.10.6 campaign, branch `feat/playwright-surface`
- **Subject**: no commit (per lane law). Lane writes:
  - `test/xaas/runtime/provider_registry_deepening_test.exs` (new, 5 tests)
  - `test/xaas/chicago/layer_deepening_test.exs` (new, 5 tests)
  - `docs/sjira/v26.10.6/plans/w984dq8-probe.md` (this receipt)

## Command + real output

From `/Users/sac/xaas`, `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`,
`MIX_BUILD_ROOT=_build-laneW984dq8`:

```
mix test test/xaas/runtime/provider_registry_deepening_test.exs test/xaas/chicago/layer_deepening_test.exs
# → ..........
#   Finished in 0.1 seconds
#   Result: 10 passed
```

Exit 0. 10/10 real executions against real supervised GenServer state and real
machine-projection maps; zero mocks.

## Census (2 candidate families)

### Family A — Billing non-approval / non-subscription modules

Modules: `fibo_revenue_profile`, `revenue_recognition`, `revenue`
(`subscription` and `approval_*` excluded per lane contract).

| module | existing coverage | verdict |
|---|---|---|
| `Xaas.Billing.Revenue` | `fibo_revenue_actuation_test.exs` exercises `recognize/3` incl. `{:revenue_amount_must_be_positive, "0"}`, missing-authority, invalid-source refusals | COVERED (thin residue: `invalid_accounting_classification`, `invalid_currency_code`, non-map-attrs branches unasserted — deferred as thin) |
| `FiboRevenueProfile` | `fibo_profile_admission_boundary_w650y_test.exs` + `fibo_revenue_actuation_test.exs` (4 refusal cases) | COVERED |
| `RevenueRecognition` | multitenancy court + w650y boundary + actuation tests | COVERED |

**Disposition**: family COVERED — no court needed; the family's top gap
(`Billing.Revenue` refusal branches) is thin.

### Family B — fresh zero-reference census over lib/xaas

Method: for every `lib/xaas/**/*.ex` module, grep `test/` for the full
CamelCase module name; modules with zero test references, by line count:

```
326  Xaas.Operations.ProjectMeasure.Census                     (ops — W984dk done)
317  Xaas.Sa2a.Changes.Execute                                 (sa2a — unclaimed)
154  Xaas.Semantics.VKG.Witness                                (semantics — W650w2 done)
148  Xaas.Billing.Changes.ApprovalPatchSlaCreditApplyApprove   (billing approvals — excluded)
137  Xaas.Ultracode.CapabilityResolver.Source.Local            (ultracode — W984dj4 done)
137  Xaas.Actuation.Validations.CausalAdmission                (actuation — W984dq6 running)
121  Xaas.Operations.ProjectMeasure.AdmissionReactor           (ops — done)
115  Xaas.AwsRepo.AwsAdapter                                   (aws — unclaimed)
115  Xaas.Operations.ProjectMeasure.Verifiers.ValidateConfiguration (ops — done)
113  Xaas.Ultracode.AutonomyAudit                              (ultracode — done)
101  Xaas.PromEx                                               (uncensed)
 94  Xaas.Library.School                                       (library — unclaimed)
 94  Xaas.Chicago.Layer                                        (chicago — unclaimed) ← court 2
 91  Xaas.Runtime.ProviderRegistry                             (runtime — unclaimed) ← court 1
```

**Court pick (×2 fresh roots)** — top state-bearing uncovered modules outside
every running lane's family:

1. `Xaas.Runtime.ProviderRegistry` (91 lines, runtime family): only indirect
   coverage via `router_test.exs`, whose setup always runs a threshold-1
   registry — the `:degraded` mid-state and the threshold-2 open transition
   had never been exercised against the registry's own contract.
2. `Xaas.Chicago.Layer` (94 lines, chicago family): sole lib consumer is
   `Xaas.Chicago.View`; `fetch/2`'s typed refusal, `standing/1`'s R8
   own-status-only law, and `list/1`'s contract order had zero direct
   coverage.

### Test/support residue census (family B adjunct)

| file | refs outside test/support | disposition |
|---|---|---|
| `test/support/dod_fixture.ex` | 5 | ALIVE |
| `test/support/semantic_jira_bridge_fixtures.ex` | 9 | ALIVE |
| `test/support/fake-node.sh` | 6 | ALIVE |
| `test/support/sip2_test_server.ex` | 2 (`library/ils_repo/sip2_adapter_test.exs`) | ALIVE |
| `test/support/vkg_observation_engine.ex` | 0 | DEAD residue |
| `test/support/generator.ex` | 0 | DEAD residue |
| `test/support/ultracode_semantic_case.ex` | 0 | DEAD residue |

DEAD residue typed disposition: **UNSUPPORTED(dead-residue)**. Lane writes
tests + receipt only; deletion is a coordinator transition.

## Court 1: Xaas.Runtime.ProviderRegistry (5 tests, all green)

1. **Registration defaults** — `register/2` + `snapshot/0` shows
   `{status: :ready, failures: 0, opened_at: nil, priority: 100}`; explicit
   priority honored. Mutation killed: dropped `put_in` insert or defaults.
2. **Capability filter + rank order** — ready < degraded < open, priority
   tie-break; `:observe` returns only the multi-capability provider. Mutation
   killed: inverted `rank/1` or dropped `status != :open` filter. Note: first
   run's expectation inverted the real contract (ready sorts BEFORE degraded);
   test corrected to the module's actual ordering — lib/ untouched.
3. **Circuit state machine** — one failure (threshold 2) → `:degraded`, still a
   candidate; second failure → `:open` with integer `opened_at`, excluded from
   candidates. Mutation killed: `n >= state.threshold` comparison or degraded
   mid-state.
4. **Success resets** — `report/2` with `:ok` after a failure →
   `{failures: 0, status: :ready, opened_at: nil}`. Mutation killed: `:ok`
   clause failing to reset.
5. **No-op unknown cast + breaker clear** — `report` on an unknown provider
   neither crashes nor inserts; re-`register` of an opened provider yields a
   fresh `:ready` entry. Mutation killed: `update/3` catch-all; register
   overwrite semantics.

## Court 2: Xaas.Chicago.Layer (5 tests, all green)

1. **Fixed contract order** — `required_ids/0` = the ten R2/R4 ids in order;
   successors (`wasm4pm`, `castle`) never interleave. Mutation killed:
   reordering or re-parenting ids between required/successor sets.
2. **Labels + known? duality** — every id has a label; `known?/1` accepts atom
   and binary; false for unknown atom/binary/integer. Mutation killed: dropped
   `@labels` entry or a broken atom/binary path.
3. **list/1 order + missing-layer loudness** — projection order ignored,
   required order wins, successors excluded; a missing required layer raises
   `KeyError` (never silently reordered). Mutation killed: `Map.fetch!` →
   `Map.get`.
4. **Typed refusal on unknown fetch** — `{:refused, {:chicago_layer_unknown, id}}`
   for atom and binary ids. Mutation killed: returning `{:ok, nil}`.
5. **R8 own-status-only standing** — status-free projection ⇒ every layer
   "UNKNOWN"; one annotated layer does not leak to siblings; `%{}` →
   "UNKNOWN". Mutation killed: sibling-status inheritance or non-"UNKNOWN"
   default.

## Verification ladder

- narrow/unit: both new files, one run — `Result: 10 passed`, exit 0 (first
  run 9/10 with one wrong expectation corrected against the module's real
  ordering; no lib/ edits).
- integration/e2e: out of lane scope (no prod code touched).

## Standing

- Court 1 (`Xaas.Runtime.ProviderRegistry`): **ALIVE** — 5/5 observed
  executions on real state.
- Court 2 (`Xaas.Chicago.Layer`): **ALIVE** — 5/5 observed executions.
- Family A (billing non-approval): **COVERED** (thin residue noted).
- Test/support residue: `dod_fixture.ex`, `semantic_jira_bridge_fixtures.ex`,
  `fake-node.sh`, `sip2_test_server.ex` ALIVE; `vkg_observation_engine.ex`,
  `generator.ex`, `ultracode_semantic_case.ex` typed
  **UNSUPPORTED(dead-residue)**.

## Falsifiers

- F1: any of the 10 tests fails on current HEAD (re-run the command above).
- F2: `:degraded` mid-state or rank ordering changes without the court
  catching it (mutation rationale per test in file moduledocs).
- F3: a layer's standing becomes derivable from a sibling's status while
  Court 2 test 5 still passes.

## Transport failures

None. One expectation correction (Court 1 test 2, first run 9/10 → 10/10).

## Lane lease

`_build-laneW984dq8` (~430 MB) left in place — `rm -rf` was denied by the
session permission system; deletion is a coordinator transition per the
fanout cleanup law.
