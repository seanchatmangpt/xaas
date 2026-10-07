# W638b — Sidecar Supersession Receipt (v26.10.7 fleet seal)

Date: 2026-10-07 · Lane: W638b · Repo: /Users/sac/xaas · Branch: feat/playwright-surface (uncommitted, per lane contract)

## Standing

ALIVE (docs-only transition; annotations + disposition + this receipt landed on disk).

## Subject

Operator's Wasmex unification directive supersedes W613/W625's out-of-process
UDS/NDJSON sidecar approach. Grounding: `~/ggen-marketplace` packs
`wasi-json-abi-pack` + `beam-wasmex-host-pack` mandate the in-process packed-u64
ABI via Wasmex → superseding capability is `Xaas.Semantics.GraphlawWasm`
(lane W638; receipts `w638-*`).

## Actions executed

1. **Supersession annotations appended** (dated 2026-10-07, lane W638b,
   superseded-by Wasmex host, spec text retained as history, falsifier cases 1-5
   carried forward to the Wasmex court):
   - `/Users/sac/xaas/docs/sjira/v26.10.7/plans/w613-pep-filter-spec.md`
   - `/Users/sac/xaas/docs/sjira/v26.10.7/plans/w625-pep-skeleton.md`
2. **Skeleton disposition: KEEP as history, no deletion.** The W625 Rust
   skeleton (`docs/sjira/v26.10.7/agentgateway/skeleton/` — Cargo.toml,
   Cargo.lock, src/) is docs-only: it never shipped as lib code and was never a
   dependency of anything. The "retire superseded sidecar code" clause does not
   apply to docs-retained artifacts; deletion would destroy history with zero
   capability surface removed.
3. **lib/ verification: confirmed zero UDS/daemon code from W613/W625.**
   `grep -rniE 'uds|daemon|unix.*(socket|domain)' /Users/sac/xaas/lib/` returned
   only two unrelated incidental hits:
   - `lib/xaas_web/live/marketplace_pplan_explorer_live.ex:28` — substring
     inside the string `"Reseller"` (no UDS semantics)
   - `lib/xaas/ultracode/semantic_crown.ex:873` — a comment about a daemonised
     grandchild process, unrelated to the PEP sidecar
   W613/W625 never wrote lib code; confirmed.

## Consequence

W613/W625 standing becomes SUPERSEDED (history retained). The five falsifier
cases (timeout shim, SIGKILL crash, malformed response, lease absent, digest
mismatch) transfer unchanged to the Wasmex court for lane W638.

## Replay

```
tail -n 14 /Users/sac/xaas/docs/sjira/v26.10.7/plans/w613-pep-filter-spec.md
tail -n 16 /Users/sac/xaas/docs/sjira/v26.10.7/plans/w625-pep-skeleton.md
grep -rniE 'uds|daemon|unix.*(socket|domain)' /Users/sac/xaas/lib/
ls /Users/sac/xaas/docs/sjira/v26.10.7/agentgateway/skeleton/
```

## Falsifier

Any W613/W625 UDS reference found in `lib/` (none found), or a Wasmex court
receipt showing falsifier cases 1-5 not carried forward.

## Boundary

No commits made (lane contract). No mix commands (lane contract). Docs-only diff:
2 annotated plan files + this receipt.
