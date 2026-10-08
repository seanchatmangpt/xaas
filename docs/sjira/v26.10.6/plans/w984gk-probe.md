# W984gk — unclaimed-family probe: `lib/mix/tasks/` vs test coverage

Lane: W984gk · branch feat/playwright-surface · subject: feat/playwright-surface @
(pre-probe HEAD, uncommitted lane files only) · 2026-10-07.

Scope: census of every `lib/mix/tasks/*.ex` (58 tasks) against `test/` coverage;
court for genuinely unexercised tasks in
`test/mix/tasks/family_court_w984gk_test.exs`. Zero mocks. No commit (lane law).

## Dispositions (58 tasks)

Covered (direct dedicated test file in test/mix/tasks/ or equivalent direct task
invocation):

| task | court |
|---|---|
| xaas.eu_ai_act_annex_iv | test/mix/tasks/xaas_eu_ai_act_annex_iv_test.exs |
| xaas.eu_ai_act_pack | test/mix/tasks/xaas_eu_ai_act_pack_test.exs |
| xaas.ingest_capability_receipts | test/mix/tasks/xaas_ingest_capability_receipts_test.exs |
| xaas.ocel_validate | test/mix/tasks/xaas_ocel_validate_test.exs |
| xaas.release_audit | test/mix/tasks/xaas_release_audit_test.exs |
| xaas.safe_generate_migrations | test/mix/tasks/xaas_safe_generate_migrations_test.exs (+ fail_fast shell test) |
| xaas.self_digest | test/mix/tasks/xaas_self_digest_test.exs |
| xaas.stop_court | test/mix/tasks/xaas_stop_court_test.exs |
| xaas.verify_and_commit | test/mix/tasks/xaas_verify_and_commit_test.exs |

Indirectly covered (exercised through domain/ultracode court tests, no dedicated
task test):

