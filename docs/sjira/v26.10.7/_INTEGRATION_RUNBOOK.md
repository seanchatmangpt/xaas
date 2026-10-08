# v26.10.7 Fleet Seal — Integration Runbook

> **Status**: this is the v26.10.7 campaign's runbook seed (the Conventions
> section below carries the sweep-lanes rule). The consolidated v26.10.6
> campaign runbook remains at `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md`.

## Conventions

Sweep lanes: campaign-versioned receipt dirs — v26.10.6 lanes write to `docs/sjira/v26.10.6/plans` even during later seals; enumerate all `docs/sjira/*/plans/` dirs (W650g3 wrong-dir miss, corrected by W650g4).

Lane-lease cleanup: osx-clnr classifier r6 (7b12d2e) nominates stale `_build-lane*`/`target-lane*` roots per-candidate (dir-mtime gate); live lanes suppressed. Future sweeps: run the oclnr CLI audit directly (the session MCP may serve a stale build). Cites: `plans/w651d-gate-fix.md` (fix), `plans/w651c2-gate-falsifier.md` (motivating refutation), `plans/w651b-audit-retest.md` (31-root witness).

Mutation-probe conventions (from the 2026-10-07 mutation-audit series):

- **Compound-mutation leg for redundant-pair guards.** When two guards mask each
  other, a single-mutant survival is NOT vacuity. W984ha's M3: the two
  `rate_limit.ex` clamps (lines 27+52) each survived alone but the compound
  mutant was killed — the court's invariant is real, only the *pair* is
  load-bearing. Mutation probes over courts guarding redundant pairs must add a
  compound-mutation leg. Cite: `docs/sjira/v26.10.6/plans/w984ha-probe.md`.
- **Tag-excluded courts report false greens under bare `mix test`.** Files with
  `@moduletag :eu_ai_act` (or any tag in the test_helper exclusion list) show
  "0 tests, N excluded, exit 0" without `--include <tag>` — a bare green on
  these is a FALSE GREEN. Mutation/court verification of such files MUST pass
  `--include <tag>`. Same hazard hid a stale assertion
  (`quiescent_stop_deepening_test.exs:203`, asserting `:OPEN_GAP` against an
  all-`:EVIDENCED` lib) for a whole campaign leg until W984ig's repair — the
  tag exclusion is why it never failed in the default loop. Cites:
  `docs/sjira/v26.10.6/plans/w984ha-probe.md`,
  `docs/sjira/v26.10.6/plans/w984ig-quiescent-repair.md`.

Classifier revision: CLASSIFIER_REVISION bumped 3→4→5→6 across the day's fixes (W651/W651c/W651d); old scan caches (`scan-rN-` prefixes) are invalidated per revision — stale caches self-invalidate, no manual sweep needed. Cites: `plans/w651-osxclnr-classifier.md`, `plans/w651c-fs-gate.md`, `plans/w651d-gate-fix.md`, `plans/w651e-gate-fix-note.md`.

## Landing addendum — 2026-10-07 (lane W984ef)

Verified per-commit on `feat/playwright-surface` (`git log --oneline -25`, `git show --stat`,
grep of receipt docs for exact SHAs). Each landing: SHA, paths, court result, receipt path.

