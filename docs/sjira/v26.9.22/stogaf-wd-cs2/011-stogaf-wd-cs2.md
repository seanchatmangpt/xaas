---
{
  "identity": "SJ-011",
  "title": "Backfill WD CS2 with Semantic TOGAF v26.9.22",
  "description": "Make the WD Case Study 2 demo an executable STOGAF architecture episode rather than a collection of independent artifacts.",
  "subject": "wd-cs2-stogaf-architecture-episode",
  "repository": "seanchatmangpt/xaas",
  "base_sha": "2a595315f4423c7e58877ff19dadd04e96dbff36",
  "standing": "UNKNOWN",
  "evidence_ceiling": "REPO_LOCAL_FIXTURE",
  "authority_requirement": "NONE",
  "current_conformance": "ST-4 CONSTRAINED",
  "target_conformance": "ST-6 AUTONOMIC",
  "required_courts": [
    "compile",
    "wd_cs2_chicago",
    "stogaf_conformance",
    "playwright",
    "no_mocks"
  ],
  "projections": [
    "canonical-architecture",
    "ocel",
    "sjira",
    "sa2a-boundary",
    "morning-brief",
    "browser"
  ],
  "acceptance": [
    "STOGAF RFC is canonical and explicitly non-official",
    "WD baseline, target and gap are machine-addressable",
    "ADM G and H are represented as implementation-governance and architecture-change transitions",
    "demo exposes current ST-4 and target ST-6 without claiming ST-7+",
    "views are documented as projections of O*",
    "sJira remains work projection and SA2A remains capability interaction",
    "MachineExperience requirements preserve verification, provenance, applicability, evidence ceiling and replay identity",
    "Playwright observes STOGAF standing on the same WD browser surface"
  ],
  "falsifiers": [
    "a presentation artifact becomes an independent source of truth",
    "ST-7 or higher is claimed without consequential authority evidence",
    "candidate ranking creates KNOWN or authority",
    "missing evidence is converted into guessed completion",
    "a MachineExperience lacks verified consequence or replay identity",
    "the browser reports architecture standing inconsistent with the executable profile"
  ]
}
---

# SJ-011 — STOGAF backfill for WD Case Study 2

## Purpose

Backfill the existing WD CS2 reference implementation with the Semantic TOGAF v26.9.22 execution profile.

## Canonical rule

```
A = μ(O*)
```

The graph is canonical. The Morning Brief, case-study deck, board deck, sJira work, SA2A interactions and browser surface are projections.

## Current ceiling

`ST-4 CONSTRAINED` is the current cumulative conformance claim.

## Friday target

`ST-6 AUTONOMIC` at `REPO_LOCAL_FIXTURE` standing.

ST-7 through ST-9 remain UNKNOWN until consequential actuation, consequence reconciliation and production learning are actually observed.
