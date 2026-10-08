# W984gc — cold-compile hazard triage (1099 type warnings / census abort)

Lane W984gc. 2026-10-07. No commit (per dispatch). Branch at triage: `feat/playwright-surface`.

## Reproduction (real outputs)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gc \
  mix compile --force
```

- EXIT 0. 10 warnings, 0 errors — all in deps/lib, none in test files
  (mix compile covers lib + test/support only; test/*.exs compile inside
  `mix test`).

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gc \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Cold test-tree compile in this lane build root: **1126 warning
  diagnostics** (≈ the reported ~1099), **0 type errors**, tests RAN:
  `Result: 1388 passed, 1 excluded`, exit 0. No abort reproduced on the
  current tree.

## Abort mechanism (config evidence + Elixir source)

The census-side abort is **not config-caused**. No
`warnings_as_errors` / `compiler_options` / `@lint` switch exists in
`mix.exs` or `config/*.exs`. The exact header
`== Type checking failed with errors ==` is printed by Elixir itself,
`kernel/parallel_compiler.ex:483` (all installed 1.20.x toolchains):

```elixir
case errors do
  [] -> {{:ok, modules, info}, state}
  _  -> IO.puts(:stderr, "== Type checking failed with errors ==")
```

It fires only when the Elixir 1.19+ gradual type checker produced
type ERRORS (impossible-pattern/no-return class), which fail the
compile regardless of any warnings policy. Warnings never abort `mix
test` on their own. The `--warnings-as-errors` flag appears only in
opt-in gates (`docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md:226`,
`scripts/sjira/release_v26_9_23.py:42,46`), not in any default path.

So W984ev's cold-census abort (run 1) was a **transient hard type-error
set that no longer exists on the current tree** — eliminated by
intervening lane landings (or a different-toolchain compile). The
warnings themselves (1098 of 1126) are one benign kind:
"the following conditional expression will always succeed" from the
gradual set-theoretic type checker, emitted at macro-expansion sites in
5 pre-existing `test/eu_ai_act/title_*_test.exs` files. They are
warnings only; on this tree, cold compile + census exits 0.

## Inventory: top files by warning diagnostics (this run, 1126 total, 16 files)

| count | file |
|---|---|
| 923 | test/eu_ai_act/title_vi_xiii_test.exs |
| 650 | test/eu_ai_act/title_iii_test.exs |
| 406 | test/eu_ai_act/title_iv_v_test.exs |
| 181 | test/eu_ai_act/title_i_test.exs |
| 33 | test/eu_ai_act/title_ii_test.exs |
| 6 | test/eu_ai_act/art11_1_art12x_audit_chain_deepening_test.exs |
| 6 | test/eu_ai_act/airo_grounding_test.exs |
| 5 | test/eu_ai_act/art9x_risk_management_deepening_test.exs |
| 3 | test/eu_ai_act/art10_2e_art26_4_dataset_purpose_deepening_test.exs |
| 2 | test/eu_ai_act/art26x_postmarket_deepening_test.exs |
| 2 | test/eu_ai_act/art14x_oversight_deepening_test.exs |
| 1 | test/eu_ai_act/title_ii_deepening_test.exs |
| 1 | test/eu_ai_act/art15x_robustness_deepening_test.exs |
| 1 | lib/xaas/operations/approval_causal_anatomy.ex |
| 1 | lib/mix/tasks/xaas.airo.compile_shacl.ex |
| 1 | lib/ash_affidavit/signing.ex |

Warning-kind breakdown: 1098 "conditional expression will always
succeed" (gradual type checker, macro-generated quote blocks), plus a
long tail: unused variable (7), "pattern matching on 0.0" (5),
comparison between distinct types (4), duplicate clauses (3), misc (9).

## Fixable-vs-policy classification

- **Fatal type ERRORS on current tree: 0.** The dispatch's step-3
  condition (trivially-fatal type errors to fix forward) does not
  obtain — fix-forward set is empty, no code edits made.
- 1098 warnings are macro-expansion artifacts in quote-based test
  generators (`Xaas.EUAIAct.TitleVIXIII.Deepenings.deepening/1` etc.);
  fixing means restructuring quote hygiene or opting the files out of
  type checking — **policy decision, not a small fix**. Left untouched
  (no compile policy changed).
- Long-tail warnings (unused vars, 0.0 match, distinct-type comparison,
  duplicate clauses ≈ 19 diagnostics) are individually trivial but not
  fatal; left for the owning lanes since they are warnings-only and do
  not block anything on the current tree.

## Transport failures

- `rm -rf _build-laneW984gc` **denied by the permission system** — the
  lane build root `/Users/sac/xaas/_build-laneW984gc` (~full test-tree
  build) remains on disk as an un-deleted lease. Coordinator must
  delete it at integration per the cleanup law.

## Standing

- TRIAGE: **ALIVE** — mechanism identified from Elixir source + config
  sweep + two real cold-build reproductions on the exact tree.
- Abort-on-current-tree: **REFUTED** — could not be reproduced;
  1388/1388 pass cold.
