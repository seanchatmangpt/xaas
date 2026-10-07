# w664b-publish-deviations — coordinator close-out receipt

**Wave**: W664b (v26.10.6 campaign publish-deviations consolidation)
**Date**: 2026-10-07
**Subject**: /Users/sac/xaas @ `feat/playwright-surface` (HEAD `a0723bf6`), canonical checkout.
**Scope**: consolidate W664's two flagged publish deviations + W660's open item into one coordinator close-out; sole write is this file.
**Inputs**: W664 lane report (coordinator transcript), W660 (`plans/w660-grounding-refresh.md`), W664b OS-20 (`plans/w664b-os20-consolidation2.md`).

## 1. Deviations and close-out actions

### D1 — ggen_igniter over-sweep (W664)

- **(a) What happened**: the W664 publish of ggen_igniter `b78a73e`
  ("v26.10.6: AIRo risk description (w618)", branch `feat/adr-0010-gate-convention`)
  captured 37 pre-staged files beyond the intended AIRo delta:
  30 × R100 renames `test/fixtures/ash_manufacture_pack/*` →
  `priv/ggen/ash-manufacture-pack/*`, plus 2 A + 5 D (37 total file changes).
- **(b) Risk**: unreviewed content in a published AIRo commit; if the renames
  were partial or incoherent, the ash-manufacture-pack profile
  (xaas CLAUDE.md GGen pack routing: the one normal Ash manufacture profile)
  could be broken or shadowed at the published SHA.
- **(c) Close-out action (executed this lane)**: verified for real against the
  published commit:
  ```
  $ git -C /Users/sac/ggen_igniter show b78a73e --name-status
  30 R100  test/fixtures/ash_manufacture_pack/* → priv/ggen/ash-manufacture-pack/*
  2 A      (new files)
  5 D      (deletions)
  ```
  Renames are R100 (100% similarity — content byte-identical), target path
  `priv/ggen/ash-manufacture-pack/` is present in the published commit
  (README.md, bin/beam4pm_oracle.sh, bin/citation_check.py, …). **VERDICT:
  COHERENT** — pure relocation, no content mutation; the canonical
  ash-manufacture-pack profile is intact at the published SHA. Deviation CLOSED.
- Note: file count 37 = 30 renames + 2 adds + 5 deletes, matching W664's
  "37 pre-staged rename files" figure.

### D2 — ggen-marketplace branch (W664)

- **(a) What happened**: W664 published ggen-marketplace `4bb5fbaff`
  ("v26.10.6: AIRo ontology vendored (w602)") on branch
  `feat/aaif-gcp-roadmap-v26.10.5`, not `main`.
- **(b) Risk**: consumers following `main` do not see the v26.10.6 AIRo
  vendoring; the marketplace selection authority could drift from the
  published feature branch until merge.
- **(c) Close-out action**: OPERATOR DECISION (not execusable by a lane) —
  operator merges `feat/aaif-gcp-roadmap-v26.10.5` → `main` when ready, or
  leaves the branch as the standing publish surface. No lane action. Deviation
  remains an OPEN operator item, no code risk.
- Observed state: local `feat/aaif-gcp-roadmap-v26.10.5` at `4bb5fbaff`.

### D3 — xaas `priv/semantic/generated/` C1-hold (W660 open item)

- **(a) What happened**: `priv/semantic/generated/` (shacl + MANIFEST.json
  projections) remains untracked and C1-held; the AIRo vendoring commit
  `a0723bf6` explicitly excluded it.
- **(b) Risk**: the pinned test `test/xaas/semantics/airo_vendored_pin_test.exs`
  pins only airo.ttl + README; without an admission decision the generated
  projections stay outside the tree, so any consumer expecting them at the
  pinned SHA finds nothing (admission_vacuous channel).
