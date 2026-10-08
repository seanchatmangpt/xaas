# W984jv — unclaimed-family stragglers probe: lib/xaas/generation/ (past W984hj)

Lane: W984jv. Branch: feat/playwright-surface (shared canonical checkout, no commits).
Date: 2026-10-07. Base context: W984hj receipt (`w984hj-probe.md`).

## Probe method

Read `dependency_graph.ex` + `residue_registry.ex` in full, read W984hj's receipt,
re-censused `test/` (`grep -n "DependencyGraph\|ResidueRegistry"` across
test/xaas/generation_test.exs, generation_deepening_test.exs,
test/xaas/generation/*). Classified remaining branches against W984hj's coverage.

## Per-branch dispositions

### dependency_graph.ex

| branch | disposition |
|---|---|
| build/1 grouping by source_path (multi-entry) | COVERED (generation_test.exs:92-110) |
| projections_for/2 hit + missing-source [] edge | COVERED (same) |
| build/1 over empty entry list → `%{}` degenerate arm | UNCOVERED — courted |
| Enum.sort normalization arm (arrival order must not leak) | UNCOVERED — W984hj's fixture arrives pre-sorted (a1,a2), so a sort-deletion mutation survived; courted with reversed-order fixture |
| duplicate (source, projection) preservation (no silent dedup) | UNCOVERED — an `Enum.uniq` injection previously survived; courted |

### residue_registry.ex

| branch | disposition |
|---|---|
| registered?/reason_for/validate empty-registry surface | COVERED (generation_test.exs:193-200, manifest_depth_w984cp:159-168) |
| validate :missing_reason arm | COVERED-VACUOUS — structurally unreachable while `@entries == []` (compile-time attribute, no injection seam; by design per moduledoc). Typed, no filler test. |
| validate :file_not_found arm | COVERED-VACUOUS — same structural reason |
| registered?/reason_for hit-arms (entry exists) | COVERED-VACUOUS — same |

## Court

`test/xaas/generation/stragglers_court_w984jv_test.exs` — 3 tests, real
`Manifest.load` structs, real graph data, zero mocks. Mutation rationale per
describe block in the moduledoc (empty-manifest arm, sort-deletion mutation,
uniq-injection mutation).

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984jv
  mix test test/xaas/generation/stragglers_court_w984jv_test.exs`
  → `3 passed`, exit 0 (cold lane build root; full dep compile ~15 min).
- Mock gate `scan_mock_usage(["test/xaas/generation", "lib/xaas/generation"])` → `[]`, exit 0.

## Cleanup

`rm -rf _build-laneW984jv` — see note below.

## Standing

PARTIAL_ALIVE → the three courted DependencyGraph branches are now witnessed.
ResidueRegistry deeper arms remain typed COVERED-VACUOUS: they become reachable
only when a real residue entry is hand-registered (a deliberate human decision),
at which point validate's filesystem re-check should get its own court.
