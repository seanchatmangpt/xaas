# W670 — EU-AI-Act gate rerun receipt (W645c gap closure attempt)

- **Subject**: /Users/sac/xaas @ `a0723bf61a1c6058bdcd2d0202c9519840182a5e`, branch `feat/playwright-surface`
- **Date**: 2026-10-07
- **Contract**: run-only; no source files edited. Log: /tmp/w670_gate.log (54k+ lines).
- **Build-root note (BLOCKED-B, reproduced)**: fresh lane build root
  `_build-laneW670` fails `mix deps.compile ash_a2a`
  (`lib/ash_a2a/bidi/plug.ex` CompileError) under strict capability_release_mode
  (config/test.exs:156). Per W645c precedent, copied pre-strict
  `_build/test/lib/ash_a2a` (ebin+priv) into `_build-laneW670/test/lib/ash_a2a`
  (build-root only, no tree change). Recorded, not fixed.

## Runs

| # | Command | Result |
|---|---------|--------|
| 1 | `mix test test/eu_ai_act/title_iii_test.exs --include eu_ai_act` | **390/391 passed, 1 failed** (exit 1). 4.3s async. |
| 2 | `mix test test/eu_ai_act --exclude eu_ai_act_open_gap` (as specified in task) | 33 passed, 1120 excluded (exit 0) — see note below |
| 3 | `mix test test/eu_ai_act --include eu_ai_act_open_gap` (as specified) | 33 passed, 1120 excluded (exit 0) — identical; tag `eu_ai_act_open_gap` is not globally excluded, so `--include` alone is a no-op |
| 2' | **Corrected gate**: `mix test --include eu_ai_act --exclude eu_ai_act_open_gap test/eu_ai_act` | **BLOCKED at compile** (exit 1): `SyntaxError test/eu_ai_act/title_ii_deepening_test.exs:204:26 — syntax error before: ']'` (`{:ok, chain0 = [%r0], h0} =`) |
| 3' | Corrected census: `mix test --include eu_ai_act test/eu_ai_act` | **BLOCKED at compile**, same SyntaxError (exit 1) |
| 4 | `mix test test/eu_ai_act/counterfactual_test.exs:{401,864,898} --include eu_ai_act`, 3 file-isolated runs | **3/3 passed, exit 0, all three runs** |

### Why runs 2/3 as literally specified are vacuous

`test/test_helper.exs:56` globally excludes `:eu_ai_act`; the suite only runs
under `--include eu_ai_act`. The task's step-2/3 commands omit that include, so
only the 33 untagged tests ran and the 1120 tagged tests were excluded in both
directions. The corrected runs 2'/3' are the real gate/census; both are
compile-blocked.

## Findings

1. **title_iii_test.exs parses and runs** (W645c BLOCKED-A confirmed resolved):
   390/391 pass. The single failure is a real content failure, not syntax:
   - `test/eu_ai_act/title_iii_test.exs:766` — "EUAI-ACT 15.5.s3 — EVIDENCED
     (W540)": expects
     `{:ok, %VulnerabilityLifecycle{state: :RESPONDED}}` from
     `VulnerabilityLifecycle.respond(ticket, %{receipt: "diff w540 fix"})`,
     got `{:error, :REFUSED_LIFECYCLE_SKIP}` (deepen chain at
     title_iii_test.exs:1032/814). Pre-existing on this HEAD; not fixed
     (outside contract).
2. **New gate blocker (W670)**: `test/eu_ai_act/title_ii_deepening_test.exs:204:26`
   SyntaxError — `[%r0]` is not valid Elixir pattern syntax (looks like a
   `%r0` struct-pin typo, likely intended `%R0{}` or a bare `r0` binding).
   The W645c green-run claim ("every line OUTSIDE title_iii_test.exs:
   SUITE-GREEN 728/728") is **stale at this HEAD**: the suite cannot compile
   today. Pre-existing; not fixed (outside contract).
3. **Census / open-gap count**: uncertifiable at this HEAD (compile-blocked).
   Tag census from file scan (non-executed): `@moduletag :eu_ai_act_open_gap`
   is module-level in title_i_test.exs and siblings; exact runnable count
   requires the compile fix.
4. **Counterfactual flakes (W645c lines ~401/864/898)**: **not reproducing** —
   3/3 passed in each of 3 file-isolated runs. Verdict: stable on this HEAD
   under file isolation.

## Standing

- Run 1 (title_iii file): **PARTIAL_ALIVE** — file parses and 390/391 pass;
  1 content failure open (15.5.s3 lifecycle skip).
- Gate/census (runs 2'/3'): **BLOCKED** — title_ii_deepening_test.exs:204
  SyntaxError.
- Flakes: **ALIVE-NOT-REPRODUCING** (3x green).
- No receipted fix: all defects disclosed, none repaired (run-only contract).

Replay: commands in the table; full log /tmp/w670_gate.log. Lane build root
`_build-laneW670`: `rm` denied by permission system — LEFT ON DISK for
coordinator cleanup (contains the copied ash_a2a artifacts; per lane lease law
the coordinator should delete it).
