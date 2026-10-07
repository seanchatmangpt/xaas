# W609 — reference_oracle Map.update site fix (OS-20 follow-up)

Lane: W609, EU-AI-Act wave v26.10.6. Date: 2026-10-06.
Subject: `/Users/sac/ex4pm` (canonical checkout, ONE lane-owned file patched, never committed).
Build root: `_build-laneW609`.

## Classification

Site: `lib/ex4pm/qualification/powl/reference_oracle.ex:109` —
`Map.update(visits, next, 1, &(&1 + 1))` in `enumerate_paths/5` (choice-graph path
enumeration visit census). This site was **not in W525d's original census** (the file
postdates it); W604 flagged it as post-census.

**ABSENT-KEY-RELIANT (inverted)** — `visits` starts as `%{}`; `next` is normally absent on
first visit; `fun.(default) = 2 ≠ 1`. Under the observed toolchain deviation the site
stores `1` (the correct first-visit count); under documented semantics it would store `2`,
prematurely exhausting the `allowed_visits = bound + 1` budget and truncating the reference
oracle's trace language — a silently wrong equivalence oracle.

## Diff

Dual-safe case/fetch idiom per w525d §5 (preserves observed behavior on this toolchain):

```elixir
        true ->
          # Dual-safe visit increment (w525d/w609): on this runtime Map.update/4
          # skips fun on an absent key (stores 1 — the intended first-visit count);
          # documented semantics would store 2. Encode observed behavior explicitly.
          visits =
            case Map.fetch(visits, next) do
              :error -> Map.put(visits, next, 1)
              {:ok, count} -> Map.put(visits, next, count + 1)
            end

          enumerate_paths(successors, next, [next | path], visits, allowed)
```

## Test

`test/w609_oracle_site_test.exs` (new, mirrors `test/w604_map_update_dual_safe_test.exs`
idiom): canary pin of the runtime deviation (`Map.update(%{}, :k, 7, &(&1+1)) == %{k: 7}`)
plus a choice-graph loop model (`a → a → ... → b → □`) whose language under bound 2 is
exactly `[["a","a","a","b"], ["a","a","b"], ["a","b"]]` (visit budget `bound+1 = 3`,
exercising both the absent-key seed and two present-key increments), and which extends to a
5-event trace under bound 3. Any flip to documented Map.update semantics would store 2 on
the first visit and truncate the language below the 5-event trace — failing the pin.

## Gates (real output, pinned toolchain: asdf shims on PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW609)

- `mix test test/w609_oracle_site_test.exs` → **2 passed**
- `mix test test/powl test/w609_oracle_site_test.exs` → **9 passed**
- `mix test test/powl_test.exs test/powl_executor_test.exs test/powl_property_corpus_test.exs test/oc_powl_test.exs test/w604_map_update_dual_safe_test.exs test/w609_oracle_site_test.exs` → **30 passed (2 doctests, 28 tests)**

No failures, no skips. No git mutations; no dev compile; lane build root only.

## Verdict

RELIANT site patched with the dual-safe idiom, pinned by a real language-equality test.
ex4pm reliant-site count: 35 → 34 unpatched (34 remaining reliant sites are the w525d
census body, covered by the w604 idiom test file). Post-census site W604 flagged is now
closed; no post-census site remains unpatched. Standing: ALIVE (observed execution, this
toolchain, exact subject above).