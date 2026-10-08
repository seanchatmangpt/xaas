---
{
  "identity": "SJ-019",
  "title": "Bind presentation claims to executable evidence",
  "description": "Ensure every claim in the Friday presentation maps to architecture state, implementation, court and evidence ceiling.",
  "subject": "wd-cs2-stogaf-architecture-episode",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "75b60b496ddc6fe8ac83a9175e3528ce3f4b1a3c",
  "standing": "UNKNOWN",
  "evidence_ceiling": "REPO_LOCAL_FIXTURE",
  "authority_requirement": "NONE",
  "dependencies": [
    "SJ-018"
  ],
  "projection": "presentation",
  "acceptance": [
    "every primary slide has a requirement/evidence mapping",
    "demo vocabulary matches executable fixture vocabulary or declares an explicit mapping",
    "authority story is consistent across deck, browser and architecture docs",
    "STOGAF and MachineExperience are visible but do not displace the WD problem"
  ],
  "falsifiers": [
    "presentation claims auto-close while the implementation requires engineer disposition",
    "slide reports production metrics not present in evidence",
    "presentation architecture differs from executable architecture"
  ]
}
---

# SJ-019 — Bind presentation claims to executable evidence

Ensure every claim in the Friday presentation maps to architecture state, implementation, court and evidence ceiling.

## Authority

This work order may SELECT and CONSTRUCT repository-local artifacts only. It grants no merge, publish, deploy, external mutation, or production FA disposition authority.

## Evidence rule

ALIVE requires observed execution of the exact subject. Design or file presence alone is insufficient where an executable court is named.
