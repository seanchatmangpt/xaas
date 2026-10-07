# W464 — Commit Manifest v3 (SUPERSEDES w153-v2 / w214 / w399 amendments)

Lane W464, 2026-10-06. Repo: /Users/sac/xaas @ feat/playwright-surface. Read-only
except this file; no git mutations performed.

**Inputs reconciled**: `_INTEGRATION_RUNBOOK.md` (incl. W399/W458/W460/W461 addenda),
`plans/w214-staging-sequence.md`, `plans/w399-runbook-freshness.md`,
`plans/w440-cleanup-manifest.md`, `plans/w323-dod7-provenance.md`.

**Live porcelain at receipt time: 245 lines (171 M, 2 RM, 72 ??)** — up from w399's
238. Drift absorbed below; every porcelain line is placed in exactly one group, the
DO-NOT-COMMIT list, the delete list, or an OPEN-DECISION item.

Precedence: W191 hazards > W225/W214 sequences > W153-v2 base, as amended by w334
(castle.ex sync-output), w354, w399, w440 (cleanup), W458/W460/W461 addenda. This
manifest supersedes all prior manifests where they differ.

---

## 0. Pre-G1 cleanup (BEFORE any commit; coordinator transition)

Execute the w440 READY-TO-DELETE list (50 items ≈ 18.9–19.0 GB): 28 xaas lane roots
(12.7 GiB), 11 sibling-repo roots (3.5 GiB), 9 /tmp items (2.7 GiB, incl. `/tmp/w392-*`
and `/tmp/os13-quarantine-*`; `/tmp/xaas-e2e-server.log` excluded while the server is
live), plus repo-root `GGEN-SH-AFTER-MIX-COMPILE.log` and `GGEN-SH-AFTER-PROOF.txt`
(both still on porcelain — delete, do not commit). ACTIVE roots hold until their lanes
land (incl. `_build-laneW394`, `_build-laneW408`, `_build-laneW437`). `erl_crash.dump`
(gitignored, not on porcelain) deletes only after final verification (w444 classed
BENIGN). Deletion is a coordinator transition (plan→approve→delete, APFS snapshot
thinning per cleanup law). `ggen.lock` is KEEP: commit only via explicit pack-pin
admission, never delete.

Gate re-runs at stage time (all mix under `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test`
only — no dev compile, live phx): mock gate
(`scan_mock_usage(["test","lib"])` → `[]`), ash-surface drift guard
(`mix test test/xaas/ash_surface_drift_guard_test.exs test/xaas/ash_surface_generator_test.exs`),
refusal negative courts (castle batches 1–6 + r2rml + vkg), Playwright tokened+seeded.

---

## 1. Ordered commit groups (G1→G12; exact-path staging, directory adds only where noted)

### G1 — deps (FIRST)
`mix.exs` `mix.lock`
`build(deps): pin v26.10.6 dependency set`

