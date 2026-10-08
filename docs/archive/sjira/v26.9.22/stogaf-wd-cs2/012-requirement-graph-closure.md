---
{
  "identity": "SJ-012",
  "title": "Close the WD requirement graph",
  "description": "Bind every WD Case Study 2 obligation to a STOGAF requirement, building block, implementation surface, court and standing.",
  "subject": "wd-cs2-stogaf-architecture-episode",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "75b60b496ddc6fe8ac83a9175e3528ce3f4b1a3c",
  "standing": "UNKNOWN",
  "evidence_ceiling": "REPO_LOCAL_FIXTURE",
  "authority_requirement": "NONE",
  "dependencies": [
    "SJ-011"
  ],
  "projection": "stogaf",
  "acceptance": [
    "requirements.json contains R-01 through R-16 exactly once",
    "every requirement has a building block, court and standing",
    "requirement traceability markdown and RDF instance agree on requirement identities",
    "unimplemented production claims remain DESIGN, PARTIAL_ALIVE or UNKNOWN"
  ],
  "falsifiers": [
    "a requirement has no court",
    "a requirement has no satisfying building block",
    "a production metric is promoted without evidence"
  ]
}
---

# SJ-012 — Close the WD requirement graph

Bind every WD Case Study 2 obligation to a STOGAF requirement, building block, implementation surface, court and standing.

## Authority

This work order may SELECT and CONSTRUCT repository-local artifacts only. It grants no merge, publish, deploy, external mutation, or production FA disposition authority.

## Evidence rule

ALIVE requires observed execution of the exact subject. Design or file presence alone is insufficient where an executable court is named.
