---
{
  "identity": "SJ-002",
  "title": "zcode-ocel-pack gets a real consumer",
  "description": "ggen_igniter renders `zcode-ocel-pack` constants (OBJECT_TYPES/EVENT_TYPES/PRIMARY_OBJECT/QUALIFIERS/TRANSITIONS) but neither xaas nor autofde-lab references them. Wire xaas's zcode plugin/OCEL emission (Xaas.Telemetry.OcelAshEmitter, priv/zcode_plugin) to the generated registry so event types are generated, not hand-listed.",
  "subject": "zcode-ocel-pack-consumer",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "PARTIAL_ALIVE",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-002",
  "required_courts": [
    "compile",
    "tests",
    "chicago_no_mocks"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "a generated ocel registry module is rendered into xaas via ggen sync",
    "OcelAshEmitter/zcode plugin validate event types against it",
    "a test asserts an unknown event type is refused"
  ],
  "falsifiers": [
    "emitter accepts an event type absent from the generated registry"
  ],
  "projections": [
    "jira",
    "machine",
    "verification",
    "receipt"
  ],
  "dependencies": [
    {
      "upstream": "SJ-001",
      "type": "requiresReceipt"
    }
  ],
  "authority_requirement": "NONE",
  "path_scope": [
    "lib/xaas/generated/**",
    "lib/xaas/telemetry/**",
    "priv/zcode_plugin/**",
    "ontology/**"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-002: zcode-ocel-pack gets a real consumer

- **Standing**: PARTIAL_ALIVE

## Status
PARTIAL_ALIVE (2026-09-22, branch `sjira/sj-002`, base_sha `8e72cfc`, worktree
`/Users/sac/xaas/worktrees/sjira/sj-002`)
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
ggen_igniter renders `zcode-ocel-pack` constants (OBJECT_TYPES/EVENT_TYPES/PRIMARY_OBJECT/QUALIFIERS/TRANSITIONS) but neither xaas nor autofde-lab references them. Wire xaas's zcode plugin/OCEL emission (Xaas.Telemetry.OcelAshEmitter, priv/zcode_plugin) to the generated registry so event types are generated, not hand-listed.

## Evidence (2026-09-22, real commands, real output)

`~/ggen_igniter/priv/ggen/zcode-ocel-pack` only ships a TypeScript template
(`templates/registry.ts.eex`) -- there was no Elixir-rendering pack anywhere
that xaas could consume directly. xaas already has a working, prior-art
pattern for this exact shape of problem (`priv/packs/xaas_telemetry_pack` ->
`lib/xaas/telemetry/ocel_envelope.ex`, ontology + SPARQL queries + EEx
template rendered via `mix ggen_igniter.sync --pack-dir`). This ticket adds a
new pack in that same idiom, `priv/packs/xaas_zcode_ocel_pack/`, vendoring
(re-namespaced `xz:`, individuals byte-identical) the same event/object-type
individuals as `~/ggen_igniter/priv/ggen/zcode-ocel-pack/ontology.ttl`.

1. `mix deps.get` (worktree had no `deps/`; symlinked from the main checkout,
   same `mix.lock`) -- exit 0.
2. `rm _build && mix compile` (own `_build`, not shared with the main
   checkout, to avoid concurrent-writer corruption) -- `Generated xaas app`,
   exit 0.
3. Real `ggen_igniter.sync` run (real oxigraph SPARQL engine, real subprocess,
   real file write, real `.ggen_igniter/receipts/2026-09-22.jsonl` entry with
   `"standing":"alive"`, `"outcome":"written"`):
   ```
   mix ggen_igniter.sync --pack-dir priv/packs/xaas_zcode_ocel_pack \
     --query event_types=priv/packs/xaas_zcode_ocel_pack/queries/010_event_types.rq \
     --query object_types=priv/packs/xaas_zcode_ocel_pack/queries/020_object_types.rq \
     --query qualifiers=priv/packs/xaas_zcode_ocel_pack/queries/030_qualifiers.rq \
     --query transitions=priv/packs/xaas_zcode_ocel_pack/queries/040_transitions.rq \
     --template priv/packs/xaas_zcode_ocel_pack/templates/zcode_event_registry.ex.eex \
     --out lib/xaas/generated/zcode_event_registry.ex
   ```
   Output: `ggen_igniter: wrote lib/xaas/generated/zcode_event_registry.ex
   (engine: oxigraph, 4 queries, 63 total row(s)) (via reactor)` -- exit 0.
   This renders the full 15-event/7-object/26-qualifier/15-transition
   registry (`Xaas.Generated.ZcodeEventRegistry`) -- generated, not
   hand-listed.
4. `mix test test/xaas/telemetry/zcode_ocel_validator_test.exs` -- `6 tests,
   0 failures`, exit 0. Includes the falsifier test: an event type absent
   from the generated registry (`"HallucinatedEventType"`) is refused by both
   `ZcodeOcelValidator.validate_event_type/1` (`{:error,
   {:unknown_event_type, ...}}`) and `build_event/3`, and
   `validate_event_type!/1` raises `ArgumentError`.
5. `mix test test/xaas/telemetry` (ticket's own runnable check, updated to
   `mix test` since this worktree has no network access to run `ggen sync`
   against a live remote) -- `14 tests, 0 failures`, exit 0.
6. `grep -rn 'unittest.mock\|Mock(\|MagicMock\|patch(\|monkeypatch\|Mox\|:meck' test/xaas/telemetry/ lib/xaas/telemetry/zcode_ocel_validator.ex` ->
   zero matches (Chicago-style: real generated module, real MapSet
   membership, real raised exceptions, no test doubles).

### What was generated vs. hand-written
- **Generated** (via real `mix ggen_igniter.sync`, never hand-edited):
  `lib/xaas/generated/zcode_event_registry.ex` -- `object_types/0`,
  `event_types/0`, `primary_object/0`, `qualifiers/0`, `transitions/0`,
  `event_type?/1`, `object_type?/1`. Every one of these is a direct
  mechanical projection of `priv/packs/xaas_zcode_ocel_pack/ontology.ttl`'s
  individuals, rendered exactly like `xaas_telemetry_pack` already does for
  `ocel_envelope.ex`.
- **Hand-written** (the ticket's own carve-out: "only hand-write the
  validation glue"): `lib/xaas/telemetry/zcode_ocel_validator.ex` -- the
  accept/refuse *decision*, error-message shape, and `build_event/3`
  convenience constructor. None of these are derivable mechanically from the
  ontology; they are genuine business logic (what to do when the registry
  says "unknown").
- Also hand-written: the pack's `ontology.ttl` (a deliberate, disclosed
  vendored copy -- see its own header), 4 SPARQL query files, and the EEx
  template -- these are pack *authoring*, the same category of hand-written
  artifact `xaas_telemetry_pack`'s own ontology/queries/template already are
  in this repo; only the rendered `.ex` output is required to be generated.

### Remaining gap (why this is PARTIAL_ALIVE, not ALIVE)
The DoD's second bullet ("OcelAshEmitter/zcode plugin validate event types
against it") is only partly closed:
- `Xaas.Telemetry.OcelAshEmitter` emits Ash-action-domain OCEL events
  (`"ocel:activity" => "#{resource_short_name}.#{action}"`, e.g.
  `"Book.create"`) -- a genuinely different, dynamic vocabulary from the
  zcode agent-loop's fixed 15-event set this pack registers. Wiring
  `ZcodeOcelValidator` into `OcelAshEmitter`'s existing `build_ocel_event/3`
  would be a category error (it would refuse every real Ash action event,
  none of which are zcode loop events) -- confirmed by reading
  `lib/xaas/telemetry/ocel_ash_emitter.ex` in full, not assumed.
- `priv/zcode_plugin`'s two Node scripts (`xaas-gate.mjs`, `xaas-lease.mjs`)
  are JavaScript and do not currently emit or validate any OCEL event at
  all (confirmed: zero `ocel`/ event-type references in either file) --
  there is no existing zcode-loop OCEL emission call site in this repo to
  wire the new validator into yet. `Xaas.Telemetry.ZcodeOcelValidator` and
  `Xaas.Generated.ZcodeEventRegistry` are real, tested, and ready to be that
  call site's Elixir-side dependency the moment zcode-loop OCEL emission is
  actually built (a distinct, larger scope than this ticket's path_scope
  suggests it is -- that emission code does not exist anywhere in xaas
  today, Elixir or JS).
- No PR opened, no merge, no push -- per the agent protocol.

## Definition of done
- [x] a generated ocel registry module is rendered into xaas via ggen sync
- [~] a validator exists and is proven to validate event types against the
      generated registry (`Xaas.Telemetry.ZcodeOcelValidator`); it is not
      yet called from `OcelAshEmitter` or `priv/zcode_plugin` because
      neither currently emits zcode-loop-shaped OCEL events (see "Remaining
      gap" above)
- [x] a test asserts an unknown event type is refused
      (`test/xaas/telemetry/zcode_ocel_validator_test.exs`)

Runnable check:

```sh
cd ~/xaas/worktrees/sjira/sj-002 && mix test test/xaas/telemetry
```

(`ggen sync` here is `mix ggen_igniter.sync --pack-dir
priv/packs/xaas_zcode_ocel_pack ...` -- see Evidence step 3 for the exact
invocation; the bare `ggen sync` in the original runnable check refers to
the Rust `ggen` CLI's `priv/zcode_plugin/ggen.toml` project, a different,
unrelated pack (plugin manifest topology, not OCEL).)

## Falsifiers
- emitter accepts an event type absent from the generated registry --
  checked and refused: see Evidence step 4
  (`test/xaas/telemetry/zcode_ocel_validator_test.exs`, test "the falsifier
  this ticket names").
