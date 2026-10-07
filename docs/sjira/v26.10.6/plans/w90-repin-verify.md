# W90 — Re-pin ash-extension pack to marketplace tip + verify

Standing: **BLOCKED** (sync refuses at tip; falsifier outcome N/A — no generation occurred)

## Subject

- Repo: /Users/sac/ash_surface (branch feat/playwright-surface, no commits made)
- ggen 26.9.28 ambient, PATH=$HOME/.asdf/shims
- Old pin: `baa5f117deefb3b84f7bd653e65e9fe8d9b1d2fa`
- Target tip (`git -C ~/ggen-marketplace rev-parse origin/main`): **`3ddbfeb7e0b8824e1022f9edb043c65b5319f82e`**
  - W80's note that tip "moved past 3ddbfeb7" is falsified: origin/main IS 3ddbfeb7e0b8824e1022f9edb043c65b5319f82e right now.

## Actions (real commands, real output)

1. Confirmed tip: `git -C ~/ggen-marketplace rev-parse origin/main` → 3ddbfeb7e0b8824e1022f9edb043c65b5319f82e.
2. Edited ~/ash_surface/ggen.toml line 8, pin field only. New full line:
   `ash-extension = { git = "https://github.com/seanchatmangpt/ggen-marketplace.git", version = "3ddbfeb7e0b8824e1022f9edb043c65b5319f82e", subdir = "packs/ash-extension-pack" }`
3. `ggen sync run` (run 1): FAILED validation before any generation —
   `ERROR: CLI execution failed: Command execution failed: validation error: [FM-PACK-008] pack ash-extension (source git:...@baa5f117...) content hash mismatch: ggen.lock has blake3:4e03a62f... but pack on disk hashes to blake3:055d29d9...`. Remediation per error: delete ggen.lock to re-lock.
4. Snapshot `git status --porcelain` → /tmp/w90-pre-status.txt (63 lines), `rm ggen.lock`, rerun `ggen sync run` (run 2): re-lock passed, then FAILED at pack gate —
   `[FM-PACK-013] pack ash-extension gate 120_spark_dead_surface.rq refused the sync against the union graph: no decorative Spark surface. Every aex:* property declared a rdf:Property ... SELECT returned 58 row(s); first row: { ?s = https://github.com/seanchatmangpt/ash_surface#admittedRef }`. Remediation paths offered: fix facts, or fix gate query.
5. Falsifier (W80): `git status --short` shows 63 pre-existing deltas (lane work) + `M ggen.toml` + **`D ggen.lock`**. Critically: `diff` of pre-run vs post-run status = **empty** — both sync runs changed NOTHING in the tree beyond ggen.toml (my edit) and ggen.lock (my deletion). No generated file was touched; the byte-identical prediction is neither confirmed nor falsified because sync never reached generation.

## Root cause of BLOCKED (from real file reads)

`ggen-marketplace:packs/ash-extension-pack/gates/120_spark_dead_surface.rq` is NEW at tip
(git show baa5f117:...gate → "exists on disk, but not in baa5f117"; pack diff baa5f117..3ddbfeb7 = 94 files, +11231/−218).
The gate query is over-broad: `?s a rdf:Property` with an aex:-only VALUES allowlist — it matches ANY
rdf:Property in the union graph, including ash_surface's 58 `surf:` declarations
(~/ash_surface/ontology.ttl line 800: `surf:admittedRef a rdf:Property`). The pack tip is incompatible
with any project whose union graph declares non-aex: rdf:Property terms.

## Verify gates (on the unchanged tree; failures are pre-existing, not sync-introduced)

- `MIX_ENV=test mix test test/conformance` (real run): **4/18 passed, 14 failed** — pre-existing on this branch state; sync changed no source.
- `npm test` (real run): **371 tests, 367 pass, 0 fail, 4 skipped** — clean.

## End state (not reverted, per rules)

- ~/ash_surface/ggen.toml: pin now 3ddbfeb7e0b8824e1022f9edb043c65b5319f82e (modified, uncommitted)
- ~/ash_surface/ggen.lock: DELETED (untracked-removal; old content recoverable via `git checkout -- ggen.lock`)
- No other tree changes; no git mutations; no generated-file hand edits.

## Typed failure summary

- REFUSED(FM-PACK-008) run 1: lock hash mismatch vs stale baa5f117 lock — resolved by re-lock.
- REFUSED(FM-PACK-013) run 2: tip pack gate 120_spark_dead_surface.rq over-broad (`?s a rdf:Property` without aex: prefix filter) vs project `surf:` properties. Fix belongs in the pack gate query (add `FILTER(STRSTARTS(STR(?s), "http://seanchatmangpt.github.io/packs/ash-extension-core#"))` or extend allowlist), not in ash_surface.
- UNVERIFIED: byte-identical projection at tip — falsifier unrun, sync never generated.