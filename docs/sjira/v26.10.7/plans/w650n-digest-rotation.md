# W650n — Graphlaw WASM digest-rotation reconciliation

Lane: W650n, v26.10.7 fleet seal. Subject: `/Users/sac/xaas` @ `feat/playwright-surface` (uncommitted working-tree lane; not committed per dispatch).
Date: 2026-10-07. Fresh root: `_build-laneW650n` (deleted after run per cleanup law).

## Digest before/after

| artifact | before | after |
|---|---|---|
| `/Users/sac/xaas/priv/graphlaw.wasm` | `b7664a5e…ae43121` (6,657,549 bytes) | `fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38` (6,657,708 bytes) |
| `/Users/sac/xaas/priv/graphlaw.wasm.sha256` | `b7664a5e…ae43121` | `fc23a292…adcb38` |
| `/Users/sac/graphlaw/priv/graphlaw.wasm` (source of rotation, W647) | — | `fc23a292…adcb38` (sidecar-verified, byte size matches) |

Copy was byte-verified: post-copy sha256 of `priv/graphlaw.wasm` equals the graphlaw sidecar
digest `fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38` exactly (re-read from
disk, not from session memory). Cross-repo pin divergence (`~/graphlaw` at fc23a292, `~/xaas` at
b7664a5e) is closed: both repos now pin `fc23a292…adcb38`.

## Pin-site updates (digest-rotation disclosure: W647 rotated the binary; W650n reconciled the consumers)

- `priv/graphlaw.wasm.sha256` — rewritten to fc23a292, path `/Users/sac/xaas/priv/graphlaw.wasm`.
- `test/xaas/semantics/graphlaw_wasm_load_test.exs` (W644 probe) — `@expected_sha256`, `@expected_bytes` (6_657_708), moduledoc (W647-rotation disclosure comment added).
- `test/xaas/semantics/graphlaw_wasm_test.exs` (W638 court) — `@receipt_digest`, moduledoc (W647-rotation disclosure). File was concurrently touched by W984dj6 earlier (mtime 14:25, pre-lane); no mid-write collision (my sed landed cleanly, no b7664a5e residue anywhere in lib/ test/ priv/).
- `test/xaas/semantics/graphlaw_wasm_load_verify_test.exs` (W984dh verifier) — `@expected_sha`, moduledoc.
- `test/xaas/semantics/w640_differential_shacl_test.exs` (sidecar-assert leg) — assertion literal + moduledoc.
- `lib/` — swept: zero `b7664a5e` occurrences in lib/, so no lib-side pin required code change.

## Three-witness table (all on fc23a292, fresh `_build-laneW650n`, MIX_ENV=test, asdf shims)

| witness | suite | result |
|---|---|---|
| W644 probe | `mix test test/xaas/semantics/graphlaw_wasm_load_test.exs` | 4 passed, exit 0 |
| W638 court | `mix test test/xaas/semantics/graphlaw_wasm_test.exs` | 8 passed, exit 0 |
| W984dh verifier | `mix test test/xaas/semantics/graphlaw_wasm_load_verify_test.exs` | 4 passed, exit 0 |
| W640 sidecar-assert leg | `mix test test/xaas/semantics/w640_differential_shacl_test.exs` | 5 passed, exit 0 |

No leg failed on the rotated binary — no typed regression finding. The W647 rotation is
behavior-compatible with all three witnesses on first run.

## W650f pending digest question

Witnessed digest on the reconciled xaas artifact: `fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38`
(6,657,708 bytes), sha256 re-read from `/Users/sac/xaas/priv/graphlaw.wasm` on disk at 15:38 PDT
2026-10-07, matching `~/graphlaw/priv/graphlaw.wasm` byte-for-byte. W650f's question is answered:
the seal-wide digest is fc23a292…adcb38.

## Standing

ALIVE for the reconciliation: artifact copied, sidecar updated, all pin sites rotated, all four
witness suites pass on the rotated binary under a fresh lane build root. Not committed (per
dispatch); files staged-by-edit only. Transport note: PromEx/Grafana nxdomain warnings during
test boot are environmental noise, unrelated to the artifact.

## Commands / exits

- `cp ~/graphlaw/priv/graphlaw.wasm ~/xaas/priv/graphlaw.wasm` + sidecar rewrite; `shasum -a 256` → fc23a292 (exit 0)
- `sed` rotation across 4 test files; `grep -rn b7664a5e lib/ test/ priv/` → zero matches
- 4 × `mix test <suite>` (env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650n`) → all exit 0
- `rm -rf _build-laneW650n` — lane lease deleted per fanout cleanup law
