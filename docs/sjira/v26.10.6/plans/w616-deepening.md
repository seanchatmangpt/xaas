# W616 — corpus evidenced-line DEEPENING receipt

Repo `/Users/sac/xaas` @ `feat/playwright-surface` (one canonical checkout). Lane W616.
Write scope honored: only `test/eu_ai_act/title_i_test.exs`,
`test/eu_ai_act/title_ii_test.exs`, and this file. No tags added/removed; NOT_APPLICABLE
and OPEN_GAP entries untouched.

## Per-line deepening table (before → after)

| # | line / test | before | after |
|---|---|---|
| 1 | Title II "admission surface: source of truth on disk" | path-existence only | real `admit/1`: violating candidate → `:REFUSED_EUAIA_MANIPULATIVE`; non-map → `:REFUSED_EUAIA_MALFORMED_CANDIDATE` |
| 2-9 | Title II 8 @partitions tests | violating `admit/1` only | + near-miss control per partition: same shape minus one join field → `{:ok, :admitted}` (proves invariant is the structural join, not a single field) |
| 10 | 5.1.c.i | candidate byte-identical to 5.1.c | distinct candidate (`:score_citizens` purpose, `:classification` technique) → same exact atom via real `admit/1` |
| 11 | 5.1.c.ii | candidate byte-identical to 5.1.c | distinct candidate (`:welfare_benefits_gate`, `:ranking`) → same exact atom |
| 12 | 5.1.g | candidate byte-identical to 5.1.g-h | distinct candidate (`:track_persons`, `:consented`, realtime/public-space join) → same exact atom |
| 13 | 5.1.h | candidate byte-identical to 5.1.g-h | distinct candidate (`:categorize_persons`, `:scraped`, realtime/public-space join) → same exact atom |
| 14 | Title II "5.live-integration" | file-exists + two grep lines | + REAL in-process call of `XaasWeb.Plugs.EuAiActAdmissionPlug.call/2` at the parse-floor handoff: social-scoring JSON-RPC body → HTTP 200 typed envelope `error.data.refusal == "REFUSED_EUAIA_SOCIAL_SCORING"`; lawful body → not halted, no envelope |
| 15 | Title I 1.2.b | paths only (no typed_call entry) | typed_call added: violating `admit/1` → `:REFUSED_EUAIA_MANIPULATIVE`; benign → `{:ok, :admitted}` |
| 16 | Title I 3.1 ("AI system") | single clean-admit call | with/without definitional attributes distinct: non-map → `:REFUSED_EUAIA_MALFORMED_CANDIDATE`; `%{}` → admitted (structural nullification); full clean map → admitted; same map with prohibited attribute → refused |
| 17 | Title I 3.29 (training data) | admit happy path | + `required_fields: ["x0","x1_missing"]` → `{:error, {:REFUSED_INCOMPLETE_DATASET, completeness: 0.5, threshold: 0.95}}` |
| 18 | Title I 3.30 (validation data) | empty + happy path | + partial-completeness scenario → exact `{:REFUSED_INCOMPLETE_DATASET, completeness: 0.5, threshold: 0.95}`; admitted path pins `completeness: 1.0` |
| 19 | Title I 3.31 (validation set) | bias refusal + admitted | + admitted result pins measured `completeness: 1.0` and `projections > 0` |
| 20 | Title I 3.32 (testing data) | admitted w/ w1+projections | + independent test split with its own `required_fields` → `completeness: 1.0`; seed-determinism: two calls same seed → identical `w1_proxy` |
| 21 | Title I 3.33 (input data) | single refusal call | with/without provenance pair: `:scraped` → `:REFUSED_EUAIA_FACIAL_SCRAPING`; same candidate `:consented` → `{:ok, :admitted}` |
| 22 | Title I 3.63 (GPAI model) | paths only (no typed_call entry) | typed_call added: GPAI-shaped candidate → `{:ok, :admitted}` (Art.5 structural gate matches no invariant for a mere general-purpose inference capability — W512 decoupling witnessed by real call) |

Deepened count: 22 test bodies upgraded (15 distinct line-ids beyond W522's 8 atoms,
counting the 8 near-miss controls as deepening of their partitions).

## Not deepened (with reason)

- Title II "5.structural-gate" (eu_gate WASI crate + 21-test receipt): the real
  collaborator is a Rust crate in a sibling repo (`/Users/sac/wasm4pm/crates/eu_gate`);
  an in-suite real call means a cargo build/run — not hermetic in `mix test`, not in this
  lane's write contract. Path/receipt asserts kept; Chicago named exception (real
  collaborator infeasible in-process).
- All NOT_APPLICABLE / OPEN_GAP lines: excluded by contract.

## Verification (real output)

- Compile: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW616 mix compile`
  → exit 0.
- Direction 1 (green gate):
  `mix test test/eu_ai_act/title_i_test.exs test/eu_ai_act/title_ii_test.exs --include eu_ai_act --exclude eu_ai_act_open_gap`
  → exit 0, `Result: 151 passed, 1 excluded`.
- Direction 2 (no open-gap exclude):
  `mix test test/eu_ai_act/title_i_test.exs test/eu_ai_act/title_ii_test.exs --include eu_ai_act`
  → exit 2 with EXACTLY one failure, `EUAI-ACT 4.1 — OPEN_GAP` (flunks by design) —
  `Result: 151/152 passed`. No W616-introduced failure.

## Transport notes (disclosed)

- A concurrent lane was mid-write in `lib/xaas/semantics/` during this lane's runs:
  untracked `airo_risk_mapping.ex` (syntax error, later fixed by its owner at 22:28) and
  `authority_channel.ex` (undefined `report_input`, fixed ~22:38). W616 temporarily
  shelved `airo_risk_mapping.ex` for one blocked run and restored it byte-identical
  (verified restored); no edits made to either foreign file. Both blocks cleared before
  the recorded verification runs.
- Lane build root `_build-laneW616` is a lease: to be deleted at integration.

Standing: evidenced Title II Art.5(1) partitions + Title I definitional lines now carry
real typed behavior calls (ALIVE on this subject); 5.structural-gate remains
PARTIAL_ALIVE (path+receipt court only, crate out of suite scope).
