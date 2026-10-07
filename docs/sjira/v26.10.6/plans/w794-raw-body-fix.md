# W794 — Ontop Proxy Raw-Body Fix (closes W776 gap UNSUPPORTED(raw_body_preservation_after_parsers))

- **Standing**: ALIVE (11/11 deepening-file passes + 3 plug-test passes on the
  exact subject, real runs below)
- **Lane**: W794, v26.10.6 campaign, repo /Users/sac/xaas, branch
  `feat/playwright-surface`, HEAD a0723bf6. Not committed (coordinator owns
  transitions per same-checkout fan-out law).
- **Closes**: W776 receipt's second typed gap
  (`docs/sjira/v26.10.6/plans/w776-ontop-proxy-deepening.md`,
  `UNSUPPORTED(raw_body_preservation_after_parsers)`) for urlencoded/json;
  multipart remains a disclosed narrower gap (below).

## Before

The endpoint's `Plug.Parsers` (urlencoded/multipart/json) consumes the raw
request body before the router runs, and `XaasWeb.OntopProxyPlug` sits in the
router at `/internal-api/sparql`. For any POST whose content type matched a
parser, the proxy ran `read_body/1` on an already-consumed conn and forwarded
an **empty body upstream** — a SPARQL 1.1 Protocol urlencoded form POST
arrived at Ontop bodyless. W776 pinned this as real failing behavior
(`assert seen2.body == ""`).

## After (minimal, house-idiomatic)

The endpoint already owned exactly this capture point: `Plug.Parsers` is wired
with `body_reader: {XaasWeb.Plugs.StripeRawBodyReader, :read_body, []}` (the
Stripe webhook raw-signature cache). W794 extends that existing reader and the
proxy — no endpoint change, no new plug in the pipeline:

- `lib/xaas_web/plugs/stripe_raw_body_reader.ex` — path gate generalized from
  `["webhooks", "stripe"]` to `@raw_body_paths` =
  `[["webhooks", "stripe"], ["internal-api", "sparql"]]`. For the sparql path
  the exact raw bytes are now cached into `conn.assigns[:raw_body]` exactly as
  Stripe's already were. Stripe behavior unchanged (its existing tests pass).
- `lib/xaas_web/plugs/ontop_proxy_plug.ex` — `call/2` now uses
  `forwarded_body/2`: prefers `conn.assigns[:raw_body]` when present (byte-exact
  cached capture), else streams `read_body/1` off the conn as before
  (content types Plug.Parsers passes through, e.g. `application/sparql-query`).

`conn.body_params` are still decoded normally by the endpoint, so consumers
parsing form params keep working unchanged.

## Remaining typed gap (disclosed, not fixed by this lane)

`UNSUPPORTED(raw_body_preservation_multipart)`: the multipart parser bypasses
`Plug.Parsers`' `:body_reader` (it reads part bodies straight off the adapter),
so the raw bytes are unrecoverable at the proxy. Fixing it needs a capture plug
mounted before `Plug.Parsers` in the endpoint pipeline — a file outside this
lane's lease. Pinned as real behavior in the deepening court.

## Courts added/changed (test/xaas_web/ontop_proxy_deepening_test.exs, extend-only)

- NEW (f): urlencoded SPARQL Protocol form POST arrives upstream with the
  **exact original body bytes** (including `+`/`%2B`/`~` wrinkles that a
  param re-serialization would mangle), and `conn.body_params` still decode.
  **Mutation rationale**: if the raw-body capture in StripeRawBodyReader is
  dropped for `["internal-api", "sparql"]` (or the proxy stops preferring
  `assigns[:raw_body]`), Plug.Parsers has already consumed the body and the
  proxy forwards `""` — `assert seen.body == body` fails (got `""`).
- NEW: multipart pinned as the honest remaining gap (`seen.body == ""` with the
  typed-gap rationale inline).
- CHANGED: the W776 (e) court's final assertion `assert seen2.body == ""`
  pinned the defect itself; re-pinned to the fixed behavior
  (`seen2.body == Jason.encode!(%{"anything" => "goes"})`). All other 8 W776
  courts untouched and green (GET byte-exact, direct sparql-query POST,
  auth-strip, 502, 400/500 passthrough, 401 floor x2, method verbatim).

## Command (real)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW794 \
  mix test test/xaas_web/ontop_proxy_deepening_test.exs \
           test/xaas_web/plugs/ontop_proxy_plug_test.exs \
           test/xaas_web/plugs/stripe_raw_body_reader_test.exs
```

Real tail:

```
..............
Finished in 0.9 seconds (0.00s async, 0.9s sync)

Result: 14 passed
```

(First run exposed the multipart body_reader bypass as a real failure
`left: ""`; classified per the verify ladder and re-pinned as the typed gap
above rather than patched-by-assertion-in-reverse.)

## Files written

- `lib/xaas_web/plugs/stripe_raw_body_reader.ex` (edit, generalize path gate)
- `lib/xaas_web/plugs/ontop_proxy_plug.ex` (edit, `forwarded_body/2`)
- `test/xaas_web/ontop_proxy_deepening_test.exs` (extend only)
- `docs/sjira/v26.10.6/plans/w794-raw-body-fix.md` (this receipt)

Handwritten (no generator profile exists for plug/test surfaces;
UNSUPPORTED(generator-capability) not owed — this is the irreducible residue
class for router-level plugs in this repo).
