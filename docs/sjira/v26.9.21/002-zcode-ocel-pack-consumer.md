---
{
  "identity": "SJ-002",
  "title": "zcode-ocel-pack gets a real consumer",
  "description": "ggen_igniter renders `zcode-ocel-pack` constants (OBJECT_TYPES/EVENT_TYPES/PRIMARY_OBJECT/QUALIFIERS/TRANSITIONS) but neither xaas nor autofde-lab references them. Wire xaas's zcode plugin/OCEL emission (Xaas.Telemetry.OcelAshEmitter, priv/zcode_plugin) to the generated registry so event types are generated, not hand-listed.",
  "subject": "zcode-ocel-pack-consumer",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "8e72cfcb85bd901ad067589295598eb7580a1442",
  "standing": "UNSUPPORTED",
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

- **Standing**: UNSUPPORTED
- **Repository**: seanchatmangpt/xaas @ `8e72cfc`

## Description
ggen_igniter renders `zcode-ocel-pack` constants (OBJECT_TYPES/EVENT_TYPES/PRIMARY_OBJECT/QUALIFIERS/TRANSITIONS) but neither xaas nor autofde-lab references them. Wire xaas's zcode plugin/OCEL emission (Xaas.Telemetry.OcelAshEmitter, priv/zcode_plugin) to the generated registry so event types are generated, not hand-listed.

## Evidence
- `grep -rn 'zcode-ocel-pack' lib test ~/autofde-lab/src` -> zero matches (verified 2026-09-21)

## Definition of done
- [ ] a generated ocel registry module is rendered into xaas via ggen sync
- [ ] OcelAshEmitter/zcode plugin validate event types against it
- [ ] a test asserts an unknown event type is refused

Runnable check:

```sh
cd ~/xaas && ggen sync && mix test test/xaas/telemetry
```

## Falsifiers
- emitter accepts an event type absent from the generated registry
