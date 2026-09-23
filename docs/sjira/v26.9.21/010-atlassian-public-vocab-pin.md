---
{
  "identity": "SJ-010",
  "title": "Pin OSLC CM and SIOC public vocabularies",
  "description": "SJ-007's ARD (docs/sjira/v26.9.21/ash-atlassian-ard.md section 5) needs OSLC CM and SIOC pinned before any ash_atlassian profile shape can be admitted: batch 1 pinned oslc automation/config/rm only and sioc is absent. Pin both under ontologies/public/xaas-profile-batch-2/ following the batch-1 MANIFEST discipline: real retrieval (HTTP 200), bytes verified as RDF, SHA-256, publisher, and disclosed failures for anything not obtained.",
  "subject": "atlassian-public-vocab-pin",
  "repository": "seanchatmangpt/ggen-marketplace",
  "base_sha": "f1c350b0b1dc732eb4d01cc5b66f186a6840849d",
  "standing": "UNKNOWN",
  "evidence_ceiling": "OBSERVED",
  "promotion_rule": "verified_by_required_courts_then_receipted",
  "replay_identity": "sjira-v26.9.21-sj-010",
  "required_courts": [
    "tests"
  ],
  "required_evidence": [
    "command_exit_codes",
    "real_output"
  ],
  "acceptance": [
    "OSLC CM and SIOC vocabularies pinned under ontologies/public/xaas-profile-batch-2/ with SHA-256 rows",
    "MANIFEST.md lists source URL, publisher and disclosed failures for anything not retrieved"
  ],
  "falsifiers": [
    "a MANIFEST row whose SHA-256 was not computed from the retrieved bytes",
    "a failed retrieval silently dropped instead of disclosed"
  ],
  "projections": [
    "jira",
    "verification",
    "receipt"
  ],
  "dependencies": [],
  "authority_requirement": "NONE",
  "path_scope": [
    "ontologies/public/**"
  ],
  "required_receipt_classes": [
    "manufacture",
    "verification"
  ]
}
---

# SJ-010: Pin OSLC CM and SIOC public vocabularies

- **Standing**: UNKNOWN

## Status
UNKNOWN
- **Repository**: seanchatmangpt/ggen-marketplace @ `f1c350b`

## Description
SJ-007's ARD (docs/sjira/v26.9.21/ash-atlassian-ard.md section 5) needs OSLC CM and SIOC pinned before any ash_atlassian profile shape can be admitted: batch 1 pinned oslc automation/config/rm only and sioc is absent. Pin both under ontologies/public/xaas-profile-batch-2/ following the batch-1 MANIFEST discipline: real retrieval (HTTP 200), bytes verified as RDF, SHA-256, publisher, and disclosed failures for anything not obtained.

- ontologies/public/xaas-profile-batch-1/ pins oslc automation/config/rm but no cm (verified 2026-09-21)
- no sioc vocabulary file under ontologies/public/ (verified 2026-09-21)
- OSLC CM vocab source observed: https://raw.githubusercontent.com/oasis-tcs/oslc-domains/master/cm/change-mgt-vocab.ttl (HTTP 200, 13178 bytes, sha256 cb9514f87955a997a01548ae407dfb9a751f8828ae29054d09cf0dcb235feeb9 at 2026-09-21; SJ-010 must recompute, not copy)

## Definition of done
- [ ] OSLC CM and SIOC vocabularies pinned under ontologies/public/xaas-profile-batch-2/ with SHA-256 rows
- [ ] MANIFEST.md lists source URL, publisher and disclosed failures for anything not retrieved

Runnable check:

```sh
cd ~/ggen-marketplace && test -f ontologies/public/xaas-profile-batch-2/oslc-cm-vocab.ttl && test -f ontologies/public/xaas-profile-batch-2/sioc-ns.ttl
```

## Falsifiers
- a MANIFEST row whose SHA-256 was not computed from the retrieved bytes
- a failed retrieval silently dropped instead of disclosed
