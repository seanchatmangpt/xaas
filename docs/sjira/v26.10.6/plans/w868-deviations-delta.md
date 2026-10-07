# W868 receipt — publish-deviations delta (post-consolidation-wave)

- **Lane**: W868, xaas v26.10.6 campaign, branch `feat/playwright-surface`,
  HEAD `a0723bf6`, canonical checkout `/Users/sac/xaas`. No commit, no build
  root.
- **Task**: refresh `plans/w664b-publish-deviations.md` against the
  consolidation wave; mark wave-resolved deviations, add new deviations
  honestly, preserve prior history as a dated delta section.
- **Date**: 2026-10-07

## Changes (one file written)

`docs/sjira/v26.10.6/plans/w664b-publish-deviations.md` — appended
"## 3. W868 delta (2026-10-07, post-consolidation-wave refresh)". §1/§2
untouched (prior resolved history intact).

Delta content, with receipts cited per line in the doc:

1. **D-resolved F1** (W752 dev-boot `insufficient_cluster_size` refusal) →
   RESOLVED by W803 (`plans/w803-dev-boot-fix.md`: `config/dev.exs`
   `cluster_size: 3`, real boot witnessed, `/tmp/w803-boot3.log`).
   Working-tree fix, uncommitted.
2. **D-resolved F2** (W752 dev-DB duplicate org-less `(run_id, cycle)` rows
   in `ultracode_epochs`) → code fix RESOLVED by W804
   (`plans/w804-epoch-dedup.md`:
   `priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs`,
   verified on xaas_test by real execution). PARTIAL_ALIVE: operator
   `MIX_ENV=dev mix ecto.migrate` on xaas_dev still pending. Uncommitted.
3. **D-new-1**: uncommitted consolidation tree — observed 2026-10-07:
   108 tracked-modified/staged entries, 308 untracked; tracked diff 77 files
   +2111/−288 (`git status --porcelain`, `git diff --stat`). Includes the
   W803/W804 fixes; published HEAD `a0723bf6` contains none of it.
4. **D-new-2**: the single real typed open gap 49.3 (Art. 49(3) deployer
   EU-database registration duty — binding, unevidenced, no registration
   seam), per W779 (`plans/w779-opengap-tag.md`) + W815
   (`plans/w815-gap-registration.md`); census-vs-gate delta 1348 − 1347 = 1.
   Standing deliberate OPEN deviation, not a wave regression.
5. **D-new-3**: operator-gated steps before publish — dev `mix ecto.migrate`
   (closes F2's operator half) and `ggen sync` regen/witness at the new HEAD
   (W663b gate 3 witnessed zero drift only at `a0723bf6`;
   `priv/semantic/generated/` still C1-held untracked — D3 unchanged).
6. **D2/D3 unchanged**: both remain OPEN operator items exactly as in §1.

## Standing

- **Doc-only lane — ALIVE**: every claim in the delta section is copied from
  or verified against the cited receipts (W663b, W752, W803, W804, W842,
  W779, W815) or real `git status`/`git diff` output observed this lane.
  No code, config, or test files touched; no execution claims made.
- **Corrections vs. the dispatch brief**: the brief said "~60-file tree";
  the observed tracked diff is 77 files (+108 tracked entries incl. staged,
  308 untracked). Recorded as observed.
- **Falsifier**: `git diff docs/sjira/v26.10.6/plans/w664b-publish-deviations.md`
  shows only the appended §3; prior sections byte-identical.
