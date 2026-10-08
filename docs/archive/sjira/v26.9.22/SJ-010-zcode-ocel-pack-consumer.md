---
{
  "identity": "SJ-010",
  "title": "zcode-ocel-pack gets a real consumer",
  "description": "Successor of v26.9.21 SJ-002 (UNSUPPORTED there). Wire Xaas.Telemetry.OcelAshEmitter (lib/xaas/telemetry/ocel_ash_emitter.ex) to the zcode-ocel-pack generated registry so xaas-emitted OCEL validates against the zcode-generated schema. Today the two vocabularies are fully disjoint and there are zero cross-repo reads: the emitter hand-shapes \"<resource_short_name>.<action>\" event types and Ash-short-name object types, validated only by the xaas-local court Xaas.Ultracode.Ocel.Validator.",
  "subject": "zcode-ocel-pack-consumer",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "2d229c272c3a02dcb8e75ff600ea0a4edc058d71",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.22-sj-010",
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
    "a generated ocel registry module is rendered into xaas via ggen sync from the zcode-ocel-pack",
    "OcelAshEmitter declares event/object types from the generated registry, not hand-listed strings",
    "differential test: an emitted ash-actions event passes the generated-schema validator",
    "a test asserts an unknown event type is refused"
  ],
  "falsifiers": [
    "emitter accepts an event type absent from the generated registry",
    "an emitted event passes the xaas court but is rejected by the zcode-generated schema"
  ],
  "projections": [
    "jira",
    "machine",
    "verification",
    "receipt"
  ],
  "dependencies": [
    {
      "upstream": "zcode-cli gall-work landed on main (2026-09-22)",
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

# SJ-010: zcode-ocel-pack gets a real consumer

- **Standing**: UNKNOWN

## Status
UNKNOWN
- **Repository**: seanchatmangpt/xaas @ `2d229c2`

## Description
Successor of v26.9.21 SJ-002 (UNSUPPORTED there). Wire Xaas.Telemetry.OcelAshEmitter (lib/xaas/telemetry/ocel_ash_emitter.ex) to the zcode-ocel-pack generated registry so xaas-emitted OCEL validates against the zcode-generated schema. Today the two vocabularies are fully disjoint and there are zero cross-repo reads: the emitter hand-shapes `"<resource_short_name>.<action>"` event types and Ash-short-name object types, validated only by the xaas-local court `Xaas.Ultracode.Ocel.Validator`.

## Evidence
- emitter's vocabulary is xaas-local and hand-listed: event type `"<resource_short_name>.<action>"`, object types `resource/actor/tenant` short names (`lib/xaas/telemetry/ocel_ash_emitter.ex:452-520`)
- zero references to the zcode-ocel-pack generated registry under `lib/` or `test/` (v26.9.21 SJ-002 grep, still true at base `2d229c2`)
- `lib/xaas/generated/` holds only sa2a bridge modules; no ocel registry

## Definition of done
- [ ] a generated ocel registry module is rendered into xaas via ggen sync from the zcode-ocel-pack
- [ ] OcelAshEmitter declares event/object types from the generated registry, not hand-listed strings
- [ ] differential test: an emitted ash-actions event passes the generated-schema validator
- [ ] a test asserts an unknown event type is refused

Runnable check:

```sh
cd ~/xaas && ggen sync && mix test test/xaas/telemetry
```

## Falsifiers
- emitter accepts an event type absent from the generated registry
- an emitted event passes the xaas court but is rejected by the zcode-generated schema
