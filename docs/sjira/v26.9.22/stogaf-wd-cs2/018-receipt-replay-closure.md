---
{
  "identity": "SJ-018",
  "title": "Close receipt and replay standing",
  "description": "Bind exact subject, evidence, verifier, semantic projection and replay outcome into a durable repository-local proof bundle.",
  "subject": "wd-cs2-stogaf-architecture-episode",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "75b60b496ddc6fe8ac83a9175e3528ce3f4b1a3c",
  "standing": "UNKNOWN",
  "evidence_ceiling": "REPO_LOCAL_FIXTURE",
  "authority_requirement": "NONE",
  "dependencies": [
    "SJ-017"
  ],
  "projection": "receipt",
  "acceptance": [
    "receipt binds exact git head",
    "receipt identifies the court and evidence ceiling",
    "tampered receipt is refused",
    "replay verifies the admitted MachineExperience transition",
    "receipt does not claim external standing"
  ],
  "falsifiers": [
    "self-certification is accepted",
    "receipt survives subject/evidence tampering",
    "receipt claims deployment or production authority"
  ]
}
---

# SJ-018 — Close receipt and replay standing

Bind exact subject, evidence, verifier, semantic projection and replay outcome into a durable repository-local proof bundle.

## Authority

This work order may SELECT and CONSTRUCT repository-local artifacts only. It grants no merge, publish, deploy, external mutation, or production FA disposition authority.

## Evidence rule

ALIVE requires observed execution of the exact subject. Design or file presence alone is insufficient where an executable court is named.
