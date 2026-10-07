# W650d — relay-verification lane (W644 → W638/W640 intel relay)

Lane W650d, v26.10.7 fleet seal. Repo: /Users/sac/xaas, branch `feat/playwright-surface`.
Read-only lane; no commit made, no files outside this receipt touched. Date: 2026-10-07.

## Relay verification table

| # | W644 claim | independent check (this lane, real commands) | verdict |
|---|---|---|---|
| 1 | `priv/graphlaw.wasm` + sidecar exist in ~/xaas with digest `b7664a5e…` | `shasum -a 256 priv/graphlaw.wasm` → `b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121`; `ls -l` → 6,657,549 bytes; `priv/graphlaw.wasm.sha256` content identical digest | CONFIRMED |
| 2 | W638 host incorporates the load-leg intel (no template replay pair) | `docs/sjira/v26.10.7/plans/w638-wasmex-host.md` landed; receipt explicitly: "the template's `replay`/`execute` receipt pair is NOT implemented … disclosed UNSUPPORTED(guest-abi)"; `grep -i replay` over `lib/xaas/semantics/graphlaw_wasm.ex` → zero hits (comment line references allowlist only) | CONFIRMED — no divergence |
| 3 | W638 host imports config matches W644's witnessed WASI surface | `lib/xaas/semantics/graphlaw_wasm.ex` `@wasi_allowlist` = 12 signatures, all `wasi_snapshot_preview1`; W644 witnessed exactly 7 imports, all inside the allowlist. Stubs derived from the same allowlist (judge/stub no-drift design). `w638` receipt: 8/8 court ×2 fresh roots, capabilities round trip passed | CONFIRMED — superset allowlist, honest hardening, not divergence |
| 4 | W640 (differential SHACL court) status | `w640-differential-shacl.md` NOT present in `docs/sjira/v26.10.7/plans/` (a `_build-laneW640` build root exists → lane started, receipt not yet landed). Unification claim remains PARTIAL, not upgradeable | PENDING |

## W638 divergence audit (task item 4)

**No integration defect found.** W638's implementation matches W644's witnessed surface:

- No replay pair wired — the template's replay/export pair is absent from the module and
  disclosed as UNSUPPORTED(guest-abi), exactly as W644 directed.
- Input-buffer ownership: W638 refined W644's suggestion ("dealloc and free both bind
  `gl_free`") into a `{:consumed, _} | {:not_consumed, _}` protocol because `gl_call`
  consumes the input buffer — refinement, not contradiction (W644's both-bind-gl_free note
  would have been a double free on the happy path; W638's court leg 6 covers it).
- WASI stubs: zero-return stubs over a 12-signature allowlist superset of the 7 witnessed
  imports (fd_read, args_sizes_get, fd_close, fd_seek, fd_fdstat_get are allowed-but-unimported
  — disclosed as a hardening note in the W638 receipt, correct direction).
- Both lanes report the identical digest b7664a5e… and Wasmex 0.15.1.

## Standing

- W644 load-leg: **ALIVE** (independently re-verified: digest, sidecar, surface claims
  re-read from receipt and cross-checked against files on disk).
- W638 host transport: **ALIVE** (receipt read; per-file disk check shows the module
  present and consistent with the receipt's claims; not re-executed this lane — read-only
  lane, W638's court re-run left to its owner/coordinator).
- W640: **PENDING** — dependency fully satisfied (W644 load-leg ALIVE + W638 host ALIVE
  with real gl_call verdicts). Nothing blocks W640's differential court from running with
  the real op:shacl.
- Unification claim: remains PARTIAL_ALIVE; upgrade to ALIVE requires W640's green run
  (and, further out, the disclosed UNSUPPORTED(guest-abi) replay leg if the guest ABI ever
  gains a replay export).

## Receipts read

- /Users/sac/xaas/docs/sjira/v26.10.7/plans/w644-wasm-roundtrip.md
- /Users/sac/xaas/docs/sjira/v26.10.7/plans/w638-wasmex-host.md
- /Users/sac/xaas/docs/sjira/v26.10.7/plans/w637-graphlaw-wasm-build.md (referenced digest)
