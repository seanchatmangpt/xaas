# W984dj6 — GraphlawWasm host reconcile to the witnessed contract (W984dh findings)

Lane W984dj6, v26.10.7 fleet seal. Repo: `/Users/sac/xaas`, branch
`feat/playwright-surface`. No commit (per lane order). Write scope honored:
`lib/xaas/semantics/graphlaw_wasm.ex` + court updates + this receipt.

## Subject identity

- `lib/xaas/semantics/graphlaw_wasm.ex` (untracked, W638-authored; reconciled here)
- `test/xaas/semantics/graphlaw_wasm_test.exs` (W638 court — audited, no edit needed, see 4-point table)
- Witness docs: `w984dh-gwasm-verify.md`, `w644-wasm-roundtrip.md`, `w638-wasmex-host.md`
- Artifact: `priv/graphlaw.wasm` sha256 `b7664a5ed21c254da1ba1a2cf497e6de23406ce935a8c6ce8a9ea8cc7ae43121` (W637 pin)

## State found on read-fresh (disclosed)

Re-reading the file per lane order ("W984cy4's SLA edits folded; read fresh")
showed the working tree had **already moved past W984dh's audit snapshot**:
W638's later fold had landed the allowlist-driven `judge_imports/2` (live in
`admit/2`), the `@free_export`-bound `safe_dealloc/3` (no `@dealloc_export`
anywhere — grep clean), and the witnessed 7-import moduledoc. My diff-scope
against that state:

- **4a. `start/2` @doc still said "zero-import surface"** — the last surviving
  zero-import claim in lib/. Rewritten to the witnessed contract: admission is
  digest pin → compile → WASI-allowlist import surface → required exports;
  names the 7 witnessed imports and discloses that `@wasi_allowlist` is a
  deliberate superset (upstream-tolerant hardening, per W638's own seam note 4).
- **4b. Court audit** — W638's court (`graphlaw_wasm_test.exs`) already asserts
  the witnessed contract, not zero-import: leg 6 admits the real WASI surface
  via `judge_imports` and refuses an injected `env.evil_import`; the round-trip
  and zero-leak legs run through the real 7-import artifact, so they falsify any
  zero-import admission regression by construction. No court edit required.
  Pre-existing, disclosed: one compiler warning at
  `graphlaw_wasm_test.exs:122` (`wasm` unused) — W638-authored, cosmetic, left.
- **4c. Ownership protocol (kept)** — `gl_call` consumes the input buffer;
  `with_buffer/3` deallocs input only on the `:not_consumed` (pre-call failure)
  path. Unchanged, per directive.

## 4-point before/after (task points → state at W984dh audit → reconciled state)

| # | point | W984dh audit state | reconciled state (this tree) |
|---|---|---|---|
| 1 | `judge_imports/2` refused all imports; allowlist dead | allowlist was dead code | `@wasi_allowlist` is the live enforcement inside `admit/2`; stubs derived from the same list (no judge/stub drift); superset-of-7 semantics disclosed in moduledoc + `start/2` @doc |
| 2 | `safe_dealloc/3` read undefined `@dealloc_export` (nil call) | nil-bound | bound to `@free_export` (`gl_free`) — the export W644 witnessed freeing both buffers |
| 3 | docstring claimed "zero-import admission" | moduledoc stale | moduledoc + `start/2` @doc state the witnessed 7-WASI-import surface; zero "zero-import" text remains (`grep` clean across lib/ and test/) |
| 4 | keep W638 ownership protocol | — | unchanged: gl_call consumes input; host deallocs input only pre-call-failure |

Points 1–3 had been fixed in the working tree between W984dh's snapshot and my
read; my session diff is 4a (the `start/2` docstring), plus the audit
establishing 4b/4c. Standing for the reconciliation is grounded in the gate
below, not in who typed the lines.

## Gate — three independent witnesses, ×2 fresh roots, real tails

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dj6 \
  mix test test/xaas/semantics/graphlaw_wasm_test.exs \
           test/xaas/semantics/graphlaw_wasm_load_test.exs \
           test/xaas/semantics/graphlaw_wasm_load_verify_test.exs
→ 16 tests, 16 passed, 0 failures (7.2s), exit 0   [run 1, fresh root _build-laneW984dj6]
```

Run 2 (second fresh root `_build-laneW984dj6b`, identical command):

```
→ 16 tests, 16 passed, 0 failures (11.3s), exit 0   [run 2, fresh root _build-laneW984dj6b]
```

Witness mapping: W638 court 8 legs (`graphlaw_wasm_test.exs`), W644 probe 4
(`graphlaw_wasm_load_test.exs`), W984dh verifier 4
(`graphlaw_wasm_load_verify_test.exs`) — three independently authored courts on
one reconciled contract, all green on the same run.

## Standing

**ALIVE (host transport, reconciled contract)** — real `graphlaw.wasm`
(b7664a5e…) loaded and executed through wasmex 0.15.1 via the adapter; the
W984dh three-point contradiction set is closed (nothing in the adapter now
contradicts the witnessed surface; `zero-import` text zero matches).

Never claimed: production supervision integration; replay receipt pair
(UNSUPPORTED(guest-abi), per W638); no DO authority — transport only.

## Falsifiers (inherited from W638, all still coded)

`:digest_mismatch`/`:digest_unpinned` (witnessed), `:import_surface_mismatch`
(witnessed), `:call_timeout` on spin guest (witnessed), `:missing_export`
(witnessed), `:call_trapped`/`:invalid_json`/`:malformed_response` (coded, not
separately witnessed — disclosed). The 100-invoke zero-leak leg witnesses the
ownership protocol (point 4).

## Cleanup

`_build-laneW984dj6` retained per lane order (coordinator may delete;
`_build-laneW984dj6b` same disposition).
