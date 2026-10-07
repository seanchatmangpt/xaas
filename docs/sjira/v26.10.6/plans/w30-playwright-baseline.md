# W30 — Playwright Full-Suite Baseline Receipt (v26.10.6)

Date: 2026-10-06 · Lane: W30 · Repo: /Users/sac/xaas · branch `feat/playwright-surface` (uncommitted W-lane changes present in tree)

## Verdict

**BLOCKED (BUILD_BROKEN) — 0 specs executed.** The Playwright webServer
(`mix phx.server`, dev env) cannot boot because the dev tree does not
compile. The suite never started; per-file counts are all zero. The compile
failure IS the receipt.

## Preconditions

| Check | Result |
|---|---|
| Postgres localhost:5432 | PASS — `localhost:5432 - accepting connections` |
| Port 4000 free | PASS — `lsof -i :4000` empty |
| INTERNAL_API_TOKEN | ABSENT — not present in `config/*.exs`, `~/.zshenv`, `~/.zshrc`, `~/.zprofile`, `~/.profile`, or any repo `.env*`. Suite ran without it (token-positive cases would self-skip) |

## Exact commands

```
# attempts 1 and 2 — identical result
PATH=$HOME/.asdf/shims:$PATH npx playwright test 2>&1 | tail -60
# → "Error: Timed out waiting 120000ms from config.webServer."

# diagnosis
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev mix compile 2>&1 > /tmp/w30-compile.log
```

## Root cause — verbatim

```
error: module AshA2A.Protocol.Agent is not loaded and could not be found
│
74 │   use AshA2A.Protocol.Agent,
│   ^^^^^^^^^^^^^^^^^^^^^^
│
└─ lib/xaas_web/a2a/next_read_ash_agent.ex:74: XaasWeb.A2A.NextReadAshAgent (module)

== Compilation error in file lib/xaas_web/a2a/next_read_ash_agent.ex ==
** (CompileError) lib/xaas_web/a2a/next_read_ash_agent.ex: cannot compile module XaasWeb.A2A.NextReadAshAgent (errors have been logged)
    (elixir 1.20.2) expanding macro: Kernel.use/2
    lib/xaas_web/a2a/next_read_ash_agent.ex:74: XaasWeb.A2A.NextReadAshAgent (module)
```

## Analysis

`lib/xaas_web/a2a/next_read_ash_agent.ex` (untracked, line 74) references
the `AshA2A.Protocol.*` namespace. That namespace does not exist at the
pinned dependency SHA:

- `mix.lock` pins `ash_a2a` at `3325032d9dea201e6deb82ef242c534aacb3b420`.
- `deps/ash_a2a/lib/` contains **no `protocol/` directory and no
  `defmodule AshA2A.Protocol`** (verified: `grep -rn "defmodule AshA2A"
  deps/ash_a2a/lib`). Closest real module: `AshA2A.Agent`
  (`deps/ash_a2a/lib/ash_a2a/agent.ex:1`). `lib/xaas_web/live/witness_live.ex`
  also imports the same namespace family (line 23 context appears in the same
  error cascade in the live run output) but the hard compile error is the
  `use AshA2A.Protocol.Agent` at `next_read_ash_agent.ex:74`.

Classification: **app gap** — new W-lane code written against a dependency
API surface (`AshA2A.Protocol.Agent`) absent at the pinned `ash_a2a` ref.
Not a spec bug (specs never ran). Not env (Postgres up, port free, only
token absent by design).

## Per-file counts

0 pass / 0 fail / 0 skip across all 15 e2e spec files — nothing executed.
The two 120 s webServer timeouts are the only observed run-level events.

## Failing assertions (top 10)

None — the failure is pre-test (compile). Full compile log captured at
`/tmp/w30-compile.log` (session temp; volatile). Non-fatal warnings observed
during the failed boots: repeated `Spark.Error.DslError` "Must specify the
`pre_check_with` option" warnings across
`lib/xaas/a2a/{agent,task}.ex`, `lib/xaas/conference/*.ex`,
`lib/xaas/igniter/{pack_manifest,refusal_code}.ex`,
`lib/xaas/marketplace/pack.ex`; plus third-party warnings
(websockex, gettext, stripe, json_ld).

## Falsifier to unblock (NOT executed — receipt-only lane)

Advance the `ash_a2a` git ref to a SHA exposing `AshA2A.Protocol.*`, or point
the two offending files at the real pinned surface (`AshA2A.Agent`). Either
unblocks compile → server boot → suite. Both out of scope for this lane.

## Standing

BLOCKED (BUILD_BROKEN), typed root cause, preconditions otherwise green.
Blocker is a compile-time app gap on uncommitted lane code, not
infrastructure.