# W355 — OS-13 staging: pack marker census + durable-fix draft (v26.10.6 convergence)

Date: 2026-10-06. Lane: W355. Mode: read-only on `/Users/sac/ggen-marketplace` and
`/Users/sac/ash_surface`; all pack-side edits below are PROPOSED text only — no pack edits
(pack changes are pin-gated; OS-13 is operator/next-cycle). No git actions taken on any repo.

## Subject identity

- ggen-marketplace: HEAD `93895f8`, working tree = the exact W126/W153 5-file uncommitted
  set (CHANGELOG.md, marketplace.active.toml, gates/120_spark_dead_surface.rq,
  ontology.ttl, templates/extension.ex.tmpl) — no drift vs W179's diff census.
- Pack pin consumed by ash_surface: `3ddbfeb7e0b8824e1022f9edb043c65b5319f82e`
  (`/Users/sac/ash_surface/ggen.toml` `[packs] ash-extension … subdir = packs/ash-extension-pack`).
- Sync source actually consumed by `ggen sync run` in ash_surface: the ggen cache clone
  `/Users/sac/ash_surface/.ggen-v2/git-packs/ash-extension` (git HEAD `3ddbfeb7`; its
  **working tree** carries W126's uncommitted mirror: gate-120 scope fix, AshA2aSpec
  fixtureOnly, fieldDoc/one_of, template support).

## Marker census (verified on disk 2026-10-06)

`aex:fixtureOnly` is declared once (`packs/ash-extension-pack/ontology.ttl:28`,
domain `aex:AshExtensionSpec`). Four `aex:AshExtensionSpec` individuals exist in the
ash-extension-pack. Status per individual, in each of the two places the pack text lives:

