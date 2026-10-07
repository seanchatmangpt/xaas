# W980g — ggen Sync Gate Execution Receipt

- **Lane**: W980g, xaas v26.10.6 campaign. **Date**: 2026-10-07.
- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface` (uncommitted worktree; not
  committed, not pushed — per lane order).
- **Executes**: W954 spec §(b) steps 3-6 + §(d) V1-V4
  (`docs/sjira/v26.10.6/plans/w954-sync-gate-spec.md`).
- **Standing**: **ALIVE** — every command below executed on this subject this session;
  all predicted verifications passed. No falsification of w918.

## Pin advance (P3)

`ggen.toml` `[packs.xaas_castle_bridge]`:

```
-version = "518572b6b53103922ae8a27636a00e982a0907c4"
+version = "b58d7854142bacbd3aeffb83501646cae56c858a"
```

Prereqs verified live before the edit:
- P1: `b58d7854142bacbd3aeffb83501646cae56c858a` exists in `/Users/sac/ggen-marketplace`,
  contained in `feat/aaif-gcp-roadmap-v26.10.5`; `grep -c "117 Ash resources" ontology.ttl` = 1.
- P2: `grep -c "W849" docs/claude/diataxis/reference/generated-surfaces.md` = 1 (w980c relocation present).

## V3 pin-range byte-compare (w918 finding 3)

`git -C /Users/sac/ggen-marketplace diff 518572b6..b58d78541 --stat -- packs/xaas-castle-bridge-pack`:

```
 packs/xaas-castle-bridge-pack/ggen.toml      | 5 -----   (0ce47cc39: pack-local ggen.toml removed)
 .../qualification/project/lib/xaas/castle.ex | 4 ++++    (0ce47cc39: qualification project file)
 packs/xaas-bridge-pack/ontology.ttl          | 9 +++++-  (b58d78541: rationale; matches w937)
```

Attribution clean: `b58d78541` itself = exactly w937's 2 files (+56/-1:
`ontology.ttl` rationale line + `tests/test_airo_pin_w687.py`); 0ce47cc39 contributed
only the predicted inter-pin pack-byte side effects, neither of which feeds the errc
page template (confirmed by the clean diff gate below).

## Sync execution — two typed transport failures, both resolved by tool-stated remediation

1. **[FM-PACK-008]** content-hash mismatch: `ggen.lock` recorded the OLD pin's hash
   (`c5e128e3…`) while the on-disk pack at the NEW pin hashes `0deefa44…`. Remediation
   per error text: delete `ggen.lock` to intentionally re-lock. Done; lock regenerated
   at the new pin (`blake3:0deefa44…`), untracked as before (never git-tracked).
2. **[FM-WRITE-005]** generated page "exists with differing content; refusing silent
   clobber. Remediation: set `force: true`" — but `force` is per-template frontmatter
   (`castle-errc.md.tmpl` has none), not a CLI/ggen.toml flag at ggen 26.9.28. Applied
   the equivalent mechanical path: removed the generated page, re-ran sync
   (`files_generated=1`, EXIT=0). Diff gate is against HEAD, so gate validity is
   unaffected. Open item for a future lane: add `force: true` (or backup) to
   `castle-errc.md.tmpl` frontmatter upstream so pin advances regen without the
   delete-first dance.

## Diff gate (w918 §c falsifier) — PREDICTION HELD

`git diff HEAD -- docs/claude/diataxis/reference/generated-castle-bridge-errc.md`
shows **exactly two hunks**:

1. Line 10 (ELIMINATE-10 "Why" cell):
   - OLD: `XaaS already owns 69 Ash resources and seven domains; …`
   - NEW: `XaaS already owns 117 Ash resources via the Xaas.Resource wrapper (152 total use Ash.Resource) and 19 domains; …`
2. Census-section deletion: `## SIBLING generated projections coverage (W849 census)`
   H2 through the trailing `8 DRIFT-CHECKED / 4 PROVENANCE-ONLY / 0 UNPINNED` paragraph.

No third hunk. All other 12 rows, header blockquote, closing paragraph byte-identical.
`files_generated=1` in emit stage → the other 6 pack-template outputs untouched.

## Drift guard (V4)

`PATH=$HOME/.asdf/shims:$PATH mix test test/xaas/generated/registry_drift_guard_test.exs`
→ `1 test, 1 passed` (asdf toolchain per repo memory; Homebrew-elixir shadow avoided).

## Post-sync verification (V1/V2)

- **V1 stability**: sync re-run twice more; page sha256 byte-identical across runs,
  `SYNC_EXIT=0`:
  `8e41a7de4c2f0da55a4810c3a088cbcdd7c8f5be420d9046bfba31bf2a16ada7`
- **V2 census relocation survives**: `grep -c "W849 census"` on regenerated page = **0**;
  `grep -c "W849"` on `generated-surfaces.md` = **1**; both relocation files present
  (untracked, from w980c): `docs/claude/diataxis/reference/generated-surfaces.md`,
  `docs/cro/artifacts/generated-surface-census-v26.10.6.md`.

## Worktree state left for integration (not committed)

- `M ggen.toml` (pin advance)
- `M docs/claude/diataxis/reference/generated-castle-bridge-errc.md` (2-hunk regen diff vs HEAD)
- untracked: `generated-surfaces.md`, `generated-surface-census-v26.10.6.md` (w980c outputs)
- untracked: `ggen.lock` (regenerated at new pin; untracked by design)
