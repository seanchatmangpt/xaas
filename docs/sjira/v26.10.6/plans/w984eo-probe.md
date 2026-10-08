# W984eo — Xaas.Sjira family probe (unclaimed-family lane)

- Subject: `/Users/sac/xaas` @ branch `feat/playwright-surface`, HEAD `32b72c4f` (lane, uncommitted)
- Lane build root: `_build-laneW984eo` (fresh full compile, Elixir 1.20.2 / OTP 28 via asdf)
- Court file: `test/xaas/sjira/family_court_w984eo_test.exs` (26 tests)
- Disjoint from w984dp3 (`w984dp3_atlassian_cursor_court_test.exs`, untracked) — no shared file.

## Per-module disposition

| Module | Prior direct test reference | Disposition |
|---|---|---|
| ard_court.ex | ard_court_test.exs | COVERED (dedicated court; not re-probed) |
| atlassian_cursor.ex | w650y3 + w984dp3 + atlassian_test | COVERED (W650y3 court + sibling lane; left alone per lane boundary) |
| atlassian_transport.ex | atlassian_transport_test.exs, boundary_limits_test.exs | COVERED |
| atlassian.ex | 5 test files | COVERED |
| checkpoint.ex | only `Checkpoint.path/3` + MemoryCheckpoint double | **UNCOVERED state lifecycle — courted here (13 tests)** |
| delivery_batch.ex | delivery_batch_depth_court_test.exs, atlassian_test | COVERED |
| engineer_workflow.ex | engineer_workflow_test.exs, cs2 bridge test | COVERED |
| engineer_workflow/codec.ex | only `encode/1` asserted | **UNCOVERED cursor/digest/pretty + atom/tuple clauses — courted here (7 tests)** |
| governance_obligation.ex | governance_obligation_test.exs | COVERED |
| governance_route.ex | governance_route_test.exs | COVERED |
| rate_limit.ex | only 2 `delay_ms/3` happy-path asserts | **UNCOVERED branch matrix — courted here (10 tests)** |
| successor.ex | successor_test.exs + 6 more | COVERED |
| yield.ex | yield_test.exs, honesty chicago court | COVERED |

## Court content

- RateLimit: malformed Retry-After/reset fallback, retry-after precedence, past-epoch
  clamp, max cap (attempt 12), "0" honored, non-tuple header skip, alternate
  `x-rate-limit-reset` spelling, map/atom-key normalization, pure backoff.
- Checkpoint (real filesystem): save/load roundtrip, corrupt-json typed error,
  non-map shape error, enoent→nil, clear + clear-absent, migrate v0→v1 defaults,
  identity migrate, unsupported-version refusal, hostile-scope segment containment.
- Codec: encode_pretty canonical order, digest stability/order-independence,
  cursor roundtrip, three refusal clauses of decode_cursor, atom/tuple canonicalization.

## Finding

`Checkpoint.path/3` hostile-scope behavior: `safe_segment/1` rewrites `/` so a
scope like `../../etc/passwd` stays ONE literal segment (`..-..-etc-passwd`) —
no traversal is possible, but `..` characters survive inside the name. The
court pins the actual containment property rather than a naive `refute =~ ".."`.
No defect; behavior is safe and now witnessed.

## Gates (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984eo \
  mix test test/xaas/sjira/family_court_w984eo_test.exs
  → 26 passed (exit 0)
mock gate scan_mock_usage(["test","lib"]) → []
```

Intermediate runs: 22/26 → fixed test-side issues (mkdir of digest subdirectory,
pretty-JSON expectation, traversal assertion shape). No source changes to lib/.

## Standing

ALIVE for the three courted modules on this exact subject. NO commit made.
Lane cleanup: `rm -rf _build-laneW984eo` **DENIED** by permission gate at close.
Build root left on disk for coordinator cleanup per fanout law.
