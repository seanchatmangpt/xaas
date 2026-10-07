# W80 — ash-extension pack re-pin diff (old baa5f117 vs new 3ddbfeb7)

Lane: W80 integration, v26.10.6 convergence. Read-only falsifier lane: no ash_surface
or ggen-marketplace tree was modified; scratch confined to /tmp + this receipt.

## Subject

- Consumer: `/Users/sac/ash_surface/ggen.toml` pins
  `ash-extension = { git = "https://github.com/seanchatmangpt/ggen-marketplace.git", version = "baa5f117deefb3b84f7bd653e65e9fe8d9b1d2fa", subdir = "packs/ash-extension-pack" }`.
  `ggen.lock` content_hash `blake3:4e03a62ffd19de341dae4596bd3c727212f61bb4998017842a4a01febea148bd`.
- New candidate pin: `3ddbfeb7e0b8824e1022f9edb043c65b5319f82e`. Note: marketplace
  tip at read time is already `93895f808775e04dce9441fbf4014a3d4d40c942` — ahead of
  3ddbfeb7; coordinator should re-confirm the target SHA before editing.
- Range `baa5f117..3ddbfeb7` touches `packs/ash-extension-pack` in 31 commits
  (port-then-delete consolidation, Vision 2040 consolidation, Spark closure courts,
  receipted-action/reactor-step hardening, A2A skill surface absorption at pack
  0.5.0, ledger-paydown doc families, installer switch to `Spark.Igniter.add_extension/5`).

## Raw diff numbers (real output)

- `git -C ~/ggen-marketplace diff baa5f117 3ddbfeb7 -- packs/ash-extension-pack`:
  **94 files changed, 11231 insertions(+), 218 deletions(-)**.
- `diff -rq` over the materialized trees: 51 changed/new paths at directory level.
- Materialized via `git archive <sha> -- packs/ash-extension-pack | tar -x` into
  `/tmp/w80-pack-old` and `/tmp/w80-pack-new` (kept for coordinator inspection).

## What changed between the pins

1. **Render-relevant query semantics changed** (highest risk class):
   - `templates/extension.ex.tmpl` SPARQL: every sub-query now joins
     `aex:sectionOf ?spec` + `?spec aex:packageName ?package_name` and adds
     `ORDER BY ?package_name ...` (previously unordered or section-scoped only);
     new OPTIONAL vars `codegen_task` / `codegen_name`;
     new `FILTER NOT EXISTS { ?s aex:fixtureOnly true }`.
   - `queries/reactor_steps.rq`: adds required `?package_name` projection and
     `GROUP BY / ORDER BY ?package_name ?step_order`.
   - `queries/reactor_step_modules.rq` (new file); `queries/receipted_action.rq`
     gains `ORDER BY ?package_name`.
2. **New optional ontology properties** consumed by templates: `aex:codegenTask`,
   `aex:codegenName`, `aex:supportSubdir`, `aex:fixtureOnly`,
   `aex:sectionFieldDefault`, `aex:sectionFieldDoc`, `aex:entityDescribe` — all
   unset in ash_surface's `surf:AshSurfaceSpec`.
3. **New templates** (new outputs only if the consumer spec opts in):
   `receipt.ex.tmpl`, `reactor_step.ex.tmpl`, `a2a_skill.ex.tmpl`, LICENSE +
   SCRIPTS_README doc families, plus ~15 `*_court.exs.tmpl` / `runtime_burn_in.exs.tmpl`
   qualification templates (courts run inside pack qualification, not emitted into
   the consumer).
4. **8 templates backing existing ash_surface outputs changed**: `extension.ex.tmpl`
   (161-line delta), `receipted_action.ex.tmpl` (+192), `install.ex.tmpl` (+68),
   `reactor_pipeline.ex.tmpl` (28), `verify.ex.tmpl` (33), `info.ex.tmpl` and
   `persist.ex.tmpl` (23 each), `composition_test.exs.tmpl` (45).
   `reactor_pipeline` / `receipted_action` are NOT rendered for ash_surface (spec
   sets `aex:workflowReactor false`; no `aex:generatesReceiptedAction`; zero
   `aex:ReactorStep` rows) — 2 of the 8 moot. The remaining 6 back live outputs.
