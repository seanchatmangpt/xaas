# Delaware Caremark/Marchand/McDonald's Rebuttal Evidence Map

Lane W525c, EU-AI-Act wave, 2026-10-06. Dissertation Ch8 Thm 8.2. Subject: repo
`/Users/sac/xaas` @ `feat/playwright-surface` @ `d1db2b03` (same subject as
`docs/cro/artifacts/evidence-claims-index.md`). Honest-numbers: every claim is a
path on disk; standing is the receipt's own, not asserted upward.

## Prong 1 rebuttal — a formal reporting/information system EXISTS

*Stone v. Ritter, 911 A.2d 362 (Del. 2006): the board must show a reporting
system existed and board-level information flow was not delayed or incomplete.*

| # | System component | On-disk evidence (path-verified 2026-10-06) |
|---|---|---|
| 1 | Receipt corpus (the information system itself) | `docs/sjira/v26.10.6/plans/` — 329 files (counted `ls | wc -l`), one line per receipt in `_INDEX.md`; closure receipt `_CLOSURE_RECEIPT.md` populated only from receipt-cited evidence, PENDING markers explicit |
| 2 | Refusal ledger export | `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` — counts: 62/62 refusal classes fixture-covered, 10 mutation runs / 9 kills, 2 structurally-unreachable disclosed; notes field records w382/w414 anti-vacuity closure |
| 3 | Conformance pack | `test/mix/tasks/xaas_eu_ai_act_pack_test.exs` (exists, verified) plus `test/mix/tasks/xaas_eu_ai_act_annex_iv_test.exs`; pack task `mix xaas.eu_ai_act_pack` |
| 4 | OCEL telemetry surfaces | `lib/xaas/telemetry/{ocel_envelope,ocel_ndjson,ocel_forwarder,ocel_ash_emitter,zcode_ocel_validator}.ex` — event-log capture of the governed process itself |
| 5 | Coverage map | `docs/sjira/v26.10.6/plans/w342-e2e-coverage-map.md`, `w367-capability-coverage.md`; refusal-exhaustion audit `vector2-refusal-coverage.md` (xaas: 50 distinct REFUSED_* variants) |
| 6 | Integrity-anchored witness store | `lib/xaas/witness/{certified_receipt,audit_chain,catalog,verification_key}.ex`; persisted write-once receipts, pluggable `sig` verify callback |

## Prong 2 rebuttal — ACTIVE monitoring, not passive existence

*In re Marchand (2009), McDonald (2021): the system must be actually operated and
board must respond to red flags. Evidence of running, dated, result-bearing runs.*

| # | Monitoring activity | On-disk evidence |
|---|---|---|
| 1 | OCEL conformance/fitness (drift detection) | `w511-art72-conformance.md` — `BeamPM.Art72Conformance.fitness_from_stats/1` + `drift_decision/2` (strict `C < 1−ε ⇒ :DRIFT`); Result: 10 passed, beam4pm canonical checkout. Standing: PARTIAL_ALIVE (token-game fitness over in-repo log; alignment fitness only in the WASM engine) |
| 2 | Executable regulation (Chicago court suite) | `test/eu_ai_act/` — 20 tests across title_ii/iii/iv_v/vi_xiii + smoke; support/corpus_loader.ex; receipts: `w525-title-vi-xiii.md` and title receipts in `docs/sjira/v26.10.6/plans/` |
| 3 | Castle verification gates | `w61-castle-bin-gate.md` (CASTLE_BIN at pinned SHA), `w67-castle-combined.md`, `w380-castle-kernel-witness.md` (DoD 1 opt-in class evidence) |
| 4 | Refusal-suite capstone run | `w236-refusal-capstone.md` — verbatim "Result: 86 passed" across 12 refusal-negative suites, pinned asdf toolchain, MIX_ENV=test |
| 5 | Art.12 audit chain | `w503-art12-audit-chain.md` — Def 4.2 chain + Thm 4.1, `test/xaas/witness/audit_chain_test.exs` |
| 6 | PW suite re-mint cadence | `w471-pw-remint.md` — load-gated mint, **96 passed / 0 failed / 2 typed stripe skips (33.6s)**, load-avg gate (<10) documented pre-mint |
| 7 | Contest cadence (anti-vacuity) | `w382-anti-vacuity-r2` + w414 (recorded in ledger notes): 2/3 mutants killed, survivor killed by w414, "Anti-vacuity gaps: 0 open" — the court attacking its own tests |

