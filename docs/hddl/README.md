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
| `ash-vector-migration-fallout.hddl` | `FIX-VECTOR-MIGRATION-FALLOUT` | `Book.embedding`'s migration from plain list to pgvector-backed `Ash.Vector`: `lib/xaas/library/ranker.ex:231-249` had to add an `%Ash.Vector{}` clause and convert via `Ash.Vector.to_list/1`. One verified instance so far. |

## Why these domains

Per the doctrine's Explore≠Exploit split: these domains are ALIVE (observed, executed,
repeated across workflows with the same real shape). Anything observed only once
isn't a "known class" yet — it's still exploration, and writing an HDDL method for a
one-off would be premature formalization, not Operationalize. `docs/vision/` cycles
that invent a genuinely new task shape should get a new `.hddl` file added here only
after that shape repeats.

## Loop-Until-Dry Safety Pattern

A `loop-until-dry` (run rounds until N consecutive rounds find nothing new) is a real,
useful termination pattern for one class of search and a real hang risk for another.
This section names the rule that separates them, extracted from the RCA in
`docs/vision/vision-2030-2026-09-09-0738.md` after cycle 0538's `LoopUntilDry` phase
ran to round 937+ before being killed via `TaskStop` with zero live process and no
commit.

### The rule

`loop-until-dry` is safe only when both of the following hold:

1. **Fixed pre-existing enumeration domain.** The set being searched must already
   exist and be finite before the loop starts (every function in a file, every real
   occurrence of a grep pattern in a codebase, every row in a table) — not a set that
   is invented or extended by the act of searching it.
2. **Independent negative-membership test.** There must be a way to check "is this
   item actually in the domain?" that does not depend on the same process being asked
   to produce more items — e.g. a second, independent grep/query that can return zero
   results, not just the same generator claiming it has nothing left.

### The distinction that actually causes the hang

**Monotonic exhaustion vs. diminishing plausibility.** A finite real-search domain
exhausts monotonically: once every real occurrence is found, the independent test
proves zero remain, permanently. An open-ended generative task (invent a new edge
case, brainstorm a new design concern) never exhausts — it only becomes less likely
per round that the generator produces something *it considers* novel, and an LLM
asked "is there anything new?" will nearly always produce *a* plausible-sounding
answer rather than truthfully report the domain is empty. Two consecutive empty
rounds looks identical from inside the loop in both cases; only the domain's real
structure tells them apart.

### Classification test

Before wiring a `loop-until-dry` exit condition, ask: **does "nothing left" correspond
to an empty set the tool can observe, or to the model saying it can't think of more?**

- Empty set an independent tool call can observe (a grep, a query, a fixed
  enumeration) → safe to loop until dry.
- The model's own claim that it has exhausted its ideas, with no independent set to
  check against → unsafe; the loop must carry a hard round cap regardless of the
  dry-streak condition.

### Corollary example

- **Safe**: "find every real occurrence of grep pattern `X` in this codebase" — the
  codebase is a fixed, finite domain; a second `grep -c` run is an independent
  negative-membership test; the search monotonically exhausts.
- **Unsafe**: "invent a new edge case for a mix task that doesn't exist yet" — there
  is no fixed domain to exhaust and no independent test for "no edge cases remain";
  this is exactly the pattern that produced the real 937+-round kill-switch incident
  in `docs/vision/vision-2030-2026-09-09-0738.md` (`LoopUntilDry` phase of cycle
  `vision-2030-cycle-2026-09-09-0538`, killed via `TaskStop` after ~2 hours with zero
  live `beam.smp`/`mix` process and no commit).

**Applied fix**: any `loop-until-dry` over an open-ended design question must carry a
hard round cap (e.g. 15) in addition to its dry-streak exit condition, so a runaway
design-brainstorm loop cannot hang indefinitely the way cycle 0538's did.

### See Also

- `docs/vision/vision-2030-2026-09-09-0738.md` — the RCA case study this section is
  extracted from, including the real failing loop code and the retry cycle's fix.
- `docs/hddl/verify-and-commit.hddl` — reconciled this same cycle against
  `lib/mix/tasks/xaas.verify_and_commit.ex`'s real flat pipeline (no git-status
  branching, no push, `git commit -am` not `-F`); an example of a fixed, finite,
  independently-checkable domain (the real diff between spec and code) used as a
  one-shot reconciliation, not a `loop-until-dry`.
