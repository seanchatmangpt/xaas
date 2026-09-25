---
{
  "identity": "SJ-016",
  "title": "Bind WD work to bounded SA2A capabilities",
  "description": "Make architecture/work obligations select typed capabilities without ambient authority or LLM mediation on KNOWN classes.",
  "subject": "wd-cs2-stogaf-architecture-episode",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "75b60b496ddc6fe8ac83a9175e3528ce3f4b1a3c",
  "standing": "UNKNOWN",
  "evidence_ceiling": "REPO_LOCAL_FIXTURE",
  "authority_requirement": "NONE",
  "dependencies": [
    "SJ-015"
  ],
  "projection": "sa2a",
  "acceptance": [
    "capability catalog includes reconstruct, retrieve, rank, admit, construct work, verify and replay",
    "all Friday capabilities are OBSERVE/SELECT/CONSTRUCT only",
    "production DO capability is explicitly outside the Friday admissible set",
    "KNOWN path requires zero general LLM calls"
  ],
  "falsifiers": [
    "capability selection grants authority",
    "sa2a_execute is called without admitted authority",
    "KNOWN classification depends on general LLM reasoning"
  ]
}
---

# SJ-016 — Bind WD work to bounded SA2A capabilities

Make architecture/work obligations select typed capabilities without ambient authority or LLM mediation on KNOWN classes.

## Authority

This work order may SELECT and CONSTRUCT repository-local artifacts only. It grants no merge, publish, deploy, external mutation, or production FA disposition authority.

## Evidence rule

ALIVE requires observed execution of the exact subject. Design or file presence alone is insufficient where an executable court is named.
