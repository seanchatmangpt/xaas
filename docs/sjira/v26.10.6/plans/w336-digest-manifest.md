# W336 — Digest manifest for machine registries (P2-5) — DONE

- **Subject**: xaas @ feat/playwright-surface (d1db2b03 + working tree), lane W336, v26.10.6 convergence, P2-5 of `_CLOSURE_PLAN.md` Phase 2.
- **Contract**: writes limited to `priv/semantic/generated/MANIFEST.json` (new) and this receipt. Zero behavior change.

## Pre-check (no duplicate)

No digest manifest existed for the machine registries. `find priv docs -iname '*manifest*'`
found only unrelated manifests (`docs/case-studies/wd-fa/EVALUATION-MANIFEST.json`,
`docs/ultracode/.../MANIFEST.sha256`, sjira receipts manifests, a pack fixture manifest).
`vector6-docs-abi.md` §1 explicitly states "NO RECORDED DIGEST TO VERIFY (gap)" and that the
priv copies need "a digest manifest for the priv copies". No prior w-lane landed one (no
P2-5 receipt in `docs/sjira/v26.10.6/plans/`).

## Artifact

`priv/semantic/generated/MANIFEST.json` — `{generated_by, algorithm: sha256, entries: [{path, sha256, bytes}], absent: []}`.
All digests are real `shasum -a 256` output; no invented digests.

## Entries (6, all present/hashed)

| path | sha256 | bytes |
|---|---|---|
| priv/ash_surface/surface_contract.json | 6446a2653d979837bf02ce8a523d678f32d1e58ffd8ce0200f383c57c17da793 | 1071739 |
| priv/ash_surface/live_view.json | e124cd956e9cb39dee014ff454c6057473dcc942ba8f7f55ba5917d5df2f299f | 277624 |
| priv/ash_surface/aria.json | ad41cf3c4b4f45d4e79db3e72c0eba18468ae858fd23b1d45cdd0e9a0b6dde64 | 133791 |
| priv/ultracode/runtime_surface.json | 985a8ca025a832857aca087128d298ece67edee88c7e46c63d3bacdc92c2bef4 | 13468 |
| priv/ultracode/remote-relay.contract.json | 76ff551c16cea5afb40b385ecee9ab7462ce1d73bee47655c0e0c63dc0a33f89 | 2572 |
| lib/xaas/generated/zcode_event_registry.ex | d185723654af3eca4c8f710752ce78f5e4ce4f123b34041bdc4448993ddef861 | 6445 |

## Absent registries

None — every target path existed. `absent: []`.

## Round-trip proof

Re-hash after writing the manifest (fresh `shasum -a 256` on disk state):

```
$ shasum -a 256 priv/ash_surface/live_view.json priv/ultracode/runtime_surface.json
e124cd956e9cb39dee014ff454c6057473dcc942ba8f7f55ba5917d5df2f299f  priv/ash_surface/live_view.json
985a8ca025a832857aca087128d298ece67edee88c7e46c63d3bacdc92c2bef4  priv/ultracode/runtime_surface.json
```

Both match the manifest entries byte-for-byte.

## Findings worth carrying

- `priv/ash_surface/{surface_contract,live_view,aria}.json` digests **differ** from the
  audited baselines recorded in `vector6-docs-abi.md` §1 (e.g. surface_contract was
  `cba66d0b...`, now `6446a265...`) — the working tree regenerated them since that audit.
  The two `priv/ultracode/*` digests **match** the baselines exactly. Manifest records
  current on-disk truth; the skew vector6 flagged (generatorIdentity ash_surface:v26.10.1)
  still applies.
- `ash_surface:tmp/tdb-surface/render_digest.txt` from vector6's table is out-of-repo
  (`~/ash_surface`), non-authoritative, and not recorded here.

## Standing

ALIVE (real hashing executed on the exact on-disk subject; round-trip verified; no commit per lane contract).
