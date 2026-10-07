# W622 Receipt — WP-5/OS-13 consumer-mode sync flag (fixtureOnly emission suppression)

Standing: PARTIAL_ALIVE (implemented + tested in ~/ggen working tree; NOT committed, per directive)
Date: 2026-10-07
Subject: `~/ggen` working tree at HEAD `ba837d7437367dd84543c07b5179c88e214cbff4` (branch — uncommitted lane edits on top; only the five files below are this lane's diff, everything else in `git status` pre-dates this lane)

## Design

Consumer mode is opt-in per consumer and flows from two sanctioned sources (either enables):

1. **Run flag**: `ggen sync run --consumer-mode` — new `bool` verb arg (`SyncOptions.consumer_mode`).
2. **Permanent config key**: `[templates] consumer_mode = true` in the consumer's `ggen.toml` — a `#[serde(default)]` backward-compatible addition to `Templates` (the same sanctioned pattern `aggregate_modules` uses under `deny_unknown_fields`).

Effective = `opts.consumer_mode || config.templates.consumer_mode`. When on, sync collects the
fixtureOnly-marked subject set ONCE from the post-enrich union graph with a typed SPARQL probe:

    SELECT ?s WHERE { ?s ?p true . FILTER(CONTAINS(STR(?p), "fixtureOnly")) }

(predicate-substring match covers `aex:fixtureOnly` and the mirrored `pr:priorArtFixtureOnly`
idiom W610 found; value must be literal-true, matching the pack gates' `FILTER NOT EXISTS { ?s aex:fixtureOnly true }`
exemption semantics). Every candidate write is provenance-checked before joining `pending`, at
the three projection sites in the generate stage of `crates/ggen-engine/src/sync.rs`:

- **Row fan-out** (`to:` contains `{{`): the driving row's JSON is walked; if any string value
  contains a marked subject IRI, the write is suppressed.
- **Aggregate (`for_each:` + static `to:`) and whole-file** projections: the named query
  results are walked; any reference to a marked subject suppresses the output whole.

Suppressed outputs never reach `apply`, never run `sh_before`/`sh_after` hooks, never join the
`aggregate_modules` aggregator (it mounts from `pending`, post-filter), and never enter the
receipt `outputs` map. Each suppression is a typed, deterministic skip in the report's
`skipped`/`decisions`:

    consumer-mode: row references fixtureOnly-marked spec <http://example.com/aex#AuditTrailSpec> — installer emission suppressed

Fail-closed direction is deliberate: flag off (default) = current behavior byte-identical
(proven by test 1); flag on = suppression. Note: with the flag ON, any consumer pack template
that renders a whole-file projection naming a marked spec gets suppressed — this is the
intended fail-closed semantic; a pack author must unmark or split the projection. With the
flag OFF nothing changes for existing consumers.

## Files changed (this lane's complete diff, all in ~/ggen)

| file | change |
|---|---|
| `crates/ggen-engine/src/sync.rs` | `SyncOptions.consumer_mode`; `fixture_only_subjects()` SPARQL probe; `fixture_reference_in()` JSON walk; consumer-mode filter at the three projection push sites with typed skip recording |
| `crates/ggen-engine/src/config.rs` | `Templates.consumer_mode` (`#[serde(default)]` key, doc) |
| `crates/ggen-engine/src/pack.rs` | test-only: `Templates` struct literal gains `consumer_mode: false` |
| `crates/ggen-engine/src/verbs/handlers.rs` | `handle_sync_run(dry_run, watch, consumer_mode)` plumbing |
| `crates/ggen-engine/src/verbs/sync.rs` | `sync_run` verb gains `consumer_mode: bool` arg → `--consumer-mode` |
| `crates/ggen-engine/tests/consumer_mode_fixture_only_e2e.rs` | NEW — 4 Chicago-style e2e courts (real tempdir FS + real GraphLaw engine + real Tera; no mocks) |

## Boundary disclosures

- `crates/ggen-engine/src/verbs/sync.rs` is marked GENERATED ("Do not edit by hand", from
  `schema/praxis.ttl`, which no longer exists at that path). The flag is a hand extension of
  the generated verb — handwritten=irreducible residue, disclosed here. If the verb surface
  is ever regenerated, `--consumer-mode` must be re-added or the flag is lost while
  `SyncOptions`/config-key paths keep working.
- `generation_rules.rs::run` also takes `SyncOptions`; consumer-mode filtering is implemented
  in the frontmatter-project `sync()` path only. The declarative-rules path ignores
  `consumer_mode` today — typed boundary, not silently wrong: the fixtureOnly marker idiom
  exists only in frontmatter-projection packs (ggen-marketplace ash-extension packs).
- IRIs must appear in row values for detection; IRIs bind as bare IRI strings
  (`term_to_engine_value` → `EngineValue::String`), so substring detection over row JSON is
  sound for IRI-bound variables. A projection whose rows bind only label literals while the
  spec IRI never appears in any bound variable would evade detection — the fan-out idiom in
  every real pack binds the spec subject itself, so this is theoretical; noted as the
  detection boundary.
- ggen-marketplace sibling edits: untouched, uncommitted (per directive).

## Verification (real commands, real tails)

Toolchain: `cargo` at `~/.cargo/bin`; isolated `CARGO_TARGET_DIR=target-laneW622`.

    cargo check -p ggen-engine -p ggen -p ggen-mcp        → Finished `dev` profile in 1m 05s (0 errors)
    cargo check -p ggen-engine                            → Finished in 0.81s (pass 2)
    cargo test -p ggen-engine --lib                       → 204 passed; 0 failed; 2 ignored (runs 1 and 2)
    cargo test -p ggen-engine --test consumer_mode_fixture_only_e2e   → 4 passed; 0 failed (runs 1 and 2)
    cargo test -p ggen-engine --test frontmatter_fields_e2e --test cross_pack_matrix → 14 + 7 passed; 0 failed

New e2e courts (all passing ×2):
1. `default_off_emits_both_specs_into_lib` — flag off = current behavior, zero skips.
2. `consumer_mode_flag_suppresses_fixture_spec_but_emits_live_spec` — fixture-marked spec's `lib/audit_trail.ex` absent on disk, live spec still emits, exactly one typed skip naming the IRI.
3. `config_key_consumer_mode_is_permanent_per_consumer` — `[templates] consumer_mode = true` alone (flag false) suppresses both fixture-derived outputs.
4. `whole_file_projection_touching_fixture_spec_is_suppressed` — whole projection naming a marked spec is suppressed with typed skip.

## Not done (typed)

- **NOT-COMMITTED**: nothing committed anywhere (directive); working-tree-only diff.
- **BLOCKED(local-policy)**: lane build root `~/ggen/target-laneW622` (11 GB) could not be
  deleted — `rm -rf` was denied by the permission system twice. Left on disk; coordinator
  should remove it (single `rm -rf /Users/sac/ggen/target-laneW622`).
- ggen-marketplace pack-internal probe specs deliberately not marked (W610's flagged concern:
  marking live qualification surfaces would weaken `100_projection_isolation_contract.rq`'s
  exemption) — unchanged from W610's standing.
