# EU AI Act Chicago-Test Suite

Executable regulation: every normative line of Regulation (EU) 2024/1689
becomes exactly one Chicago test in this directory. The corpus substrate
(`docs/eu_ai_act/corpus.json`, 1068 lines across 13 titles / 113 articles)
is the source; this suite is its projection. Corpus schema, provenance, and
the test-mapping contract live in
[`docs/eu_ai_act/corpus-README.md`](../../docs/eu_ai_act/corpus-README.md).

## What the suite is

Each corpus `line_id` maps to exactly one test named `"EUAI-ACT <line_id>"`
asserting one of three typed verdicts:

- **EVIDENCED(path)** — a real seam exists; the test executes real code and
  asserts real state (module call, plug call, or `File.exists?/1` on the
  cited path). Never source-text introspection as "evidence".
- **NOT_APPLICABLE(reason)** — the line does not bind xaas (e.g. Member
  State penalty procedure, AI Board machinery, voluntary codes of conduct).
  The reason must name the binding scope and why xaas is outside it.
- **OPEN_GAP** — the line binds and is not yet evidenced. The test `flunk`s
  by design and carries ONLY the `:eu_ai_act_open_gap` tag. These failures
  are the wave's typed work queue, not suite defects.

Definitions (`kind: "definition"`, 80 lines) become typed-vocabulary
assertions; prohibitions (Art. 5) are courted as exact typed refusal atoms
through `Xaas.Semantics.EuAiActAdmission.admit/1`.

## How to run

Run every mix command under the pinned asdf toolchain (Homebrew elixir
shadows asdf; plain `mix` runs 1.19.5).

### Green gate (compliance gate — open gaps excluded by design)

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW651 \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
```

### Honest census (open gaps included — the gap inventory)

```bash
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW651 \
  mix test test/eu_ai_act --include eu_ai_act --include eu_ai_act_open_gap
