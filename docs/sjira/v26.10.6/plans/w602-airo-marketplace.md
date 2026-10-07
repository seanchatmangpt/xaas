# W602 — AIRo vendored into ggen-marketplace active pack

Lane: W602 (AIRo wiring wave). Repo: /Users/sac/ggen-marketplace (canonical checkout, uncommitted).

## Placement

`packs/ggen-platform-pack/ontology/airo.ttl`

Rationale: `marketplace.active.toml` pins `front_door = "ggen-platform-pack"` (active
version 26.10.6). `scripts/marketplace.py:ontology_files()` recognizes two ontology
surfaces per pack: `*.ttl` at pack root and everything under `ontology/`. The
`ontology/` subdir keeps the vendored third-party ontology separate from the pack's
own `ontology.ttl` / `source.ttl` (pack-authored vocabulary), so no hand-edit of
authoritative pack files. Verbatim vendored, no edits.

## Source + identity

- Source: https://raw.githubusercontent.com/DelaramGlp/airo/main/airo.ttl (fetched 2026-10-06 via curl, byte-verbatim)
- sha256: `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
- AIRO v1.0 (owl:versionIRI https://w3id.org/airo/1.0), CC BY 4.0, ADAPT Centre Trinity College Dublin
- rdflib parse: 558 triples, OK

## Verification (real output)

- `python3 scripts/marketplace.py validate`
  → `validated packs=305 manifests=305 ontologies=503 templates=1819 native_gates=1868 verifier_gates=21 profiles={"project":101,"projection":158,"semantic":46} diataxis=20` exit 0
- `python3 scripts/marketplace.py check ggen-platform-pack --no-qualify`
  → `check ok packs=1 turtle=ok qualify=skipped` exit 0 (turtle_issues gate over all pack *.ttl passes)

## Standing

ALIVE for the vendoring+validation scope; uncommitted on the canonical checkout per
lane contract (coordinator owns commits). Not wired into any pack component
declaration — the ontology is present on the accepted surface, downstream consumers
may reference `https://w3id.org/airo#` terms.
