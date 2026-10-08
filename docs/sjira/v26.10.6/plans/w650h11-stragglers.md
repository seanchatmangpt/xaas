# W650h11 — W650h5 NO-RECEIPT straggler verification + repair

- Subject: `/Users/sac/xaas` @ `feat/playwright-surface`, working tree (no commit — coordinator owns commits)
- Task: verify the 4 W650h5 NO-RECEIPT exclusions (receipt on disk? test green ×1?), stage what qualifies, repair reds against the real module surface.
- Env: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW650h11`
- Build root `_build-laneW650h11` left in place for the coordinator (cold-compile cost ~25 min); per campaign law it is a lane lease, coordinator deletes at integration.

## 4-row table

| test file | owner lane | receipt on disk | test on disk | verdict (batch, final) | action |
|---|---|---|---|---| NEXT sweep note |
| `test/xaas/self_digest/promotion_pipeline_depth_test.exs` | W650w | YES — `w650w-probe.md` documents exactly this file, 5-passed ×2 fresh roots | YES (was untracked) | GREEN 5/5 | STAGED (pathspec) for next receipts sweep |
| `test/xaas/semantics/vkg/query_depth_test.exs` | W984de | NO — no `w984de` receipt file anywhere in plans/ or any commit (lane killed mid-flight) | YES (was untracked) | RED 2/5 → REPAIRED → GREEN 5/5 | REPAIRED + STAGED |
| `test/xaas/operations/approval_castle_verb_schedule_authority_test.exs` | W984dp2 | YES — `w984dp2-ops-residue.md`; landed by W984dq4 (bcf1371d) | YES (tracked @HEAD, byte-identical to working copy) | GREEN 5/5 | NONE — already landed; drop from exclusion list |
| `test/xaas/marketplace/catalog_consumption_depth_w984dg_test.exs` | W984dg (NOT W984bo — receipt mismatch) | NO for this file: `w984bo-marketplace-depth.md` exists but documents the *tracked* `pack_catalog_depth_test.exs`; no W984dg receipt exists | YES (was untracked) | RED 1/5 → REPAIRED → GREEN 5/5 | REPAIRED + STAGED |

Verdict: 4/4 test files on disk, 4/4 green after repair, batch 20/20 passed.

## Repairs (test-only; zero lib/ changes)

### query_depth (W984de) — real-surface facts witnessed
1. `%{@base_attrs | key: ...}` KeyError on plain-map update (`@base_attrs` lacks the
   optional fields) → `Map.put/3` throughout.
2. `nil` `max_rows`/`timeout_ms` is NOT refused: `fetch/2 \|\| default` silently
   defaults to 5_000/10_000. Test now asserts the defaulting as a witnessed
   contract (`{:ok, defaulted}`, default values) instead of expecting refusal.
3. String VALUES are not atomized (only string KEYS via `fetch/2` fallback) —
   `"purpose" => "process_intelligence"` is refused at subject `:purpose`.
   Test now passes atom values for the parity case and asserts the string-value
   refusal explicitly.
4. Removed vacuous `authority: :NONE` digest mutant (admit only ever admits
   :NONE, so every authority mutant is refused before digest — mutant was a
   no-op vs base).

### catalog_consumption (W984dg)
1. Omitted `readiness` makes `Catalog.ingest/1` raise a raw `Ash.Error.Invalid`
   ("attribute readiness is required") — reproduced by this lane; matches the
   KNOWN DEFECT documented in the landed W984bo court. Default pack fixture now
   supplies `"readiness" => %{"gates" => true}` with the defect note.
2. `get_pack!` on an absent name raises `Ash.Error.Invalid` (NotFound wrapped in
   the Invalid class), not bare `Ash.Error.Query.NotFound` — assertion corrected,
   matching the landed W984bo sibling (`pack_catalog_depth_test.exs`).

## Commands / exits

```
# cold-compile batch (background, first run)
mix test <4 files>  → Result: 13/20 passed, Failed: 7
# per-file isolation + 3 repair rounds (all warm)
mix test <4 files>  → Result: 19/20 → 19/20 → 20 passed (exit 0)
```

Final receipt: batch `mix test` over the 4 files = **20 tests, 20 passed, exit 0**.

## Standing

- promotion_pipeline: ALIVE (receipt + green test, staged)
- query_depth: ALIVE after lane repair (receipt MISSING — W984de owner never
  produced one; flag for the next receipts sweep)
- approval_castle: ALIVE (already landed via W984dq4; remove from W650h5
  exclusion list)
- catalog_consumption: ALIVE after lane repair (receipt MISSING under the
  correct owner W984dg; the W984bo receipt covers a different file — flag both
  facts for the next receipts sweep)

## Next receipts sweep notes

1. Stage+commit the 3 staged test files (`git commit` with the existing index —
   they are already in the index via pathspec).
2. Mint missing owner receipts for W984de (query_depth) and W984dg
   (catalog_consumption), citing this receipt for the repair provenance.
3. W984bo receipt↔file mismatch: the W984bo receipt should be annotated to
   point at its actual file `pack_catalog_depth_test.exs`, not
   `catalog_consumption_depth_w984dg_test.exs`.

## See Also

`docs/sjira/v26.10.6/plans/w650w-probe.md` · `w984dp2-ops-residue.md` ·
`w984bo-marketplace-depth.md` · `../plans/w650h5` exclusions list
