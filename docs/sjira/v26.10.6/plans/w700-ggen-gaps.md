# W700 — ggen gap audit → xaas fill

Lane: W700, cross-project gap wave (ggen → xaas). Date: 2026-10-06.
Subjects: /Users/sac/ggen (read-only audit) → /Users/sac/xaas @ feat/playwright-surface.

## Audit: ggen surface → xaas equivalent

| ggen surface | ggen locus | xaas status | verdict |
|---|---|---|---|
| sync-drift CI gate | closure-gates-style `ggen sync run` + `git diff` refusal | PRESENT: `.github/workflows/closure-gates.yml` root-sync-drift leg (§3 gate 1, advisory) | covered |
| portable_receipt exact-SHA replay | ggen-engine `portable_receipt.rs` | PRESENT: `.ggen-v2/receipt-portable.json` + `Xaas.Deployment.ReleaseSnapshot` + `mix xaas.release_snapshot.verify` | covered |
| docs-sync drift gate (`justfile docs-sync`) | generated docs must be content no-ops; git diff = drift | NOT PRESENT, and **no xaas surface is generated docs** — diataxis docs are hand-authored; no merge regions in README/CLAUDE.md. Nothing to drift. | skipped-typed: no generated-docs surface exists to gate |
| verify-tcps evidence loop (`justfile verify-tcps`) | evidence emitters + gate refusal of red/missing/stale evidence + `ggen receipt verify` | PARTIAL: `r79-tcps-admission.yml` covers the TCPS admission leg; the **receipt chain verification** (`ggen receipt verify` semantics) had no xaas equivalent | FILLED (test below) |
| marketplace validate | `ggen-marketplace/src/marketplace/validation.rs` | xaas CONSUMES packs via ggen.toml pins; **no test bound ggen.toml pins to ggen.lock or to the minted receipt** | FILLED (test below) |
| ggen-sync-run selftest workflow | `ggen-sync-run-selftest.yml` | xaas equivalent infeasible in-test (external Rust toolchain); frozen-content side already owned by `test/xaas/generated/registry_drift_guard_test.exs` sha pins; CI leg covers regen | skipped-typed: external-toolchain; CI + sha-pin division of labor already covers |

## Filled

`test/xaas/ggen_lock_closure_test.exs` (new, Chicago: real files, real parsing,
asserts on real state):

1. ggen.toml `[packs.*]` pins ↔ ggen.lock entry set equality, exact
   `git:<url>@<40hex>#<subdir>` source match, blake3:64hex content_hash format.
2. Lock-orphan direction named explicitly.
3. `.ggen-v2/receipt-log.jsonl` chain linkage: valid JSON per line, `record`
   with chain fields, genesis prev = 64 zeros, each prev_chain_hash_hex ==
   prior chain_hash_hex (mirrors `ggen receipt verify`).
4. `.ggen-v2/receipt-portable.json` required receipt fields + standing==ALIVE +
   subject.pack_digest sha256:64hex.
5. Declared `[ontology] source` and `[templates] dir` exist on disk.

## Skipped (typed)

- **docs-sync gate** — UNSUPPORTED(no-generated-docs-surface): xaas generates no
  docs; a drift gate over hand-authored docs would be a content-free check.
- **ggen-sync-run selftest in-test** — REFUSED(external-toolchain): same
  disclosed boundary as registry_drift_guard_test.exs; covered by the
  root-sync-drift CI leg + sha pins.

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_BUILD_ROOT=_build-laneW700 \
  mix test test/xaas/ggen_lock_closure_test.exs
Running ExUnit with seed: 307077, max_cases: 32
Excluding tags: [:stress, :kind, ..., :castle_kernel, :eu_ai_act]
.....
Finished in 0.1 seconds (0.1s async, 0.00s sync)
Result: 5 passed          [exit 0]
```

No lib/ or config/ files touched; existing suites untouched. Lane build root
`_build-laneW700` deleted at integration per cleanup law.

## Standing

ALIVE — 5/5 real-file tests green on the pinned subject; skipped gaps carry
typed reasons (UNSUPPORTED no-generated-docs-surface; REFUSED
external-toolchain with CI+sha-pin coverage already present).
