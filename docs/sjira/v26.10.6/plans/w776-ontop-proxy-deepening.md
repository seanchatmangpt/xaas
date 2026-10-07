# W776 — Ontop SPARQL Proxy Deepening Court

- **Standing**: ALIVE (9/9 real test passes on the exact subject)
- **Lane**: W776, v26.10.6 campaign, repo /Users/sac/xaas, branch
  `feat/playwright-surface`, HEAD a0723bf6
- **Subject**: `test/xaas_web/ontop_proxy_deepening_test.exs` (new, sole
  written file) against `lib/xaas_web/plugs/ontop_proxy_plug.ex` mounted at
  `/internal-api/sparql` in `lib/xaas_web/router.ex:255-259`
- **Command** (real):
  ```
  PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW776 \
    mix test test/xaas_web/ontop_proxy_deepening_test.exs
  ```
- **Real tail**:
  ```
  .........
  Finished in 1.0 seconds (0.00s async, 1.0s sync)

  Result: 9 passed
  ```
- **Docketed backlog item**: the Ontop SPARQL proxy deepening item is now
  docketed and closed by this receipt.

## What the court pins (all real router dispatches + real Bandit receiver on a real OS-assigned ephemeral port via the plug's own `config :xaas, :ontop_base_url` override; zero mocks of owned code)

- **(a) byte-exact forwarding / verbatim relay**
  - GET: query string forwarded byte-exact (receiver observes
    `query=<percent-encoded bytes>` identical to what the client sent;
    upstream path `/sparql`), receiver's response relayed verbatim
    (`application/sparql-results+json; charset=utf-8`, exact body bytes).
  - POST (SPARQL 1.1 Protocol direct POST, `Content-Type:
    application/sparql-query`): raw body forwarded byte-exact and response
    relayed verbatim.
  - `Authorization` header is stripped, never forwarded upstream.
- **(b) receiver down** -> real 502, exact envelope
  `%{"error" => "ontop_unreachable", "detail" => <nonempty inspect string containing "refused">}`,
  halted. Real connection-refused (bind-port-0-then-close), not a stubbed client.
- **(c) receiver 4xx/5xx** -> real passthrough contract: status and body
  relayed verbatim (400 and 500 both pinned), proxy does not halt, does not
  retry, does not rewrite.
- **(d) auth floor per the W723 pinned matrix**: no Authorization header ->
  401 exact W723 body
  `%{"error" => "unauthorized", "detail" => "missing or invalid Bearer token"}`,
  halted, receiver provably never sees the request; wrong Bearer token ->
  same 401/halting. (Env-absent 503 case is owned by the W723 court; not
  re-pinned here.)
- **(e) read-only posture** — honest typed gaps, real behavior pinned:
  - `UNSUPPORTED(method_allowlist)`: the plug forwards `conn.method`
    verbatim for ANY method — a DELETE (with body) and a POST of arbitrary
    JSON are forwarded byte-for-byte like GET. Read-only-ness is enforced
    only by Ontop itself being a query-only SPARQL endpoint, not by this
    proxy.
  - `UNSUPPORTED(raw_body_preservation_after_parsers)`: for content types
    the endpoint's `Plug.Parsers` consumes (`urlencoded`/`multipart`/
    `json`), the raw body is gone before the proxy runs — the proxy
    forwards an EMPTY body upstream and never re-serializes the parsed
    params. A SPARQL-Protocol urlencoded form POST therefore arrives at
    Ontop bodyless through this proxy (existing
    `test/xaas_web/plugs/ontop_proxy_plug_test.exs` never exercised POST,
    so this defect class was unpinned until now).

## Findings (real, run-discovered)

1. POST-form body loss (the second typed gap above) is a real forwarding
   defect class, previously untested; the proxy is byte-exact only for
   content types Plug.Parsers passes through (`application/sparql-query`,
   `text/plain`, ...).
2. Two transient mid-run compile failures of
   `lib/xaas/platform/validations/route_secrets_requires_approver.ex`
   (`undefined variable "previous"`, then `undefined variable "changecset"`)
   were another lane concurrently editing the shared tree; not W776-attributed.
   They resolved as that lane settled; the final run above is clean.

## Lane lease

`_build-laneW776` deletion was denied by the permission system; the lane
build root remains on disk for coordinator cleanup per the same-checkout
fan-out cleanup law.
