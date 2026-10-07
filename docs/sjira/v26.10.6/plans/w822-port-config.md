# W822 — test endpoint port honors PORT/PW_PORT

Lane: W822, xaas v26.10.6, branch `feat/playwright-surface`, base HEAD `a0723bf6`.
Source: W688 finding + W752 typed note — `config/test.exs:73` hardcoded port 4002,
so a MIX_ENV=test playwright boot's readiness probe on PW_PORT could never pass,
forcing `reuseExistingServer` + orphan-beam cleanup each run.

## Change

File: `/Users/sac/xaas/config/test.exs` (only file touched besides this receipt).

Before:

```elixir
  http: [ip: {127, 0, 0, 1}, port: 4002],
```

After:

```elixir
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || System.get_env("PW_PORT") || "4002")],
```

## Verification (executed)

`Code.eval_file/1` directly raises `Config.raise_improper_use!` (guard against
evaluating config outside Config.Reader — pre-existing behavior, not a syntax
failure), so the parse check is `Config.Reader.read!/1` with the endpoint port
extracted:

```
default port: 4002
PORT=5999 -> 5999
PW_PORT=6113 -> 6113
PORT precedence -> 1        (PORT set + PW_PORT set: PORT wins, per || order)
```

All four combinations parse and resolve. No server booted, no build root created.

## Standing

- Config parse + env resolution: ALIVE (observed, exact commands above).
- End-to-end fix: UNKNOWN → the next e2e lane run with a fresh playwright boot
  on PW_PORT is the real acceptance (readiness probe must pass without
  `reuseExistingServer` and without orphan-beam cleanup). That run, not this
  receipt, falsifies or confirms the fix.
