# W816 — 15.5.s3 residual: VERIFICATION of W778's fix

Standing: **ALIVE (verification)** — no edits made by this lane.

## Deconflict

Mid-run, the coordinator re-scoped W816: W778 had already fixed the 15.5.s3
residual (the order-inverted history assertion). W816's re-scoped task is a
real-run verification of W778's fix on the settled tree, plus this receipt.

## Subject

- Repo: `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6` (unchanged tree in region)
- File: `test/eu_ai_act/title_iii_test.exs`, `deepen_kind(:vuln_lifecycle)` (15.5.s3), lines 1018–1049
- No edits to `test/eu_ai_act/title_iii_test.exs` or `lib/` by this lane.

## Why the original assert failed (root cause, cited)

`lib/xaas/semantics/vulnerability_lifecycle.ex:136-138` — `advance/3` appends
chronologically:

```elixir
history: h ++ [{:advance, to}]
```

History starts `[{:detect, :DETECTED}]` (line 78), so after DETECTED→TRIAGED→
RESPONDED the history is `[{:detect, :DETECTED}, {:advance, :TRIAGED},
{:advance, :RESPONDED}]`. `Enum.reverse/1 |> Enum.take(2)` is therefore
newest-first: `[{:advance, :RESPONDED}, {:advance, :TRIAGED}]` — exactly what
W778's corrected assert (test lines 1035–1037) expects. The pre-fix assert
expected `[{:advance, :TRIAGED}, {:advance, :RESPONDED}]` (oldest-first
reading), which cannot match a chronologically-appended history.

**Mutation rationale**: reverting W778's fix (re-inverting the expected pair
to `[TRIAGED, RESPONDED]`) makes the assert at title_iii_test.exs:1036-1037
fail — it is the only assert whose left side is `responded.history |> reverse
|> take(2)`.

## Verification (real tail)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW816 \
  mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act
```

```
Finished in 3.3 seconds (3.3s async, 0.00s sync)

Result: 391 passed
[exited with code 0]
```

Full file green on the settled tree, including 15.5.s3 (`deepen_kind(:vuln_lifecycle)`).

## Lane lease

`_build-laneW816` deletion was denied by the permission system; left in place
for coordinator cleanup per dispatch fallback.

## See Also

`docs/sjira/v26.10.6/plans/w778-gate-fix-verify.md`
