# W984ax — eu_ai_act gate re-witness on the current tree (post-W984ao graphql removal check)

Date: 2026-10-07 · Repo: /Users/sac/xaas · Branch: feat/playwright-surface @ 5f7f70d9
Lane: W984ax, xaas v26.10.6 campaign. Read-only witness lane: no commit, no source
modifications. Writes: this receipt only. Lane build root `_build-laneW984ax` deleted on
exit.

## Verdict

**ALIVE — PASS.** Gate holds: **1352 passed / 0 failed / 1 excluded**, exit 0,
identical to the certified census (gate w982w: ≥1352 passed / 0 failed). The graphql
removal work (W984ao, mid-flight) has not perturbed the eu_ai_act corpus.

## Subject

- Working tree at HEAD `5f7f70d9` with 182 dirty files (W984ao graphql-removal edits
  in flight among them). Method: **working tree** (no scratch-HEAD fallback needed).
- Toolchain: asdf elixir 1.20.2-otp-28 / erlang 28.5.0.2 (pinned, PATH shimmed).
- Isolation: `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ax` (private lane build root).

## Execution

1. `mix compile` — exit 0, "Generated xaas app" (no mid-edit compile abort; retry
   ladder unused). Concurrent lanes W984ao/W984bc were compiling on the same tree
   during this window; no interference observed.
2. Gate command (identical to W981x/w982w):

   ```
   PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984ax \
     mix test test/eu_ai_act --include eu_ai_act --exclude eu_ai_act_open_gap
   ```

   Real tail: `Excluding tags: [:eu_ai_act_open_gap, :stress, :kind, ...]` →
   `Finished in 17.5 seconds (16.8s async, 0.6s sync)` → **`Result: 1352 passed,
   1 excluded`**, exit 0. Full log: `/tmp/w984ax-run.log`.

## Classification note

0 failures — no failing-file rerun required.

## Standing

ALIVE (single witnessed run on the exact current subject, real exit 0 tail).
Corpus graphql-independence: **confirmed** — the gated count, exclusions, and runtime
are unchanged from the W981x census at 6f235905.

## Falsifier status

Falsified-counter held: had the run returned ≠1352 passed or any failure, the removal
would be marked corpus-perturbing. Not observed.
