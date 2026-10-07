# W921 — Fresh Build Root Divergence: Root Cause

Lane: W921, v26.10.6 campaign, repo `/Users/sac/xaas` (branch `feat/playwright-surface`).
Date: 2026-10-07. Standing: **ALIVE** (root cause diagnosed, confirmed by fresh-root compile going green after W902's fixes landed).

## Root cause: hypothesis (a) — stale shared .beam masking a transiently broken in-flight tree

W894's fresh-root failure at `lib/xaas/library/checkout.ex:91` (`misplaced operator ^user_id`) was the
genuine, transient state of W902's in-flight uncommitted edits. The shared `_build/test` compiles "clean"
only because its `.beam` for the affected files predated the edits — mix's freshness check never recompiled
them there. Mechanism, fully evidenced:

1. **Shared-root staleness window.** `_build/test/lib/xaas/ebin/Elixir.Xaas.Library.Checkout.beam` mtime
   `06:27:39`; source `lib/xaas/library/checkout.ex` mtime `06:38:19`. The shared build was 11 minutes stale
   against the working tree — the divergence W894 saw between fresh and shared roots.

2. **The in-flight tree was genuinely broken; three transient states observed while W902 edited.**
   - State 1 (seen by W894): `checkout.ex:91` — `misplaced operator ^user_id` — an
     `Ash.Query.filter(user_id == ^user_id ...)` pin inside the W902 borrow-cap change; macro-expansion-time
     error (the file tokenizes clean standalone — `Code.string_to_quoted/1` returned PARSE_OK — so the failure
     is in Ash's expression compiler, not the Elixir parser).
   - State 2 (my first fresh-root compile, ~06:40): `lib/xaas/governance/audit_export_token.ex:121` —
     `FunctionClauseError` in `Keyword.put_new/3` (`increment(:use_count, 1)` passing a bare integer as the
     keyword list). Fixed in-flight at 06:47 as `increment(:use_count, amount: 1)`.
   - State 3 (my second fresh-root compile, ~06:52): `audit_export_token.ex` — "Duplicate routes defined for
     patch: /:id" (AshJsonApi transformer error). Fixed in-flight at 06:56.

3. **Dep-version divergence excluded (hypothesis (b) rejected).** Both build roots live in the same
   checkout: the fresh lane root resolves from the same `mix.lock` and same `deps/` directory as the
   shared root, so a dep-version mechanism is structurally impossible here (the error transcripts name
   the same locked versions, e.g. `ash 3.34.4`, in the fresh root).

4. **Generated-code path divergence excluded (hypothesis (c) rejected).** No generated-surface difference: the
   same `ggen` manifests apply to both roots; the failing files are hand-written resource modules, not
   generated projections. (c) rejected.

## Compile outputs (real, both ways)

- Fresh lane root (`MIX_BUILD_ROOT=_build-laneW921`, 06:40 run): `== Compilation error in file
  lib/xaas/governance/audit_export_token.ex ==` FunctionClauseError `Keyword.put_new/3` at
  `ash 3.34.4 builtins.ex:125 increment/2`, `audit_export_token.ex:121` → failed.
- Fresh lane root (06:52 run): `Duplicate routes defined for patch: /:id` at `audit_export_token.ex:1`
  (AshJsonApi transformer) → failed.
- Shared root, plain `mix compile` (06:54–06:55, non-force): recompiled 13+4 files including the stale
  sources; exit 0, `Generated xaas app`. (A plain non-force compile recompiles the stale files since source
  mtime > beam mtime — this is the proof the shared root was only *stale*, not clean.)
- Fresh lane root, after W902 landed (06:56+ sources; third run): compiled all 934 files, `Generated xaas
  app`, **exit 0**. W902's landed state fixes the fresh root; checkout.ex:91 no longer fails.
  Shared beam refreshed 06:53 (183,748 bytes, refreshed by the shared-root compile).

## Fix ownership

W902 owns and has landed the fixes (checkout.ex pin-filter fix and audit_export_token.ex
`increment/2` keyword + route-duplicate fix). No W921 diff; W921 changed zero source files.

## Disposition

- Standing: **ALIVE** — the diagnosis is confirmed by the fresh root compiling exit 0 after W902's fixes
  landed (the "wait-and-retry once" condition resolved positively).
- Lane build root `_build-laneW921` deleted per fanout cleanup law (356 MB reclaimed).
- No commits made. Receipt only.

## Method note (permanent guard candidate)

The shared-root "clean" signal is only as fresh as mix's mtime freshness check over an actively-edited
tree: during in-flight lanes, a shared-root compile can pass on stale .beam files, while any fresh root
exposes the real tree state. Fresh-root compile is the honest gate during fan-out. Consider a campaign
guard: during active lanes, "shared build clean" is not admissible evidence of tree health; require a
fresh-root (or at minimum, a non-force shared recompile) before declaring BUILD_ALIVE.
