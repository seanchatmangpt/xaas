#!/usr/bin/env node
// Scripted agent backend for `ultracode-run.mjs selftest` (XAAS-26922-26).
//
// WHY THIS DOUBLE EXISTS (the one legitimate test double, per the Chicago
// testing discipline): the real collaborator is `zcode --prompt <p> --json
// --cwd <d> --mode yolo`, which drives a networked, paid LLM whose output is
// nondeterministic. The runtime's behaviour under test (journal, resume,
// schema re-ask via --resume <sessionId>, rate-limit backoff, null on failure,
// worktree isolation, concurrency cap) depends on exact, repeatable agent
// replies, including deliberately invalid ones and rate-limit exits. This
// executable pins that nondeterminism and nothing else: it is a real process,
// spawned by the real runtime through the real argv contract (selected with
// env ULTRACODE_AGENT_CMD), and it prints the same JSON shape zcode prints:
// {"sessionId","traceId","response"}. No module of ours is mocked; the runtime,
// git, the filesystem and the journal files are all real.
//
// Behaviour is chosen by a directive inside the prompt: [[scripted:<verb> <arg>]]
//   echo <text>            reply <text>
//   json <json>            reply the JSON text
//   fenced <json>          reply prose with the JSON in a ```json fence
//   prose-object <json>    reply prose with the JSON object inline
//   bad-then <json>        first turn: non-JSON prose; resumed turn (--resume): <json>
//   nosession-bad-then <json>  reply with an empty sessionId (no --resume possible): non-JSON
//                          prose, unless the prompt carries the runtime's fresh re-ask block,
//                          then <json>
//   always-bad             never JSON
//   ratelimit-once <text>  first call for this prompt: "429 ... 1302" on stderr, exit 75; then reply <text>
//   die                    exit 1 (unrecoverable)
//   sleep <ms> <text>      sleep, then reply <text>
//   readonly-check         reply READONLY if the prompt carries the READ-ONLY instruction, else WRITABLE
//   pwd                    reply the --cwd it was given
//   write-file <name> <s>  write <s>\n to <cwd>/<name>, reply the cwd
// Every invocation appends one JSON line to $ULTRACODE_SCRIPTED_STATE/calls.jsonl.
import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";

const argv = process.argv.slice(2);
const opt = (name) => {
  const i = argv.indexOf(name);
  return i >= 0 && i + 1 < argv.length ? argv[i + 1] : null;
};
const stateDir = process.env.ULTRACODE_SCRIPTED_STATE;
if (!stateDir) {
  process.stderr.write("ultracode-scripted-agent: ULTRACODE_SCRIPTED_STATE is required\n");
  process.exit(64);
}
const prompt = opt("--prompt") ?? "";
const cwd = opt("--cwd") ?? process.cwd();
const resume = opt("--resume");
const mode = opt("--mode");
const json = argv.includes("--json");
const tStart = Date.now();
const sha = (s) => createHash("sha256").update(s).digest("hex");
const sessions = path.join(stateDir, "sessions");
fs.mkdirSync(sessions, { recursive: true });

let session;
if (resume) {
  session = JSON.parse(fs.readFileSync(path.join(sessions, `${resume}.json`), "utf8"));
  session.turns += 1;
} else {
  const m = /\[\[scripted:([\w-]+)(?: ([\s\S]*?))?\]\]/.exec(prompt);
  session = {
    id: "sess-" + sha(`${prompt}:${process.pid}:${process.hrtime.bigint()}`).slice(0, 16),
    verb: m ? m[1] : "none",
    arg: m ? (m[2] ?? "") : "",
    prompt,
    turns: 1,
  };
}

const record = (exit) => {
  fs.appendFileSync(path.join(stateDir, "calls.jsonl"), JSON.stringify({
    pid: process.pid, verb: session.verb, arg: session.arg, session: session.id, turn: session.turns,
    resume, cwd, mode, json, exit,
    harness: prompt.startsWith("[UltraCode"),
    readonly: /READ-ONLY/.test(prompt),
    fresh_reask: prompt.includes("--- previous attempt ---"),
    carries_errors: /failed schema validation:\n- /.test(prompt),
    prompt_head: prompt.slice(0, 300),
    t_start: tStart, t_end: Date.now(),
  }) + "\n");
};

const reply = (response, { sessionless = false } = {}) => {
  fs.writeFileSync(path.join(sessions, `${session.id}.json`), JSON.stringify(session));
  record(0);
  process.stdout.write(JSON.stringify({ sessionId: sessionless ? "" : session.id, traceId: `trace-${session.id.slice(5)}`, response }) + "\n");
  process.exit(0);
};

const fail = (code, message) => {
  record(code);
  process.stderr.write(message + "\n");
  process.exit(code);
};

const [first, ...rest] = session.arg.split(" ");
switch (session.verb) {
  case "echo":
  case "json":
    reply(session.arg);
    break;
  case "fenced":
    reply("Here is the result:\n```json\n" + session.arg + "\n```\nDone.");
    break;
  case "prose-object":
    reply("The answer is " + session.arg + " as requested.");
    break;
  case "bad-then":
    reply(session.turns === 1 ? "I could not produce JSON this time." : session.arg);
    break;
  case "nosession-bad-then":
    reply(prompt.includes("--- previous attempt ---") ? session.arg : "no JSON and no session to resume", { sessionless: true });
    break;
  case "always-bad":
    reply(`still not json, turn ${session.turns}`);
    break;
  case "ratelimit-once": {
    const flag = path.join(stateDir, `rl-${sha(session.prompt).slice(0, 16)}`);
    if (!fs.existsSync(flag)) {
      fs.writeFileSync(flag, "1");
      fail(75, "API Error: 429 rate limit exceeded (code 1302)");
    }
    reply(session.arg);
    break;
  }
  case "die":
    fail(1, "boom: scripted unrecoverable failure");
    break;
  case "sleep":
    await new Promise((r) => setTimeout(r, Number(first)));
    reply(rest.join(" "));
    break;
  case "readonly-check":
    reply(/READ-ONLY/.test(prompt) ? "READONLY" : "WRITABLE");
    break;
  case "pwd":
    reply(cwd);
    break;
  case "write-file":
    fs.writeFileSync(path.join(cwd, first), rest.join(" ") + "\n");
    reply(cwd);
    break;
  default:
    reply("no directive");
}
