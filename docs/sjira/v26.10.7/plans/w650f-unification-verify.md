# W650f — Independent unification verification (closure-receipt final leg)

Lane W650f, v26.10.7 fleet seal. 2026-10-07. Repo `/Users/sac/xaas`, branch
`feat/playwright-surface`, HEAD at write time `c6a750bb` (moved during lane;
started near `f3911592`). Not committed (lane contract). Receipt only.

## Digest witnessed: fc23a292 (rotation reconciled)

At lane start, `priv/graphlaw.wasm` carried sha256
`b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121` (6,657,549
bytes, W637 build). At 15:03 the W647/W650n rotation replaced both the binary
(6,657,708 bytes, mtime 15:03) and the sidecar, and the owning lane updated
`test/xaas/semantics/graphlaw_wasm_test.exs` (`@receipt_digest` now
`fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a8…` — exact value
`fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38`) and
`test/xaas/semantics/w640_differential_shacl_test.exs` (line 222 hard-pins
fc23a292) **before** my runs executed. Re-hashed post-run:

```
fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38  priv/graphlaw.wasm
fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38  priv/graphlaw.wasm.sha256  (same digest)
```

Every run below exercised the **fc23a292** artifact — digest witnessed by
execution, not by file reads alone: the court's digest leg (sidecar == pin ==
`GraphlawWasm.digest(bytes)` == fc23a292) is one of the 8 passing legs.

## Run ledger (real tails)

Command form:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650f mix test <file>`

| # | court | file | result | tail |
|---|---|---|---|---|
| 1 | W638 host court, run 1 (fresh `_build-laneW650f`, cold compile of the full dep tree) | `test/xaas/semantics/graphlaw_wasm_test.exs` | 8/8 | `Result: 8 passed` — exit 0 |
| 2 | W638 host court, run 2 (warm) | same | 8/8 | `Result: 8 passed` — exit 0 |
| 3 | W640-named fuzz court (OS-21), ×1 | `test/xaas/semantics/admission_fuzz_test.exs` | 9/9 | `Result: 9 passed` — exit 0, one pre-existing expected-refusal IO.inspect noise line (admission_fuzz_test.exs:327 nonneg_number) |
| 4 | W640 differential-SHACL court, ×1 | `test/xaas/semantics/w640_differential_shacl_test.exs` | 4/5 | `Result: 4/5 passed, Failed: 1 test` — C0 |

Run 4 first attempt hit a transient cross-lane compile break
(`lib/mix/tasks/xaas.release_audit.ex`, another lane mid-edit; cleared within
the compile-freeze SLA window). Second attempt ran clean and produced the 4/5.

## Certified verdict

**ALIVE (unified execution, digest fc23a292)** — with one stale-court
disclosure.

- W638 host court: **8/8 ×2** on fc23a292 (round trip, zero-leak ×100,
  digest-mismatch/unpinned refusals, pin match, import judge, watchdog
  timeout, missing-export refusal — all through real Wasmex execution of the
  artifact). W638's "no witnessed firing" DRAFT flag in
  `_GRAPHLAW_WASM_UNIFICATION_RECEIPT.md` §5 is **cleared by witnessed
  execution**.
- W640 fuzz court: 9/9 (OS-21 leg of W640 satisfied, witnessed).
- Differential-SHACL: the agreement matrix **holds** — C1–C4 AGREE rows pass
  (conforms-boolean + focus-node sets host `violations/1` vs guest
  `op:"shacl"` on the repaired profile). C0 ("guest refuses raw profile
  TYPED") now **fails, and that failure is the expected post-fix state**: at
  15:18 the W615 generator owner repaired finding (b) (the illegal
  `airo#shapes#` IRI → `airo#shapes-`), so the guest now ADMITS the raw
  profile bytes. The court's C0 asserted the defect-firing; the defect no
  longer exists. This is a **stale-court disclosure, not a unification
  defect**. Coordinator should have the court owner update C0 to assert
  guest-admission on the repaired bytes (C1–C4 unchanged).
- `w640-differential-shacl.md` landed mid-lane (was absent at drafting);
  its ×2 5/5 runs witnessed **b7664a5e**; my run witnessed **fc23a292** —
  the agreement matrix now has witnessed executions on **both** digests of
  the agreement itself, and the C0 discrepancy is fully explained by the
  finding-(b) repair, not digest drift.
- Unification receipt `_GRAPHLAW_WASM_UNIFICATION_RECEIPT.md` §9/§10 open
  items 1–3 are each witnessed by this lane's runs; W640 finding (c)
  (zero-value WASI stubs trap on real SHACL workload) remains as disclosed
  by W640 — the differential court uses a real WASI store with digest pin,
  which is the witnessed surface.

## Standing

**ALIVE (unified execution on fc23a292), scoped**: W638 host surface (8
legs ×2) + W640 agreement matrix (C1–C4) + OS-21 fuzz (9 legs), all executed
against digest fc23a292 with digest-pin leg passing. NOT asserted: SHACL
conformance beyond the corpus; real-workload execution through
`GraphlawWasm.invoke` with zero-value WASI stubs (W640 finding c, open);
profile-bytes typed refusal (superseded by the finding-(b) repair).

## Falsifiers fired this lane

1. C0 stale-court failure — traced to the finding-(b) generator repair
   (15:18), not digest drift: C1–C4 agreement rows pass on the same run.
2. Transient cross-lane compile break (`xaas.release_audit.ex`) — cleared
   within the compile-freeze SLA window; unrelated to graphlaw surface.

## Replay

```
cd /Users/sac/xaas
shasum -a 256 priv/graphlaw.wasm   # expect fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650f \
  mix test test/xaas/semantics/graphlaw_wasm_test.exs            # 8 passed
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650f \
  mix test test/xaas/semantics/admission_fuzz_test.exs            # 9 passed
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650f \
  mix test test/xaas/semantics/w640_differential_shacl_test.exs   # 4/5 (C0 stale post-fix)
```

## Lane hygiene

`_build-laneW650f` deleted at lane end per cleanup law (attempted; see
coordinator note if rm was denied).