```

### Tag semantics — the W523 exclude-before-include trap

`ExUnit.Filters.eval/4` applies **exclude before include**. A
`@moduletag :eu_ai_act` on an open-gap test would be *resurrected* by the
gate's `--include eu_ai_act`, so the exclusion would silently never fire
and the green gate would be fake-green. The suite therefore uses per-test
tagging: EVIDENCED and NOT_APPLICABLE tests carry `@tag :eu_ai_act`
(or the suite-structure modules carry `@moduletag :eu_ai_act` where they
contain no gaps); open-gap tests carry ONLY `:eu_ai_act_open_gap` —
deliberately NO `:eu_ai_act` tag (see the comment blocks in
`title_iii_test.exs`, `title_vi_xiii_test.exs`, `title_iv_v_test.exs`).
Three probe files isolated the behavior empirically; it is documented in
the `Xaas.EUAIAct.TitleIIITest` module docstring.

### Suite wiring

`:eu_ai_act` is on the default exclude list in `test/test_helper.exs`
(W526), so the default `mix test` loop stays neutral; the compliance suite
runs explicitly via `--include eu_ai_act`.

## File map (per title)

| File | Module(s) | Corpus title(s) | Pattern |
|---|---|---|---|
| `smoke_test.exs` | `Xaas.EUAIAct.SmokeTest` | — (structure gate: corpus loads, every line has `line_id`/`text`/`kind`, typed-absent path) | handwritten |
| `support/corpus_loader.ex` | `Xaas.EUAIAct.CorpusLoader` | — (loader: `lines/0`, `line/1`, `counts/0`; raises typed `REFUSED(EUAIA_CORPUS_MISSING_W520)` when corpus.json absent) | handwritten |
| `title_i_test.exs` | `Xaas.EUAIAct.TitleITest` + `Xaas.EUAIAct.TitleIOpenGapsTest` | I (Arts 1–4) | generator + separate OpenGaps module |
| `title_ii_test.exs` | `Xaas.EUAIAct.TitleIITest` | II (Art. 5) | handwritten refusal-atom partition suite |
| `title_iii_test.exs` | `Xaas.EUAIAct.TitleIIITest` + `Xaas.EUAIAct.TitleIIIOpenGapsTest` | III (Arts 6–49) | generator |
| `title_iv_v_test.exs` | `Xaas.EUAIAct.TitleIVVTest` | IV+V (Arts 50–55) | generator + W619 real-behavior deepenings |
| `title_vi_xiii_test.exs` | `Xaas.EUAIAct.TitleVIXIII.Lines` compile-time substrate + `Xaas.EUAIAct.TitleVIXIIITest` + `Xaas.EUAIAct.TitleVIXIIIOpenGapsTest` | VI–XIII (Arts 57–113) | generator + separate OpenGaps module |
| `counterfactual_test.exs` | `Xaas.EuAiAct.CounterfactualTest` | — (cross-title do-intervention harness, Pearl 3-step: FACTUAL → ACTION → PREDICTION) | handwritten |
| `airo_grounding_test.exs` | `Xaas.EuAiAct.AiroGroundingTest` | — (W702 AIRo grounding court: every Art. 5 refusal atom grounded to a W601 AIRo risk-graph concept; cited consumer files asserted to exist first) | handwritten |

### Deepening and audit suites in this directory (addendum, W984ja registry audit)

These 16 files live in `test/eu_ai_act/` but predate this file map; registered
here per the W984ja registry audit so the map matches `ls test/eu_ai_act/`.

| File | Module | Scope | Pattern |
|---|---|---|---|
| `art9x_risk_management_deepening_test.exs` | `Xaas.EUAIAct.Art9xRiskManagementDeepeningTest` | Art. 9 risk-management deepening | handwritten deepening |
| `art10_2e_art26_4_dataset_purpose_deepening_test.exs` | `Xaas.EUAIAct.Art10_2eArt26_4DatasetPurposeDeepeningTest` | Art. 10.2e / 26.4 dataset purpose-limitation | handwritten deepening |
| `art11_1_art12x_audit_chain_deepening_test.exs` | `Xaas.EUAIAct.Art11_1Art12xAuditChainDeepeningTest` | Art. 11.1 / 12.x record-keeping + AuditChain | handwritten deepening |
| `art13x_counterfactual_deepening_test.exs` | `Xaas.EuAiAct.Art13xCounterfactualDeepeningTest` | Art. 13.x counterfactual transparency | handwritten deepening |
| `art14x_oversight_deepening_test.exs` | `Xaas.EUAIAct.Art14xOversightDeepeningTest` | Art. 14.x human oversight | handwritten deepening |
| `art15_deepening_test.exs` | `Xaas.EUAIAct.Art15DeepeningTest` | Art. 15 accuracy/robustness | handwritten deepening |
| `art15x_robustness_deepening_test.exs` | `Xaas.EUAIAct.Art15xRobustnessDeepeningTest` | Art. 15.x robustness margin | handwritten deepening |
| `art26x_postmarket_deepening_test.exs` | `Xaas.EUAIAct.Art26xPostmarketDeepeningTest` | Art. 26.x deployer post-market | handwritten deepening |
| `art50_deepening_test.exs` | `Xaas.EUAIAct.Art50DeepeningTest` | Art. 50 transparency | handwritten deepening |
| `art73_chain_deepening_test.exs` | `Xaas.EUAIAct.Art73ChainDeepeningTest` | Art. 73 serious-incident chain | handwritten deepening |
| `art86_rights_deepening_test.exs` | `Xaas.EuAiAct.Art86RightsDeepeningTest` | Art. 86 explanatory rights | handwritten deepening |
| `art99_enforcement_deepening_test.exs` | `Xaas.EUAIAct.Art99EnforcementDeepeningTest` | Art. 99 enforcement | handwritten deepening |
| `counterfactual_deepening_test.exs` | `Xaas.EuAiAct.CounterfactualDeepeningTest` | counterfactual harness deepening | handwritten deepening |
| `title_ii_deepening_test.exs` | `Xaas.EUAIAct.TitleIIDeepeningTest` | Title II Art. 5 refusal-atom deepening | handwritten deepening |
| `eyerun_wire_deepening_test.exs` | `Xaas.EUAIAct.EyerunWireDeepeningTest` | eyerun wire surface | handwritten deepening |
| `not_applicable_completeness_test.exs` | `Xaas.EUAIAct.NotApplicableCompletenessTest` | NOT_APPLICABLE reason completeness gate | handwritten audit |

All carry `@moduletag :eu_ai_act` (gate-included) except `art9x...` which
additionally per-test tags 7 tests with `@tag :eu_ai_act`.

Companion surfaces outside this directory (run under the same doctrine,
same build-root discipline; not part of the per-title corpus projection):

| File | Module(s) | Scope | Pattern |
|---|---|---|---|
| `test/xaas/semantics/admission_fuzz_test.exs` | `Xaas.Semantics.AdmissionFuzzTest` | W621 seeded fuzz (500 adversarial cases/gate x 3 admission gates: EuAiActAdmission, DatasetAdmission, RobustMargin) asserting totality + determinism | handwritten seeded property fuzz |
| `test/xaas/semantics/master_equation_soak_test.exs` | `Xaas.Semantics.MasterEquationSoakTest` | W628 determinism soak (100 iterations x 3 candidate classes = 300 runs, seed 62828; byte-identical run repetition + single soak-level AuditChain of 100 DO receipts) | handwritten soak over the W541 composition court |

Note: corpus Title IV = Art. 50 (transparency), Title V = Arts 51–55 (GPAI).
The brief that described Title IV as Arts 28–39 used a different numbering;
on-disk scope was confirmed by the coordinator (W524 receipt, scope note).

## How to add a title/lines (corpus → generator pattern)

1. New corpus lines land in `docs/eu_ai_act/corpus.json`
   (W520 substrate; regenerate per corpus-README).
2. The per-title generators read corpus.json **at compile time** and emit
   one test per `line_id`, classified through a single ordered `cond`:
   evidence-map hit → EVIDENCED; consolidated-rendering placeholder
   ("Not present after the amendment...") → NOT_APPLICABLE;
   `addressee == "authority"` → NOT_APPLICABLE; then per-title rules;
   default → OPEN_GAP (honest fallback). Because emission is compile-time,
   corpus updates auto-extend the suite — no per-line hand-authoring.
3. New EVIDENCED classifications require both the module and its test file
   on disk (W547 discipline: verify both before each flip) and a flip row in
   the lane receipt's flip table.

## Mutation-falsification protocol (W551)

The counterfactual harness (`Xaas.EuAiAct.CounterfactualTest` rows — six asserted
modules: EuAiActAdmission, DatasetAdmission, AuditChain, RobustMargin,
VulnerabilityLifecycle, AutomationBiasCountermeasure) is falsified by hand-applied
one-line mutants (M1–M6 ledger in
`docs/sjira/v26.10.6/plans/w551-counterfactual-kill-ledger.md`):

1. Worktree clean on the six targets; record baseline run.
2. Apply the one-line edit to `lib/**` (e.g. `if w1 > epsilon` → `if false`).
3. Run the harness + the module's own test file under a private
   `MIX_BUILD_ROOT`; verdict KILLED (exit != 0) / SURVIVED (vacuous clause).
4. Revert byte-exact via inverse edit; `git diff --stat <file>` must be empty.

KILLED = the harness exerts real pressure on the module; SURVIVED = a vacuous
harness clause, recorded as a typed finding, never silently fixed.

### Extension: admission-gate fuzz + OS-21 totality (W621 + W630)

W621 added a second falsification surface: a seeded deterministic fuzz
(500 adversarial cases per gate over the three admission gates, corpus:
unicode/empty/integer keys, 1 MB payloads, 250-deep nesting, ±max-finite
floats, improper lists, non-map inputs) asserting (P1) totality — no raise,
verdict is `{:ok, _}` or `{:error, atom-in-declared-set}` — and (P2)
determinism. Its four executed escapes (FunctionClauseError in
`RobustMargin.admit/4`, Protocol.UndefinedError escapes in
`DatasetAdmission` and `EuAiActAdmission`, badarith float overflow) were
flipped by W630 (OS-21) into typed refusals
(`REFUSED_MALFORMED_MARGIN_INPUT`, `REFUSED_INCOMPLETE_DATASET` /
`REFUSED_BIAS_THRESHOLD`, opaque-leaf wrapping, `REFUSED_ARITHMETIC_OVERFLOW`),
each with a flip-test in `test/xaas/semantics/admission_fuzz_test.exs`
(flip table in `docs/sjira/v26.10.6/plans/w630-totality-fix.md`). Receipts:
`docs/sjira/v26.10.6/plans/w621-admission-fuzz.md`,
`docs/sjira/v26.10.6/plans/w630-totality-fix.md`.

## Current census headline

Latest full aggregation (W605, 2026-10-06,
`docs/sjira/v26.10.6/plans/w605-euaia-aggregation-3.md`): gate 1068 passed /
19 excluded, census 1068/1087 with 19 typed open gaps; coverage audit (W611,
`w611-corpus-coverage-final.md`): **0 uncovered corpus lines** — all 1068
line_ids have a generated, executed test; the 6 extras are the documented
intentional Title II synthetic layer (`5.1.a-manipulative`,
`5.1.a-vulnerability`, `5.1.g-h`, `5.catch-all`, `5.live-integration`,
`5.structural-gate`).

Re-run on this README's own subject (W984ja registry audit, 2026-10-07, on
the shared `feat/playwright-surface` tree; gap lineage: 37 pre-W547 → 24
(W547) → 19 (W605) → 10 (W622/W629) → 5 (W651) → **1 today**):

- **Honest census: 1388/1389 passed, 1 failed = the single remaining
  intentional `:eu_ai_act_open_gap` test, Art. 49.3 deployer EU-database
  registration (`Xaas.EUAIAct.TitleIVVTest`)** — exactly the one
  intentional open gap. **Green gate: 1388 passed, 1 excluded, exit 0.**
  (`art9x...` also per-test tags 7 tests with `@tag :eu_ai_act`.)

Historical aggregation (W651 lane run, 2026-10-06 23:2x–23:4x,
build root `_build-laneW651`, on the shared `feat/playwright-surface` tree
with sibling lanes landing concurrently):

- **First green-gate run: 1112 passed, 5 excluded, exit 0** (suite green at
  run time).
- **Honest census: 1112/1118 passed, 6 failed = the 5
  `:eu_ai_act_open_gap`-tagged failures (4.1, 8.1, 27.1.b/e/f) + 1
  cross-repo drift red (below).** Typed open-gap count was then **5** (down
  from 10 at W622/W629, 19 at W605, 24 at W547, 37 before W547; since
  closed to 1 — see the W984ja re-run above).
- **Disclosed concurrent-landing drift**: between the first gate run and
  the census, a sibling lane's refactor of the external
  `/Users/sac/wasm4pm` `crates/eu_gate/src/lib.rs` (verdict rendered via
  serde `rename_all = "SCREAMING_SNAKE_CASE"`; the literal `"ADMITTED"`
  no longer appears in the source text) broke the W509 55.1.d
  source-text assertion (`assert crate =~ "ADMITTED"`). Re-run gate after
  the drift: 1112/1113, 1 untagged red. This is outside this lane's write
  contract (the crate is in another repo); recorded here as a typed
  cross-repo drift finding, not fixed.

## Falsifier of this README

Any command above going red where the receipt shows green, or the file map
diverging from `ls test/eu_ai_act/`, falsifies this document. Known
cross-repo coupling: `title_iv_v_test.exs` reads
`/Users/sac/wasm4pm/crates/eu_gate/src/{lib,main}.rs` at runtime, so a
drift in that sibling repo falsifies the 55.1.d row of any receipt written
before the drift.
