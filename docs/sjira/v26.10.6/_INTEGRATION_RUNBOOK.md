# INTEGRATION RUNBOOK — v26.10.6 closure

Consolidated from every coordinator/operator handoff receipt. One canonical checkout
per repo; coordinator owns all git transitions; lanes never commit. Every command is
copy-executable; every item cites its receipt under `docs/sjira/v26.10.6/plans/`.

Precedence rule (w214 §W242): **W191 hazards > W225/W214 sequences > W153-v2 base**,
as amended by w334 (castle.ex sync-output caveat) and w354 (freshness).

Pre-flight: `git status --porcelain` fresh pull in ALL repos immediately before
executing — three receipts show count drift within one day (w214 C7, w354).

---

## 1. Commit sequences (in order)

### 1.0 Pre-G1 cleanup (cleanup law, BEFORE any commit)

Delete lane build roots — 17 across 3 repos (w354 §7):

```bash
rm -rf /Users/sac/xaas/_build-lane295 /Users/sac/xaas/W125 /Users/sac/xaas/W141 \
  /Users/sac/xaas/W177 /Users/sac/xaas/W212 /Users/sac/xaas/W248 /Users/sac/xaas/W316 \
  /Users/sac/xaas/W318 /Users/sac/xaas/W320 /Users/sac/xaas/W329 /Users/sac/xaas/W335 \
  /Users/sac/xaas/W347 /Users/sac/xaas/W349 /Users/sac/xaas/W350
rm -rf /Users/sac/ash_surface/_build-laneW326 /Users/sac/ash_surface/_build-laneW348
rm -rf /Users/sac/ggen_igniter/_build-laneW343
```

Also delete (w191 + w354): `/Users/sac/xaas/erl_crash.dump`,
`GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`.

Gate re-runs required at stage time (w214 gate table, before the relevant commit):
mock gate (`scan_mock_usage(["test","lib"])` → `[]`), ash-surface drift guard
(`mix test test/xaas/ash_surface_drift_guard_test.exs test/xaas/ash_surface_generator_test.exs`),
refusal negative courts (incl. batch6 + r2rml), Playwright (tokened, seeded).
All mix under `PATH=$HOME/.asdf/shims:$PATH`, `MIX_ENV=test` only (no dev compile — live phx).

### 1.1 xaas (repo order: LAST in dependency chain; G-groups per w214 as amended)

Coordinators follow w214 G1–G11 (split refinement supersedes w153-v2 X1; w214 C4/C5):

| # | group | message | ref |
|---|---|---|---|
| 1 | G1 deps: `mix.exs mix.lock` | `build(deps): pin v26.10.6 dependency set` | w214 G1, w153-v2 X1 |
| 2 | G2 release: `VERSION CHANGELOG.md README.md` | `chore(release): v26.10.6 version bump + changelog + README` | w214 G2 |
| 3 | G3 config: `config/{config,dev,test}.exs` | `chore(config): v26.10.6 config alignment` | w214 G3 |
| 4 | G4 CI: `.github/workflows/{ci_cd.yaml,playwright-e2e.yml}` | `ci: add playwright-e2e workflow, update ci_cd` | w214 G4 |
| 5 | G5 lib fixes (66 files — full add-list verbatim in w214 G5) | `fix(lib): v26.10.6 convergence — witness domain, ferroplan bridge, a2a parse floor, gymact surface, refusal codes` | w214 G5 |
| 6 | G6 generated (8 files) | `chore(generated): regenerate castle-bridge contract/edges/SHACL + ash_surface projection` | w214 G6 **amended**: run drift-guard gate first; see caveat below on castle.ex + shacl.ttl |
| 7 | G7 migration `20261006000000_repair_witness_certified_receipts.exs` | `fix(repo): repair witness certified_receipts migration` | w214 G7, w263 |
| 8 | G7b migration `20261006212508_add_w247_convergence_snapshots.exs` | `chore(repo): add W247 convergence snapshots migration (post-W258 dedup fix)` | w214 G7b/W263 |
| 9 | G8 scripts/courts/bench (6 files) | `chore(scripts): semantic replay task, substitution policy court, bench alignment` | w214 G8 |
| 10 | G9 tests (70 lines; full add-list verbatim in w214 G9) | `test: v26.10.6 convergence — refusal courts, witness/v1-protocol/ferroplan coverage, trimtab realignment` | w214 G9 |
| 11 | G10 e2e + playwright (22 lines) | `test(e2e): playwright surface — v1 protocol, witness, fabric, dev-routes specs; js→cjs rename` | w214 G10 |
| 12 | G11 docs/plans (24 lines, includes this runbook) | `docs: v26.10.6 diataxis reference updates, historical sjira receipts, W214 staging plan` | w214 G11 |

