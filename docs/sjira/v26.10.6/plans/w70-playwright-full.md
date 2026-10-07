# W70 — Full Playwright Surface Receipt (v26.10.6)

- **Subject**: repo /Users/sac/xaas, branch `feat/playwright-surface`, uncommitted working tree (head d1db2b03), run 2026-10-06.
- **Environment (honest)**: Postgres up (`localhost:5432 accepting connections`); port 4000 free; `INTERNAL_API_TOKEN` **absent** in this environment (no `.env`, not in shell env). Per instruction the run was made **without** the token, exercising the fail-closed 503 surface.
- **Server boot**: Playwright `webServer` (`mix phx.server`, 120s window) **failed to boot in 2/2 standalone attempts**:

  ```
  ** (Mix) Could not start application localize: exited in: Localize.Application.start(:normal, [])
      ** (EXIT) exited in: GenServer.call(Localize.DataLoader, {:load, {:localize, :supplemental, "all_locale_names.etf"}, ...}, :infinity)
          ** (EXIT) an exception was raised:
              ** (File.Error) could not read file "/Users/sac/xaas/_build/dev/lib/localize/priv/localize/supplemental_data/all_locale_names.etf": permission denied
  ```

  The file is `-rw-r--r-- sac` with xattr `com.apple.provenance` and reads fine from an interactive shell; direct start (`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev mix phx.server`) **boots clean and serves HTTP 200**. Playwright then ran against that live server via `reuseExistingServer: true`. Class: **env** (spawned-process file-permission denial), not spec or app. No fixes applied (receipt-only lane).

## Totals

| pass | fail | skip | flaky |
|---|---|---|---|
| 49 | 37 | 11 | 0 |

Duration 79.2s, exit 1. Raw JSON report: `/tmp/w70-report.json`; failure corpus: `/tmp/w70-fails.json`.

## Per-file results

| file | pass | fail | skip |
|---|---|---|---|
| a2a-v1.spec.cjs | 1 | 6 | 0 |
| ash-admin-destroy.spec.cjs | 0 | 1 | 0 |
| ash-admin-matrix.spec.cjs | 2 | 2 | 0 |
| ash-admin-state-change.spec.cjs | 0 | 1 | 0 |
| ash-surface-client.spec.cjs | 4 | 2 | 0 |
| autofde-lab.spec.cjs | 1 | 1 | 0 |
| chicago-pplan-deep.spec.cjs | 11 | 1 | 0 |
| dev-routes.spec.cjs | 0 | 2 | 0 |
| execution-fabric.spec.cjs | 1 | 0 | 2 |
| full_surface.spec.ts | 8 | 3 | 0 |
| ggen-workbench.spec.cjs | 0 | 6 | 0 |
| internal-api.spec.cjs | 2 | 0 | 2 |
| marketplace.spec.ts | 0 | 4 | 0 |
| mcp-a2a.spec.cjs | 2 | 3 | 0 |
| next-read-ml.spec.cjs | 4 | 2 | 0 |
| smoke.spec.cjs | 1 | 0 | 0 |
| sparql-proxy.spec.cjs | 2 | 0 | 1 |
| stripe-webhook.spec.cjs | 2 | 0 | 2 |
| system-deep.spec.cjs | 5 | 1 | 0 |
| wd-fa-cs2.spec.cjs | 1 | 0 | 0 |
| witness.spec.cjs | 0 | 2 | 1 |
| zcode-cli-fabric.spec.cjs | 2 | 0 | 3 |
| **TOTAL** | **49** | **37** | **11** |

## Failure classification (37)

### Class: env — token-absent fail-closed 503 (17)

Specs reach token-gated routes (`/api`, `/internal-api`, `/a2a`, `/mcp`, ash_admin data endpoints) and get fail-closed **503** where they expect 200/405/422. Would pass with `INTERNAL_API_TOKEN` provisioned.

