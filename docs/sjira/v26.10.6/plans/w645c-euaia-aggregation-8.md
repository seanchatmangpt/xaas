# W645c — EU-AI-Act aggregation-8 gate + census receipt

- Subject: /Users/sac/xaas @ feat/playwright-surface, HEAD a0723bf61a1c6058bdcd2d0202c9519840182a5e, plus the converged untracked working-tree test tree.
- Lane build root: `_build-laneW645c` (private; seeded: copied `_build/test/lib/ash_a2a` into the lane root — see BLOCKED-B for the defect that made this necessary).
- Contract: writes confined to this file. Zero tree edits made.

## Run evidence (all real, captured in /tmp/w645c_*.log)

| run | command | result |
|---|---|---|
| 1+2 | `mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act/` (twice, retry protocol honored) | BLOCKED at compile: `SyntaxError test/eu_ai_act/title_iii_test.exs:233:7 — syntax error before: "27.3"` |
| 3 | same, minus `title_iii_test.exs` | `Result: 728 passed` / 0 failed / 0 skipped |
| 4 | same minus title_iii, WITHOUT `--exclude eu_ai_act_open_gap` | `Result: 728 passed` (open-gap-tagged tests are include-gated; identical set) |
| 5 | minus title_iii, `--include eu_ai_act --include eu_ai_act_open_gap` | `725/728 — 3 failed` (see FINDING-B) |
| 6 | counterfactual file isolated, 3 consecutive runs | `26 passed` x3 (stable green) |

## BLOCKED-A (converged-tree syntax defect, coordinator-owned)

`test/eu_ai_act/title_iii_test.exs` is UNTRACKED (`git status` → `??`) — an uncommitted
sibling-lane working-tree write. Line 232/233 boundary: the `"27.1.f"` evidence-map entry's
closing `}` is followed directly by `"27.3" =>` with **no comma**. Deterministic SyntaxError,
reproduced twice; retry protocol (2 min + rerun) exhausted — not transient.

Exact fix (one character, owner = whichever lane wrote the file, attribution W537/W507/W648b):
insert `,` after the `"27.1.f"` entry's closing `}` at end of line 232
(after `..."docs/sjira/v26.10.6/plans/w537-art26-27-governance.md"]}`).

Consequence: title_iii_test.exs (19 tests, 1129 lines) does not compile; the full-directory
green gate and the compile-derived open-gap test count are uncertifiable until fixed.

## BLOCKED-B (fresh build root cannot compile ash_a2a at the converged tree)

Any FRESH `MIX_BUILD_ROOT` fails `mix deps.compile ash_a2a`:
`cannot build released AgentCard: :capability_release_closure_missing` at compile time of
`AshA2A.Chicago.Bench.B11Wire.WidgetAgent` (b11_wire.ex:41, `use AshA2A.Agent` builds the
AgentCard at compile time). Mechanism: xaas config sets `capability_release_mode: :strict`
(config/test.exs:156, dev.exs:523, runtime.exs: permanent) with **no
`capability_release_closure` configured anywhere in config/**, so the dep's own compile-time
card build refuses. Existing roots (e.g. `_build/test`, compiled 2026-10-06 13:29) hold a
pre-strict ash_a2a; every fresh root (and CI, and the crown replay) will hit this.
Suggested owner: W701 (which landed the strict config lines).

## FINDING-B (flaky under full-dir concurrency)

Three tests in `test/eu_ai_act/counterfactual_test.exs` fail ONLY when the whole directory
runs with open-gap tests included (run 5): all assert `refusal_anatomy != []` but observe `[]`:
- `counterfactual_test.exs:401` (Art 14(4)(b) refusal briefing)
- `counterfactual_test.exs:864` (Art 14(4)(b) extension, REFUSED_STOP_AUTHORITY)
- `counterfactual_test:898` (Art 14(4)(a) degradation-with-signal)

They pass in the gate run (open_gap excluded) and 3x file-isolated — a real
concurrency-interference signal (both test names claim "deterministically"; observed
nondeterministic under async load). Not flaked away: recorded per-title attribution above.

## Open-gap census (static, compile-count blocked by BLOCKED-A)

Open-gap tests are `flunk`-based, generated from typed data rows; count is compile-derived
only after BLOCKED-A is fixed. Static census of typed `:open_gap` rows:

- `title_i_test.exs` — 0 (comment: "Title I now has ZERO typed open gaps")
- `title_ii_test.exs` / `airo_grounding` / `smoke` / `counterfactual` — 0 tagged rows
- `title_iv_v_test.exs` — @open_gaps map-driven rows (map at ~:381, inline at :419)
- `title_vi_xiii_test.exs` — 4 declared gap classes (Art 73, 99.4.e, fallback) — inline rows at :84/:97/:117/:149
- `title_3` (`title_iii_test.exs`) — inline rows at :661/:676; comment says only 8.1 (Title III) remains — but this file does not compile, so its exact count is UNKNOWN

Static total ≈ 7-9 typed open-gap rows vs the ~10-15 expectation; the exact number is
UNKNOWN (compile-count blocked by BLOCKED-A). No test tagged with the open-gap tag was
skipped-and-passed: the 3 reds in run 5 are genuinely failing under load, not soft passes.

## Verdict

**BLOCKED(SYNTAX_DEFECT_CONVERGED_TREE)** — cannot certify EVERY-LINE-TESTED + SUITE-GREEN
at the full converged tree. What IS certified at exact tree a0723bf6 + working tree:
- Every line OUTSIDE `title_iii_test.exs`: SUITE-GREEN (728/728 gate; 728/728 census-1)
- `title_iii_test.exs`: UNTESTABLE (does not compile) — 19 tests / 1129 lines untested
- 3 concurrency-flaky counterfactual tests, per-title attributed
- Static open-gap census ≈ 7-9 rows, exact compile-count UNKNOWN pending BLOCKED-A fix

Replay: commands in the table above; full logs at /tmp/w645c_gate.log, /tmp/w645c_gate_noiii.log,
/tmp/w645c_census.log, /tmp/w645c_census2.log.
