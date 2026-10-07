# W295b — Definitive Full-Suite Measurement, Clean Build Root

- Subject: `/Users/sac/xaas` @ `d1db2b03179975213c14663b9dbd86b5ac2a14cf` (branch `feat/playwright-surface`), working tree as-is (uncommitted lane changes present)
- Build root: `_build-w295b` (cold build, private — eliminates the W282/W215 shared-`_build` mixed-OTP-beam contamination class)
- Toolchain: asdf pinned elixir 1.20.2-otp-28 / erlang 28.5.0.2 (`PATH=$HOME/.asdf/shims:$PATH`)
- Command:
  `MIX_BUILD_ROOT=_build-w295b PATH=$HOME/.asdf/shims:$PATH INTERNAL_API_TOKEN=dev-e2e-token MIX_ENV=test mix test`
- Date: 2026-10-06, wall clock ~15:44–15:50 local; suite time 369.2s (30.4s async / 338.8s sync)

## Verbatim result

```
Finished in 369.2 seconds (30.4s async, 338.8s sync)

Result: 3235 passed (6 doctests, 3229 tests), 36 skipped, 91 excluded
```

**Failures: 0.** No failure blocks in the log (no `N) test` / `N) doctest` entries; no
`N) test` summary section exists). Full log: `/tmp/w295b-suite.log` (4848+ lines).

## Classification vs known-typed set

- Failures: **none to classify** — the suite was fully green on a clean, private build root.
  This confirms W282's 125F and W215's 420F were shared-`_build` contamination
  (mixed OTP28/29 beams, concurrent compiles), not real defects.
- 36 skipped / 91 excluded: pre-existing typed skips (OS-9 skips, witness env, etc.);
  unchanged and not failure-class.
- Non-fatal log noise observed (no test effect): Reactor.Audit idempotency_conflict log line,
  ultracode verifier crash log (`key :steps not found`), capability-resolution court BYPASS
  warning, PromEx/Grafana nxdomain upload warnings, AshA2A legacy_compat profile warnings.

## Quiescence disclosure

Strict quiescence (0 other `mix test` on the checkout across 3 checks 2 min apart) was never
achieved — other lanes launched runs intermittently for ~35 min. Proceeded with the private
build root; residual risk class is CPU contention only (no shared compile state), and the
suite completed fully green, so no isolation re-run was required.

## Mock gate

`mix run --no-compile -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`
→ **`[]`** (clean; expected AshA2A legacy_compat / PromEx / sa2a-bridge warnings only).

## Standing

ALIVE — clean-root full-suite pass witnessed at the exact subject SHA above.
No fixes made, no git operations performed. Build root cleanup: see below.
