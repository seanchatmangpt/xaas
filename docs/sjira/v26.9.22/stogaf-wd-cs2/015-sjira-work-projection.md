---
{
  "identity": "SJ-015",
  "title": "Project WD architecture gaps into sJira",
  "description": "Represent missing evidence, diagnostic obligations, architecture gaps and Friday closure work as semantic work orders rather than manually reconstructed tickets.",
  "subject": "wd-cs2-stogaf-architecture-episode",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "75b60b496ddc6fe8ac83a9175e3528ce3f4b1a3c",
  "standing": "UNKNOWN",
  "evidence_ceiling": "REPO_LOCAL_FIXTURE",
  "authority_requirement": "NONE",
  "dependencies": [
    "SJ-013"
  ],
  "projection": "stogaf",
  "acceptance": [
    "PARTIAL case creates an explicit missing-evidence obligation",
    "work order binds subject, owner, evidence, standing and dependencies",
    "ST-6 closure orders are machine-indexed",
    "sJira remains a projection, not canonical state"
  ],
  "falsifiers": [
    "ticket text is required to reconstruct subject identity",
    "work can promote architecture standing without verification"
  ]
}
---

# SJ-015 — Project WD architecture gaps into sJira

Represent missing evidence, diagnostic obligations, architecture gaps and Friday closure work as semantic work orders rather than manually reconstructed tickets.

## Authority

This work order may SELECT and CONSTRUCT repository-local artifacts only. It grants no merge, publish, deploy, external mutation, or production FA disposition authority.

## Evidence rule

ALIVE requires observed execution of the exact subject. Design or file presence alone is insufficient where an executable court is named.