- **(c) Close-out action**: STANDING ADMISSION DECISION — coordinator/operator
  decides: admit `priv/semantic/generated/` (commit the generated projections
  under the ontology-first discipline: graph → ggen → projection) or make the
  C1-hold permanent with a typed refusal. Lane records the decision point; the
  decision itself is an operator item. Deviation remains OPEN pending decision.
- Observed state: `git status` shows `?? priv/semantic/generated/` (untracked).

## 2. Published SHA table (all 15 campaign repos)

Observed 2026-10-07 (local HEADs of canonical checkouts; where W664b-os20
remote-confirmed via `ls-remote`, marked ✓).

| repo | HEAD | subject | branch | push state |
|---|---|---|---|---|
| xaas | `a0723bf6` | chore(semantic): vendor AIRo ontology (W500 wave; generated/shacl+MANIFEST.json remain C1-held) | `feat/playwright-surface` | local, not pushed |
| ggen | `bc4d23909` | v26.10.6: version bump + AIRo risk description (w614) | `feat/v26.10.5-release-cut` | local |
| ggen_igniter | `b78a73e` | v26.10.6: AIRo risk description (w618) | `feat/adr-0010-gate-convention` | pushed (W664) |
| ggen-marketplace | `4bb5fbaff` | v(push deviation D2) | `feat/aaif-gcp-roadmap-v26.10.5` | pushed to branch, not main (D2) |
| ash_a2a | `b588c55c` | v26.10.6: OS-20 dual-safe Map.update + AIRo risk descriptions | `feat/tck-vuln-hardening` | ✓ remote-confirmed (W664b) |
| ash_pplan | `7eeaaa1` | v26.10.6: OS-20 dual-safe Map.update + AIRo risk descriptions | `fix/ggen-verify-header` | ✓ remote-confirmed (W664b) |
| ferroplan | `c037876` | chore(plugin): regenerate stale chatman-ecosystem agent projection | `main` | local |
| zcode-cli | `eb97f76` | v26.10.6: AIRo risk description (w615) | `fix/v26926-preview-publish-typed-skip` | local |
| gymact | `20b3fd7` | v26.10.6: AIRo risk description (w603) | `v26926/gymact-land-alloop-execution-kernel` | local |
| beam4pm | `813eb924` | docs: add verified Diataxis docs set | `main` | local; OS-20 commit W663a in flight |
| wasm4pm | `32deb59f6` | ci: install rdflib and pytest before TypeScript integration tests | `fix/v26.9.30-ci-fmt-tsc` | local |
| ex4pm | `46bfcc8` | v26.10.6: OS-20 dual-safe Map.update + AIRo risk descriptions + wave fixes | `main` | ✓ remote-confirmed (W664b) |
| autofde-lab | `2a3d064e` | feat(aaif): integrate AAIF vanilla runtime, FastMCP server, and A2A handler | `feat/doctrine-lab` | local |
| ash_r2rml | `b86a6a6` | v26.10.6: AIRo risk description + vocabulary pin | `fix/v26.9.29-from-source-head` | local |
| ash_surface | `d55c576d1` | v26.10.6: AIRo risk description + vocabulary pin | `main` | local |

### 2b. Corrections

- ex4pm subject is the full "v26.10.6: OS-20 dual-safe Map.update + AIRo risk
  descriptions + wave fixes" (table cell truncated in §2; full text in
  `plans/w664b-os20-consolidation2.md`).
- ash_surface subject: "v26.10.6: AIRo risk description + vocabulary pin" —
  no deviation involved; D2/D3 do not touch ash_surface.

## 3. W868 delta (2026-10-07, post-consolidation-wave refresh)

Prior §1/§2 history preserved verbatim; this section records only what the
consolidation wave (W663b, W752→W803/W804, W842) changed.

### D-resolved — W752 F1 dev-boot (RESOLVED by W803)

