# W618 — Fleet Version Bump to 26.10.7 (WP-5, v26.10.7 campaign)

Lane: W618. Date: 2026-10-07.
No commits made. Edits are uncommitted working-tree changes on each repo's
currently checked-out branch. No build roots used (file edits + grep/python only).

## Bumped (26.10.x -> 26.10.7)

| repo | branch | file(s) | before -> after | validation |
|---|---|---|---|---|
| ash_pplan | fix/ggen-verify-header (main sealed at 6dbd3b0 honored) | `mix.exs` `@version` (line 4) | 26.10.3 -> 26.10.7 | grep on disk |
| ash_a2a | feat/tck-vuln-hardening | `mix.exs` `version:` (line 29) | 26.10.5 -> 26.10.7 | grep on disk |
| gymact | v26926/gymact-land-aloop-execution-kernel | `pyproject.toml` `[project] version` (line 7) | 26.10.6 -> 26.10.7 | `tomllib.load` OK |
| ggen | feat/v26.10.5-release-cut | `Cargo.toml` `[workspace.package] version` (line 2; member crates inherit via `version.workspace = true`) | 26.10.6 -> 26.10.7 | `tomllib.load` OK |
| ggen | feat/v26.10.5-release-cut | `ggen.toml` `[project] version` (line 3) | 26.10.6 -> 26.10.7 | `tomllib.load` OK |
| ggen_igniter | feat/adr-0010-gate-convention | `mix.exs` `version:` (line 9) | 26.10.5 -> 26.10.7 | grep on disk |
| wasm4pm | fix/v26.9.30-ci-fmt-tsc | `package.json` `version` (line 3) | 26.10.6 -> 26.10.7 (W601p had taken it to 26.10.6) | `json.load` OK |
| ash_graphlaw | main | `ontology.ttl` `glx:packageVersion` (line 84) AND `mix.exs` `@version` (line 11) | 26.10.1 -> 26.10.7 | grep both files |

ash_graphlaw note: `mix.exs` is a ggen-rendered projection of
`glx:packageVersion` in `ontology.ttl` (comment in the file says so). The
canonical source (`ontology.ttl`) was edited first; the projection was kept in
sync by hand because `ggen sync` was not run in this lane. A `scripts/ggen_sync.sh`
re-render on that repo should confirm zero drift.

## Deliberately untouched (with reason)

- ferroplan — `Cargo.toml` `[package] version` 0.29.0 and `ggen.toml` 0.1.0:
  not 26.10.x; own cadence. Dependency `version = "1"` constraints untouched.
- ggen-marketplace — `pyproject.toml` `[project] version` 0.1.0: not 26.10.x.
- zcode-cli — `package.json` version 3.14.3-1: not 26.10.x; own cadence.
  (Its `scripts/bump-build.ts` flow owns the `-1` build suffix.)
- autofde-lab — `ggen.toml` 0.1.0 (pyproject uses `dynamic = ["version"]`):
  not 26.10.x.
- wasm4pm `Cargo.toml` `[package] version` 26.9.30: not 26.10.x (stale 26.9.x);
  left per the bump rule. Same for `ggen.toml` 26.6.11.
- gymact `pyproject.toml` line ~135 `version = "26.8.23"`: that is inside a
  `[tool]` section (pep440/pep621 version-scheme config), not the project
  version — left alone.
- All dependency version constraints, locked deps, and `version.workspace = true`
  member crates (ggen workspace members inherit; nothing per-crate to edit).

## Standing

PARTIAL_ALIVE: all target files verified bumped on disk with real grep/json/
tomllib output; no commits, no builds, no ggen re-render. Open follow-ups:
(1) ggen sync re-render in ash_graphlaw to confirm projection parity;
(2) commit of these bumps is owned by the coordinator (integration wave).
