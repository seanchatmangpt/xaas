# W954 — ggen Sync Gate Spec (operator checklist)

- **Lane**: W954, xaas v26.10.6 campaign. **Date**: 2026-10-07.
- **Standing**: **PLAN-ONLY / UNKNOWN** — assembled from receipts w918, w919, w754, w937.
  No command below has been executed by this lane; execution standing belongs to the
  operator/coordinator integration step. No build root. No sync run. Not committed.
- **Subject (after gate passes)**: `/Users/sac/xaas` @ feat/playwright-surface, ggen.toml
  pin advanced `518572b6…` → `b58d78541…`, one `ggen sync` regen of
  `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`.
- **Source receipts** (all under `/Users/sac/xaas/docs/sjira/v26.10.6/plans/` unless noted):
  w918-sync-drift-precheck.md (PREDICTED), w919-census-relocate-receipt.md +
  `/Users/sac/xaas/docs/claude/diataxis/reference/w849-census-relocate-plan.md` (PLAN-ONLY),
  w754-castle-bridge-verify.md (ALIVE projection / PARTIAL_ALIVE currency), w937-fleet-commits.md
  (ALIVE commit-act: ggen-marketplace **b58d78541** on `feat/aaif-gcp-roadmap-v26.10.5`,
  carrying W756's rationale edit, 2 files +56/-1).

---

## (a) Blocking prerequisites (all must hold BEFORE the sync step)

| # | Prerequisite | Authority receipt | Status at assembly |
|---|---|---|---|
| P1 | W756's rationale edit **committed** in ggen-marketplace: commit `b58d78541` on branch `feat/aaif-gcp-roadmap-v26.10.5` in `/Users/sac/ggen-marketplace` (2 files: `packs/xaas-castle-bridge-pack/ontology.ttl` + AIRo pin court, +56/-1) | w937 (ALIVE, per-repo table row 1) | SATISFIED — verified committed 2026-10-07 |
| P2 | The W849 census relocation must execute **in the same integration step** as the sync: the census section currently at lines ~23-41 of the generated page must be moved to its new homes BEFORE/with the regen, so the section's deletion rides the regen diff, not a post-hoc hand-edit | w919 + w849-census-relocate-plan.md (PLAN-ONLY) | OPEN — operator executes per §(b) steps 1-2 |
| P3 | Pin advance in `/Users/sac/xaas/ggen.toml` `[packs.xaas_castle_bridge]`: `version = "518572b6b53103922ae8a27636a00e982a0907c4"` → `version = "b58d78541…"` (full SHA of the w937 commit). Without this, sync resolves the OLD rationale and the predicted delta is zero (w918 finding 2) | w918 (BLOCKED-until-pin-advance), w937 | OPEN — operator executes per §(b) step 3 |

**Carried warning from w918 (finding 3)**: advancing the pin from 518572b6 to b58d78541
pulls every marketplace commit in between (including 0ce47cc39, "make all 376 packs
qualify through real ggen 26.9.28"). ERRCDecision rows are identical pin→HEAD, but other
pack bytes (templates/pack.toml) must be byte-compared after the pin move, not assumed
identical — see §(d) V3.

**Line-number note (receipts disagree by one)**: w918 says census occupies page lines
22-41; w919/w849-plan say 23-41. The operator should locate the section by its H2 text
(`## SIBLING generated projections coverage (W849 census)`) through the trailing
"8 DRIFT-CHECKED / 4 PROVENANCE-ONLY / 0 UNPINNED" paragraph, not by raw line number.

## (b) Operator command sequence (with verification at each step)

All commands from `/Users/sac/xaas` unless noted. STOP at any verification that fails.

```bash
# Step 1 — census relocation, pre-regen hand-authored files (w849-plan §b.1, §b.5)
#   Create reference/generated-surfaces.md carrying the census section
#   (copy lines ~23-41 of the generated page; reword the "this page" table row to
#   `| generated-castle-bridge-errc.md | ggen-marketplace/xaas-castle-bridge-pack |
#     ggen sync; W754 faithful-projection verification | DRIFT-CHECKED |`),
#   create docs/cro/artifacts/generated-surface-census-v26.10.6.md (full table),
#   add the README.md Reference index entry.
grep -c "W849" docs/claude/diataxis/reference/generated-surfaces.md
#   EXPECT: >= 1

# Step 2 — verify prerequisite P1 against the live checkout (do not trust the receipt alone)
git -C /Users/sac/ggen-marketplace rev-parse --verify b58d78541^{commit}
git -C /Users/sac/ggen-marketplace branch --contains b58d78541   # EXPECT: feat/aaif-gcp-roadmap-v26.10.5
grep -c "117 Ash resources" /Users/sac/ggen-marketplace/packs/xaas-castle-bridge-pack/ontology.ttl
#   EXPECT: 1   (W756 rationale present in the commit being pinned)

# Step 3 — pin advance (P3). Edit ggen.toml [packs.xaas_castle_bridge]:
#   version = "518572b6b53103922ae8a27636a00e982a0907c4"  ->  version = "<full b58d78541 SHA>"
grep -A3 'packs.xaas_castle_bridge' ggen.toml
#   EXPECT: version = "b58d78541…"

# Step 4 — the sync (THE step; single execution)
ggen sync

# Step 5 — the predicted diff gate (w918 §c falsifier)
git diff docs/claude/diataxis/reference/generated-castle-bridge-errc.md
#   EXPECTED, exactly:
#     hunk 1 — page line 10 ("Why" cell of ELIMINATE-10 row):
#       OLD: `XaaS already owns 69 Ash resources and seven domains; compose through the native RouteCastle capability instead`
#       NEW: `XaaS already owns 117 Ash resources via the Xaas.Resource wrapper (152 total use Ash.Resource) and 19 domains; compose through the native RouteCastle capability instead`
#     hunk 2 — census-section removal (H2 through the "8 DRIFT-CHECKED / 4
#       PROVENANCE-ONLY / 0 UNPINNED" paragraph, lines 22-41 per w918).
#   All other 12 table rows, header, blockquote, closing paragraph byte-identical.

# Step 6 — regression gate
mix test test/xaas/generated/registry_drift_guard_test.exs
#   EXPECT: green (page is not pinned in that test per w918 finding 4; this confirms
#   no other generated surface drifted via the pin move)
```

## (c) Falsifier — anything else in the diff

**Claim under test (w918 §c)**: post-pin-advance sync produces EXACTLY the line-10
rationale change plus the census-section deletion (lines 22-41).

**Falsifier**: any third hunk, any other changed table row, any change to the header
blockquote / closing paragraph, or any change to the other 6 pack-template outputs
(castle-bridge-shacl.ttl, castle-contract-inject.ex, castle-contract-test.exs,
castle-contract.ex, castle-edge-catalog.ex, castle-innovation.json) falsifies the
prediction.

**On falsification — investigate, do not accept**: stop the sequence, do not commit,
classify the unexpected delta (pin-advance side effect per w918 finding 3 — e.g. a
0ce47cc39 pack-byte change — vs. a template/ontology regression vs. an unmodeled
consumer), and route back to a new lane with the diff attached. Re-running sync without
a new hypothesis is prohibited (unchanged-failure rule).

Also investigate (expected-nonzero-exit checks): if Step 5 shows NO line-10 change, the
pin did not actually advance to b58d78541 or the rationale edit is not in that commit —
re-run Step 2 checks.

## (d) Post-sync verification

| # | Check | Command | Expected |
|---|---|---|---|
| V1 | Drift check / regen stability | `ggen sync run && git diff --exit-code` | exit 0 — second sync is a no-op; also confirms the census section is NOT re-introduced (w849-plan falsifier) |
| V2 | Census fully relocated | `grep -c "W849 census" docs/claude/diataxis/reference/generated-castle-bridge-errc.md` | `0`; and `grep -c "W849" docs/claude/diataxis/reference/generated-surfaces.md` returns `>= 1` (w849-plan falsifiers) |
| V3 | Pin-advance side-effect byte-compare (w918 finding 3) | `git -C /Users/sac/ggen-marketplace diff 518572b6..b58d78541 -- packs/xaas-castle-bridge-pack` | only ontology.ttl rationale + the w937 second file; any template/pack.toml delta must be explained against the predicted diff before commit |
| V4 | Drift guard regression | `mix test test/xaas/generated/registry_drift_guard_test.exs` | green |
| V5 | W754 faithful-projection verification re-run | re-execute w754's checks against the regenerated page: 13 rows vs ontology.ttl ERRCDecision facts (ORDER BY category, priority), header/closing prose byte-equal to template, ELIMINATE-10 rationale now the "117/152/19" literal, RouteCastleRun read-only + private-execute claims unchanged in lib/ | page ALIVE as projection — byte-faithful to generator inputs at the new pin |

## Standing (header, per lane order)

**W954: PLAN-ONLY / UNKNOWN.** This file is the deliverable — an operator checklist
assembled from receipts w918 (PREDICTED/BLOCKED), w919+w849-plan (PLAN-ONLY), w754
(ALIVE projection), w937 (ALIVE commit-act). No prerequisite execution, sync, or
verification in §(b)/(d) has been run by this lane; all EXPECT values are predictions
carried from those receipts. No build root created. Not committed.
