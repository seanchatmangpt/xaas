# AIRo Wiring Ledger — v26.10.6 Wave (W600–W639)

Consolidated ledger for the AIRo (AI Risk Ontology, https://w3id.org/airo#)
wiring wave. Assembled by lane W639, 2026-10-06. Per-lane receipts live in
`docs/sjira/v26.10.6/plans/` (xaas side); sibling-repo artifacts are listed
per row.

## Coverage statement

**14 repos covered across 13 lanes — all receipts landed.** Poll of
w600/w601/w602/w603/w604/w605/w614/w615/w618/w625d/w634/w637/w638 complete
(w637 was in flight at consolidation start; landed during the 30-min poll
window and is included below). Every lane receipt records executed
verification on the exact on-disk subject; W639 re-verified every artifact
file on disk (paths + sizes). All byte-verbatim vendored vocabulary copies
are sha256-identical at
`6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
(AIRo 1.0, DelaramGlp/airo@`6c67de4`, CC-BY-4.0).

## Consolidated table

| lane | repo | artifact | sha/parse proof | tests executed | receipt |
|---|---|---|---|---|---|
| w600 | xaas | `priv/semantic/airo/airo.ttl` (41,366 B) + README | rdflib parse: 558 triples, 46 classes, 52 props | n/a (vendored) | plans/w600-airo-vendor.md |
| w601 | xaas | `lib/xaas/semantics/airo_risk_mapping.ex` + test | emitted graph rdflib round-trip: 642 triples, 73 subject nodes | 7 passed | plans/w601-airo-mapping.md |
| w602 | ggen-marketplace | `packs/ggen-platform-pack/ontology/airo.ttl` | rdflib 558; `marketplace.py validate` exit 0 (305 packs, 503 ontologies) | n/a (validate) | plans/w602-airo-marketplace.md |
| w603 | gymact | `src/gymact/ontology/airo_risk_description.ttl` (5,353 B) | rdflib 7.6.0 structure court, real parse | 4 passed | plans/w603-gymact-airo.md |
| w604 | autofde-lab | `ontology/airo_risk_description.ttl` (8,071 B) | pytest court, real rdflib parse; 8/8 cited paths on disk | 6 passed | plans/w604-autofde-airo.md |
| w605 | ash_a2a | `priv/ontology/ash_a2a_airo.ttl` (8,917 B) | ExUnit court; 11 RiskSources / 5 Controls / 5 Risks | 9 passed | plans/w605-ash-a2a-airo.md |
| w614 | ggen | `docs/airo-risk-description.ttl` (8,306 B) + `scripts/check_airo.sh` | 618 triples after vocab union; 15/15 vocab terms; 5/5 cited paths | script PASS | plans/w614-ggen-airo.md |
| w615 | wasm4pm | `tests/ontology/airo_risk_description.ttl` (8,511 B) | rdflib parse + structure court | 4 passed | plans/w615-wasm4pm-zcode-airo.md |
| w615 | zcode-cli | `ontology/airo_risk_description.ttl` (8,022 B) | bun structural court; w356 contract shas recomputed in-test | 4 passed (+1076 full unit gate) | plans/w615-wasm4pm-zcode-airo.md |
| w618 | ggen_igniter | `priv/airo_risk_description.ttl` (10,296 B) | 4-test court; every `airo:` term from fetched vocab; cited paths asserted | 4 passed | plans/w618-ggen-igniter-airo.md |
| w625d | ash_r2rml | `priv/airo_risk_description.ttl` + `test/fixtures/airo_vocabulary_snapshot.ttl` | 6-test court; snapshot sha asserted == pin; full suite 1004/0/9 skipped | 6 passed (+1004 full) | plans/w625d-ash-r2rml-airo.md |
| w634 | beam4pm | `priv/airo_risk_description.ttl` (14,146 B) | rdflib 179 triples; sha verified vs pin | 11 passed (8 court + 3 canary) | plans/w634-beam4pm-airo.md |
| w637 | ash_affidavit | `ontology/airo_risk_description.ttl` (12,084 B) | 4-test ExUnit court; path-exists assertions; vocab per w600 pin | 4 passed | plans/w637-affidavit-surface-airo.md |
| w637 | ash_surface | `priv/airo_risk_description.ttl` (11,271 B) | 4-test ExUnit court after 57-file compile; path-exists assertions | 4 passed | plans/w637-affidavit-surface-airo.md |
| w638 | ferroplan | `docs/airo-risk-description.ttl` (5,417 B) + `scripts/check_airo.sh` | 592 triples after vocab union; 15/15 vocab terms; 5/5 cited paths | script PASS | plans/w638-ferroplan-airo.md |

## Cross-repo sha consistency check

**Verdict: CONSISTENT.** `shasum -a 256` executed by W639 on every landed
byte-verbatim vendored copy:

| file | sha256 |
|---|---|
| /Users/sac/xaas/priv/semantic/airo/airo.ttl | 6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469 |
| /Users/sac/ggen-marketplace/packs/ggen-platform-pack/ontology/airo.ttl | 6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469 |
| /Users/sac/ash_r2rml/test/fixtures/airo_vocabulary_snapshot.ttl | 6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469 |
| /tmp/airo.ttl (shared cache behind w614/w638 checks) | 6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469 |

All four copies match the w600/w621b pin byte-for-byte.

## Carry-forwards

1. Nothing committed in any of the 14 repos; all lane work is uncommitted on
   canonical checkouts — coordinator owns the integration commits.
2. Lane build-root leases to delete at integration: `_build-laneW601`
   (xaas), `_build-laneW605` (ash_a2a), `_build-laneW625d` (ash_r2rml),
   `_build-laneW634` (beam4pm), `_build-laneW637a` (ash_affidavit),
   `_build-laneW637b` (ash_surface).
3. w601 disclosed a mid-lane concurrent overwrite of
   `lib/xaas/semantics/airo_risk_mapping.ex`; integration must re-run
   `mix test test/xaas/semantics/airo_risk_mapping_test.exs` and diff-check
   the file before commit.
4. w638 deferred Likelihood/Severity individuals (noted in TTL); w614
   asserted self-assessed individuals — optional harmonization pass later.
5. AIRo 1.0 is a structural vocabulary with no concrete risk-concept
   individuals; xaas mints `ex:`-qualified concepts (w601 convention) — this
   is the standing convention for consumer repos.