**castle.ex sync-output caveat (w334, BINDING):** stage `lib/xaas/castle.ex` in the
SYNC-OUTPUT version (`26839b9d…`), NOT the live-tree uncommitted version (`eac1e204…`).
w334's sufficiency verdict: the committed set must be exactly castle.ex (sync output) +
7 new generated files: `ggen.lock`*, `lib/xaas/generated/castle_bridge_{contract,edges}.ex`,
`priv/semantic/generated/castle_bridge_shacl.ttl`*, `test/xaas/generated/castle_bridge_contract_test.exs`,
`generated/castle_bridge/innovation.json`, `docs/claude/diataxis/reference/generated-castle-bridge-errc.md`.
(* = only with explicit coordinator admission of the castle-bridge pack-pin group,
per w214 conflict C1 / w191; otherwise both stay DO-NOT-COMMIT.)
Replay falsifier: fresh archive→hash→sync→hash in scratch must show empty diff post-commit (w334).

Post-commit verification (w153-v2): per-repo `git status --porcelain` sweep across all
10 repos; expected residue = only flagged/parked items (§2 below).

### 1.2 ferroplan — WP-B

- **w191 OVERRIDES w153-v2 §6b**: the wasm blob AND the 4 `.ggen-v2/` receipt files are
  DO-NOT-COMMIT (3.5 MB build artifact + checkout noise) — no ferroplan commit this cycle
  unless coordinator overrides w191 (w214 resolution rule; w225 resolved to W191).
- If coordinator admits the artifact chore anyway (per _CLOSURE_PLAN §3/w45):
  `git add crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` + the 4 `.ggen-v2/receipt*`
  files, message `chore(generated): refresh ferroplan-wasm registry artifact + ggen-v2 receipts`.
- Verify: `cargo test -p ferroplan-wasm --test pin_drift` → 7 pass (w45, _CLOSURE_PLAN WP-B).

### 1.3 zcode-cli — WP-C (18 files, one coherent commit)

`git status --porcelain` = 18 lines, staging intact (w354 §4). Two commits per w153-v2 §7:

- C1 `feat(max-turns): subagent max-turns config surface + expert-strategy config tests` —
  `src/max-turns.ts src/launcher.ts scripts/sync-runtime.ts test/max-turns.test.ts
  test/sync-runtime-anchor-drift.test.ts test/expert-strategy-config.test.ts test/fixtures/max-turns/`
- C2 `docs: configuration/host-integration/releasing/c4 doc closure` — `AGENTS.md HANDWRITTEN.md
  README.md docs/CONFIGURATION.md docs/CONFIGURATION.zh-CN.md docs/HOST_INTEGRATION.md
  docs/RELEASING.md docs/c4-zcode-cli-fabric.md` (per w153-v2 §7 C2 list)
- `artifacts/` NEVER committed (w191).
- Verify: `ZCODE_REQUIRE_TOOLCHAINS=1 bun test test/*.test.ts`; `shasum -a 256` both
  contracts (r7 G3, w46, w58; _CLOSURE_PLAN WP-C). Suite already 1072 pass (w58).

