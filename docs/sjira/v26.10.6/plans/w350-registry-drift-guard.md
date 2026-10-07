# W350 — Generated-Registry Drift Guard (_CLOSURE_PLAN.md §1 row 17)

**Subject**: /Users/sac/xaas @ feat/playwright-surface, working tree (uncommitted, test-only diff)
**Contract**: only `test/xaas/generated/registry_drift_guard_test.exs` + this receipt; zero lib/ changes.

## Form chosen: sha256 digest pin (weaker form)

Why not in-test regeneration: the named generators for all six files are
external — `mix ggen_igniter.sync` against
`priv/packs/xaas_zcode_ocel_pack` (for `zcode_event_registry.ex`) and
ggen-marketplace packs (`sa2a-bridge-pack`, `xaas-castle-bridge-pack`, ggen_igniter
renderer) for the bridge files. In-test regeneration requires the external
ggen_igniter toolchain + pack dirs outside the repo; too heavy/unsafe in-test,
so the digest form is used per task instruction.

Weakness (documented per task): a digest pin detects any drift of the
committed file (hand-edit, accidental regen), but does NOT prove the file
matches its ontology/pack source. That check (real regeneration + compare)
remains the open CI leg — coordinator work (P2-2 CI leg).

## Coverage

All six generated `.ex` files under `lib/xaas/generated/`:
zcode_event_registry.ex, sa2a_bridge_contract.ex, sa2a_bridge_edges.ex,
sa2a_mcp_descriptor.ex, castle_bridge_contract.ex, castle_bridge_edges.ex
(scope asked for zcode registry + sa2a_bridge_*.ex; castle files and the
sa2a MCP descriptor included at no extra cost — same idiom, same digest form).

## Verification (real output)

1. Initial run failed: `:crypto.hash/2` argument-order bug in the test itself
   (`not an iodata term`) — session-introduced, fixed with `then/2`.
2. Green run:
```
Result: 1 passed
Finished in 0.03 seconds (0.03s async, 0.00s sync)
```
3. Non-vacuity probe: corrupted the zcode_event_registry digest to all-zeros
   in-test -> `0/1 passed, Failed: 1` with the DRIFT message naming the file,
   expected vs actual sha256, and the regen command; digests restored, green again.
4. No re-hash was needed (tree not dirty under these six files mid-campaign).

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW350` — **DENIED by permission system**
(twice: combined with test run, and standalone). Lane build root
`/Users/sac/xaas/_build-laneW350` (~cold-build, test env) REMAINS ON DISK.
Per same-checkout-fanout cleanup law this is an incomplete integration:
coordinator must delete `_build-laneW350` at integration.

## Row-17 verdict

**Local gate landed.** CI leg (real regeneration compared against disk in CI)
still open — coordinator work.
