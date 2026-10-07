# W645b — ex4pm AIRo risk description (ex4pm leg)

Lane: W645b (AIRo wiring wave, ex4pm leg). Repo: /Users/sac/ex4pm (one canonical
checkout, NOTHING committed — coordinator owns git transitions). Private build
root `_build-laneW645b` used for all mix commands
(`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW645b`).
Pre-existing uncommitted lane context cited as RiskControls, not reverted:
W604's 35 dual-safe patches + W609's oracle-site fix. No `Map.update` written
in this lane's diff (OS-20 hazard memory honored).

## Files written

- /Users/sac/ex4pm/priv/ontologies/airo_risk_description.ttl (new, 77 triples)
- /Users/sac/ex4pm/test/w645b_airo_risk_description_test.exs (new, 5 tests)
- this plan file (in xaas, outside the ex4pm write boundary per contract)

## Vocabulary

AIRo 1.0, sha256 `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
— byte-identical at both /tmp/airo.ttl (cached) and the canonical vendored copy
/Users/sac/xaas/priv/semantic/airo/airo.ttl (W600 vendor receipt). No re-fetch.

## Mapping

- ex4airo:Ex4pmProcessMiningOracle a airo:AISystem ; airo:isProvidedBy
  ex4airo:Ex4pmProvider (airo:AIProvider)
- 3 airo:RiskSource/Risk/Hazard individuals, all real documented items:
  - RiskMapUpdateAbsentKeyDeviation — otp-29 Map.update/4 absent-key deviation
    (fun skipped on absent key), MITIGATED: W604's 35 dual-safe patches at the
    w525d-census sites (VectorClock.tick, ObjectEvent.index, Markov.fit,
    InductiveMiner.directly_follows_graph) + W609's oracle-site fix. Likelihood
    medium / severity high (honest qualitative).
  - RiskConformanceSplit — alignment vs token-replay conformance split:
    lib/ex4pm_engine/alignment.ex (A* optimal alignment, Van der Aalst 2012)
    vs lib/ex4pm_engine/conformance/token_replay.ex. Likelihood medium /
    severity medium.
  - RiskReferenceOracleTruncation — reference-oracle trace-language truncation
    hazard W609 pinned: early bound exhaustion in
    lib/ex4pm/qualification/powl/reference_oracle.ex under-approximates the
    bounded language. Likelihood low / severity high (post-W609).
- 4 airo:RiskControl individuals = the real gates, files verified on disk:
  - ControlDualSafePatches → W604 dual-safe patches (35 sites) + their 8-test
    court, test/w604_map_update_dual_safe_test.exs
  - ControlOracleCanary → W609 canary + choice-graph pins,
    test/w609_oracle_site_test.exs
  - ControlTestSuite → the full ExUnit suite under test/ (958 test
    declarations on disk at this subject; contract called it the 896-test
    suite — both counts recorded, no overclaim)
  - ControlPowlConformanceModule → lib/ex4pm_engine/alignment.ex,
    lib/ex4pm_engine/conformance/token_replay.ex,
    lib/ex4pm/qualification/powl/reference_oracle.ex
- Qualitative Likelihood/Severity asserted as self-assessed individuals of
  airo:Likelihood / airo:Severity (W614 idiom, disclosed in the TTL header).

## Test court (executed, exact command)

```
cd /Users/sac/ex4pm && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
  MIX_BUILD_ROOT=_build-laneW645b mix test \
  test/w645b_airo_risk_description_test.exs \
  test/w604_map_update_dual_safe_test.exs \
  test/w609_oracle_site_test.exs
```

- Test assertions: TTL exists on disk; rdflib structural parse (77 triples;
  union with the 558-triple AIRo vocab strictly larger); all cited
  hasDocumentation paths exist on disk (>= 4); every AIRo term used is defined
  in the vocabulary (10 classes + 10 properties checked against the vocab
  source); OS-20 canary (Map.update/4 skips fun on absent key) still passes.
- One fix-forward cycle: initial TTL used single-quoted multi-line strings
  (rdflib BadSyntax, 14/15); converted to Turtle long strings, reparse 77
  triples, rerun → green.
- Final tail: `Finished in 0.2 seconds … Result: 15 passed` (15/15, includes
  W604's 8-test court and W609's canary suite).

## Standing

ALIVE for this lane's falsifier (parse + path-existence + vocabulary-term
check + OS-20 canary), executed on the exact on-disk subject under the lane
build root. Not committed. Writes confined to the contract surface
(priv/ontologies/airo_risk_description.ttl, its test, this plan file).