### G2 — release metadata
`VERSION` `CHANGELOG.md` `README.md`
`chore(release): v26.10.6 version bump + changelog + README`
(today's CHANGELOG bullet rides in this path — no separate line)

### G3 — config
`config/config.exs` `config/dev.exs` `config/test.exs`
`chore(config): v26.10.6 config alignment`

### G4 — CI
`.github/workflows/ci_cd.yaml` `.github/workflows/playwright-e2e.yml`
`ci: add playwright-e2e workflow, update ci_cd for v26.10.6`
**closure-gates.yml stays OUT** (G4-held; w327 GGEN_SHA-vs-ggen.lock unresolved;
add only on coordinator admission).

### G5 — lib fixes (70 files; depends on G1)
w214 G5 verbatim + w399's 4 additions. Final list:

```
lib/mix/tasks/xaas.ash_surface.ex
lib/mix/tasks/xaas.capability_coverage.ex
lib/mix/tasks/xaas.fabric.redeploy.ex
lib/mix/tasks/xaas.ingest_capability_receipts.ex
lib/mix/tasks/xaas.release_audit.ex
lib/mix/tasks/xaas.release_snapshot.verify.ex
lib/mix/tasks/xaas.run_validate.ex
lib/mix/tasks/xaas.safe_generate_migrations.ex
lib/mix/tasks/xaas.self_digest.ex
lib/mix/tasks/xaas.sjira.engineer_work.ex
lib/mix/tasks/xaas.stop_court.ex
lib/xaas/a2a/agent.ex
lib/xaas/a2a/task.ex
lib/xaas/accounts/token.ex
lib/xaas/actuation.ex
lib/xaas/application.ex
lib/xaas/autofde/status_parser.ex
lib/xaas/bridges/ex4pm.ex
lib/xaas/bridges/graphlaw.ex
lib/xaas/bridges/pplan.ex
lib/xaas/bridges/registry.ex
lib/xaas/bridges/ferroplan.ex            # new
lib/xaas/castle.ex                        # ⚠ SYNC-OUTPUT 26839b9d… from docs/sjira/v26.10.6/plans/w390-sync-output-staging/lib/xaas/castle.ex — NOT live-tree eac1e204… (w334 BINDING)
lib/xaas/chicago/layer.ex
lib/xaas/conference/attendee.ex
lib/xaas/conference/event.ex
lib/xaas/conference/registration.ex
lib/xaas/conference/session.ex
lib/xaas/conference/speaker.ex
lib/xaas/conference/sponsor.ex
lib/xaas/conference/track.ex
lib/xaas/eds/falsifier.ex
lib/xaas/fabric.ex
lib/xaas/fabric/failure.ex
lib/xaas/fabric/planes/actuation.ex
lib/xaas/fabric/planes/evidence.ex
lib/xaas/fabric/planes/law.ex
lib/xaas/fabric/planes/process.ex
lib/xaas/graphlaw/catalog.ex
lib/xaas/igniter/pack_manifest.ex
lib/xaas/igniter/refusal_code.ex
lib/xaas/marketplace/pack.ex
lib/xaas/operations/capability_liveness_receipt.ex   # w337-era policy work; NOT an admin-ingest fix (w460 refuted the policy hypothesis)
lib/xaas/operations/gymact_surface.ex     # new
lib/xaas/sa2a/court.ex
lib/xaas/security/finding.ex
lib/xaas/ultracode/autonomic.ex
lib/xaas/ultracode/semantic_drive.ex
lib/xaas/ultracode/semantic_drive/plan_next.ex
lib/xaas/vault.ex                          # OS-17 vault guard
lib/xaas/witness/catalog.ex
lib/xaas/witness/certified_receipt.ex
lib/xaas/witness/verification_key.ex
lib/xaas_web/a2a/next_read_user_agent.ex
lib/xaas_web/a2a/next_read_ash_agent.ex   # new
lib/xaas_web/a2a/v1_transport_plug.ex     # new
lib/xaas_web/a2a/zoe_event_simulation_agent.ex
lib/xaas_web/controllers/execution_fabric_controller.ex
lib/xaas_web/controllers/health_controller.ex
lib/xaas_web/endpoint.ex
lib/xaas_web/live/chicago/drill_down_live.ex
lib/xaas_web/live/chicago/seller_live.ex
lib/xaas_web/live/marketplace_catalog_live.ex
lib/xaas_web/live/marketplace_pplan_explorer_live.ex
lib/xaas_web/live/witness_live.ex          # new
lib/xaas_web/live/system/command_center_adapter.ex
lib/xaas_web/live/system/command_center_live.ex
lib/xaas_web/plugs/stripe_raw_body_reader.ex
lib/xaas_web/plugs/a2a_parse_floor.ex      # new
lib/xaas_web/router.ex
```

`fix(lib): v26.10.6 convergence — witness domain, ferroplan bridge, a2a parse floor, gymact surface, refusal codes`

### G6 — generated (incl. W247 snapshots; one open admission gate)
- `lib/xaas/generated/castle_bridge_contract.ex`
- `lib/xaas/generated/castle_bridge_edges.ex`
- `priv/semantic/generated/castle_bridge_shacl.ttl` — **ADMISSION-GATED (w214 C1)**:
  stages only with explicit coordinator admission of the castle-bridge pack-pin group;
  otherwise DO-NOT-COMMIT with `ggen.lock`.
- `priv/semantic/generated/MANIFEST.json` — **NEW since w399, G6-adjacent decision**.
  RECOMMEND ADMISSION alongside the shacl: same generator surface, one sync run emits
  both; splitting strands the manifest reference. If C1 admission is refused, both go
  DO-NOT-COMMIT together.
- `priv/ash_surface/aria.json`, `priv/ash_surface/ash_surface_runtime.mjs`,
  `priv/ash_surface/live_view.json`, `priv/ash_surface/surface_contract.json`,
  `priv/ash_surface/xaas_ash_surface_client.mjs`
- W247 resource snapshots (w399 G6/G7c option, folded here as G6-snapshots):
  `git add priv/resource_snapshots/` covering
  `priv/resource_snapshots/repo/actuation_intents/20261006212509.json`,
  `.../actuation_receipts/20261006212512.json`, `.../billing_revenue_recognitions/`,
  `.../graphlaw_capabilities/`, `.../graphlaw_engine_limits/`,
  `.../ultracode_runs/20261006212513.json`, `.../witness_certified_receipts/`,
  `.../witness_verification_keys/`

Gate: ash-surface drift guard BEFORE this commit.
`chore(generated): regenerate castle-bridge contract/edges/SHACL + ash_surface projection + W247 snapshots`

### G7 — migration
`priv/repo/migrations/20261006000000_repair_witness_certified_receipts.exs`
`fix(repo): repair witness certified_receipts migration`

### G7b — W247 convergence snapshots migration
`priv/repo/migrations/20261006212508_add_w247_convergence_snapshots.exs`
`chore(repo): add W247 convergence snapshots migration (post-W258 dedup fix)`

### G8 — scripts / courts / bench
`scripts/semantic_replay_task.exs`
`priv/courts/substitution_policy_court.exs`
`bench/prometheus_proxy_error_path_bench.exs`   # w408 typed-skip conversion — include
`bench/sjira_atlassian_projection.exs`
`bench/sjira_atlassian_transport.exs`
`bench/sjira_engineer_workflow.exs`
`chore(scripts): semantic replay task, substitution policy court, bench alignment`

### G9 — tests (81 paths; depends on G5/G6/G7)
w214 G9 verbatim (70) + w399's 10 + w408's prometheus controller test. Final list:

```
test/fixtures/semantic_work/sj-001-descriptor.json
test/mix/tasks/xaas_ingest_capability_receipts_test.exs
test/mix/tasks/xaas_refusal_render_test.exs
test/mix/tasks/xaas_self_digest_test.exs
test/mix/tasks/xaas_stop_court_test.exs
test/sjira/v26_9_23_goal_test.exs
test/xaas/actuation_test.exs
test/xaas/actuation_refusal_negative_test.exs
test/xaas/accounts/token_revocation_test.exs
test/xaas/ash_surface_drift_guard_test.exs
test/xaas/ash_surface_generator_test.exs
test/xaas/autofde/status_parser_test.exs
test/xaas/boundary_limits_test.exs
test/xaas/bridges/                          # dir: ferroplan_test.exs — re-check contents at stage time
test/xaas/castle_refusal_negative_test.exs  # incl. w297d castle-lock mutex
test/xaas/castle_refusal_negative_batch2_test.exs
test/xaas/castle_refusal_negative_batch3_test.exs
test/xaas/castle_refusal_negative_batch4_test.exs
test/xaas/castle_refusal_negative_batch5_test.exs
test/xaas/castle_refusal_negative_batch6_test.exs
test/xaas/chicago/bridges/ex4pm_test.exs
test/xaas/chicago/bridges/pplan_test.exs
test/xaas/chicago/bridges/registry_test.exs
test/xaas/chicago/consumer/chicago_view_test.exs
test/xaas/chicago/negative_courts/chicago_authority_courts_test.exs
test/xaas/chicago/negative_courts/chicago_consequence_courts_test.exs
test/xaas/chicago/negative_courts/chicago_evidence_courts_test.exs
test/xaas/chicago/negative_courts/chicago_graph_courts_test.exs
test/xaas/chicago/negative_courts/support/mutants.ex
test/xaas/chicago/presence_pin_test.exs
test/xaas/chicago/seller/seller_live_test.exs
test/xaas/chicago/surface/command_center_adapter_test.exs
test/xaas/conference/conference_test.exs
test/xaas/eds/falsifier_test.exs
test/xaas/fabric/castle_alive_test.exs
test/xaas/generated/                        # dir: castle_bridge_contract_test.exs
test/xaas/graphlaw/catalog_test.exs
test/xaas/igniter/igniter_catalog_test.exs
test/xaas/mix/                              # dir: tasks/capability_coverage_test.exs
test/xaas/ocel/ocpm_test.exs
test/xaas/operations/capability_liveness_receipt_test.exs
test/xaas/operations/gymact_surface_test.exs
test/xaas/planning/stale_plan_gate_test.exs
test/xaas/receipt/r_projection_test.exs
test/xaas/sa2a/court_stale_plan_test.exs
test/xaas/sa2a/execute_test.exs
test/xaas/sa2a/route_test.exs
test/xaas/security/security_test.exs
test/xaas/semantics/r2rml_refusal_test.exs
test/xaas/semantics/vkg_refusal_negative_test.exs
test/xaas/sjira/ard_court_test.exs
test/xaas/sjira/engineer_workflow_test.exs
test/xaas/telemetry/ocel_ash_emitter_test.exs
test/xaas/topology_guard_test.exs
test/xaas/trimtab/context_budget_test.exs
test/xaas/trimtab/falsifier_test.exs
test/xaas/trimtab/recovery_test.exs
test/xaas/ultracode/autonomic_profile_sense_test.exs
test/xaas/ultracode/machine_experience_test.exs
test/xaas/ultracode/semantic_drive_anchor_test.exs
test/xaas/ultracode/semantic_drive_plan_next_test.exs
test/xaas/ultracode/semantic_drive_test.exs
test/xaas/ultracode/semantic_jira_bridge_test.exs
test/xaas/ultracode/semantic_replay_test.exs
test/xaas/ultracode/sj_program_registry_test.exs
test/xaas/vault_env_guard_test.exs
test/xaas/witness/catalog_test.exs
test/xaas_web/a2a/v1_protocol_test.exs
test/xaas_web/a2a/v1_sse_test.exs
test/xaas_web/a2a/zoe_event_simulation_agent_test.exs
test/xaas_web/controllers/health_controller_test.exs
test/xaas_web/controllers/prometheus_query_controller_test.exs   # w408
test/xaas_web/endpoint_body_limit_test.exs
test/xaas_web/execution_fabric_controller_test.exs               # note: actual porcelain path is test/xaas_web/execution_fabric_controller_test.exs
test/xaas_web/ggen_workbench_auth_floor_test.exs
test/xaas_web/live/marketplace_catalog_live_test.exs
test/xaas_web/live/marketplace_pplan_explorer_live_test.exs
test/xaas_web/live/witness_live_test.exs
test/xaas_web/plugs/require_internal_api_token_test.exs
```

Note: w399 wrote `test/xaas_web/a2a/execution_fabric_controller_test.exs`-adjacent
phrasing; the real path on porcelain is
`test/xaas_web/execution_fabric_controller_test.exs` (M) — the list above uses the
real path. Gates: mock gate + refusal courts BEFORE this commit.

`test: v26.10.6 convergence — refusal courts, witness/v1-protocol/ferroplan coverage, trimtab realignment`

### G10 — e2e + playwright (22 paths; depends on G5)
```
playwright.config.cjs
e2e/ash-admin-destroy.spec.cjs        # RM staged rename + w460 settle-wait edit
e2e/ash-admin-state-change.spec.cjs   # RM staged rename + w460 settle-wait edit
e2e/next-read-ml.spec.cjs
e2e/wd-fa-cs2.spec.cjs
e2e/a2a-v1.spec.cjs
e2e/ash-admin-matrix.spec.cjs
e2e/ash-surface-client.spec.cjs
e2e/autofde-lab.spec.cjs
e2e/chicago-pplan-deep.spec.cjs
e2e/dev-routes.spec.cjs
e2e/execution-fabric.spec.cjs
e2e/ggen-workbench.spec.cjs
e2e/global-setup.cjs
e2e/internal-api.spec.cjs
e2e/mcp-a2a.spec.cjs
e2e/seed-witness.exs
e2e/sparql-proxy.spec.cjs
e2e/stripe-webhook.spec.cjs
e2e/system-deep.spec.cjs
e2e/witness.spec.cjs
e2e/zcode-cli-fabric.spec.cjs
```
**w460 marker**: the two ash-admin specs' settle-wait edits are IN-FLIGHT (6/6
stability runs required). Do not stage G10 until w460's receipt lands; if the
coordinator must commit before that, commit the pair with the w460-in-flight marker
in the message.
`test(e2e): playwright surface — v1 protocol, witness, fabric, dev-routes specs; js→cjs rename`