## Cross-examination exposure (typed limitations — what a plaintiff can probe)

1. **Receipts integrity-hashed, not all ML-DSA-signed.** `w510-mldsa-signing.md`
   standing is PARTIAL_ALIVE: ML-DSA-65 runtime signing witnessed through OpenSSL
   CLI subprocess (FIPS 204) over a single test path; engine-side
   (`ash_affidavit` wasm) `ML_DSA65` sign/verify is UNSUPPORTED at the pinned
   ABI; the drop-in seam is documented, not closed. Non-repudiation for the whole
   corpus is hash-based until the engine op lands.
2. **End-user disclosure surface unbuilt (OS-16).** `w525-title-vi-xiii.md:15`
   records Art 86 (86.2/86.3) as OPEN_GAP — the end-user-facing explanation
   surface does not exist on disk; transparency duties to end users are not yet
   dischargeable from evidence.
3. **OS-18 tautology witness.** `w466-os-register-check.md:23` records: "w398
   (cited by OS-18 as a serialization dependency, not owning receipt) has no
   standalone receipt file on disk" — confirmed this session (`ls` finds no
   w398* file). Any board statement citing a w398b contest receipt would be
   citing a nonexistent artifact. This map cites only w236/w382/w414/w471, all
   of which exist.
4. **Fitness/drift is PARTIAL_ALIVE.** w511's drift signal is computed over a
   token-game fitness on an in-repo log, not production traces; WASM engine
   exposes alignment fitness only. A plaintiff can probe whether drift monitoring
   has ever fired on real process data.
5. **Refusal mutants: 9/10 killed, 1 structurally-unreachable pair disclosed**
   (ledger counts). 2 refusal classes are tested by structural-unreachability
   argument, not fixture — probeable as under-testing.
6. **Advisory CI gates, not blocking.** `_CLOSURE_RECEIPT.md` W352 flip pass:
   `closure-gates.yml` is YAML-valid but continue-on-error; blocking promotion
   is an operator transition, not yet machine-enforced.
7. **Coordinator legs still PENDING** (`_CLOSURE_RECEIPT.md`): coordinator
   commit, PR/replay-identity, r8 falsifier legs carry explicit PENDING
   markers — the corpus is not self-declared complete.

## What the board can state under oath (derived strictly from cited evidence)

1. A formal information system exists: 329 dated receipt files indexed in
   `docs/sjira/v26.10.6/plans/_INDEX.md`, each citing command, toolchain, and
   verbatim result.
2. The system's data is generated continuously, not assembled: OCEL telemetry
   emitters (`lib/xaas/telemetry/`) capture the governed process as an event
   log at run time.
3. Out-of-bounds actions are refused, not repaired: 62/62 refusal classes
   fixture-covered per `refusal-ledger-v26.10.6.jcs.json`, witnessed by the
   w236 capstone run (86 passed, 0 failures).
4. The monitoring machinery attacks its own tests: anti-vacuity mutation runs
   killed or disclosed every mutant; ledger notes record "anti-vacuity gaps: 0
   open" after w382/w414.
5. An audit chain per Def 4.2 with tamper-negative controls is implemented and
   tested (`w503`, `test/xaas/witness/audit_chain_test.exs`).
6. A Playwright surface suite was re-minted under a documented load gate:
   96 passed / 0 failed / 2 typed skips (w471).
7. An executable rendering of the EU AI Act titles runs as 20 Chicago-style
   tests with a versioned spec corpus loader (`test/eu_ai_act/`).
8. The board's own index distinguishes ALIVE / PARTIAL_ALIVE / UNSUPPORTED and
   PENDING explicitly (`_INDEX.md`, `_CLOSURE_RECEIPT.md`) — limitations are
   disclosed in the system's own records, not concealed.
9. An Art.72 fitness/drift decision procedure is implemented and tested
   (w511, 10 passed), with its own PARTIAL_ALIVE limits disclosed in the
   receipt.
10. Integrity anchoring (hash chain) is in place; cryptographic signing
    (ML-DSA-65) is witnessed for a test path only — stated as PARTIAL_ALIVE,
    with the closure seam documented (w510).
