# W645 — Release-readiness audit run (checklist item 4, v26.10.7 fleet seal)

Date: 2026-10-07 · Lane W645 · Repo `/Users/sac/xaas` · Branch `feat/playwright-surface`
Subject: working tree at HEAD `56325fa5` (W632 VERSION 26.10.7 seal) + 108 dirty paths from concurrent lanes. No commits, no tags cut.

## Real execution (pinned toolchain, MIX_ENV=test, MIX_BUILD_ROOT=_build-laneW645)

1. `mix compile --force` fresh lane root: **EXIT=0** ("Generated xaas app").
   4 warnings, all pre-existing per W617's receipt: `ash_affidavit` unused
   `@envelope_domain_tag`; `xaas.airo.compile_shacl` unused
   `descriptions_with_predicate/2`; `approval_causal_anatomy.ex:144` unused
   `intent`; `refusal_ledger_export.ex:377` dead `not is_binary(court)` cond.
2. `mix xaas.release_audit`: **EXIT=1, exactly 19 typed findings** (matches W617's
   count; first finding is the W612 tag leg, as briefed).

## Finding table (all 19, classified)

| # | Finding (abridged) | Class |
|---|---|---|
| 1 | `release tag v26.10.6 does not match VERSION baseline 26.10.7 — pins diverged` | **EXPECTED per sequencing** — W612-added check; clears when coordinator cuts `v26.10.7` |
| 2 | configured Ash domains differ from canonical seven-domain order | pre-existing (in W617's set) |
| 3 | Ash resource counts drifted: Accounts 5, Billing 8, Governance 34, Ledger 4, Marketplace 3, Operations 21, Platform 7 | pre-existing |
| 4 | expected 70 domain resources, observed 82 | pre-existing |
| 5 | 40 `Xaas.Resource` modules missing from domains | pre-existing |
| 6 | 7 domain resources missing canonical source modules (`*.Version` / `RevokeNonce` pattern) | pre-existing |
| 7 | broken Markdown link: `docs/claude/diataxis/reference/w849-census-relocate-plan.md` → `reference/generated-surfaces.md` | pre-existing |
| 8 | broken Markdown link: `docs/claude/diataxis/reference/w919-census-relocate-plan.md` → `reference/generated-surfaces.md` | pre-existing |
| 9 | legacy six-domain router claim in `docs/archive/ASH-MIGRATION-PLAN.md` | pre-existing W872-era |
| 10 | legacy route denominator in `docs/claude/diataxis/explanation/errc-innovation-grid.md` | pre-existing W872-era |
| 11 | legacy 49-resource API claim in `errc-innovation-grid.md` | pre-existing W872-era |
| 12 | legacy 49-resource API claim in `security-and-testing-decisions.md` | pre-existing W872-era |
| 13 | legacy 49-resource API claim in `docs/sjira/v26.10.6/plans/w376-diataxis-tutorial-howto.md` | pre-existing |
| 14 | legacy 49-resource API claim in `docs/sjira/v26.10.6/plans/w467-release-audit-pin.md` | pre-existing W872-era |
| 15 | legacy 69-resource total in `w467-release-audit-pin.md` | pre-existing W872-era |
| 16 | legacy route denominator in `w467-release-audit-pin.md` | pre-existing W872-era |
| 17 | legacy six-domain router claim in `w467-release-audit-pin.md` | pre-existing W872-era |
| 18 | legacy 49-resource API claim in `lib/xaas/operations/capability_liveness_receipt.ex` (lib code, not docs) | pre-existing |
| 19 | architecture overview does not carry the canonical 70-resource total | pre-existing |

Classification summary: 1 expected-by-design (tag), 18 pre-existing
(present in W617's observed set), 0 W612-churn-caused, 0 new vs W617.

## Strict-compile state (fresh)

EXIT=0 under pinned toolchain; 4 warnings, all pre-existing and identical in
kind to W617's list. BUILD_ALIVE.

## Standing

- Compile: **ALIVE** (witnessed EXIT=0).
- Gate: **BLOCKED(release_audit)** — 19 typed findings.
- W612's hardening added the check producing finding #1 but added **zero**
  new non-tag findings vs W617's run.
- Audit-corpus drift is pre-existing, disclosed, not session-introduced.

## Lane hygiene

`_build-laneW645` deletion denied by harness permissions (same refusal W617
hit); 426 MB directory left for coordinator cleanup per campaign law.

## Preconditions for coordinator to cut `v26.10.7` (ordered)

1. **Owner lanes clear the 18 pre-existing findings**: re-pin audit constants
   (canonical domain order, `@resource_counts`, 70→82 total, `**70**` marker)
   to the current capability surface or register the missing resources; fix
   the 2 broken diataxis links; remediate the stale-claim corpus (docs +
   `capability_liveness_receipt.ex`).
2. **Write `docs/sjira/v26.10.7/_CLOSURE_PLAN.md`** — absent today;
   `docs/sjira/v26.10.7/plans/` holds 72 receipts (all resolve). Every
   explicit `docs/sjira/v26.10.7/plans/...` ref in the plan must resolve on
   disk (W612 `closure_receipt_findings/1` fires otherwise).
3. **Commit** the audit-pin corrections + closure plan.
4. **Tag `v26.10.7`** on that commit (newest tag must equal `v26.10.7`;
   v26.10.6 already tagged by W601q).
5. **Re-run `mix xaas.release_audit`** — passes only when newest tag ==
   VERSION and the tagged closure surface fully resolves.
6. Courts green: `test/mix/tasks/xaas_release_audit_test.exs` +
   `test/xaas/release_audit_enoent_court_test.exs` (W612 baseline 17/17).
