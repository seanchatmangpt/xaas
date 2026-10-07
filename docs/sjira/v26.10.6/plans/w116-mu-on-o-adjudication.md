# W116 — mu_on_O Adjudication

- Lane: W116
- Subject: see _LANES roster
- Date: 2026-10-06
- Note: backfilled by coordinator from lane completion report

## What landed

- Anchor tests 8/8 after pinning the typed refusal
  `{broken_term: "mu_on_O",
    detail: ["descriptor_refused", ["not_eligible", "EP-A", "unknown_identity"]]}`.
- Root cause (cross-repo): ggen_igniter 23c36c8 (AC-04) made
  origin_authority required; the sealed fmt-1 fixture predates it.
- EP-A genuinely foreign to current law (verified by direct
  `mix semantic_jira.descriptor` in sibling).

## Gate output (verbatim as reported)

8/8 anchor tests passed.

## Disclosures

- Failure is a fixture/law-version skew, not a regression.
