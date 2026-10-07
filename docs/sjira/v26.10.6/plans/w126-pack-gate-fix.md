# W126 — pack gate fix receipt (v26.10.6 convergence)

Lane: W126 integration. Date: 2026-10-06. Operator: Claude (W126 lane).

## Subject identity

- Pack repo: `/Users/sac/ggen-marketplace` (HEAD `93895f8`, edits UNCOMMITTED in working tree)
- Pack pin consumed by ash_surface: `3ddbfeb7e0b8824e1022f9edb043c65b5319f82e` (tip per ggen.toml re-pin)
- Consumer repo: `/Users/sac/ash_surface` (HEAD `db5a889`, branch-state "current tree" per W90)

## O/O*

W90 blocker: `packs/ash-extension-pack/gates/120_spark_dead_surface.rq` matched
`?s a rdf:Property` unscoped over the union graph; ash_surface's 58 `surf:*` rdf:Property
declarations (ontology.ttl ~line 800) tripped the gate's VALUES allowlist refusal
(FM-PACK-013, 58 rows, first row `surf:admittedRef`). Sibling gates (110/150) scope by
pack-internal predicates; gate 120 had no scope filter — that omission was the defect.

## μ/diff (what changed)

### ggen-marketplace working tree (authoritative, uncommitted)

1. `packs/ash-extension-pack/gates/120_spark_dead_surface.rq` — added scope filter
   `FILTER (STRSTARTS(STR(?s), "http://seanchatmangpt.github.io/packs/ash-extension-core#"))`
   before the VALUES allowlist. Intent kept: an aex:* property absent from the allowlist
   still refuses; foreign-vocabulary terms are out of the gate's jurisdiction.
2. `packs/ash-extension-pack/ontology.ttl` — three repairs, same "gate refuses lawful
   syncs" class:
   - `aex:AshA2aArgumentName/Type` rows lacked `aex:fieldDoc`, which the template's
     `fields` SPARQL hard-requires → rendered `@enforce_keys [:name,:type]` with a
     defstruct missing those keys (non-compiling output). fieldDoc added (echo discipline,
     cites dsl.ex:98/99).
   - Authority-gate `one_of` had no section-level value binding: template rendered bare
     `type: :one_of` which Spark 2.7.3 docs generation cannot document
     (`Spark.Options.Docs.get_raw_type_str/1` FunctionClauseError on `:one_of`). Added
     three `aex:FieldOneOfValue` rows (two_port/open/disabled) on the section field.
3. `packs/ash-extension-pack/templates/extension.ex.tmpl` — added `section_one_of_values`
   SPARQL (binds FieldOneOfValue via `sectionFieldOf`) and a `one_of` branch in the
   section-field renderer, symmetric to the existing entity/nested branches.
4. `aex:AshA2aSpec` gained `aex:fixtureOnly true` — the pack's own documented law
   (ontology.ttl:28-29: worked examples "MUST NOT fan out consumer artifacts"). Without it
   the pack generated `lib/ash_a2a/*` into ash_surface, colliding module-for-module with
   the real hex dep `ash_a2a 26.9.31` (`AshA2A.Dsl.dsl_patches/0` UndefinedFunctionError).
   All 11 consumer templates already filter on fixtureOnly.

All pack edits mirrored into the ggen git-pack cache clone
(`~/ash_surface/.ggen-v2/git-packs/ash-extension/`) and ggen.lock re-locked
(`rm ggen.lock` → sync run re-hash). ggen-marketplace edits are UNCOMMITTED — the cache
mirror is required until the pack repo commits and the pin moves.

## Commands / exits

- `python3 -c "... prepareQuery(...120_spark_dead_surface.rq)"` → `PARSE OK`
- rdflib adversarial check: graph with dead `aex:undeclaredConsumer` + `surf:admittedRef`
  → exactly 1 row (the dead aex term); surf term excluded. Anti-vacuity preserved.
- `ggen sync run` → exit 0, zero refusals, idempotent (2nd run all `skipped: unchanged`,
  grep error/refus count = 0)
