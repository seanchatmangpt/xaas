# W614 — ggen AIRo risk description (ggen leg)

Lane: W614 (AIRo wiring wave, ggen leg). Repo: /Users/sac/ggen (canonical checkout, nothing committed).
Branch state of repo: observed on disk 2026-10-06; no git operations performed.

## Files written

- /Users/sac/ggen/docs/airo-risk-description.ttl
- /Users/sac/ggen/scripts/check_airo.sh (executable)

## Vocabulary

Fetched https://raw.githubusercontent.com/DelaramGlp/airo/main/airo.ttl → /tmp/airo.ttl
sha256 6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469 — matches W600's verified sha.

## Mapping

- ggen-airo:GgenManufactureSystem a airo:AISystem ; airo:isProvidedBy ggen-airo:GgenProject (airo:AIProvider)
- 3 airo:Risk individuals, each grounded in a real documented hazard:
  - generated-code drift (the docs-sync gate exists because this materialised, #285/#287 churn)
  - generator-identity skew (composition catalog primitive R, w523-era; C20 falsifier UNKNOWN)
  - stale cross-repo pin (w377/w339 class; composition-root lock N)
- 3 airo:RiskControl individuals = the real gates, real files verified on disk:
  - ControlPortableReceiptReplay → crates/ggen-engine/src/portable_receipt.rs (RFC subject + sha256 digest closure)
  - ControlSyncDriftGate → .github/workflows/publish-candidate.yml ("Docs-through-ggen drift gate (docs-sync)") + justfile recipes `docs-sync`/`verify-tcps` (justfile:783/806)
  - ControlFrozenCourtPinning → .github/workflows/ggen-sync-run.yml (exact release tag input, e.g. v26.8.27) + ggen-sync-run-selftest.yml (ggen_release: v26.8.27)
- Likelihood/Severity individuals are self-assessed (Low/Medium; Moderate/Major) and labelled as such in rdfs:comment;
  airo.ttl defines the classes but no individuals.
- dc27242 admission and w334/w474/w523/w377/w339 cited as cross-repo wave receipt identifiers, not file paths.

## Check output (real run, /Users/sac/ggen/scripts/check_airo.sh)

- 5/5 cited paths exist on disk
- TTL parses with rdflib (/tmp/airo-venv, python3.14): 618 triples after union with the AIRo vocabulary
- 15/15 AIRo terms used are defined in the fetched vocabulary
- check_airo: PASS

## Standing

ALIVE for this lane's falsifier (parse + path-existence + vocabulary-term check), executed on the exact
on-disk subject. Not committed (canonical checkout, coordinator owns git transitions).
