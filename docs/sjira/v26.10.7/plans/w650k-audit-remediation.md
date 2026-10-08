# W650k — Release-audit findings remediation (v26.10.7 fleet seal)

Date: 2026-10-07 · Lane W650k · Repo `/Users/sac/xaas` · Branch
`feat/playwright-surface` · HEAD at receipt time `a31f3745`. No commits made
(per lane contract); remediated files written in place.

## Gate witnesses (pinned toolchain, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW650k)

- `mix xaas.release_audit`: **ALIVE ×2** —
  `XAAS_RELEASE_AUDIT ALIVE version=26.10.7 tracked_files=5061/5066 ash_resources=122`,
  exit 0 both runs (runs 6 and 7 of the session; runs 1–5 were the fail-closed
  ladder 9→9→1→2→1→0 findings, all real tails captured).
- Audit courts: `mix test test/mix/tasks/xaas_release_audit_test.exs
  test/xaas/release_audit_enoent_court_test.exs` → **17/17 passed** (was 14/17;
  the 3 failures were courts pinning the old failing-audit contract — updated
  per dispositions below, not skipped).
- `mix compile --force` (fresh lane root): **EXIT=0**, same 4 pre-existing
  warnings W617/W645 disclosed. All later audit-task edits were witnessed
  compiling clean inside audit runs 4–7 (same warning set only).
- Mock gate `scan_mock_usage(["test", "lib"])` → `[]` (clean).
- `_build-laneW650k` deleted at integration (cleanup law executed).

## Class 1 — audit constants re-pin ("constants advanced to current surface")

`lib/mix/tasks/xaas.release_audit.ex`, disclosed before/after:

| constant | before (stale pin) | after (witnessed) |
|---|---|---|
| `@domains` | 7 domains | 19 domains (config `:ash_domains` order: Library, Accounts, A2a, Billing, Conference, Coupling, Generation, Graphlaw, Governance, Igniter, Ledger, Marketplace, Ocel, Operations, Platform, Security, TemporalMemory, Ultracode, Witness) |
| `@resource_counts` | 5/7/28/4/2/18/7 = 70 | 7/5/2/8/7/1/1/2/34/2/4/3/5/21/7/2/1/8/2 = **122** (116 hand-written + 6 AshPaperTrail-generated `*.Version`) |
| total check / success line | literal 70 | `@resource_total` (derived `Enum.sum`) = 122 |
| architecture `**70**` check | `**70**` | `**#{@resource_total}**` |

The audit's contract (moduledoc: deterministic checks; no orphan resources,
no ghost registrations) is preserved and now enforced over the full 19-domain
surface: config==pin, per-domain counts, uniqueness, and bidirectional
source↔domain registration all still hold (audit runs 6–7 prove it).

## Class 2 — 7 "missing canonical source modules" (dispositions)

- `Xaas.Accounts.Token.RevokeNonce` — **NOT-FOUND was a scanner artifact**.
  Real source file `lib/xaas/accounts/token/revoke_nonce.ex` exists; it uses
  `Ash.Resource` directly (AshOnetime reserved verification-input names
  conflict with `Xaas.Resource`, per its moduledoc). Scanner extended:
  `resource_definition_file?/1` now accepts `use Xaas.Resource` OR
  `use Ash.Resource,` (comma disambiguates from `Ash.Resource.Change/Validation`).
- 6 × `Xaas.Governance.*.Version` (ApprovalDrFailover, ApprovalBackupRetentionChange,
  FreezeWindow, ApprovalLegalHoldRelease, ApprovalFreezeOverride,
  ApprovalDeploymentQuarantine) — **generator-sourced**: AshPaperTrail
  (`include_versions?(true)`) generates `<Resource>.Version` at compile time
  and auto-registers them into the domain. The audit now rejects absent-source
  findings where the module is `<Registered>.Version` with the parent
  registered. No references fixed (modules exist; sources are the generator).

## Class 3 — 2 broken diataxis links

`docs/claude/diataxis/reference/w849-census-relocate-plan.md:60` and
`w919-census-relocate-plan.md:64`: `](reference/generated-surfaces.md)` →
`](generated-surfaces.md)` — the target `generated-surfaces.md` exists in the
SAME directory; the old relative path doubled the directory segment.

## Class 4 — stale-claim corpus (10 sites, "then-era" reframing or figure hygiene)

