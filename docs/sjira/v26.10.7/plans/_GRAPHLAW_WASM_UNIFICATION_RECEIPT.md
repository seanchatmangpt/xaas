# GRAPHLAW WASM UNIFICATION RECEIPT — **DRAFT-pending-final-runs**

Wasmex directive Phase 3 deliverable. Compiled by lane W643, v26.10.7 fleet seal, 2026-10-07.
Repo: `/Users/sac/xaas` (branch `feat/playwright-surface`). Every claim cites its landed
receipt; incomplete legs are explicitly DRAFT-flagged and are **not asserted**.

## 1. Git SHAs

| subject | SHA | evidence |
|---|---|---|
| graphlaw wasm profile + digest sidecar commit | `1869a16` (`0bb0df2..1869a16` pushed ff to `origin main`, branch `graphlaw-registry-limits`) | [w637b-graphlaw-commit.md](w637b-graphlaw-commit.md) |
| xaas HEAD at drafting | `f3911592` (`feat/playwright-surface`) | [w639-shacl-typestate.md](w639-shacl-typestate.md) §Receipt; session git status head |

## 2. Artifact digest (.wasm SHA-256)

```
b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121  priv/graphlaw.wasm (6,657,549 bytes)
```

- Source: [w637-graphlaw-wasm-build.md](w637-graphlaw-wasm-build.md) §(4); re-verified on disk
  pre-commit in [w637b-graphlaw-commit.md](w637b-graphlaw-commit.md) (identical digest, size 6657549).
- Binary itself is local-only (`~/graphlaw/priv/graphlaw.wasm`, untracked per repo convention —
  repo tracks no priv artifacts); committed sidecar `priv/graphlaw.wasm.sha256` carries the digest
  (w637b). Consumers replay via the sidecar, not the remote.

## 3. Build surface — ALIVE (witnessed)

Real compile, exit 0, 2m 25s, pinned toolchain 1.96.0, `[profile.wasm]` merge
(opt-level "s", lto, codegen-units=1, strip, panic=abort). WASI purity witnessed:
zero `js_sys`/`wasm_bindgen` strings; MVP header verified via file(1)+xxd; exports
`gl_alloc`/`gl_call`/`gl_free` present by name. FFI merge was a signature-exact NO-OP
(in-tree `graphlaw::abi` FFI already protocol-identical to the wasi-json-abi-pack:
ABI 1, 16 MiB request limit, 256 MiB outstanding cap). Source:
[w637-graphlaw-wasm-build.md](w637-graphlaw-wasm-build.md) §§(1)-(4).

## 4. Wasmex host adapter — **DRAFT-PENDING: receipt does not exist**

The host adapter lane (W638, `Xaas.Semantics.GraphlawWasm` via Wasmex) was reported
running, but **no receipt file `w638-wasmex-host.md` exists at
`docs/sjira/v26.10.7/plans/` as of 2026-10-07** (disk check this session).
Per no-overclaiming: load/execute of `gl_call` through Wasmex is **NOT witnessed**
and is **not asserted**. W637's build receipt itself scopes behavioral courts out of
Phase 1. Consequence: unification standing cannot exceed **ALIVE(build-surface)**.

## 5. Court counts (graphlaw_wasm_test legs) — **DRAFT-PENDING**

`DRAFT-PENDING: w638-wasmex-host.md absent; court counts cannot be read from any
landed receipt and are not asserted.` The five superseded-sidecar falsifier cases
(timeout shim, SIGKILL crash, malformed response, lease absent, digest mismatch)
transfer to the Wasmex court per
[w638b-sidecar-superseded.md](w638b-sidecar-superseded.md); until W638's receipt
lands, the court has no witnessed firing.

## 6. Strict compile output — **DRAFT-PENDING-FINAL**

No strict/final compile run receipt is landed for the unified surface. Marked
pending-final per the directive; will be filled from the final-runs legs
(w638/w640) when they land.

## 7. Differential-SHACL agreement matrix — **DRAFT-PENDING**

`w640-differential-shacl.md` does not exist on disk as of 2026-10-07. The design it
must witness is specified in [w639-shacl-typestate.md](w639-shacl-typestate.md):
in-tree hand-rolled `violations/1` vs guest-side `op:"shacl"` with
`priv/airo/profile.shacl.ttl` as shapes, over a conforming/violating corpus;
agreement = ALIVE, disagreement = typed REFUSED (C14 differential-admission
falsifier). **No agreement rows are asserted.**

### 7.1 C0 row — dual-digest witness (W650f2 update, 2026-10-07)

