---
name: ultracode-takeover
description: Spec of Claude Code Workflow scripts (body form and module form, Draft-07 schemas, journal and resume semantics) and the procedure for ZCode to take over an in-flight ultracode run when Claude is unavailable. Use when a ~/.claude/workflow-handoff record is stale, when asked to run or resume a .claude/workflows script, or when Claude is rate limited or down.
---

# UltraCode takeover: running Claude Code Workflow scripts from ZCode

Claude Code sessions orchestrate multi-agent work with **Workflow scripts** (the
"ultracode" mode). When Claude is unavailable (rate limit, outage, session death)
ZCode must continue those runs without re-deriving the plan. This skill is the
file-format spec plus the takeover procedure. The runtime is
`scripts/ultracode-run.mjs`; the stall detector is `scripts/ultracode-watch.mjs`.

## 1. Where Claude keeps a run

| artifact | path |
|---|---|
| handoff record (one per launched run) | `~/.claude/workflow-handoff/<runId>.json` — written by a Claude PostToolUse hook on the Workflow tool: `{runId, scriptFile, transcriptDir, args, cwd, sessionId, launchedAt}` |
| script (persisted copy of what ran) | `~/.claude/projects/<project>/<session>/workflows/scripts/<name>-<runId>.js` |
| run transcript dir | `~/.claude/projects/<project>/<session>/subagents/workflows/<runId>/` |
| journal | `<transcriptDir>/journal.jsonl` |
| per-agent transcripts | `<transcriptDir>/agent-<agentId>.jsonl` (+ `.meta.json`: description = label, workflowPhase) |
| takeover lock | `~/.claude/workflow-handoff/<runId>.takeover` (written by ZCode when it takes over; Claude must read it before resuming) |
| saved (named) workflows | `~/.claude/workflows/*.js` (user), `<repo>/.claude/workflows/*.js` (project), `<plugin>/workflows/*.js` (plugin) — runnable directly: `ultracode-run.mjs run <file> --args '<json or text>'` |

Journal lines (JSON per line):
- `{"type":"launched"}`
- `{"type":"started","key":"v2:<sha256>","agentId":"<id>","label":"<label>","phase":"<phase>"}`
- `{"type":"result","key":"v2:<sha256>","agentId":"<id>","result":<value>}` — the agent's return
  value (a string, or the schema-validated object)

There is no explicit "run completed" line. A run is complete when replaying the script
against the journal reaches `return` without needing any live agent (`ultracode-run.mjs
run --dry-run` reports `live_agents_needed: 0`).

## 2. Script format (plain JavaScript, not TypeScript)

```js
export const meta = {            // PURE LITERAL: no variables, calls, spreads, interpolation
  name: 'kebab-name',            // required
  description: 'one line',       // required
  phases: [{ title: 'Survey', detail: '...' }],   // optional; titles match phase() calls
}
// body: runs in an async context; top-level await and a final `return <value>` are allowed
```

Globals available to the body:

| hook | semantics |
|---|---|
| `agent(prompt, opts?)` | spawn one subagent; resolves to its final text, or, with `opts.schema` (JSON Schema, root `type: object`), the validated object. Resolves `null` if the agent dies or is skipped. opts: `label` (display + **resume key across runtimes**), `phase`, `schema`, `model`, `effort` (`low..max`), `isolation: 'worktree'` (fresh git worktree, removed if unchanged), `agentType` (`Explore` = read-only search agent; `general-purpose`; custom names) |
| `pipeline(items, stage1, stage2, ...)` | each item flows through all stages independently, no barrier; each stage gets `(prevResult, originalItem, index)`; a throwing stage drops that item to `null` |
| `parallel(thunks)` | barrier; runs `() => Promise` thunks concurrently; a rejected thunk becomes `null`; never rejects |
| `phase(title)` / `log(msg)` | progress grouping / narrator line |
| `args` | the Workflow call's `args` value, verbatim JSON |
| `budget` | `{total: number|null, spent(), remaining()}`; ZCode: `total = null`, `remaining() = Infinity` |
| `workflow(nameOrRef, args)` | run a child workflow inline (`{scriptPath}`), one level deep |

### 2b. Module form (published docs form) — also accepted

