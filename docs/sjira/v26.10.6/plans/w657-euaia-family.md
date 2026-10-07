# W657 — EUAIA family clauses in `risk_concept_for/1`

## Subject

- Repo: `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout)
- Lane build root: `_build-laneW657`, `MIX_ENV=test`
- Contract files (all touched here, none outside):
  - `lib/xaas/semantics/airo_risk_mapping.ex`
  - `test/xaas/semantics/airo_risk_mapping_test.exs`
  - `test/eu_ai_act/airo_grounding_test.exs`
  - this file

## Pinned typed finding (W702)

Every Art. 5 atom (`REFUSED_EUAIA_*`, W500's 8-atom set in
`lib/xaas/semantics/eu_ai_act_admission.ex:33`) fell through
`AiroRiskMapping.risk_concept_for/1` to the generic
`UNADMITTED_TRANSITION` fallback: the cond had no EUAIA family clause.

## Change

Added the EUAIA family as the first clauses of the `risk_concept_for/1`
cond (ahead of every generic substring family), plus a MALFORMED class:

| atom | risk concept | dissertation partition |
|---|---|---|
| `REFUSED_EUAIA_MANIPULATIVE` | `RISK_TO_INFORMED_CHOICE` | risk to informed choice |
| `REFUSED_EUAIA_VULNERABILITY_EXPLOIT` | `RISK_TO_VULNERABLE_PERSONS` | risk to vulnerable persons |
| `REFUSED_EUAIA_SOCIAL_SCORING` | `CROSS_CONTEXT_RISK` | cross-context risk |
| `REFUSED_EUAIA_PREDICTIVE_POLICING` | `DUE_PROCESS_RISK` | due-process risk |
| `REFUSED_EUAIA_FACIAL_SCRAPING` | `PRIVACY_RISK` | privacy risk |
| `REFUSED_EUAIA_EMOTION_RECOGNITION` | `MENTAL_PRIVACY_RISK` | mental-privacy risk |
| `REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` | `DISCRIMINATION_RISK` | discrimination risk |
| `REFUSED_EUAIA_REALTIME_RBI` | `SURVEILLANCE_RISK` | surveillance risk |
| `REFUSED_EUAIA_MALFORMED_CANDIDATE` | `MALFORMED_INPUT_CANDIDATE` | malformed-input class |

`risk_graph/0` additionally emits one `airo:RiskSource`/`airo:Hazard` node
per Art. 5 atom (the refusal ledger has no EUAIA variants, so the grounded
concepts would otherwise never appear in the emitted graph) with
`ex:mapsToRiskConcept` edges and matching `airo:hasRisk` edges. The
ex:-qualified concept locals follow the standing consumer convention.

## Fallback reachability

For the 8 EUAIA atoms the `UNADMITTED_TRANSITION` fallback is now
unreachable: each atom is captured by its specific `EUAIA_*` clause before
any generic family (AUTHORITY/DIGEST/RECEIPT/SEMANTIC/...) is consulted.
The fallback itself is unchanged for non-EUAIA variants
(`REFUSED_TOTALLY_BOGUS_ATOM` still grounds to `UNADMITTED_TRANSITION`).

## Verification

Commands (pinned toolchain via asdf shims, lane build root):

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW657 MIX_ENV=test mix compile
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW657 MIX_ENV=test \
  mix test test/xaas/semantics/airo_risk_mapping_test.exs test/eu_ai_act/airo_grounding_test.exs
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW657 MIX_ENV=test \
  mix test test/xaas/eu_ai_act_admission_test.exs test/xaas/master_equation_test.exs
```

Results (all exit 0):

- `mix compile` under `_build-laneW657`: `Generated xaas app`, exit 0
- `mix compile --warnings-as-errors`: exit 0
- airo_risk_mapping_test + airo_grounding_test: **15 passed, 1 skipped**
  (rdflib round-trip skips without a local python parser; pure-Elixir
  structural assertions all pass)
- master_equation_soak + admission_fuzz + eu_ai_act_refusal_closed_set +
  master_equation: **26 passed, 0 failed**

Note: running `master_equation_soak_test.exs` WITHOUT
`master_equation_test.exs` in the same invocation fails 4 tests with
`Xaas.Semantics.MasterEquationTest.f_actuate/2 is undefined` — a
test-load-isolation artifact of the soak suite's direct cross-module call,
pre-existing and unrelated to this lane's diff (reproduces identically on
the unmodified mapping).
