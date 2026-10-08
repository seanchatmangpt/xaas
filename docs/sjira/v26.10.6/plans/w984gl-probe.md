# W984gl — zoe/meeting unclaimed-family probe (receipt)

Lane: W984gl · subject: branch `feat/playwright-surface` @ 4eba5a44 (uncommitted working tree) · date: 2026-10-07

## Scope + disjointness

Zoe domain lib modules: `lib/xaas/zoe/private_meeting_inference.ex` (471 lines) and
`lib/xaas/zoe/event_simulation.ex` (933 lines). W984em's court
(`test/xaas_web/a2a/a2a_uncovered_branch_court_w984em_test.exs`) covers the wire stack
(`ZoeEventPlug` / `ZoeEventSimulationAgent` / POST /a2a/zoe-event); this lane never touches
`lib/xaas_web` — disjoint. Pre-existing tests were not modified; single new file
`test/xaas/zoe/family_court_w984gl_test.exs` (16 tests).

## Per-module dispositions

### lib/xaas/zoe/private_meeting_inference.ex

| branch/state courted | disposition before | court |
|---|---|---|
| `repository(nil)` non-binary clause | uncovered | typed `:invalid_model_directory` |
| `repository/1` on a regular file + nonexistent path | uncovered | both `:local_model_directory_missing` |
| `verify_model_manifest/1` non-binary clause | uncovered | `:invalid_model_directory` |
| empty manifest | uncovered | `:model_manifest_empty` |
| `../`-escaping manifest path | uncovered | `:unsafe_model_manifest_path` |
| malformed manifest line | uncovered | `:invalid_model_manifest_line` |
| duplicate manifest paths | uncovered | `:duplicate_model_manifest_path` |
| manifest completeness, missing-from-disk direction | uncovered (existing test only drove missing-from-manifest) | `:model_manifest_incomplete` w/ `missing_files` |
| symlink inside model dir during manifest verify | uncovered | `:model_symlink_refused` |
| decoder missing `observations` key | uncovered | `:observations_required` |
| decoder wrong-shape args fallthrough | uncovered | `:invalid_model_output` |
| `process_waste` default when `process_metrics` absent | uncovered | `unnecessary_minutes == 0` |
| `extract/3` non-serving fallthrough | uncovered | `:invalid_private_inference_request` |

COVERED (already exercised, no new test): `repository/1` local dir / https / symlink-at-root
refusals; decoder happy path with PII discard; unknown-requirement-id / invalid-status /
invalid-digest / not-json / invalid-novel refusals; manifest good path, unbound-file
(`missing_from_manifest`), digest-mismatch refusals. Full-covered is legitimate.

UNREACHABLE without a real Nx/Bumblebee model (typed, not a gap in this lane):
`extract/3` serving-backed path (`Nx.Serving.run`, `generated_text/1` string vs map clauses,
`requirements_required`/`invalid_requirement_id`/`duplicate_requirement_id` inside `extract/3`)
and `build_serving/2` — require a real local model artifact set; left for the model-backed
court.

### lib/xaas/zoe/event_simulation.ex

| branch/state courted | disposition before | court |
|---|---|--- |
| `simulate/2` non-map params clause | uncovered | `:invalid_simulation` |
| non-map observation | uncovered | `{:invalid, :observation}` |
| non-boolean `roster_complete?` / `attendance_submitted?` | uncovered | typed count-style refusals |
| non-list `incidents` in an observation | uncovered | `{:invalid, :incidents}` |
| drifted `contract_version` routing | uncovered | routes to timeline surface → `{:invalid, :event_id}` (kills a prefix-match routing rewrite) |
| scenario: negative `walk_ins`, non-list `incidents`, incident missing `kind`, non-list/non-binary `resolutions` | uncovered | typed `{:invalid_scenario, _}` |
| unresolved incident persists as `reported` and surfaces in reconcile payload | uncovered state-bearing | kills a resolve-everything rewrite |
| zero walk-ins → no `walk_in.construct` trace item; zero shortfall → no reinforcement obligation/routed item | uncovered (existing fixtures always use 1) | zero-clause pin |
| duplicate `check_ins` `person_ref` dedup | uncovered | attendance `checked_in == 1` for 2 rows |

COVERED (already exercised): timeline happy path, determinism, policy refusals, phase/count/
observations refusals, snapshot contract refusals (provider/authority_boundary/do_authority/
event), PII refusal both snapshot and scenario, wire path via ConnCase, incident
report/resolve happy path, security shortfall obligation + routed trace item, walk-in
construction, reconcile payload, contract/0, digest determinism.

COVERED-elsewhere (not this lane's subject): `normalize_incident(other)` invalid-incident
fallthrough for the timeline surface — the `{:invalid, :observation}` path is now courted
here; the `normalize_incident` normalization branch (non-map incident inside a valid
observation) remains unexercised by any test file I found; flagged, not courted (bounded by
the same validation wall upstream — low falsifier value).

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gl mix test test/xaas/zoe/family_court_w984gl_test.exs` → **16 passed, 0 failures**, exit 0
- `... mix test test/xaas/zoe/` → **28 passed** (no regression to pre-existing zoe tests), exit 0
- Mock gate `scan_mock_usage(["test","lib"])` → **`[]`** (zero banned patterns)

## Files

- New: `test/xaas/zoe/family_court_w984gl_test.exs` (16 tests, zero mocks, real temp dirs/manifests/simulator state, mutation rationale per test)

Typo check: file is `test/xaas/zoe/family_court_w984gl_test.exs`. No commit (per lane law);
no other files touched.
