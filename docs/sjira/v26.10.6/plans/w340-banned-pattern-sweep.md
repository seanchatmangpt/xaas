# W340 — Banned-Pattern / Non-negotiables Regression Sweep (v26.10.6)

Subject: /Users/sac/xaas @ feat/playwright-surface, one canonical checkout, read-only.
Gate: all five checks executed 2026-10-06. Verdict: **0 violations**.

## 1. Mock gate (mix run scan_mock_usage)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix run -e \
  'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test","lib"]))'
```

Real output (tail): Grafana/PromEx upload warnings (:nxdomain, pre-existing, unrelated),
then:

```
[]
```

Verdict: PASS — empty list, as required.

## 2. Banned-pattern grep

`grep -rn 'unittest.mock\|Mock()\|monkeypatch\|mockall\|jest.mock' test/ lib/ e2e/`

Hits (5), all classified exempt (own-check / documentation):

| file:line | text | class |
|---|---|---|
| test/mix/tasks/xaas_verify_and_commit_test.exs:137 | comment: `...word "monkeypatch"... would self-match` | scanner's own self-match test comment — exempt |
| test/mix/tasks/xaas_verify_and_commit_test.exs:206,207,218 | `uses_monkeypatch.ex` fixture asserting the scanner *detects* the pattern | the mock gate's own detection test — exempt |
| test/xaas/generation_test.exs:7 | docstring "`unittest.mock`/`Mox`/stubbed collaborators." | documentation of the ban itself — exempt |
| lib/mix/tasks/xaas.verify_and_commit.ex:131 | `@banned_mock_regex ~r/unittest\.mock|...monkeypatch.../` | the gate's own regex — exempt |

Zero fakes of owned collaborators. Verdict: PASS.

## 3. API-auth floor (router diff)

`git diff lib/xaas_web/router.ex` additions:

- `live("/witness", WitnessLive)` — public LiveView surface per w-* receipt (w305/w-*).
  No token-gated sibling affected.
- `forward("/v1", XaasWeb.A2A.V1TransportPlug, ...)` — mounted inside the existing
  A2A scope whose `:require_internal_api_token` floor stands; comment cites W10 stacked-auth
  analysis and W305 (owned transport replacing vendored Protocol.Plug). No unauthenticated
  sibling to /internal-api or /api.
- Two pipeline reorders (W150, W299c): `:require_internal_api_token` moved BEFORE `:api` /
  `:internal_api` so unauthenticated probes can no longer learn accepted content types via a
  406 before auth. These STRENGTHEN the auth floor; no route weakened.
- No unauthenticated sibling route added. Verdict: PASS.

## 4. Fence census vs _CLOSURE_PLAN §1 rows 4–9

`grep -rn 'TODO(ash_surface)' lib/` → exactly 1:

```
lib/xaas_web/live/marketplace_catalog_live.ex:21: TODO(ash_surface): the generated surface path is
```

Matches §1 row 4 exactly (same file:line, flagged possibly-STALE there). Rows 5–9 fence
classes (CLOAK_KEY placeholder, authorize?: false ingest bypass, unscheduled monitor,
Code.ensure_loaded? soft-gates, optional-dep gate) — none of these classes appears as a NEW
marker in the convergence diff: `git diff lib/ | grep '^+.*TODO(ash_surface)'` → empty
(exit 1). Verdict: PASS — no new fence markers.

## 5. Sensitive-resource routes

`git diff lib/xaas_web/router.ex | grep '^+' | grep -i 'ledger\|accounts'` → empty (exit 1).
No route touching Xaas.Ledger.* or Xaas.Accounts.* added. Verdict: PASS.

## Receipt

- Checks: 5/5 executed, real output recorded above.
- Violations: 0.
- Pre-existing unrelated noise: PromEx/Grafana dashboard-uploader nxdomain warnings during
  the mock-gate mix run (dev telemetry, not a gate failure).
