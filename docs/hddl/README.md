# HDDL — Known Task Classes (Exercise)

Per this repo's operating doctrine (`CLAUDE.md`): a known task class routes to its
optimal existing formalism instead of being re-planned in prose by an LLM every time.
This directory names the task classes actually observed recurring across this
session's workflows and writes each as a real HDDL domain — compound task, methods,
primitive actions with preconditions/effects grounded in the real commands this repo
actually runs, not invented ones.

**Status: exercise, not wired to a solver.** No HTN planner currently consumes these
files; nothing in this repo's `mix` tasks or Workflow scripts parses HDDL syntax. This
is the Operationalize step's *first* half — writing the fixed method down — not yet the
second half (a planner or script that executes it without an LLM re-deriving the
decomposition each time). That wiring is real, disclosed future work, not claimed done.

**What the standing observation loop (`docs/ocel/session-activity.ndjson` +
`docs/hddl/observed-activity.md`, appended every ~20 minutes) actually contributes, and
what it doesn't:** it removes the need for a human (or a full reasoning pass) to
manually notice and log routine repo activity — real commits/cycles get captured and
tagged against a known task class from this directory without anyone deciding to check
in and write it down. But it is still LLM-in-the-loop, not LLM-retired: it's an agent
invocation reading `git log` and deciding what to write each cycle, not a fixed script.
What it generates is the *evidence* needed to get there — enough tagged instances of
"this is a `VERIFY-AND-COMMIT`" or "this doesn't match any known class" to eventually
promote a pattern into a real, zero-LLM-reasoning script. It does not remove judgment
calls, anything destructive/ambiguous, deciding what the next cycle's real theme should
be, or anything requiring the doctrine's Fence/RCA reasoning — those still need a full
pass, not a 20-minute observation tick. The actual "don't need a human to drive this"
claim requires the fixed HDDL method wired into a real planner or script consuming
these logs, which — per the paragraph above — is not yet done.

## Domains

| File | Compound task | Observed this session |
|---|---|---|
| `verify-and-commit.hddl` | `VERIFY-AND-COMMIT` | Every workflow's final "Verify" stage: compile → migrate → test → mock-grep → commit. Run 6+ times. |
| `workflow-cycle.hddl` | `RUN-CYCLE` | The shape every `Workflow` script in this session actually took: research → design → implement → verify. |
| `actor-binding-fix.hddl` | `CLOSE-FMEA-GAP` | The vision-2030 cycle 0020 pattern: find an unbound actor-resolution gap, design a grant/audit binding, build it, wire it, verify via avatar tests. |
| `mechanical-rename.hddl` | `RENAME-NAMESPACE` | The `kanban`→`xaas` rename: discover references, move files, text-sweep, recompile, fix stragglers, verify, commit. |
| `hourly-vision-cycle.hddl` | `VISION-2030-CYCLE` | The standing cron job's own shape (ERRC/FMEA/RCA pick → charter doc → swarm → results). Composes the four domains above as subtasks. |
| `next-read.hddl` | `NEXT-READ-DUAL-PERSONA-EXPERIENCE` | The Next Read library recommendation platform: dual-persona split LiveView UI, A2A student simulation with persona grants, and Ash AI read-only MCP catalog tools. |

## Why these domains

Per the doctrine's Explore≠Exploit split: these domains are ALIVE (observed, executed,
repeated across workflows with the same real shape). Anything observed only once
isn't a "known class" yet — it's still exploration, and writing an HDDL method for a
one-off would be premature formalization, not Operationalize. `docs/vision/` cycles
that invent a genuinely new task shape should get a new `.hddl` file added here only
after that shape repeats.
