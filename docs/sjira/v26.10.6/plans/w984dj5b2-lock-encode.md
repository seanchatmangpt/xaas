# W984dj5b2 — Lock/HashManifest error-entry encode divergence: fixed

Lane: W984dj5b2, xaas v26.10.6 campaign, 2026-10-07.
Branch: `feat/playwright-surface` (shared checkout, no commits made).

## Defect (from W984dj5's receipt)

`HashManifest.persist/2` encoded an error entry as `"error: #{inspect(reason)}"`
(with a space); `Lock.build/1` canonically encodes `"error:#{inspect(reason)}"`
(no space). A lock computed in-memory over a manifest containing an unreadable
projection was NOT reproducible from the reloaded on-disk manifest.

## Canonical form pinned by the court

`Lock.build/1` (`lib/xaas/generation/lock.ex:23`) is the contract:
`"#{path}\0error:#{inspect(reason)}"` → on disk `"error::enoent"` for
`{:error, :enoent}`. Consumer grep found no live consumers of the old
space-form persist encoding (only W984dj5's court, which witnessed the
asymmetry). Fix applied to `persist/2`, one line:

```elixir
{path, {:error, reason}} -> {path, "error:#{inspect(reason)}"}
```

(`lib/xaas/generation/hash_manifest.ex:65`. First attempt used
`"error::#{...}"`, which produced `error:::enoent` — the court caught it on
run 1: `left: "error:::enoent", right: "error::enoent"`. Corrected to the
single-colon canonical form.)

## Court legs (new file, mine)

`test/xaas/generation/lock_error_roundtrip_w984dj5b2_test.exs` — 2 tests,
real temp files, no mocks:

1. error-entry manifest → persist → load → `Lock.build(loaded) ==
   in_memory_lock` and `Lock.verify(loaded, ...) == :match`; asserts the
   canonical `"error::enoent"` on-disk literal.
2. mixed manifest (one real digest + one error entry) roundtrips to the
   same lock.

## Court leg update (W984dj5's file)

`test/xaas/generation/lock_persistence_depth_w984dj5_test.exs` test 4
updated: the disclosed-asymmetry `refute Lock.build(loaded) ==
lock_with_error` is now `assert ... == ...` (the fix closes the boundary),
with the historical note retained in a comment.

## Verification (real, ×2)

```
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dj5b2  (fresh root, full compile; first
  run surfaced the triple-colon miss, fixed, re-ran incrementally on same root)
mix test test/xaas/generation/lock_persistence_depth_w984dj5_test.exs \
         test/xaas/generation/lock_error_roundtrip_w984dj5b2_test.exs
  => 7 passed, 0 failures, exit 0
MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dj5b2c (second fresh root, full compile)
  => 7 passed, 0 failures, exit 0   (see run tail below)
mix test test/xaas/generation_test.exs (baseline, same tree)
  => 19 passed, 0 failures
```

Run 2 tail (fresh root `_build-laneW984dj5b2c`):

```
Result: 7 passed
```

## Files written

- `lib/xaas/generation/hash_manifest.ex` (one-line fix)
- `test/xaas/generation/lock_error_roundtrip_w984dj5b2_test.exs` (new, 2 legs)
- `test/xaas/generation/lock_persistence_depth_w984dj5_test.exs` (test 4 leg update)
- `docs/sjira/v26.10.6/plans/w984dj5b2-lock-encode.md` (this receipt)

No commits. Lane build roots left for coordinator cleanup:
`_build-laneW984dj5b2`, `_build-laneW984dj5b2c` (leases per
[[same-checkout-fanout]]).

## Standing

- Fix: **ALIVE** — error-entry locks now reproduce across the disk
  roundtrip, witnessed on two independent compile roots of the exact
  working tree.
- W984dj5's disclosed defect: **closed** (court test 4 now asserts the
  positive roundtrip).
- Mock gate: no mocks introduced; court uses real files, real SHA-256,
  real JSON.
