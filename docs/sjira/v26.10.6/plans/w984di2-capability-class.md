# W984di2 — CapabilityClass retirement candidate (report-only, C23 discipline)

- **Lane**: W984di2 (verify-only; NO code changes, NO commit)
- **Date**: 2026-10-07
- **Subject**: `/Users/sac/xaas` @ branch `feat/playwright-surface` @ `56325fa5`
- **Origin**: W984cy4 (gov-73) finding — `Xaas.Governance.Types.CapabilityClass` dead vocabulary
- **Standing**: VERIFIED (finding confirmed, with one scope correction to W984cy4)
- **Mode**: report-only. Product change deferred to owner lane per C23 retirement discipline.

## Verification evidence (commands run on live tree, 2026-10-07)

1. `grep -rn "CapabilityClass|capability_class" lib test priv e2e config`:
   - Module definition: `lib/xaas/governance/types/capability_class.ex` (3 lines,
     `use Ash.Type.Enum, values: [:observe, :select, :construct, :do]`).
   - **Code consumers: ZERO.** No resource attribute, DSL call, or runtime code anywhere in
     `lib/`, `test/`, `priv/`, `e2e/` references the module or binds the `:capability_class`
     custom type name.
2. `grep -rn "Governance.Types" lib test priv config`:
   - **Scope correction to W984cy4**: the module is not merely unreferenced — it is
     *registered-but-unused*. `config/config.exs:204` registers
     `capability_class: Xaas.Governance.Types.CapabilityClass` in Ash `custom_types`,
     alongside 18 sibling governance enums. But no resource ever uses the custom type
     name `:capability_class`: the only semantic consumer,
     `lib/xaas/graphlaw/capability.ex:30`, binds **bare `:atom` with
     `constraints: [one_of: [:observe, :select, :construct, :do]]`**, duplicating the
     enum inline. The registration is dead wiring.
3. Tests: `test/xaas/graphlaw_deepening_test.exs` (SPEC-09 courts, W912) exercise the
   bare-`:atom` attribute and its `one_of` constraint; they never touch the module.
   No test imports the module.
4. Migration `priv/repo/migrations/20261007210000_add_capability_class_to_graphlaw_capabilities.exs`
   adds the DB column backing the graphlaw attribute — stored via `:atom`, not the module.
   Historical migration; untouched by the retirement.

## Cross-check: ontology / TTL (graph-change question)

- `ontology.ttl` (repo root, lines 45-46) declares **`xar:capabilityClass`** — an
  `owl:DatatypeProperty` (`xsd:string`, values "Do"/"Select"/"Construct"/"Observe") on
  `xar:RenderTarget` individuals, sourced from `platform-console-capabilities.ttl`. This is
  **ggen render-target vocabulary, unrelated to the Elixir module**: no generator emits or
  consumes `Xaas.Governance.Types.CapabilityClass` from the graph.
- `priv/semantic/` (airo/, generated/: `castle_bridge_shacl.ttl`, `MANIFEST.json`) and
  `priv/packs/` carry no `CapabilityClass` bindings.
- **Conclusion: retirement is a file deletion + config-line removal + doc fix — NOT a
  graph change.** No TTL edit required.

## Related stale doc

`docs/claude/diataxis/reference/ash-configuration.md:47,55` documents the module and the
`custom_types` registration — stale-on-landing documentation of the dead wiring; the owner
lane must update it alongside the deletion.

## Retirement plan (owner-lane diff, NOT applied by this lane)

1. **Delete module file**: `lib/xaas/governance/types/capability_class.ex`
2. **Remove config registration**: `config/config.exs` `custom_types` line 204 —
   the entry `capability_class: Xaas.Governance.Types.CapabilityClass,`
3. **Update docs**: `docs/claude/diataxis/reference/ash-configuration.md` — remove the
   `capability_class:` line from the config snippet (~line 47) and the table row (~line 55)
   that cite the module. Note there that `Xaas.Graphlaw.Capability` binds `capability_class`
   as bare `:atom` with an inline `one_of` constraint (the living enum), which is a separate
   later decision: adopt the custom type there, or keep the inline constraint.
4. **No TTL/graph change**: `xar:capabilityClass` in `ontology.ttl` is unrelated
   (ggen render-target datatype property, string range) — leave untouched.
5. **No migration change**: the graphlaw migration only adds a column; historical.

## Tests unaffected (verified)

- `test/xaas/graphlaw_deepening_test.exs` SPEC-09 courts (W912) assert on the bare-`:atom`
  attribute + `one_of` constraint, never the module. No test imports the module.
- Chicago discipline: no mocks involved; the retirement diff removes only dead wiring.

## Falsifier for this finding

Any one of the following, if found, would overturn "dead vocabulary":
- a resource attribute binding the custom type name `:capability_class`;
- a direct module reference (`Xaas.Governance.Types.CapabilityClass`) outside
  `config/config.exs` and `docs/`;
- a TTL that generates the module.
None exist (verified 2026-10-07 @ `56325fa5`).

## Standing

- Finding: **VERIFIED** — module is dead vocabulary: registered-but-unused dead wiring in
  `config/config.exs:204`; zero resource/DSL/runtime consumers; graphlaw binds bare `:atom`.
- Retirement: **PENDING-OWNER** — report-only lane; deletion is a product change for the
  governance-surface owner lane under C23 discipline. This lane made no code change.
