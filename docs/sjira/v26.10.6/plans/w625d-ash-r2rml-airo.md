# W625d — ash_r2rml AIRo risk description (AIRo wiring wave, ash_r2rml leg)

## Order

Author an AIRo (https://w3id.org/airo) risk description of ash_r2rml's R2RML→Ash
mapping engine: the engine as `airo:AISystem`, real documented hazards as
risk sources, the real fail-closed gates as `airo:RiskControl`s, honest
qualitative likelihood/severity — plus an ExUnit court asserting the
description against the real vocabulary and the real repo.

## Manufacture

### Subjects (one canonical checkout, never committed)

- `/Users/sac/ash_r2rml/priv/airo_risk_description.ttl` — AIRo description (hand-written; no generator profile exists for AIRo instance data in this repo, so handwritten with typed justification: UNSUPPORTED(generator-capability) — no airo pack bound).
- `/Users/sac/ash_r2rml/test/airo_risk_description_test.exs` — ExUnit court.
- `/Users/sac/ash_r2rml/test/fixtures/airo_vocabulary_snapshot.ttl` — byte-exact vendored airo.ttl.

### Vocabulary fetch

- `curl -sL https://raw.githubusercontent.com/DelaramGlp/airo/main/airo.ttl`
- sha256 `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469` (matches order's `6274d2d8…`), 974 lines, 219 `airo:` token hits.
- Vendored byte-exact; the test asserts the sha256 of the snapshot on disk.

### AIRo description content

`airo:AISystem` `r2rml-ash-mapping-engine` with two components, three risks,
four controls, three consequences, likelihood/severity individuals:

| element | cites (real, on-disk) |
|---|---|
| Risk: empty-contract admission | hazard neighbor `lib/ash_r2rml/vkg.ex:52` (catch-all query/1 clause class); consequence "silently admitted empty VKG" |
| Risk: mapping misclassification | `:REFUSED_UNKNOWN_ATTRIBUTE` tautology-by-breadth in `lib/ash_r2rml/admission.ex` verify_attributes (377–392) — one tag reused for non-atom names / non-string columns / duplicates |
| Risk: unknownAshName derivation | shape-checked derived names naming no real Ash attribute; enforced at `lib/ash_r2rml/resource.ex:362,751`, `lib/ash_r2rml/alignment.ex:39`, `lib/ash_r2rml/provenance.ex:113,150,175` |
| Control: Registry.admit non-empty refusal | `lib/ash_r2rml/vkg/registry.ex:16-27` (head-matched on non-empty list; empty/non-list → refusal) |
| Control: unproven-equivalence / hash refusal | `:REFUSED_UNPROVEN_EQUIVALENCE` at `lib/ash_r2rml/admission.ex` (51,73,155,207,257,265,467,596,632), `lib/ash_r2rml/compiler.ex:194`, sha256 identity in `lib/ash_r2rml/integrity.ex` |
| Control: r2rml test suite | `test/vkg/v26_9_28_admission_test.exs`, `v26_9_28_verify_test.exs`, `test/mapping_changeset_test.exs`, `test/adversarial_closure_test.exs`, `test/equivalence_and_falsifier_test.exs` |
| Control: dual-safe Map.update (w609-era) | `lib/ash_r2rml/vkg/consumer/engineering.ex:19`, `lib/ash_r2rml/knowledge_hooks.ex:1336`, `lib/ash_r2rml/knowledge_hook/{datalog,rdf,shacl}.ex` (386/303/288) |

Likelihood/severity are declared qualitative individuals (`likelihood-low`,
`likelihood-medium`, `severity-medium`) with one-sentence justifications —
engineering judgment, not measurements.

### Court (test)

`test/airo_risk_description_test.exs`, 6 tests, Chicago-style (real files,
real hash, no mocks):

1. description exists, non-empty
2. structural Turtle: every used prefix declared, `<>` balanced, AISystem typed
3. AISystem/Risk/RiskSource-Hazard/RiskControl/Consequence/Likelihood/Severity terms present
4. every cited `lib/…`/`test/…` path exists on disk (line numbers stripped)
5. every `airo:` term used appears in the vendored vocabulary (comment-stripped)
6. vendored snapshot sha256 == fetched sha256

The court fired twice during development on real defects (trailing `.` in a
cited path; `shacl.ex:288` misread as prefix `ex:`) — both fixed in the
court's extractors, not by editing the description to dodge.

## Verification receipt

```
$ cd /Users/sac/ash_r2rml && PATH=$HOME/.asdf/shims:$PATH \
  MIX_ENV=test MIX_BUILD_ROOT=_build-laneW625d \
  mix test test/airo_risk_description_test.exs
Running ExUnit with seed: 419978, max_cases: 32
......
Finished in 0.07 seconds (0.07s async, 0.00s sync)
6 tests, 0 failures
```

Full-suite run verified (`MIX_BUILD_ROOT=_build-laneW625d mix test`, exit 0):

```
Finished in 15.3 seconds (11.7s async, 3.6s sync)
1004 tests, 0 failures, 9 skipped
```

The TTL's control description originally claimed "998 tests, 0 failures";
the measured suite is 1004/0/9 skipped — the TTL was corrected to the real
number before handoff.

## Standing

- Description: ALIVE at the exact files above (uncommitted, per lane law).
- Handwritten residue: justified — no AIRo instance-data generator pack is
  bound in ash_r2rml (UNSUPPORTED generator-capability receipt).
- No worktrees used; no commits made; `_build-laneW625d` is a lane lease to
  be deleted at integration.