```js
// .claude/workflows/<name>.js   or   <plugin>/workflows/<name>.js
import { agent, parallel, pipeline } from "claude";
export const meta = { name: "custom-migration", description: "...", phases: ["discover", "understand", "plan", "build"] };
export async function run(promptContext) {
  const plan = await agent({ prompt: `... ${promptContext}`, schema: { type: "object", required: ["targets"], properties: { /* ... */ }, additionalProperties: false } });
  if (!plan) throw new Error("dropped");
  const results = await parallel(plan.targets.map(t => agent({ prompt: `Apply ${t.changeSummary} to ${t.filepath}` })));
  return results.filter(Boolean);
}
```

Equivalences the runtime implements so both forms run unchanged:
- `import ... from "claude"` resolves to the same primitives as the globals.
- `agent({prompt, schema, ...opts})` ≡ `agent(prompt, {schema, ...opts})`.
- `parallel([...promises])` is accepted as well as `parallel([...thunks])`.
- `meta.phases` may be `["title", ...]` or `[{title, detail}]`.
- `run(promptContext)` receives `args` (a string prompt or the args object); a body-form script's `return` value and a module-form `run()` return value are both the run result.

### 2c. Structured output (schemas)

- Schemas are JSON Schema **Draft-07** (Zod users: `zodToJsonSchema(S, { target: "draft7" })`);
  root must be `type: "object"`; `required ⊆ properties`.
- Pre-flight: before any agent is spawned, the runtime rejects contradictory schemas (a
  `required` key absent from `properties` while `additionalProperties: false`, required not an
  array, non-object root, unknown `type`) — the run halts with a typed error, zero tokens spent.
- A response that fails validation is re-asked with the validator errors, up to
  `MAX_STRUCTURED_OUTPUT_RETRIES` (default 5), then the agent resolves `null`.

### 2d. Composition patterns (all plain JS over the primitives)

Tournament / generate-and-kill (N independent candidates → judge agent selects); adversarial verify
(N refuters, majority kills); conditional triage (schema'd `type` field → `switch` routes to domain
agents); feedback repair loop (agent → real test command → errors fed back → bounded retries);
loop-until-dry (dedup vs a `seen` set); pipeline-by-default, barrier only for cross-item needs.

Rules the runtime enforces: concurrency cap `min(16, cpus-2)` (env `ULTRACODE_CONCURRENCY`);
at most 1000 agents per run; `Date.now()`, `Math.random()` and argless `new Date()` are not used by
scripts (deterministic replay). Subagents treat their final message as the return value (raw data,
not prose for a human).

## 3. Takeover procedure (ZCode)

1. Find candidates: `node scripts/ultracode-watch.mjs scan` lists handoff records whose
   transcript dir has had no write for `ULTRACODE_STALE_MINUTES` (default 15) and whose dry-run
   still needs live agents.
2. Take over one run: `node scripts/ultracode-watch.mjs takeover <runId>` — writes the
   `.takeover` lock, then runs
   `node scripts/ultracode-run.mjs run <scriptFile> --args @<handoff args> --resume-from <transcriptDir> --run-dir ~/.zcode/ultracode/runs/<runId>`.
   Completed agents are replayed from Claude's journal **by label** (nth call with a label ↔ nth
   Claude result with that label); only unfinished agents run live, each as
   `zcode --prompt <harness+prompt> --json --cwd <cwd> --mode yolo`.
3. The ZCode run writes its own `journal.jsonl` (same line shapes, keys `zc1:<sha256>`) and
   `result.json` into the run dir, so Claude (or another ZCode) can continue from it.
4. Doctrine is unchanged under takeover: `~/.zcode/AGENTS.md` (generated from
   `~/.claude/rules`) binds every spawned agent — receipts, no mocks, merge lock protocol,
   no push/merge/tag without the court gate.

## 4. Writing takeover-safe workflows (for Claude)

- Give every `agent()` call a **unique, deterministic `label`** (e.g. `build:${order}-${cand}`):
  labels are the cross-runtime resume key.
- Keep side effects inside agents (worktrees, commits); keep script control flow pure.
- Put absolute repo paths in prompts (ZCode agents start with no conversation context).
