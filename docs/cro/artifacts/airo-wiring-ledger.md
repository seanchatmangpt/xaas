# AIRo Wiring Ledger — v26.10.6 Wave (W600–W639)

Consolidated ledger for the AIRo (AI Risk Ontology, https://w3id.org/airo#)
wiring wave. Assembled by lane W639, 2026-10-06. Per-lane receipts live in
`docs/sjira/v26.10.6/plans/` (xaas side); sibling-repo artifacts are listed
per row.

> **Fleet SHAs updated post-W937 commit wave (W965, 2026-10-07); pre-commit
> SHAs in plans/w937-fleet-commits.md**

## Fleet repo SHAs (post-W937 commit wave, W965)

Each HEAD verified via real `git -C <repo> rev-parse HEAD` on 2026-10-07.
Wave-commit column annotates the commit landed by W937
(`docs/sjira/v26.10.6/plans/w937-fleet-commits.md`).

| repo | branch | HEAD (post-W937) | wave commit | lane receipt |
|---|---|---|---|---|
| ggen-marketplace | feat/aaif-gcp-roadmap-v26.10.5 | `b58d7854142bacbd3aeffb83501646cae56c858a` | b58d78541 | plans/w602-airo-marketplace.md |
| ggen | feat/v26.10.5-release-cut | `ba837d7437367dd84543c07b5179c88e214cbff4` | ba837d743 | plans/w614-ggen-airo.md |
| beam4pm | main | `560202484f5f61568e74fb0bfde13f6f6a67fdd2` | 56020248 | plans/w634-beam4pm-airo.md |
| beam4pm/vendor/ggen-marketplace (submodule) | main | `6e4de9765e36392c09539afb1464e1eae4f9b2d8` | 6e4de9765 | plans/w658b (via w937) |
| ash_surface | main | `b70da9e1c2f5c3ff0bc61299b5a0dcc65bcdd1d3` | b70da9e1c | plans/w637-affidavit-surface-airo.md |
| gymact | v26926/gymact-land-aloop-execution-kernel | `2fa947cb71f91b6cfbc7f86cc5d69efc9f349337` | 2fa947c | plans/w603-gymact-airo.md |
| autofde-lab | feat/doctrine-lab | `31e3decfbbbd2d0df8f5fb9085d5d9de32042911` | 31e3decf | plans/w604-autofde-airo.md |
| wasm4pm | fix/v26.9.30-ci-fmt-tsc | `d980a2a2941327a7d2b0bd892afbb2cf017e230e` | d980a2a29 | plans/w615-wasm4pm-zcode-airo.md |
| zcode-cli | fix/v26926-preview-publish-typed-skip | `1e40596c6ce7ace3868484556827ff14e840f5a7` | 1e40596 | plans/w615-wasm4pm-zcode-airo.md |
| ex4pm | main | `abac0d23e2a5517a13a605da514da417e651147a` | abac0d2 | plans/w680-ex4pm-airo-pin.md |
| ash_pplan | fix/ggen-verify-header | `343e52aebf299a18d12eb81e83c53df78650d15b` | 343e52a | plans/w682-ash-pplan-airo-pin.md |
| ferroplan | main | `e2c48d339cb084a94f0c5d6ae4cccc1904b74b1f` | e2c48d3 | plans/w638-ferroplan-airo.md |

beam4pm gitlink check: `git -C beam4pm rev-parse HEAD:vendor/ggen-marketplace`
= `6e4de9765e36392c09539afb1464e1eae4f9b2d8` = submodule HEAD — not dangling.
Repos not touched by W937 (ash_a2a, ash_r2rml, ggen_igniter, ash_affidavit)
retain their pre-wave HEADs; no post-pin commit was reported for them.

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
| w604 | autofde-lab | `ontology/airo_risk_description.ttl` (8,071 B) | pytest court, real rdflib parse; 7/7 distinct cited paths on disk (9 seeAlso triples, 2 dupes) | 6 passed | plans/w604-autofde-airo.md |
| w605 | ash_a2a | `priv/ontology/ash_a2a_airo.ttl` (8,917 B) | ExUnit court; 11 RiskSources / 5 Controls / 5 Risks | 9 passed | plans/w605-ash-a2a-airo.md |
| w614 | ggen | `docs/airo-risk-description.ttl` (8,306 B) + `scripts/check_airo.sh` | 618 triples after vocab union; 15/15 vocab terms; 5/5 cited paths | script PASS | plans/w614-ggen-airo.md |
| w615 | wasm4pm | `tests/ontology/airo_risk_description.ttl` (8,511 B) | rdflib parse + structure court | 4 passed | plans/w615-wasm4pm-zcode-airo.md |
| w615 | zcode-cli | `ontology/airo_risk_description.ttl` (8,022 B) | bun structural court; w356 contract shas recomputed in-test | 4 passed (+1076 full unit gate) | plans/w615-wasm4pm-zcode-airo.md |
| w618 | ggen_igniter | `priv/airo_risk_description.ttl` (10,296 B) | 4-test court; every `airo:` term from fetched vocab; cited paths asserted | 4 passed | plans/w618-ggen-igniter-airo.md |
| w625d | ash_r2rml | `priv/airo_risk_description.ttl` + `test/fixtures/airo_vocabulary_snapshot.ttl` | 6-test court; snapshot sha asserted == pin; full suite 1004/0/9 skipped | 6 passed (+1004 full) | plans/w625d-ash-r2rml-airo.md |
| w634 | beam4pm | `priv/airo_risk_description.ttl` (14,146 B) | rdflib 179 triples; sha verified vs pin | 11 passed (8 court + 3 canary) | plans/w634-beam4pm-airo.md |
| w645b/W680 | ex4pm | `priv/ontologies/airo_risk_description.ttl` (7,956 B, own-sha 766059ce…, risk-description instance) | rdflib 77 solo / 635 unioned with canonical vocab 6274d2d8…; W680 pin court | 9 passed (4 pin + 5 w645b) | plans/w680-ex4pm-airo-pin.md |
| W682 | ash_pplan | `priv/airo_risk_description.ttl` (11,609 B, own-sha 5d28a105…, header pins canonical vocab 6274d2d8…) | committed at HEAD 7eeaaa1; W682 pin court (sha/structure/VIA-path/module-load pins) | 10 passed (6 pin + 4 w635 court) | plans/w682-ash-pplan-airo-pin.md |
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
