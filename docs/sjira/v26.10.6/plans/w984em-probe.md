# W984em — A2A surface unclaimed-family probe + depth court

- Lane: W984em, checkout `/Users/sac/xaas`, branch `feat/playwright-surface` (untouched)
- Subject: `test/xaas_web/a2a/a2a_uncovered_branch_court_w984em_test.exs` (new, 7 tests, all real
  A2A.call/ConnCase/Postgres, zero mocks)
- Sibling in-flight file in `test/xaas_web/a2a/`:
  `return_hold_cascade_avatars_test.exs` (modified, another lane) — disjoint, not touched.

## Per-module disposition table

| lib module | classification | disposition |
|---|---|---|
| `XaasWeb.A2A.NextReadUserAgent` | covered + genuinely unexercised state-bearing branches | 4 new tests: empty-band browse reply (`books == []` arm, :158), cast-failure deny arm of `resolve_actor/2` (:112-119, real via `PersonaGrant.list_active`'s `:uuid` arg), CirculationBorrowReactor default/hold branch reply (:202-208, real `HoldRequest` row + zero inventory + checkout-count delta), `run/3` true-arm `:input_required` fallback (:140-141) |
| `XaasWeb.A2A.NextReadUserAgentSkills` | no state (generated card data, never hand-edited per its own moduledoc) | COVERED indirectly via every dispatch test; no state to court |
| `XaasWeb.A2A.NextReadAshAgent` | adapter; reply/input_required/error passthrough covered indirectly by v1_protocol/v1_sse tests | `map_parts/1` File and Data arms are unreachable through real dispatch (the hex agent never emits File/Data parts) — recorded UNCOVERED-UNREACHABLE, not faked; `handle_cancel` trivial `:ok` |
| `XaasWeb.A2A.V1TransportPlug` | GET-card caching arm covered (v1_protocol test 1 pins `public, max-age=300`) | new test pins the `conn.method == "GET"` guard: POST JSON-RPC cache-control is NOT rewritten, with a pairing assertion that the GET contract still holds (kills the drop-the-method-guard mutation) |
| `XaasWeb.A2A.ZoeEventPlug` | no state (pure delegation to `A2A.Plug`) | COVERED indirectly via the `/zoe-event` router forward; nothing to court |
| `XaasWeb.A2A.ZoeEventSimulationAgent` | contract/simulate/structured-json-refusal covered | 2 new tests: non-object snapshot catch-all arm (:67-68) and the `{:error, reason}` → `"simulation refused: ..."` stringify arm (:64-65) with the real observed refusal `{:invalid, :event_id}` |

## Not courted (typed, no filler)

- `NextReadUserAgent.browse/2` `{:error, error}` arm and `checkout/3` `{:halted, reactor}` arm:
  no real state trigger found (would require breaking Ash reads / halting the reactor from
  outside); recorded rather than fabricated.
- `NextReadAshAgent.map_parts/1` File/Data arms: unreachable through the real skill surface.

## Gates (real output)

- Court run: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984em mix test
  test/xaas_web/a2a/a2a_uncovered_branch_court_w984em_test.exs` → exit 0, `7 passed` (iterations:
  2/7 → 4/7 → 7/7; fixes: setup context must be returned as `{:ok, map}` for ExUnit to merge it;
  grade-1000 empty band because the test DB carries seeded grade-3/4 catalog rows; checkout count
  asserted as delta — test DB has pre-existing checkout rows; zoe stringified-refusal real shape is
  `Error: "simulation refused: {:invalid, :event_id}"`).
- Mock gate on the court file: `[]` (expect `[]`).
- No commit made (per lane instructions).

## Build-root cleanup

- `rm -rf /Users/sac/xaas/_build-laneW984em` — succeeded; directory confirmed gone (`ls`:
  "No such file or directory"). Not denied.