5. **Pack-local worked instances naming ash_surface** were added to the pack
   ontology (`aex:AshSurfaceLicense`, `aex:AshSurfaceScriptsIndex` + entries —
   ledger-paydown families). If sync merges pack + consumer ontologies, these
   could emit doc outputs into the consumer repo.

## Would ash_surface's outputs change? (reasoned from the diff, not render-verified)

Verdict: **existing outputs predicted byte-identical; two named risks**.

- The 6 changed templates that actually render for ash_surface changed in two
  modes: (a) additive gating — new OPTIONAL vars are unset in the consumer ontology,
  so they render null and existing template branches apply unchanged; (b) ordering /
  scoping — new ORDER BY keys are stable for ash_surface's single-spec, single-section,
  single-package graph (one `aex:AshExtensionSpec` = `surf:AshSurfaceSpec`, one
  `aex:DslSection` = `surf:SurfaceSection` which does carry `aex:sectionOf`, zero
  `singletonEntityKey` rows, zero `ReactorStep` rows). The new required
  `?spec aex:sectionOf` joins are satisfied by the consumer ontology.
- Risk 1 (ordering): if a future ontology adds multi-row groups, the new ORDER BY
  keys could reorder emitted code. Today's graph is too small to reorder.
- Risk 2 (doc families): pack-ontology worked instances reference ash_surface by
  name. If sync merges pack + consumer graphs, LICENSE / scripts-index doc outputs
  could newly appear or change. The pack ontology itself states the LICENSE family
  is a round-trip-proven ledger-paydown of the existing hand-written LICENSE, so
  predicted byte-stable — but this is the top render-verify item.

No new outputs: reactor steps, receipts, A2A skill, and supportSubdir families all
require spec opt-ins ash_surface does not declare.

## Recommended re-pin decision

**Re-pin, gated on one render-verification run.** The 31-commit gap includes real
fixes ash_surface currently does not receive (installer `Spark.Igniter.add_extension/5`,
Spark closure parser-safety, receipted-action hardening, HDDL closure fixes) and the
pack identity moved 0.1.0 → 0.5.0 with an explicit consolidation law (pack.toml:
sibling generic Ash packs retired; REUSE→COMPOSE→EXTEND→INVENT search order). Staying
on baa5f117 means consuming a pack identity the marketplace has declared superseded.

Exact ggen.toml edit for the coordinator (in `/Users/sac/ash_surface/ggen.toml`):

```toml
[packs]
ash-extension = { git = "https://github.com/seanchatmangpt/ggen-marketplace.git", version = "3ddbfeb7e0b8824e1022f9edb043c65b5319f82e", subdir = "packs/ash-extension-pack" }
```

Opens for the coordinator:
1. Re-confirm target SHA — tip is `93895f80`, already ahead of `3ddbfeb7`.
2. Falsifier for this receipt's verdict: run `ggen sync` in ash_surface at the new
   pin; expected `git -C ~/ash_surface diff --stat` shows only `ggen.lock` (new SHA +
   content_hash). Any other file delta falsifies the byte-identical prediction.

## Commands + exits (real)

- `git rev-parse baa5f117 3ddbfeb7` → both resolve, exit 0.
- `git archive <sha> -- packs/ash-extension-pack | tar -x -C /tmp/w80-pack-{old,new}` → exit 0 both.
- `diff -rq /tmp/w80-pack-old /tmp/w80-pack-new` → 51 paths, exit 1 (differences exist).
- `git diff --shortstat` → 94 files, +11231/−218, exit 0.
- No git mutations; no real-tree writes; scratch confined to /tmp + this receipt.
