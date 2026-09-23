---
{
  "identity": "SJ-012",
  "title": "Admit the ash_atlassian SHACL application profile",
  "description": "Admit the ARD section 4 SHACL application profile over the SJ-010-pinned public classes (oslc_cm:ChangeRequest, doap:Project, sioc:Space, sioc:Post, schema:Comment, foaf:Person) into the family's designated profile surface: six NodeShapes targeting public classes, datatype property shapes per the ARD section 4 table, enum-valued oslc_cm:status/oslc_cm:priority via the SJ-011 enum projection. Gates 010/020 green; ggen sync renders mix ash.gen.* commands with AshAtlassian.* modules from the consumer-namespace fact.",
  "subject": "ash-atlassian-profile-admit",
  "repository": "seanchatmangpt/ggen-marketplace",
  "base_sha": "f1c350b0b1dc732eb4d01cc5b66f186a6840849d",
  "standing": "UNKNOWN",
  "evidence_ceiling": "EXECUTED_VERIFIED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-012",
  "required_courts": [
    "tests"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "profile admitted in exactly one family profile surface with gates 010_no_custom_vocabulary and 020_public_target_classes passing",
    "ggen sync renders ash.gen.resource commands with AshAtlassian.* module names in the pack's declared output file",
    "no local owl:Class/rdf:Property appears anywhere in the admitted graph"
  ],
  "falsifiers": [
    "profile declares any local owl:Class or rdf:Property",
    "ggen sync output is a hand-editable resource file instead of generator commands"
  ],
  "projections": [
    "jira",
    "ard",
    "verification",
    "receipt"
  ],
  "dependencies": [
    {
      "upstream": "SJ-010",
      "type": "requiresReceipt"
    },
    {
      "upstream": "SJ-011",
      "type": "requiresReceipt"
    }
  ],
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

# SJ-012: Admit the ash_atlassian SHACL application profile

- **Standing**: UNKNOWN

## Status
UNKNOWN
- **Repository**: seanchatmangpt/ggen-marketplace @ `f1c350b`

## Description
Admit the ARD section 4 SHACL application profile over the SJ-010-pinned public classes (oslc_cm:ChangeRequest, doap:Project, sioc:Space, sioc:Post, schema:Comment, foaf:Person) into the family's designated profile surface: six NodeShapes targeting public classes, datatype property shapes per the ARD section 4 table, enum-valued oslc_cm:status/oslc_cm:priority via the SJ-011 enum projection. Gates 010/020 green; ggen sync renders mix ash.gen.* commands with AshAtlassian.* modules from the consumer-namespace fact.

- ARD §4 lists six public target classes with datatype paths (docs/sjira/v26.9.21/ash-atlassian-ard.md)
- xaas-ash-core-pack/profiles/public-shapes.ttl is empty on purpose awaiting admitted public mappings

## Definition of done
- [ ] profile admitted in exactly one family profile surface with gates 010_no_custom_vocabulary and 020_public_target_classes passing
- [ ] ggen sync renders ash.gen.resource commands with AshAtlassian.* module names in the pack's declared output file
- [ ] no local owl:Class/rdf:Property appears anywhere in the admitted graph

Runnable check:

```sh
cd ~/ggen-marketplace && ggen sync && grep -q 'ash.gen.resource' packs/xaas-public-ash-projection-pack/xaas-public-ash-GENERATED.sh && grep -q 'AshAtlassian' packs/xaas-public-ash-projection-pack/xaas-public-ash-GENERATED.sh
```

## Falsifiers
- profile declares any local owl:Class or rdf:Property
- ggen sync output is a hand-editable resource file instead of generator commands
