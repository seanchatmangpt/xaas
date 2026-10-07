# Castle Refusal-Negative Coverage (W975)

Campaign v26.10.6. The five refusal classes of the castle Execute surface now have
full court coverage; verified by real runs this lane, 2026-10-07.

## The 5 refusal classes

1. Expired envelope — `REFUSED_XAAS_ADMISSION_EXPIRED` (+ no-expiry-field variant
   `REFUSED_XAAS_ADMISSION_MISMATCH`)
2. Foreign witness — `REFUSED_XAAS_CHECKPOINT_WITNESS_MISMATCH` (witness bound to a
   foreign receipt; also the checkpoint-mutation variant)
3. Missing context — `REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED`
4. Protocol mismatch — `REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH`
   (W863 compare-side `to_string` normalization)
5. Checkpoint replay — `REFUSED_XAAS_CHECKPOINT_HASH_REQUIRED` /
   `REFUSED_XAAS_CASTLE_CHECKPOINT_REQUIRED`

## Court files and pass counts (real runs, this lane)

- `test/xaas/castle_execute_court_test.exs`: 10 passed / 0 failed (128.1s)
- `test/xaas/castle_refusal_negative_test.exs`: 19 passed / 0 failed (4.2s, post-W974)

## Receipts

- w828 — castle execute court baseline
- w863 — castle protocol fix (compare-side to_string normalization)
- w974 — refusal-negative recursion fix (`castle_manufacture/2` self-recursion)

## Disclosed exclusions (carried from w828/w863)

`:castle_kernel` court with the real CASTLE binary not run in this lane.
