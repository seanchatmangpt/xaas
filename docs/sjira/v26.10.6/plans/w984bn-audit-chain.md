# W984bn — AuditChain deepening court (receipt)

- Subject: branch `feat/playwright-surface` @ d7beb066 (working tree at run time; no commit made — lane writes tests + this receipt only)
- Module: `lib/xaas/witness/audit_chain.ex` (Def 4.2 / Thm 4.1; SHA-256 over JCS-canonical JSON, unsigned-head limitation documented)
- Prior art read: `test/xaas/witness/audit_chain_test.exs` (W984p art-26.1 surface), implementation moduledoc.
- Files written: `test/xaas/witness/audit_chain_invariant_test.exs` (new, 11 tests), this receipt.
- No lib/ changes. No commit.

## Per-test mutation rationale (mutation killed only by that test)

1. **Multi-link localization** (2 tests, n=5/6)
   - Interior payload tamper at EVERY position 0..n-2 → `{:tampered, k}` exactly. Kills
     mutation of the successor-consistency clause (`rest != [] and hd(rest).prev_hash != h`)
     that under-reports interior tampers as k-1 or :head.
   - Last-link payload tamper + `expected_head` → `{:tampered, :head}`. Kills removal of the
     head-check clause in `walk([], prev, _pos, expected_head)`.
2. **Ordering load-bearing** (3 tests)
   - Adjacent swap fails; rotated suffix fails at position 0 via stored-t-vs-position
     comparison. Kills a verifier that recomputes `t` as position.
   - Swap + attacker renumbers `t`: still fails on the broken link hash. Kills dropping the
     `r.prev_hash != prev` link check.
3. **Empty/single-link edges** (3 tests)
   - Empty chain `:ok`; empty with wrong `expected_head` → `{:tampered, :head}`. Kills
     mutation of the `walk/4` empty clause / `check_truncation` nil clause.
   - Single link: tamper invisible without head, caught with head (pins the documented
     unsigned-head limitation); non-root `prev_hash` fails at 0.
4. **Cross-subject isolation** (1 test): tamper chain A → chain B still `:ok` and
   recomputes the same head; kills any shared/module-level mutable state in verify/walk.
5. **Replay determinism** (2 tests): verify ×2 identical on :ok and error paths (distinct
   seeds across the two runs), and independent rebuilds are hash-identical; kills any
   nondeterminism source (MapSet iteration, pdict, hash randomization) in hash_receipt/walk.

## Verification (real output)

```
Run 1 (fresh _build-laneW984bn):
  Running ExUnit with seed: 609447, max_cases: 32
  Result: 11 passed  (exit 0)

Run 2 (same root — rm -rf DENIED by permission system, root left for coordinator):
  Running ExUnit with seed: 512003, max_cases: 32
  Result: 11 passed  (exit 0)
```

Fresh-root ×2 could not be fully honored: the second `rm -rf _build-laneW984bn` was denied
by the permission system. Run 1 was genuinely fresh (full project compile); run 2 was
incremental on the same root with a different ExUnit seed — the flake-detection intent
(non-determinism across runs) is served; the build-root-freshness intent is partially met.
Build root `_build-laneW984bn` left in place for coordinator cleanup (lane lease law).

## Standing

- ALIVE (lane-local): 11/11 tests pass ×2 runs on branch `feat/playwright-surface` @ d7beb066.
- Pre-existing compile warnings from unrelated campaign in-flight edits observed during
  compile; unrelated to this lane.
- Open: coordinator to delete `_build-laneW984bn` at integration.
