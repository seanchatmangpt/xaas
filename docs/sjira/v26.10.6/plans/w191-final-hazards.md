# W191 Final Do-Not-Commit Hazards — v26.10.6 Convergence

Lane W191, 2026-10-06. Fresh `git status --porcelain` per repo (read-only; no git mutations).
Supersedes the stale W153-v2 hazard list (`w153-commit-plan-v2.md`). Classification legend:

- **DO-NOT-COMMIT** = same-day scratch, build output, or generated lockfile noise
- **PARKED** = deliberate untracked work with no owning lane/commit in the sequence
- everything else untracked is COMMIT-eligible

Falsifier: the coordinator's commit script excludes exactly the DO-NOT-COMMIT paths below and
post-commit `git status --porcelain` shows no scratch in the committed set.

## xaas (`/Users/sac/xaas`)

### DO-NOT-COMMIT

| path | why |
|---|---|
| `GGEN-SH-AFTER-MIX-COMPILE.log` | same-day scratch log (mtime 2026-10-06 11:55) |
| `GGEN-SH-AFTER-PROOF.txt` | same-day scratch stub (11:55) |
| `ggen.lock` | generated `ggen sync` lockfile at xaas root (11:55); commit only if the coordinator separately admits the castle-bridge pack pin as a group |
| `.clap-noun-verb/` | same-day scratch (ocel.json, receipts.jsonl, 11:55) |
| `.ggen_igniter/receipts/2026-10-06.jsonl` | same-day receipt log (dir mtime 12:34) |
| `_build-laneW125/`, `_build-laneW141/`, `_build-w136/`, `_build-w150/` | orphaned lane build roots (git-ignored, so not commit hazards, but per the 2026-10-01 cleanup law the coordinator must delete these at integration BEFORE the final commit) |
| `priv/semantic/generated/castle_bridge_shacl.ttl` | same-day ggen sync projection (11:55) paired with `ggen.lock`; same admission condition as `ggen.lock` |

### PARKED

(none — every xaas untracked item is either a deliberate deliverable or scratch)

### COMMIT groups (informational, for the coordinator's sequence)

- Playwright/e2e: 16 new `e2e/*.spec.cjs`, `e2e/global-setup.cjs`, `e2e/seed-witness.exs`,
  staged renames `e2e/ash-admin-*.spec.js -> .spec.cjs`, `playwright.config.cjs`,
  `.github/workflows/playwright-e2e.yml`
- Witness surface (PW5 follow-through): `lib/xaas_web/live/witness_live.ex`,
  `test/xaas_web/live/witness_live_test.exs`, migration
  `priv/repo/migrations/20261006000000_repair_witness_certified_receipts.exs`
- Castle bridge: `lib/xaas/bridges/ferroplan.ex`, `lib/xaas/generated/castle_bridge_contract.ex`,
  `lib/xaas/generated/castle_bridge_edges.ex`, `test/xaas/bridges/`, `test/xaas/generated/`
- Refusal-negative/boundary courts: `test/xaas/castle_refusal_negative*_test.exs` (5),
  `test/xaas/boundary_limits_test.exs`, `test/xaas/semantics/vkg_refusal_negative_test.exs`,
  `test/xaas/actuation_refusal_negative_test.exs`, `test/xaas/ash_surface_drift_guard_test.exs`,
  `test/xaas/ash_surface_generator_test.exs`, `test/xaas/accounts/token_revocation_test.exs`,
  `test/mix/tasks/` (8 files), `test/xaas/mix/tasks/capability_coverage_test.exs`
- Gymact surface: `lib/xaas/operations/gymact_surface.ex` + `test/xaas/operations/gymact_surface_test.exs`
- A2A parse floor: `lib/xaas_web/plugs/a2a_parse_floor.ex`, `lib/xaas_web/a2a/next_read_ash_agent.ex`,
  `test/xaas_web/a2a/v1_protocol_test.exs`
- New docs: `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`,
  `docs/sjira/v26.10.6/` (including this receipt)

## ash_surface (`/Users/sac/ash_surface`)

### DO-NOT-COMMIT

| path | why |
|---|---|
| `doc/` | exdoc build output (139 entries incl. `.build`, `.build.markdown`, HTML); mtime Oct 3; not git-ignored but is a build artifact |

### PARKED (w168 ownerless specimen courts — 30 files)

