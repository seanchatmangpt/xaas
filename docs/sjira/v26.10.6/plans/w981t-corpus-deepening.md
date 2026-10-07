# W981t — Corpus evidenced-line deepening (3 lines, 9 courts)

Lane W981t · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; no commit per dispatch).
Build root `_build-laneW981t` — cold compile, pinned asdf toolchain
1.20.2-otp-28.

## Gap-inventory provenance

Newest gap-inventory receipt on disk: `w547-gap-flips.md` (w547 flip pass;
the corpus itself, `docs/eu_ai_act/corpus.json`, drives the per-line verdicts
at compile time, so the on-disk inventory is the live inventory). w547's
held-open list and the w543 aggregation receipt were read; the three lines
deepened here are all already **EVIDENCED** in the corpus tests and had no
deepening court binding the article text to a real execution of the named
surface (verified by reading the existing test trees — see per-line notes).

## Per-line courts

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 26.6 | deployer record-keeping: logs preserved | `Xaas.Actuation.run/4` → durable `ActuationIntent` + `ActuationReceipt` rows (real Postgres sandbox), cited by `OversightGovernance.retention_policy/0` | `test/xaas/deepening/art_26_6_retention_durable_row_test.exs` (3 courts) | delete hash population (`ontology_projection_hash`/`input_hash`/`result_hash`) from the receipt write in `lib/xaas/actuation.ex` — hash-presence + replay-adds-no-row assertions fail while structure-only courts still pass |
| 14.4.b | automation-bias countermeasure: operator can correctly interpret output | `AutomationBiasCountermeasure.briefing/2` composed with real `Counterfactual.run/evaluate` + `AdmissionAttribution.shapley/2` over a real `DatasetAdmission` bias refusal | `test/xaas/deepening/art_14_4b_causal_briefing_test.exs` (3 courts) | return `[]` from `refusal_anatomy/2` for refusals (or name passing checks) — causality assertions fail while determinism/shape courts pass |
| 15.5.s3 | Art 15(5) lifecycle: detect→respond→resolve over lifetime | `VulnerabilityLifecycle` driven from a LIVE `DatasetAdmission` bias-gate refusal (real executed surface), full drive to `:RESOLVED`, skip/backward typed refusals, determinism ×2 | `test/xaas/deepening/art_15_5s3_lifecycle_real_detection_test.exs` (3 courts) | drop the `not_empty` evidence guards in `triage/respond/resolve` — empty-evidence path reaches `:RESOLVED`, evidence-refusal assertions fail |

(Compare: quiescent stop 27.3 already deepened W704
`test/xaas/actuation/quiescent_stop_deepening_test.exs`; FRIA 27.1 family
structure courts exist in `test/xaas/semantics/oversight_governance_test.exs`
— avoided duplication by choosing composition/liveness properties those
courts do not assert.)

## Verification (real tails)

Cold-lane build; the compile-then-test command, run 2× consecutively green on
the same fresh root:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW981t \
  mix test test/xaas/deepening/ --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Run 3 (seed 478095): `Result: 9 passed` — exit 0
- Run 4 (fresh seed): `Result: 9 passed` — exit 0

Earlier runs (witnessed, disclosed as repair history): run 1 compile error
(`require Ash.Query` missing), run 2 3/9 (receipt filter on nonexistent
`idempotency_key` attribute; Counterfactual check-contract mismatch
`{:refused, r}` vs Shapley's `{:refuse, r}`; two genuinely-new facts learned
and folded into the courts: replay envelope status is `:replayed` not
`:succeeded`, and `evaluate/3` verifies the recorded input under the SAME
checks, so causal flip is witnessed via a second `run/2` replay — both now
asserted as behavior), run 3 → green.

Mock gate: grep of the three files → prose-only "no mocks"; zero
`Mock`/`patch(`/`.expect(` usage. Chicago: real Ash actions over real
sandboxed Postgres (26.6), real deterministic modules over a real executed
admission refusal (14.4.b, 15.5.s3).

## Tagging convention (read from w543/w547 + existing slice files)

Corpus-article lines → `@moduletag :eu_ai_act` (all three files), so they
land in the eu_ai_act census; runs used `--include eu_ai_act --exclude
eu_ai_act_open_gap`, the census command. No `eu_ai_act_open_gap` tags (no
line was flipped; this lane deepens already-evidenced lines only).

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  9/9 ×2, real commands + real exits.
- `_build-laneW981t`: deletion permission-denied in this lane session
  (`rm -rf` refused), **LEFT FOR COORDINATOR** per the fanout cleanup law
  (fallback pattern identical to W928b/W926/W980i).
- Real contract facts witnessed (worth retaining): same-key actuation replay
  envelope status is `:replayed` (not `:succeeded`); `ActuationReceipt` is
  keyed by `intent_id` (+attempt), not idempotency_key; `Counterfactual`
  check funs return `:ok | {:refused, atom}` while `AdmissionAttribution`
  expects `:pass | {:refuse, atom}`.
- Not done (typed): no line flips, no lib edits, no corpus edits — out of
  this lane's contract (test/ + receipt only).
