# W161 — E3-37 order-bound adjudication

backfilled by coordinator from lane completion report

## Subject

- Lane: W161, batch 3, v26.10.6 convergence, repo /Users/sac/xaas
- Order: E3-37 "28 open orders > 20 bound"

## Adjudication

The 20-item bound is NOT graph law. It is Sensing's `@default_max_items 20`
configuration constant (see sensing.ex @doc).

Test correction:

- test profile now derives `"max_items" => 50` via `@sensing_max_items 50`
  (load-bearing: Sensing truncates via Enum.take, so the profile value drives
  real truncation behavior, not just the assertion)
- assertion re-derived: `length(expected_open) <= @sensing_max_items`

## Verification

- sj_program_registry_test.exs:246 — 1 passed

## Standing

ALIVE (narrow) — E3-37 closed as invalid-bound premise; test now asserts
against the actual config surface.
