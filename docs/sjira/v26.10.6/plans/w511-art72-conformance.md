# W511 — Art. 72 token-replay conformance (Definition 7.2) — receipt

Lane W511, EU-AI-Act wave, 2026-10-06. Subject: /Users/sac/beam4pm (canonical checkout,
nothing committed; private build root `tmp/w511_build`).

## Definition 7.2 mapping

`C(L,P) = ½(1 − m/c) + ½(1 − r/p)` implemented exactly as
`BeamPM.Art72Conformance.fitness_from_stats/1` + `log_fitness/2` (token-sum
aggregation across traces), with `drift_decision/2`: `C < 1 − ε ⇒ :DRIFT`
(pure, typed, strict `<`).

## Honest deviation (task item 2)

beam4pm's rust4pm WASM engine exposes **alignment-based** fitness only
(`BeamPM.Rust4PM.compute_fitness/2`, `align_trace/2`, `align_variants/2`);
its dispatch surface has NO token-replay op exposing m/c/r/p (checked
2026-10-06 against `lib/beam4pm_rust4pm.ex`). Definition 7.2 is token-replay
fitness, so the formula is implemented over a real in-repo token game in
pure Elixir (places / weighted arcs / initial+final marking, underfed
pm4py-style firing, end-marking deficit→missing/excess→remaining), documented
in the module moduledoc of `lib/beam4pm_art72_conformance.ex`. The existing
alignment machinery (`BeamPM.PowlConformance.check_conformance/3`) remains
the repo's own conformance path; this module is additive, nothing edited.

## Constructed per contract

New files only:
- `/Users/sac/beam4pm/lib/beam4pm_art72_conformance.ex`
- `/Users/sac/beam4pm/test/beam4pm_art72_conformance_test.exs`
- this receipt file (xaas-side write)

## Exact asserted C values (hand-derived)

Synthetic net `start → t_a → p1 → t_b → p2 → t_c → end`:

| log | tokens (c,p,m,r) | C |
|---|---|---|
| `[t_a,t_b,t_c]` | (3,3,0,0) | **1.0** |
| `[t_a,t_b]` (skips t_c) | (3,3,1,1) | **2/3** |
| `[t_a,t_c]` (underfed) | (2,3,1,1) | **7/12** |
| mixed `[t_a,t_b,t_c],[t_a,t_b]` | (6,6,1,1) | **5/6** |
| empty log | (0,0,0,0) | 1.0 (convention) |

Drift: `drift_decision(5/6, 0.1) == :DRIFT`; `(1.0, 0.1) == :NO_DRIFT`;
boundary `(0.9, 0.1) == :NO_DRIFT` (strict `<`).

## Execution

```
cd /Users/sac/beam4pm && PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=tmp/w511_build \
  mix test test/beam4pm_art72_conformance_test.exs
```

Real tail (2026-10-06, asdf elixir 1.20.4-otp-29, private build root
`tmp/w511_build`):

```
Finished in 0.02 seconds (0.02s async, 0.00s sync)
Result: 10 passed
```

## Toolchain finding (permanent guard material)

First runs failed with impossible token counts. Root cause, isolated by
probe on this exact toolchain (asdf elixir 1.20.4-otp-29):

```
Map.update(%{k: 5}, :k, 0, &(&1 + 1))  #=> %{k: 6}   (existing key: correct)
Map.update(%{},   :k, 7, &(&1 + 1))    #=> %{k: 7}   (absent key: default inserted RAW, updater NOT applied)
```

This differs from upstream Elixir's documented `Map.update/3` (which applies
`fun` to the default on an absent key). The module therefore avoids relying
on absent-key updater application (uses `Map.put` + `Map.get` for both the
consume and produce paths). Any beam4pm/xaas code assuming documented
`Map.update` absent-key semantics is silently wrong on this toolchain.

## xaas-side integration seam (no wiring performed)

xaas OCEL emission already produces the event-log side:
`lib/xaas/telemetry/ocel_ash_emitter.ex` (OCEL event log from Ash lifecycle;
see also `lib/xaas/telemetry/ocel_ndjson.ex`). The lawful seam is: export
those OCEL events → flatten per object (the same flattening beam4pm's
`ocel_variants_of_object_type` performs) → map activity names to transition
names of a discovered/declared net → `BeamPM.Art72Conformance.log_fitness/2`
→ `drift_decision/2` feeding the Art. 72 post-market drift receipt. No xaas
code was modified by this lane (contract: receipt write only).
