# W836 — Health-endpoint contract court

Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD `a0723bf61a1c6058bdcd2d0202c9519840182a5e` (canonical checkout; lane build root `_build-laneW836`)

## Task

The health endpoint's check set (W752 found `ultracode_tick` erroring under
Oban `testing: :manual`) was undocumented as a contract. Add
`test/xaas_web/health_court_test.exs`: Chicago-style via real ConnCase
pinning (a) the healthy 200 body shape, (b) the real `ultracode_tick`
`testing: :manual` contract, (c) each check's typed failure mode, (d)
determinism x2.

## Findings (from reading the code, then pinning it)

`lib/xaas_web_web/controllers/health_controller.ex` runs **10 checks** over
`GET /internal-api/health` (token-gated `/internal-api` scope,
`lib/xaas_web/router.ex:100`):

| check | real behavior | failure mode (typed) |
|---|---|---|
| `repo` | `SELECT 1` via `Ecto.Adapters.SQL.query!` on `Xaas.LegacyRepo` | raises → `rescue` → `detail = {exception, message}` map |
| `ontop` | config-gated on `config :xaas, :ontop_endpoint`; real HTTP probe `/sparql` via `:ontop_proxy_http_client` (default `Req`) | absent → `skipped(:not_configured)` (aggregate stays 200); 5xx/transport error → string `detail`; raised → structured `{exception, message}`; exit → `catch` clause string `"exit: ..."` |
| `ultracode_tick` | `Xaas.Ultracode.TickHealth.check/1` against real `oban_jobs` (`completed`/`executing` `Xaas.Ultracode.Run.Workers.Tick` rows), staleness 5 min, W310h warmup typing (boot + 5+2 min grace, test seam `:health_node_boot_at_override`) | W310h branches: post-boot healthy → ok with `last_tick_at`/`elapsed_minutes`; post-boot stale → error map `detail{last_tick_at, elapsed_minutes, stale_after_minutes, reason}`; no post-boot evidence within grace → `skipped(:warming_up)`; past grace with no evidence → error with "appears dead, not just warming up" reason |
| `ash_domain:<7 domains>` | real `Ash.count!/2, authorize?: false` on one resource per real `Ash.Domain` (`Accounts`, `Billing`, `Governance`, `Ledger`, `Marketplace`, `Operations`, `Platform`) | raise → `rescue` → structured `detail`; catch → string |

Aggregate: fail-closed — only a real `"error"` degrades to 503/`"error"`;
`"skipped"` is not down. No timeouts: the controller wraps each check in
`try/rescue/catch` only — a hung check would hang the request (typed gap).

## Court contents (test/xaas_web/health_court_test.exs, 11 tests)

- 401 floor through the real token pipeline.
- Healthy path: 200, exact 10-name check set (`@check_names` — a removed
  or added check fails the court), exact top-level `{status, checks}`
  shape, every check `ok`/`skipped`/`error` + real `latency_ms`, per-check
  payload keys (`count` for all 7 `ash_domain:*`, `last_tick_at` +
  `elapsed_minutes` for `ultracode_tick`).
- `ultracode_tick` under Oban `testing: :manual` (empty sandbox
  `oban_jobs`): pinned as typed `skipped(:warming_up)`, aggregate 200,
  and `warmup_until - node_boot_at == 7 minutes` exactly. W752's "503"
  is the *past-grace* case: boot + 7 min with no tick evidence is a real
  503 error (pinned via the controller's real `:health_node_boot_at_override`
  seam, no sleeping).
- Stale-but-post-boot branch: real 30-min-old completed tick row → error
  carrying exact `last_tick_at` (usec-exact), `elapsed_minutes >= 29`,
  `stale_after_minutes == 5`, reason string.
- Failure modes typed: ontop transport error → string `detail` containing
  `econnrefused`; raising check → `{exception: "RuntimeError", message}`
  map; exit → `"exit: :timeout_probe"` catch clause; unconfigured ontop →
  `skipped(:not_configured)` 200.
- Determinism x2: two consecutive requests identical modulo `latency_ms`
  (healthy 200 case), and two consecutive 503 runs identical typed
  `ultracode_tick` error (reason + `last_tick_at`).

No mocks; the only stand-ins are real `request/1` modules for the Ontop
HTTP client (same disclosed pattern as the sibling
`health_controller_test.exs` — the Java Ontop container is genuinely
infeasible in-sandbox).

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW836 \
  mix test test/xaas_web/health_court_test.exs
```

Real tails (runs 4 and 5, exit 0 both):

```
...........
Finished in 0.8 seconds (0.00s async, 0.8s sync)

Result: 11 passed
```

```
...........
Finished in 1.0 seconds (0.00s async, 1.0s sync)

Result: 11 passed
```

(Run 1: 7/11 — three real test bugs, fixed forward: `elem(0)` vs `elem(1)`
on `DateTime.from_iso8601` tuples, usec-exact `last_tick_at` comparison,
and `a == b == c` chains being left-associative boolean compares. No
implementation change: the controller behaves as documented.)

## Standing

ALIVE (11/11 across two consecutive real runs against exact HEAD
`a0723bf6`).

## Typed gaps / notes

- UNSUPPORTED(timeout-typing): no check has a timeout — a hung
  collaborator (e.g. a real Ontop that accepts but never answers) hangs
  the health request itself. The `catch` clause covers exits/throws, not
  stalls. Not fixed here (implementation lane, not test lane).
- GAP(diataxis): the check-set contract now lives in
  `test/xaas_web/health_court_test.exs`; `docs/claude/diataxis/reference/http-api-surface.md`
  does not enumerate the 10 checks. Doc lane item.
- W752 resolution: under `testing: :manual` the real contract is
  `skipped(:warming_up)` with aggregate 200 (not 503); the 503 only
  occurs past the boot+7-min grace window with zero tick evidence —
  pinned by test.
- Lane hygiene: `_build-laneW836` deletion was refused by the permission
  system (`rm -rf` denied); left in place for the coordinator per the
  fanout cleanup law (≈ full-deps test build, ~2 GB class).
- Not committed, per lane contract. Files: the test + this receipt only.