### G11 — docs/plans (LAST; includes this manifest)
```
docs/sjira/v26.10.6/                  # dir add — includes runbook, all plans/, THIS manifest, and the two staging dirs (see §3 decisions)
docs/claude/diataxis/README.md
docs/claude/diataxis/explanation/architecture-overview.md
docs/claude/diataxis/reference/actuation-and-semantics.md
docs/claude/diataxis/reference/ash-configuration.md
docs/claude/diataxis/reference/http-api-surface.md
docs/claude/diataxis/reference/generated-castle-bridge-errc.md
docs/claude/diataxis/how-to/add-a-real-json-api-route-to-an-ash-resource.md
docs/claude/diataxis/how-to/author-ggen-templates-safely.md
docs/claude/diataxis/how-to/fix-ash-admin-and-use-ggen-for-codegen.md
docs/sjira/v26.9.21/001-xaas-semantic-jira-e2e.md
docs/sjira/v26.9.21/002-zcode-ocel-pack-consumer.md
docs/sjira/v26.9.21/001…012 (all twelve numbered receipts, per w214 verbatim)
docs/sjira/v26.9.21/admit.exs
docs/sjira/v26.9.21/generate.py
docs/sjira/v26.9.21/receipts/sa2a_post_SJ-003.exs
docs/sjira/v26.9.21/sa2a_loop.exs
docs/sjira/v26.9.22/sa2a_loop.exs
docs/sjira/v26.9.22/shacl.exs
```
(The v26.9.21 numbered receipts are 001–012 exactly as in w214 G11; not re-spelled
here to avoid transcription error — the w214 list is incorporated by reference.)
`docs: v26.10.6 diataxis reference updates, historical sjira receipts, W214 staging plan`