- a2a-v1.spec.cjs (6): agent card 200→503; wrong-method 405→503; malformed JSON -32700 200→503; unknown method -32601 200→503; message/send 200→503; SSE stream 200→503.
- ash-admin-destroy.spec.cjs:55 (1): destroy CapabilityLivenessReceipt, 200→503.
- ash-admin-state-change.spec.cjs:26 (1): create CapabilityLivenessReceipt, 200→503.
- ash-admin-matrix.spec.cjs:112 (1): record show panel, 200→503.
- mcp-a2a.spec.cjs (3): bearer gate not-503 → 503; agent card 200→503; zoe-event card 200→503.
- ggen-workbench.spec.cjs (5): `typed auth refusal without token` x2 expected 406 got [401, 503]; oversized argv / traversal / non-integer-timeout refusals x3 expected 422 got 503.

### Class: env-triggered app/spec contract gap (1)

- ggen-workbench.spec.cjs:69 — `resp.headers()["link"]` is undefined on the fail-closed response; spec comment claims the AsyncAPI `rel="service-desc"` Link header is "unconditional". Server does not advertise it on the 503/401 path. Either server-side fix (advertise on refusal) or spec-side (drop the unconditional claim).

### Class: spec bug (6)

- dev-routes.spec.cjs:37 — strict-mode violation: `getByText('Phoenix LiveDashboard')` resolves to 2 elements (`<h1>` + footer "Phoenix LiveDashboard was…"). Ambiguous locator; page renders correctly.
- autofde-lab.spec.cjs:55 — strict-mode violation: `locator('table tbody tr').filter(…).first().or(getByText('No webhook deliveries yet.'))` resolves to 2 elements (the typed empty-state row AND its cell). Panel renders the typed empty state correctly; the `.or()` chain is self-defeating.
- system-deep.spec.cjs:137 — `toHaveText(/^(ALIVE|UNKNOWN)$/)` received `"\n              UNKNOWN\n            "` — whitespace; server renders UNKNOWN as designed; spec needs trimmed matching.
- ash-admin-matrix.spec.cjs:52 + dev-routes.spec.cjs:59 (2) — `getByText('Operations', { exact: true }).first()` resolves to a **hidden** collapsed-nav `<span>Operations</span>` in the ash_admin chrome; element exists but is not visible at 1280x720. Wrong locator target.

### Class: app gap (6)

- ash-surface-client.spec.cjs:70, 103 (2): generated runtime/client `.mjs` fails browser compile — `compile error: Unexpected token ':'`. Generated JS is not browser-valid (EA35 aftermath). Real generator/app gap.
- witness.spec.cjs:96, 104 (2): h1 "Certified Receipts" not found; neither the receipts table nor the typed `witness-empty-row` renders. The in-spec W55 `mix run -e` seed also produced no `W55_SEED_OK` marker (seed step failed in this harness env), but the spec's contract states the typed empty state must render even when unseeded — it does not. App gap.
- next-read-ml.spec.cjs:75, 98 (2): `[data-testid="flash-info"]` and `[data-testid="ask-results"]` never appear after the actions. LiveView events not producing the expected markup (timing-sensitive; could not distinguish timing vs missing markup in this run).

### Class: seed-dependent (7)

- full_surface.spec.ts:61, 82, 117 (3) + marketplace.spec.ts:39, 60, 88, 109 (4): pack table renders **0 rows**; search narrows to 0; detail journey unreachable. LiveView renders; the ingested marketplace catalog is empty in this dev DB (no ingestion run on this subject).
- chicago-pplan-deep.spec.cjs:194 (1): wasm4pm capability card shows state `successor` where the spec expects `candidate` — committed data drift from the fixture assumption.

## Class totals

| class | count |
|---|---|
| env (token-absent fail-closed 503) | 17 |
| env-triggered contract gap (Link header on 503) | 1 |
| spec bug | 6 |
| app gap | 6 |
| seed-dependent | 7 |
| **TOTAL** | **37** |

Plus run-level: webServer boot failure (env, 2/2).
