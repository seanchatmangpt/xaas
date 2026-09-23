---
{
  "identity": "SJ-011",
  "title": "Extend the public-ash projection family (namespace, enums, relationships)",
  "description": "The public-ash projection family (xaas-public-ash-projection-pack + xaas-ash-core-pack) hard-binds module/domain to Xaas.Public (queries/ash-gen-commands.rq BIND lines), projects no sh:in enums, and fails closed on all object properties. Extend the family per ARD section 6 failed edges e1-e3: consumer-declared namespace derivation as a ggen.toml generation fact (never RDF vocabulary), sh:in-constrained string shapes rendered through mix ash.gen.enum, and object-property -> relationship projection admitted only behind an explicit profile fact (fail-closed default unchanged). Add pack tests (pytest, ash-revops-structural-factory-pack pattern).",
  "subject": "public-ash-projection-extend",
  "repository": "seanchatmangpt/ggen-marketplace",
  "base_sha": "f1c350b0b1dc732eb4d01cc5b66f186a6840849d",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-011",
  "required_courts": [
    "tests"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "namespace fact drives module/domain derivation with pack tests; no Xaas.Public hard-bind remains",
    "sh:in string shapes render mix ash.gen.enum plus enum-typed attributes",
    "relationship projection fires only behind an explicit admitted profile fact; default unchanged",
    "family gates 010/020/030/040/050/060 still pass on existing fixtures"
  ],
  "falsifiers": [
    "template renders .ex files directly instead of ash.gen.* commands",
    "namespace fact lands in RDF as local vocabulary (gate 010 violation)",
    "object properties project without an explicit admission fact"
  ],
  "projections": [
    "jira",
    "machine",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "packs/xaas-public-ash-projection-pack/**",
    "packs/xaas-ash-core-pack/**"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-011: Extend the public-ash projection family (namespace, enums, relationships)

- **Standing**: UNKNOWN

## Status
UNKNOWN
- **Repository**: seanchatmangpt/ggen-marketplace @ `f1c350b`

## Description
The public-ash projection family (xaas-public-ash-projection-pack + xaas-ash-core-pack) hard-binds module/domain to Xaas.Public (queries/ash-gen-commands.rq BIND lines), projects no sh:in enums, and fails closed on all object properties. Extend the family per ARD section 6 failed edges e1-e3: consumer-declared namespace derivation as a ggen.toml generation fact (never RDF vocabulary), sh:in-constrained string shapes rendered through mix ash.gen.enum, and object-property -> relationship projection admitted only behind an explicit profile fact (fail-closed default unchanged). Add pack tests (pytest, ash-revops-structural-factory-pack pattern).

## Evidence
- both packs' queries/ash-gen-commands.rq BIND CONCAT("Xaas.Public.") and domain "Xaas.Public" (projection pack line 17, core pack line 15; verified 2026-09-21)
- gates/060_object_property_projection_pending.rq exists; pack README keeps relationship projection fail-closed
- xaas-public-ash-projection-pack has no tests/ directory; xaas-ash-core-pack/tests holds only test_public_projection_adapter.py (verified 2026-09-21)

## Definition of done
- [ ] namespace fact drives module/domain derivation with pack tests; no Xaas.Public hard-bind remains
- [ ] sh:in string shapes render mix ash.gen.enum plus enum-typed attributes
- [ ] relationship projection fires only behind an explicit admitted profile fact; default unchanged
- [ ] family gates 010/020/030/040/050/060 still pass on existing fixtures

Runnable check:

```sh
cd ~/ggen-marketplace && python3 -m pytest packs/xaas-public-ash-projection-pack/tests -q && ggen sync
```

## Falsifiers
- template renders .ex files directly instead of ash.gen.* commands
- namespace fact lands in RDF as local vocabulary (gate 010 violation)
- object properties project without an explicit admission fact
