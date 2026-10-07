# W694 — OS Register Re-derivation (lane receipt)

- Subject: xaas @ feat/playwright-surface, HEAD a0723bf6 (+ uncommitted lane build), repo /Users/sac/xaas
- Task: re-derive every OS register entry (§4, OS-1..OS-21) from cited receipts + current tree, not register prose.
- Method: file existence, grep of cited atoms, receipt tails. No test execution. No register edits (`_CLOSURE_PLAN.md` untouched).

## Per-OS table

| OS | Register claim | Re-derived status | Evidence (file:line) | Gap / flag |
|----|----------------|-------------------|----------------------|------------|
| OS-1 | Strict preflight: decide auth stacking before mount edit admitted | **STALE** — decision was made and the mount LANDED | `lib/xaas_web/router.ex:202-228`: `/a2a` scope with `:require_internal_api_token` as single auth floor, "AshA2A's own Plug.Auth is left unconfigured", citing W10's stacked-auth analysis; W305 seam mounts owned V1TransportPlug; `e2e/a2a-v1.spec.cjs` on disk; r4 = `plans/r4-a2a.md` | Register row still lists OS-1 as an open operator decision; `w323-dod7-provenance.md:283` ("auth stacking decision still open") is stale too |
| OS-2 | Bump ~/zcode-cli main past npm latest 3.14.4-32 | **OPERATOR_GATED** — not done | `~/zcode-cli/package.json:3` = `3.14.3-1`, 19 dirty files; `plans/w40-zcode-release-workflow.md:40-46` (npm latest = 3.14.4-32) | Local checkout (3.14.3-1) disagrees with w40's "origin/main is 3.14.4-32" — local tree is not the bumped main; register otherwise accurate |
| OS-3 | Cut ggen tag v26.10.6 after CI green | **OPERATOR_GATED** — tag absent | `git -C ~/ggen tag -l 'v26.10*'` → v26.10.0, v26.10.5, v26.10.5-3-gbc4d23909 only | none |
| OS-4 | ggen_igniter hex ship scope for promoted pack | **OPERATOR_GATED** — decision open | Pack promoted on disk: `~/ggen_igniter/priv/ggen/ash-manufacture-pack/` (bin/gates/ontology.ttl/templates/verify present) | none |
| OS-5 | Approve/sequence r9 C1→C7 splits | **OPERATOR_GATED** — not done | `git -C ~/beam4pm status --porcelain` = **2,576** dirty entries; `plans/r9-beam4pm.md` + `w52-beam4pm-qualification.md` on disk | Register's 2,462 count is stale (now 2,576) |
| OS-6 | Frozen ggen pin v26.8.11@402cecdf, user-gated | **OPERATOR_GATED** (pin unverifiable beyond absence) | Grep for `402cecdf`/`v26.8.11` in `~/ggen-marketplace/marketplace.active.toml`: 0 hits | Could not locate the pin string's live location; absence consistent with unchanged user-gated state |
| OS-7 | Convert xaas ash_surface path dep to versioned | **OPERATOR_GATED** — still a path dep | `mix.exs:115` `{:ash_surface, path: "../ash_surface"}` | none |
| OS-8 | Plugin cache reinstall (host-state mutation) | **OPERATOR_GATED** — consent open | `~/.zcode/cli/plugins/cache/zcode-plugins-official/` exists (android-emulator, browser-use, …) | none |
| OS-9 | BLOCKED(law_evolution) GC23 court redesign | **BLOCKED (register-consistent)** | `docs/sjira/v26.9.23/courts/GC23-0.sh`… on disk; `plans/w133b-compile-prose-stop.md`, `w128-oracle-final.md`, `w107-schema-drift.md` all exist | The plan's own evidence-link audit (lines ~311-319) claims w133b/w128 receipts "do not exist" — both exist under plans/; that audit note is the stale part. 52/56 court status not re-run (out of lane scope) |
| OS-10 | BLOCKED(new-code) gymact DCM-018 | **BLOCKED (register-consistent)** | `plans/w129-gymact-crown.md:27` receipt_id `adae920dffff40f3aab590db9a2abacf` ALIVE; :43 close-requirements list | none |
| OS-11 | Fleet permission-bit stripping, watch item | **OPERATOR (watch)** — register-consistent | `plans/w365-toolchain-coherence.md` + `w91-permission-sweep.md` on disk; no new unreadable-dir receipt | none |
| OS-12 | Token-revocation disclosures (a)(b) | **OPERATOR_GATED** — register-consistent | `test/xaas/accounts/token_revocation_test.exs:17-28,86` carries the full store_invariant + jti-PK disclosures | "W183 findings" still has no w183* receipt file (plan's own audit already flags this) |
| OS-13 | ash_extension_pack installer re-emission, pack-side fix open | **OPERATOR_GATED** — register-consistent | `plans/w230-r2rml-skew.md` + `w126-pack-gate-fix.md` on disk; `~/ash_surface/lib` currently holds only ash_surface/mix — no shadowing installer products right now | Durable pack-side fix (fixtureOnly extension or consumer-mode sync flag) still absent from marketplace packs |
| OS-14 | Art. 12(3) export endpoint LANDED (W620) | **LANDED** | `lib/xaas_web/router.ex:98` `get("/eu-ai-act/pack", …)`; `lib/xaas_web/controllers/eu_ai_act_export_controller.ex`; `test/xaas_web/eu_ai_act_export_controller_test.exs`; `plans/w620-os14-export-endpoint.md` | none |
| OS-15 | Art. 14(4)(e) doc-class CLOSED | **LANDED** (receipt-file gap) | `docs/cro/artifacts/bias-awareness-measures-v26.10.6.md` exists, grounded (typed limitations incl. NO_DEMOGRAPHIC_BIAS_DETECTION) | No `w423*` receipt file exists anywhere under docs/ — the cited receipt is missing; only the artifact doc witnesses the closure |
| OS-16 | Typed GAP, no end-user disclosure, v26.10.7+ | **STALE (underclaim)** — Art 50(1)/(2) marking landed on this lane build | `plans/w665-art50-deepening.md` standing: "Art. 50(1)/(2) marking … ALIVE (7/7 witnessed on feat/playwright-surface @ lane build; uncommitted, coordinator integration pending)"; `test/eu_ai_act/art50_deepening_test.exs` on disk; W547 already flipped 50.2 EVIDENCED (plan line 403) | The end-user-facing disclosure surface itself is still absent, so the row is partially right; row body not refreshed for W665/W547. Residual: emotion-recognition gate is conjunctive-only (technique-atom refusal = impl change if wanted) |
| OS-17 | CLOAK_KEY prod guard FIXED | **LANDED** | `lib/xaas/vault.ex:31` `{:stop, {:cloak_key_missing, :prod_refuses_placeholder_key}}`; CHANGELOG.md:60-63; `plans/w349-cloak-key-guard.md` + `w393-cloak-prod-wiring.md` | none |
| OS-18 | checkpoint_external identity clause FIXED (W546) | **LANDED** | `lib/xaas/actuation.ex:569` `{:error, :external_admission_identity_mismatch}`; witness `test/xaas/actuation_refusal_negative_test.exs:195,218`; `plans/w546-os18-fix.md` + `w379-actuation-kill.md` | none |
| OS-19 | Stale 26.8.21 @version pin; fix = one-liner, "v26.10.7 candidate or coordinator one-liner" | **LANDED** — row body STALE (underclaim) | `lib/mix/tasks/xaas.release_audit.ex:14` = `@version File.read!("VERSION") |> String.trim()` — the exact proposed fix is in the tree; `plans/w600-os19-fix.md` on disk; trailing W600 note (row 274) documents landing + residual drift | Row body still reads as unfixed; only the appended W600 note corrects it. Residuals (operator/v26.10.7): kanban_web router.ex drift typing; `check_rpc_alignment` File.read! fail-crash |
| OS-20 | OTP-29 Map.update sweep, ~80% closure | **IN_FLIGHT / OPERATOR_GATED** — 61/61 sites patched, 3/4 repos committed | `plans/w525d-map-update-sweep.md`, `w657-os20-refresh.md`, `w664b-os20-consolidation2.md` on disk; xaas test files `test/xaas/map_update_dual_safe_test.exs`, `test/xaas/w705_map_update_dual_safe_test.exs`, `test/xaas/semantics/map_update_dual_safe_test.exs` exist | Remaining (per w664b): ash_pplan §6 suite capture (W603 §6 placeholder, W610 load-gated); coordinator commits for beam4pm (2,576 dirty) + xaas tree; beam4pm `bpm:HandAuthoredSource` admission for w601 test file |
| OS-21 | 4 adversarial escape classes raise instead of ⊥; fuzz suite should assert | **LANDED on lane build (UNCOMMITTED)** — row body STALE | Catch-alls on disk: `lib/xaas/semantics/robust_margin.ex:51,65,106,120` try/rescue; `lib/xaas/semantics/dataset_admission.ex:66`; `lib/xaas/semantics/eu_ai_act_admission.ex:201-205`; fuzz asserts typed handling: `test/xaas/semantics/admission_fuzz_test.exs:13` ("Former non-totality escapes — now FIXED and asserted (lane W630)"), :228 (`:REFUSED_ARITHMETIC_OVERFLOW`) | Register row still describes all 4 escape classes as open; whole fix set uncommitted (git status: robust_margin.ex, dataset_admission/jcs/counterfactual/title_iii tests modified) |

## Totals

- **LANDED**: 6 — OS-14, OS-15, OS-17, OS-18, OS-19, OS-21 (OS-16 partially; OS-19/OS-21 landings are on the uncommitted lane build where noted)
- **STALE (register prose contradicted by tree)**: 2 — OS-1, OS-16; plus stale row bodies on OS-19 and OS-21 (fix landed, row reads unfixed)
- **IN_FLIGHT / OPERATOR_GATED**: 1 — OS-20
- **OPERATOR_GATED (register-accurate)**: 9 — OS-2, OS-3, OS-4, OS-5, OS-6, OS-7, OS-8, OS-12, OS-13
- **BLOCKED, register-consistent**: 2 — OS-9, OS-10
- **Watch**: 1 — OS-11

## Overclaim flags (register says more than the tree supports)

1. **OS-1** — largest overclaim-in-reverse: register presents a decided-and-landed mount as an open operator decision.
2. **OS-19** — row body claims the fix is a future candidate; the exact one-liner is in the tree with a receipt.
3. **OS-21** — row body claims 4 live escape classes; catch-alls + asserting fuzz suite are on disk (uncommitted).
4. **OS-15** — closure cites a receipt (`w423`) that does not exist on disk.
5. **OS-5** — dirty count cited as 2,462; actual 2,576.
6. **OS-9** — the plan's own evidence-link audit wrongly claims w133b/w128 receipts are absent.

## Receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf6 + uncommitted lane build
- Checks run: file existence + grep only, no test execution, no commits, no register edits
- Deliverable: this file. Standing: PARTIAL_ALIVE — verdicts above are grep/existence-grade evidence, not witnessed test runs.
