# W951b — internal-api spec authorship-witnessing gate (closes W949 NEEDS-REVIEW)

## Subject

- Repo: /Users/sac/xaas, branch `feat/playwright-surface`, uncommitted working tree
  (W836-contract edit to `e2e/internal-api.spec.cjs` as left by the authoring lane).
- Exact head: `fab56ae1` + uncommitted spec diff (not committed — coordinator owns commits).

## Contract under witness

`e2e/internal-api.spec.cjs` implements W836's warming_up-skip contract:
`ultracode_tick.status` ∈ {"ok","skipped"}; `skipped` must carry
`reason: "warming_up"` (fresh-boot grace window). W949 ruled the edit correct
on inspection but NEEDS-REVIEW because no receipt witnessed it passing.

## Real run (authorship-witnessing)

Fresh Playwright boot per established convention (W822 port config + W848
quoted probe both in `playwright.config.cjs`):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW951b \
  PW_PORT=4132 INTERNAL_API_TOKEN=dev-e2e-token \
  PW_MARKETPLACE_CATALOG=/tmp/w951b-marketplace-catalog.json \
  npx playwright test e2e/internal-api.spec.cjs --reporter=list
```

- `mix compile` under the lane build root: exit 0 ("Generated xaas app").
- Boot: catalog written (13 packs), W55/W823 seed OK, readiness probe 200 on
  4132 via tokened `/internal-api/health`; server log `/tmp/xaas-e2e-server.log`
  (PromEx/Grafana nxdomain warnings only — offline environment noise).
- Run tail:

```
  ✓  1 .../internal-api token gate › refuses /internal-api/health without a token (fail-closed, typed body) (41ms)
  ✓  2 .../internal-api token gate › refuses /internal-api/ocel_summary with an invalid token (401, typed body) (10ms)
  ✓  3 .../internal-api token gate › serves real health data with the env token (21ms)
  ✓  4 .../internal-api token gate › serves real OCEL summary data with the env token (31ms)

  4 passed (2.1m)
[exited with code 0]
```

## Verdict

PASS — all 4 tests green on a real tokened fresh boot, including the W836
warming_up-skip assertions. W949's NEEDS-REVIEW is closed by this run.

## Standing

ALIVE (spec contract witnessed passing on the exact edited subject).

## Cleanup

`rm -rf _build-laneW951b` was denied by the session permission gate — the
lane build root (compile-verified, ~warm) is LEFT FOR THE COORDINATOR to
delete at integration per the fanout cleanup law. No leftover server: the
playwright webServer was tree-killed on exit (port 4132 released by the
run's own teardown).
