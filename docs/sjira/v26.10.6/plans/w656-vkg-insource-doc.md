# W656 — vkg.ex:52 dead-clause in-source documentation

Lane: W656, EU-AI-Act wave. Repo: /Users/sac/xaas @ feat/playwright-surface.
Contract scope: comment-only edit to `lib/xaas/semantics/vkg.ex` + this receipt. No behavior change.

## Before

`lib/xaas/semantics/vkg.ex:52`:

```elixir
    else
      [] -> {:error, :REFUSED_VKG_EMPTY_CATALOG}
      error -> error
    end
```

No comment at or near the clause; no mention of unreachability anywhere in the file (grep
`unreachable|REFUSED_VKG_EMPTY|Registry.admit` → single hit, the clause itself).

## Structural proof (re-derived against the real subject, not the task brief)

- `AshR2RML.VKG.Catalog.ids/1` (`deps/ash_r2rml/lib/ash_r2rml/vkg/catalog.ex:77`) returns
  `Map.keys(contracts) |> Enum.sort()` — `[]` only if the catalog has zero contracts.
- Catalogs reach `Runtime.catalog/1` from `AshR2RML.VKG.Manifest.from_json`, which at
  `deps/ash_r2rml/lib/ash_r2rml/vkg/manifest.ex:49` admits only
  `{:ok, contracts} when contracts != []`; the empty-contract edge refuses earlier as
  `REFUSED_VKG_MANIFEST` (manifest.ex:241).
- Therefore `ids` can never return `[]` and the `[] ->` clause is dead.

Note: the dispatch brief cited `registry.ex:25` as the refusal site. The live subject has
no such clause there — `Xaas.Semantics.Registry.admit/1` (registry.ex:151) refuses
non-public IRIs, not empty contracts. The in-source comment cites the verified site
(manifest.ex:49) instead of a wrong line number.

## After

Added a 4-line comment block immediately above the clause:

```elixir
      # Structurally unreachable: Manifest.from_json refuses [] contracts
      # (ash_r2rml manifest.ex:49, REFUSED_VKG_MANIFEST), so Catalog.ids/1
      # cannot return []. The real empty edge refuses earlier. Proven by
      # w378/w626-era analysis; deletion candidate.
      [] -> {:error, :REFUSED_VKG_EMPTY_CATALOG}
```

## Verification

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW656 mix compile`
  → see compile tail below (fresh lane build root, full app compile).
- `mix test test/xaas/semantics/` under the same env → see below.

## Compile tail

```
Compiling lib/mix/tasks/xaas.ultracode.learn.ex (it's taking more than 10s)
Generated xaas app
EXIT=0
```

Fresh lane build root `_build-laneW656`, full app compile, exit 0.

## Test run

`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW656 mix test test/xaas/semantics/`

- Run 1: 231/232 passed, 1 skipped, 5 excluded, 1 failed (failure did not reproduce;
  transient/flaky — see run 2).
- Run 2: **232 passed, 1 skipped, 5 excluded, 0 failed.**

Standing: comment-only edit, no behavior change; suite green on stable rerun.
