# W984cx — Xaas.Hddl.Mermaid Depth Court — RECEIPT

Lane: W984cx, xaas v26.10.6 campaign. Subject: branch `feat/playwright-surface`,
uncommitted lane files only (no commit made, per directive).

## Module surface analysis

`lib/xaas/hddl/mermaid.ex` — 5 public functions:

- `for_reactor/1` — runtime Mermaid generation via `Reactor.Mermaid.to_mermaid/2`
  (observed: emits `flowchart LR`, `start{"Start"}`, `==>` trunk edges,
  per-step `input_*`/`step_*` nodes with `-->|label|` edges). Static `.mmd`
  fallback on error (fallback path not exercised by these courts — the runtime
  path succeeds, so the fallback remains UNCOVERED).
- `for_domain/1` — atom-keyed dispatch over `@known_reactors`
  (`:actuation`, `:recommendation_pipeline`, `:circulation_borrow`);
  typed `{:error, :unknown_domain}` otherwise.
- `for_file/1` — reads a pre-generated `.mmd`. **DEFECT (observed, not
  repaired — tests-only lane):** resolves relative paths against
  `Path.dirname(Path.dirname(:code.priv_dir(:xaas)))` = the build `lib/` dir
  (e.g. `_build-laneW984cx/test/lib/docs/hddl/...`), NOT the project root.
  `for_file("docs/hddl/actuation_reactor.mmd")` returns
  `{:error, {:file_read_error, :enoent, ...}}` even though the file exists at
  `/Users/sac/xaas/docs/hddl/actuation_reactor.mmd`. Broken under normal
  `_build/test` too, not just lane roots. Same resolution bug in the private
  `read_static_mmd/1` fallback, so the static fallback is also dead in
  practice. Suggested fix: `File.cwd!()`-relative or `File.cwd!()`-join
  instead of priv_dir climbing.
- `annotation_header/2` — `%%` header embedding method name, module, and the
  HDDL↔Reactor isomorphism line.
- `for_drawer/2` — `header <> diagram` composition.

## Courts (test/xaas/hddl_mermaid_depth_test.exs, 6 tests, 0 mocks)

1. Well-formedness — real emission for `Xaas.Actuation.Reactor`: binary,
   non-empty, `flowchart (LR|TD)` header, `-->` edges, `[` node bodies.
2. Determinism ×2 — two fresh `for_reactor/1` calls byte-identical.
3. Drawer determinism + composition order — `for_drawer/2` output is exactly
   `annotation_header/2 <> for_reactor/1` diagram (pinned-binary match).
4. Typed failures — `{:error, :unknown_domain}` for unknown atom; `{:error,
   {:file_read_error, :enoent, abs_path}}` for a missing file. Never raises.
5. Structural fidelity — every `-->` edge endpoint is a declared node
   (closure), edges non-empty; static `docs/hddl/actuation_reactor.mmd`
   fixture read directly via `File.read` (bypassing the `for_file/1` path
   bug, disclosed inline) and asserted non-empty edge count.
6. Header content — `annotation_header/2` embeds method, module, isomorphism.

Mutation rationale per test is in the test moduledoc (kills empty/garbage
emission, shuffling/caching, header-drop, crash-on-malformed, dropped-step,
and format-regression mutants).

## Verification (real output)

```
$ MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cx mix test test/xaas/hddl_mermaid_depth_test.exs
Result: 6 passed            (seed 120192; earlier run seed 713158 reached 5/6 with the disclosed compile/match iterations)
$ mix test --seed 987654 test/xaas/hddl_mermaid_depth_test.exs
Result: 6 passed            (×2 fresh root/seeds, both green)
```

Both runs exit 0. Grafana/PromEx nxdomain warnings are pre-existing ambient
noise, unrelated to this lane.

## Standing

- Court: ALIVE (6/6, ×2 seeds, real reactor, real files, zero mocks).
- `for_reactor/1`, `for_domain/1`, `annotation_header/2`, `for_drawer/2`:
  covered ALIVE.
- `for_file/1` happy path + `for_reactor/1` static-`.mmd` fallback:
  UNSUPPORTED(path-resolution defect) — covered only as typed-error paths
  until the priv_dir-climbing bug is fixed.
- Build root `_build-laneW984cx` NOT deleted: `rm -rf` denied by the
  permission system this session. Coordinator should remove it at
  integration (fanout cleanup law).
