# W619 — ggen_igniter asdf-shim rerun of W618's court

Verdict: **PINNED-TOOLCHAIN-CONFIRMED**

## Subject

- Repo: /Users/sac/ggen_igniter (canonical checkout, nothing committed)
- Court: test/airo_risk_description_test.exs (W618's court, re-run)
- Build root: /Users/sac/ggen_igniter/_build-laneW619 (cold, per-lane lease)

## Shadow confirmation (step 1)

- bare `which elixir` → /opt/homebrew/bin/elixir — Elixir 1.19.5 (compiled with Erlang/OTP 28)
- `PATH=$HOME/.asdf/shims:$PATH which elixir` → /Users/sac/.asdf/shims/elixir — Elixir 1.20.2 (compiled with Erlang/OTP 28)

W618's shadow hypothesis confirmed: bare PATH resolves to homebrew 1.19.5, not the pinned
asdf 1.20.2.

## Rerun (step 2)

```
cd /Users/sac/ggen_igniter && PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test \
MIX_BUILD_ROOT=/Users/sac/ggen_igniter/_build-laneW619 mix test test/airo_risk_description_test.exs
```

Result (exit 0, pinned elixir 1.20.2):

```
Finished in 0.05 seconds (0.05s async, 0.00s sync)
4 tests, 0 failures
```

One compiler warning observed in the test file itself (not a failure):
`test/airo_risk_description_test.exs:44:24 — use of operator > has no effect`
(`byte_size(content) > 2_000` used as an expression, not a boolean guard).

## TTL surface (step 3)

TTL is data — nothing to compile; structural assertions covered by the same test run above
(4/4 pass under pinned toolchain).

## Receipt fields

- identity: ggen_igniter @ HEAD of canonical checkout, court file
  test/airo_risk_description_test.exs, lane W619 build root
- authority: AIRo wave lane W619 contract (read-only repo + this receipt file)
- consequence: 4 tests / 0 failures, exit code 0, under elixir 1.20.2-otp-28
- replay: command in "Rerun" section above; delete `_build-laneW619` and re-run
- standing: PINNED-TOOLCHAIN-CONFIRMED — no divergence between W618's structurally-
  observed result and the pinned-toolchain rerun

## Cleanup note

`_build-laneW619` is a lane lease; coordinator deletes at integration per
[[same-checkout-fanout]] cleanup law.
