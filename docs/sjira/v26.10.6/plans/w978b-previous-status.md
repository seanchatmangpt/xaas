# W978b Receipt — previous_status support (W968c / SPEC-14)

Date: 2026-10-07 · Lane W978b · repo /Users/sac/xaas @ feat/playwright-surface fc14f10b (plus in-flight lane edits)

## Finding (primary)

The W968c gap is **already closed on disk** by the sibling refactor lane. No code change
was needed or made by W978b:

- `lib/xaas/operations/capability_liveness_receipt.ex` — `previous_status` attribute
  (:214, nullable string, public), deliberately **not** in `:ingest`'s accept list
  (:174), written only via `change {Xaas.Operations.Changes.SetPreviousStatus, []}`
  (:186) which captures the prior row's status at same capability+subject before the
  identity upsert overwrites it. Migration
  `priv/repo/migrations/20261007231000_add_previous_status_to_capability_liveness_receipts.exs`
  persists it (real column; tests read it through real Postgres).
- `lib/xaas/operations/changes/set_previous_status.ex` — the only writer.
- `test/xaas/operations/capability_liveness_deepening_test.exs:201` — the W968c court
  "previous_status is written by :ingest on overwrite and not forgeable by callers"
  already present (file was `M` in the shared tree).

W978b's work therefore reduced to verification + mutation rationale + this receipt.

## Verification (real output, MIX_ENV=test, pinned asdf toolchain)

- W968c court (`test/.../capability_liveness_deepening_test.exs:201`), ×2:
  `Result: 1 passed, 10 excluded` / `Result: 1 passed, 10 excluded`
- Full deepening file (includes the W768 status-gate court):
  `Result: 11 passed`
- **Mutation**: removed `change {Xaas.Operations.Changes.SetPreviousStatus, []}` from
  the resource → court fails:
  `code: assert refreshed.previous_status == "ALIVE"` — `Result: 0/1 passed`.
  Restored (md5 `218d8fcca2205daa754643f03fd73e3d`). Court is non-vacuous.

## Shared-tree blockers encountered (disclosed, all restored byte-identical)

The canonical checkout carried in-flight edits from concurrent lanes (W975b / W970a)
that do not compile under ash 3.34.4: `parse_inline_idents?(false)` inside the new
`multitenancy` blocks of 4 billing resources (`approval_sla_credit_apply.ex`,
`approval_patch_sla_credit_apply.ex`, `subscription.ex`, `revenue_recognition.ex`) —
`parse_inline_idents?/1` has **zero definitions** in deps/ash or deps/spark; this is
not a valid DSL option in this Ash version. Any resource churn forces recompile of
`lib/xaas/graphql_schema.ex`, which then fails on the **committed** `keynote?` boolean
attribute in `lib/xaas/conference/speaker.ex:44` (`public?: true` → GraphQL field
name "keynote?" violates the GraphQL Name regex under absinthe 1.12.0).

To verify, W978b temporarily (a) reverted the 4 billing files to HEAD and (b) flipped
`keynote?` to `public?: false`, compiled clean (`Generated xaas app`, exit 0), ran the
full verification ladder above, then restored all 5 files byte-identical (md5-verified
against pre-lane checksums). The billing multitenancy wave is broken at source level
for any fresh compile; coordinator should route back to W975b/W970a, and `keynote?`
needs a GraphQL-visible name fix (rename or `graphql` rename/field override).

## Standing

- W968c / SPEC-14 previous_status: **ALIVE** on subject fc14f10b + in-flight tree,
  witnessed by real test runs + mutation kill; blocked from fresh-build reproduction
  only by unrelated lanes' compile churn (typed above).
- Coordinator actions: W975b/W970a must fix `parse_inline_idents?`; `keynote?`
  GraphQL surface needs repair; no W978b diff to integrate (no code change made).
