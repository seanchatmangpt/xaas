# W984ej — Security parsing / error-normalization robustness court

Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface` (no commit; working-tree lane
W984ej). No branch switch, no stash, no commit.

## Scope

Robustness deepening on the typed parsing / error-normalization family:
`lib/xaas/security.ex` (`atomize/1`, `parse_dt/1`, exercised via the public
`Security.ingest/1` path) and `lib/xaas_web/controllers/execution_fabric_controller.ex`
`format_reason/1` (exercised via its real wire paths: `GET
/internal-api/execution/epochs/:id/receipts` 400 arm and `POST
/internal-api/execution/runs` 400 arm).

## Artifact

`test/xaas/security_parsing_robustness_court_w984ej_test.exs` — 11 tests, zero mocks,
real sandboxed rows + real ConnCase HTTP.

## Input-class matrix

| target | input class | input | observed contract | status |
|---|---|---|---|---|
| parse_dt | valid UTC ISO8601 | fixture `scan_date` | `%DateTime{}` on posture | PASS |
| parse_dt | non-UTC offset (`+09:00`) | `discovered_at` | normalized to UTC (`2026-10-05T03:00:00Z`) | PASS |
| parse_dt | non-UTC offset (`-05:00`) | `scan_date` | normalized to UTC (`2026-10-05T14:30:00Z`) | PASS |
| parse_dt | malformed string | `"not-a-date"` | pass-through binary → Ash typed `Ash.Error.Invalid` refusal | PASS (typed) |
| parse_dt | integer | `discovered_at => 12345` | **FunctionClauseError crash** | TYPED FINDING |
| parse_dt | map | `discovered_at => %{"iso" => "x"}` | **FunctionClauseError crash** | TYPED FINDING |
| parse_dt | integer (scan_date) | `scan_date => 999` | **FunctionClauseError crash** | TYPED FINDING |
| atomize | unknown enum string | `disposition => "bogus_disposition"` | pass-through → Ash `one_of` typed refusal | PASS (typed) |
| atomize | nil severity | `severity => nil` | required-attribute typed refusal | PASS (typed) |
| atomize | integer severity | `severity => 5` | **FunctionClauseError crash** | TYPED FINDING |
| format_reason | `Ash.Error.Invalid` w/ field | bad epoch id → 400 | binary detail, no struct-blob / `nil` leak | PASS |
| format_reason | empty submission | `POST /execution/runs` `%{}` | 400 `invalid_request`, binary detail | PASS |
| format_reason | tuple/atom/string clauses | prior W984ca coverage (`execution_fabric_hook_depth_test`) | unchanged | pre-existing |

## Typed findings (NOT repaired in this lane, per lane rules)

`parse_dt/1` and `atomize/1` in `lib/xaas/security.ex` have no clause for
non-binary / non-nil / non-DateTime input. Where the decoded summary carries a wrong
JSON type (integers/maps for `discovered_at`, `scan_date`, `severity`), `Security.ingest/1`
crashes with `FunctionClauseError` instead of the documented typed pass-through refusal
(the moduledoc convention: "never a MatchError crash" — the same guarantee its own
comment claims for the malformed-string class).

Reproduce (one instance; all four are the same missing-clause class):

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix run -e 'Xaas.Security.ingest(%{"repo" => "r", "findings" => [%{"severity" => "high", "source" => "sobelow", "file" => "f", "description" => "d", "discovered_at" => 12345}]})'
```

Each crash class is pinned in the court as `assert_raise FunctionClauseError` tests with
the finding noted in-test, so the mutant that "fixes" lib/ without the court noticing is
also killed, and the regression floor documents current (crash) behavior until a repair
lane closes the finding.

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ej \
  mix test test/xaas/security_parsing_robustness_court_w984ej_test.exs
# Result: 11 passed, 0 failures (exit 0)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ej \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
# expect: []
```

## Standing

ALIVE (court executed on the exact lane subject; 11/11 pass; no skip tags needed —
the lib/ crash classes are pinned as `assert_raise FunctionClauseError` rather than
skipped, so they run and pass on the current behavior while disclosing the finding).
No commit made, per lane contract.
