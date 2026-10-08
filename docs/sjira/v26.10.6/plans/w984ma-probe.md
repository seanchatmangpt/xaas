# W984ma — in-source KNOWN-DEFECT comment refresh (W984ln repair follow-up)

Lane: W984ma · branch `feat/playwright-surface` · 2026-10-08 · NO COMMIT (lane
contract — coordinator owns commits).

## Subject

W984ln (`docs/sjira/v26.10.6/plans/w984ln-repair.md`) repaired the readiness
`""`-fallthrough defect in `Xaas.Marketplace.Catalog.validate_packs/1` (typed
`:invalid_pack` refusal with `[:invalid_readiness]` detail, before any upsert).
Its receipt flagged that `pack_catalog_depth_test.exs` still carried the
W984bo-era KNOWN DEFECT comment describing the now-repaired raw-raise. This
lane refreshes the documentation; lib behavior is untouched (owned by W984ln).

## Diff (comments only, 1 file, 0 code lines changed)

`test/xaas/marketplace/pack_catalog_depth_test.exs`:

1. Inline comment in `catalog_map/2` (was "KNOWN DEFECT (W984bo finding):
   omitting \"readiness\" entirely makes Catalog.ingest/1 raise
   Ash.Error.Invalid ...") → rewritten to current truth: repaired by W984ln;
   validate_packs/1 refuses non-map/non-binary readiness typed with
   `{:error, %Catalog.Error{reason: :invalid_pack, detail: {i,
   [:invalid_readiness], readiness}}}` before any upsert; cites
   `docs/sjira/v26.10.6/plans/w984ln-repair.md`.
2. Moduledoc coverage item 2 (was "binary passthrough, absent readiness ->
   \"\", mixed-flag map ordering") → stale absent-readiness claim replaced
   with: malformed readiness (nil/integer) is refused typed by
   validate_packs/1 since the W984ln repair; see
   `catalog_court_w984kt_test.exs` leg 4.

No assertion in this file pinned the old raw-raise behavior (court 2 uses a
valid map-form readiness; the typed-refusal behavior change did not affect any
assertion here), so no test-body edit was needed — file ran first to confirm.

## Gates (all executed, real output)

Env for all: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test
MIX_BUILD_ROOT=_build-laneW984ma` (fresh lane build root, pinned asdf
toolchain).

1. `mix test test/xaas/marketplace/pack_catalog_depth_test.exs` →
   `Result: 5 passed`, exit 0.
2. Mock gate: `scan_mock_usage(["test", "lib"])` → `[]`, exit 0.

## Standing

- Comment refresh: ALIVE (file's court 5/5 exit 0 on exact working tree after
  the edit).
- Lane build root `_build-laneW984ma` deleted post-gates per fanout cleanup
  law (see cleanup note below).
- No commit made; the edited file is left in the working tree for integration.
