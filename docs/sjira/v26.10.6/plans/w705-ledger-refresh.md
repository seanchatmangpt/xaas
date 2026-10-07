# W705 — Refusal Ledger Refresh (v26.10.6)

- **Lane**: W705, xaas v26.10.6 campaign
- **Subject**: /Users/sac/xaas (canonical checkout), branch `feat/playwright-surface`, HEAD `a0723bf61a1c6058bdcd2d0202c9519840182a5e`, no commit (coordinator owns integration)
- **Artifact**: `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` (only in-repo write besides this receipt)
- **Method**: ledger schema read; each cited receipt read in full before its entry was appended; canonical JCS via `Xaas.Semantics.Jcs` (`mix run` under `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW705`)

## Per-entry provenance (8 new entries, each source receipt read first)

| # | variant | source receipt | kill class | witness (real output) |
|---|---|---|---|---|
| 1 | REFUSED_MALFORMED_MARGIN_INPUT | plans/w676-margin-hardening.md, mutation check 1 | mutant KILLED | guard removal → 10/12, 2 × CaseClauseError; restored, 37/37 green. Same gate re-asserted by w640 FLIP-1 (8 malformed quads ×2 deterministic) |
| 2 | REFUSED_ARITHMETIC_OVERFLOW | plans/w676-margin-hardening.md, mutation check 2 | mutant KILLED | W630 rescue arm mutated to `raise ArithmeticError("mutated")` → 6/7, overflow regression test fails; restored green. Also witnessed typed by w640 probes P4a/P4b ×2 and the w676 extreme-float (1.0e308) regression test |
| 3 | REFUSED_EUAIA_MANIPULATIVE | plans/w703-plug-order-court.md | mutant KILLED (reorder) | reordered composition executed live (test d, Plug.Conn level, endpoint.ex unmutated) — halted Art-5 refusal envelope ships UNMARKED; test (c) pins endpoint.ex:99-100; 4/4 green |
| 4 | REFUSED_LIFECYCLE_SKIP | plans/w659d-lifecycle-fixes.md, fix 1 (counterfactual_test.exs) | assertion-witnessed | typed refusal + determinism (`e1 == e2`) + lifecycle invariant (lattice ranks non-decreasing, `walk == Enum.sort(walk)`, refused skip = no completed edge); no mutation run |
| 5 | REFUSED_LIFECYCLE_EVIDENCE | plans/w659d-lifecycle-fixes.md, fix 2 (title_iii deepen_kind :vuln_lifecycle) | assertion-witnessed | happy walk → `{:ok, RESPONDED}` with forward history tail; `respond/2` from lawful TRIAGED with `%{}` → `{:error, :REFUSED_LIFECYCLE_EVIDENCE}`; 26 passed ×2, no collateral (241 passed semantics dir) |
| 6 | REFUSED_BIAS_THRESHOLD | plans/w640-os21-verify.md, FLIP-2 + probe P2 | assertion/probe-witnessed | fuzz suite 9/9; `{:error, {:REFUSED_BIAS_THRESHOLD, %{epsilon_bias: 0.5, w1_proxy: :inf}}}` ×2 deterministic |
| 7 | REFUSED_REQUIRED_FIELD_MISSING | plans/w653b-binary-leg.md | external-binary run witnessed | real eyerun_wasi release binary (`/tmp/w653b-target/release/eyerun_wasi`, 628,928 B) — violating candidate → `{"verdict":"REFUSED","code":"REFUSED_REQUIRED_FIELD_MISSING"}` exit 0; ADMITTED pair witnessed on satisfying candidate; title_iv_v 65 passed with binary present via symlink |
| 8 | REFUSED_INFRASTRUCTURE_FAULT | plans/w653b-binary-leg.md | external-binary run witnessed | malformed candidate (truncated JSON) → `{"verdict":"REFUSED","code":"REFUSED_INFRASTRUCTURE_FAULT"}` exit 0; 65 passed with binary present |


## Totals before / after

| field | before | after |
|---|---|---|
| variants array length | 63 | 71 |
| counts.declared | 62 (stale — array already held 63; corrected, note appended in ledger) | 71 |
| counts.fixture_covered / coverage | 62 / "62/62" | 71 / "71/71" |
| counts.mutant_kill_verified | 9 | 12 (9 prior verified + 3 new witnessed kills) |
| counts.mutation_runs | 10 | 13 |
| counts.structurally_unreachable | 2 | 2 |
| mutant_kill_evidence.constructed / killed / survived | 6 / 4 / 2 | 9 / 7 / 2 |
| per_mutant | mutants 1–6 | mutants 1–9 (7 = margin guard, 8 = overflow rescue arm, 9 = plug reorder) |

## Hash transition (sha256 over canonical JCS via Xaas.Semantics.Jcs)

1. `sha256:d90b66c4b670e7dd15baebeb7ed015a7b3c303488ef651236f526a5db759daa9` — original (17,590 B)
2. `sha256:2b02f952da82661c12067a1789f8e8840a907985697a11c67d9e01b55371cbec` — intermediate: 8 entries appended, subject pinned to a0723bf6, but stale 62-declared counts block
3. `sha256:96d539c200b284d131552b92924b98a4fe52c2157abe455ea6c8e672bedf2d9e` — FINAL (24,470 B, re-verified twice post-write): counts recomputed from the array (71/71), re-encode round-trip reproduces the hash exactly

## Standing

- Ledger: ALIVE — 8/8 appended entries carry receipt-cited witnesses; subject re-pinned d1db2b03 → a0723bf6; JCS round-trip verified on the exact final bytes.
- `mutant_killed` vocabulary preserved exactly: `true` = witnessed mutation run (3 new), `false` = assertion/probe/binary-run witnessed per receipt (5 new), `null` = fixture-presence only (unchanged entries). `mutant_kill_evidence.note` updated to define the extension.
- Kill-class honesty: w659d/w640/w653b entries are recorded as witnessed runs/assertions, NOT mutation kills — no mutation run exists in those receipts.
- Pre-existing stale counts (62 vs 63 actual) found and corrected; correction note appended in ledger `notes`.
- Falsifier: re-encode the ledger bytes with Xaas.Semantics.Jcs and sha256 — must yield `96d539c2…f2d9e`; any drift means the artifact was hand-edited post-refresh.

## Cleanup

- `/tmp/w705_update.exs`, `/tmp/w705_fix_counts.exs` scripts left in /tmp (lane scratch).
- `_build-laneW705` NOT deleted: the `rm -rf` was denied by the session permission system (three attempts). Coordinator should delete `/Users/sac/xaas/_build-laneW705` at integration per the fanout cleanup law.
