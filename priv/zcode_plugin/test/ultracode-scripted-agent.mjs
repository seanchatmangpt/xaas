#!/usr/bin/env node
// ultracode-scripted-agent.mjs -- scripted agent backend for ultracode-run.mjs tests.
//
// Test-double justification (the ONE allowed double, per ~/.claude/rules/
// testing-chicago-style.md "one legitimate use"): a live model's reply is
// nondeterministic and spends tokens, so `ultracode-run.mjs selftest` pins the agent's
// reply with this real executable instead of the model. Nothing about the runtime is
// faked: it is selected exactly the way production selects zcode (env
// ULTRACODE_AGENT_CMD), spawned as a real subprocess, receives the same argv
// (`--prompt <p> --json --cwd <dir> --mode yolo [--resume <sessionId>]`) and prints the
// same JSON shape as `zcode --prompt --json`: {"sessionId","traceId","response"}. The
// runtime's own modules are never mocked; every other collaborator in the selftest is
// real (processes, a tmp git repo, git worktrees, files, journals).
//
// Scripting: the prompt names a scenario with `SCRIPTED:<name>` (last occurrence wins);
// scenarios live in $ULTRACODE_SCRIPTED_STATE/scenarios.json as
// {"<name>": {"replies": [reply, ...]}}. The n-th invocation for a scenario (fresh or
// resumed session; counted with exclusive-create files, so concurrent invocations get
// distinct n) plays replies[min(n, len-1)]. A `--resume <sessionId>` invocation
// recovers its scenario from the session file, so a re-ask prompt need not repeat it.
// Reply forms: "text" | {text} | {json} | {echo:true} | {exit, stderr, stdout}, plus
// optional sleep_ms, write:{file, content} (relative to --cwd), no_session:true.
// Every invocation appends one line to $ULTRACODE_SCRIPTED_STATE/calls.jsonl.

import fs from 'node:fs';
import path from 'node:path';
import { randomUUID } from 'node:crypto';

const argv = process.argv.slice(2);
const opt = (name) => {
  const i = argv.indexOf(name);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : undefined;
};

const state = process.env.ULTRACODE_SCRIPTED_STATE;
if (!state) {
  process.stderr.write('ultracode-scripted-agent: ULTRACODE_SCRIPTED_STATE is not set\n');
  process.exit(2);
}

const t0 = Date.now();
const prompt = opt('--prompt') ?? '';
const cwd = opt('--cwd') ?? process.cwd();
const resume = opt('--resume') ?? null;
fs.mkdirSync(path.join(state, 'sessions'), { recursive: true });
fs.mkdirSync(path.join(state, 'counters'), { recursive: true });

let scenario = null;
if (resume) {
  try {
    scenario = JSON.parse(fs.readFileSync(path.join(state, 'sessions', `${resume}.json`), 'utf8')).scenario;
  } catch {
    scenario = null;
  }
}
if (!scenario) {
  const all = [...prompt.matchAll(/SCRIPTED:([A-Za-z0-9_.:-]+)/g)];
  scenario = all.length ? all[all.length - 1][1] : 'default';
}

let scenarios = {};
try {
  scenarios = JSON.parse(fs.readFileSync(path.join(state, 'scenarios.json'), 'utf8'));
} catch {
  scenarios = {};
}
const spec = scenarios[scenario] ?? { replies: ['SCRIPTED-DEFAULT'] };
const replies = Array.isArray(spec.replies) && spec.replies.length ? spec.replies : ['SCRIPTED-DEFAULT'];

let attempt = 0;
for (;; attempt++) {
  try {
    fs.closeSync(fs.openSync(path.join(state, 'counters', `${scenario}.${attempt}`), 'wx'));
    break;
  } catch (e) {
    if (e.code !== 'EEXIST') throw e;
  }
}

let reply = replies[Math.min(attempt, replies.length - 1)];
if (typeof reply === 'string') reply = { text: reply };

if (reply.sleep_ms) await new Promise((r) => setTimeout(r, reply.sleep_ms));
if (reply.write) fs.writeFileSync(path.join(cwd, reply.write.file), reply.write.content ?? '');

const sessionId = reply.no_session ? null : resume ?? `sess-${randomUUID()}`;
if (sessionId) fs.writeFileSync(path.join(state, 'sessions', `${sessionId}.json`), JSON.stringify({ scenario }));

let response;
if (reply.echo) {
  response = JSON.stringify({ cwd: fs.realpathSync(cwd), processCwd: process.cwd(), readOnly: prompt.includes('READ-ONLY'), resumed: Boolean(resume) });
} else if ('json' in reply) {
  response = JSON.stringify(reply.json);
} else {
  response = String(reply.text ?? '');
}

const t1 = Date.now();
fs.appendFileSync(
  path.join(state, 'calls.jsonl'),
  JSON.stringify({
    scenario,
    attempt,
    resume,
    sessionId,
    cwd,
    readOnly: prompt.includes('READ-ONLY'),
    reask: /did not validate/.test(prompt),
    exit: reply.exit ?? 0,
    t0,
    t1,
    pid: process.pid,
  }) + '\n',
);

if (reply.exit) {
  if (reply.stdout) process.stdout.write(reply.stdout);
  process.stderr.write(`${reply.stderr ?? 'scripted failure'}\n`);
  process.exit(reply.exit);
}
process.stdout.write(JSON.stringify({ sessionId, traceId: `trace-${randomUUID()}`, response }) + '\n');