| SHA | Landing | Paths | Court result | Receipt |
|---|---|---|---|---|
| `f0321df2` | W984dq6 SpgGate integration (F2 guard + single-funnel seam) | `lib/xaas/actuation.ex`, `lib/xaas/actuation/spg_gate.ex`, `test/xaas/actuation/spg_gate_test.exs`, `test/xaas/actuation/spg_integration_test.exs` | integration court 7 cases green, ×2 fresh roots | `docs/sjira/v26.10.6/plans/w984dq6-spg-execute.md`; commit receipt `docs/sjira/v26.10.7/plans/w650h22-commit.md` |
| `ee6c18bc` | W650h22 commit receipt for the SpgGate landing | `docs/sjira/v26.10.7/plans/w650h22-commit.md` | docs-only | same file |
| `34fc8a53` | W650h33 vkg query_depth court (W984de, unreceipted-owner) | `test/xaas/semantics/vkg/query_depth_test.exs` (+158) | landed; owner receipt flagged below | `docs/sjira/v26.10.7/plans/w650h33b-commit.md` (git-state verdict corrected by `d51119c5`) |
| `0b1b70fc` + `d51119c5` | W650h33b vkg query_depth court receipt (5 tests) + git-state correction | `docs/sjira/v26.10.7/plans/w650h33b-commit.md` | 5 tests, court green | `docs/sjira/v26.10.7/plans/w650h33b-commit.md` |
| `5cf56c13` | W984ds2b completed-lane courts W984ds + W650za (batch) | `docs/sjira/v26.10.6/plans/w650za-probe.md`, `docs/sjira/v26.10.6/plans/w984ds-probe.md`, `test/xaas/ultracode/w650za_incident_lifecycle_guard_court_test.exs`, `test/xaas/ultracode/validations_court_w984ds_test.exs` | 10 green | `docs/sjira/v26.10.7/plans/w984ds2b-commit.md` |
| `b75918a5` + `f2d30813` | W984ds2b lane commit receipt + cleanup-wording correction (`rm` denied; build root moved to `/tmp`) | `docs/sjira/v26.10.7/plans/w984ds2b-commit.md` | docs-only | same file |
| `32b72c4f` | W650h10 repaired causal_receipt process_receipt_depth court | `test/xaas/causal_receipt/process_receipt_depth_test.exs` (+153), `docs/sjira/v26.10.6/plans/w650h10-owner-defect.md` | 5 passed, 0 failed; standing ALIVE on exact subject | `docs/sjira/v26.10.7/plans/w650h33c-commit.md` (cites `32b72c4f` full SHA) |

### Open items (disclosed, not landed this wave)

- **Idempotency-deepening 3F** — W650h23 in flight; landing pending.
- **W984de owner receipt** — the `34fc8a53` vkg query_depth court landed with an
  unreceipted owner (flagged in the landing commit subject and in
  `plans/w650h33b-commit.md`); owner receipt still UNSUPPORTED/open.

## Landing addendum — 2026-10-07 (lane W984ft)

Verified per-commit on `feat/playwright-surface` (`git log --oneline -30` re-run
at addendum time; HEAD moved past W984ef's range during this lane's read —
`06fed7b2`, `1ac2ad42`, `e2ef8aa5` landed mid-lane and are included). Each row:
real `git show --stat` + receipt grep on disk. Each landing: SHA, paths, court
result, receipt path.

