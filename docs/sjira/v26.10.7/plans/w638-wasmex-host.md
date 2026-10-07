# W638 — Wasmex host transport for the graphlaw kernel (Wasmex unification Phase 2)

Lane W638, v26.10.7 fleet seal. Date: 2026-10-07. Repo: `/Users/sac/xaas` (canonical checkout, branch `feat/playwright-surface`, HEAD f3911592 at lane start). Not committed, per directive.

## Subject

- `lib/xaas/semantics/graphlaw_wasm.ex` (new)
- `test/xaas/semantics/graphlaw_wasm_test.exs` (new court, 8 legs)
- `test/support/graphlaw_spin_guest.rs` (new watchdog fixture source)
- `mix.exs`: `{:wasmex, "~> 0.15"}` added directly to deps
- `priv/graphlaw.wasm` + `priv/graphlaw.wasm.sha256` (installed copies of W637's artifact; sha256 `b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121`)
- mix.lock: **NO-OP** — wasmex 0.15.1 was already locked via ggen_igniter (`~> 0.9` admits 0.15.1); real `mix deps.get` after the mix.exs addition changed nothing in mix.lock

## Dependency on W637

W637 landed mid-lane: artifact at `~/graphlaw/priv/graphlaw.wasm` (6,657,549 bytes), digest byte-identical to `docs/sjira/v26.10.7/plans/w637-graphlaw-wasm-build.md` (b7664a5e...). The .wasm and a `sha256sum`-format pin file were installed into `priv/` (disclosed above). The court re-derives the digest from bytes and asserts it equals the receipt digest, so the pin is receipt-anchored, not trusted.

## Seam analysis (grounded in the template + probed wasmex 0.15.1 reality)

1. **Refusal shape** — the directive named `Xaas.Refusal`, which does not exist in lib/. The real typed refusal shape is `Xaas.Actuation.Refusal` (Splode, `:code`/`:detail`, class `:forbidden`), so refusals are ledger-indistinguishable from policy outcomes. Court asserts on `%Refusal{code: ...}` structs.
2. **wasmex import type shape** — `Wasmex.Module.imports/1` returns `%{ns => %{name => {:fn, params, results}}}` with string ns; the template's `%{params: ..., results: ...}` map shape does not exist in 0.15.1. The first judge version refused EVERY import (fail-closed direction — witnessed firing); the court caught it and the tuple shape was fixed.
3. **Input-buffer ownership** — the template's separate `dealloc` export does not exist in the graphlaw ABI. Per `~/graphlaw/wasm/src/lib.rs`, `gl_call` CONSUMES the input buffer, so a host `gl_free` after a completed call is a double free. The host deallocs input only on the pre-call failure path (write failure) via an explicit `{:consumed, _} | {:not_consumed, _}` ownership protocol in `with_buffer/3`. If `gl_call` exits (watchdog), the input is not freed (consumed-or-unknown, bounded by the guest's own OUTSTANDING cap).
4. **WASI imports are real** — the wasip1 build imports 7 `wasi_snapshot_preview1` functions (probed: clock_time_get, environ_get, environ_sizes_get, fd_write, proc_exit, random_get, sched_yield). Modeled as wasi-only admission: hard `@wasi_allowlist` (12 signatures), judge refuses anything outside; instantiation stubs are derived from the SAME allowlist so judge and stubs cannot drift. Allowlist is upstream-tolerant (fd_read etc. allowed but currently unimported — hardening note for the coordinator, not a defect). WASI stubs return zero values; the capabilities round trip passed with zero stubs, and the HOST owns the watchdog, so zero-stubs are honest for this surface. Exports probe also shows `__wbindgen_*` exports (wasm-bindgen machinery, zero js imports — consistent with W637's purity check; unused by the ABI).

## Court verdicts (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW638 \
  mix test test/xaas/semantics/graphlaw_wasm_test.exs
# => Result: 8 passed   (and again from a fresh root _build-laneW638b)
```

| leg | verdict |
|---|---|
| statutory round trip `{"op":"capabilities"}` through the real artifact | PASS (`response["ok"] == true`) |
| zero-leak: 100 real invokes, all `{:ok, _}` (guest OUTSTANDING cap holds) | PASS |
| digest-mismatch (wrong pin) → `:digest_mismatch` | PASS |
| digest-unpinned (nil pin) → `:digest_unpinned` | PASS |
| installed pin == W637 receipt digest (re-derived from bytes) | PASS |
| import judge admits real WASI surface / refuses injected `env.evil_import` | PASS (fail-closed witnessed) |
| watchdog on spin guest (200M-iteration spin past 15ms) → `:call_timeout` | PASS |
| missing-export → `:missing_export` | PASS |

8/8 passed. Mock gate: `scan_mock_usage` on lane files → `[]`.

## Verification ladder

- **This closes W637's disclosed gap**: W637 marked "NOT yet witnessed: actual load/execute of gl_call through Wasmex". Now witnessed on the exact digest-pinned bytes.
- narrow→unit: compile clean (zero warnings from lane files after fixes), 8-leg court 8/8 on the lane root, then 8/8 again from a fresh build root (`_build-laneW638b`).
- Cross-check: digest asserted equal to the W637 receipt, not to the pin file alone.

## Standing

**ALIVE** (host-transport surface, exact-subject witnessed: real `graphlaw.wasm` b7664a5e... executed through wasmex 0.15.1, 8-leg court 8/8 ×2 fresh roots).

Never claimed: production supervision integration (no supervisor child spec added); no DO authority — transport only; the template's `replay`/`execute` receipt pair is NOT implemented (the graphlaw guest ABI has no replay export, so it cannot be witnessed without a guest change — disclosed UNSUPPORTED(guest-abi) for that leg).

## Falsifiers

1. Digest drift in `priv/graphlaw.wasm` or the pin file → `start/1` refuses `:digest_mismatch` / `:digest_unpinned` (both witnessed).
2. Any import outside `@wasi_allowlist` (or outside `wasi_snapshot_preview1`) → `:import_surface_mismatch` (witnessed via injected offender).
3. `gl_call` exceeding 15ms → `:call_timeout` (witnessed on the spin guest).
4. `gl_call` trap → `:call_trapped` (coded, not separately witnessed — disclosed).
5. Non-JSON / non-object response → `:invalid_json` / `:malformed_response` (coded, not separately witnessed — disclosed).
6. Failing the 100-invoke leg would falsify the ownership protocol — passed.

## Cleanup

- `/tmp/w638-graphlaw-spin-guest.wasm{,.sha256}` — fixture cache in /tmp, not the repo.
- Lane build roots `_build-laneW638` and `_build-laneW638b` deleted after the fresh-root run lands, per the fanout cleanup law (coordinator may re-create by rerunning the court; deps/ additions — wasmex — remain for other lanes).
- No commit made (directive). Working tree carries everything under Subject.
