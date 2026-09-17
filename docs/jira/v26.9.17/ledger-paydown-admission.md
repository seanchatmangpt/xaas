# Ledger Paydown Admission — turn the wave's hand-writes into packs (比: 0% → rising)

## Summary

The wave's honest 比 is 0% manufactured (78 産面 insertions, all hand-written;
fail-closed count in `ledger-closure.md`). The paydown plan already names the
admissions; this ticket executes them so future drift renders manufactured
instead of accumulating HANDWRITTEN.md rows.

## Status

Queued / Not Started (agent work; marketplace + ggen_igniter surfaces).

## Scope

1. **Admit `zcode-plugin-pack`** — the blocker ("ZCode-side install bug") is
   now SOLVED and proven (commit `2f49261`: user_config token, manifest
   default, `plugins configure` persistence; install+discovery witnessed).
   Promote `priv/templates/zcode_plugin/` + `lib/mix/tasks/xaas.gen_zcode_plugin.ex`
   into the marketplace pack (pack.toml + SemVer + description + RDF source +
   gates) per the admission checklist; xaas then consumes it as a dependency
   and the projection renders from the pack.
2. **Admit `ultracode-actuation-lease-pack`** — lease kernel + admission
   court shapes are proven (13 lease tripwire tests green); encode the
   ontology facts + gates so lease-surface changes render.
3. **Extend `mcp-surface-pack`** — the execution-fabric MCP tool surface
   (6 tools, JSON-RPC over streamable HTTP, bearer gate semantics) as a
   transport fact in the existing family (EXTEND, not INVENT).
4. Update `HANDWRITTEN.md`: rows move from open to owner-pack-paid as each
   admission lands; ledger must shrink monotonically with this milestone.
5. Re-render + re-verify each projection after admission (ggen court:
   `just pre-commit`).

## Key Invariant(s)

- Marketplace admission is the only path (loose files are contract
  violations); each pack gets SemVer + RDF source + gates.
- Ledger shrinks; growth requires a paydown plan in the same change.

## Relationship to Existing Work

- `ledger-closure.md` (比 computation + this plan verbatim);
  `wave1-07-priorart.md` (the ladder verdict: EXTEND mcp-surface-pack +
  INVENT-admit zcode-plugin-pack — already the recorded decision).

## Falsifiers / What Would Defeat This

- An admitted pack whose render diverges from the proven working tree
  (projection ≠ witnessed state).
- HANDWRITTEN.md rows closing without their owner pack admitted (decorative
  paydown).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | queued | marketplace (~/ggen-marketplace) + xaas @ 6ff1a32 | 比 0% (78/78 hand-written, fail-closed) | 3 admissions → ledger shrink → re-render courts |