| SHA | Landing | Paths | Court result | Receipt |
|---|---|---|---|---|
| `3c03bffa` | W650h14 gated lib/test landing batch 1 (16 files) | `lib/xaas_web/plugs/prov_origin_header.ex`, `lib/xaas_web/router.ex`, `lib/xaas/dev_seeds.ex`, `lib/xaas/semantics/airo_risk_mapping.ex`, `lib/mix/tasks/xaas.generated.regen_check.ex`, `priv/airo_risk_description.ttl`, `priv/airo/profile.shacl.ttl` + 9 court/test files | fresh-root compile EXIT=0; eu_ai_act census 1354/1355 (1 subprocess compile hit a concurrent lane's mid-edit tree; isolated rerun 26/26) → ≥1352/0/1 MET; staged batch 57/0 EXIT=0 | `docs/sjira/v26.10.7/plans/w650h14-gated-commit.md` (cites `3c03bffa`) |
| `ed015775` | W650h14 docs commit (v26.10.6 runbook + coverage-map append + freeze-deepening receipt) | `docs/sjira/v26.10.6/_INTEGRATION_RUNBOOK.md`, `docs/sjira/v26.10.6/plans/w984cj-coverage-map.md`, `docs/sjira/v26.10.6/plans/w983g-freeze-deepening.md` | docs-only | same receipt; also cited by `docs/sjira/v26.10.6/plans/w984fh-recensus.md` |
| `0153101a` | W984fe landing batch #2 — courts w984eh/en/ea + probes + w984er orphan register | `test/xaas/billing/gov_long_tail_court_w984ea_test.exs`, `test/xaas/chicago/family_court_w984en_test.exs`, `test/xaas/library/cascade_court_w984eh_test.exs`, 5 probe/receipt files | batch re-run 28 passed, exit 0; mock gate `[]` | `docs/sjira/v26.10.7/plans/w984fe-commit.md` (cites `0153101a`) |
| `c6bf5bbc` | W984ed airo_risk_mapping additive entry + W984ee OTP-29 Map.update compat module | `lib/xaas/compat/otp29_map_update.ex` (new), `docs/cro/artifacts/airo-wiring-ledger.md`, `docs/sjira/v26.10.6/plans/w984ed-probe.md`, `docs/sjira/v26.10.6/plans/w984ee-probe.md` | lib landed; w984ee court file ABSENT at stage time (disclosed, left to owning lane) | `docs/sjira/v26.10.6/plans/w984ee-probe.md`; landing receipt `docs/sjira/v26.10.7/plans/w984fe-commit.md` |
| `49992412` | W984et mix.lock unlock (absinthe, absinthe_plug, ash_graphql) | `mix.lock` (3 deletions, diff-verified pre-stage) | docs/dep-only; probe landed later by `43265cb1` | `docs/sjira/v26.10.6/plans/w984et-probe.md` |
| `a420b7d5` | W984ej security parsing robustness court receipt (court file deferred to W984ez) | `docs/sjira/v26.10.6/plans/w984ej-probe.md` | receipt-only; court deferred per batch contract | `docs/sjira/v26.10.6/plans/w984ej-probe.md` |
| `43265cb1` | W984fe: w984et probe + batch commit receipt | `docs/sjira/v26.10.6/plans/w984et-probe.md`, `docs/sjira/v26.10.7/plans/w984fe-commit.md` | docs-only | same file |
| `06fed7b2` | W984eo + W984em courts from finished lanes | `test/xaas/sjira/family_court_w984eo_test.exs`, `test/xaas_web/a2a/a2a_uncovered_branch_court_w984em_test.exs`, w984em/w984eo probes | courts carried green from owner lanes (per commit subject); no separate batch re-run receipt cites this SHA yet | owner probes `w984em-probe.md`, `w984eo-probe.md` (self-carried in the commit; no third-party receipt cites `06fed7b2` by hash yet) |
| `1ac2ad42` | W984es SA2A authority-evidence repair (W984dq9 Finding 1) | `lib/xaas/sa2a/changes/execute.ex`, `test/sa2a/changes/execute_deepening_test.exs` (+274), `docs/sjira/v26.10.6/plans/w984dq9-probe.md`, `docs/sjira/v26.10.6/plans/w984es-repair.md` | deepening court landed with the fix (witnessed `execute_unexpected_reply` BLOCKED path repaired with `:authority` evidence map) | `docs/sjira/v26.10.6/plans/w984es-repair.md` (self-carried in `1ac2ad42`) |
| `e2ef8aa5` | W984fh sixth coverage re-census | `docs/sjira/v26.10.6/plans/w984cj-coverage-map.md` (+78 append), `docs/sjira/v26.10.6/plans/w984fh-recensus.md` | docs/census-only | `docs/sjira/v26.10.6/plans/w984fh-recensus.md` (self-carried) |

### Open items (updated, disclosed)

- **Idempotency-deepening 3F — CLOSED/REPAIRED.** W650h23 landed the repair
  (scoped-read root cause); superseded the "in flight" status from the W984ef
  addendum. The `0b1b70fc`/`d51119c5`-era in-flight flag is retired.
- **W984es SA2A authority repair — LANDED** as `1ac2ad42` (was uncommitted
  in-flight at the start of this lane; landed mid-lane). No longer open.
- **W984ee court file loss + W984fo restoration — still in flight.** The court
  file `test/xaas/compat/otp29_map_update_court_test.exs` is present on disk
  but UNCOMMITTED (`git status` → `??`); no `w984fo` receipt exists yet in
  `docs/sjira/*/plans/`. The W984fe receipt's disclosure (court file absent at
  stage time) stands until the owning lane lands it.
- **Lane build roots** — ~100 `_build-lane*` roots present at the repo root
  (verified by `ls -d _build-lane*`); disclosed as denied-rm leases per the
  fanout cleanup law, pending osx-clnr classifier-r6 per-candidate sweep.

## Landing addendum — 2026-10-07 (lane W984gn)

Third dated landing addendum, following the W984ef/W984ft conventions. Verified
per-commit on `feat/playwright-surface` (`git log --oneline -35` re-run at
addendum time; HEAD = `102c1782`). Covers everything since W984ft's stated
boundary (~`4eba5a44`): the five W984fu landing-batch-#4 commits. No newer
commits from W984gi found. Each row: real `git show --stat` + receipt grep
(`grep -rl <sha> docs/sjira/`) on disk.