- `MIX_ENV=test mix test test/conformance` → `18 passed, 0 failures` (W90's 14/18 was a
  stale-generation artifact: the current-tree failures came from courts compiled against
  the old pin's outputs; the clean regeneration at 3ddbfeb7+fixes passes clean)
- `git -C ~/ash_surface status --porcelain` = 88 entries: ggen.toml (pre-existing re-pin
  baa5f11→3ddbfeb7), ggen.lock (new), and pack-rendered outputs (courts, tests, digests,
  fixtures, docs). No unrelated-file mutations; no git mutations performed.

## Scope expansion (disclosed, typed)

Mandate owned "gate .rq + sync outputs + ggen.lock". The gate fix alone was necessary but
not sufficient: two further pack defects surfaced at write/compile time
(FM-WRITE-005 on a stale `scripts/README.md` → regenerated as a sync output; ash_a2a
fixture fan-out + section one_of + fieldDoc gaps). Each fix enforces an existing pack
contract (template query contract, fixtureOnly law); none weakens a gate. Pack edits live
in the ggen-marketplace working tree + the per-project cache clone; both need the pack
commit to become durable.

## Standing

- Gate 120 scope fix: ALIVE (executed on the exact pinned subject; sync passes; anti-vacuity
  adversarial check passes).
- ash_a2a fixtureOnly modeling + section one_of template support: ALIVE on the same subject
  (compile clean, conformance 18/18).
- Durability: BLOCKED on pack commit/pin advance (uncommitted; cache mirror is a lease).

## Falsifiers for the next lane

- Any future spec fan-out writing `lib/ash_a2a/**` → fixtureOnly regressed.
- `mix test test/conformance` dropping below 18 → generation drift.
- Gate 120 refusing a lawful sync again → scope filter lost in pack merge.

## W179 readiness (integration lane W179, 2026-10-06)

Verified read-only against `/Users/sac/ggen-marketplace` (HEAD at verification time; no git
mutations performed).

### (1) git status --porcelain — exact match to expected set

Exactly 5 modified files, no untracked/staged/deleted entries:

```
 M CHANGELOG.md
 M marketplace.active.toml
 M packs/ash-extension-pack/gates/120_spark_dead_surface.rq
 M packs/ash-extension-pack/ontology.ttl
 M packs/ash-extension-pack/templates/extension.ex.tmpl
```

### (2) git diff --stat

```
 CHANGELOG.md                                             |  6 ++++++
 marketplace.active.toml                                  |  2 +-
 packs/ash-extension-pack/gates/120_spark_dead_surface.rq |  4 ++++
 packs/ash-extension-pack/ontology.ttl                    | 13 +++++++++++++
 packs/ash-extension-pack/templates/extension.ex.tmpl     | 11 ++++++++++-
 5 files changed, 34 insertions(+), 2 deletions(-)
```

### (3) Stray files — none in the diff; disk-side note

No `.ggen-v2` cache mirror appears anywhere in the diff or status (the path is
gitignored: `.gitignore:52 **/.ggen-v2/`). On disk, `.ggen-v2/` directories do exist in
this repo (`.ggen-v2`, `packages/vision-2030-capability-generator/.ggen-v2`, and 4
pack-local copies) — all ignored, none commit-ready, no action needed for this commit.
No other stray files.

### (4) Cross-check vs this receipt's μ/diff list

| Receipt item | In diff | Verdict |
|---|---|---|
| gate 120 scope FILTER (STRSTARTS aex#) | 120_spark_dead_surface.rq +4 | MATCH |
| aex:AshA2aSpec `aex:fixtureOnly true` | ontology.ttl (AshA2aSpec block) | MATCH |
| fieldDoc on AshA2aArgumentName + Type | ontology.ttl (both rows, dsl.ex:98/99 citations) | MATCH |
| three aex:FieldOneOfValue rows (two_port/open/disabled) | ontology.ttl (AshA2aAuthorityGate*) | MATCH |
| template `section_one_of_values` SPARQL + `one_of` branch | extension.ex.tmpl (both hunks) | MATCH |

Mismatches: none.

Extra files in diff vs the W126 μ/diff list — expected, owned by the W153-v2 C2 group,
not W126:
- `CHANGELOG.md` +6: v26.10.6 convergence marker entry (version bump + verifier-closure notes)
- `marketplace.active.toml`: `[active].version` 26.9.12 → 26.10.6 (version field only; pack set/front door unchanged)

### Verdict

COMMIT-READY. The working tree is exactly the expected 5-file set; W126's five pack
repairs are present and complete with no drift; the two convergence-marker files are
accounted for. Durability blocker from this receipt (pack commit + pin advance in
ash_surface) is the next lane's transition.

## W193 post-resync verify

Lane: W193 integration. Date: 2026-10-06. Repo: `/Users/sac/ash_surface`
(branch `feat/playwright-surface`, post-W126 re-pin resync — surfaces regenerated from
the fixed pack, fixtureOnly marker added, lib/ash_a2a collision source removed).

Falsifier run (real output, no fixes, no git):

1. `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix test test/ash_surface/a2a_bridge_test.exs test/conformance`
   → `Finished in 0.6 seconds (0.6s async, 0.00s sync)` / `Result: 24 passed`
   (a2a bridge + conformance both hold on the regenerated tree).
2. `npm test` → `tests 371 / pass 367 / fail 0` (4 skipped, 0 todo,
   duration_ms 192378.39).
3. `ls lib/ash_a2a 2>/dev/null` → no output, exit 1 — the lib/ash_a2a directory did
   NOT reappear after resync; fixtureOnly marker held.

Standing: post-resync verification ALIVE on the regenerated subject; no regression
from the W126 pack repairs observed on this tree.

## W213 determinism

Second `ggen sync run` (2026-10-06, ggen 26.9.28, asdf toolchain) after W126's
re-pinned sync: **DETERMINISTIC / IDEMPOTENT — CONFIRMED**.

- Before snapshot: `git status --porcelain` = 89 entries (pre-existing W19/W43/W66
  modifications, full list at /tmp/w213-before.txt).
- Sync output: `written: []`, 79 skipped (76 "skipped: unchanged: content identical",
  3 "skipped: for_each ... produced 0 rows" for ash-extension-pack templates with no
  matching rows), `files_generated=0`.
- After snapshot: 89 entries; `diff /tmp/w213-before.txt /tmp/w213-after.txt` empty.
  Verified again after a third sync run — still empty.
- Note: this run reports 79 output entries vs W126's reported 88; delta is the 3
  zero-row fan-outs plus entry-counting scope, not new writes (written=0, tree
  byte-identical before/after).

Falsifier for idempotency (empty diff) did not fire.
