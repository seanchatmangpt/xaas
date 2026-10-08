# W984ka — unclaimed-family probe: library authorship/subject family

Lane: W984ka · Repo: /Users/sac/xaas · Branch: feat/playwright-surface · Date: 2026-10-08
File: `test/xaas/library/authorship_court_w984ka_test.exs` (new, one file, 5 courts)
NO commit (per lane contract).

## Census and dispositions

No author/subject/topic/category resources exist in `lib/xaas/library/`. Unclaimed
candidates censused against `test/`:

| module | disposition |
|---|---|
| book, checkout, hold_request, school, config, ils_repo, curation, embeddings, explainer, persona_grant, ranker | COVERED — dedicated test files exist and are exercised |
| recommendation_log.ex | PARTIAL → courted. Behavior covered via next_read tests, but only `authorize?: false`; the deny-by-default policy floor (`policy action_type([:create,:update,:destroy]) authorize_if actor_present()`) and guest-read branch had ZERO direct exercise. 5 new courts. |
| changes/write_actor_resolution_audit.ex | INDIRECTLY COVERED — a2a persona tests assert real `a2a.actor_resolution.allowed/denied` audit rows (next_read_user_agent_test.exs:155,180; w984em court:134; vision_2030_avatars:121) |
| changes/enforce_borrow_cap.ex | INDIRECTLY COVERED — checkout_hold_lifecycle_stress_test.exs:163,202 (cap refusal on :fulfill) |
| changes/{decrement,increment}_book_inventory, fulfill_next_hold | COVERED — checkout concurrency/cascade courts |
| reactors/ | COVERED — reactor/step courts |

## Courts (5/5 pass)

1. guest (actor nil) read of RecommendationLog → `{:ok, [...]}` (documented guest-browse branch)
2. anonymous create refused → `Ash.Error.Forbidden`; real state asserted (no row landed)
3. actor-present create allowed via real policy evaluation (not `authorize?: false`)
4. `update :accepted` toggle: actor nil refused Forbidden; actor-present update persists (re-read from DB)
5. destroy: actor nil refused; actor-present `Ash.destroy` → `:ok`; row gone (re-read)

Mutation rationale: each court observes the real authorization verdict; mutating the
policy floor (dropping `authorize_if actor_present()` or requiring actor for reads)
flips the observed verdict, so the branch is non-vacuous.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ka mix test test/xaas/library/authorship_court_w984ka_test.exs`
  → `Result: 5 passed` (exit 0; 3 repair rounds: for_update/for_destroy argument shape, destroy return `:ok`)
- Mock gate: `[]` (expect [])
- `rm -rf _build-laneW984ka`: DELETED (lane lease released)

## Standing

ALIVE for the RecommendationLog policy-floor branch family; all other family members
typed COVERED / INDIRECTLY-COVERED as tabled above.
