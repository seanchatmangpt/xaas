# W615 — WP-6: Direct AIRO → SHACL Compilation (v26.10.7 campaign)

Lane: W615 · Wave: v26.10.7 · Base HEAD: `cf228da6632829396ee3d06b860b3ea3a04b8904`
Branch: `feat/playwright-surface` (shared campaign checkout; NOT committed — per lane orders)
Date: 2026-10-07

## Subject (exact)

- Vocabulary: `priv/semantic/airo/airo.ttl` — AIRO 1.0, sha256
  `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`
  (matches W981j/W982m pin; re-verified on disk this session).
- Instance graph: `priv/airo_risk_description.ttl` (W982m; 5 RiskSources/Hazards,
  1 Risk, 5 RiskControls, full risk→consequence→impact chain).
- Deps ground truth: RDF.ex 3.0.1 + SPARQL 0.3.12 present; **no SHACL package**
  (`shacl` absent from mix.lock) → hand-rolled constraint checker, engine absence
  disclosed below.

## Compilation contract

`Mix.Tasks.Xaas.Airo.CompileShacl.compile/0` parses the pinned vocabulary, emits
`priv/airo/profile.shacl.ttl` (GENERATED header, do-not-edit), and gates itself on
a round-trip re-parse:

- One `sh:NodeShape` per AIRO class, `sh:targetClass` bound; shape census ==
  AIRO class census (46 = 46).
- Constraint 1 — Control binds ≥1 risk concept: `airo-sh:airo-shape-RiskControl`
  carries `sh:or` over PropertyShapes `{sh:path airo:mitigates|detects|eliminates|
  modifiesRiskConcept ; sh:minCount 1}`.
- Constraint 2 — Risk cited by ≥1 control: `airo-sh:airo-shape-Risk` carries
  `sh:or` over inverse-path PropertyShapes.
- Constraint 3 — file citations: `rdfs:seeAlso` must be `file://` (checked by
  `check_file_citations/1` against the real filesystem; not SHACL-expressible).
- Zero custom TBoxes: profile IRIs live only under sh:, airo:, rdf:/rdfs:
  (rdf:type structural only). No other namespace appears.

## Standing: ALIVE (narrow, with one disclosed boundary)

Commands (all real, this session, toolchain asdf elixir 1.20.2-otp-28,
`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW615`):

```
mix compile                                   → exit 0 (warnings pre-existing in other lanes' files)
mix test test/xaas/airo_shacl_court_test.exs  → 5 passed, 0 failed (multiple runs)
  W615 court run 1: OK (census=46, triples=130)
  W615 court run 2: OK (census=46, triples=130)
```

Court `test/xaas/airo_shacl_court_test.exs`, 5 assertions-groups:

- C6 pin gate: on-disk vocab sha256 == 6274d2d8… (passes).
- C1 parse-back: emitted profile re-parses; triple count matches (130).
- C2 census: shapes == AIRO classes (46 == 46), ×2 runs, byte-identical output
  on recompile (determinism asserted in-court).
- C3 namespace purity: every IRI under sh/airo/rdf/rdfs only; blank nodes
  (sh:or list nodes) excluded as structural. Falsified twice mid-build (blank
  node, rdf:type) and repaired — non-vacuous.
- C4 malformed-instance mutation: `w615:OrphanControl a airo:RiskControl .` with
  no binding predicate and an uncited `airo:Risk` → both violations fire; adding
  `airo:mitigatesRiskConcept` clears the control violation (non-vacuity lens).
- C5 real instance graph: 0 violations, 0 dead file citations across the 18
  `file://` seeAlso paths in `priv/airo_risk_description.ttl`.

## Disclosed boundary (UNSUPPORTED, engine-level)

**No SHACL validator exists in this dependency tree.** The C4/C5 constraint
checks run through `violations/1` / `check_file_citations/1` — a hand-rolled
checker implementing exactly the three compiled constraints — NOT a conformant
SHACL engine. The emitted Turtle is standards-shaped SHACL; conformance of the
profile under a real engine (pySHACL / shacl2) is UNKNOWN until a validator is
admitted into the tree. The `sh:or`/inverse-path profile is the projection of
the same constraint set the hand-rolled checker implements, so the mapping is
stated, but the engine gap is real and named here.

## Falsifiers

- `mix test test/xaas/airo_shacl_court_test.exs` red ⇒ standing downgraded.
- Vocab byte drift (sha ≠ 6274d2d8…) ⇒ C6 fails, compilation refuses implicitly.
- A control in the instance graph dropping its binding predicate ⇒ C5 fails.
- Profile not byte-identical on recompile ⇒ determinism assert fails.

## Lane hygiene

`_build-laneW615` deletion was denied by the permission system in this lane's
session — **left in place for the coordinator to delete** (contains only the
lane's test build; no source state). Files
written (uncommitted, coordinator owns integration):

- `priv/airo/profile.shacl.ttl` (generated, 159 lines)
- `lib/mix/tasks/xaas.airo.compile_shacl.ex`
- `test/xaas/airo_shacl_court_test.exs`
- this receipt
