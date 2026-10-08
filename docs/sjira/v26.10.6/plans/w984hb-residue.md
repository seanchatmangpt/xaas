# W984hb — ash_pplan working-tree residue (dsl-pack ontology.ttl) — lane receipt

Date: 2026-10-08 · Lane: W984hb · Subject: /Users/sac/ash_pplan @ HEAD 16a7bfa5-era (branch untouched, no commit)

## Task

Classify `priv/ggen/ash-pplan-dsl-pack/ontology.ttl` working-tree modification (disclosed W650v,
receipt `docs/sjira/v26.10.7/plans/w650v-pplan-suite.md`); restore iff proven pure regen artifact.

## Diff characterization

Working-tree file (sha256 `94563b67…`) vs HEAD (`b63fa769…`): header + version bump
`owl:versionInfo "26.10.3"` → `"26.10.7"` plus ~280 added lines — the RunStatus state machine
(`st:RunStatusMachine`, states pending..cancelled, transitions) under a `st:` prefix block, plus
one blank line after the provenance header. Matches the version-companion bump landed in W650j
(commit `847f487`, "align version companions with 26.10.7").

## Regen proof (deterministic)

- No script writes this file: `bin/manufacture-dsl` writes only `lib/ash_pplan/dsl*`. The file's
  lawful "generator" is the copy convention (4-line GENERATED-PROVENANCE header + root body).
- Recomputed the convention output from canonical root `ontology.ttl` (26.10.7,
  sha256 `2d4c382d…`):
  `{ header; cat ontology.ttl; }` → sha256 `94563b6775bb748e531bf694985d002fa66fdfedcf4979d7d00fd442588f86d1`
  — `cmp` BYTE-IDENTICAL to the working-tree file.
- Release contract loop (`test/release_contract_test.exs` "pack ontologies are real files…")
  covers only `ash-pplan-pack` / `ash-pplan-workflow-pack` (both already at 26.10.7, committed);
  the dsl-pack copy is excluded from every court that reads pack ontologies.
- Decisive context: W650j's commit message itself: "dsl-pack copy is pre-existing drift, restored
  untouched." The working-tree change was an unsanctioned re-application of that declined sync.

## Restore

`git checkout -- priv/ggen/ash-pplan-dsl-pack/ontology.ttl`
Post-restore: `git status --short` for the path → empty; on-disk sha256 `b63fa769…` == `git show
HEAD:…` sha256 `b63fa769…`.

## Verification ladder (owning tests)

Toolchain: ash_pplan pins elixir 1.20.4-otp-29 / erlang 29.1.1 (`.tool-versions`); all runs used
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hb`. Machine load ran
60–80 (other lanes' xaas tests) throughout; several runs hit the 30-min harness background cap
and were relaunched (build root persisted, incremental).

- `mix test test/courts/pack_dsl_smoke_court_test.exs` → **1 test, 1 passed, exit 0** (570.9s).
  This is the direct dsl-pack court.
- `mix test test/manufacture_test.exs` (full file): 2 tests passed; the pack-regeneration court
  case for `manufacture-runtime-contract` exceeded its internal `System.cmd` timeout under load —
  environment contention, NOT file content (the script does not touch ontology.ttl). 5 runs, cap
  kills documented.
- `mix test test/manufacture_test.exs:198` (pack-court loop, 8 scripts, each a cold private build
  root): 3 cases passed before the 30-min cap kill; dsl-pack court is 3rd in the list and passed.
  Full-file exit-0 under this contention could not be completed within harness limits.
- Not observed to affect the restored file: post-test `git status` shows
  `priv/ggen/ash-pplan-dsl-pack/ontology.ttl` clean.

## Escalation — NEW residue introduced by the mandated test runs (OUT of lane scope, untouched)

Starting status showed only ontology.ttl modified. After the manufacture_test runs, `git status`
shows ~40 modified/deleted + ~15 untracked paths under `priv/ggen/vendor/` (chaos-pack,
tokyo-depeg-burn-in-pack, protocol-court-pack: gates/*.rq, templates *.tmpl, provenance.ttl,
sync.sh, PACKS.lock.json) and `lib/ash_pplan/runtime_contract/*.ex`. Mtimes (1791434933–1791440020
≈ 23:15–23:20 local) fall inside the full manufacture_test window — the runtime-contract /
vendor-sync courts rewrote them. These were NOT restored or reverted by this lane: they may be
in-flight W650 vendor-pack work and reverting blind risks destroying another lane's output.
Coordinator decision required (restore vs. commit vs. own as drift).

## Cleanup

`rm -rf _build-laneW984hb` — **DENIED** by permission system. The 398M build root remains at
`/Users/sac/ash_pplan/_build-laneW984hb`; coordinator cleanup required.

## Standing

- ontology.ttl residue: classified, proven regen-convention output, restored, ALIVE (clean +
  smoke court exit 0).
- manufacture_test full-file green: BLOCKED(environment-contention / harness 30-min cap), not
  file-related.
- vendor-tree residue: UNKNOWN, escalated to coordinator.
