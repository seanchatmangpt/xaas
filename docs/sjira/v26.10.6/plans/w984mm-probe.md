# Receipt — W984mm census-tail court (W984lq eighth re-census remainder)

- **Lane**: W984mm, xaas v26.10.6 campaign, 2026-10-08
- **Subject**: /Users/sac/xaas @ feat/playwright-surface, uncommitted working
  tree as-walked (no commit made, per lane contract)
- **Task**: court the 5 non-route-validation entries remaining from W984lq's
  eighth re-census (`docs/sjira/v26.10.6/plans/w984lq-recensus.md` rows
  6–10; the 5 route validations were taken by W984ls).

## Commands / exits

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984mm \
  mix test test/xaas/census_tail_court_w984mm_test.exs --warnings-as-errors
# exit 0 — 16 tests, 0 failures, 0 warnings
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984mm \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
# exit 0 — [] (mock gate clean)
```

First run over the fresh lane build root was backgrounded for a full
compile (completed exit 0, with 2 warning classes); the 3 fixed iterations
after that each re-ran in ~seconds against the warm build.

## Per-entry dispositions

| # | Entry | Classification | Disposition |
|---|---|---|---|
| 6 | `Xaas.PromEx.CpuPlugin` | state-bearing plugin | **COURTED** — 5 tests: happy path of `execute_cpu_metrics/0` through the real disclosed `Xaas.AwsRepo.FixtureAdapter` with a real telemetry handler asserting the fixture instance id `i-09ba9852c02d92e38` + nonzero float util; error path through a hand-written real adapter `W984mm.FailingAdapter` (real behaviour impl, not a mock) asserting the `util: 0.0` + empty-metadata degradation event; `polling_metrics/1` default poll_rate 1_000, group_name `:os_cpu_polling_events`, measurements_mfa → `execute_cpu_metrics`, and custom poll_rate 5_000 |
| 7 | `Xaas.Runtime.ProviderFabric.Budget` | pure state machine | **COURTED** — 4 tests: decrement transition, exhausted (`attempts: 0` → `{:error, :exhausted}`), last-attempt lands at exactly 0 then next draw refuses, non-Budget input falls to the guard fallthrough `{:error, :exhausted}` |
| 8 | `Xaas.Trimtab.ZcodeAdapter` | pure encode | **COURTED** — 3 tests: full-request encode (protocol/subject/objective/action/payload), missing `:action`/`:payload` keys default to nil without failing, invalid shapes (`%{subject: ...}` map without objective, non-map) → `{:error, :invalid_request}` |
| 9 | `UNKNOWN_postgrex_types` (`lib/xaas/postgrex_types.ex`) | compile-time `Postgrex.Types.define` projection (no public functions of its own) | **COURTED (surface court)** — 1 test: module loads, `AshPostgres.Extensions.Vector` loads, and the generated Postgrex dispatch surface is exported (`encode_params/2`, `decode_rows/3`, `find/2`) |
| 10 | `Xaas.Governance.Types.ChangeOfControlEventType` | pure types module | **COURTED** — 4 tests through the real Ash.Type.Enum derivation: `values/0` = exactly the 3 platform-console-ported values; `cast_input/2` accepts atoms/strings/nil; refuses out-of-enum values (`:error`); `storage_type/0` is `:string` |

16 tests total, all real collaborators, real state, zero mocks. Mutation
rationale: each test names the branch it kills (decrement vs exhausted vs
guard fallthrough; happy vs error telemetry branch; default vs custom poll
rate; encode-complete vs encode-default vs encode-refuse; load+surface;
values/cast-accept/cast-refuse/storage).

## Standing

ALIVE (as a lane receipt + passing court). The 5 entries should now read
COVERED in the next re-census run; expected delta 38 → 33 uncovered (the 5
route validations remain with W984ls, not this lane).

## Lane hygiene

`_build-laneW984mm` was created for per-lane isolation and removed at lane
end: `rm -rf _build-laneW984mm` exit 0, confirmed absent on disk afterward
(the trailing nonzero exit in the compound command is the confirming
`ls`, not the `rm`). No commit made.
