# W778 — Gate Fix Verification Receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 (uncommitted tree, shared checkout)
- Date: 2026-10-07
- Scope: verify coordinator's two W760 court-side repairs (F1, F2); gate must be green.
- Build: PATH=$HOME/.asdf/shims:$PATH, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW778 (deleted after green runs).

## F1 — title_i_test.exs 3.49 (coordinator repair, verified as-found-on-disk)

`test/eu_ai_act/title_i_test.exs:458-460`:

```elixir
      # W679: a lawful REFUSED_EUAIA_* admission refusal is the receipt-
      # integrity family, not a malfunction — partition-exact classification.
      refute :MALFUNCTION in report.classification
```

Verified green: suite `test/eu_ai_act/title_i_test.exs test/eu_ai_act/title_iii_test.exs --include eu_ai_act` → 503 passed, exit 0.

## F2 — title_iii_test.exs 15.5.s3 deepen_kind(:vuln_lifecycle)

Coordinator's as-found-on-disk assertion was itself inverted: it expected
`reverse |> take(2) == [{:advance, :TRIAGED}, {:advance, :RESPONDED}]` but
`VulnerabilityLifecycle` history is chronological, so `reverse |> take(2)`
is newest-first (`[RESPONDED, TRIAGED]`). Real machine behavior confirmed
twice (run1/run2 failure output left=[advance: :RESPONDED, advance: :TRIAGED]).

W778 forward fix (test/eu_ai_act/title_iii_test.exs, deepen_kind(:vuln_lifecycle)):

```elixir
    # history is chronological; reversed take(2) is newest-first.
    assert responded.history |> Enum.reverse() |> Enum.take(2) ==
             [{:advance, :RESPONDED}, {:advance, :TRIAGED}]
```

## Real runs (all MIX_ENV=test, lane build root _build-laneW778)

1. Coordinator repairs as-found: 502/503 — F1 green, F2 still red
   (order-inverted expectation, real diff in /tmp/w778_run2.log).
2. After W778 one-line order fix: 503 passed, exit 0 (title_i + title_iii).
3. Gate `mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`:
   **1347 passed, 1 excluded, 0 failures, exit 0** (coordinator target 1200;
   actual population is larger and fully green — no regression).

## Transport note

Mid-verification another lane concurrently edited lib/ on the shared checkout
(`route_secrets_requires_approver.ex` typo `changecset`, then
`route_secrets.ex` missing `end`); two runs died at compile. W778 waited for
the tree to settle and re-ran on the compiling tree; final runs above are on
the settled tree.

## Standing

F1: VERIFIED (coordinator repair correct as-found). F2: PARTIAL — coordinator
repair was direction-inverted; W778 corrected forward. Gate: ALIVE
(1347/1347 green, 0 failed, 1 excluded open-gap).

## Falsifier

`mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap`
red on the settled tree would refute this receipt.
