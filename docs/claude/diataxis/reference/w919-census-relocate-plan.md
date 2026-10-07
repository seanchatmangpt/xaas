# W849 Census Relocation Plan (W919)

> Status: PLAN ONLY — not executed. Lane W919, v26.10.6 campaign.
> Canonical home of this plan: `docs/claude/diataxis/reference/w919-census-relocate-plan.md`
> (dispatch-named path; originally written as `w849-census-relocate-plan.md` — W956/W957
> resolution: both paths exist, this one is the file W954's operator spec references).
> Resolves W918's second finding: the "SIBLING generated projections coverage (W849
> census)" section (lines 23-41 of `reference/generated-castle-bridge-errc.md` at the
> W956 grep) lives inside a ggen-generated page, so a plain `ggen sync` regen silently
> deletes it.

## (a) Target selection

**Recommendation: new hand-authored page `docs/claude/diataxis/reference/generated-surfaces.md`.**

Why not `reference/standing-vocabulary.md`: thematically wrong (that page owns the closed
standing-status set and refusal atoms, enforced by `CapabilityLivenessReceiptStatusGate`).
A generated-surface census is a provenance/drift topic, not a standing-vocabulary topic;
hosting it there would blur two owned contracts.

Why not `README.md` (the diataxis index): the index's own canonical-source rule (last
section of `README.md`) says the index is authoritative for *navigation* and that
"individual pages link to, rather than duplicate, contracts owned by other quadrants."
Hosting a substantive census table there would violate the index's own authority rule.

Why a new page works:

- The census is a cross-cutting contract ("which surfaces are generated, how each is
  drift-checked") covering 12+ surfaces — bigger than the ERRC page's scope. It is a
  Reference-quadrant fact: an exact factual listing, not a tutorial/how-to/explanation.
- It gives `lib/xaas/generated/`, `assets/js/ash_*.ts`, `lib/xaas_web/mcp_scope.ex`,
  `lib/mix/tasks/xaas.library.manufacture.ex`, and the ERRC page a single named,
  linkable home for provenance/drift status.
- It is hand-authored and never regenerated, so the regen-deletion hazard is gone.

## (b) Exact move steps (one integration step, same as ggen sync)

1. **Copy** the section: `generated-castle-bridge-errc.md` lines 23-41 (from the
   `## SIBLING generated projections coverage (W849 census)` H2 through the trailing
   "8 DRIFT-CHECKED / 4 PROVENANCE-ONLY / 0 UNPINNED" paragraph) into the new
   `reference/generated-surfaces.md`, promoted to be the page's main body under an H1
   `# Generated Surfaces — Provenance and Drift Census`, with a one-line preamble:
   "Hand-authored. Census of generated surfaces (W849 census); see the live receipt at
   `docs/sjira/v26.10.6/plans/w849-generated-surface-census.md`."
2. **Adjust the link** inside the copied census table: the row for the ERRC page itself
   (row "this page") must be reworded from "this page" to point at the actual relative
   path `generated-castle-bridge-errc.md`, since "this page" is now ambiguous in the new
   home. Update the row to:
   `| generated-castle-bridge-errc.md | ggen-marketplace/xaas-castle-bridge-pack | ggen sync; W754 faithful-projection verification | DRIFT-CHECKED |`.
3. **Delete** lines 23-41 (the H2 through the trailing paragraph, plus the preceding
   blank-line gap) from `generated-castle-bridge-errc.md` **as part of the same
   integration step as the `ggen sync` regen** — so the deletion of the section from the
   generated page is recorded as the regen's intended output, not a hand-edit of a
   generated file. Concretely: run `ggen sync`, verify the section is gone from the
   regen output, and let that regen be the diff hunk that removes it. If the pack
   template still emits the section (it does — the template source carries it), then the
   deletion is a one-time hand deletion immediately before the sync, and the sync
   confirms stability (`git diff` after sync must show no re-introduction).
4. **Cross-link**: in `generated-castle-bridge-errc.md`, if the pack template permits a
   trailing hand-edit-safe pointer, skip it (do not hand-edit the generated page). The
   link direction is one-way: the new hand-authored page links TO the generated page;
   the generated page gets no reverse link (never hand-edit generated output).
5. **Index the new page** in `docs/claude/diataxis/README.md` under Reference:
   - [`reference/generated-surfaces.md`](reference/generated-surfaces.md) — hand-authored census of generated surfaces: provenance, drift checks, DRIFT-CHECKED / PROVENANCE-ONLY / UNPINNED classes (W849; relocated from the generated ERRC page, W919).

## (c) Follow-up guard: census artifact home

Do NOT add the census back to anything generated. Per the campaign's convention
(snapshots and ledgers under `docs/cro/artifacts/` — cf. `airo-wiring-ledger.md`,
`implementation-wave-ledger.md`, `evidence-claims-index.md`), the durable census artifact
should live at:

**`docs/cro/artifacts/generated-surface-census-v26.10.6.md`**

Reasons:

- `docs/cro/artifacts/` is already the campaign's ledger home for exactly this class of
  machine-checkable factual snapshot (counts, classes, per-surface status) — same
  register as `evidence-claims-index.md`.
- Diataxis reference pages should stay lean and navigation-facing; a 12-row census table
  with per-surface drift commands is an artifact, not reader-facing contract prose. The
  diataxis page should carry a short summary + link to the artifact; the artifact is the
  full table.
- Keeping it there makes the artifact subject to the campaign's artifact-integrity and
  evidence-index conventions (`artifact-integrity.md`, `evidence-claims-index.md`),
  rather than orphaned in a generated page.

Split of labor: `reference/generated-surfaces.md` = hand-authored, reader-facing summary
of the census classes and how drift is checked; `docs/cro/artifacts/generated-surface-census-v26.10.6.md`
= full per-surface table, per campaign convention. The W849 plan receipt (`docs/sjira/v26.10.6/plans/w849-generated-surface-census.md`)
stays where it is as the point-in-time receipt.

## (d) Execution ordering vs the integration sequence

The integration runbook's ggen step (`_INTEGRATION_RUNBOOK.md`: `ggen sync run && git
diff --exit-code` drift check, plus the W756 regen at new HEAD) must observe this order:

1. **Before `ggen sync`** (pre-regen, hand-authored edits): create
   `reference/generated-surfaces.md`, create
   `docs/cro/artifacts/generated-surface-census-v26.10.6.md`, update the README index.
   All three are hand-authored files the regen will not touch.
2. **The `ggen sync` step itself** deletes the census section from the generated page.
   Verify with `git diff docs/claude/diataxis/reference/generated-castle-bridge-errc.md`
   that the only hunk is the census-section removal (plus any legitimate regen drift).
   If the pack template still emits the section, delete it by hand in the same commit,
   and the sync's `git diff --exit-code` check must show the page stable thereafter.
3. **After sync**: `mix test test/xaas/generated/registry_drift_guard_test.exs` (the
   census references it as the drift guard; confirm it stays green) and the W754
   faithful-projection check if runbook-scheduled.
4. **No test changes**: the relocation touches only docs; the census's referenced guards
   (`registry_drift_guard_test.exs`, W837 regen-and-byte-compare court) are untouched.

## Falsifier (for the coordinator's execution)

- After execution, `grep -c "W849 census" docs/claude/diataxis/reference/generated-castle-bridge-errc.md` must return `0`.
- `ggen sync run && git diff --exit-code` must pass (no regen re-introduces the section).
- `grep -c "W849" docs/claude/diataxis/reference/generated-surfaces.md` must return `>= 1`.
- README index contains the new page entry.
