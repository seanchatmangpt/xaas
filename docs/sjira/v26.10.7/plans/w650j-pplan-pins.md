# W650j — ash_pplan 26.10.7 version-pin companion fix

Lane W650j, v26.10.7 fleet seal. Repo `~/ash_pplan`, branch
`fix/ggen-verify-header`. Gate card: `w984cx2-pplan-gates.md` (NOT
release-ready: 4 version-pin court failures — `862f0c0` bumped mix.exs
only). Operator-delegated commit+push authority; no force; `git commit -F`.

## Standing

ALIVE (v26.10.7 release-gate court class), exact subject
`847f487b4bb3b4e41afc179c813406d97cdfdc98` on `fix/ggen-verify-header`;
main ff'd `862f0c0 -> 847f487` (merge-base --is-ancestor held pre-push).
Tag `v26.10.7` (annotated, `37a736f6`) rides at `862f0c0` (W635/W618) and
was NOT moved: the companion fix is post-tag on branch + main. Recorded
honestly — the tagged tree itself still contains the stale companions;
26.10.7-versioned content lives one commit later.

## Per-file edits (6 files, +14/-5)

| file | edit |
|---|---|
| `test/ash_pplan_test.exs:18` | pin `"26.10.3"` -> `"26.10.7"` |
| `CHANGELOG.md` | new `## 26.10.7 - 2026-10-07` entry prepended; 26.10.3 entry and all history preserved |
| `ontology.ttl:17` | `owl:versionInfo` `"26.10.3"` -> `"26.10.7"` only |
| `ecosystem.lock.toml:2` | `release = "v26.10.3"` -> `"v26.10.7"` (producer lock) |
| `priv/ggen/ash-pplan-pack/ontology.ttl` | 4-line GENERATED-PROVENANCE header preserved + refreshed root body (version line only diff) |
| `priv/ggen/ash-pplan-workflow-pack/ontology.ttl` | same mirror refresh |

dsl-pack note: `priv/ggen/ash-pplan-dsl-pack/ontology.ttl` also carries a
stale 26.10.3 copy but is NOT covered by the pack-identity court
(court checks pack + workflow-pack only) — pre-existing drift, restored to
HEAD untouched after an over-broad first copy, disclosed here.

## Commands / exits

```
MIX_ENV=test mix compile --force --warnings-as-errors   # ok, 0 warnings (264 files)
MIX_ENV=test mix test test/ash_pplan_test.exs test/release_contract_test.exs
  run 1: 42 passed   run 2: 42 passed   (x2 fresh, green both)
```

Court coverage: AshPPlanTest version pin, ReleaseContractTest changelog/
ontology/producer-lock lines + pack-identity court (header + byte-identity
vs root), all green.

Intermediate failures (fixed forward, disclosed):
1. First run 41/42 — pack-identity court failed byte-identity (raw `cp`
   dropped the 4-line provenance header). Rebuilt as header+body.
2. Second run 41/42 — header line itself missing. Restored exact 4-line
   header from `git show HEAD:` (3 comment lines + blank).
3. dsl-pack over-copy reverted via `git checkout HEAD --`.

## Transport

Pushed `fix/ggen-verify-header` `110f5d6..847f487`; ff push `HEAD:main`
`862f0c0..847f487`; `origin/main == origin/fix/ggen-verify-header ==
847f487`. Handwritten diff (4 content pins + 2 pack mirrors); no generator
in this repo's loop for these files.

Falsifier for the lane: the 4 version-pin courts re-run green on the exact
pushed head — witnessed above, ×2.
