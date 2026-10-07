# W600 — AIRO vendor receipt (lane W600, AIRo wiring wave)

- **Repo**: /Users/sac/xaas @ feat/playwright-surface (canonical checkout, private build root `_build-laneW600` — unused; no mix commands needed)
- **Scope honored**: writes confined to `priv/semantic/airo/` (new) + this plan file. No other files touched.
- **Standing**: ALIVE (vendored artifact + parse executed + sha recorded)

## Subject

- `priv/semantic/airo/airo.ttl` — 41,366 bytes
- `priv/semantic/airo/README.md`

## Source

- URL: https://raw.githubusercontent.com/DelaramGlp/airo/main/airo.ttl
- Repo commit: `6c67de43abd154393b09bb54da1fe1fa7501215b` (main, 2025-08-01T17:00:09Z)
- sha256: `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
- Version: 1.0 (`owl:versionIRI <https://w3id.org/airo/1.0>`), CC-BY-4.0
- Prefix: `airo:` → `https://w3id.org/airo#`

## Fetch + parse (executed)

- `curl -sL -o priv/semantic/airo/airo.ttl https://raw.githubusercontent.com/DelaramGlp/airo/main/airo.ttl` — exit 0
- `python3 -c "import rdflib; g=rdflib.Graph(); g.parse('priv/semantic/airo/airo.ttl', format='turtle'); print(len(g))"` — exit 0

## Parse proof

- rdflib turtle parse: **558 triples**, 46 owl:Class, 52 airo: properties
- All key classes verified present: AISystem, Risk, RiskSource, Hazard, Consequence, Impact, Likelihood, Severity, Vulnerability, RiskControl, AIProvider, AIDeployer, AISubject
- All key properties verified present: hasRisk, hasConsequence, hasImpact, hasLikelihood, hasSeverity, mitigatesRiskConcept, detectsRiskConcept, eliminatesRiskConcept
- Prefixes in file: airo, dc, owl, rdf, rdfs, terms, xml, xsd — self-contained (no owl:imports of DPV/DQV/DCAT/PROV in this artifact; DPV extension relationship is documented at the namespace doc, not imported in-file)

## Notes for consumer lanes

- Query the vendored file directly; `https://w3id.org/airo#` IRIs; no transitive imports to resolve.
- mix.exs already declares `{:rdf, "~> 3.0"}` / `{:sparql, "~> 0.3"}` — Elixir-side SPARQL over the vendored TTL is available without new deps.
- Re-vendor procedure: re-fetch the raw URL, recompute sha256, update README + this receipt; never edit airo.ttl in place.