| Case | Digest witnessed | Guest behavior | Receipt |
|---|---|---|---|
| C0 profile-bytes | `b7664a5e` (W637, pre-repair) | TYPED REFUSAL of raw profile bytes (`EngineRejected / Turtle / iri-disallowed-char`) | [w640-differential-shacl.md](w640-differential-shacl.md) (5/5 ×2 on b7664a5e) |
| C0 profile-bytes | `fc23a292` (post-rotation, post-repair) | ADMISSION of the repaired profile bytes, host/guest conforms-boolean agreement | [w650f-unification-verify.md](w650f-unification-verify.md) (stale-court witness) + [w650f2-c0-flip.md](w650f2-c0-flip.md) (5/5 ×2 on fc23a292) |

C0 flipped in W650f2: the W615 generator owner repaired finding (b) (the
illegal `airo#shapes#` IRI → `airo#shapes-`; w650i's profile repair, repair
witnessed on-disk in `priv/airo/profile.shacl.ttl`; w650i receipt not on disk
as of this lane), so the guest now admits the bytes. C1–C4 rows unchanged
(AGREE on both digests: w640 on b7664a5e, w650f on fc23a292).

Disclosed boundary from W615 (carried forward): no SHACL validator exists in the
Elixir dependency tree; the in-tree checker implements exactly the three compiled
constraints, not a conformant engine. Source:
[w615-airo-shacl.md](w615-airo-shacl.md) §Disclosed boundary.

## 8. Landed context legs (asserted, receipt-cited)

- **W615 AIRO→SHACL**: ALIVE (narrow). Vocabulary pin `airo.ttl` sha256
  `6274d2d8711e046cf38f1b5b2980188094d4aa87b5af79804005a06468fd8469`; profile 46
  NodeShapes / 130 triples; court `test/xaas/airo_shacl_court_test.exs` 5 passed
  ×2 runs, determinism + mutation non-vacuity witnessed. Source:
  [w615-airo-shacl.md](w615-airo-shacl.md).
- **W616 refusal ledger**: PARTIAL_ALIVE (emit + digest replay + fake-variant
  mutation court ×2 fresh roots; artifact uncommitted). 77 canonical entries
  (76 REFUSED_* + 1 BLOCKED_CASTLE_TRANSPORT), 77/77 court-cited; artifact sha256
  `203fee7cd4ec9d7c68d4621469cac248c774a8c102ce6a1cc169f3132bea8f59`; SHA-256 not
  BLAKE3 (blake3 absent from mix.lock, disclosed). Source:
  [w616-refusal-ledger.md](w616-refusal-ledger.md).
- **W638b sidecar supersession**: ALIVE (docs-only). W613/W625 UDS/NDJSON sidecar
  approach SUPERSEDED by the Wasmex in-process packed-u64 ABI; lib/ verified zero
  UDS/daemon code; skeleton retained as history; five falsifier cases carried
  forward. Source: [w638b-sidecar-superseded.md](w638b-sidecar-superseded.md).
- **W639 typestate feasibility**: PARTIAL_ALIVE (read-only assessment). Literal
  Rust typestates are NOT the pack mechanism (guards.rs has none); nearest real
  mechanism is the `law` op's guard-sequence pipeline (n3 → shacl inside one
  gl_call); constraints 1-2 realizable guest-side via `op:"shacl"`, constraint 3
  (file:// citations) stays host-side. Source:
  [w639-shacl-typestate.md](w639-shacl-typestate.md).

## 9. Standing (as of this draft)

**ALIVE(build-surface) only, union PARTIAL_ALIVE(context legs).** The unification
claim — one graphlaw kernel executing in-process via Wasmex with SHACL admission —
remains **UNKNOWN** until W638 (host execute + courts) and W640 (differential
agreement) land receipts.

## 10. Open items to clear the DRAFT flags

1. `w638-wasmex-host.md` lands with: witnessed `gl_call` execution through Wasmex,
   per-leg graphlaw_wasm_test court counts (incl. the five carried falsifier
   cases), artifact digest match vs §2.
2. Strict compile output from the final run (clears §6).
3. `w640-differential-shacl.md` lands with the agreement matrix
   (violations/1 vs op:"shacl" over the corpus) (clears §7).
4. Coordinator integrates this file + w643-unification-receipt.md; DRAFT header
   removed only after 1-3.

## Replay

```
ls /Users/sac/xaas/docs/sjira/v26.10.7/plans/w638-wasmex-host.md   # absent (DRAFT basis)
ls /Users/sac/xaas/docs/sjira/v26.10.7/plans/w640-differential-shacl.md  # absent (DRAFT basis)
shasum -a 256 /Users/sac/graphlaw/priv/graphlaw.wasm
cd /Users/sac/graphlaw && git show 1869a16 --stat
```
