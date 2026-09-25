# RELEASE-STATE-v26.9.17 — FOND predicate table (authoritative, wave-4 agent 8/8)

Date: 2026-09-17 (assembled 12:06 local). Domain: `sa2a-v26-9-17` HDDL (paste archive
`/Users/sac/.zcode/tmp/paste-attachments/2026-09-17/pasted-text-20260917-000929-66de71ad.txt`).
Context: ORIENT-v26.9.17.md (t1 heads), DESIGN.md (P0–P4 falsifiers).

## Receipt inventory (16 expected)

LANDED (15): boundary-ash-a2a, boundary-ash-r2rml, boundary-bcinr, boundary-ggen,
boundary-ggen-igniter, boundary-xaas, boundary-affidavit, boundary-beam4pm,
boundary-autofde-lab, hook-court, affidavit-issuance, ep2-replay, certify-prep,
ep1-driver, ep1-observer.
NOT LANDED at deadline (1): **ledger-closure.md** → every predicate only it could evidence
is UNKNOWN ("receipt not landed"); the release 比 (ratio) is UNKNOWN.

Honesty rule applied: a predicate is SATISFIED only with witnessed evidence in a receipt;
executor claims without observer confirmation are CLAIMED-UNVERIFIED; where executor and
observer both witnessed, both are cited. Raw-log observations are labeled as such and never
upgraded into classifications the owning agent did not make.

---

## a. FOND predicate table (all 44 domain predicates)

Status is RELEASE-SCOPE (what the operator reads to cut the release). Machinery = typed
machinery witnessed green in a passing suite; it does NOT by itself satisfy an episode-scoped
predicate. Counts at bottom.

