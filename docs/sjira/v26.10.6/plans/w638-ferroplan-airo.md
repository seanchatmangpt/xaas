# W638 — ferroplan AIRo risk description (ferroplan leg)

Lane: W638 (AIRo wiring wave, ferroplan leg). Repo: /Users/sac/ferroplan (one
canonical checkout, nothing committed). No git operations performed. Private
target dir untouched (no cargo commands needed — this lane maps existing gates,
builds nothing).

## Files written

- /Users/sac/ferroplan/docs/airo-risk-description.ttl (new)
- /Users/sac/ferroplan/scripts/check_airo.sh (new, executable)

## Vocabulary

Reused the cached /tmp/airo.ttl: sha256
6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469 — matches
W600's verified fetch sha (recorded in w600-airo-vendor.md). No re-fetch.

## Mapping

- fp-airo:FerroplanSystem a airo:AISystem ; airo:isProvidedBy
  fp-airo:FerroplanProvider (airo:AIProvider)
- 2 airo:Risk = airo:RiskSource individuals, each a real documented hazard:
  - RiskUnreachableGoalPlanning — unreachable-goal planning into prohibited
    states; the exact hazard BackwardSafeSet eliminates (dissertation Ch3
    Theorem 3.1; reachability.rs module header; W501 receipt)
  - RiskPlanNonDeterminism — sequential-plan dead-sink under adversarial oneof
    outcome resolution; documented by planning_runtime.rs
    fond_policy_strong_cyclic (:923) and its dead-sink reproducer tests
    (:2286, :2314)
- 4 airo:RiskControl individuals = the real gates, files verified on disk:
  - ControlBackwardSafeSet → crates/ferroplan/src/reachability.rs
    (BackwardSafeSet::from_successors/from_predecessors/is_safe/unsafe_count/
    depth_reached/saturated)
  - ControlReachabilityCourt → crates/ferroplan/src/reachability.rs tests
    module; 6 tests, skip(1)-predecessor-edge mutant killed 4/6
    (receipt: w501-art9-reachability.md)
  - ControlForbiddenOpMask → crates/ferroplan/src/session.rs:187 (forbidden
    field) dispatched at crates/ferroplan/src/search.rs:984/1410 (verified by
    grep this session)
  - ControlStrongCyclicSolver → crates/ferroplan/src/planning_runtime.rs:923
    (fond_policy_strong_cyclic); hddl.rs:339 documents the surface
- Likelihood/Severity individuals not asserted (AIRo defines the classes, no
  individuals; self-assessment deferred — noted in the TTL standing comment,
  unlike W614 which asserted self-assessed individuals).

## Check output (real run, /Users/sac/ferroplan/scripts/check_airo.sh)

- 5/5 cited paths exist on disk (line-number suffixes stripped before the
  existence test — a W638 refinement over W614's regex)
- TTL parses with rdflib (/tmp/airo-venv): 592 triples after union with the
  AIRo vocabulary
- 15/15 AIRo terms used are defined in the fetched vocabulary
- check_airo: PASS (first run FAILED on line-numbered citations; regex fixed
  and rerun — fix-forward, no reset)

## Standing

ALIVE for this lane's falsifier (parse + path-existence + vocabulary-term
check), executed on the exact on-disk subject. Not committed (coordinator owns
git transitions). Pre-existing lane context (W501's uncommitted
reachability.rs, W601-era uncommitted state) cited, not reverted.
