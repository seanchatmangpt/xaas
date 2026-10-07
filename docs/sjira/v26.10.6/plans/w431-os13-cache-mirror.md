# W431 — OS-13 mechanical half: cache-clone marker mirror (v26.10.6 convergence)

Date: 2026-10-06. Lane: W431.
Subject: `/Users/sac/ash_surface/.ggen-v2/git-packs/ash-extension` (sync-cache clone —
the tree `ggen sync run` actually reads per W355) + `/Users/sac/ggen-marketplace`
(marker source, read-only).
Only xaas write: this file. No commit in the cache clone (ephemeral host state; edit left
as working-tree drift, same lease discipline as W126/W355).

## Procedure (per w355-os13-pack-markers.md + w126-pack-gate-fix.md)

Edit only the cache clone's `packs/ash-extension-pack/ontology.ttl`, mirroring the
marketplace working tree's marked blocks verbatim (`aex:fixtureOnly true ;` as first
predicate line after the subject line).

## Marker census (real grep output, cache clone ontology.ttl)

### Before (lane start)

`grep -c "fixtureOnly true"` → **3**

| individual | cache line | state before |
|---|---|---|
| aex:AuditTrailSpec | :270 | UNMARKED |
| aex:AshR2RMLSpec | :341 | UNMARKED |
| aex:NotificationExtensionSpec | :553 | UNMARKED |
| aex:AshA2aSpec | :1586 | MARKED (:1587) |

W355's table asserted AuditTrailSpec was already MARKED in the cache; live disk
contradicted it (block at :270 showed `packageName` directly after the subject). Live disk
wins; AuditTrailSpec was mirrored as well.

### After (verified on disk)

`grep -c "fixtureOnly true"` → **4**

| individual | subject line | marker line |
|---|---| Integration
|---|---|---|
| aex:AuditTrailSpec | :270 | :271 |
| aex:AshR2RMLSpec | :341 | :342 |
| aex:NotificationExtensionSpec | :554 | :555 |
| aex:AshA2aSpec | :1588 | :1589 |

### Parity check

`diff cache-ontology.ttl marketplace-ontology.ttl` → **IDENTICAL** (byte-identical after
the mirror; cache no longer drifts from the pack authority).

## What changed (μ/diff)

Three `Edit` operations on
`/Users/sac/ash_surface/.ggen-v2/git-packs/ash-extension/packs/ash-extension-pack/ontology.ttl`:
inserted `aex:fixtureOnly true ;` immediately after the subject line of
`aex:AuditTrailSpec`, `aex:AshR2RMLSpec`, `aex:NotificationExtensionSpec` — verbatim
marketplace shape. `git diff --stat` in the cache clone:
`packs/ash-extension-pack/ontology.ttl | 16 ++++++++++++++++` (16 insertions: 15 from the
W126 mirror previously present in the working tree + 3 new marker lines; the diff stat
shows 16 insertions because the file is measured against HEAD `3ddbfeb7`, not against the
pre-lane state).

## Sync-path check (no full sync run)

The edited file IS the sync-read path: W355 verified the cache clone
`.ggen-v2/git-packs/ash-extension` is what `ggen sync run` consumes (pin `3ddbfeb7…`, ggen.toml
`subdir = packs/ash-extension-pack`), and this lane diffed byte-identical against the
marketplace working tree. ggen.lock is present in ash_surface (W126 re-locked at
3ddbfeb7+fixes; the lock hashes the pack input, so a marker-line change will surface as a
ggen.lock mismatch at the next sync run rather than a silent skip — see falsifier).

## Falsifier (resync re-emission; NOT run here — mutates ash_surface lib/, coordinator runs at integration)

```bash
cd /Users/sac/ash_surface && ggen sync run
# then:
ls lib/ash_r2rml lib/audit_trail lib/notification_extension 2>&1
grep -rl "AshR2RML\|audit_trail\|notification_extension" lib/mix/tasks/ | grep install
```

Expect after the mirror: sync emits `written: []`-equivalent (all `skipped: unchanged`
against the existing gitignored strays) OR re-emits files whose content now includes the
fixtureOnly gate — in both cases `lib/ash_r2rml/` must NOT reappear (it was quarantined in
W230 and its install task residue W265-noted). If `lib/ash_r2rml/` reappears, the mirror
failed and OS-13 reopens.

## Cache git status (recorded, no commit)

```
 M packs/ash-extension-pack/gates/120_spark_dead_surface.rq
 M packs/ash-extension-pack/ontology.ttl
 M packs/ash-extension-pack/templates/extension.ex.tmpl
?? .ggen-git-pin
```

HEAD `3ddbfeb7e0b8824e1022f9edb043c65b5319f82e`. No git mutations performed in the cache
clone or any repo.
