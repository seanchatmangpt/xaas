# W864 — Semantics module census (W671 page refresh)

Date: 2026-10-07. Repo: /Users/sac/xaas, branch `feat/playwright-surface`,
HEAD `a0723bf6`. Lane W864, v26.10.6 campaign. Doc-only diff; no commit
(per lane instruction; coordinator owns commits).

## Subject

- Page: `docs/claude/diataxis/reference/eu-ai-act-semantics.md`
- Directory: `lib/xaas/semantics/` (real `ls` at 2026-10-07)

## Diff performed

Page section list vs real directory listing:

- 17 top-level `.ex` files + `vkg/` subdir (4 modules). `computation.ex`
  defines 5 modules (ComputationArtifact, ComputationHash, ComputationClaim,
  PlanningAdvice, RuntimeEquivalence) → **25 modules across 18 files**.
- Every top-level module already had a per-module section. The only gap:
  the four `vkg/` submodules (`Xaas.Semantics.VKG.{Query,Witness,Replay,
  Workspace}`) had no sections — the page's VKG bullet covered only
  `vkg.ex`.

## Additions to the page

1. Top note (eu-ai-act-semantics.md:7-9): per-module sections are the
   authority; census is a stamped snapshot.
2. New subsections under "Registry / R2RML / VKG" (page lines 345-417):
   - `Xaas.Semantics.VKG.Query` — signatures `new/1`, `admit/1`, `digest/1`,
     `with_contracts/2`; purposes closed set; refusal atom
     `REFUSED_XAAS_VKG_QUERY`. Evidence: `lib/xaas/semantics/vkg/query.ex:50-114`.
   - `Xaas.Semantics.VKG.Witness` — `from_session/2`, `verify/1`,
     `summary/1`; standing `:observed_not_actuated`, authority `:NONE`;
     refusal `REFUSED_XAAS_VKG_WITNESS`. Evidence:
     `lib/xaas/semantics/vkg/witness.ex:44-101`.
   - `Xaas.Semantics.VKG.Replay` — `witness/1`, `workspace/1`,
     `serialized_witness/1`; refusal `REFUSED_XAAS_VKG_REPLAY`. Evidence:
     `lib/xaas/semantics/vkg/replay.ex:14-96`.
   - `Xaas.Semantics.VKG.Workspace` — `build/2`, `subjects/1`, `fetch/2`,
     `provenance/2`, `witness_index/1`, `verify/1`; refusal
     `REFUSED_XAAS_VKG_WORKSPACE`. Evidence:
     `lib/xaas/semantics/vkg/workspace.ex:17-86`.
3. Four `REFUSED_XAAS_VKG_*` atoms added to the cross-module refusal-atom
   index (page lines 439-442). Evidence:
   `vkg/query.ex:151`, `vkg/witness.ex:152`, `vkg/replay.ex:95`,
   `vkg/workspace.ex:158` (each module's `refusal/3` helper).
4. "Module census (W864, 2026-10-07)" block (page lines 444-476): 25
   modules / 18 files, one-line purpose per file, generated from the real
   `ls` output above.

## Verification

- `ls -la /Users/sac/xaas/lib/xaas/semantics/` → 17 `.ex` + `vkg/` (real output in transcript).
- `ls /Users/sac/xaas/lib/xaas/semantics/vkg/` → query.ex replay.ex witness.ex workspace.ex.
- Post-edit grep on the page confirmed: top note (line 7), four new
  subsections (lines 345/370/383/397), atom-index rows (lines 439-442),
  census heading (line 444). Page now 487 lines.
- Read of all four `vkg/` sources for signatures + refusal atoms; all
  facts in the new sections taken from those reads.

## Standing

- Page edit: OBSERVED (written to disk, verified by grep on disk).
- Module coverage: ALIVE — census matches the real directory at
  2026-10-07 / `a0723bf6`; next wave drift re-triggers the census law.
- No tests run (doc-only change; no build root used).
