# Slide facts projection

Generated from the case-study claims ledger via the cs: projection
conventions (cs:rendersClaim / cs:renderedBy / cs:noClaimReason). A
presentation pack exists (pptx-presentation-pack, pres:); a consumer maps its
pres:Presentation and pres:Slide onto cs:Projection with a bridge of subclass
axioms (see packs/greene-licensing-case-pack/ontology/cs-pres-bridge.ttl)
without touching this ledger. Gate 030 guarantees this projection adds no
claim: every slide fact below resolves to a declared claim; slides without
claims carry only their cs:noClaimReason.

## Slide facts (claims that render)

- https://ggen.dev/ontology/greene-licensing-case/deck#deck: [C01 | ALIVE_FIXTURE] At the bound commit the doctrine lab ran 252 episodes over 9 worlds and 2 seeds and sealed a 252-record ledger. (evidence: `src/autofde_lab/simulation/doctrine_lab/seal.py`)
- https://ggen.dev/ontology/greene-licensing-case/deck#deck: [C02 | ALIVE_FIXTURE] A second, separate process reproduces report.json and ledger.jsonl byte for byte. (evidence: `src/autofde_lab/simulation/doctrine_lab/report.py`)
- https://ggen.dev/ontology/greene-licensing-case/deck#deck: [C03 | ALIVE_FIXTURE] verify_run with replay re-executes the run and reports it valid with zero failures. (evidence: `src/autofde_lab/simulation/doctrine_lab/verify.py`)
- https://ggen.dev/ontology/greene-licensing-case/deck#deck: [C04 | ALIVE_FIXTURE] In this model, two pairs of distinct doctrine compositions produced behaviourally identical policies. (evidence: `src/autofde_lab/simulation/doctrine_lab/relations.py`)
- https://ggen.dev/ontology/greene-licensing-case/deck#deck: [C05 | ALIVE_FIXTURE] The strategic-doctrine catalog projection carries a licensing non-claim and is gated against excerpts. (evidence: `packs/strategic-doctrine-pack/generated/catalog.json`)
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-02: [C05 | ALIVE_FIXTURE] The strategic-doctrine catalog projection carries a licensing non-claim and is gated against excerpts. (evidence: `packs/strategic-doctrine-pack/generated/catalog.json`)
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-04: [C01 | ALIVE_FIXTURE] At the bound commit the doctrine lab ran 252 episodes over 9 worlds and 2 seeds and sealed a 252-record ledger. (evidence: `src/autofde_lab/simulation/doctrine_lab/seal.py`)
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-04: [C03 | ALIVE_FIXTURE] verify_run with replay re-executes the run and reports it valid with zero failures. (evidence: `src/autofde_lab/simulation/doctrine_lab/verify.py`)
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-05: [C02 | ALIVE_FIXTURE] A second, separate process reproduces report.json and ledger.jsonl byte for byte. (evidence: `src/autofde_lab/simulation/doctrine_lab/report.py`)
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-06: [C04 | ALIVE_FIXTURE] In this model, two pairs of distinct doctrine compositions produced behaviourally identical policies. (evidence: `src/autofde_lab/simulation/doctrine_lab/relations.py`)


## Slides without claims

- https://ggen.dev/ontology/greene-licensing-case/deck#slide-01: Title slide; states the packet boundary only.
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-03: Mechanism overview; carries no evidence-bearing claim.
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-07: Request summary; rights items are not case claims.
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-08: Decision branches; carries no evidence-bearing claim.
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-09: Lists the case non-claims; renders no claim.
- https://ggen.dev/ontology/greene-licensing-case/deck#slide-10: Closing slide; carries no evidence-bearing claim.


## Claims omitted from the projection (omission is lawful; addition is not)

- (none -- every claim renders)