### 1.4 ggen — WP-D: bump head → merge to main → CI → OS-3 tag

- Local branch `feat/v26.10.5-release-cut` @ `000bffb8f` is 29 commits ahead of
  origin/main, on NO remote branch (w346 OS-3). Bump content verified:
  `Cargo.toml` 26.10.6, CHANGELOG `[26.10.6]` section present (w346).
- Sequence (w346 OS-3 verbatim):
  ```bash
  cd /Users/sac/ggen
  git push origin feat/v26.10.5-release-cut   # materialize the 29-commit head
  # merge to main (merge, never rebase/force)
  git checkout main && git pull && git merge --no-ff feat/v26.10.5-release-cut && git push origin main
  git log -1 --format='%h %s'   # must be a merge containing 000bffb8f
  gh run watch                   # CI green on new main head
  git tag -a v26.10.6 -m "v26.10.6 - v26.10.5 Convergence Closure"
  git push origin v26.10.6       # = OS-3 lift
  ```
- Non-ggen per-repo commits in dependency order (w153-v2 sequenced table, rows 1–8, 18;
  add-lists verbatim in that receipt): ggen-marketplace C1 (2 files) + C2 (3 files,
  pairs with parked ash_surface courts); ggen_igniter C1 (27, incl. pyc deletions) C2 (8)
  C3 (11) C4 (9); ash_pplan C1 (1) + W201-A1/A2/A3 (3, w153-v2 W201 delta); wasm4pm C1 (4).
- ash_a2a: only the 3 W201 commits; `docs/thesis/` parked (w191).
- ash_surface: w153-v2 §6 C1–C5; `doc/` DO-NOT-COMMIT (build output); 31 specimen courts +
  `fixture/` PARKED (w191/W246; `test/ash_surface/a2a_bridge_test.exs` is the EXCEPTION —
  commits with its module in C1); ash_surface `ggen.lock` DO-NOT-COMMIT.
- beam4pm: SKIPPED — split is OS-5 (operator) after WP-F qualification (w153-v2, _CLOSURE_PLAN §4).

### 1.5 gymact — WP-J (7 dirty files)

Dirty set is exactly 7 (w373): `CHANGELOG.md README.md docs/reference.md pyproject.toml
src/gymact/__init__.py src/gymact/gyms/ggen.py src/gymact/surfaces/fastapi.py`.
Version coherence ALREADY holds at 26.10.6 everywhere (w373 NO-OP on version strings).

```bash
git add pyproject.toml src/gymact/__init__.py CHANGELOG.md README.md docs/reference.md \
  src/gymact/gyms/ggen.py src/gymact/surfaces/fastapi.py
git commit -F <msg-file>   # feat(gyms): ggen/fastapi surface updates + v26.10.6 version closure
```
Verify: `.venv/bin/python -m pytest tests/test_production_surfaces.py tests/test_surfaces_sota.py -q`
→ 4 passed (w373). No tags exist in gymact; date-based 26.x.y convention (w373).

### 1.6 ash_surface — C-fixtures + C′/C″ tests (closure-only residue)

- C-fixtures: per _CLOSURE_PLAN §2, `fixture/burn_in/` stays PARKED with the specimen
  courts (W246 verdict); the C-family items are tests only.
- **C′ (standing-evidence adversarial fixture)** and **C″ (200/503 HTTP mapping fixture)**:
  two small test additions in `/Users/sac/ash_surface/test/…` per _CLOSURE_PLAN §4 P1-4;
  verify with `mix test` in ash_surface. Both remain open as typed small additions —
  they are the ONLY permitted ash_surface test work beyond w153-v2 C4's already-staged
  `test/ash_surface/` realignment.
- Coordinator still owes conflict C2 resolution: `fixture/burn_in/` commit-alone (w191
  rationale) vs parked-with-courts (w225/W246) — W246 verdict PARK is the standing ruling.

