# W984hw — unclaimed-family probe receipt: `lib/xaas/generation/hash_manifest.ex`

Lane: W984hw on /Users/sac/xaas @ feat/playwright-surface (no commit, per dispatch).
Subject: hash_manifest.ex @ HEAD 82f7f558; fix under probe 02902f5c (Lock encode
canonical form `"error:" <> inspect(reason)`, no space).

## Census (HashManifest vs test/)

- `test/xaas/generation_test.exs` — compute_hash ok/:enoent, verify match/mismatch
  (incl. via RegenerationVerifier), build mixed digest+error entries, Lock.build
  determinism.
- `test/xaas/generation_deepening_test.exs` — hash usage across regeneration flows.
- `test/xaas/generation/lock_error_roundtrip_w984dj5b2_test.exs` — **the 02902f5c
  regression pin already exists**: line 47 asserts `loaded[missing] == "error::enoent"`
  plus full build→persist→load→Lock.build reproducibility. Typed COVERED.
- `test/xaas/generation/lock_persistence_depth_w984dj5_test.exs` — persist/load
  roundtrip, load failure paths (:enoent, %Jason.DecodeError{}).
- `test/xaas/generation/family_court_w984hj_test.exs` — load/1 failure paths
  (duplicated leg), ProvenanceHeader/UnsupportedReceipt/CapabilityRegistry edges.

Classification: happy paths, tamper (mismatch), :enoent encode roundtrip, and
load failure paths — COVERED. No additional regression test needed for 02902f5c;
it is already pinned.

## Genuinely unexercised branches → new court

`test/xaas/generation/hash_manifest_court_w984hw_test.exs` (4 tests, real
files/dirs, zero mocks; mutation rationale in-file):

1. `:eisdir` error-reason encode — projection path is a real directory →
   build records `{:error, :eisdir}`, persist emits canonical no-space
   `"error::eisdir"`, load roundtrips. Closes gap: prior pin covers :enoent only;
   an encode regression on other reasons would survive the prior suite.
2. `HashManifest.build/1` order-independence over Manifest entry lists
   (Lock.build determinism was tested; build/1 itself was not).
3. `verify/2` error tunnel — unreadable path → `{:error, :enoent}`, never
   `:mismatch` (misreporting infra failure as tamper).
4. `verify/2` `:eisdir` propagation through the same tunnel.

## Gates (real output)

- `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984hw mix test test/xaas/generation/hash_manifest_court_w984hw_test.exs`
  → `4 passed`, exit 0 (fresh lane build root, full compile).
- Mock gate: `mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'`
  → `[]`.

## Cleanup

`rm -rf _build-laneW984hw` — attempted at lane end; result: [see coordinator
note — removal attempted post-receipt].

Standing: ALIVE for the four courted branches; COVERED (typed, no filler) for
the remainder of hash_manifest.ex. No new defect found in the 02902f5c fix.