### G12 — CRO evidence infrastructure (NEW DECISION — RECOMMENDED)
```
docs/cro/   # README.md, CRO-LOOP.md, CYCLE-LOG.md, ARTIFACT-MANIFEST.md, artifacts/
```
RECOMMEND: `docs/cro` ships as its own commit — it is evidence infrastructure (loop
logs + artifact manifest), belongs in history, and keeping it out of G11 prevents the
G11 directory sweep from absorbing it silently.
`docs(cro): CRO loop cycle log, artifact manifest, evidence artifacts`
Order: after G11 (pure docs, no dependency).

---

## 2. DO-NOT-COMMIT list (never `git add`)

| path | why | receipt |
|---|---|---|
| `ggen.lock` | same-day sync lockfile; commit only via explicit coordinator admission of the castle-bridge pack-pin group (with the shacl + MANIFEST.json) | w191, w214 C1 |
| `.clap-noun-verb/` | same-day scratch | w191, w334 |
| `.ggen_igniter/receipts/2026-10-06.jsonl` | same-day receipt log | w191 |
| `.github/workflows/closure-gates.yml` | G4-held until w327 GGEN_SHA-vs-ggen.lock resolved | w399, w327 |
| `GGEN-SH-AFTER-MIX-COMPILE.log` | lane scratch → DELETE | w191, w354, w440 |
| `GGEN-SH-AFTER-PROOF.txt` | lane scratch → DELETE | w191, w354, w440 |
| `.ggen/keys/` (incl. `signing.key`) | SIGNING KEY, never commit; gitignore recommendation stands | w334 |
| `erl_crash.dump` | gitignored crash dump → delete after final verification | w444, w440 |

