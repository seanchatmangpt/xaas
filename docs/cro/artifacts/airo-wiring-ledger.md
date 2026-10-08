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
| beam4pm/vendor/ggen-marketplace (submodule) | main | `6e93441406684f6270a90c7f44660cbadbe0500d` | 6e9344140 | plans/w658b (via w937; rebased per w980b, equivalence verified per w982h) |
| ash_surface | main | `b70da9e1c2f5c3ff0bc61299b5a0dcc65bcdd1d3` | b70da9e1c | plans/w637-affidavit-surface-airo.md |
| gymact | v26926/gymact-land-aloop-execution-kernel | `2fa947cb71f91b6cfbc7f86cc5d69efc9f349337` | 2fa947c | plans/w603-gymact-airo.md |
| autofde-lab | feat/doctrine-lab | `31e3decfbbbd2d0df8f5fb9085d5d9de32042911` | 31e3decf | plans/w604-autofde-airo.md |
| wasm4pm | fix/v26.9.30-ci-fmt-tsc | `d980a2a2941327a7d2b0bd892afbb2cf017e230e` | d980a2a29 | plans/w615-wasm4pm-zcode-airo.md |
| zcode-cli | fix/v26926-preview-publish-typed-skip | `1e40596c6ce7ace3868484556827ff14e840f5a7` | 1e40596 | plans/w615-wasm4pm-zcode-airo.md |
| ex4pm | main | `abac0d23e2a5517a13a605da514da417e651147a` | abac0d2 | plans/w680-ex4pm-airo-pin.md |
| ash_pplan | fix/ggen-verify-header | `343e52aebf299a18d12eb81e83c53df78650d15b` | 343e52a | plans/w682-ash-pplan-airo-pin.md |
| ferroplan | main | `e2c48d339cb084a94f0c5d6ae4cccc1904b74b1f` | e2c48d3 | plans/w638-ferroplan-airo.md |

beam4pm gitlink check: `git -C beam4pm rev-parse HEAD:vendor/ggen-marketplace`
= `6e93441406684f6270a90c7f44660cbadbe0500d` = submodule HEAD — not dangling.
(Updated by W982h: 6e4de9765 was rebased to 6e9344140 by W980b during the
NON_FAST_FORWARD repair; patch-ids identical, no content lost.)
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
| w982m | xaas | `priv/airo_risk_description.ttl` (10,323 B, own-sha c85de1b8…, header pins canonical vocab 6274d2d8…) — **ALIVE** | RDF.ex parse: 95 triples, 4 RiskSources / 5 RiskControls / 1 Risk; 26 distinct airo: IRIs, all canonical-vocab members (`missing_from_vocab: []`); 6/6 cited paths on disk | 6 passed (pin court ×2) | plans/w982m-airo-xaas-ttl.md |

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

## Extension — W981e (2026-10-07): repos present on disk, absent from this ledger

Cross-check of `~/` sibling checkouts against the coverage table. Three
fleet repos found on disk with no ledger row; verified SHAs via real
`git -C <repo> rev-parse HEAD`; reference docs at `docs/airo/<repo>/`.
All rows UNKNOWN — no AIRo artifact exists in any of the three repos yet
(filesystem-verified); each row's falsifier names the pin court that
would have to exist for ALIVE.

| repo | branch | HEAD (2026-10-07) | AIRo risk dimension | cited surface | falsifier (ALIVE gate) | standing |
|---|---|---|---|---|---|---|
| ash_graphlaw | main | `3ecae0e771f5448e90d8adc2a8a0786439b5b13e` | Control/guardrail enforcement over agentic actions | `lib/ash_graphlaw/admissions.ex`, `authority.ex`, `evidence.ex` (WASM admission kernel) | AIRo-mapping UNKNOWN — no AIRo instance graph exists in ash_graphlaw at `3ecae0e7` (tree-verified W650t: `git grep -il airo` empty; only `ontology.ttl`, `.sa2a/diataxis.ttl`, `priv/graphlaw/capability-registry.ttl`). Falsifier for ALIVE: repo ships an `airo_risk_description.ttl` (or equivalent AIRo instance graph) at the pinned SHA; pin court = commit-existence of the pinned SHA + cited-path existence (`admissions.ex`/`authority.ex`/`evidence.ex` — present at `3ecae0e7`, W650t) + graph parses w/ RiskSource/Control/Risk triples. Previously cited `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…` — file never existed; pin court was not executable (W650s finding, repaired W650t). Updated from `1d89ba5f` — lawful fast-forward (W631b pull/merge, W634-disclosed drift; ancestor proof + drift re-check: plans/w650s-pin-drift.md) | UNKNOWN |
| ggen-ecosystem | main | `7e107f18c43b8cf2266da68f310e878cd37a8577` | Human-oversight/governance over autonomous actuation | `admission/` (`courts/ws1-*.rq`, `policies.ttl`, `exclusions.ttl`), `ecosystem.ttl` (`eco:doesNotOwn eco:AmbientActuation`) | pin court at SHA: `admission/airo_risk_description.ttl` w/ vocab sha, cited paths exist, 10 courts execute over emitted graph | UNKNOWN |
| chatman-ecosystem | docs/v27927-closed-manufacture-loop | `83ceef8a862a423917e84a8713500745ab162dad` | Control over autonomous-agent actuation authority | `crates/gall` (governed actuator, authority boundary; same pattern as zcode-cli gall-work) | pin court at SHA: `crates/gall/airo_risk_description.ttl` w/ vocab sha, cited paths exist, `cargo test -p gall` passes | UNKNOWN |

