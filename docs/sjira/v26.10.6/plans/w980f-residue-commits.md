# w980f — residue integration commits (W955 "+1" fold)

- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, base `fab56ae1` (W980e confirmed zero commits since)
- **Executed**: 2026-10-07 07:57–08:08 PDT
- **Authority**: W980f lane dispatch (residue integration commit per W946d residue table + W949 adjudication + W940b SPEC-16/17 precedent)
- **No push performed.** Branch remains local.

## Per-group commits (12)

| # | SHA | family | files |
|---|-----|--------|-------|
| c1 | `c3df69a8` | fix(governance): SPEC-16/17-adjacent hardening (w935/w944b/w969) | 8 |
| c2 | `abbfcb1c` | fix(operations): W897/W902 batch-3 cheap repairs — incident guards, lifecycle validations, typed VERSION boot | 7 |
| c3 | `dbdd6df8` | fix(conference): W925/W947 slot/registration | 2 |
| c4 | `ba9703fb` | fix(semantics): W907 bare-fun + W853/W880/W851 doctests (w927) | 6 |
| c5 | `aa2b4022` | fix(graphlaw): W845/W872/W873 + SPEC-09 capability_class | 5 |
| c6 | `fd471722` | fix(operations): SPEC-14 previous_status + witness tie courts (w968c/w920/w918b) | 8 |
| c7 | `352cc34c` | fix(ledger): SPEC-27 reversal + double-reversal backstop (w968c) | 4 |
| c8 | `5a853130` | fix(web): SPEC-04 per-org authentication + fabric/refusal-negative folds (w951b/w969b/w975) | 10 |
| c9 | `b2758300` | fix(platform): W969c SPEC-21 route create + W970b hold/retention/castle link | 8 |
| c10 | `ed407ef8` | docs(diataxis): W966 cap-doc-sync + generated surfaces | 7 |
| c11 | `7a0b58fc` | docs(cro): cycle log/manifest + coverage artifacts | 7 |
| c12 | `88c2c515` | docs(sjira): W946d runbook final + register flips + census plans | 6 |

Total: 78 files. `git log --oneline fab56ae1..HEAD` = these 12 SHAs **plus one concurrent lane commit** `84a5ef51` (chore(sync) w980c/w980g) landed by a live lane during this run — not a W980f product.

## Excluded (operator rows / receipts, per dispatch)

- **Platform deletion pairs** (operator): `lib/xaas/platform/changes/route_orgs_custom_domain_approve.ex`, `route_projects_backups_approve.ex`, `validations/route_orgs_custom_domain_requires_approver.ex`, `route_projects_backups_requires_approver.ex` (all `D`, untouched)
- **Dev-migrate migrations** (operator, held): `priv/repo/migrations/20261007111457_add_ash_onetime_logical_partitions.exs`, `20261007120000_dedup_orgless_epochs_then_unique_index.exs` (untracked)
- **Generated projection**: `priv/semantic/generated/` (untouched)
- **Receipt/plan docs**: all `?? docs/sjira/v26.10.6/plans/w*.md` (~90 files, still growing during execution — w980g-sync-exec appeared mid-run) + `docs/claude/diataxis/reference/w849|w919-census-relocate-plan.md` — blanket-roll into next CG-14. NOTE: the two census-relocate plan docs WERE committed in c12 as dispatch named them; the still-arriving `??` plan docs were not.
- **Build junk**: `_buildNew-lineW968c/` untracked build dir (appeared mid-run; not deleted — lane lease, coordinator cleanup law applies at integration)

## HOLD list (in-flight lane edits, mtime 08:04–08:07 during run)

Lanes were demonstrably live during execution (5-min porcelain drift check at 07:57/08:02 showed receipts + `ggen.toml`; further edits landed 08:04–08:07 on top of already-committed files). Held, not committed:

- `ggen.toml` (M)
- `lib/xaas/checks/system_actor.ex` (M, 08:04)
- `lib/xaas/semantics/dataset_admission.ex` (M, 08:05)
- `mix.exs` (M — re-modified after c2 committed it, 08:05)
- `test/xaas_web/graphql_http_surface_test.exs` (??, 08:06)
- `test/xaas/actuation_refusal_negative_test.exs` (M — re-modified after c8)
- `test/xaas/conference/enrollment_journey_court_test.exs` (M — re-modified after c3)
- `test/xaas/governance/freeze_window_active_gate_test.exs` (M — re-modified after c1)
- `test/xaas/ledger/reversal_deepening_test.exs` (M — re-modified after c7)

## Verification

- Pre-commit: 5-min two-snapshot porcelain drift check (07:57:34 → 08:02:34): code files quiescent >5 min at commit time; drift was receipts-only (`ggen.toml` + new plan docs + `_buildNew-lineW968c/`).
- Post-commit: porcelain reduced 159 → 105 rows; non-excluded, non-HOLD residue = zero (verified `grep -vE 'plans/|operator rows'` → only HOLD + operator + receipts remain).
- Lane attribution read from real diffs (moduledocs name SPEC/W lanes: SPEC-04 W969b, SPEC-09 W912, SPEC-14 W968c, SPEC-21 W969c, SPEC-27 W968c, W897, W970b).
- `mix test` NOT run: lanes still actively editing test files (HOLD list) — a run now would measure a moving tree, not the committed subject. Falsifier for each group remains its named court test at a quiescent HEAD.

## Standing

- Commits: observed execution on exact HEAD chain `fab56ae1..88c2c515` (12 commits, 78 files).
- Working tree: ALIVE and still receiving lane output — this fold is a snapshot integration, not campaign close.
- Follow-ups: (a) CG-14 blanket roll of `?? docs/sjira/plans/` receipts; (b) a later quiescent-window residue commit for the HOLD list (incl. `ggen.toml`, `mix.exs` re-edit, `graphql_http_surface_test.exs`); (c) coordinator cleanup of `_buildNew-lineW968c/`; (d) operator rows (platform deletion pairs, dev-migrate migrations, `priv/semantic/generated/`) remain outside lane authority.