| # | Predicate | Status | Evidence (receipt + exact command/exit/row) |
|---|-----------|--------|---------------------------------------------|
| 1 | `owns ?r ?c` | SATISFIED | problem `:init` 11 owned pairs; ORIENT table (9 critical boundaries each attempted by a named agent this wave) |
| 2 | `critical ?c` | SATISFIED | problem `:init` (9 critical caps); all 9 boundary receipts dispatched against exactly these |
| 3 | `qualified ?r ?c` | PARTIAL (7/9) | SATISFIED: ash_r2rml (boundary-ash-r2rml.md: `mix compile --force --warnings-as-errors`→0, `mix test`→0, 738 tests/0 fail/9 skip @ 7d958a8); bcinr (boundary-bcinr.md: `cargo test --workspace --all-targets --no-fail-fast`→0 + 3 targeted suites→0 @ f70999c0); ggen (boundary-ggen.md: full `just pre-commit` PRE-COMMIT EXIT=0, all 17 gates, at repaired head 5cc8808c1 — pinned head as-found BUILD_BROKEN); ggen_igniter (boundary-ggen-igniter.md: compile→0, `mix test` 932 tests/0 fail @ d018ed4); xaas (boundary-xaas.md: compile→0, `mix test` 648/0, `--only ultracode` 8/0, tripwires 30/0 @ fd68647); affidavit (boundary-affidavit.md: at repair tip 3106f64 fmt→0, 352 tests/0 fail, live `affi receipt verify`→0 ACCEPT — verification court only, see #6); beam4pm (boundary-beam4pm.md: `rebar3 eunit` 3100 pass, `mix test`+env contract 1108/0, targeted 41/0 @ ace23e5). NOT-SATISFIED: autofde-lab/cap-crown (boundary-autofde-lab.md: 12-gate runner 11/12, sole fail CHI-ID `ExactIdentityFenced` — court withholds qualified from untagged HEAD; certify-prep.md re-confirms at 156cb6fe). NOT-SATISFIED (receipt never closed): ash_a2a/cap-orchestration — boundary-ash-a2a.md ends "FOND classification (pending)"; RAW-LOG OBSERVATION (not a classification): /tmp/uzc/ash-a2a-court.log finished 11:49 local, `1912 tests, 49 failures, 8 invalid, 1 skipped (14 excluded)`, `MIX_TEST_EXIT:2` at re-pinned HEAD 801374a — court red as observed; no agent adjudication (env vs real) has landed |
| 4 | `build-broken ?r ?c` | SATISFIED (witnessed; current holdings named) | Witnessed true: ggen @ pinned 03ceb0df6 (boundary-ggen.md: fmt-check→1, guard-claims-schema→1, guard-pack-proofs→1 FM-PACK-008, guard-generation-hash-pin→1, guard-pack-count→1, guard-pack-e2e-coverage→1) — cleared by 5 commits on fix/ggen-v26.9.17-boundary; affidavit @ pinned 7f1caf6 (boundary-affidavit.md: `cargo fmt --all -- --check`→1, `--test e2e`→101 (5/5 FAILED), `--test cli_dispatch` FAILED (6/6), `cargo clippy --lib`→101 223 print_stdout convictions) — cleared at tip 3106f64; autofde-lab court-TYPES current HEAD BUILD_BROKEN (certify-prep.md: runner receipt `standing=BUILD_BROKEN`, CHI-ID FAIL, tag_sha=unreleased — adjudicated lawful-fence, see D5). Latent (NOT court failure, no repair sanctioned): ash_a2a `MIX_ENV=test mix compile --force --warnings-as-errors`→1, 36 domain-config-inclusion warnings, fresh-compile only (boundary-ash-a2a.md falsifier 1) |
| 5 | `blocked ?r ?c` | NOT-SATISFIED (no repo-capability binding holds) | No boundary receipt declares its repo/capability blocked. Episode-level BLOCKED witnessed separately: ep1-driver.md (standing BLOCKED, server dead) — not this predicate's shape |
| 6 | `unsupported ?r ?c` | SATISFIED (typed, ledgered) | `UNSUPPORTED(issue-affidavit, cryptographic-signature)` — boundary-affidavit.md: `handlers::sign` (src/handlers.rs:686-718) emits `"algorithm":"ed25519","status":"signed"` with NO cryptography; notarize/attest likewise structural; restated in-chain (affidavit-issuance.md evt-13) and in AFFIDAVIT.md. Evidence integrity = BLAKE3 chain tamper-evidence only |
| 7 | `heads-pinned v26-9-17` | SATISFIED | ORIENT-v26.9.17.md table (9 heads with branch/SHA/dirty). r1 movement witnessed and re-pinned: pinned 02d8616 → observed 801374a (3 commits, test fixtures + CHANGELOG only, `git rev-parse`→0), verification proceeded at 801374a (boundary-ash-a2a.md). Dirty trees preserved-not-stashed: xaas 15, beam4pm 17 (+5 test-emitted ERC-002 receipts by session end), autofde-lab 10, affidavit 2 (Cargo [patch] drift — load-bearing, see D4) |
| 8 | `world-reconstructed e1 sa2a-self-improvement` | SATISFIED (dual-witnessed) | ep1-driver.md: read-only DB survey 7 runs / 7 epochs / 40 receipts, graveyard finding (5 prior zcode runs, all epochs :missed, worktree=nil); worktree created `git worktree add /tmp/uzc/ep1-worktree -b feat/ep1-missed-epoch-receipt fd68647` RC=0. ep1-observer.md independently corroborates: DB baseline 7 runs (06:33–06:54Z, all state=running), 40 receipts, worktree first exists 18:53:36Z with 3 real commits (`fd68647`, `37aaa85`, `fd829dc`) |
| 9 | `classified e1` | NOT-SATISFIED | Episode never reached classification: ep1-observer.md — run NEVER created (15+8 polls, 0 new runs), app dead from 18:29:10Z; classification step never executed |
| 10 | `unknown e1` | NOT-SATISFIED | Same — never classified unknown (ep1-observer.md verdict: zero DB footprint) |
| 11 | `known e1` | NOT-SATISFIED | Same — never classified known |
| 12 | `frontier-clean ?e` | PARTIAL | Machinery: ep2-replay.md — `route_known_replay` refuses `REFUSED_FRONTIER_NOT_CLEAN`; replay route structurally cannot reach `CMCACandidateAllocator.allocate` (imports `ExplorationBudget` only); 14 tests incl. measured zero allocator calls. Named-term gap: boundary-autofde-lab.md — literal `frontier_clean` 0 grep hits repo-wide; realized as FrontierAllocationPlan + OCEL all_objects_conform + R-304. Open (ep2-replay.md §4): OCEL/witness-derived frontier_clean wired to CHI-KNOWN; frontier_clean is caller-declared at route time. Episode-2 real replay: never executed → preservation through completion UNWITNESSED at release level |
| 13 | `candidate-produced e1 candidate-1` | NOT-SATISFIED | Episode never started (ep1-observer.md: 0 runs/epochs/receipts during watch). Machinery witnessed: boundary-autofde-lab.md court #2 (15 passed — Cycle 0 refused → promotion → Cycle 1 zero inference) |
| 14 | `admitted candidate-1` | NOT-SATISFIED | ep1-driver.md: admission `mix run /tmp/uzc/ep1_admit.exs` (pid 10012) stopped BEFORE its eval executed; post-incident DB verification ultracode_runs=7 unchanged, zero rows carry the goal string. Machinery: admission court sole KNOWN-granter (unknown/resolution.py:174; tests green) |
| 15 | `candidate-refused candidate-1` | UNKNOWN (episode) | No episode candidate existed to refuse. Machinery: typed refusal witnessed (Cycle 0 refused, boundary-autofde-lab.md #2) |
| 16 | `candidate-blocked candidate-1` | UNKNOWN | Typed oneof alternative exists (HDDL; admission court types); no witnessed instance any receipt |
| 17 | `candidate-unsupported candidate-1` | UNKNOWN | Same — typed alternative, no witnessed instance this wave |
| 18 | `plan-built e1 plan-episode-1` | CLAIMED-UNVERIFIED | ep1-driver.md: /tmp/uzc/ep1_admit.exs written (Run :create {provider zcode, max_cycles 1, epoch_timeout_seconds 3600} + :start exact_subject=/tmp/uzc/ep1-worktree) — script exists, never executed; no observer could see a plan take effect (observer: zero footprint). Machinery: CHI-PLAN Gate04_PlanningCandidateOnly PASS (certify-prep.md gate table) |
| 19 | `allocation-bounded plan-episode-1` | CLAIMED-UNVERIFIED | Bounds declared in the unexecuted admission script (max_cycles 1, timeout 3600 — ep1-driver.md). Machinery: CHI-BUDGET Gate05_WholeBoundedPlanPreflighted PASS (certify-prep.md); bcinr typed bounds (boundary-bcinr.md §3) |
| 20 | `allocation-blocked plan-episode-1` | UNKNOWN | No witnessed instance |
| 21 | `manufactured e1 artifact-episode-1` | PARTIAL | Capability witnessed: boundary-ggen.md — `ggen sync run` produced committed projection diffs + re-lock; `--dry-run` then `written: []` (idempotent fixed point); FM-PACK-008 + FM-WRITE-005 refusals fired; BLAKE3-signed receipts. EPISODE artifact: never manufactured (episode blocked). Gate-level: CHI-EXEC Gate06_AutonomousExecutionInsideEnvelope PASS (certify-prep.md) |
| 22 | `manufacture-failed e1` | UNKNOWN | No witnessed instance (episode never reached manufacture) |
| 23 | `authority-admitted e1` | NOT-SATISFIED | Run never admitted; server dead from 18:29:10Z (ep1-driver.md; ep1-observer.md). Machinery: CHI-BOUNDARY Gate07_SoleDOBoundaryBRCE PASS; xaas lease court (`admit_tool` allows Edit, refuses `git_push`/`Bash` → `{:error, {:refused_no_authority, ...}}`, unknown class `TimeMachine` fenced; forged final_head downgrades to :build_broken) — boundary-xaas.md tripwires |
| 24 | `authority-refused e1` | UNKNOWN (episode) | No episode authority request existed. Machinery witnessed: lease_test refusals above; ep1-driver zero-Bash MET vacuously |
| 25 | `command-issued e1 command-episode-1` | NOT-SATISFIED | Zero DB writes by driver (psql counts 7/40 unchanged — ep1-driver.md); observer: zero HTTP from executor inside window; run never created |
| 26 | `actuated command-episode-1` | NOT-SATISFIED | Nothing actuated (ep1-observer.md: receipts constant at 40, ocel_events=0 constant). Machinery: boundary-xaas.md actuation_test.exs 4/0 (Reactor is the admitted DO path; idempotent replay) |
| 27 | `actuation-failed command-episode-1` | UNKNOWN | No command existed to fail |
| 28 | `receipt-pending command-episode-1` | UNKNOWN (episode) | Never reached. Machinery: BRCE invariant witnessed in tests — "mutation cannot commit ahead of its receipt" (lib/xaas/actuation.ex transaction-wrapped Reactor, boundary-xaas.md) |
| 29 | `receipt-durable ?cmd ?r` | PARTIAL | Durable receipts exist but NOT the P2 target kind: ep1-observer.md — 40 receipts DB-wide, evidence keys ONLY {epoch_timeout_seconds, expected_at, expected_state, observed_state}; **no provider, no head_verified field in ANY receipt ever written**; 7 :blocked receipts sealed LIVE by Oban missed-epoch sweep (ep1-driver.md: newest 06:55Z; matches missed_epochs.ex advance_run/1; test missed_epoch_receipt_test.exs exists at fd68647 — commit 45fbbb9 closed the named gap). `Receipt(provider=zcode, outcome=alive, head_verified=true)`: NOT MET (ep1-driver falsifier verdict) — and STRUCTURALLY unreachable through the sanctioned flow: no production path sets epoch.worktree (lease.ex:91-110, create_first_epoch.ex:32-49, next_epoch.ex:96-121; lease.ex:290 encodes worktree-from-epoch-row) → every close downgrades :partial_alive (verifier_unavailable=:no_worktree). See D3 |
| 30 | `receipt-reconcile-blocked ?cmd` | UNKNOWN | No witnessed instance |
| 31 | `verified e1` | NOT-SATISFIED | ep1-driver.md falsifier verdict: NOT MET ("Receipt(provider=zcode, outcome=alive, head_verified=true): impossible — no lease cycle could start; server dead"). Observer verdict: BLOCKED, "Verified/ALIVE cannot be attributed to ep1 from the DB by any observer" (ep1-observer.md) |
| 32 | `verification-failed e1` | SATISFIED (witnessed) | ep1-driver.md (standing BLOCKED, falsifier NOT MET) + ep1-observer.md verdicts (a) NOT VERIFIED episode-absent, (e) FAIL ocel nothing landed. Executor and observer AGREE — no executor ALIVE claim exists to reconcile |
| 33 | `process-conformant e1` | NOT-SATISFIED (machinery gate green) | Episode process never ran, so nothing conformed (ep1-observer.md: zero transitions). Gate-level: CHI-OBS Gate08_IndependentPostconditionObservation PASS (certify-prep.md); beam4pm conformance court real and witnessed (boundary-beam4pm.md: e2e asserts named deviation `[">>", "clean_house"]`, cost>0, fitness<1.0) |
| 34 | `process-nonconformant e1` | UNKNOWN | No witnessed instance at release scope |
| 35 | `feedback-recorded e1` | NOT-SATISFIED | Episode feedback step never reached. Hook observers ran transport-skipped (`record_skipped` — server dead; hook-court.md table). Incident intel lives in receipts, not in the episode's feedback path |
| 36 | `experience-created e1 experience-1` | NOT-SATISFIED | Never reached. Machinery: MachineExperienceCompiler (unknown/compilation.py:57,73; boundary-autofde-lab.md) + ep2 admission tests green (ep2-replay.md: 47 passed) |
| 37 | `experience-admitted experience-1` | NOT-SATISFIED | Never reached at episode level. Machinery: `admit_machine_experience` court refuses uncompiled/empty; success yields `AdmittedMachineExperience` with declared literals `admitted=True, replay_contract=True` (ep2-replay.md §2; tested) |
| 38 | `replay-contract experience-1` | NOT-SATISFIED | Same split: machinery typed + tested (ep2-replay.md); real experience-1 never existed |
| 39 | `equivalent e2 e1` | UNKNOWN (episode) | Real episode pair never ran. Machinery witnessed BOTH directions: ep2-replay.md — `prove_semantic_equivalence` pure typed field comparison (goal/subject/ordered steps/bounds), EQUIVALENT path and 5 parametrized EQUIVALENCE_FAILED paths (goal, subject, step missing, steps reordered, bounds), proof digest deterministic; forged EQUIVALENT report refused `REFUSED_EQUIVALENCE_PROOF_INVALID` |
| 40 | `equivalence-failed e2 e1` | UNKNOWN (episode) | Same — machinery witnessed (5 refusal tests), episode never ran |
| 41 | `replayed e2 experience-1` | NOT-SATISFIED (machinery + gate green) | Real replay never executed. Machinery: `replay_known_transition` re-asserts known ∧ frontier_clean ∧ replay-contract fail-closed; counting engine exactly 1 on the green path, 0 on refusals (ep2-replay.md §3: 14+33=47 passed). Gate: CHI-REPLAY Gate10_ReplaySucceedsDeterministically PASS (certify-prep.md) |
| 42 | `affidavit-issued ?e` | PARTIAL | RELEASE-level affidavit ISSUED: affidavit-issuance.md — 18 court commands; `affi receipt assemble`→0 (content 67dc1210…); `affi receipt verify`→0 `verdict: ACCEPT [core/v1] — all stages passed` (7/7 stages, 14 events); 11 boundary-receipt evidence files BLAKE3-bound; tamper falsifier on copy → exit 1 (`chain hash mismatch: receipt claims 13672dfb…, recomputed 2b99ec61…`); binding-bite falsifier: pristine re-commit d91073a4… = evt-6 exactly, +1 byte → 05cff986…. Artifact /tmp/uzc/affidavit-v26.9.17/ (MANIFEST sha256 -c → all OK exit 0). NOT cryptographically signed (UNSUPPORTED #6). EPISODE affidavits (e1/e2): NOT issued — ep1 evidence was pending at issuance (evt-12 pending-evidence) and the episode then blocked; ledger-closure.md not landed |
| 43 | `episode-alive ?e` | NOT-SATISFIED | e1: BLOCKED per executor AND observer (dual-witnessed). e2: machinery ALIVE only (ep2-replay.md standing ALIVE "for THIS boundary"; release-level qualification awaits integration + operator release act) |
| 44 | `release-qualified v26-9-17` | NOT-SATISFIED | m-certify-release preconditions unmet: verified/process-conformant/affidavit-issued e1 all fail; experience-1 never admitted; e2 never replayed; CHI-ID fence pending operator tag. Court's own 12-gate receipt at 156cb6fe: standing=BUILD_BROKEN, 11/12 (certify-prep.md). Falsifier PROVES the fence: scratch clone + scratch tag v26.9.17 → exit 0, standing=ALIVE, all_gates_passed=True, tag_equality=True (main repo never tagged; `git tag -l` verified empty after) |

### Predicate counts (release-scope, 44 rows)

| Status | Count | Rows |
|--------|-------|------|
| SATISFIED | 7 | owns, critical, build-broken, unsupported, heads-pinned, world-reconstructed, verification-failed |
| PARTIAL | 5 | qualified (7/9), frontier-clean, manufactured, receipt-durable, affidavit-issued |
| NOT-SATISFIED | 18 | blocked, classified, unknown, known, candidate-produced, admitted, authority-admitted, command-issued, actuated, verified, process-conformant, feedback-recorded, experience-created, experience-admitted, replay-contract, replayed, episode-alive, release-qualified |
| CLAIMED-UNVERIFIED | 2 | plan-built, allocation-bounded |
| UNKNOWN | 12 | candidate-refused, candidate-blocked, candidate-unsupported, allocation-blocked, manufacture-failed, authority-refused, actuation-failed, receipt-pending, receipt-reconcile-blocked, process-nonconformant, equivalent, equivalence-failed |

Of the 12 UNKNOWNs, 11 are "typed machinery exists, episode step never reached" and 0 are
"receipt not landed" except as noted: **ledger-closure.md not landed** leaves the wave-level
比 and ledger closure UNKNOWN (see header).

---

## b. Boundary matrix

| repo | capability | standing | pinned head (branch) | repairs (branch + SHAs) |
|------|-----------|----------|----------------------|--------------------------|
| ash_a2a | cap-orchestration | PENDING → court observed RED per raw log (see #3); no agent classification landed | pinned 02d8616, **moved**, re-pinned 801374a (main, clean, ahead of origin 111) | none sanctioned (latent test-env strict-compile defect escalated, not repaired) |
| ash_r2rml | cap-semantic-feedback | ALIVE / qualified | 7d958a8 (epoch/v26.9.15-semantic-subject, clean) | none; fix/ash-r2rml-v26.9.17-boundary NOT created |
| bcinr | cap-bounded-select | ALIVE / qualified | f70999c0 (release/26.9.15, clean) | none; fix/bcinr-v26.9.17-boundary unused |
| ggen | cap-manufacture | ALIVE at repaired head; pinned head as-found BUILD_BROKEN | 03ceb0df6 (feat/marketplace-sparql-semantic-search, clean) | fix/ggen-v26.9.17-boundary: 0d2b4a9c9 (fmt), 4e2b4df3e (pack/consumer reconciliation via ggen sync run), ebeb27515 (rf:packCount 86→94), 76a4d15b3 (coverage ratchet 19→20), 5cc8808c1 (rmcp proof-strength restoration) — tip 5cc8808c1, full pre-commit EXIT=0 |
| ggen_igniter | cap-framework-projection | ALIVE / qualified | d018ed4 (feat/calver-ticket-day-pack, clean) | none |
| xaas | cap-system-authority | ALIVE / qualified | fd68647 (feat/execution-actuation-fabric) | none; UNCOMMITTED boundary-adjacent drift reported for owner to commit: execution_fabric_controller.ex (+16, atom-table DoS hardening) + controller_test.exs (+42, negative test) — tests green WITH it in tree |
| affidavit | cap-standing | PARTIAL_ALIVE (verification court ALIVE; signing sub-surface UNSUPPORTED) | 7f1caf6 (main; 2 dirty Cargo files = operator's [patch.crates-io] wasm4pm-compat drift — see D4) | fix/affidavit-v26.9.17-boundary: 72cd90f (fmt sweep), ada0b29 (§6 stderr transport restore), 3106f64 (witness flags --r#type/--receipt) — tip 3106f64; issuance worktree branch feat/v26.9.17-release-affidavit (patch block uncommitted, by design) |
| beam4pm | cap-process-court | ALIVE / qualified | ace23e5 (main; 17 dirty preserved, +5 test-emitted ERC-002 receipts at end) | none (provisioning only: rust4pm wasm build + 4 native oracle builds + repo's own env contract) |
| autofde-lab | cap-crown | PARTIAL_ALIVE (court-types HEAD BUILD_BROKEN pending operator tag; adjudicated lawful fence) | 00af45ee (master; 10 dirty preserved) | fix/autofde-lab-v26.9.17-boundary: 64181bb7 (ocel_tracer typed attributes + tripwire), 156cb6fe (release_tag→v26.9.17 + URN derivation + 3-test tripwire); separate branch feat/ep2-replay-contract: 112d7e41 (Episode₂ replay contract, 811 insertions, 14 tests) — DIVERGENT from 156cb6fe, integration pending |

Non-critical (owned, not this wave): unrdf (cap-runtime), wasm4pm (cap-portable-runtime).
Adjacent surface: hook court (wave-4 agent 6/8) — **PARTIAL_ALIVE**; 6 hooks of installed
xaas-fabric plugin: pre_tool_use fail-closed DENY proven live (exit 2, `{"decision":"deny",
"reason":"BRCE_UNAVAILABLE"}` on dead control plane), observers best-effort, stop short-circuits
no_lease; registration (hooks.json event names, matcher `"*"`, command form, xaas.md command,
SKILL.md, .mcp.json `${user_config.zcode_xaas_token}`, config key len 34) QUALIFIED vs
diagnosing-* docs + P0P1 bundle source. Deviations: token leak (see header) ; server-side
403/401/503 through hooks remain test-covered only (server dead).

---

## c. Episode status vs HDDL ordered-subtasks

### Episode₁ (e1.1–e1.16) — discovery. Overall: BLOCKED (dual-witnessed)

| step | HDDL action | state |
|------|-------------|-------|
| e1.1 | reconstruct-world | DONE (dual-witnessed: driver survey + observer baseline agree 7/7/40) |
| e1.2 | classify-problem | NOT REACHED (run never created) |
| e1.3 | solve-classified-problem | NOT REACHED (P2 falsifier NOT MET — honestly reported) |
| e1.4 | construct-plan | CLAIMED-UNVERIFIED (ep1_admit.exs written, never executed) |
| e1.5 | bound-allocation | CLAIMED-UNVERIFIED (bounds in script; CHI-BUDGET gate green) |
| e1.6 | manufacture | NOT REACHED |
| e1.7 | admit-authority | NOT REACHED (admission stopped before eval; zero DB writes) |
| e1.8 | dispatch-command | NOT REACHED |
| e1.9 | execute-command | NOT REACHED (observer: receipts constant 40, ocel_events=0) |
| e1.10 | close-receipt | NOT REACHED (head_verified target structurally unreachable — see #29/D3) |
| e1.11 | independent-verify | DONE, verdict NEGATIVE (driver: NOT MET; observer: BLOCKED) |
| e1.12 | observe-process | NOT REACHED (nothing to observe) |
| e1.13 | record-feedback | NOT REACHED at episode level (hook observers transport-skipped) |
| e1.14 | create-machine-experience | NOT REACHED |
| e1.15 | admit-machine-experience | NOT REACHED |
| e1.16 | issue-affidavit | NOT ISSUED for e1 (release-level affidavit issued with e1 evidence marked pending, evt-12) |

Environment incident (both receipts agree): app death ~18:29:10Z — PostgrexTypes module
unavailable → Oban transaction retries exhausted → CodeReloader ETS crash on reload! →
`Application xaas exited: shutdown`. Driver self-attributes the fatal window (its admission
`mix run` recompiled the sibling-dirty tree into SHARED _build/dev while its own curl
triggered the live reload); observer and hook-court agent each disclaim own causation
(observer: zero HTTP/writes; hook-court: log delta 1219→1219 across its run). Operational
law recorded by driver: serialize `mix` against LIVE REQUESTS too, not just sibling agents;
use `mix run --no-start` + explicit Repo start or isolated worktree build. Stale-state
hazard (observer): on restart, the sweep meets 7 zombie :running runs first.

### Episode₂ (k1–k11) — known-replay. Overall: machinery ALIVE, episode NOT RUN

| step | HDDL action | state |
|------|-------------|-------|
| k1 | reconstruct-world e2 | NOT RUN (machinery only) |
| k2 | prove-semantic-equivalence | MACHINERY DONE (ep2-replay.md: EpisodeRecord + pure typed equivalence, 14 tests both directions; was 0 hits before 112d7e41) |
| k3 | route-known-replay | MACHINERY DONE (route court with all-or-nothing refusals incl. REFUSED_FRONTIER_NOT_CLEAN) |
| k4 | replay-known-transition | MACHINERY DONE (fail-closed re-assertion; ReplayEngine.verify_chain offline) |
| k5 | admit-authority-replay | MACHINERY (Replay ≠ DO enforced; authority inside verify_chain) |
| k6 | dispatch-replay-command | MACHINERY ONLY (test counting collaborators) |
| k7 | execute-replay-command | MACHINERY ONLY |
| k8 | close-replay-receipt | MACHINERY ONLY (real DO receipts via ConsequenceBoundary in tests) |
| k9 | verify-replay | GATE+MACHINERY (CHI-REPLAY Gate10 PASS at 156cb6fe; 47 tests) |
| k10 | observe-replay-process | GATE (CHI-OBS Gate08 PASS at 156cb6fe) |
| k11 | issue-affidavit e2 | NOT ISSUED |

Known gaps (ep2-replay.md §4, honest): steps are declared, not yet projected from a real
episode's OCEL trace; OCEL-derived frontier_clean wiring open; explore-unknown structurally
absent from the replay module (the FOND crown property is enforced by construction: imports
ExplorationBudget only, never CMCACandidateAllocator).

### Certification (t5)

Eleven of twelve crown gates PASS at committed HEAD 156cb6fe; CHI-ID fails solely on the
untagged HEAD (fence); scratch-clone falsifier proves 12/12 ALIVE the moment the operator's
tag exists. `release-qualified` remains NOT-SATISFIED (see #44).

---

## d. OPERATOR ACT list (only the operator can cut these)

1. **Cut the release tag + re-run the crown runner** (certify-prep.md ACT SHEET, verbatim):
```bash
cd /Users/sac/autofde-lab
git checkout fix/autofde-lab-v26.9.17-boundary
git log --oneline -1                       # confirm tip is 156cb6fe (or the agreed release HEAD)
git tag -a v26.9.17 -m "SA2A release v26.9.17" 156cb6feffcc18dc715efb1f17e6760696fd70b6
.venv/bin/python scripts/run_chicago_qualification.py
# If more commits land on the branch before the cut, tag the NEW tip SHA instead and
# re-run from that checkout; the fence checks tag == HEAD.
# The default receipt/OCEL paths are git-tracked/published artifacts; commit or discard
# the refreshed receipt per release procedure (operator's call).
```
   Note for the cut: the branch tip does NOT include ep2's 112d7e41 (divergent branch) —
   decide whether Episode₂ machinery belongs in v26.9.17 or the next epoch.
2. **Restart the xaas dev server (fresh cut), then redispatch P2** (ep1-driver.md):
   "What the operator MUST do next: restart the dev server (fresh cut), then redispatch P2 —
   the cycle script above is ready" (/tmp/uzc/ep1_admit.exs; worktree /tmp/uzc/ep1-worktree
   @ fd68647 ready). Beware the 7 zombie :running runs the sweep will meet on restart
   (ep1-observer.md anomaly 4).
3. **Decide the head_verified/worktree design question** (ep1-driver.md intel 2): production
   never sets epoch.worktree, so head_verified receipts are structurally unreachable; client-
   supplied worktrees at claim time "would reverse an encoded decision — a design change for
   the operator, not a driver workaround."
4. **Rotate the dev-local ZCODE_XAAS token** (hook-court.md §5): one-time print of the
   scalar into the session transcript; "RECOMMENDED: rotate before any non-dev use."
5. **Commit the uncommitted xaas atom-safety drift** (boundary-xaas.md): controller +16 /
   test +42 (String.to_existing_atom hardening + negative test) — lawful, tested, awaiting
   the seam owner's commit.
6. **Push/PR/merge decisions** (no agent pushed anything):
   - ggen fix/ggen-v26.9.17-boundary (5 commits → 5cc8808c1; marketplace untouched, read-only);
   - affidavit fix/affidavit-v26.9.17-boundary (3 commits → 3106f64) + resolve the
     buildability drift D4 (committed tip does not compile without the operator's uncommitted
     [patch.crates-io] wasm4pm-compat block);
   - autofde-lab fix/autofde-lab-v26.9.17-boundary (64181bb7 + 156cb6fe);
   - autofde-lab feat/ep2-replay-contract (112d7e41) — integration decision (see act 1 note).
7. **Follow-up affidavit** binding ep1-driver.md + ep1-observer.md (and ep2-replay.md,
   certify-prep.md, hook-court.md, which post-date the issuance evidence set) — the chain
   records evt-12 pending-evidence naming exactly this (affidavit-issuance.md).
8. **Read the 比 from ledger-closure.md when it lands** — it had not landed at assembly
   deadline; the wave-level ratio is UNKNOWN here. Per-receipt 比 claims (not the release
   number): 0 hand-written 産面 lines for ash_r2rml, bcinr, ggen_igniter, xaas, beam4pm,
   hook-court, ep1-driver, ep1-observer; ggen = tool/generator/guard-named one-fact
   remediations + template reconstruction from witnessed output (boundary-ggen.md 比 section);
   affidavit = 3 narrow commits; autofde-lab = 2 files/54 insertions (64181bb7) + 2 files/811
   insertions (112d7e41) + 2 files/+75/−6 (156cb6fe).

---

## e. Session receipt header (house law)

**Repos / base / tree** (nothing pushed, nothing merged, no tags moved by any agent):
- /Users/sac/ash_a2a — main @ 801374a (moved from pinned 02d8616; re-pinned), clean; prior-wave log superseded (see D7).
- /Users/sac/ash_r2rml — epoch/v26.9.15-semantic-subject @ 7d958a8, clean.
- /Users/sac/bcinr — release/26.9.15 @ f70999c0, clean.
- /Users/sac/ggen — feat/marketplace-sparql-semantic-search @ 03ceb0df6 (clean); branch fix/ggen-v26.9.17-boundary @ 5cc8808c1 (5 commits).
- /Users/sac/ggen_igniter — feat/calver-ticket-day-pack @ d018ed4, clean.
- /Users/sac/xaas — feat/execution-actuation-fabric @ fd68647; 15 dirty entries preserved (drift classified in boundary-xaas.md); worktree /tmp/uzc/ep1-worktree @ fd68647 (feat/ep1-missed-epoch-receipt, no commits).
- /Users/sac/affidavit — main @ 7f1caf6 (2 dirty Cargo files preserved); branch fix/affidavit-v26.9.17-boundary @ 3106f64 (3 commits); worktree /tmp/uzc/affidavit-wt (feat/v26.9.17-release-affidavit, patch block uncommitted by design).
- /Users/sac/beam4pm — main @ ace23e5; 17 dirty preserved (+5 machine-written ERC-002 receipts by session end).
- /Users/sac/autofde-lab — master @ 00af45ee (dirty preserved); branches fix/autofde-lab-v26.9.17-boundary @ 156cb6fe and feat/ep2-replay-contract @ 112d7e41; scratch clone /tmp/uzc/fence-falsifier-clone destroyed after falsifier.
- This assembler: read-only on all repos; sole output this file.

**Commands + exit codes summary** (each cited at its row above): 9 boundary courts executed
at pinned heads (all exits recorded per receipt); crown runner exit 1 lawful-fence at
156cb6fe with 11/12 PASS; scratch-clone falsifier exit 0 / 12/12; affidavit issuance 18
commands exit 0, tamper falsifier exit 1 (teeth), manifest check exit 0; ep2 suites 47
passed; ep1 server probes → HTTP 000 / ECONNREFUSED, psql counts 7/40 unchanged, admission
job stopped before eval; hook court 6 runs exits 0,0,2,0,0,0; ash_a2a court log (raw
observation) 1912 tests / 49 failures / 8 invalid / MIX_TEST_EXIT:2.

**比 pointer**: ledger-closure.md — **receipt not landed; ratio UNKNOWN**. Do not cut the
release on a claimed ratio.

**Standing deltas witnessed this wave**: cap-process-court UNKNOWN → ALIVE (beam4pm);
cap-semantic-feedback, cap-bounded-select, cap-framework-projection, cap-system-authority →
ALIVE/qualified; cap-manufacture → ALIVE at repaired head (as-found BUILD_BROKEN); cap-standing
→ PARTIAL_ALIVE with UNSUPPORTED(cryptographic-signature) ledgered; cap-crown → PARTIAL_ALIVE
(pending operator tag); cap-orchestration → PENDING (court red per raw log, unadjudicated);
hook court → PARTIAL_ALIVE; Episode₂ machinery → ALIVE; P2 lease cycle → BLOCKED.

**Falsifiers attempted across the wave** (all survived unless noted): stricter-than-court
compiles (ash_a2a — surfaced latent defect; ggen_igniter, xaas — clean); single-field tamper
through real binaries (affidavit ×2 — both caught: exit 1 chain-hash mismatch); commitment
binding-bite (+1 byte → different hash); forged EQUIVALENT report → REFUSED_EQUIVALENCE_
PROOF_INVALID; steps-permutation ≠ equivalent; direct ReplayRoute forgery → typed error;
sync-without-force clobber → FM-WRITE-005 refusal; fabricated ledger hash → git cat-file
absent-then-fetched (clone gap, not fabrication); "capability emulated host-side" →
differential wasm≡native oracles (beam4pm); "dirt broke the court" → falsified twice
(beam4pm additive dirt; affidavit drift-blame via lock comparison); crown fail-closed claim
(0 PARTIAL/MISSING despite 16 BLOCKED — survived); "loop is aspirational" → falsified
(measured zero-inference replay); PYTHONPATH-suffices → falsified (editable meta-finder);
release fence → falsified in the direction of honesty (scratch tag → 12/12, proving the sole
failure is the missing operator act); **P2 lease-cycle falsifier → NOT MET, honestly reported
as BLOCKED** (ep1-driver + ep1-observer agree); "run exists but timestamps misread" →
falsified (UTC confirmed two independent ways); oban late-jobs / log-truncation / observer
self-involvement → all falsified.

**Deviations ledgered, not papered over**: hook-court token leak (rotate — act 4); ep1-driver
environment incident with honest self-attribution + operational law; affidavit-issuance
uncommitted [patch] reproduction in worktree (3 lines + comment, provenance-commented);
certify-prep uv interpreter lost exec-bit repaired chmod +x (flagged: something mutated
~/.local/share/uv mid-wave); ash_a2a Postgres :55432 squatter (Docker Desktop backend pid
62485) + colima degradation documented, NOT repaired (no authority to quit shared Docker
Desktop).

**What the operator did NOT have to write**: everything above except the act list in (d).
Per receipts: all 9 boundary qualifications (including 10 repair commits across ggen,
affidavit, autofde-lab), the 12-gate fence rewiring + tripwires, the Episode₂ replay
contract (811 insertions), the wave affidavit artifact (/tmp/uzc/affidavit-v26.9.17/), the
hook-court qualification, the P2 driver + independent observer records, and this assembly.
Operator keystrokes reserved for: one tag command + one re-run, a server restart, a token
rotation, and the commit/Push decisions.

---

## f. Disagreement register (BOTH claims recorded — never averaged)

| # | Parties | Disagreement | Resolution status |
|---|---------|--------------|-------------------|
| D1 | ORIENT vs boundary-ash-a2a | Pinned head 02d8616 vs observed 801374a | HEAD legitimately moved (3 commits: hddl reconcile + dogfood fixtures, merge, changelog; only test fixtures + CHANGELOG); verification re-pinned at 801374a. Both heads recorded |
| D2 | boundary-ash-a2a (receipt) vs /tmp/uzc/ash-a2a-court.log (raw) | Receipt leaves FOND classification "pending"; raw log shows court RED (1912/49f/8i, exit 2) | OPEN — no agent adjudication landed (env attribution like beam4pm's vs real defect is unmade). Predicate row #3 carries the raw numbers as observation, NOT as classification |
| D3 | boundary-xaas (ALIVE/qualified, 648/0) vs ep1-driver + ep1-observer (production head_verified receipts structurally unreachable; no receipt ever carried provider/head_verified keys) | SCOPE disagreement, both true: the TEST court is green; the PRODUCTION lease-close path can never produce the P2 target receipt | Both recorded (#29); operator design decision (act 3) |
| D4 | boundary-affidavit ("drift did NOT break the court; build passed under drift") vs affidavit-issuance ("committed build state at tip 3106f64 does not compile: registry wasm4pm-compat 26.6.13 fails, 550 errors") | Buildability of affidavit depends on the operator's UNCOMMITTED [patch.crates-io] drift | Both recorded; affidavit repo is not buildable-from-HEAD without the patch — commit decision belongs to operator (act 6) |
| D5 | certify-prep court output (standing=BUILD_BROKEN at 156cb6fe) vs boundary-autofde-lab adjudication ("the fence, not the loop" → PARTIAL_ALIVE) | Same facts, different typing: court types mechanically; agent adjudicates the failure as the identity fence working | Both recorded; operator's tag resolves it one way or the other (act 1) |
| D6 | beam4pm bare `mix test` (exit 2, 22 failures) vs env-contract `mix test` (exit 0, 1108/0) | Environmental root cause (unbuilt oracle binaries + unset repo-defined env contract), not code | Resolved by provisioning; both numbers recorded (boundary-beam4pm.md) |
| D7 | ash_a2a prior-wave log (1910 tests, 22 failures, 8 invalid, Erlang corrupt-atom-table crash) vs this session's run | Prior log treated UNRELIABLE (VM corruption under 10-agent load), superseded | Recorded in boundary-ash-a2a.md falsifier 2 |
| D8 | ep1-driver self-attribution of the server death vs hook-court/ep1-observer neutral recordings | Driver claims its shared-_build/dev compile + curl reload trigger caused the crash; the other two agents only disclaim their own causation and document the crash chain | Compatible, not contradictory; the only causal claim on record is the driver's own — retained |

---

**Bottom line for the cut decision**: 7 of 9 critical boundaries qualified with witnessed
courts; cap-crown is one operator tag away from 12/12 (falsifier-proven); cap-orchestration's
court is red with no landed adjudication; Episode₁ is BLOCKED with dual-witnessed zero DB
footprint and a structural head_verified gap; Episode₂ machinery is ALIVE but unexercised at
release level; the release-level affidavit is issued, chain-verifiable, NOT cryptographically
signed (typed UNSUPPORTED); the wave 比 is UNKNOWN (ledger-closure.md not landed).
`release-qualified v26-9-17` = NOT-SATISFIED.

---

## ADDENDUM (12:20 local — receipts that landed after the assembly deadline)

1. **D2 RESOLVED — ash_a2a/cap-orchestration classified: PARTIAL_ALIVE** (boundary-ash-a2a.md
   finalized). The raw 49-failure court run was caused by the agent's container volume mounts
   wiping gitignored native binaries; rebuilt per the repo's own printed instructions (exit 0),
   court re-run: **1912 tests, 0 failures** (58 doctests, 19 properties, 606s). Exit 2 is now
   solely **8 invalid** = `ObanDeliveryQualification` + `ScheduledSweepQualification`, whose
   setup_all raises-by-design when Postgres :55432 is unreachable — host port squatted by a
   stale Docker Desktop backend (pid 62485); colima also degraded. Freeing the port needs the
   operator (new act 9). Predicate #3 → `qualified` now **8/9 modulo the port act**
   (ash_a2a counted PARTIAL until :55432 frees and the last 8 tests run green). The dogfood
   HDDL test of this release wave passes and names `ash-a2a/cap-orchestration` ALIVE.
2. **ledger-closure.md LANDED** — release 比 now KNOWN: **0% manufactured, honestly**
   (fail-closed count, a11bf7a..HEAD: 178/13 lines; 産面 = 78 insertions, all hand-written:
   generator 9, templates 10, controller 15, test 44; manufactured = 0). Paydown plan recorded:
   admit zcode-plugin-pack (templates now contract/credential-clean), ultracode-actuation-
   lease-pack + mcp-surface extension from proven shapes. Commits on feat/execution-actuation-
   fabric: **32b5ba1** (atom-table DoS fix + test — RESOLVES operator act 5), **113a6eb**
   (HANDWRITTEN.md reconciliation), **6ff1a32** (PROGRESS.md wave-4 entry). Act 8 RESOLVED.
   One hazard documented for the still-live receipts/lease author in the xaas tree: bare
   `git commit` without re-adding controller/test would revert the atom fix (status `MM`).
3. **Operator act list delta**: act 5 RESOLVED (committed by wave), act 8 RESOLVED (比 = 0%),
   NEW act 9: free host port 55432 (quit stale Docker Desktop backend pid 62485 / restart
   Docker Desktop), then re-run `mix test --only qualification` in ash_a2a to close the last
   8 invalid tests → full-court green.
4. Receipt set preserved durably (untracked) at
   /Users/sac/xaas/docs/ultracode/wave-v26.9.17-receipts/ (copied from /tmp/uzc, which is
   volatile).
