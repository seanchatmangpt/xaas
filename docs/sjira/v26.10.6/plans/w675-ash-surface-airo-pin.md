# W675 — ash_surface AIRo surface pin (receipt)

- **Lane**: W675 (v26.10.6 campaign), AIRo wiring extension
- **Subject**: /Users/sac/ash_surface @ branch `main`, HEAD `d55c576d11a2213a666c44f135c96e2f6baf44d0` (unmodified by me except my new test file; large pre-existing dirty tree from other lanes — untouched)
- **Toolchain**: elixir 1.20.3-otp-28 / erlang 28.3 (asdf, per `.tool-versions`); private build root `_build-laneW675` (deleted after run)

## Ledger row (airo-wiring-ledger.md:37, w637)

Ledger claims `priv/airo_risk_description.ttl` (11,271 B) + 4-test ExUnit court. Verified on disk: TTL is exactly 11,271 bytes; `test/airo_risk_description_test.exs` (4 tests) exists and passes. **No ledger drift.**

## What was added

`test/airo_surface_pin_w675_test.exs` — Chicago-style pin asserting the TTL's claims about the real modules by calling them (no mocks):

1. `AshSurface.Standing.base_standings/0`: each base standing passes `valid?/1`, round-trips `validate!/1`, is not a refusal (`Vocabulary.refusal_atom?/1 == false`, `Standing.refused?/1 == false`); `validate!/1` returns well-formed refusal `:REFUSED_UNKNOWN_SUBJECT` unchanged; raises `ArgumentError` on `:not_a_standing_w675` and on `:UNKNOWN` (typed message).
2. `AshSurface.Vocabulary` REFUSED_* contract per TTL prose: bare `"REFUSED"` / `"REFUSED_"` / `:REFUSED` rejected; `"REFUSED_NO_AUTHORITY"` and `:REFUSED_W675_PROBE` accepted; `"REFUSED_BAD CODE!"` rejected; `refusal_prefix/0 == "REFUSED_"`; non-atom/boolean standings invalid.
3. All `VIA <path>` citations re-derived from the TTL by regex (not copied from W637's list) exist on disk.

## Real commands and output

```
$ cd /Users/sac/ash_surface && PATH=$HOME/.asdf/shims:$PATH \
  MIX_BUILD_ROOT=_build-laneW675 MIX_ENV=test mix test test/airo_surface_pin_w675_test.exs
...
Finished in 0.1 seconds
Result: 3 passed

$ ... mix test test/airo_risk_description_test.exs
....
Result: 4 passed
```

## Standing

- **W675 pin court**: ALIVE — 3/3 passed on exact subject d55c576d.
- **W637 AIRo court (pre-existing)**: ALIVE — 4/4 passed (re-run, not session-introduced).
- **Ledger row w637**: accurate; standing unchanged.
- Not committed (per lane instructions); coordinator owns integration. `_build-laneW675` deleted.