W752 (`plans/w752-e2e-validation.md`) recorded dev-env server boot BLOCKED by
F1 (`AshA2A.Authority.SecurityPreflight` refusing `Ekv` receipt store with
`cluster_size: 1` → `{:insufficient_cluster_size, 1}`). W803
(`plans/w803-dev-boot-fix.md`) set `config/dev.exs` `receipt_store_ekv_opts`
`cluster_size: 3` (dev inherits the production rule set via
`security_profile: :strict`; the `authority_broker` Ekv at 1 is not gated by
the preflight) and witnessed a real boot with no preflight refusal and no
`insufficient_cluster_size` in the log (`/tmp/w803-boot3.log`). F1 is CLOSED
in the working tree; the fix is uncommitted (see D-new-1).

### D-resolved — W752 F2 dev-DB epoch duplicates (RESOLVED in tree; operator step OPEN)

W752 F2: duplicate org-less `(run_id, cycle)` rows in `ultracode_epochs`
made W737's `20261007010000` migration raise on xaas_dev. W804
(`plans/w804-epoch-dedup.md`) wrote
`priv/repo/migrations/20261007120000_dedup_orgless_epochs_then_unique_index.exs`
(dedup keep-earliest `inserted_at`, then partial unique index
`WHERE org_id IS NULL`), verified by real execution on xaas_test (23505
mutation demonstrated, keep-rule asserted on real rows, version recorded).
PARTIAL_ALIVE: the operator still must run `MIX_ENV=dev mix ecto.migrate` on
xaas_dev (both modules `if_not_exists`-guarded; order-safe). F2 code fix is
in the working tree, uncommitted (see D-new-1); the dev migrate is an open
operator step.

### D-new-1 — uncommitted consolidation tree (~77 tracked modified + ~308 untracked)

The consolidation wave's product is entirely uncommitted: as of 2026-10-07
`git status --porcelain` shows 108 tracked-modified/staged entries and 308
untracked; `git diff --stat` on tracked modifications is 77 files, +2111/−288.
This includes the W803 `config/dev.exs` fix, the W804 migration, wave docs,
and billing/ledger sibling WIP. Until the coordinator commits, every
resolved deviation above is working-tree-only and the published HEAD
`a0723bf6` does not contain any of it.

### D-new-2 — single real open gap 49.3 (Art. 49(3), OPEN — by design, unevidenced)

The EU-AI-Act corpus census (W779 `plans/w779-opengap-tag.md`, corrected and
registered by W815 `plans/w815-gap-registration.md`) establishes exactly one
real typed open gap: Art. 49(3) deployer EU-database registration duty —
binding, unevidenced, no registration seam in this repo; the honest shape is
the flunk row itself (`Xaas.EUAIAct.TitleIVVTest` OPEN_GAP row; census-vs-gate
delta 1348 − 1347 = 1). This is a standing, deliberate OPEN deviation, not a
wave regression.

### D-new-3 — operator-gated dev migrate + ggen sync regen (OPEN operator items)

Two operator steps remain before publish:
1. `MIX_ENV=dev mix ecto.migrate` on xaas_dev (completes D-resolved F2;
   W804's documented command).
2. `ggen sync` regeneration after the commit lands, to re-witness zero
   `priv/semantic` output drift at the new HEAD (W663b gate 3 witnessed it
   only at `a0723bf6`; `priv/semantic/generated/` remains C1-held /
   untracked — same subject as D3 above, still OPEN).

### D2/D3 status (unchanged, still OPEN operator items)

D2 (ggen-marketplace on feature branch, not main) and D3
(`priv/semantic/generated/` C1-hold admission decision) are untouched by the
consolidation wave; they remain OPEN operator decisions exactly as recorded
in §1.
- **D-new-4 (W901, 2026-10-07)**: the "~/ash_surface validated against playwright" leg is witnessed ALIVE — 371/371 tests pass on `main@d55c576d` with a real headless Chromium (repo CI install path; 4 baseline env-skips resolved). Receipt: `plans/w901-ash-surface-playwright.md`.
