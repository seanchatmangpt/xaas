# W984cp — Depth court: deterministic-generation-closure family (non-projection_record)

Lane W984cp, xaas v26.10.6, branch `feat/playwright-surface`. Subject: working tree at
base `755b6559` (plus concurrent lane edits in shared `lib/` — see Unblock fix below).
No commit made (per lane contract).

## Coverage map

`docs/sjira/v26.10.6/plans/w984cj-coverage-map.md` does not exist on disk (checked).
Fallback families scanned fresh:

- **coupling** (engine + coupling_run): heavily covered — `engine_test.exs` (14 tests),
  `coupling_deepening_test.exs` (16), `coupling_run_test.exs` (5) incl. read-policy
  court. Excluded.
- **security (Finding/Posture)**: heavily covered — `security_test.exs` (4) +
  `security_deepening_test.exs` (13) incl. GAP-lens courts. Excluded.
- **generation (non-projection_record)**: selected. `generation_test.exs` covers
  happy paths per module; `generation_deepening_test.exs` covers
  `ProjectionRecord` admission. Depth edges below are asserted nowhere in the tree.

## Test file

`test/xaas/generation/manifest_depth_w984cp_test.exs` — 5 tests, Chicago, real bytes,
real temp file for the `detect/1` path, no mocks. Each test names its mutation
rationale in a comment:

1. `Manifest.load/1` raises on each of the 3 missing required keys — kills
   `Map.fetch!` -> `Map.get(key, nil)` silent-partial-entry mutant.
2. `ProvenanceHeader` build/parse round-trip + malformed-hash/missing-field refusal
   (uppercase hash, short hash, empty hash, missing hash field, no header) — kills
   regex-anchor/case-relaxation and `build/1` field-order mutants.
3. `ModificationDetector.detect_content/1` tri-state (`:match` / `:modified` /
   `:unmanaged`) + real-file `detect/1` `:match` and `{:error, :enoent}` — kills
   hash-the-whole-content, branch-swap, and header-absent->match mutants.
4. `CapabilityRegistry` unknown-generator -> nil capabilities / supports?-false;
   exact ggen capability set; `manual` registered-but-capable-of-nothing — kills
   catch-all-default-capability mutant.
5. `ResidueRegistry` unregistered path -> `registered?` false / `reason_for` nil;
   empty registry validates clean — kills registered?->true mutant that would
   void the CanonicalGraph+ManualPatch invariant.

## Finding (pre-existing, disclosed)

`Xaas.Generation.Manifest.load/1` moduledoc claims "Raises `ArgumentError`" but
`Map.fetch!/2` raises **KeyError**. Test pins the real contract; doc fix left to
the owner lane (I only wrote tests + one compile-unblock, below).

## Compile-freeze unblock (shared lib/, disclosed per SLA)

`lib/mix/tasks/xaas.release_audit.ex:217` (uncommitted concurrent lane edit) broke
the shared compile with an unclosed `~r{...}` delimiter (char class contains `{}`).
By the time I applied a minimal fix, another lane had already landed a `~r|...|`
variant on disk; the shared compile then passed. I did not alter that file's logic.
My `sed` to that file was a no-op against the already-fixed content.

## Commands / exits (real)

- Run 1 (fresh `_build-laneW984cp`, first compile of the lane root):
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cp mix test test/xaas/generation/manifest_depth_w984cp_test.exs`
  -> first attempt 4/5 (KeyError vs ArgumentError mismatch, test bug — fixed);
  after fix: **5 passed, exit 0**.
- Run 2 (second fresh root `_build-laneW984cp-r2`): **Result: 5 passed, exit 0**
  (full fresh compile, second root).

## Standing

- Falsifier: any of the 5 courts fails on this subject -> standing falls to
  BUILD_BROKEN for this family's depth edges.
- Current standing: **ALIVE (verified)** — 5/5 passed ×2 fresh build roots
  (`_build-laneW984cp`, `_build-laneW984cp-r2`), both exit 0.

## Build roots

`_build-laneW984cp` and `_build-laneW984cp-r2` left in place for the coordinator
per lane contract (not deleted).