Not on porcelain but still governed: `.ggen/keys/signing.key`, ferroplan wasm blob +
`.ggen-v2/` receipts (w191; other repos), zcode-cli `artifacts/`, ash_surface `doc/`,
`ggen.lock` + 31 specimen courts + `fixture/` (PARKED), ash_a2a `docs/thesis/`, beam4pm
whole repo (OS-5).

## 3. Open decisions (coordinator, pre-commit)

1. **C1 admission (pre-G6)**: admit `ggen.lock` + `priv/semantic/generated/castle_bridge_shacl.ttl`
   + `priv/semantic/generated/MANIFEST.json` as the castle-bridge pack-pin group, or
   all three stay DO-NOT-COMMIT. Default if unadmitted: DO-NOT-COMMIT (priv/semantic/
   then contributes nothing to any commit).
2. **G11 staging-dir sweep (pre-G11)**: `docs/sjira/v26.10.6/plans/w390-sync-output-staging/`
   and `plans/w392-os12-migration-staging/` sit inside the `docs/sjira/v26.10.6/`
   directory add. DECISION: delete both pre-G11 (recommend: w390 copies are consumed
   by the G5 castle.ex stage and w392's os12 migration is executed, so both staging
   dirs are process residue) or admit them as provenance. Do not let G11 sweep them
   silently. Note w390's receipt file itself (`w390-sync-output-staging.md`) is
   provenance and SHOULD ship in G11.