---

## 2. Do-not-commit / delete lists

### Never commit (xaas)

| path | why | receipt |
|---|---|---|
| `ggen.lock` | same-day sync lockfile; commit only via explicit coordinator admission of the castle-bridge pack-pin group | w191, w214 C1, w153-v2 W204 |
| `GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt` | lane scratch → DELETE | w191, w354 §6, _CLOSURE_PLAN §3 |
| `erl_crash.dump` | crash dump → DELETE | _CLOSURE_PLAN §3, w354 §6 |
| `.clap-noun-verb/` (`ocel.json`, `receipts.jsonl`) | same-day scratch | w191, w334 |
| `.ggen_igniter/receipts/2026-10-06.jsonl` | same-day receipt log | w191 |
| `.ggen/keys/` | sync side artifacts — **`.ggen/keys/signing.key` is a SIGNING KEY, NEVER commit**; recommend gitignore (coordinator decision) | w334 |
| `priv/semantic/generated/castle_bridge_shacl.ttl` | commit ONLY inside the admitted pack-pin group (C1 resolution); otherwise excluded | w214 C1, w191 |

### Never commit (other repos)

| repo | path | why | receipt |
|---|---|---|---|
| zcode-cli | `artifacts/` | same-day agent scratch | w191 |
| ash_surface | `doc/` | exdoc build output (139 entries) | w191 |
| ash_surface | `ggen.lock` | runtime residue | w153-v2 flag table |
| ash_surface | 31 specimen courts + `fixture/` | PARKED, ownerless (list verbatim in w191) | w191, W246 |
| ash_a2a | `docs/thesis/` | ownerless | w191 |
| ferroplan | `crates/ferroplan-wasm/registry/ferroplan_wasm.wasm` + 4 `.ggen-v2/receipt*` | build artifact + checkout noise (unless coordinator overrides w191 per §1.2) | w191 |
| beam4pm | whole repo | SKIPPED / OS-5 | w153-v2, r9 |

### Delete (coordinator executes at integration, BEFORE final commit)

- 17 lane build roots (§1.0 list) — w354 §7 supersedes w191's shorter list.
- `GGEN-SH-AFTER-MIX-COMPILE.log`, `GGEN-SH-AFTER-PROOF.txt`, `erl_crash.dump` — w354 §6.
- w334 scratch: `rm -rf /tmp/w334-scratch /tmp/w334-{before,after}.{txt,log}` per w334 Cleanup.

---

## 3. OS register quick-lift card

