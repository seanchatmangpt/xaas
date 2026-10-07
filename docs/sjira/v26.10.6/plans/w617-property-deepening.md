# W617 — Property/Fuzz Deepening: AuditChain + JCS

Lane W617 of the EU-AI-Act wave. Repo `/Users/sac/xaas` @ `feat/playwright-surface`.
Build root: `_build-laneW617` (private lease, deleted at integration).

## Files (contract scope, all new)

- `test/xaas/witness/audit_chain_property_test.exs`
- `test/xaas/semantics/jcs_property_test.exs`

## Subjects

- `lib/xaas/witness/audit_chain.ex` (W503) — read-only.
- `lib/xaas/semantics/jcs.ex` (W514) — read-only.

## Property inventories

### AuditChain (`Xaas.Witness.AuditChainPropertyTest`)

| id | property | generator |
|----|----------|-----------|
| P1 | valid chains length 1..50 verify `:ok` (plain, `expected_head`, `expected_length`) | 500 seeds x 50 lengths |
| P2 | tamper at EVERY position k detected: `{:error, {:tampered, k}}` for k < n-1 plain; with `expected_head` always detected (`k` or `:head` for final link) | 200 seeds x 50 lengths, exhaustive k per chain |
| P2b | fixed length-50 chain, all 50 positions swept, expected_head pinned | deterministic |
| P3 | any nontrivial permutation detected `{:error, {:tampered, k}}`, integer k | 300 seeds x 29 lengths x 300 mutate seeds |
| P3b | reversal + rotation detected | deterministic |
| P4 | martingale monotone non-increasing over randomized tamper patterns (0/1 latch, `1*0*` shape), all-valid = all-ones; consistency with verify under expected_head | 500 seeds x 50 lengths x 3 modes |
| P4b | 120-case deterministic monotonicity floor batch | seeds 1..120 |

Documented unsigned-tail limitation (last link content tamper w/o `expected_head`) is asserted, not papered over.

### JCS (`Xaas.Semantics.JcsPropertyTest`)

| id | property | generator |
|----|----------|-----------|
| J1 | encode deterministic across repeated calls and rebuilds | 1000 seeded nested structures (depth 4) |
| J2 | `Jason.decode!(encode(x))` round-trips (normalized) | same cases |
| J3 | keys ascending at EVERY nesting level, verified by scanning the encoded bytes (own JSON scanner), not by trusting the encoder | same cases |
| J4a | integer corpus (incl. >2^53, bignums) minimal + round-trip | fixed corpus |
| J4b | float/exponent corpus minimal forms pinned (`1.0e30`→`1e+30`, `-0.0`→`0`, `2.0e-308`, max-double) + round-trip | fixed corpus |
| J4c | 2000 seeded random magnitudes round-trip to identical doubles | property |
| J4d | numbers stable byte-identical inside nested structures | fixed |

## Verification

```
MIX_BUILD_ROOT=_build-laneW617 mix compile          # strict, green
MIX_BUILD_ROOT=_build-laneW617 mix test \
  test/xaas/semantics/jcs_property_test.exs \
  test/xaas/witness/audit_chain_property_test.exs   # green
```

Case counts (property-case inventory, run tail recorded at execution):

- AuditChain: P1 25,000 (500x50) + P2 200 chains x exhaustive k (~5,000 chains avg 25.5 => ~127,500 positions x2 verify variants) + P2b 50 + P3 300x29x300 shuffled candidates + P3b 2 + P4 75,000 (500x50x3) + P4b 120.
- JCS: J1/J2/J3 1,000 seeded structures + J4a 9 + J4b 13 + J4c 2,000 + J4d 1.