| SHA | Landing | Paths | Court result | Receipt |
|---|---|---|---|---|
| `a9056f7b` | W984fj/W984fg/W984eq courts from finished lanes | `test/xaas/operations/castle_verb_court_w984fj_test.exs`, `test/xaas/runtime/family_court_w984fg_test.exs`, `test/xaas_web/controllers/residue_court_w984eq_test.exs` + w984eq/fg/fj probes (6 files, +776) | W984fj 6 passed; W984fg 11 passed (mock gate `[]`); W984eq 5 passed (per batch receipt) | `docs/sjira/v26.10.7/plans/w984fu-commit.md` (cites `a9056f7b` full SHA) |
| `180d4606` | W984fc/W984fa/W984ec eu_ai_act deepenings + W984eu title_iii prose | `test/eu_ai_act/art9x_risk_management_deepening_test.exs`, `test/eu_ai_act/art15x_robustness_deepening_test.exs`, `test/eu_ai_act/art10_2e_art26_4_dataset_purpose_deepening_test.exs` + w984ec/fa/fc probes (6 files, +960) | W984fc art9x 7 passed; W984fa art15x 8 passed; W984ec 3 passed; title_iii landed here because W984fl had not landed (per batch receipt) | `docs/sjira/v26.10.7/plans/w984fu-commit.md` (cites `180d4606` full SHA) |
| `956b772a` | W984ep flake-fix sweep — scope shared-table emptiness reads | 6 test files scoped (`test/mix/tasks/xaas_self_digest_test.exs`, `test/xaas/witness/catalog_durability_test.exs`, `test/xaas/ultracode/semantic_drive_test.exs`, `test/xaas/ultracode/semantic_wave_trigger_test.exs`, `test/xaas/billing/fibo_revenue_actuation_test.exs`, `test/xaas/operations/autofde_planner_connector_depth_test.exs`) + w984ep-probe.md (+197/−31, zero lib/ changes) | batch re-run green (included in the 473-passed batch gate) | `docs/sjira/v26.10.7/plans/w984fu-commit.md` (cites `956b772a` full SHA) |
| `b5615c6d` | W984ff gap-register refresh + W984fp evidence-claims refresh | `docs/sjira/v26.10.6/plans/w859-typed-gap-register.md`, `docs/cro/artifacts/evidence-claims-index.md` + w984ff/fp probes (4 files, +231/−11) | docs-only | `docs/sjira/v26.10.7/plans/w984fu-commit.md` (cites `b5615c6d` full SHA) |
| `102c1782` | W984fu landing batch #4 lane commit receipt | `docs/sjira/v26.10.7/plans/w984fu-commit.md` | docs-only; batch gate: 13 files, `--include eu_ai_act` → 473 passed, 5 skipped, 0 failed, exit 0 (pinned asdf toolchain, `_build-laneW984fu` removed at close) | `docs/sjira/v26.10.7/plans/w984fu-commit.md` — self-carried in its own commit; grep for `102c1782` in docs/sjira/ returns zero third-party citations |

### Open items (updated, disclosed)

- **W984fw foreign seed-row writer — IDENTIFIED + FIX LANDED-IN-TREE (uncommitted).**
  Root cause named in `docs/sjira/v26.10.6/plans/w984fw-seed-writer.md`: the
  liveview_librarian/toggle_pin rows came from the Playwright e2e pipeline
  (`next-read-ml.spec.cjs` pin click → `reader_live.ex` `toggle_pin` actuation)
  when the Playwright webServer inherited `MIX_ENV=test` (no sandbox checkout,
  real rows committed to `xaas_test`). The fix lives in `playwright.config.cjs`
  + `e2e/global-setup.cjs` — present on disk as UNCOMMITTED modifications at
  addendum time. Falsifier: full e2e re-run; coordinator owns the landing.
- **W984fv W784 TOFU — REPAIRED on disk, NOT landed.** Receipt
  `docs/sjira/v26.10.6/plans/w984fv-w784.md` (standing REPAIRED, honesty-bounded):
  `lib/xaas/a2a/tofu.ex` (`Xaas.A2a.Tofu` TOFU pinning + typed `:pin_mismatch`
  rotation refusal) + `test/xaas/a2a/tofu_test.exs` (6/6, exit 0) exist but are
  UNTRACKED (`??` in `git status`) at addendum time. Supersedes the "build in
  flight" flag from this lane's dispatch.