| individual | marketplace wt @93895f8 | cache-clone wt (the sync source) | consumer artifacts when unmarked |
|---|---|---|---|
| aex:AshA2aSpec | MARKED (:1590) | MARKED | lib/ash_a2a/** |
| aex:AuditTrailSpec | MARKED (:271) | MARKED | lib/audit_trail/**, lib/mix/tasks/audit_trail.install.ex |
| aex:AshR2RMLSpec | MARKED (:343) | **UNMARKED** | lib/ash_r2rml/**, lib/mix/tasks/ash_r2rml.install.ex |
| aex:NotificationExtensionSpec | MARKED (:556) | **UNMARKED** | lib/notification_extension/**, lib/mix/tasks/notification_extension.install.ex |

Census greps (real output):

- marketplace: `grep -n "fixtureOnly true" packs/ash-extension-pack/ontology.ttl`
  → `271: 343: 556: 1590:` (4 markers, all four individuals marked).
- cache clone: `grep -c "fixtureOnly true"
  .ggen-v2/git-packs/ash-extension/packs/ash-extension-pack/ontology.ttl` → `1`
  (only AshA2aSpec, at the same position as marketplace's :1590 minus the three W264 lines).
- cache clone core-pack (not the synced subdir, noted for completeness):
  `grep -c "fixtureOnly true" …/ash-extension-core-pack/ontology.ttl` → `2`
  (AuditTrailSpec :106, AshR2RMLSpec :168 — duplicates of the pack-side individuals).

### Root cause of the recurring emission

W264 added 3 markers (AshR2RMLSpec, AuditTrailSpec, NotificationExtensionSpec) to the
**marketplace working tree only**; the W126 procedure's required step — mirror pack edits
into the per-project cache clone — was never re-run for the W264 additions. The cache
clone is what `ggen sync run` actually reads, so any resync from the current cache state
re-emits `lib/ash_r2rml/`, `lib/audit_trail/`, `lib/notification_extension/` and their
`lib/mix/tasks/*.install.ex` files into ash_surface. W230's quarantine of `lib/ash_r2rml`
removed the shadow module that broke the xaas runtime; it did not remove the emission
source, and W230 explicitly noted the residual `lib/mix/tasks/ash_r2rml.install.ex`
warning (W265).

### ash_surface contamination state (verified 2026-10-06)

- `lib/ash_r2rml/` — ABSENT (W230 quarantine held; quarantine copy still at
  `/tmp/w230-quarantine/ash_surface-lib-ash_r2rml/` — /tmp, non-durable).
- `lib/ash_a2a/` — ABSENT.
- `lib/audit_trail/` — PRESENT (7 files: info, persist, receipt, receipted_action, reactor/,
  resource, verify; mtime 2026-10-06 13:10:32, i.e. pre-W264 emission, gitignored via
  `.gitignore:29`).
- `lib/notification_extension/` — PRESENT (7 files, same timestamp, `.gitignore:30`).
- `lib/mix/tasks/ash_r2rml.install.ex`, `audit_trail.install.ex`,
  `notification_extension.install.ex` — ALL PRESENT (gitignored, `.gitignore:35/37/38`).
  These are the W265-noted warning residue: with `lib/ash_r2rml` gone the install task's
  `use`/alias of the quarantined module still fails resolution at task-help/compile scan time.
- All emission products are untracked + gitignored strays; nothing is commit-ready.
- A same-name duplication exists inside the pack itself: `ash-extension-core-pack`
  defines its own `aex:AuditTrailSpec`/`aex:AshR2RMLSpec` (marked) while
  `ash-extension-pack` redefines them — future marker work must touch the synced pack
  (`ash-extension-pack`, per ggen.toml `subdir`), not only core-pack.

## Proposed durable fix (pack-side; PROPOSED TTL snippets, do not commit from this lane)

Mirror W264's three marketplace additions into the sync source. Exact snippets, W126/W264
shape (`aex:fixtureOnly true ;` as the first predicate line of the spec individual):

In `/Users/sac/ash_surface/.ggen-v2/git-gens/…` — correction: in
`/Users/sac/ash_surface/.ggen-v2/git-packs/ash-extension/packs/ash-extension-pack/ontology.ttl`:

```turtle
# 1. aex:AshR2RMLSpec — insert immediately after the subject line
aex:AshR2RMLSpec a aex:AshExtensionSpec ;
    aex:fixtureOnly true ;
    aex:packageName "ash_r2rml" ;
```

```turtle
# 2. aex:AuditTrailSpec — already present in the cache working tree (line 271);
#    NO cache edit needed. Listed only to prevent a spurious re-add (duplicate
#    aex:fixtureOnly on one subject would be a new defect class).
```

```
# 3. aex:NotificationExtensionSpec — insert immediately after the subject line
aex:NotificationExtensionSpec a aex:AshExtensionSpec ;
    aex:fixtureOnly true ;
    aex:packageName "notification_extension" ;
```

Then re-run the W126 mirror discipline end-to-end: edit cache clone, `ggen sync run`
(expect `written: []` / all `skipped: unchanged` once the stale strays are removed), and
quarantine the remaining strays the same way W230 did (`mv` to /tmp or durable location;
lib/audit_trail, lib/notification_extension, and the three `lib/mix/tasks/*.install.ex`).

**Operator next-cycle (the actual durable fix)**: commit the marketplace working tree
(all 4 markers + gate-120 fix), advance the ash_surface pin past 3ddbfeb7, delete the
cache mirror dependence. Until the pin advances, the cache-clone working tree is a lease
and the 3-line mirror above is the minimum viable guard.

## Alternative: consumer-mode emission gate (sync-tooling flag)

If locatable read-only — it is: `/Users/sac/ggen/crates/ggen-engine/src/sync.rs`.

- `SyncOptions.dry_run: bool` exists (sync.rs:116) and already gates which resolver runs
  (sync.rs:278-290). A sibling consumer option — e.g. `fixture_only_skip: bool` or a
  `[sync] exclude_paths = [...]` list read from the consumer's `ggen.toml` — would gate at
  the Stage-5 write loop (sync.rs:~827 `let mut skipped: Vec<(PathBuf, String)> = …`,
  per-file `when:` guard region ~sync.rs:868), turning each fixture-only artifact into a
  `skipped: fixtureOnly` entry instead of a write.
- This is strictly secondary to the pack fix: a consumer flag papers over a pack whose
  sync source is stale, and the W126 pack law (ontology.ttl:28-29: fixtureOnly individuals
  "MUST NOT fan out consumer artifacts") already places the obligation on the pack side.

## Falsifiers

- Re-sync from the current cache state re-emits `lib/ash_r2rml/` (testable: run
  `ggen sync run` in ash_surface and `ls lib/ash_r2rml` — expect it to appear until the
  mirror is applied). Not executed in this lane (would recontaminate the tree).
- Duplicate-marker guard: `grep -c "fixtureOnly true"` per individual must stay exactly 1
  per subject after any next-cycle edit.
- Cache-clone lease: if the marketplace pack commits and the ash_surface pin advances
  without deleting `.ggen-v2/git-packs/ash-extension` working-tree drift, a stale cache
  working tree can silently win again — sync must be re-verified after any pin advance.