| OS | Lift | Command / decision | receipt |
|---|---|---|---|
| OS-2 | zcode-cli main version bump | one-line `package.json` `"3.14.3-1"` → `"3.14.4-33"` on `main` (one greater than npm latest; passes `compareReleaseVersions`). Verify with manual `workflow_dispatch` (kind=upstream) before the next 01:30 scheduled run. Do NOT patch the guard. | w346 OS-2, w40 |
| OS-3 | ggen tag | §1.4 sequence: push → merge to main → `gh run watch` green → `git tag -a v26.10.6` → `git push origin v26.10.6`. BLOCKED until WP-D bump lands on main. | w346 OS-3 |
| OS-4 | ggen_igniter ship-scope | operator decides hex ship scope for promoted `priv/ggen/ash-manufacture-pack`: whole pack vs ontology/gates/templates/verify only (r3 E3/R-5). Unblocks WP-G final layout. | _CLOSURE_PLAN §4 OS-4, r3 |
| OS-5 | beam4pm split | approve/sequence r9 C1→C7 commit groups (incl. C6 `receipts/engine_ops` untrack) after WP-F OTP-29 qualification. | _CLOSURE_PLAN §4 OS-5, r9, w52, w74 |
| OS-6 | frozen ggen pin v26.8.11 | USER-ONLY gate (`BLOCKED:pin-bump-user-gated`). Staged procedure at `ggen-marketplace:docs/context/ggen-pin-bump.pending.md`. No lane may edit the pin. | w346 OS-6, r2 §4.4 |
| OS-12 | ash_onetime `logical_partition` | sanctioned migration (both DBs): `PATH=$HOME/.asdf/shims:$PATH mix ash_onetime.gen.logical_partitions --repo Xaas.Repo` then `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix ecto.migrate`; then `MIX_ENV=test mix test test/xaas/accounts/token_revocation_test.exs` (first call passes, repeat must fail `:nonce_already_used`). **Doctor preflight**: `mix ash_onetime.doctor --live` (v1.2.0 schema-currency check; names the failure instead of cryptic `:store_invariant`) — run before migrate and consider pinning in CI. NOT test-only: `xaas_dev` has the same stale schema. Open sub-item (b): jti PK collision design decision (operator). NOTE: plan w363-ash-onetime-doctor.md does NOT exist on disk; the doctor preflight is specified inside w333 §2. | w333 (§§1–4) |
| OS-13 | pack markers / cache mirror | (1) TTL snippets: add `aex:fixtureOnly true ;` after the subject line for `aex:AshR2RMLSpec` and `aex:NotificationExtensionSpec` in the CACHE clone `/Users/sac/ash_surface/.ggen-v2/git-packs/ash-extension/packs/ash-extension-pack/ontology.ttl` (AuditTrailSpec already marked there — do NOT duplicate). (2) Re-run W126 mirror discipline: edit cache clone → `ggen sync run` (expect `written: []`, all `skipped: unchanged`) → quarantine remaining strays (`lib/audit_trail/`, `lib/notification_extension/`, 3 × `lib/mix/tasks/*.install.ex`). (3) LIVE quarantine exists at `/tmp/os13-quarantine-20261006-165326` (non-durable); durable snapshot under `docs/sjira/v26.10.6/plans/os13-quarantine-snapshot/`. (4) Durable next-cycle fix: commit marketplace wt (all 4 markers + gate-120 fix @93895f8), advance ash_surface pin past `3ddbfeb7`, delete cache-mirror dependence. Falsifier: per-individual `grep -c "fixtureOnly true"` must stay exactly 1. | w355, _CLOSURE_PLAN §4 OS-13, w230, w126 |
| OS-14 | Art. 12(3) authority-export surface | v26.10.7 NEW FEATURE: operator-facing export of refusal/authority receipts. | _CLOSURE_PLAN §4 OS-14, w319 |
| OS-15 | Art. 14(4)(e) bias-awareness doc-class | v26.10.7 DOC-CLASS work. | _CLOSURE_PLAN §4 OS-15, w319 |
| OS-16 | Art. 50 end-user disclosure | v26.10.7 NEW FEATURE: AI-interaction disclosure surface. | _CLOSURE_PLAN §4 OS-16, w319 |

Also standing (register, not lifted here): OS-1 auth-stacking decision (r4 §7),
OS-7 ash_surface path-dep → versioned, OS-8 plugin cache reinstall consent,
OS-9 GC23 court redesign (law_evolution, v26.10.7+), OS-10 gymact DCM-018
standing-feedback (v26.10.7+), OS-11 permission-bit watch item (no recurrence per w365).

---

## 4. Final verification replay card (post-integration)

All under `PATH=$HOME/.asdf/shims:$PATH`; `MIX_ENV=test` only (no dev compile — live phx
per repo CLAUDE.md / memory). Server tokened for PW.

```bash
# 1. Full test suite (DoD 1) — with INTERNAL_API_TOKEN exported
MIX_ENV=test mix test

# 2. Mock gate (expect [])
mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'

# 3. Sync drift gates (DoD 4) — both must be empty-diff
ggen sync run && git diff --exit-code                     # root manifest drift
mix xaas.ash_surface && git diff --exit-code priv/ash_surface   # ash_surface projection drift

# 4. Full Playwright, tokened (DoD 5 browser rung) — server booted with INTERNAL_API_TOKEN, seeded
mix run e2e/seed-witness.exs
PW_PORT=<port> INTERNAL_API_TOKEN=<real-token> npx playwright test   # all spec files, no 0-tests

# 5. Strict compiles ×2 (DoD 2)
MIX_ENV=test mix compile --warnings-as-errors
MIX_ENV=prod mix compile --warnings-as-errors
```