- **W984gc cold-compile triage — in flight, unreceipted.** Grep for `w984gc`
  in `docs/sjira/*/plans/` returns zero hits; no receipt exists yet. The triage
  status stays OPEN until the owning lane writes its receipt.
- **Carried from W984ft, unchanged:** W984ee court file
  (`test/xaas/compat/otp29_map_update_court_test.exs`) uncommitted / no `w984fo`
  receipt; ~100 `_build-lane*` roots pending osx-clnr classifier-r6 sweep.

## Landing addendum — 2026-10-07 (lane W984hs)

Fourth dated landing addendum, following the W984ef/W984ft/W984gn conventions.
Verified per-commit on `feat/playwright-surface` (`git log --oneline -20` re-run
at addendum time; HEAD = `009bd05768794cb8b62e7bc3fda0d9c81faad657`, no commits
newer than `009bd057` found). Covers everything since W984gn's stated boundary
(`102c1782`): landing batches #6 and #7. Each row: real `git show --stat` +
receipt grep (`grep -rl <sha> docs/sjira/`) on disk at addendum time.

| SHA | Landing | Paths | Court result | Receipt |
|---|---|---|---|---|
| `ba3309c7` | W984fy aws_adapter runtime base_url + real Plug/Cowboy local harness court | `lib/xaas/aws_repo_adapters/aws_adapter.ex`, `test/xaas/aws_repo_adapters/aws_adapter_local_harness_court_w984fy_test.exs` (+232), `docs/sjira/v26.10.6/plans/w984fy-probe.md` | court carried green from owner lane (per batch receipts) | `w984gy-commit.md` + `w984hg-commit.md` (both cite `ba3309c7`) |
| `226803b8` | W984fy/W984gu/W984hc — IMDS runtime-config seam + 2xx status guards | `lib/xaas/aws_repo_adapters/aws_adapter.ex`, `test/xaas/aws_repo_adapters/aws_adapter_token_guard_court_w984hc_test.exs` (+92), w984gu/hc repair docs (3 files, +207) | W984hc token-guard court landed with the fix (per batch receipt) | `w984gy-commit.md` + `w984hg-commit.md` |
| `3b0bf56d` | W984gy landing batch #6 — six family courts | `test/xaas/generator/family_court_w984ga_test.exs`, `test/xaas/witness/family_court_w984gb_test.exs`, `test/xaas_web/live/family_court_w984gh_test.exs`, `test/xaas_web/plugs/family_court_w984gf_test.exs` (12 files, +1302) | courts carried green from owner lanes (per batch receipt) | `w984gy-commit.md` + `w984hg-commit.md` |
| `56615dc3` | W984gy landing batch #6 — docs surface + witness/triage/receipt sweep | `docs/sjira/v26.10.6/plans/w984gc-triage.md` (+109), `w984gn-probe.md`, `w984gq-probe.md`, `docs/sjira/v26.10.7/plans/w984gm-census-witness.md` (+29) (8 files, +509) | census witness: 1388 passed, 0 failed, 1 excluded @ `102c1782` | `w984gy-commit.md` (sole citing receipt; self-path only) |
| `857ebe60` | W984gy landing batch #6 lane commit receipt | `docs/sjira/v26.10.7/plans/w984gy-commit.md` | docs-only | **self-carried; grep for `857ebe60` in docs/sjira/ returns zero third-party citations** |
| `d1a2b91b` | W984hg landing batch #7 — gj/gl/gp family courts | `test/xaas/telemetry/family_court_w984gj_test.exs` (+210), `test/xaas/zoe/family_court_w984gl_test.exs` (+324), `test/xaas_web/mcp/family_court_w984gp_test.exs` (+289), `docs/sjira/v26.10.6/plans/w984gp-probe.md` (6 files, +1029) | courts carried green from owner lanes (per batch receipt) | `w984hg-commit.md` |
| `69c5a095` | W984hg batch #7 — W984gr item-14 closure + W984gz truthing | `docs/sjira/v26.10.6/plans/w984gr-item14.md` (+35), `w984gz-probe.md` (+77), `docs/sjira/v26.10.7/_CLOSURE_RECEIPT.md` refresh, gap-register addendum (4 files, +139/−8) | docs-only closure/truthing | `w984hg-commit.md` |
| `3674159f` | W984hg landing batch #7 lane commit receipt | `docs/sjira/v26.10.7/plans/w984hg-commit.md` | docs-only | self-carried; third-party citations appear only after `009bd057` added the pushed head, and even `009bd057` itself has **zero** citations |
| `009bd057` | W984hg — record pushed head in lane receipt | `docs/sjira/v26.10.7/plans/w984hg-commit.md` (2+/2−) | docs-only; records the pushed head | **self-carried; zero third-party citations at addendum time** |

