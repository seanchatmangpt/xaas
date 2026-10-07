# W984al — Corpus evidenced-line deepening wave 5 (2 lines, 6 courts)

Lane W984al · xaas v26.10.6 campaign · repo `/Users/sac/xaas` @
`feat/playwright-surface` (uncommitted campaign tree; no commit per
dispatch). Build root `_build-laneW984al` — cold compile, pinned asdf
toolchain (PATH=$HOME/.asdf/shims), `MIX_ENV=test`. **Build root DELETED
at integration** (rm -rf succeeded this time) per the fanout cleanup law.

## Gap-inventory provenance

Receipts read fresh before picking: `w981t-corpus-deepening.md` (26.6 /
14.4.b / 15.5.s3), `w982z-corpus-deepening-2.md` (26.7, 27.1.c/d),
`w984a-corpus-deepening-3.md` (10.2.h / 10.3; also names W984p's 26.9 and
26.1), plus the dispatch's taken-list (27.3, art50 W665, 15.3 W658c/W697,
title-II W691, counterfactual 13.x/86.1, art73 W669b/W538, eyerun
15.5/15.5.s2, art15 W667, art99). The census directory was listed fresh:
two sibling files (`art_26_2_human_oversight_assignment_test.exs`,
`art_26_5_operation_monitoring_egress_test.exs`) landed mid-lane from
lanes W984be/W984p-family — their lines (26.2, 26.5) treated as taken.
Picked lines are EVIDENCED (corpus evidence map, `title_iii_test.exs`),
had no deepening court, and are not GraphQL-adjacent:

| line | article requirement | implementing surface | court | mutation rationale |
|---|---|---|---|---|
| 9.4 | combined-application effects of AI systems considered (Art 9(4)) — evidence lane W322, zero-config posture audit | EXECUTED env-invariance of the real gate family: `DatasetAdmission.admit/2` + `RobustMargin.admit/4` + `EuAiActAdmission.admit/1` return identical verdicts under a hostilely-seeded ambient application env (11 knob names a regression would introduce, hostile VALUES) vs clean env | `test/xaas/deepening/art_9_4_zero_config_env_invariance_test.exs` (3 courts) | a gate starts reading the ambient env in its safety path (the w322 anti-selling finding class) → hostile-env verdict diverges and all 3 courts fail, while every existing single-verdict court passes (none sets a knob first). Distinct from W984a's eta-flip court: that flips with a CALL-ARGUMENT change, these flip NOTHING under an AMBIENT-ENV change |
| 13.3.e | resources/lifetime/maintenance recorded in instructions (Art 13(3)(e)) — evidence "docs+W322": pinned toolchain | LIVENESS of the pin: the BEAM actually executing the tree (`System.version/0`, `:erlang.system_info(:otp_release)`) matches the `.tool-versions` elixir/erlang pins, the declared `-otp-` pairing is coherent, and the pinned runtime actually executes the gate family | `test/xaas/deepening/art_13_3e_live_toolchain_pin_test.exs` (3 courts) | an unpinned/shadowed toolchain runs the tree (a witnessed fleet failure class: homebrew elixir shadows asdf), a stale pin after a toolchain bump, or an elixir/OTP pairing drift → the live-vs-pin equality fails while `toolchain_court_test.exs` (W704) still passes — those courts read only the FILE and CI wiring, never the executing VM |

## Verification (real tails)

Cold-lane build; census command, run ×2 green (different ExUnit seeds):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984al \
  mix test test/xaas/deepening/ --include eu_ai_act --exclude eu_ai_act_open_gap
```

- Run 1 (seed 841677): `Result: 36 passed` — exit 0
- Run 2 (seed 734813): `Result: 36 passed` — exit 0

(36 = prior 30 + this lane's 6. Single-file run before the census:
`Result: 6 passed` for the two new files.)

Disclosed repair history (genuinely-new contract facts learned and folded
into the courts):

1. Run 1 of the new files failed 4/6: (a) single-feature alternating-group
   populations are NOT bias-free under the W1 gate (odd/even feature
   interleaving gives W1 ≈ 0.5–1.0 > 0.1) — fixtures rebuilt as PAIRED
   samples with identical per-group feature multisets (W1 = 0); (b)
   `:erlang.system_info(:otp_release)` returns the major line "28", not
   the full pin "28.5.0.2" — court 2 asserts the live line is on the
   pin's line (`starts_with?(pin, live <> ".")`), and the elixir pin's
   declared `-otp-` line must equal the live line.
2. A post-sweep dead variable (`l_e`) warning was folded in (court 3
   sweeps l_e too).

## Disclosed minimal sibling-lane fixes (compile-freeze SLA)

`test/xaas/deepening/art_26_5_operation_monitoring_egress_test.exs`
(lane W984be, line 26.5) failed 1/3 deterministically in every census run
(witnessed ×3), blocking the census gate:

1. `[first, rest] = Enum.split(lines, 1)` — `Enum.split/2` returns a
   `{prefix, suffix}` tuple, not a list; MatchError every run. Fixed to
   `{[first_line], rest} = Enum.split(lines, 1)` with the tamper logic
   adjusted (`String.replace` on the single line, `[tampered_first | rest]`).
2. `verify_chain(tampered_chain) == {:error, {:tampered, 0}}` — a chain
   REBUILT from tampered content is internally self-consistent and is
   `:ok` by the module's documented contract; tamper evidence against the
   pre-tamper head rides the documented `expected_head` last-link check.
   Fixed to build `original_head` from the pre-tamper chain and assert
   `verify_chain(tampered_chain, expected_head: original_head) ==
   {:error, {:tampered, :head}}`.

Intent preserved (tamper-evident egress), all other assertions unchanged;
after fix the file is 3/3 and the census went green ×2. No mocks
introduced; lib/ untouched by these fixes.

## Tagging convention

Both new files carry `@moduletag :eu_ai_act`; runs used `--include
eu_ai_act --exclude eu_ai_act_open_gap`, the census command. No
`eu_ai_act_open_gap` tags — no line flipped; this lane deepens
already-evidenced lines only.

## Standing

- New courts: **ALIVE** — observed execution on the exact lane subject,
  6/6, census 36/36 ×2 (seeds 841677, 734813), real commands + real exits.
- `_build-laneW984al`: **deleted** by this lane at integration (cleanup
  law satisfied; unlike W981t/W982z/W984a whose rm -rf was denied).
- Real contract facts witnessed (worth retaining): sliced-W1 on
  interleaved (non-paired) sensitive groups over correlated features is
  ~0.5–1.0 even when groups "interleave" — bias-free fixtures must pair
  identical feature multisets; `:erlang.system_info(:otp_release)` is the
  major line ("28"), never the full asdf pin ("28.5.0.2"); a rebuilt
  audit chain over tampered content verifies `:ok` internally —
  tamper-evidence vs a prior state requires `expected_head`.
- Census is a shared moving surface: sibling files landed mid-lane
  (26.2, 26.5); the 36/36 result is as-of these runs (receipt-cited
  counts re-read at use time per no-overclaiming).
- Not done (typed): no line flips, no lib edits, no corpus edits —
  test/ + receipt only, per this lane's contract (the two disclosed
  sibling-file fixes are confined to the one sibling test file).
