# W378 — REFUSED_VKG_EMPTY_CATALOG anti-vacuity (W320 gap 1)

## Outcome: (b) typed structural unreachability — no kill test written

## Call-graph analysis

Target: `[] -> {:error, :REFUSED_VKG_EMPTY_CATALOG}` at lib/xaas/semantics/vkg.ex:52,
the `with`-`else` handler of `observe_all/1` (vkg.ex:38-55).

Public entries of Xaas.Semantics.VKG: observe/2 (two heads), observe_all/1,
engineering/1, graphql/2, catalog/1, catalog_snapshot/1, encode_witness!/1,
verify/1. Only `observe_all/1` binds `ids` through the `ids when ids != []` guard
(vkg.ex:40); the :52 clause is precisely the else clause matching the raw value
`[]` when that guard fails. So the clause is reachable iff `Catalog.ids(catalog)`
can return `[]` for a catalog yielded as `{:ok, catalog}` by
`Runtime.catalog/1`.

Call graph to the guard's input:

- `Runtime.catalog(root)` = `AshR2RML.VKG.Catalog.load(root)`
  (deps/ash_r2rml/lib/ash_r2rml/vkg/catalog.ex:19)
- `Catalog.load` = `Manifest.load_all(root)` → `Registry.admit(contracts)`
- `Manifest.load_all/1` on an empty/invalid sources dir refuses
  (`REFUSED_VKG_MANIFEST`); a successful load returns a non-empty contract
  list, and even if it returned `[]`, `Registry.admit/1` refuses `[]` outright:
  deps/ash_r2rml/lib/ash_r2rml/vkg/registry.ex:25 —
  `def admit([]), do: refusal(:contracts, "VKG registry requires at least one contract", %{})`
- `Catalog.ids/1` (catalog.ex:77) = `Map.keys(registry.contracts)`; a
  non-empty contract list admits to a non-empty registry map, so `ids/1` on an
  admitted catalog always returns a non-empty, sorted list.

Therefore the guard `ids when ids != []` can never fail with `[]` on any value
reaching it through a public entry: the clause at :52 is dead defensive code.
The manifest-layer refusal (`REFUSED_VKG_MANIFEST`) is the real fail-closed edge
for the empty-root input, already asserted by the pre-existing test in
test/xaas/semantics/vkg_refusal_negative_test.exs.

## Action taken

- No fake kill test written (contract forbids constructing an input through a
  private seam; no real input reaches :52).
- Test file comment updated (test-only edit) to replace the loose
  "currently shielded" note with the full structural proof so the dead clause's
  status is machine-greppable and carries its evidence inline.
- lib decision — delete the `[] ->` clause (and then the guard can also drop to
  a plain binding) or feed it from a guard-reform — is an operator/next-cycle
  call, per contract (NO lib/ edits).

## Verification

Command:

    PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW378 \
      mix test test/xaas/semantics/vkg_refusal_negative_test.exs

Actual run tail (exit 0):

    Finished in 0.4 seconds (0.4s async, 0.00s sync)
    Result: 3 passed

3 tests, 0 failures (the 3 pre-existing tests; comment-only edit to the
empty-catalog describe). Kill-verification runs: N/A — outcome (b), no mutant
constructed.

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW378` was DENIED by the permission system
(2026-10-06). Build root left in place; ~1 GB class, coordinator may remove it
at integration per the lane-lease cleanup law.

(recorded after run)