No-refusals: no repo in this extension was recorded UNSUPPORTED(no-referent) —
all three have a concrete, cited surface. Other on-disk repos surveyed and
excluded as non-fleet or non-Ash/BEAM: `ash_atlassian` (43e3d21b), `ex4pm_engine`
(not a git repo), `ash_dspy`/`ash_kudzu`/`ash_planning_center`/`ash_expo`/`ash_autofde`
(not surveyed this lane; candidates for a future extension).

## Extension — W981f (2026-10-07): Wave-2 wiring of excluded candidate repos

W981e left six Ash-sibling repos as future-extension candidates. All six
checkouts exist under `$HOME`; HEADs verified via real
`git -C <repo> rev-parse HEAD` on 2026-10-07. Note: the ash_atlassian
number W981e flagged as possibly stale (`43e3d21b…`) was re-verified and
is **current** at HEAD on main. Filesystem check per repo: no `*airo*`
artifact exists (excluding `.git`/`_build`/`deps`) — all rows UNKNOWN,
none invented. Reference docs: `docs/airo/<repo>/airo-reference.md` (new
paths, no duplication with W981e's three).

| repo | branch | HEAD (2026-10-07) | AIRo risk dimension | cited surface | falsifier (ALIVE gate) | standing |
|---|---|---|---|---|---|---|
| ash_atlassian | main | `43e3d21b7c4e4571493fcf3757392ed16f2dd967` | Human-oversight/governance over architectural transitions | `lib/ash_atlassian/governance/` (architecture_decision/requirement/receipt, sbb_qualification, transition_obligation), `architecture_governance.ex` | pin court at SHA: `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…`, cited paths exist, graph parses w/ RiskSource/Control/Risk | UNKNOWN |
| ash_dspy | feat/v26926-ashdspy-abb-sbb-seed | `5d985d5332e86d663ba554d249498ba5bd9a0306` | Verification/admission integrity for AI-program evaluation outcomes | `lib/ash_dspy/court.ex` + `court/`, `receipt.ex`, `verify.ex`, `metric.ex`, `ocel.ex` | pin court at SHA: `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…`, cited paths exist, graph parses | UNKNOWN |
| ash_kudzu | main | `2d600ffd4a6721ed5534c753bd4031cd2bf77500` | Evidence-admission integrity for ontology extraction from untrusted sources | `lib/ash_kudzu/shacl_admission.ex`, `sa2a_evidence_admission.ex`, `sa2a_candidate.ex`, `unified_source/` | pin court at SHA: `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…`, cited paths exist, graph parses | UNKNOWN |
| ash_planning_center | main | `5ee26cbdc8fef26c92c7691355c76f5aed2e7b2c` | Data-integrity/access-control over a generated external-API client | `lib/ash_planning_center/client.ex`, `json_api.ex`, `open_api.ex`, `generated/`, `people/` | pin court at SHA: `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…`, cited paths exist, graph parses | UNKNOWN |
| ash_expo | test/end-to-end-codegen | `59a80d5e9a18208d8b25c47e02de6e714e0b8e8c` | Generated-artifact integrity (codegen/manifest drift in mobile builds) | `lib/ash_expo/codegen.ex`, `manifest.ex`, `resource/`, `info.ex` | pin court at SHA: `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…`, cited paths exist, graph parses | UNKNOWN |
| ash_autofde | main | `65cd05e1bd884383456423af3e516981d8747560` | Resource-allocation control + actuation receipts in WASM CMCA cascade | `lib/ash_autofde/cascade_allocator.ex`, `wasm_cmca.ex`, `resources/actuation_receipt.ex`, `resources/cmca_cascade_plan.ex` | pin court at SHA: `priv/airo_risk_description.ttl` w/ vocab sha `6274d2d8…`, cited paths exist, graph parses | UNKNOWN |

No UNSUPPORTED(no-referent) rows: all six repos have a concrete, cited
surface (paths verified on disk at their SHAs). After this extension, the
ledger covers 25 repos (16 + 3 W981e + 6 W981f); no on-disk `$HOME` fleet
repo remains unwired to lane knowledge.

## Extension — W984ed (2026-10-07): provider-lifecycle RiskControl surface

One more in-repo fleet surface mapped onto the AIRo vocabulary via
`lib/xaas/semantics/airo_risk_mapping.ex` `risk_controls/0` (no prior airo
reference anywhere in the marketplace/provider-lifecycle domain; verified by
tree grep). Additive entry only — no policy change, no variant-mapping change.

| lane | repo | artifact | sha/parse proof | tests executed | receipt |
|---|---|---|---|---|---|
| w984ed | xaas | `lib/xaas/semantics/airo_risk_mapping.ex` `risk_controls/0` — new RiskControl `Xaas.Marketplace.Changes.ApplyProviderStatusChange` (`lib/xaas/marketplace/changes/apply_provider_status_change.ex`), detects/mitigates `UNRECEIPTED_PROVIDER_STATUS_TRANSITION`; maker-checker bridge routes approved provider status changes through receipted `Xaas.Actuation.run/4` | emitted `risk_graph/0` contains `ex:riskControl-Xaas.Marketplace.Changes.ApplyProviderStatusChange a airo:RiskControl` exactly once plus the `airo:hasRiskControl` system edge (exactly 2 occurrences of the local, court-pinned); `mix xaas.airo.compile_shacl` exit 0 (46 classes / 46 shapes / 130 triples, vocab sha `6274d2d8…`) | 6 passed (`test/xaas/semantics/airo_risk_mapping_depth_test.exs` test 6, new); 11 passed sibling courts (airo_shacl_court, airo_vendored_pin, airo_grounding); mock gate `[]` exit 0 | plans/w984ed-probe.md |

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
