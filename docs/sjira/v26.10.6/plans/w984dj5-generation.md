# W984dj5 — Generation non-manifest modules: census + Lock/HashManifest persistence depth court

Lane: W984dj5, xaas v26.10.6 campaign, 2026-10-07.
Branch: `feat/playwright-surface` (shared checkout, no commits made).

## Census (CamelCase-aware method over `lib/xaas/generation/`)

11 modules + 1 validation. Coverage subtracted per W984dd's named exclusions
(Manifest=W984cp, SubstitutionPolicy=W984cw3 at `lib/xaas/ultracode/substitution_policy.ex`,
ProvenanceHeader/ModificationDetector/CapabilityRegistry/ResidueRegistry in W984cp's
file `test/xaas/generation/manifest_depth_w984cp_test.exs`) plus the baseline
`test/xaas/generation_test.exs` and depth courts `projection_record_admission_depth_test.exs`
(W983h) / `substitution_policy_depth_test.exs`:

| module | state-bearing? | existing coverage | depth |
|---|---|---|---|
| manifest.ex | entry list | W984cp court | covered |
| hash_manifest.ex | digest map on disk | baseline: compute_hash/verify/build | persist/2 + load/1: **zero test references** |
| lock.ex | digest over sorted hash manifest | baseline: 2 tests, **in-memory maps only** | thin — never through disk |
| dependency_graph.ex | derived map | baseline: build + projections_for | adequate (pure derived) |
| regeneration_verifier.ex | delegation + typed UNSUPPORTED | baseline: 2 tests incl. typed receipt | adequate |
| unsupported_receipt.ex | struct | baseline (typed receipt shape) | adequate |
| projection_record.ex | Ash ETS resource | W983h depth court | covered |
| validations/no_manual_patch.ex | Ash validation | covered via ProjectionRecord admit/refuse tests | covered |

**Top remaining state-bearing module**: `Xaas.Generation.Lock`, chained to the
uncovered `HashManifest.persist/2` / `load/1` disk roundtrip — the determinism
contract of the generation closure is only as good as its persistence path, and
that path was untested end to end.

## Court

`test/xaas/generation/lock_persistence_depth_w984dj5_test.exs` — 5 tests, real
temp files, real SHA-256, real JSON on disk, real typed load failures. No mocks.

1. **lock digest is insertion-order-insensitive** — mutation killed:
   `Lock.build` removing `Enum.sort` (locking to map iteration order, which
   Elixir does not guarantee) flips this to flaky/failing.
2. **persist -> load disk roundtrip reproduces the lock** (`verify :match`,
   digest equality entry-for-entry) — mutation killed: persist writing a
   different encoding, or load dropping/renaming entries, breaks the roundtrip.
3. **real on-disk tamper after persist detected as :mismatch after reload** —
   the ticket's drift-detection falsifier, exercised through the full
   persist/detect chain rather than in-memory maps only.
4. **error entries are visible, not hidden** — a missing file hashes to
   `{:error, :enoent}`, produces a lock distinct from any digest entry, and
   persists as a literal `"error: :enoent"` string. **Real defect found and
   disclosed as a boundary**: `persist/2` encodes `"error: #{inspect(reason)}"`
   (with space) while `Lock.build` canonically encodes
   `"error:#{inspect(reason)}"` (no space), so a lock computed in-memory over a
   manifest containing an error entry is NOT reproducible from the reloaded
   on-disk manifest. Digest-only manifests roundtrip exactly; error entries do
   not. The test witnesses the asymmetry rather than papering over it. Fix (one
   line, `hash_manifest.ex` persist encoding) is left to a code-owning lane.
5. **empty-manifest lock well-defined (64-hex, distinct from any nonempty
   lock) + typed load failures** — `{:error, :enoent}` for a missing store,
   `{:error, %Jason.DecodeError{}}` for malformed JSON, never a raise.

## Verification (real, ×2 fresh roots)

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dj5  mix test test/xaas/generation/lock_persistence_depth_w984dj5_test.exs
  => 5 passed, 0 failures, exit 0 (fresh build root, full compile)
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dj5b mix test test/xaas/generation/lock_persistence_depth_w984dj5_test.exs
  => 5 passed, 0 failures, exit 0 (second fresh build root, full compile)
```

Note: `rm -rf` of `_build-laneW984dj5` was denied by the permission system, so
run 2 used a fresh differently-named root (`_build-laneW984dj5b`) instead of
re-deleting run 1's. **Coordinator cleanup**: delete both `_build-laneW984dj5`
and `_build-laneW984dj5b` at integration (lane build roots are leases, per
[[same-checkout-fanout]] cleanup law).

## Files written

- `test/xaas/generation/lock_persistence_depth_w984dj5_test.exs` (new)
- `docs/sjira/v26.10.6/plans/w984dj5-generation.md` (this receipt)

No other files touched. No commits.

## Standing

- Court: **ALIVE** — 5/5 passing on two independent fresh compile roots of the
  exact working tree at HEAD `56325fa5` (uncommitted shared tree).
- Claim: W984dd's "uncovered-and-unclaimed" set narrows to the Lock/persist-load
  chain; it is now depth-claimed by this lane. Remaining generation modules are
  covered-and-adequately-claimed (census table above); a typed
  DISPOSITION(COVERED) applies to them, no further court needed this wave.
- Defect receipt (for a code lane): `HashManifest.persist/2` vs `Lock.build/1`
  error-entry encoding mismatch breaks lock reproducibility across a disk
  roundtrip when the manifest contains an unreadable projection.