All untracked top-level `test/*court*.exs` specimen files; count verified 2026-10-06 via
`git status --porcelain | grep '^??' | grep -cE '^.. test/.*court'` -> `30`. w168 ruling: no
owning feature commit in the sequence; do not commit pending an owner.

- `test/aex_spark_dead_surface_court.exs`
- `test/ash_a2a_composition_court.exs`
- `test/ash_a2a_composition_test.exs`
- `test/ash_a2a_info_parity_court.exs`
- `test/ash_a2a_spark_parity_court_test.exs`
- `test/ash_a2a_transformer_court_test.exs`
- `test/ash_a2a_verifier_court_test.exs`
- `test/ash_r2rml_composition_court.exs`
- `test/ash_r2rml_igniter_idempotence_court_test.exs`
- `test/ash_r2rml_info_parity_court.exs`
- `test/ash_r2rml_spark_parity_court_test.exs`
- `test/ash_r2rml_transformer_court_test.exs`
- `test/ash_r2rml_verifier_court_test.exs`
- `test/ash_surface_composition_court.exs`
- `test/ash_surface_igniter_idempotence_court_test.exs`
- `test/ash_surface_info_parity_court.exs`
- `test/ash_surface_spark_parity_court_test.exs`
- `test/ash_surface_transformer_court_test.exs`
- `test/ash_surface_verifier_court_test.exs`
- `test/audit_trail_composition_court.exs`
- `test/audit_trail_igniter_idempotence_court_test.exs`
- `test/audit_trail_info_parity_court.exs`
- `test/audit_trail_spark_parity_court_test.exs`
- `test/audit_trail_transformer_court_test.exs`
- `test/audit_trail_verifier_court_test.exs`
- `test/notification_extension_composition_court.exs`
- `test/notification_extension_igniter_idempotence_court_test.exs`
- `test/notification_extension_info_parity_court.exs`
- `test/notification_extension_spark_parity_court_test.exs`
- `test/notification_extension_transformer_court_test.exs`
- `test/notification_extension_verifier_court_test.exs`

(31 paths listed against the count of 30 because `test/ash_a2a_composition_test.exs` is a
non-`court`-named sibling in the same ownerless family — classify it with the courts.)

**EXCEPTION — must be COMMITTED with its module, NOT parked:**
`test/ash_surface/a2a_bridge_test.exs` pairs with the deliverable
`lib/ash_surface/a2a_bridge.ex`. It is under `test/ash_surface/` (nested), not a top-level
specimen court.

### COMMIT

- `lib/ash_surface/a2a_bridge.ex` + `test/ash_surface/a2a_bridge_test.exs` (a2a bridge group)
- `fixture/burn_in/` (deliberate burn-in fixtures: evidence_export/runtime_burn_in/closure_receipt
  for ash_surface, notification_extension, ash_r2rml; mtime 2026-10-06 13:10, same-day but
  deliberate deliverable per mtime-rule exception)
- `docs/sjira/v26.10.3/ARD-PRD.ttl` (deliberate ARD/PRD ontology deliverable)
- all ` M ` modified files (lib/, test/, conformance/, priv/static regen, docs) — lane work

## ggen (`/Users/sac/ggen`)

No untracked files. 8 tracked modifications (.claude-plugin, .specify, Cargo.toml/lock,
ggen.toml, docs) — all lane work, COMMIT.

## ggen-marketplace (`/Users/sac/ggen-marketplace`)

No untracked files. 5 tracked modifications (marketplace.active.toml, ash-extension-pack
gates/ontology/template) — COMMIT.

## ggen_igniter (`/Users/sac/ggen_igniter`)

No DO-NOT-COMMIT, no PARKED. The `R`/`RM` entries (pack move
`test/fixtures/ash_manufacture_pack/ -> priv/ggen/ash-manufacture-pack/`, 28 renames) and the
5 `D __pycache__ .pyc` deletions are deliberate deliverables — COMMIT the whole group.
(Do not be tempted to "restore" the deleted .pyc files; deleting them is the point.)

## ash_pplan (`/Users/sac/ash_pplan`)

No untracked files. 2 tracked modifications (`docs/demonstration.md`,
`lib/ash_pplan/providers/a2a.ex`) — COMMIT.

## zcode-cli (`/Users/sac/zcode-cli`)

### DO-NOT-COMMIT

| path | why |
|---|---|
| `artifacts/` | same-day scratch (agent artifacts: 02-task-analysis.md, 03-arch-decompose.md, 04-env-setup.md, 05-meta-prompt.md, exec/verify_*; mtime 2026-10-06 12:12) |