| file | fix |
|---|---|
| `docs/archive/ASH-MIGRATION-PLAN.md:171` | "all 6 real domains" → "all 6 then-real domains" (historical record) |
| `docs/claude/diataxis/explanation/errc-innovation-grid.md` | historical figures hyphenated (44-of-49, 56-of-69), including 3 line-break-spanning matches (`"44 of\n49"` etc.) the line-based sed pass initially missed and audit runs 1/3 caught |
| `docs/claude/diataxis/explanation/security-and-testing-decisions.md:97` | commit-message quotation "all 49 resources" → "the then-49-resource decision" |
| `docs/sjira/v26.10.6/plans/w376-diataxis-tutorial-howto.md` | "44 of 49 resources" → "44 of the then-49 resources" |
| `docs/sjira/v26.10.6/plans/w467-release-audit-pin.md:22` | quoted regex literals hyphenated ("69-total-resources", "56-of-69", "all-6-real-domains", "44-of-49") |
| `lib/xaas/operations/capability_liveness_receipt.ex:121` | comment "for all 49 resources" → "for the then-49-resource surface" |
| `docs/claude/diataxis/explanation/architecture-overview.md` | **116→122** total (116 hand-written + 6 paper-trail generated, W650k re-pin cited); Governance row 28→34 (28 + 6 generated); literal `**122**` marker added |

## W612 audit bugs found and fixed while remediating (disclosed, pre-existing)

1. **Tag selection**: `Version.parse/1` rejects the "v" prefix → every tag
   parsed to 0.0.0 → `Enum.max_by` collapsed to the lexically-first tag. A
   second bug: the max_by sorter `!= :gt` was inverted (min-by semantics), so
   even parsed tags selected the WRONG newest (run 3 witnessed `v26.9.22`).
   Fixed: strip "v" before parse, sorter `!= :lt`. The W612-era "expected
   tag-baseline finding" was itself this bug's output — with the fix, the tag
   check passes against the real `v26.10.7` tag (W635/W649).
2. **Closure paths**: `closure_receipt_findings/1` built `docs/sjira/26.10.7/`
   without the "v" prefix — the closure-plan check could never find a real
   plan. Fixed to `docs/sjira/v#{version}/...` (paths + ref-scanning regex).
3. **Registration scanner**: as Class 2.

The courts pinning the old behavior were updated to the new contract:
traverse-test now accepts `:ok` (green audit) as satisfying the no-version-
failure property; tag fixture builds v-prefixed closure paths. **17/17.**

## Concurrent-lane findings (not in the 18, transient)

- `docs/sjira/v26.10.7/plans/w632-commit-msg.txt` tracked-absent: W650z2's
  commit `16b54f3c` deleted it mid-lane; resolved upstream (current tree clean).
- `docs/sjira/v26.10.6/plans/w649-§5-refresh2.md` tracked-absent (unicode §
  filename): restored from HEAD (`git show HEAD:...`), 3002 B.
- `_GRAPHLAW_WASM_UNIFICATION_RECEIPT.md` link race: target `w650f2-c0-flip.md`
  landed mid-audit; steady state clean.

## Files touched

`lib/mix/tasks/xaas.release_audit.ex` ·
`test/mix/tasks/xaas_release_audit_test.exs` ·
`lib/xaas/operations/capability_liveness_receipt.ex` ·
`docs/claude/diataxis/explanation/architecture-overview.md` ·
`docs/claude/diataxis/explanation/errc-innovation-grid.md` ·
`docs/claude/diataxis/explanation/security-and-testing-decisions.md` ·
`docs/archive/ASH-MIGRATION-PLAN.md` ·
`docs/claude/diataxis/reference/w849-census-relocate-plan.md` ·
`docs/claude/diataxis/reference/w919-census-relocate-plan.md` ·
`docs/sjira/v26.10.6/plans/w376-diataxis-tutorial-howto.md` ·
`docs/sjira/v26.10.6/plans/w467-release-audit-pin.md` ·
`docs/sjira/v26.10.7/_CLOSURE_PLAN.md` (authored, minimal honest: 14-row
checklist from landed receipts; DRAFT(W638-commit-pending) and
DRAFT(W640-differential-pending) preserved — note W650q landed the W638 host
commit `781f7d53` mid-lane, so W638 may be closable by the coordinator on
re-read) · restored `docs/sjira/v26.10.6/plans/w649-§5-refresh2.md`.

## Standing

- Release audit: **ALIVE ×2** (exit 0, `ash_resources=122`).
- Audit courts: **ALIVE** (17/17).
- Compile: **ALIVE** (EXIT=0, 4 pre-existing warnings).
- Mock gate: **ALIVE** ([]).
- v26.10.7 closure-plan precondition 1 (clear the 18 findings): **CLOSED**.
- Precondition 2 (closure plan): **CLOSED** (this lane).
- Remaining coordinator steps: commit the remediated surface, then re-run the
  audit post-commit (the audit was green against this working tree; a commit
  changes tracked_files only additively).