### Open items (updated from disk, disclosed)

- **W984hm landing batch #8 — IN FLIGHT, unreceipted.** `grep -rl w984hm
  docs/sjira/` returns zero hits at addendum time; no receipt exists yet.
  Status stays OPEN until the owning lane writes its receipt.
- **W984hd ash_pplan re-pin — LANDED-IN-ash_pplan.** Receipt
  `docs/sjira/v26.10.6/plans/w984hd-repin.md` is present on disk; the landing
  itself happened in the ash_pplan repo, so here it is receipt-only.
- **W984gm census witness — RESOLVED (was a false alarm).** W984hg's report
  that `w984gm-census-witness.md` "does not exist on disk" was wrong: the file
  is at `docs/sjira/v26.10.7/plans/w984gm-census-witness.md` (v26.10.**7**, not
  v26.10.6 as W984hg evidently assumed), byte-identical to the `56615dc3`
  version, with the witnessed census (1388 passed / 0 failed / 1 excluded @
  `102c1782`) intact. No restore needed.
- **Remaining coordinator/operator blockers (unchanged):** merge of
  `feat/playwright-surface` to `main` + the ash_pplan tag decision.
- **Carried from W984gn, unchanged:** W984ee court file
  (`test/xaas/compat/otp29_map_update_court_test.exs`) uncommitted / no `w984fo`
  receipt; ~100 `_build-lane*` roots pending osx-clnr classifier-r6 sweep.

## Landing addendum — 2026-10-07 (lane W984jg)

Fifth dated landing addendum, following the W984ef/W984ft/W984gn/W984hs
conventions. Verified per-commit on `feat/playwright-surface` (`git log
--oneline -25` re-run at addendum time; HEAD = `3961c4ab`, no commits newer
than `3961c4ab` found). Covers everything since W984hs's stated boundary
(`009bd057`): landing batch #8 (W984hm) + the W984hx W984fx trio landing.
Each row: real `git show --stat` + receipt grep (`grep -rl <sha> docs/sjira/`)
on disk at addendum time.

| SHA | Landing | Paths | Court result | Receipt |
|---|---|---|---|---|
| `58cd87b9` | W984hm landing batch #8 — four family courts from finished lanes | `test/xaas/actuation/validations_court_w984gw_test.exs` (+357), `test/xaas/operations/audit_log_court_w984go_test.exs` (+132), `test/xaas/workbench/family_court_w984gs_test.exs` (+132), `test/xaas/accounts/family_court_w984gx_test.exs` (+193) + w984go/gs/gw/gx probes (8 files, +1074) | courts carried green from owner lanes (per batch receipt: 27+5+16+7 = 55 passed, 0 failed) | `docs/sjira/v26.10.7/plans/w984hm-commit.md` (cites `58cd87b9`; also `w984it-recensus.md`, `_COMMIT_MANIFEST.md`) |
| `68073d8d` | W984hm batch #8 — W984gt pin rotations + drift-map zeroing + W984hd receipt | `docs/cro/artifacts/airo-wiring-ledger.md` (6 fleet pin rotations, spot-checked ash_atlassian `0e210efb` / ash_dspy `e3dcc4fa`), `test/xaas/airo/airo_pin_court_test.exs` (+189), `test/xaas/airo/pin_drift_test.exs` (`@receipted_drift` zeroed), `docs/sjira/v26.10.6/plans/w984gt-airo-pins.md`, `w984hd-repin.md` (6 files, +485/−6) | `test/xaas/airo/` block 9 passed, 0 failed (per batch receipt) | `docs/sjira/v26.10.7/plans/w984hm-commit.md` (sole citing receipt; `w984hd-repin.md` self-carried) |
| `82f7f558` | W984hm landing batch #8 lane commit receipt | `docs/sjira/v26.10.7/plans/w984hm-commit.md` (+36, docs-only) | docs-only; batch gates: mock gate `[]` exit 0; push fetch-first fast-forward `009bd057..68073d8d`, no force | **self-carried; third-party citations: w984hy/hw/hz/ij/if probes + `w984ia-audit-witness.md` + `_COMMIT_MANIFEST.md` all cite `82f7f558` only as the receipt path's owning commit context, none as third-party verification of this SHA** |
| `fc2adcb0` | W984hx — W984fx library-circulation AIRo RiskControl trio | `lib/xaas/semantics/airo_risk_mapping.ex` (+8), `test/xaas/semantics/airo_risk_mapping_depth_test.exs` (+42), `docs/cro/artifacts/airo-wiring-ledger.md` (+12, W984fx section), `docs/sjira/v26.10.6/plans/w984fx-probe.md` (4 files, +140) | depth court landed with the mapping (per `w984hx-commit.md`); push fetch-first fast-forward `82f7f558..fc2adcb0` | `docs/sjira/v26.10.7/plans/w984hx-commit.md` (cites `fc2adcb0`; also `w984it-recensus.md`, `w984cj-coverage-map.md`, `_COMMIT_MANIFEST.md`) |
| `3961c4ab` | W984hx lane commit receipt for the W984fx trio | `docs/sjira/v26.10.7/plans/w984hx-commit.md` (+43, docs-only) | docs-only; `_build-laneW984hx` deleted at close (per receipt) | **self-carried; third-party citations: `w984it-recensus.md`, `w984iq-probe.md`, `w984iz-manifest.md`, `w984id-regen-witness.md`, `w984ir-remediation.md`, `_COMMIT_MANIFEST.md` (all cite it as HEAD/baseline, not as verification)** |

### Open items (updated from disk, disclosed)

- **W984ia + W984ir release-audit leg — PASS at current HEAD.**
  `docs/sjira/v26.10.7/plans/w984ir-remediation.md` on disk: the 2 stale
  literals W984ia witnessed in `plans/w650k-audit-remediation.md` hyphenated
  (4 table rows), then fresh-root `mix xaas.release_audit` →
  `XAAS_RELEASE_AUDIT ALIVE version=26.10.7 tracked_files=5375
  ash_resources=122`, **exit 0, zero findings**; audit courts 19/19 exit 0.
  Tag-precondition audit leg: **PASS**. Note: the remediation edit and
  `lib/mix/tasks/xaas.release_audit.ex` changes are UNCOMMITTED working-tree
  modifications at addendum time — coordinator owns the commit + post-commit
  audit re-run.
- **W984iz commit-manifest — STAGED (uncommitted), 63 rows, range fully
  pushed.** `docs/sjira/v26.10.6/plans/w984iz-manifest.md` on disk: range
  `5e03acf5..3961c4ab` = 63 commits; `git rev-parse HEAD
  origin/feat/playwright-surface` both `3961c4ab`; 9 group receipts
  test-f-checked 9/9 OK; deliverable `docs/sjira/v26.10.7/_COMMIT_MANIFEST.md`
  is a new file in the working tree, awaiting coordinator commit. One
  disclosed row: `009bd057`'s receipt is on disk but the SHA itself is not
  grep-found anywhere.
- **Landing batch #9 (W984il) — IN FLIGHT, unreceipted.** `grep -rln w984il
  docs/sjira/` returns zero hits; no `w984il*` file exists under any
  `docs/sjira/*/plans/`. Status stays OPEN until the owning lane writes its
  receipt.
- **W984ee court file — RESOLVED (was carried open since W984ft).**
  `test/xaas/compat/otp29_map_update_court_test.exs` landed in `e49d7033`
  (W984gi batch #5); `git log -1 -- <path>` confirms, working tree clean for
  the path. No `w984fo` receipt was ever written; the restoration evidently
  happened via batch #5 instead. Retiring the carried flag.
- **Remaining blockers (unchanged):** coordinator merge of
  `feat/playwright-surface` to `main` + operator ash_pplan call.
- **Carried from W984hs, unchanged:** ~112 `_build-lane*` roots at repo root
  (re-counted this lane via `ls -d _build-lane* | wc -l`; W984hs said ~100)
  pending osx-clnr classifier-r6 sweep.