| task | exercising tests |
|---|---|
| xaas.airo.compile_shacl | test/xaas/airo_shacl_court_test.exs, test/xaas/semantics/w640_differential_shacl_test.exs (task file sibling-modified — read-only this lane) |
| xaas.ash_surface | xaas_refusal_render_test, ash_surface_drift_{mutation,guard}_test |
| xaas.autonomy.qualify | test/xaas/ultracode/recurrence_test.exs |
| xaas.capability_coverage | test/xaas/mix/tasks/capability_coverage_test.exs |
| xaas.close_coverage_gap | test/xaas/sparql_bridge_court_test.exs |
| xaas.episode | ultracode semantic_drive / machine_experience / anchor tests |
| xaas.export_authority_ledger | test/xaas/operations/authority_ledger_export_test.exs |
| xaas.fabric.redeploy | test/xaas/ultracode/fabric_redeploy_test.exs |
| xaas.generated.regen_check | test/xaas/generated/regen_check_court_test.exs |
| xaas.machine_experience | test/xaas/ultracode/machine_experience_test.exs |
| xaas.ocel.ocpm | test/xaas/ocel/ocpm_test.exs |
| xaas.release_snapshot.verify | xaas_refusal_render_test |
| xaas.replay | test/xaas/ultracode/semantic_replay_test.exs |
| xaas.run_validate | ultracode run_validate/ocel_conformance/autonomic tests |
| xaas.sa2a.execute | test/xaas/sa2a/execute_test.exs |
| xaas.semantic.materialize / xaas.semantic.receipt | ultracode semantic_tasks_help / semantic_jira_e2e / semantic_receipt tests |
| xaas.sjira.ard_court / engineer_work / yield | test/xaas/sjira/* |
| xaas.telemetry.check_ontology_staleness | test/xaas/ontology/staleness_task_court_test.exs |
| xaas.ultracode.audit / export_ocel / learn / ocel_conformance / reconcile_runs / repos / start / suite_health | test/xaas/ultracode/* |
| xaas.doctor (before this lane) | none → courted below |

Uncovered before this lane, courted here (10 tests, one file):

| task | legs courted |
|---|---|
| xaas.doctor | real run → last-stdout-line JSON parses; exact 6-check name list; mock_gate=pass on this tree (timeout 600s: lane census walks all _build-lane* dirs) |
| xaas.wd.fa_eval | real file write to tmp; output marker `WD_FA_EVALUATION=<path>`; decoded JSON report non-empty |
| xaas.wd.stogaf_receipt | unset env → UNKNOWN_SUBJECT_SHA fallback in written JSON; set env → sha bound into receipt; NEW: empty env → graceful fallback (defect fix below) |
| xaas.receipts | empty epoch → "No receipts found"; non-UUID epoch → typed `Could not read receipts` stderr path (real Ash `:for_epoch` read over sandboxed Postgres) |
| xaas.internal_api_token | no subcommand → typed `usage:` Mix.raise; `list` on empty ledger → "No InternalApiToken rows exist yet." (real Ash read, sandbox auto mode) |
| xaas.autonomy.audit | `--window-minutes 5` over empty sandbox window → "standing: ALIVE (UAR=0, DCR=0)" |

Deliberately not courted (legitimate, typed reasons — no filler):

- **xaas.export_refusal_ledger** — writes the tracked artifact
  `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json`; its engine
  `lib/xaas/operations/refusal_ledger_export.ex` is lane-modified by a sibling.
  Mutating a sibling-owned tracked artifact from a probe lane is out of contract.
- **xaas.autonomy.audit violation/bad-opts legs, xaas.successor, xaas.autonomic.\*,
  xaas.autonomy.stress, xaas.ultracode.stop / drain / status violation paths,
  xaas.ash.gen, xaas.library.manufacture, xaas.semantic.crown** — `System.halt(1)`
  inside ExUnit kills the VM; or the task mutates real fleet/process/campaign
  state (fabric redeploy, tick loops, run lifecycle, campaign start/stop/drain);
  or (ash.gen, library.manufacture, semantic.crown, successor) are code
  generation/work-order minting tasks whose real invocation writes into the
  shared tree — out of a read-mostly probe lane's contract.
- **xaas.internal_api_token issue/revoke legs** — DB-mutating legs of the same
  task whose list/usage legs are courted; left to a dedicated lane with full
  sandbox control.

## Findings

1. **Defect fixed (lane-owned, unclaimed file):**
   `lib/mix/tasks/xaas.wd.stogaf_receipt.ex` — `STOGAF_SUBJECT_SHA=""` (set but
   empty) crashed the task with FunctionClauseError in
   `Xaas.CaseStudies.WdFa.Stogaf.Receipt.build/1` (requires non-empty binary)
   instead of the documented `UNKNOWN_SUBJECT_SHA` fallback. Fixed to treat
   empty-as-unset; regression test added. Mutation rationale: reverting the
   case-expression to `System.get_env(...) || fallback` flips the new test red.
2. **Doctor lane census cost — FIXED (lane-owned, unclaimed file):**
   `lib/mix/tasks/xaas.doctor.ex`'s `lane_leases` check walked every file under
   every `_build-lane*/` with synchronous `File.stat` — measured against 127
   orphaned lane roots × ~426MB it exceeded 600s, making both the check and any
   test of it unusable. Fixed with a per-lane 2,000-file cap
   (`@lane_walk_file_cap 2_000`, `Enum.reduce_while` walk, `File.lstat`,
   truncation disclosed in the check's detail string). Mutation rationale:
   raising the cap back toward unbounded flips the doctor court test red on
   its 120s timeout. 127 orphaned lane roots totalling ~54GB remain on disk —
   coordinator cleanup item, not this lane's contract.
3. **Pre-existing warnings observed during compile (not this lane's):**
   `approval_causal_anatomy.ex:144` unused `intent`;
   `xaas.airo.compile_shacl.ex:273` unused `descriptions_with_predicate/2`
   (sibling-modified file — untouched).

## Verification

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984gk \
  mix test test/mix/tasks/family_court_w984gk_test.exs
```

- Run 1: 8/10 passed — doctor lane-census >60s timeout (→ finding 2) and
  stogaf empty-env FunctionClauseError (→ finding 1).
- Run 2 (20k cap): 10/11 — doctor test still >120s (cap lowered to 2k).
- Run 2 (interleaved): one compile-abort from a sibling lane's in-flight
  `lib/mix/tasks/xaas.release_audit.ex` syntax break (compile-freeze SLA
  honored: waited for their fix, poll-parse confirmed PARSE_OK, did not touch
  their file). Not counted as a lane test failure.
- Final gate: `Result: 11 passed, 0 failures` in 58.2s, exit 0.
- Mock gate: `mix run -e 'IO.inspect(scan_mock_usage(["test","lib"]))'` → `[]`.
