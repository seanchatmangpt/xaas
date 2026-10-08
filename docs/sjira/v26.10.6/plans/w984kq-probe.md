# W984kq — SPARQL Proxy Surface Unclaimed-Family Probe Receipt

- Subject: `feat/playwright-surface` working tree (no commit, per lane instruction), repo `/Users/sac/xaas`
- Lane: W984kq; date 2026-10-08
- Surface: `XaasWeb.OntopProxyPlug` (`lib/xaas_web/plugs/ontop_proxy_plug.ex`), mounted via `forward("/sparql", ...)` under `/internal-api` in `lib/xaas_web/router.ex:268`, behind `XaasWeb.Plugs.RequireInternalApiToken`.

## 1. Census disposition (all `call/2` branches)

Against pre-existing courts `test/xaas_web/ontop_proxy_deepening_test.exs` (W776) and
`test/xaas_web/plugs/ontop_proxy_plug_test.exs`:

| branch | disposition |
|---|---|
| query-string-present (`"?" <> qs`) | COVERED (deepening (a)) |
| req-header strip (host/authorization/content-length) | COVERED (deepening (a) auth-strip; content-length not observable downstream — receiver re-frames) |
| `{:ok, resp}` verbatim relay | COVERED (deepening (a)) |
| `{:error, reason}` → 502 `ontop_unreachable`, halted | COVERED (deepening (b), real connection-refused) |
| 4xx/5xx passthrough, not halted | COVERED (deepening (c)) |
| 401 auth floor before plug | COVERED (deepening (d)) |
| `assigns[:raw_body]` preference (W794) | COVERED (deepening (f), incl. multipart pinned gap) |
| method verbatim, no allow-list (typed gap) | COVERED as pinned typed gap (deepening (e)) |
| **empty query-string branch** | UNCOVERED → courted (T1) |
| **`read_body` `{:more, _, _}` accumulation** | UNCOVERED → courted (T2) |
| **upstream hop-by-hop response-header strip** | UNCOVERED → courted (T3) |
| defensive `path_info` fallback `"/sparql"` | UNCOVERED via router (dead through `forward/2`, which preserves full `path_info`); courted at plug level (T4) |
| `encode_body` non-binary clause | UNREACHABLE via `Req`'s public contract (bodies are binaries) — typed, no filler test |

## 2. Court file

`test/xaas_web/controllers/sparql_proxy_court_w984kq_test.exs` — 4 tests:

- **T1** empty query string → upstream sees `query_string == ""` (no dangling `?`).
- **T2** >8MB `application/sparql-query` POST → `{:more,_,_}` recursion; upstream sees the body byte-complete.
- **T3** upstream response with `transfer-encoding`/`connection` → stripped on the client conn; `x-ontop-node` relayed. Via the plug's documented `config :xaas, :ontop_proxy_http_client` seam with a real module (`FakeHopByHopClient`, same idiom as `ontop_proxy_plug_test.exs`) because a real Bandit receiver cannot emit hop-by-hop response headers (Bandit owns framing and rejects them).
- **T4** plug-level call with non-`["internal-api","sparql"|...]` `path_info` → falls back to upstream `/sparql`.

Chicago posture: real ConnCase through the real router, real Bandit ephemeral-port receiver (stated exception: third-party Ontop Java container not assumed running, same as W776), zero mocks, no interaction-only assertions; mutation rationale in each test comment.

## 3. Transport finding during court construction

T3 first attempt (receiver setting `transfer-encoding`) produced a real 502: Bandit rejects
plug-set hop-by-hop response headers. Receiver also had to implement its own `{:more, _, _}`
accumulation (same contract as the proxy) to receive T2's >8MB body. Both are receiver-side
facts, not proxy defects; no production code changed.

## 4. Verification (real runs, this lane build root)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984kq mix test test/xaas_web/controllers/sparql_proxy_court_w984kq_test.exs` → exit 0, `4 passed` (first run 2/4: receiver-side chunking + Bandit hop-by-hop findings above; fixed in receiver, re-run green).
- Same env, `mix test test/xaas_web/ontop_proxy_deepening_test.exs test/xaas_web/plugs/ontop_proxy_plug_test.exs test/xaas/sparql_bridge_court_test.exs` → exit 0, `19 passed` (pre-existing courts stay green).
- Mock gate `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'` → `[]`.

## 5. Standing

- New branches: T1–T4 COVERED (witnessed execution, this receipt).
- `encode_body` non-binary clause: UNSUPPORTED (unreachable-through-req-contract) — no test written.
- Proxy method allow-list remains the disclosed UNSUPPORTED(method_allowlist) typed gap (W776).
- No commit (lane instruction); file left in working tree for coordinator integration.
- Lane build root `_build-laneW984kq` deleted at integration per cleanup law (see below).

## 6. Replay

```bash
cd /Users/sac/xaas
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984kq \
  mix test test/xaas_web/controllers/sparql_proxy_court_w984kq_test.exs
```