### COMMIT

`test/expert-strategy-config.test.ts`, `test/fixtures/max-turns/setting-subagent-{100,invalid,missing}.json`
(same-day but deliberate deliverables — they pair with the modified `test/max-turns.test.ts` and
`src/max-turns.ts`), plus the 13 tracked modifications.

## gymact (`/Users/sac/gymact`)

No untracked files. 7 tracked modifications — COMMIT.

## ferroplan (`/Users/sac/ferroplan`)

### DO-NOT-COMMIT

| path | why |
|---|---|
| `crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` | 3.5 MB compiled WASM build artifact, rebuilt same-day (mtime 2026-10-06 12:06); registry already carries ARTIFACTS.sha256 + capability-registry.json which ARE committed surface — only the binary blob stays out |
| `.ggen-v2/receipt-log.jsonl`, `.ggen-v2/receipt.json` (both root and `crates/ferroplan-wasm/`) | tracked-but-modified ggen scratch receipts (mtime Oct 1); checkout noise, not lane work — leave dirty or restore, never commit |

### COMMIT

the remaining tracked modifications (README/docs/pyproject/src) — none listed beyond the
.ggen-v2 ones; if `git status` shows only .ggen-v2 modifications plus the wasm blob, the
committed set for ferroplan this cycle is the wasm-registry metadata only.

## wasm4pm (`/Users/sac/wasm4pm`)

No untracked files. 28 tracked modifications (package.json version bumps across workspaces,
README/docs, one test) — COMMIT.

## ash_a2a (`/Users/sac/ash_a2a`)

### PARKED

| path | why |
|---|---|
| `docs/thesis/` | ownerless LaTeX thesis (main.tex/pdf/aux/toc/out/log); mtime Oct 5; no owning lane/commit in the v26.10.6 sequence; park pending owner |

### COMMIT

`lib/ash_a2a/authzen/client.ex`, `test/ash_a2a/command_bus_test.exs`, `test/test_helper.exs` (tracked mods).

## Verification record

Commands run (read-only): `git -C <repo> status --porcelain` for all 11 repos; `ls -lT` mtime
sampling on scratch candidates; `find` inventories of ambiguous dirs (`.clap-noun-verb/`,
`.ggen_igniter/receipts/`, `priv/semantic/`, `artifacts/`, `doc/`, `fixture/`, `docs/thesis/`,
`ferroplan-wasm/registry/`); court-test count grep (30). No git mutations performed.

## W246 burn_in disposition

**Verdict: PARK** (with the parked specimen courts; do not stage in the C-group).

**Evidence** (repo /Users/sac/ash_surface, branch state 2026-10-06):

- `git log --all -- fixture/burn_in/` → empty; `git status --short` → `?? fixture/`
  (whole `fixture/` tree is untracked; never committed on any branch).
- Contents: 5 specimen families (ash_a2a, ash_r2rml, ash_surface, audit_trail,
  notification_extension) × 3 self-contained scripts each (`runtime_burn_in.exs`,
  `closure_receipt.exs`, `evidence_export.exs`), 6245 lines total. No README/manifest.
- Headers self-describe as stand-alone courts: `Mix.install`-based, "Run:
  `elixir packs/ash-extension-pack/fixture/burn_in/runtime_burn_in.exs`", "Touches
  nothing else in the tree". No evidence/ output dir present (never run in place).
- Consumers: `grep -rn "burn_in" lib/ test/ priv/ ... | grep -v burn_in_test` → only
  `test/tokyo_depeg_surface_test.exs`, which consumes `priv/surfaces/tdb_burn_in_manifest.exs`
  (authored, committed surface manifest — unrelated to `fixture/burn_in/`).
  `grep -rn "fixture/burn_in"` repo-wide → zero hits outside the fixture itself.
  None of the 31 parked specimen court files (`test/*_court*.exs`, `test/*_parity*`,
  `test/*_transformer*`, `test/*_verifier*`) reference `burn_in` at all.
- The five fixture families correspond by name to the five parked specimen families,
  but no code or court links them.

**Disposition**: consumed by no committed lib/ code and no committed or parked court —
genuinely ownerless → parks alongside the 31 specimen courts. If the specimen courts are
later admitted, `fixture/burn_in/` may be staged with them as their burn-in harness.
