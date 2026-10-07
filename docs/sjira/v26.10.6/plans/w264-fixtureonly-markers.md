# W264 — `aex:fixtureOnly` markers for ash-extension-pack worked examples (OS-13 durable fix)

- Lane: W264 (integration lane, v26.10.6 convergence)
- Date: 2026-10-06
- Subject: `/Users/sac/ggen-marketplace` (working tree, no git mutations)
- Files owned/changed: `packs/ash-extension-pack/ontology.ttl` only (+ this receipt)
- Precedent mirrored: W126 (added `aex:fixtureOnly true` to `aex:AshA2aSpec`)

## Problem

`ggen sync` for the ash_surface consumer fans out the pack's worked-example
specs (`AshR2RMLSpec` → `lib/ash_r2rml/`, `AuditTrailSpec` → `lib/audit_trail/`,
`NotificationExtensionSpec` → `lib/notification_extension/`, plus their
`Mix.Tasks.*.Install` emitters) into `~/ash_surface/lib` on every sync run.
W126 already proved the mechanism: specs marked `aex:fixtureOnly true` are
excluded from consumer fan-out by the templates' `FILTER NOT EXISTS { ?spec
aex:fixtureOnly true }` SPARQL guards, while remaining visible to gates/audits.

## Fix

Added `aex:fixtureOnly true ;` as the first property of each of the three
remaining `aex:AshExtensionSpec` individuals, mirroring the W126
`aex:AshA2aSpec` row exactly (same predicate `aex:fixtureOnly`, same object
`true`, same position after the type declaration):

| row | ontology.ttl |
|---|---|
| `aex:AuditTrailSpec` | line 271 |
| `aex:AshR2RMLSpec` | line 343 |
| `aex:NotificationExtensionSpec` | line 554 |

Full fixtureOnly population after the fix (verified in the parsed graph,
1931 triples): `AshA2aSpec`, `AshR2RMLSpec`, `AuditTrailSpec`,
`NotificationExtensionSpec` — all four `AshExtensionSpec` individuals.

## Validation (real output)

1. `uv run python scripts/verify_msct_profile.py` (in `/Users/sac/ggen-marketplace`) →
   exit 0:

   ```
   MSCT/MX profile invariants: ALIVE
   active_packs=13 front_door=ggen-platform-pack
   minimum_novelty=reuse>compose>extend>invent
   human_implementation_required=false grants_do_authority=false
   ```

2. `gates/100_projection_isolation_contract.rq` executed against the parsed
   ontology (rdflib): **rows=0** (duplicate-packageName arm exempts
   fixtureOnly pairs, so the four now-fixtureOnly specs cannot false-positive
   on shared `packageName`-class collisions; supportSubdir arm clean).
3. `gates/120_spark_dead_surface.rq` executed against the parsed ontology
   (rdflib): **rows=0** (`aex:fixtureOnly` stays in the closed VALUES
   consumer-attested allowlist; new rows are consumers, not new vocabulary).
4. Template consumers confirmed live: `FILTER NOT EXISTS { ?spec aex:fixtureOnly true }`
   present in `templates/extension.ex.tmpl:13`, `templates/persist.ex.tmpl:24`,
   `templates/receipt.ex.tmpl:11`, `templates/composition_test.exs.tmpl:10`,
   `templates/a2a_skill.ex.tmpl:540`, `templates/a2a_skill.ex.tmpl:40` —
   the fan-out exclusion the new rows now trigger.
5. Durability/pin note verified on disk: the ggen sync cache clone at
   `/Users/sac/ash_surface/.ggen-v2/git-packs/ash-extension/packs/ash-extension-pack/ontology.ttl`
   contains exactly **1** `fixtureOnly true` row (the W126 AshA2aSpec row at
   the pinned SHA). The three new rows are absent there today; they take
   effect on the next pack pin advance in the consumer. No re-sync of
   ash_surface was performed, per task constraint.

## Standing

- Marker fix: ALIVE on the pack-repo subject (validated in the real graph and
  by gate-120-style checks, exit 0).
- Consumer effect (no more installer products in `~/ash_surface/lib`):
  lands at next pin advance of ash-extension-pack in the ash_surface
  consumer — UNKNOWN until that run, by construction (cache mirrors the pack
  repo pin, not the working tree).

## W266 post-W264 diff

Observed 2026-10-06, repo /Users/sac/ggen-marketplace (integration lane W266,
v26.10.6 convergence), post-W264 staging check — read-only, no git mutations.

`git status --porcelain`:

```
 M CHANGELOG.md
 M marketplace.active.toml
 M packs/ash-extension-pack/gates/120_spark_dead_surface.rq
 M packs/ash-extension-pack/ontology.ttl
 M packs/ash-extension-pack/templates/extension.ex.tmpl
```

Exactly the 5 expected M files; nothing added, deleted, or renamed.

`git diff --stat`:

```
 CHANGELOG.md                                             | 10 ++++++++++
 marketplace.active.toml                                  |  2 +-
 packs/ash-extension-pack/gates/120_spark_dead_surface.rq |  4 ++++
 packs/ash-extension-pack/ontology.ttl                    | 16 ++++++++++++++++
 packs/ash-extension-pack/templates/extension.ex.tmpl     | 11 ++++++++++-
 5 files changed, 41 insertions(+), 2 deletions(-)
```

Deviation note: ontology.ttl carries **4** new `aex:fixtureOnly true ;` rows,
not 3 — the expected AuditTrailSpec / AshR2RMLSpec / NotificationExtensionSpec
plus a fourth on `aex:AshA2aSpec` (the W126 row's marker re-stated in the
working tree). The diff also carries additional content beyond the markers:
two `aex:fieldDoc` additions on the deprecated AshA2aArgument rows and 3 new
`aex:AshA2aAuthorityGate*` FieldOneOfValue rows (two_port/open/disabled).

## W267 regression

Integration lane W267, v26.10.6 convergence, repo /Users/sac/ggen-marketplace. No fixes, no git. Real output, 2026-10-06.

```
$ uv run pytest tests/ -q -k "ash_extension or fixture or composition"
150 passed, 19 skipped, 1845 deselected, 3522 warnings, 2 subtests passed in 92.94s (0:01:32)
```

```
$ uv run python scripts/verify_msct_profile.py
minimum_novelty=reuse>compose>extend>invent
human_implementation_required=false grants_do_authority=false
```

Both gates green. No new fixtureOnly rows beyond the 4 noted in the deviation note above; no regression observed post-W264.

## W289 full suite

Integration lane W289, v26.10.6 convergence, repo /Users/sac/ggen-marketplace.
Full-suite regression post-W264 ontology marker rows (W267 ran only -k
filtered). No fixes, no git. Real output, 2026-10-06.

Subject SHA: `93895f808775e04dce9441fbf4014a3d4d40c942`

```
$ uv run pytest tests/ -q 2>&1 | tail -4
1956 passed, 58 skipped, 75716 warnings, 146 subtests passed in 1200.56s (0:20:00)
```

Exit code 0. **1956 passed — exactly on the W169/W105 baseline target.**
No regressions from the W264 `aex:fixtureOnly` marker rows on the full suite;
full-suite standing for the marker fix is ALIVE on subject 93895f80.
