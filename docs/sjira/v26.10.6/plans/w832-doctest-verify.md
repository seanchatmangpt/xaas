# W832 — Doctest Surface Verification (findings-only, no lib edits)

Lane: W832, xaas v26.10.6 campaign. Subject: `/Users/sac/xaas` @ feat/playwright-surface, HEAD a0723bf6 (plus in-flight W464 working-tree state).
MIX_BUILD_ROOT=_build-laneW832, MIX_ENV=test, pinned asdf toolchain (`PATH=$HOME/.asdf/shims:$PATH`).

## (a) Real run — exact count and result

Invocation determined from `test/test_helper.exs`: doctests are **not** tagged or
excluded anywhere (`exclude:` list has no doctest entry), so they run by default;
the correct invocation is running the files that declare `doctest` directly.
`--include doctest` / `--only doctest` are meaningless here (no such tag exists).

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW832 \
  mix test test/xaas/ultracode/worker_env_test.exs test/xaas/ultracode/provider_recovery_test.exs
Running ExUnit with seed: 189354, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act]
........................................................
Finished in 1.0 seconds (0.1s async, 0.9s sync)
Result: 56 passed (6 doctests, 50 tests)          [exit 0]
```

Run 2 (determinism): identical — `Result: 56 passed (6 doctests, 50 tests)`, exit 0.

**Confirmed: 6 doctests, 6/6 passed, ×2 deterministic.** Matches W663b's gate-1 note.

## (b) Inventory

The entire lib doctest surface is exactly two modules (grep `iex>` over `lib/`:
7 hits, all in these two files):

| module | file | iex> prompts | doctests registered |
|---|---|---|---|
| `Xaas.Ultracode.WorkerEnv` | lib/xaas/ultracode/worker_env.ex (lines 91, 93) | 2 | part of the 6 |
| `Xaas.Ultracode.ProviderRecovery` | lib/xaas/ultracode/provider_recovery.ex (lines 85–97) | 5 | part of the 6 |

Note: 7 `iex>` prompts vs 6 registered doctests — one prompt is a continuation
without its own expected-output entry. Minor; count is 6, matching W663b.

Only two test files declare `doctest`:
- `test/xaas/ultracode/worker_env_test.exs:11` (`doctest WorkerEnv`)
- `test/xaas/ultracode/provider_recovery_test.exs:16` (`doctest ProviderRecovery`)

No `iex>` examples exist anywhere in `lib/xaas/semantics/` — the newest
W500-series modules carry zero doctests today.

## (c) Top-3 doctest candidates (W500-series semantics, findings-only)

All three are pure, deterministic, and @spec'd — ideal doctest material:

1. **`Xaas.Semantics.JCS.encode/1`** (`lib/xaas/semantics/jcs.ex:43`,
   `@spec encode(term()) :: String.t()` — RFC 8785 JSON canonicalization.
   A doctest like `iex> Xaas.Semantics.JCS.encode(%{"b" => 1, "a" => 2})`
   would pin key-ordering + canonical output determinism.
2. **`Xaas.Semantics.Computation.*.hash/1`** — `lib/xaas/semantics/computation.ex:66/91/186/289`,
   multiple `hash(t())` @specs across the module's structs; each pins a deterministic
   hash of a struct built with `new/1`. Pure and deterministic.
3. **`Xaas.Semantics.Counterfactual.run/2`** — `lib/xaas/semantics/counterfactual.ex:105-106`,
   `@spec run(term(), [check()]) :: %{outcome: ..., checks: [...]}` — a doctest on a
   small admitted input pins the `%{outcome: :admitted, checks: [...]}` result shape.

(Computed from @spec lines; no lib edits made per lane contract.)

## Standing

- Doctest claim "6/6 doctests" (W663b gate-1): **ALIVE** on subject a0723bf6 —
  really ran, 6 doctests, all passed, twice.
- Doctest surface thinness: **CONFIRMED** — 2 modules / 6 cases total; semantics
  modules have zero doctest coverage.
- `_build-laneW832` deletion was refused by the permission system; left in place
  for coordinator cleanup.
