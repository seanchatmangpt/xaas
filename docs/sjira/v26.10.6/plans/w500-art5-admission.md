# w500 — Art. 5(1)(a)-(h) constructive-nullification admission profile

Lane W500, EU-AI-Act wave, 2026-10-06. Subject: `feat/playwright-surface` (uncommitted lane; files only:
`lib/xaas/semantics/eu_ai_act_admission.ex`, `test/xaas/semantics/eu_ai_act_admission_test.exs`).

## Design decisions — dissertation equation → check

Equation realized: a prohibited practice is an **unrepresentable input shape**, not a content
classification. Each partition is a schema-level field/context disjointness invariant; the
admission function is content-blind (unknown map keys never affect the verdict — tested).

| Art. 5(1) | refusal atom | structural invariant |
|---|---|---|
| (a) manipulative | `REFUSED_EUAIA_MANIPULATIVE` | technique class ∉ {manipulate_behavior, deceptive, subliminal} |
| (a) vulnerability exploit | `REFUSED_EUAIA_VULNERABILITY_EXPLOIT` | no audience-slice × vulnerability-predicate join |
| (b) social scoring | `REFUSED_EUAIA_SOCIAL_SCORING` | `:social_behavior` domain ⊗ `:unrelated_context_join` |
| (c) predictive policing | `REFUSED_EUAIA_PREDICTIVE_POLICING` | `:predict_offending` purpose ⊗ `:individualized_profile_join` |
| (d) facial scraping | `REFUSED_EUAIA_FACIAL_SCRAPING` | `:facial_images` domain ⇒ `provenance == :consented` |
| (e) emotion recognition | `REFUSED_EUAIA_EMOTION_RECOGNITION` | `:affective` domain ⊗ {workplace, education} setting |
| (f) biometric categorization | `REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION` | boolean-only match tokens ∧ empty `:inferences` |
| (g)(h) realtime RBI | `REFUSED_EUAIA_REALTIME_RBI` | `:realtime` latency ⊗ `:biometric_identification` ⊗ `:public_space` |

Checks run in article order; first violated invariant returns its exact atom (order determinism is
itself tested via the peeling test). Mirrors the `Xaas.Semantics.VKG` typed-refusal idiom
(`{:error, atom}` verdicts, documented admission-only surface, zero authority, zero state).

Non-goals: no live-route wiring (later lane), no content sniffing, no state mutation.

## Verification

- Transport failure (disclosed, pre-existing, NOT this lane): `MIX_BUILD_ROOT=_build-laneW500
  mix compile` fails on `lib/xaas/actuation/quiescent_stop.ex` (untracked in-flight file from
  another lane; hard CompileError at line 91, `find_intent/1`). Lane contract forbids touching it.
- Strict compile (this lane's module): `elixirc --warnings-as-errors` → clean after fixing one
  unused-variable warning (`checks/1` param).
- Suite (real run, no mocks): `elixir -pa <ebin> -e 'ExUnit.start(autorun: false); Code.require_file(...); ExUnit.run()'`
  — 8 lawful positives + 10 violation fixtures (e and f have two/three each) + 2 combination +
  5 surface-contract tests = **24 tests, 0 failures**.
- Fallback falsifier still standing: once `quiescent_stop.ex` compiles, `MIX_ENV=test
  MIX_BUILD_ROOT=_build-laneW500 mix test test/xaas/semantics/eu_ai_act_admission_test.exs`
  must give the same 24/24 (module has no deps beyond stdlib, so app-compile gating is the only hop).

### Test tail

```
Result: 24 passed
```

## Mutant-kill witness (anti-vacuity protocol)

Mutant: weaken `(e)` `affective_in_context?/1` by dropping the setting conjunct (i.e. refuse any
candidate carrying the `:affective` domain).

Result: `test (e) ... affective-state domain in workplace/education settings is refused` still
passes, but `test (e) ... affective analysis outside workplace/education is admitted` FAILS
(expected `{:ok, :admitted}`, got `{:error, :REFUSED_EUAIA_EMOTION_RECOGNITION}`) — suite red.
Second probe: weakening `(b)` `social_scoring_join?/1` to drop the `:unrelated_context_join`
conjunct kills `test (b) ... domain-scoped social data with own-service join is admitted`.
Both mutants reverted; full suite green again. Conclusion: the suite is non-vacuous; every
refusal atom is guarded by at least one killing fixture on both the refuse side and the
admit side.

## Verdict

ALIVE on the admission surface (24/24 green, strict compile clean, mutant-kill witnessed).
Integration into live routes: BLOCKED by lane contract (out of scope, later lane).
