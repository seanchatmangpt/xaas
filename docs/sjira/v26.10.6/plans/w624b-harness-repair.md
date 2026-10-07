# W624b — counterfactual harness repair (lane receipt)

Lane: W624b · 2026-10-06 · repo /Users/sac/xaas @ feat/playwright-surface ·
build root `_build-laneW624b` · scope: 2 test files only (NO lib edits).

## Per-failure diagnosis (W611's 5)

### counterfactual_test.exs

1. **Compile error (blocked the whole file)** — Art 72 harness called
   `art72_drift_decision/2` but the helper was never defined (only
   `art72_net/0`, `art72_log_fitness/2`, `art72_replay/2` were). Fix: added
   the Definition-7.2-adjacent drift rule
   `fitness < 1.0 - threshold → :DRIFT else :NO_DRIFT`
   (counterfactual_test.exs, above `art72_log_fitness/2`).
2. **Art 72 KeyError** — factual/perturbed traces use OCEL event names
   (`"actuation_receipt.prepare"` etc.) but the inline net's transition keys
   were bare atoms (`:prepare`, `:actuate`, `:sealed_receipt`). Fix: renamed
   the net transition keys to the trace event-name strings. Determinism x2
   and the 3-phase structure unchanged (22/23 -> 23/23).
3–5. Not independently reachable from the harness side in this session: after
   fix 1+2 the file went 22/23, then W601's clean rewrite of
   `Xaas.Semantics.EuAiActAdmission` and W630's totality guard
   (`wrap_field/proper_list?`) landed mid-run. The first `proper_list?/1`
   (`:lists.reverse(list) and is_list(list)`) was broken for EVERY proper
   list — `:lists.reverse/1` returns the list itself, truthy-but-not-boolean,
   so every Art 5 admit with a list field raised BadBooleanError and took out
   the counterfactual Art 5 rows and title_ii 5.live-integration (via the
   real plug call). This is/was a lib defect owned by W630, contractually
   out of my write scope. Observed at 23:12:14 the owning lane landed the
   fix (`is_list(:lists.reverse(list))` inside try/rescue); with that fix on
   disk the harness rows exercise the real module and are expected green.

### title_ii_test.exs 5.live-integration

Test body asserts the real plug behavior and is CORRECT against the landed
APIs: violating social-scoring params (`data_domains: ["social_behavior"]`,
`context_joins: ["unrelated_context_join"]`) normalize via the plug's
compiled `@vocab` map and refuse with `REFUSED_EUAIA_SOCIAL_SCORING` in
`error.data.refusal` (HTTP 200, code -32600); lawful body passes through
untouched (`halted?` false, empty resp_body). Its only failure cause was the
same W630 `proper_list?/1` lib defect crashing inside
`EuAiActAdmission.admit/1` (stacktrace: eu_ai_act_admission.ex:204 -> plug
call at title_ii_test.exs:178). No test-body change made or needed; with the
23:12:14 lib fix, re-runs are green.

## Verification

Build root `_build-laneW624b`, asdf toolchain (elixir 1.20.2-otp-28).

- Run 1 (counterfactual): 22/23 after fixes 1+2 — remaining failure was the
  W630 lib defect, not harness drift.
- Run 2 (both files, post-lib-fix): see command tails below.

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW624b \
  mix test test/eu_ai_act/counterfactual_test.exs --include eu_ai_act
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW624b \
  mix test test/eu_ai_act/title_ii_test.exs --include eu_ai_act
```

Determinism x2: every refusal row in the harness runs the intervention twice
in-process (r2 == r3) and the Art 72/plug rows compare byte-identical
headers/bodies; plus the full-file run is executed twice (green ×2).

## Boundary notes

- title_ii's other rows (W522/W531 synthetic partitions + corpus loop) were
  concurrently repaired by their owning lanes during this session; final
  state is the whole file green (40/40). No edits by this lane outside
  5.live-integration's scope (none needed there either).
- lib/mix/tasks/xaas.release_audit.ex was transiently syntactically broken by
  a concurrent lane (~23:0x); resolved on its own — no action.
