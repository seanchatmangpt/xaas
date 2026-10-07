# W736 — Xaas.Generation deepening court

- **Subject**: xaas @ a0723bf6, branch `feat/playwright-surface`, canonical checkout `/Users/sac/xaas`
- **Lane**: W736 (read-first deepening; no commit — coordinator integrates)
- **Files written**: `test/xaas/generation_deepening_test.exs` (new, only source change)

## Domain read (O*)

- `lib/xaas/generation.ex` — Ash domain, one resource.
- `lib/xaas/generation/projection_record.ex` — ETS resource; `:admit` create action carries `Xaas.Generation.Validations.NoManualPatch`.
- `lib/xaas/generation/validations/no_manual_patch.ex` — the real admission boundary: computes the real on-disk sha256 of `projection_path`, compares to `recorded_hash`; divergence without `ResidueRegistry` registration refuses with the typed message `forbidden CanonicalGraph + ManualPatch path`.
- `lib/xaas/generation/hash_manifest.ex`, `provenance_header.ex`, `regeneration_verifier.ex`, `residue_registry.ex`, `manifest.ex` — closure components. `Manifest` explicitly does NOT traverse the canonical RDF graph (bounded UNSUPPORTED, per its moduledoc).

## Tests added (Chicago, real files, real Ash ETS, no mocks)

1. **Closure determinism ×3** — same canonical graph bytes → byte-identical rendered projection across 3 runs; on-disk hash equals sha256 of the bytes.
2. **Regeneration matches recorded hash** — same graph regenerates identical bytes; `RegenerationVerifier.verify` → `:match`.
3. **ManualPatch refusal** — hand-patched divergence after hash recording → `Ash.Error.Invalid` with the typed `forbidden CanonicalGraph + ManualPatch path` message naming `Xaas.Generation.ResidueRegistry`.
4. **Patch reversed → re-admits** — refuse first, regenerate exact original bytes, admission succeeds with the original hash.
5. **Mutation check** — different graph → different projection bytes, different sha256, `verify/2` → `:mismatch` crosswise.
6. **Degenerate graph** — empty canonical graph renders a well-formed projection; provenance header carries sha256 of the SOURCE graph (`sha256("")`), `source_path` correct, and admits cleanly.
7. **Missing projection file** — admission refuses with `could not read projection`.

## Receipt

- Command: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW736 mix test test/xaas/generation_deepening_test.exs`
- Real tail: `Result: 7 passed` (0 failures; run under pinned asdf elixir 1.20.2-otp-28)
- Standing: **ALIVE** (lane-local verification on exact tree state a0723bf6 + new test file)
- Typed gaps: the "generator" in the determinism/mutation tests is a test-local deterministic render standing in for a repo-wide g/1 traversal — `Manifest` declares this traversal UNSUPPORTED by design; a real repo-wide g(CanonicalGraph) traversal remains UNBUILT (out of this lane's scope). No `@moduletag :eu_ai_act`. Pre-existing sibling-lane compile contention observed (~10 concurrent lane BEAMs) — disclosed, no effect on this file's result.
- Lane lease: `_build-laneW736` deleted after green run per fanout cleanup law.
