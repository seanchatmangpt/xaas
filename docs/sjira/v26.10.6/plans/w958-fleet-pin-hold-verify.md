# W958 — Fleet Pin Hold Verify Receipt (W955 §1b)

**Lane**: W958. **Date**: 2026-10-07.
**Authority**: operator dispatch on W955's §1b hold ("w939's fleet pin suites UNKNOWN").
**Coordination**: `w939-fleet-pin-postcommit.md` was NOT landed at run start
(`ls plans/ | grep w939` → only w955/w958 candidates), so the fast-subset branch
of the dispatch executed: 5 of 11 pin suites run in this lane, 6 marked PENDING-w939.

## Subjects

All 5 repos verified at the exact W937 commit SHAs before running
(`git rev-parse --short HEAD` per repo, all matched — real output below):

| repo | HEAD (verified) | W937 commit |
|---|---|---|
| /Users/sac/ggen-marketplace | b58d78541 | b58d78541 |
| /Users/sac/ggen | ba837d743 | ba837d743 |
| /Users/sac/ash_surface | b70da9e1c | b70da9e1c |
| /Users/sac/gymact | 2fa947c | 2fa947c |
| /Users/sac/zcode-cli | 1e40596 | 1e40596 |

## Per-repo matrix (11 rows)

| # | repo | suite | result | tail |
|---|------|-------|--------|------|
| 1 | ggen-marketplace | pytest `tests/test_airo_pin_w687.py` | **GREEN** | `5 passed in 1.35s`, exit 0 |
| 2 | ggen | `bash scripts/check_airo.sh` | **GREEN** | `check_airo: PASS`, exit 0; `618 triples after vocabulary union`; 20 vocabulary-term ok lines |
| 3 | ash_surface | `mix test test/airo_surface_pin_w675_test.exs` (asdf elixir, PATH-prefixed) | **GREEN** | `3 passed`, exit 0 |
| 4 | gymact | `uv run pytest tests/test_airo_w677_pin.py` | **GREEN** | `9 passed in 0.95s`, exit 0 |
| 5 | zcode-cli | `bun test test/airo` | **GREEN** | `9 pass, 0 fail, 64 expect()` across 2 files, exit 0 |
| 6 | beam4pm | — | PENDING-w939 | not run this lane (w939 not landed) |
| 7 | autofde-lab | — | PENDING-w939 | not run this lane |
| 8 | wasm4pm | — | PENDING-w939 | not run this lane |
| 9 | ex4pm | — | PENDING-w939 | not run this lane |
| 10 | ash_pplan | — | PENDING-w939 | not run this lane |
| 11 | ferroplan | — | PENDING-w939 | not run this lane |

Totals: **5 GREEN / 0 RED / 0 BLOCKED / 6 PENDING-w939**.

## Execution notes (real observations)

- ggen-marketplace pytest ran under homebrew Python 3.14.3 / pytest 9.0.3 — green as-is.
- gymact: bare `python3 -m pytest` fails collection (`ModuleNotFoundError: No module named
  'gymact'`; package lives at `src/gymact`); the repo's lawful runner is `uv run pytest`
  (justfile:53), which passed. Bare-python failure is an invocation artifact, not a pin
  defect — classified, not repaired (out of scope).
- ash_surface ran under the pinned asdf toolchain (PATH=$HOME/.asdf/shims prefix).
- No new build roots created; ash_surface compiled into its existing `_build`.
- No commits, no pushes. Only file written by this lane: this receipt.

## Standing

- The 5 fast-subset repos: **ALIVE** at exact W937 subjects (observed execution, real
  tails above, exit 0 each).
- **W955 §1b hold: NARROWED, not cleared.** The hold's UNKNOWN class ("fleet pin suites
  post-commit") is resolved GREEN for 5/11 exact subjects. The hold fully clears only
  when w939's receipt lands covering beam4pm, autofde-lab, wasm4pm, ex4pm, ash_pplan,
  ferroplan (or this lane's successor runs them). Remaining 6 carry no observed failure —
  they are UNKNOWN (unobserved), not RED.

## Replay

```
git -C /Users/sac/ggen-marketplace rev-parse --short HEAD   # b58d78541
cd /Users/sac/ggen-marketplace && python3 -m pytest tests/test_airo_pin_w687.py
git -C /Users/sac/ggen rev-parse --short HEAD               # ba837d743
cd /Users/sac/ggen && bash scripts/check_airo.sh
git -C /Users/sac/ash_surface rev-parse --short HEAD        # b70da9e1c
cd /Users/sac/ash_surface && PATH=$HOME/.asdf/shims:$PATH mix test test/airo_surface_pin_w675_test.exs
git -C /Users/sac/gymact rev-parse --short HEAD             # 2fa947c
cd /Users/sac/gymact && uv run pytest tests/test_airo_w677_pin.py
git -C /Users/sac/zcode-cli rev-parse --short HEAD          # 1e40596
cd /Users/sac/zcode-cli && bun test test/airo
```
