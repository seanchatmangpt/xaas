# W637b — counterfactual_test.exs seed-dependent flake fix

## Subject

- Repo: `/Users/sac/xaas` @ `feat/playwright-surface` (canonical checkout)
- Lane build root: `_build-laneW637b`
- Files touched: `test/eu_ai_act/counterfactual_test.exs` ONLY (brittle assertions
  in "Art 14(4)(a) positive..." test, ~line 880)

## Defect

`Xaas.Semantics.AutomationBiasCountermeasure.briefing/2` emits `per_check_causes`
elements that may carry an extra `refusal: nil` key. The Art 14(4)(a) positive
test asserted exact map membership:

```elixir
assert %{name: :consent_ok, verdict: :pass, shapley: 0.0} in briefing.per_check_causes
```

`in` uses `===/2`; map equality requires exact key sets, so any emitted
`refusal: nil` key fails the assert. Result: random-seed GREEN, `--seed 0` RED
(seed-dependent flake exposed by W635's aggregation).

## Fix (subset-based assertion)

Whole-map equality against a module-emitted struct replaced by exact-key
subset comparison (`Map.take` on both sides) per relevant check name:

```elixir
for {name, shapley} <- [consent_ok: 0.0, scope_ok: 0.0] do
  assert Enum.any?(briefing.per_check_causes, fn cause ->
           Map.take(cause, [:name, :verdict, :shapley]) ==
             %{name: name, verdict: :pass, shapley: shapley}
         end),
         "no per_check_causes entry with name=#{inspect(name)}"
end
```

Intent preserved: the positive per-check assertions still verify each check
carries verdict `:pass` and Shapley blame `0.0`; extra keys are now ignored
by design.

## Sweep result (other map-equality assertions)

Audited the whole file: the only whole-map equality against
`per_check_causes`/decision records was the pair at ~:880/:881. The other
per-element assertions use *pattern matching* (`assert [%{name: :id_ok,
refusal: :REFUSED_NO_ID}] = briefing.refusal_anatomy` at ~:383 and ~:837),
which is already subset semantics in Elixir — no fix needed. The
`b2 == b1` / `p2 == p1` determinism assertions compare two outputs of the
same call, so exact equality is correct there.

## Brittleness pattern note

Map-equality (`in`, `==`, `=` on non-pattern literal maps) against
module-emitted structs is brittle: adding a key to the struct silently breaks
consumers' assertions, and default-valued keys (`refusal: nil`) make failures
look seed/random-dependent. Rule: assert on the keys the test's intent names,
via `Map.take` subset comparison or pattern matches; reserve whole-map `==`
for two outputs of the same producer (determinism x2 checks).

## Verification

3-seed run (default, `--seed 0`, `--seed 123`), tail output recorded in the
lane report. Verdict: see lane W637b final report (3/3 green required).
