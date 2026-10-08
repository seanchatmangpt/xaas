# _LANES.md — burn-in repair wave, 2026-09-26 (v26.9.26)

SUPERSEDED mid-wave by operator order 2026-09-26: "we are no longer using
worktrees/tmp/shadow dirs. We want agent collisions because that
strengthens the implementations." The disjoint-file-ownership contract
below was the wave's launch shape; future waves fan agents onto the SAME
real surfaces concurrently and let collisions + courts decide. Retained
for the record of what each lane actually touched.

Operator order: "launch agents, I have a massive budget". Three write lanes,
disjoint file ownership, one canonical checkout per repo. Coordinator owns
every git transition; lanes never run git state commands. Wave-1 finding
being repaired: tick 1 (run b38fa6b7, epoch e6f31aa4) — worker honestly
refused: `worktree: null` lease (cwd = empty reap dir), gate scoping Bash to
cwd, gate internal "MCP server is not configured" error on file tools, and
no OCEL tap on the generic `--json` argv.

| lane | repo | owned files (nothing else) | task |
|---|---|---|---|
| L1 wave-loop work surface | ~/xaas | lib/xaas/ultracode/wave_loop/state.ex, lib/xaas/ultracode/wave_loop.ex, test/xaas/ultracode/wave_loop_state_test.exs, test/xaas/ultracode/wave_loop_test.exs (if present) | `WORK SURFACE:` line in STATE → epoch worktree → dispatch cwd |
| L2 gate config fix | ~/xaas (+ plugin cache forward) | canonical xaas-gate.mjs source under ~/xaas, its tests, cache copy | repair the `xaas-execution MCP server is not configured` lookup inside leased workers |
| L3 OCEL-tappable dispatch | ~/xaas + ~/zcode-cli | lib/xaas/ultracode/dispatch.ex, test/xaas/ultracode/dispatch_test.exs; ~/zcode-cli/src/ocel-tap.ts + test/ocel-*.test.ts if tap-side | make generic worker sessions emit OCEL events without breaking the collector |

Coordinator-owned: STATE.md step reset, driver relaunch, Phase B, OCEL v2
export/validate, commits. Shared seams resolved here; no chat negotiation.
