# W984hj — unclaimed-family probe: lib/xaas/generation/

Lane: W984hj. Branch: feat/playwright-surface (shared canonical checkout, no commits).
Date: 2026-10-07.

## Probe method

Listed `lib/xaas/generation/**/*.ex` (11 modules + 1 validation). CamelCase-grepped
each module name against `test/`, then function-level greps
(`capabilities(`, `regenerate_and_diff`, `ResidueRegistry.`, `persist(`, `Lock.verify`,
`ProvenanceHeader.`, `NoManualPatch`, ...) to distinguish shallow-name mentions from
real branch exercise.

## Per-module dispositions

| module | verdict |
|---|---|
| capability_registry.ex | COVERED (generation_test, manifest_depth_w984cp) except `known_generators/0`: zero callers in lib/ or test/ — courted |
| dependency_graph.ex | COVERED (generation_test build + projections_for incl. missing-source [] edge) |
| hash_manifest.ex | COVERED (build/verify/persist/load roundtrips incl. error-entry encoding in w984dj5b2) except `load/1` failure paths (missing file, malformed JSON) — courted |
| lock.ex | COVERED (build determinism, verify match/mismatch, error-entry roundtrip w984dj5/w984dj5b2) |
| manifest.ex | COVERED (load, fail-loud missing-key edges, find_by_projection, projection_paths — w984cp) |
| modification_detector.ex | COVERED (detect :unmanaged/:match/:modified/:error all witnessed) |
| projection_record.ex | COVERED (projection_record_admission_depth_test, NoManualPatch validation path) |
| provenance_header.ex | COVERED (build/parse happy path) except parse rejection edges (uppercase hex hash, truncated header) — courted |
| regeneration_verifier.ex | COVERED (verify mismatch + regenerate_and_diff typed receipt) |
| residue_registry.ex | COVERED for the empty-registry surface (registered?/reason_for/validate). The :missing_reason/:file_not_found validate branches are unreachable while `@entries == []` — structural vacuity, not a test gap |
| unsupported_receipt.ex | COVERED (build happy path) except input guards (non-binary id, non-atom reason) — courted |
| validations/no_manual_patch.ex | COVERED (via projection_record_admission_depth_test) |

## Court

`test/xaas/generation/family_court_w984hj_test.exs` — 8 tests, real files/structs/
Jason decode, zero mocks. Mutation rationale per describe block is in the moduledoc:

- known_generators/0 registry-key mutation would previously survive the suite.
- ProvenanceHeader regex loosening (case-insensitive/optional hash) previously survived.
- UnsupportedReceipt.build guard removal previously survived.
- HashManifest.load error swallowing previously survived.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hj mix test
  test/xaas/generation/family_court_w984hj_test.exs` → `8 passed`, exit 0.
- Mock gate `scan_mock_usage(["test/xaas/generation", "lib/xaas/generation"])` → `[]`.

## Notes

- First run failed compile (`after` block variable scope); fixed forward, no resets.
- No commit made, per lane contract. `rm -rf _build-laneW984hj` attempted at close.
