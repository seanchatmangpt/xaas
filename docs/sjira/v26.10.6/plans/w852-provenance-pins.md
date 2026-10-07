# W852 — Provenance-Only Surface Pins (registry drift guard extension)

Lane W852, branch `feat/playwright-surface`, HEAD a0723bf6. Closes backlog item 1 of
`w849-generated-surface-census.md`. No generated file edited; only the guard's sha map
extended.

## Change

`test/xaas/generated/registry_drift_guard_test.exs`: keys of `@regen_commands` /
`@expected_sha256` moved from bare filenames to repo-relative paths (required — the new
surfaces live outside `lib/xaas/generated/`); 4 entries added, mirroring the existing
structure and failure message exactly. Failure message now states the pin is hand-edit
detection only, per the W849 finding that sha pins do not prove ontology conformance.

## Pins added (sha256 of current bytes at HEAD a0723bf6)

| Surface | sha256 | Regen |
|---|---|---|
| `lib/xaas_web/mcp_scope.ex` | `51d9d7cbf83d5aa7ef91f727e3a1d8283ed8e51047fe7867637ee85ca99b3780` | ggen_igniter from `priv/ggen_igniter/mcp_a2a/xaas-surface.ttl` (W849 backlog 3: regen command not in pack-dir form) |
| `lib/mix/tasks/xaas.library.manufacture.ex` | `5796cae051757de949bc543f20564809f0e453dd4916eeac7e94beb71c56eb21` | `mix ggen_igniter.sync --pack-dir priv/packs/xaas_library_pack` |
| `lib/xaas/generated/capital_census/facts.ex` | `be12c29a29b2e32335de0a46757574f6575e4614825c1936e1e200ff928070c4` | `mix ggen_igniter.sync --pack-dir priv/ggen/ultracode-self-digest-pack --template templates/facts.ex.eex --yes` |
| `lib/xaas/telemetry/ocel_envelope.ex` | `16757701865686d1087879c4f4745e83e3c0f9a3364bce03e052f8762a181e77` | `mix ggen_igniter.sync --pack-dir priv/packs/xaas_telemetry_pack --template .../ocel_envelope.ex.eex --out lib/xaas/telemetry/ocel_envelope.ex` |

## Counts

- Before: 6 pinned surfaces (guard), census 8 DRIFT-CHECKED / 4 PROVENANCE-ONLY.
- After: 10 pinned surfaces; the 4 PROVENANCE-ONLY surfaces are now pin-DRIFT-CHECKED
  (0 PROVENANCE-ONLY remain; census entry 9's regen-form normalization is W849 backlog 3,
  still open).

## Verification (real tails)

Run 1 (fresh lane build root `_build-laneW852`, full dep compile):
```
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 1 passed
[exited with code 0]
```
Run 2 (warm):
```
Finished in 0.02 seconds (0.02s async, 0.00s sync)
Result: 1 passed
```

## Mutation rationale (documented, not executed — cheap to run if needed)

Edit one byte of any pinned file, e.g. append a comment to `lib/xaas/telemetry/ocel_envelope.ex`,
then rerun the guard. The single `for`-loop assert at
`test/xaas/generated/registry_drift_guard_test.exs` ("every generated registry file matches
its pinned sha256", the `assert actual == expected` inside the loop) fails exactly once,
naming the edited path in the `GENERATED-REGISTRY DRIFT: <rel_path>` message with
expected/actual sha256. Because the loop iterates `@expected_sha256` and only one file's
hash changes, exactly one failure naming that file occurs; the key-set equality assert
(`MapSet.new` of the two map keys) is unaffected. Same holds for all 10 entries — the
mutation result is file-independent by construction.

## Standing

- Guard extension: ALIVE on HEAD a0723bf6 (2 real green runs).
- Pin semantics: hand-edit detection only; ontology-conformance regen leg remains P2-2
  (W849 backlog 2), open.
- Lane build root `_build-laneW852`: deletion attempted but denied by session permissions;
  left in place for coordinator cleanup per lane contract fallback.