Success criteria: (1) green incl. un-ignored bounded suites, zero skips in completed
files; (2) `[]`; (3) both `git diff --exit-code` exit 0 (castle-bridge + ash_surface
projections byte-stable at the committed head); (4) all collected specs green against
tokened server; (5) both strict compiles exit 0. Plus residue sweep: per-repo
`git status --porcelain` shows only §2 flagged/parked items, and no `_build-lane*`,
`GGEN-SH-*`, `erl_crash.dump` anywhere (DoD 4 residue legs).

---

## Runbook standing

PLAN-ONLY consolidation (lane W384): no git mutations, no deletions executed. Sole write
is this file. Falsifier: any step above diverging from its cited receipt at execution
time — the receipt wins; re-pull fresh porcelain first (w214 C7).

## W399 amendments (2026-10-06, live-porcelain freshness check)

Supersedes the group lists above where they differ; live porcelain = 238 lines.

- **G5 +4**: lib/xaas/vault.ex (OS-17 guard, w394-class lib safety fix),
  lib/xaas/ultracode/autonomic.ex, lib/xaas_web/live/chicago/seller_live.ex,
  lib/xaas_web/a2a/v1_transport_plug.ex (pairs with a2a_parse_floor.ex).
- **G6/G7c +8**: priv/resource_snapshots/repo/* (W247 family — fold into G6 or
  a new G7c snapshot commit beside G7b).
- **G9 +10**: test/xaas/vault_env_guard_test.exs, test/xaas/receipt/r_projection_test.exs
  (w369 conversion), test/mix/tasks/xaas_self_digest_test.exs,
  test/xaas_web/a2a/v1_sse_test.exs, test/xaas_web/execution_fabric_controller_test.exs,
  test/xaas/chicago/presence_pin_test.exs (w359), + 3 ultracode tests
  (autonomic_profile_sense, machine_experience, semantic_drive).
- **G11 +4**: docs/claude/diataxis/README.md + the 3 corrected how-to pages
  (w376 corrections applied 2026-10-06).
- **G4 (decision)**: .github/workflows/closure-gates.yml stays OUT until the
  GGEN_SHA-vs-ggen.lock question (w327) is resolved; add only on coordinator admission.
- **castle.ex caveat (§1.1)**: the staged SYNC-OUTPUT copies live at
  docs/sjira/v26.10.6/plans/w390-sync-output-staging/ (8 files, digest-match
  verified twice, w390). DECISION PRE-G11: delete the staging dir before the docs
  commit, or explicitly admit it under docs/ — do not let G11 sweep it in silently.
- Correction to W392's report: its claimed pplan.ex:98 compile failure does NOT
  reproduce at HEAD (strict compile shows only the known dep-class warnings;
  w315's 3235/0 stands) — scratch-overlay artifact, not a tree defect.

## W458 addendum (2026-10-06, slice-witness wave)

Every path below `test -f`-verified before citation (lane W458, 2026-10-06).
All slice receipts live under `docs/sjira/v26.10.6/plans/`.

### Per-directory slice witnesses on file

| lane | slice | receipt | result | notes |
|---|---|---|---|---|
| W429 | marketplace | `w429-marketplace-slice.md` | 23 passed / 0 failed / 0 skipped, exit 0 | non-stress 4-file run; documents the lawful `:actuate_status` + `xaas_actuation` context idiom (test/xaas/marketplace/approval_provider_status_change_provider_org_matches_test.exs:34-52) |
| W432 | telemetry | `w432-telemetry-slice.md` | 33 passed / 0 failed, exit 0 | matches w197-era 33/0 baseline |
| W433 | operations | `w433-operations-slice.md` | 49 passed / 5 excluded (`requires_cnv_deploy`, W412 scope), 0 failed | w440 also lists `_build-laneW437` as ACTIVE — fabric lane ran but its receipt did not land |
| W434 | witness | `w434-witness-slice.md` | 9 passed / 0 failed, exit 0 | algorithm census: ES256 + ML-DSA-65 (hybrid) exercised; ES256+ML-DSA-65 / SLH-DSA-SHA2-128s rejected via `:algorithm_not_in_admitted_enum`; ed25519 negative-only; no BLAKE3 anywhere in the witness test tree; SHA-256 content-hash/subject-prefix only |
| W435 | chicago | `w435-chicago-slice.md` | 152 passed / 0 failed, exit 0 | +2 vs w154-era 150/0 (seller un-skip per w399 G5) |
| W436 | mix-tasks | `w436-mixtasks-slice.md` | 48 passed / 1 skipped / 15 excluded, 0 failed | covers test/mix/tasks/ incl. xaas_self_digest_test.exs (w399 G9) |
| W437 | fabric | — | **IN-FLIGHT** — receipt ABSENT (`test -f w437-fabric-slice.md` fails); `_build-laneW437` is ACTIVE in w440 | cite real numbers only when the receipt lands |
| W442 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W443 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W445 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W446 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W447 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W453 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W454 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W455 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W456 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |
| W457 | (unfiled) | — | **IN-FLIGHT** — receipt ABSENT | |

Slice-wave subtotal (receipted, zero failures): 23 + 33 + 49 + 9 + 152 + 48 = 314 passed,
0 failed across six filed slices; W436's 1 skip and W433's 5 excludes are the only
non-pass outcomes, both accounted for in their receipts.

### Browser rung

- `w438-pw-final-quiet.md` — full PW run **94 passed / 2 failed / 2 skipped** (98 listed,
  1.8m): the 2 failures are the pre-existing CapabilityLivenessReceipt admin-UI ingest
  regression w391 isolated (byte-identical identity/signature), not new drift.
- `w449-ash-admin-independent.md` — **FIX-VERIFIED 2 passed / 0 failed**: the same two
  ash-admin specs green against W394's on-disk fix. Expected end state: a single clean
  full-suite rerun receipt (W452's scope). **W452: IN-FLIGHT — receipt ABSENT**
  (`test -f` fails); until it lands, the browser rung stands at w438 94/2/2 + w449 2/0.
- Skip pair is the STRIPE_WEBHOOK_SECRET-pair (w381), unchanged.

### Admin-ingest regression: RESOLVED

W394's on-disk, uncommitted fix in `lib/xaas/operations/capability_liveness_receipt.ex`
(mtime Oct 6 11:35) replaces the `authorize?: false` ingest exception with a scoped Ash
bypass — `bypass action(:ingest) do authorize_if({Xaas.Checks.SystemActor, service:
:oban_scheduler}) end` (lines 91/101 region) — deny floor intact for all other actors,
`:destroy` still forbidden. Independently verified by W449 (2/0). The fix file is already
in the w214 G5 lib add-list; it stays in **G5** and must be committed with that group —
no separate commit.

### Cleanup

`w440-cleanup-manifest.md` is the authoritative delete list: **50 READY-TO-DELETE items
≈ 18.9–19.0 GB** (28 xaas lane roots 12.7 GiB + 11 sibling-repo roots 3.5 GiB + 9 /tmp
items 2.7 GiB + 2 repo-root scratch files). ACTIVE roots (~5.2 GB, incl. `_build-laneW394`
and `_build-laneW437`) are excluded from the delete list until their lanes land;
`erl_crash.dump` delete only after w444 classification. Supersedes the shorter §1.0/§2
delete lists where they overlap; deletion is a coordinator transition (plan→approve→
delete with APFS snapshot thinning per cleanup law).

### W458 standing

Lane W458: sole write is this addendum (append-only; existing text above untouched).
All receipts cited were existence-verified (`test -f`) 2026-10-06. Falsifier: any
IN-FLIGHT marker above is retired by a coordinator re-check once the named receipt
lands under `docs/sjira/v26.10.6/plans/`.

### W460 correction (2026-10-06, superseding the W458 addendum's admin-ingest line)

W394's final diagnosis REFUTES the policy hypothesis: AshAdmin 1.3.2 form
submissions run with `authorize?: socket.assigns[:authorizing]` defaulting
false — the `:ingest` policy never gates the admin UI, and no admin bypass
was needed (none was added; the capability_liveness_receipt.ex policy remains
as w337/w338 landed it). The real regression is a LiveView hydration race in
the two specs (Save clicked ~1s after New, before `phx-submit` wires; w394
measured 1/5 persisted raw, 5/5 with settle wait). Fix = settle-wait lines in
e2e/ash-admin-destroy.spec.cjs + e2e/ash-admin-state-change.spec.cjs
(w460, in flight — 6/6 stability runs required). No lib/ change for this
item; G5 grouping of capability_liveness_receipt.ex stands for its own
w337-era policy work, unrelated to the specs.

### W461 addendum (2026-10-06, fleet-contention taxonomy)
Lane W461: sole write is this addendum (append-only). Sources: w297d lane findings
(load avg 77-82 under ~20 concurrent lanes, cross-lane castle CLI lock ping-pong,
orphaned beams), w398b isolate-twice protocol, w438 (94/2/2 quiet-machine baseline),
w316 kill note. All on-disk-verified 2026-10-06.

**(a) Postgres sandbox timeouts** under concurrent suites — checkout-timeout/ownership
failures that vanish on a quiet machine; never classify as a real regression without
isolate-twice.
**(b) Castle kernel CLI subprocess overlap** — multiple lanes each spawning the castle
kernel ping-pong the same CLI. FIXED by w297d: `with_castle_lock/1` in
`test/xaas/castle_refusal_negative_test.exs` (exclusive-create /tmp file-lock spin
mutex, real OS lock not a test double); lock path overridable at runtime via
`XAAS_CASTLE_TEST_LOCK` for isolated verification.
**(c) Shared `_build/test` write races** — concurrent mix invocations corrupt shared
compile state. MITIGATED by w297d's per-invocation APFS-cloned `MIX_BUILD_ROOT`
pattern (`cp -c` clone, deleted on exit); adopt for ANY nested mix invocation.
**(d) LiveView hydration races in PW specs** — Save clicked before `phx-submit`
wires (w394 measured 1/5 persisted raw vs 5/5 with settle wait). FIXED by w460
settle-wait lines in the two ash-admin specs (6/6 stability runs required).
**(e) fd-closure beam death** — w444 classified the `erl_crash.dump` class BENIGN;
delete the dump only after final verification per w440 cleanup manifest.

**Replay protocol (coordinator final verification)**: run heavy suites SERIALLY or
on a quiet machine (<10 load; current load 80.5 as of 2026-10-06 18:18). Any
failure → isolate-twice before classifying real: (1) rerun the failing test
alone under a unique `MIX_BUILD_ROOT`; (2) if it persists, rerun with
`XAAS_CASTLE_TEST_LOCK` pointed at a private lock. Only then file as real.
Worked examples: w398b (isolate-twice classification), w297d (lock + build-root
mitigations), w414 (empty-bearer kill executed under contention).

**Load-shedding note**: at load 77-82 with ~20 lanes, sandbox timeouts (a) and
build races (c) dominate residuals. The §Verification replay card must be
executed at <10 load — a replay receipt minted at load >50 is not admissible as
ALIVE evidence for contention-sensitive suites (a)/(c).
