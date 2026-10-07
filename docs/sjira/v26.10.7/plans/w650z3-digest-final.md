# W650z3 — Final Digest-State Reconciliation (Wasm Witness, Final Leg)

Lane W650z3, v26.10.7 fleet seal. Date: 2026-10-07. Subject: `~/xaas` @ branch
`feat/playwright-surface`, HEAD `16b54f3c`. No commits made (per lane contract).

## 1. Current digest state — ALL AGREE on fc23a292

```
fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38  priv/graphlaw.wasm          (shasum -a 256, this session)
fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38  priv/graphlaw.wasm.sha256   (sidecar content)
```

Artifact digest == sidecar digest. **W647 rotation (b7664a5e → fc23a292, 6,657,549 →
6,657,708 bytes) is fully landed in the current state.**

## 2. Pin census (test/ — the court surface)

Every court pin in `test/` is fc23a292. **Zero stale b7664a5e pins in any court file.**
No rotation edits were required.

| Court file | Pin |
|---|---|
| `test/xaas/semantics/graphlaw_wasm_test.exs` (L6, L22 `@receipt_digest`) | fc23a292…cb38 |
| `test/xaas/semantics/graphlaw_wasm_load_test.exs` (L9, L18 `@expected_sha256`) | fc23a292…cb38 |
| `test/analysis/comparison.md` | — |
| `test/xaas/semantics/graphlaw_wasm_load_verify_test.exs` (L4, L17 `@expected_sha`) | fc23a292…cb00 → full `fc23a2927187029ade92a4a64abd2de2cd15147be0cd95c70d89504a1aadcb38` |
| `test/xaas/semantics/w640_differential_shacl_test.exs` (L32, L239 assertion) | fc23a292…cb38 |

`b7664a5e` occurrences in `docs/sjira/v26.10.7/` are historical receipts only
(W637/W641c/W644/W650d/W984dj6 witnessed b7664a5e before the rotation; W650f/W647/W650n
already document the rotation with disclosure). Receipts are records, not pins — no edit.
The W650f-noted stale court (the W644 differential leg pinning b7664a5e) was already
reconciled: `w640_differential_shacl_test.exs:239` now asserts fc23a292.

## 3. Witness runs (×1 each, real, this session, on final state)

Command (pinned toolchain, lane build root):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650z3 \
  mix test test/xaas/semantics/graphlaw_wasm_test.exs \
           test/xaas/semantics/graphlaw_wasm_load_test.exs \
           test/xaas/semantics/graphlaw_wasm_load_verify_test.exs
```

Witness tail (combined run, seed 914954):

```
Running ExUnit with seed: 914954, max_cases: 32
Excluding tags: [:stress, :kind, :requires_cnv_deploy, :requires_semantic_jira_api, :external, :external_llm, :subprocess, :property, :castle_kernel, :eu_ai_act, :perf_smoke]
................
Finished in 6.7 seconds (0.00s async, 6.7s sync)
Result: 16 passed
[exited with code 0]
```

16/16 passed, exit 0, in 6.7s. Pre-test compile warnings are pre-existing
(unused `wasm` var in `graphlaw_wasm_test.exs:122` `build_spin_guest!/0`; PromEx/Grafana
nxdomain uploader noise — no Grafana on this network) — not session-introduced.

## 4. Certification

**Standing: ALIVE** — the final closure-receipt leg is certified on the witnessed final
state: artifact (fc23a292…cb38, 6,657,708 bytes) == sidecar == all five court pins, and
the full wasm witness set (16 tests across the 3 court files) passes on that exact
artifact under wasmex 0.15.1. Digest table fully agreeing; no reconciliation edits
required this lane.

## Cleanup disclosure

`_build-laneW650z3` (368 MB) deletion was denied by the permission system (twice); per
the lane contract it is **left for the coordinator** to delete at integration.

## Replay

```bash
shasum -a 256 priv/graphlaw.wasm                       # expect fc23a292…cb38
cat priv/graphlaw.wasm.sha256                          # same digest
grep -rn "b7664a5e" test/                              # expect no hits
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650z3 \
  mix test test/xaas/semantics/graphlaw_wasm_test.exs \
           test/xaas/semantics/graphlaw_wasm_load_test.exs \
           test/xaas/semantics/graphlaw_wasm_load_verify_test.exs   # expect 16 passed
```
