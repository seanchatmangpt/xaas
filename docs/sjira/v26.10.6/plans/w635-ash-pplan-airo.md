# W635 — ash_pplan AIRo risk description (AIRo wiring wave)

- **Repo**: /Users/sac/ash_pplan @ fix/ggen-verify-header (one canonical checkout; private build root `_build-laneW635`; no commit — coordinator owns integration).
- **Scope honored**: writes confined to `priv/airo_risk_description.ttl` (new), `test/airo_risk_description_test.exs` (new), and this plan file. No other files touched; W291's 2 patches and W603's 8 dual-safe sites left untouched (cited as RiskControls).
- **Vocabulary**: AIRo 1.0 per W600 — `https://w3id.org/airo#`, vendored in xaas at `priv/semantic/airo/airo.ttl`, sha256 `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` (DelaramGlp/airo@6c67de43).
- **Standing**: ALIVE (artifact on disk + rdflib parse + 4/4 ExUnit green)

## Subject

- `priv/airo_risk_description.ttl` — 92 triples (rdflib turtle parse, exit 0)
- `test/airo_risk_description_test.exs` — structural court, 4 tests

## Mapping (AIRo → ash_pplan reality)

**AISystem**: `w635:FondPolicyPlanner` — the FOND policy planner + durable Reactor
engine (synthesis, policy supervisor offers, checkpointed engine, step-keyed ledger
`key.ex`, Dets/Ets continuation store).

**RiskSources** (3, all real documented hazards):

| id | hazard | status |
|---|---|---|
| RS-1 `ForgedPairAdmission` | w379 `checkpoint_external/2` tautology — internally consistent forged `{intent, receipt}` pair ADMITTED | MITIGATED — closed downstream by W546's live `:external_admission_identity_mismatch` clause (lib/xaas/actuation.ex, xaas repo), witness flipped + mutant-killed |
| RS-2 `DeadClauseMasking` | `defp rank(_), do: 9` dead fallback in offers ranking silently deprioritizing unknown offer kinds | ELIMINATED — W291 deleted the clause from `lib/ash_pplan/fond/policy_supervisor/offers.ex`; unknown offers now raise FunctionClauseError |
| RS-3 `ResumeExternalStateHazard` | resumed continuation observes external state moved since checkpoint (durable bridge surface) | OPEN residual, bounded — migration/resume skip logic must match `key.ex` derivation exactly |

**RiskControls** (5, all real paths):

| control | gates |
|---|---|
| `ExternalIdentityClause` | W546 live clause + flipped mutant-killed witness (`test/xaas/actuation_refusal_negative_test.exs`, xaas) |
| `ManufactureVerifyGate` | `bin/verify-package` + `bin/gate` (`mix compile --warnings-as-errors`) + `test/manufacture_test.exs` — now PASSING per W291 |
| `ReactorReconciliationSaga` | `lib/ash_pplan/reactor/durable/steps/{dispatch,poll}.ex` + `compensations/{dispatch,poll}.ex` |
| `DurableContinuationStore` | `store.ex` + `store/{dets,ets}.ex` + `key.ex` + `migration.ex` resume-skip + `test/durable/` suite |
| `DualSafeMapUpdatePin` | W603 dual-safe `Map.update` idiom + regression pin `test/map_update_absent_key_test.exs` |

**Qualitative assessment**: hasLikelihood Low (post-mitigation), hasSeverity Medium
(consumer state integrity/auditability); residual risk remains hasRisk.

## Verification (executed)

1. rdflib turtle parse: **92 triples**, exit 0.
2. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW635 mix test
   test/airo_risk_description_test.exs` → tail:

```
....
Finished in 0.03 seconds (0.03s async, 0.00s sync)

Result: 4 passed
```

All 18 VIA-cited paths exist on disk (asserted by the path-exists test, not eyeballed).

## Notes for coordinator

- The W546 clause lives in the xaas consumer surface, not ash_pplan; the TTL cites it
  by name + xaas path inside dcterms:description (not VIA, so the in-repo path check
  stays truthful).
- All citations to W291/W603 landings describe them as uncommitted on
  fix/ggen-verify-header, matching W291's pin warning — do not advance xaas pins
  until committed.
