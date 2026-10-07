# W658d — W705 census tripwire fix (lane receipt)

Lane: W658d, campaign v26.10.6. Subject: `/Users/sac/xaas` @ `feat/playwright-surface`,
working tree (uncommitted, lane-contract files only), build root `_build-laneW658d`.

## Diagnoses (W647's two findings, re-derived on this tree)

### 1. Census tripwire path

`find lib -name '*circuit*'`:
- `lib/xaas/runtime/fond/circuit.ex` — `Xaas.Runtime.FOND.Circuit` (the W705 census site)
- `lib/xaas/runtime/provider_fabric/circuit.ex` — `Xaas.Runtime.ProviderFabric.Circuit` (unrelated sibling, not a census site)
- `lib/xaas/ultracode/provider_mesh/circuit_breaker.ex` — unrelated

The real path IS `lib/xaas/runtime/fond/circuit.ex` (verified on disk and by
`Xaas.Runtime.FOND.Circuit.module_info(:module)` in the tripwire test). Both
on-disk census test files (`test/xaas/w705_map_update_dual_safe_test.exs`,
`test/xaas/semantics/map_update_dual_safe_test.exs`) already carry the correct
path; W647's "wrong path" finding does not reproduce on the current tree —
no lib edit was needed or made.

### 2. `Xaas.Gall.Turtle.from_turtle/1` → `{:refused, :refused_authority}`

Read of `lib/xaas/gall/turtle.ex` + `lib/xaas/gall/checkpoint.ex`:
`from_turtle/1` takes ONLY the TTL text — there is no authority-context
argument to supply. `{:refused, :refused_authority}` is an admission refusal
from `Xaas.Gall.Checkpoint.new/1`, produced by `require_fields/1`
(`@required_fields = [:identity, :class, :repository, :base_sha, :goal,
:verifier, :standing]`), `validate_identity/1` (must be
`urn:gall:checkpoint:<repo>:<id>` with both segments non-empty),
`validate_standing/1`, or `validate_string_lists/1`. The module's own tests
(`test/xaas/gall/turtle_test.exs`, `@canonical_ttl`) show the idiom: feed the
full PRD reference TTL form — repository IRI `urn:repo:seanchatmangpt:xaas`
(trailing segment matching the identity's repo segment), verifier as the FULL
known-verifier IRI `https://semantic-a2a.dev/gall#XaasChicagoCourt`, standing
in the vocabulary — and the parse admits `{:ok, %Xaas.Gall.Checkpoint{}}`.

## Diff

One new file: `test/xaas/map_update_dual_safe_test.exs` (lane-contract path;
preserves W705's dual-safe pins — canaries, FOND.Circuit
fail/open?/reset threshold boundary, Fabric.Planes.Process :observe
absent-key seed — plus the census tripwire pinned to the verified real path
and a real-parse `from_turtle/1` pin with an admission-valid TTL, including
a typed-refusal negative control). No lib/ changes.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW658d \
  mix test test/xaas/map_update_dual_safe_test.exs   # Result: 9 passed
# second run                                          # Result: 9 passed
```

Also run (pre-existing, untouched by this lane):
`test/xaas/semantics/map_update_dual_safe_test.exs` +
`test/xaas/w705_map_update_dual_safe_test.exs` → 13 passed, 0 failures
(so W647's findings were already remediated on-disk by W659's lib patches
plus these files; W658d's file makes the corrected tripwire stand alone at
the contract path).

Standing: ALIVE (focused file, exact commands, green ×2 on this tree).
