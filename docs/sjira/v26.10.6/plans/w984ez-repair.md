# W984ez — Repair of W984ej typed findings (Security parse_dt/1 + atomize/1 wrong-type crash class)

Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`, working tree of lane
W984ez. No branch switch, no stash, no commit.

## Diff rationale

Closes the crash class pinned in `docs/sjira/v26.10.6/plans/w984ej-probe.md`:
`parse_dt/1` and `atomize/1` in `lib/xaas/security.ex` had no clause for
non-binary / non-nil / non-DateTime input, so wrong-type JSON (integers/maps for
`discovered_at`, `scan_date`, `severity`) crashed `Security.ingest/1` with
`FunctionClauseError` instead of the module's documented typed pass-through refusal.

Repair follows the module's own convention exactly — pass the wrong-typed value
through and let Ash's cast / `one_of` constraint produce the typed refusal; no new
error format invented:

- `atomize(v) when not is_binary(v) and not is_nil(v)` → pass through to Ash
  `one_of` typed refusal (same as the `ArgumentError` arm for unknown strings).
- `parse_dt(v) when not is_binary(v) and not is_struct(v, DateTime)` → pass
  through to Ash `utc_datetime` cast typed refusal (same as the
  `{:error, _} -> bin` arm for malformed strings).

`test/xaas/security_parsing_robustness_court_w984ej_test.exs` (W984ej's uncommitted
court): the 4 `assert_raise FunctionClauseError` pins converted to
`assert_raise Ash.Error.Invalid` (the real typed refusal), with mutation-kill
rationale updated. All other tests unchanged.

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ez \
  mix test test/xaas/security_parsing_robustness_court_w984ej_test.exs
# Result: 11 passed  (exit 0)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ez \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
# []

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ez \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
# Result: 1388 passed, 1 excluded  (exit 0, 0 failures)
```

Census note (pre-existing, disclosed): on a COLD lane build root the first census
run aborted at compile time with `== Type checking failed with errors ==` and exit 1
from 1099 pre-existing Elixir 1.20 type *warnings* in committed `test/eu_ai_act/*`
files (none in files this lane touched — `title_vi_xiii_test.exs` is committed
unchanged; this lane's only lib diff is `lib/xaas/security.ex` +12). The rerun on
the now-warm build root ran clean to `1388 passed, 1 excluded`. This is a fresh-lane
compile-time hazard for every fan-out lane, independent of this repair.

## Standing

ALIVE (court + census + mock gate executed on the exact lane subject). Finding
W984ej's four `FunctionClauseError` pins are now typed-refusal assertions against
the repaired module. No commit made, per lane contract.

## Lane build-root cleanup

`rm -rf /Users/sac/xaas/_build-laneW984ez` was DENIED by the session permission
system. `_build-laneW984ez/` remains on disk under `/Users/sac/xaas/` and must be
deleted by the coordinator at integration (lane-lease law).
