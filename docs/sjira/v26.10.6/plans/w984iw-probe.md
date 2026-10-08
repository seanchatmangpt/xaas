# W984iw — http-api-surface.md doc deepening probe

Lane W984iw · checkout `/Users/sac/xaas` @ `feat/playwright-surface` · 2026-10-07 ·
docs-only, no commit, no build root (per lane contract).

## Subject

`docs/claude/diataxis/reference/http-api-surface.md` — refreshed with the W984 wave's
router/endpoint findings via an appended (inserted before "## See Also", no restructuring)
`## Verified 2026-10-07 (W984 wave router/endpoint probes)` section (now line 683).
Doc grew 704 → 772 lines.

## Command-verified claims (real grep/sed output this session)

- `grep -n "rpc/run..." lib/xaas_web/router.ex` → `post("/rpc/run", ...)` at router.ex:109,
  `post("/rpc/validate", ...)` at router.ex:110, inside the explicit token-gated
  `/internal-api` scope (`:api` + `:require_internal_api_token`).
- `sed -n 25,360p lib/xaas_web/router.ex` → scope/pipeline orders confirmed in code:
  `/webhooks` (`:api` only), `/internal-api` explicit scope, `/internal-api/fabric`,
  `/internal-api/sparql` forward, `/mcp` (`:api, :require_internal_api_token,
  :resolve_org_actor, :audit_mcp_tool_call`), `/a2a`
  (`:prov_origin, :api, :require_internal_api_token`) with `/zoe-event`, `/v1`, `/`
  forwards, `/api/workbench` (`[:require_internal_api_token, :api]` — W150 order),
  `forward "/internal-api"` (`[:require_internal_api_token, :internal_api,
  :set_internal_api_system_actor]` — W739 order), `forward "/api"`
  (`[:prov_origin, :require_internal_api_token, :internal_api, :authenticate_org,
  :resolve_org_attr...]` — W299c/W605 order).
- `sed -n 90,94p` + `grep -n PROMETHEUS_URL` →
  `lib/xaas_web/controllers/prometheus_query_controller.ex:92`
  `System.get_env("PROMETHEUS_URL", @default_base_url)` (default
  `http://localhost:9090`).
- `grep -n '^## Verified'` on the doc → line 683, `wc -l` → 772.

## Court receipts cited (all present on disk)

- `w984hq-probe.md` — router/endpoint plug-chain probe: per-scope disposition table;
  negotiation cells courted (browser 406, HEAD, stripe 406/dispatch, authenticated
  text/plain on `/internal-api` catch-all → 406); 6 tests passed exit 0.
- `w984if-probe.md` — PrometheusQueryController 502 branch closure via the real
  `PROMETHEUS_URL` seam (real Bandit upstream, zero mocks); 4 tests passed.
- `w984eq-probe.md` — controller residue probe: per-module disposition table; real
  ConnCase court for missing `query` param + subquery rejection; notes the
  auth-before-negotiation floor ordering (W150/W299c/W739).
- `w984ho-probe.md` — AshTypescript RPC surface probe: routes at router.ex:109-110
  confirmed; GET-on-POST-only → 406 via catch-all; `rpc/validate` non-list `fields`
  FunctionClauseError (500) defect found and pinned (`rpc/run` returns typed
  `success=false` for the same body).

`w984iu-probe.md` (this file) is the lane's own receipt; the task also named it as a
possible citation, but it did not exist at write time — no self-citation.

## Doc staleness fixes

No stale route lists found — the pre-existing route/pipeline content matched the
router on disk (scopes, forwards, workbench, stripe, sparql, prometheus, rpc,
browser, dev-routes). The verified section adds: exact pipeline orders with
mutation rationale, the PROMETHEUS_URL seam, the allowlist/400/502 branch map, the
authenticated catch-all 406 behavior, the `/api` GET-forward 406 fall-through, and
the disclosed `rpc/validate` cast-failure defect.

## Gates

No code touched; no test run required (docs-only lane). Verification was real
grep/sed output against `lib/xaas_web/router.ex` and the cited probe receipts on
disk, re-read at use time.

## Standing

ALIVE (doc claims command-verified against code at this tree state; receipts re-read
from disk, not recalled).
