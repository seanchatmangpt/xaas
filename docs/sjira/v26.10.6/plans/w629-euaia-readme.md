# W629 — EU AI Act suite README (receipt)

Lane W629 · repo `/Users/sac/xaas` @ `feat/playwright-surface` ·
lane build root `_build-laneW629` (lease) · asdf pinned toolchain
(`PATH=$HOME/.asdf/shims:$PATH` → elixir 1.20.2-otp-28).
Contract write set honored: `test/eu_ai_act/README.md` (NEW) + this receipt.

## Diff

- `test/eu_ai_act/README.md` — NEW, handwritten (no generator capability for
  documentation). Contents: suite definition (1068 corpus lines → one Chicago
  test per line_id, three typed verdicts EVIDENCED / NOT_APPLICABLE /
  OPEN_GAP), green-gate + honest-census run commands (verbatim from the
  landed receipts W526/W523/W605, build root swapped to `_build-laneW629`),
  the W523 exclude-before-include tag trap and per-test tagging discipline,
  per-title file map, corpus→generator extension pattern, W551 mutation
  protocol, and the census headline.

## Verification (real runs, lane root `_build-laneW629`)

Two transport failures were recorded before the green run, both foreign-lane
mid-write state on the shared tree, both waited out (not repaired by this
lane; outside the write contract):

1. First run: `lib/mix/tasks/xaas.release_audit.ex` mid-write SyntaxError
   (unclosed delimiter) — poll loop until `Code.string_to_quoted!/1` parsed
   CLEAN (2 polls).
2. Second run: `test/eu_ai_act/title_vi_xiii_test.exs` compile error
   (`:erlang.//2 inside a match` in the 72.1 test) — file was being rewritten
   by the Art-72/73 deepening lane (mtime 23:08); mtime-stability poll, then
   rerun after settle.

Green gate (exit 0):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW629 \
  mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap

Result: 1100 passed, 10 excluded
exit=0
```

Honest census (exit 2 by design):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW629 \
  mix test test/eu_ai_act --include eu_ai_act --include eu_ai_act_open_gap

Result: 1100/1110 passed
Failed: 10 tests
exit=2
```

Census failures (10) exactly equal the gate's exclusions (10) — every
failure is a tagged OPEN_GAP, zero untagged failures.

## Census headline (cited)

- W605 aggregation: gate 1068/19 excluded, census 1068/1087, 19 gaps.
- W611 coverage final: 0 uncovered corpus lines; 6 documented Title II
  synthetic extras.
- W629 rerun (this receipt): gate 1100 passed / 10 excluded, exit 0;
  census 1100/1110, **10 typed open gaps** (19 → 10 via sibling-lane flips
  that landed after W605).

## File-count claims (verified by `ls`)

7 `.exs` test files + `support/corpus_loader.ex` under `test/eu_ai_act/`;
corpus ground truth re-derived: 1068 line_ids in `docs/eu_ai_act/corpus.json`
(python json parse, not copied).

## Standing

PARTIAL_ALIVE — the README documents a green suite whose commands were
executed on this subject with real output; it will drift as lanes land
(new gaps, new files); the README's own falsifier section names that.