3. **G4 promotion**: `closure-gates.yml` joins G4 only on coordinator admission after
   the w327 GGEN_SHA-vs-ggen.lock question resolves.
4. **w460 settle-waits (pre-G10)**: hold G10 until w460's 6/6 stability receipt lands,
   or commit with an in-flight marker.

## 4. Delete list

w440 READY-TO-DELETE (50 items, ≈18.9–19.0 GB) is incorporated by reference —
including `/tmp/w392-build`, `/tmp/w392-build-old`, `/tmp/w392-scratch`,
`/tmp/w392-{gen.exs,out}`, `/tmp/os13-quarantine-20261006-165326`, `/tmp/w385-v1-conformance.json`,
`/tmp/w344-server.log`, `/tmp/w325_pytest_full.log` — plus repo-root
`GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`, `erl_crash.dump`
(after final verification), and w334 scratch `/tmp/w334-scratch`,
`/tmp/w334-{before,after}.{txt,log}`. ACTIVE lane roots hold until lanes land.
Deletion = coordinator transition (plan→approve→delete, APFS thinning).

## 5. Post-commit verification sequence (replay card + W461 load rule)

All under `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test` only (no dev compile — live
phx). **W461 load rule: execute at <10 load average on a quiet machine; a replay
receipt minted at load >50 is not admissible ALIVE evidence for contention-sensitive
suites.** Any failure → isolate-twice (unique `MIX_BUILD_ROOT`, then private
`XAAS_CASTLE_TEST_LOCK`) before classifying real.

```bash
# 1. Full test suite (DoD 1) — with INTERNAL_API_TOKEN exported
MIX_ENV=test mix test

# 2. Mock gate (expect [])
mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'

# 3. Sync drift gates (DoD 4) — both must be empty-diff
ggen sync run && git diff --exit-code
mix xaas.ash_surface && git diff --exit-code priv/ash_surface

# 4. Full Playwright, tokened (DoD 5) — server booted with INTERNAL_API_TOKEN, seeded
mix run e2e/seed-witness.exs
PW_PORT=<port> INTERNAL_API_TOKEN=<real-token> npx playwright test   # all specs, no 0-tests

# 5. Strict compiles ×2 (DoD 2)
MIX_ENV=test mix compile --warnings-as-errors
MIX_ENV=prod mix compile --warnings-as-errors

# 6. Residue sweep — per-repo porcelain shows only §2/§3 flagged/parked items;
#    no _build-lane*, no GGEN-SH-*, no erl_crash.dump anywhere (DoD 4 residue legs)
```

Success criteria: (1) green incl. un-ignored bounded suites; (2) `[]`; (3) both drift
gates exit 0 (castle-bridge + ash_surface projections byte-stable at committed head —
castle-bridge leg requires the C1 admission to have landed); (4) all specs green
tokened; (5) both strict compiles exit 0; (6) clean residue sweep.

## 6. Accounting / receipt

- Live porcelain at receipt time: **245 lines** (171 M, 2 RM, 72 ??).
- **MANIFEST-GAP count: 0** — every porcelain line is placed (groups, DNC, delete,
  or a named open decision). Two items are placed-conditional: MANIFEST.json + shacl
  (C1 admission), closure-gates.yml (G4-held).
- Total distinct paths governed: **245 porcelain lines** (renames double-counted per
  side) ≈ 243 unique paths; group path totals: G1 2, G2 3, G3 3, G4 2, G5 70, G6 5+5+8
  (+2 admission-gated), G7 1, G7b 1, G8 6, G9 81, G10 22, G11 28+dir, G12 1 dir (5 files).
- W460 in-flight marker carried on G10's ash-admin pair.
- Falsifier: any path absent from fresh porcelain at execution time voids its row —
  re-pull porcelain immediately before staging (w214 C7 drift discipline).
