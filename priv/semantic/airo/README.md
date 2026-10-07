# AIRO — AI Risk Ontology (vendored)

Verbatim vendored copy of the AI Risk Ontology (AIRO) by Delaram Golpayegani
(AIRO project), for fleet-wide AI-risk vocabulary. Consumed by AIRo wiring-wave
lanes (W600 vendoring lane).

- **File**: `airo.ttl` (byte-exact, no edits)
- **Source URL**: https://raw.githubusercontent.com/DelaramGlp/airo/main/airo.ttl
- **Repo**: https://github.com/DelaramGlp/airo
- **Commit**: `6c67de43abd154393b09bb54da1fe1fa7501215b` (main, committed 2025-08-01T17:00:09Z; 318 commits total)
- **sha256**: `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
- **Namespace prefix**: `airo:` → `https://w3id.org/airo#`
- **Namespace doc**: https://delaramglp.github.io/airo/
- **Ontology version**: 1.0 (`owl:versionIRI <https://w3id.org/airo/1.0>`, `owl:versionInfo "1.0"`)
- **License**: CC-BY-4.0 (`http://purl.org/dc/terms/license` → https://creativecommons.org/licenses/by/4.0/)

## Parse proof

rdflib (python3) turtle parse, run 2026-10-06:

```
triples: 558
classes: 46
properties: 52
```

## Inventory (key terms, all verified present in the vendored file)

Classes (46 owl:Class total): `AISystem`, `Risk`, `RiskSource`, `Hazard`,
`Consequence`, `Impact`, `Likelihood`, `Severity`, `Vulnerability`,
`RiskControl`, `AIProvider`, `AIDeployer`, `AISubject`, plus (non-exhaustive)
`RiskMatrices`, `RiskDocumentation`, `RiskControlCertificate`, `Person`,
`Group`, `Organisation`, `DefinedTerm`, `Scalable`, `LargeScaleAI`, `GPAIThirdPartyProvider`,
`Action`, `Trace`, `Evidence`, `RedTeamingExercise`, `ConformityAssessment`,
`StandardRef`, `Licence`, `STANDARD`, `Assessment`, `AssessmentCertification`,
`ImpactOn...` (impact subclasses), `Consequence`, `hasGoal` domain terms.

Properties (52 total): `hasRisk`, `hasConsequence`, `hasImpact`,
`hasLikelihood`, `hasSeverity`, `hasRiskSource`, `hasVulnerability`,
`hasRiskControl`, `isRiskStoredIn`, `isImpactOfRisk`, `isConsequenceOf`,
`mitigatesRiskConcept`, `detectsRiskConcept`, `eliminatesRiskConcept`,
`hasProvider`, `hasDeployer`, `hasSubject`, `hasAction`, `hasTrace`,
`hasEvidence`, `hasGoal`, `hasLicense`, `hasRedTeamExercise`, `hasGPAIModel`,
`isDeployedBy`, `isProvidedBy`, `isRiskOf`, `isRiskSourceOf`, `isVulnerabilityOf`,
`isRiskControlOf`, `isParticipant`, `isRelatedToUsers`,
`isRelatedToDocuments`, `isRelatedToRisk`, `isRelatedToDocuments`,
`isRelatedToRiskControl`, `isRiskMatrices`, `isRiskDocumentation`...

## Reuse note

The v1.0 artifact is self-contained — its only declared import surface in this
file is DC/DCMI metadata (`dc:`/`terms:` annotation properties; no
`owl:imports` of DPV/DQV/DCAT/PROV in this artifact). AIRO's DPV alignment is
documented at the namespace doc (https://delaramglp.github.io/airo/), which
describes AIRO as an extension of DPV (W3C DPV); DPV/DQV/DCAT/PROV reuse is a
documented design relationship, not an in-file `owl:imports` in the v1.0 .ttl.

## Consumer contract

- Consume verbatim: do not hand-edit `airo.ttl` (third-party vocabulary;
  regenerate only by re-vendoring a new commit).
- Consumers should query against `https://w3id.org/airo#` IRIs directly;
  the file is self-contained and parses standalone.
