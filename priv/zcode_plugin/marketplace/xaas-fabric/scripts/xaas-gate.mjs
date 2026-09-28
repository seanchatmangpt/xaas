// Host-level PreToolUse gate for XaaS leased workers.
//
// Runs as a ZCode plugin PreToolUse command hook (hooks/hooks.json). Active
// only when XAAS_WORKER=1 (set by the unattended dispatcher); in an
// interactive session it is a silent pass-through. It only ever DENIES or
// defers -- it never grants a permission the host would not otherwise grant.
//
// Fail closed: any internal error, unparseable input, unreachable arbiter, or
// missing lease is a deny. A hook that crashes with a non-2 exit code is a
// recoverable failure to the host, so every path here exits 0 with an explicit
// decision.
//
// Enforcement, per tool call:
//   * xaas-execution MCP tools (claim_next, admit_tool, close_candidate, ...)
//     -> defer (that IS the lease protocol).
//   * Bash -> argv-parsed allowlist only: `git` (no push), the lease script,
//     and read-only helpers scoped to the leased worktree; no chaining,
//     redirection, substitution or globbing. Bash stays hard-refused by the
//     server's admit_tool; this is the narrow host-side carve-out that lets a
//     worker commit its own worktree.
//   * every other tool -> requires a live lease, a server-side admit_tool
//     allow, and (for writes) real-path containment inside the leased
//     worktree and never inside a .git directory.
//   * Read/Grep/Glob never touch credential directories.
//   * Agent (subagent spawning) is denied unless XAAS_ALLOW_SUBAGENTS=1: a
//     subagent's own tool calls were observed NOT to be routed through
//     PreToolUse (a subagent ran `curl` with no gate decision logged), so
//     spawning one would let a worker step outside every rule above.
import { readFileSync, realpathSync, appendFileSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir, homedir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const STATE_DIR = path.join(tmpdir(), "xaas-fabric");

// Built-in gate floor. Identical to the "gate" section of
// priv/ultracode/runtime_surface.json today; used only when that policy file is
// unreadable or a field is malformed -- never widened by a load failure.
const DEFAULT_GATE = Object.freeze({
  pre_lease_ok: ["Read", "Grep", "Glob", "TodoWrite", "Skill"],
  local_only: ["Skill"],
  git_subs: ["add", "commit", "status", "diff", "log", "rev-parse", "show", "ls-files"],
  // Sweep-profile git: strictly read-only subcommands (add/commit stay
  // worktree-only even in sweep mode).
  git_sweep_subs: ["status", "diff", "log", "rev-parse", "show", "ls-files"],
  git_forbidden: ["-c", "--exec-path", "--namespace", "--no-index", "-F", "--file", "-t", "--template"],
  read_helpers: ["ls", "cat", "head", "tail", "wc"],
  sensitive_home_dirs: [".zcode", ".ssh", ".aws", ".gnupg", ".config", ".claude", ".docker", ".kube", ".netrc", ".npmrc"],
  deny_tools: ["WebFetch", "WebSearch"],
});

/**
 * Path of the runtime-surface policy JSON: XAAS_SURFACE_PATH, else the
 * repo-relative priv/ultracode/runtime_surface.json next to this plugin tree.
 * @returns {string}
 */
export function surfacePath() {
  const fromEnv = (process.env.XAAS_SURFACE_PATH ?? "").trim();
  return fromEnv || path.join(HERE, "..", "..", "..", "..", "ultracode", "runtime_surface.json");
}

/**
 * Loads the "gate" section of the runtime-surface policy. Each field must be an
 * array of strings; an unreadable file, unparseable JSON, missing section or
 * malformed field falls back to DEFAULT_GATE for that field.
 * @param {string} [file]
 * @returns {{source: string, gate: Record<string, string[]>}}
 */
export function loadGatePolicy(file = surfacePath()) {
  let section = null;
  let source = "builtin";
  try {
    const doc = JSON.parse(readFileSync(file, "utf8"));
    if (doc && typeof doc.gate === "object" && doc.gate !== null) {
      section = doc.gate;
      source = file;
    }
  } catch {
    section = null;
  }
  /** @type {Record<string, string[]>} */
  const gate = {};
  for (const [key, fallback] of Object.entries(DEFAULT_GATE)) {
    const v = section?.[key];
    gate[key] = Array.isArray(v) && v.every((x) => typeof x === "string") ? v : fallback;
  }
  return { source, gate };
}

const POLICY = loadGatePolicy();
const PRE_LEASE_OK = new Set(POLICY.gate.pre_lease_ok);
const LOCAL_ONLY = new Set(POLICY.gate.local_only);
const WRITE_TOOLS = new Set(["Write", "Edit", "NotebookEdit", "MultiEdit"]);
const TOOL_MAP = { Agent: "Task", TaskOutput: "Task", TaskStop: "Task", MultiEdit: "Edit", NotebookEdit: "Edit" };
const GIT_SUBS = new Set(POLICY.gate.git_subs);
const GIT_FORBIDDEN = new Set(POLICY.gate.git_forbidden);
const READ_HELPERS = new Set(POLICY.gate.read_helpers);
const GIT_SWEEP_SUBS = new Set(POLICY.gate.git_sweep_subs);
const SENSITIVE_HOME_DIRS = POLICY.gate.sensitive_home_dirs;
// Tools with no lawful direct edge from a leased worker: external semantic
// reads go through UltraCode -> SA2A -> resolve_capability, never direct.
const DENY_TOOLS = new Set(POLICY.gate.deny_tools);

function realpathLoose(p) {
  let cur = path.resolve(p);
  const tail = [];
  for (;;) {
    try {
      return path.join(realpathSync(cur), ...tail.reverse());
    } catch {
      const parent = path.dirname(cur);
      if (parent === cur) return path.resolve(p);
      tail.push(path.basename(cur));
      cur = parent;
    }
  }
}

function inside(root, p) {
  const rel = path.relative(root, p);
  return rel === "" || (rel !== ".." && !rel.startsWith(".." + path.sep) && !path.isAbsolute(rel));
}

function stateFile(cwd, suffix) {
  return path.join(STATE_DIR, `${createHash("sha256").update(cwd).digest("hex")}${suffix}`);
}

// Key-matching law: the worker (zcode-cli src/gall-work.ts leaseFilePathsKeyed)
// writes its lease state to a -<XAAS_LEASE_ID>-suffixed file when the
// dispatcher sets that env. The gate must read the same key first or a keyed
// worker is fenceless (denied everything) — observed 2026-09-27 as wave-loop
// tick 14's worker_unclosed: exit 0, work done, no receipt sealed. Legacy
// per-cwd path stays as fallback so non-keyed sessions are unchanged.
function leaseIdSuffix() {
  const id = (process.env.XAAS_LEASE_ID ?? "").trim();
  return id ? `-${id.replace(/[^A-Za-z0-9._-]/g, "_")}` : "";
}

function readLease(leaseCwd) {
  const keyed = leaseIdSuffix();
  for (const cwd of new Set([leaseCwd, realpathLoose(leaseCwd)])) {
    const suffixes = keyed ? [`${keyed}.json`, ".json"] : [".json"];
    for (const suffix of suffixes) {
      try {
        const lease = JSON.parse(readFileSync(stateFile(cwd, suffix), "utf8"));
        const expiresAt = Date.parse(lease.lease_expires_at ?? "");
        if (lease && typeof lease.lease_token === "string" && lease.lease_token && expiresAt > Date.now()) {
          return lease;
        }
      } catch {
        // try the next candidate key
      }
    }
  }
  return null;
}

function decide(decision, reason, ctx) {
  try {
    mkdirSync(STATE_DIR, { recursive: true, mode: 0o700 });
    appendFileSync(
      stateFile(ctx.leaseCwd, ".gate.ndjson"),
      JSON.stringify({ ts: new Date().toISOString(), tool: ctx.tool, decision, reason }) + "\n",
      { mode: 0o600 }
    );
  } catch {
    // audit log is best-effort; the decision itself must still be emitted
  }
  if (decision === "deny") {
    process.stdout.write(
      JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: `xaas-gate: ${reason}`,
        },
      }) + "\n"
    );
  }
  process.exit(0);
}

// Splits a command into argv only if it is a single simple command: no
// chaining, pipes, redirection, substitution, expansion, globbing or
// backslash escapes (except the POSIX `\'` apostrophe splice used to embed a
// quote in single-quoted JSON). Returns null when it is anything else.
export function tokenize(cmd) {
  const argv = [];
  let cur = "";
  let has = false;
  let i = 0;
  const unsafe = new Set([";", "&", "|", "<", ">", "(", ")", "`", "$", "\\", "\n", "\r", "*", "?", "[", "]", "{", "}", "~", "#", "!"]);
  while (i < cmd.length) {
    const c = cmd[i];
    if (c === "'") {
      const j = cmd.indexOf("'", i + 1);
      if (j < 0) return null;
      cur += cmd.slice(i + 1, j);
      has = true;
      i = j + 1;
    } else if (c === '"') {
      i++;
      has = true;
      while (i < cmd.length && cmd[i] !== '"') {
        if (cmd[i] === "$" || cmd[i] === "`" || cmd[i] === "\\") return null;
        cur += cmd[i++];
      }
      if (i >= cmd.length) return null;
      i++;
    } else if (c === "\\" && cmd[i + 1] === "'") {
      cur += "'";
      has = true;
      i += 2;
    } else if (c === " " || c === "\t") {
      if (has) argv.push(cur);
      cur = "";
      has = false;
      i++;
    } else if (unsafe.has(c) || (c === "=" && !has)) {
      return null;
    } else {
      cur += c;
      has = true;
      i++;
    }
  }
  if (has) argv.push(cur);
  return argv;
}

function bashDecision(command, lease, ctx) {
  const trimmed = command.trim();
  if (Array.isArray(lease?.verifier) && lease.verifier.includes(trimmed)) return null;

  const argv = tokenize(trimmed);
  if (!argv || argv.length === 0) {
    return "bash command is not a single simple command (no chaining, pipes, redirection, substitution, globbing or expansion); use the Write/Edit tools for file changes";
  }
  const [bin, ...args] = argv;

  if (bin === "node") {
    const script = args[0] ? realpathLoose(path.resolve(ctx.leaseCwd, args[0])) : "";
    const leaseScript = realpathLoose(path.join(HERE, "xaas-lease.mjs"));
    if (script === leaseScript && ["save", "get", "clear"].includes(args[1])) return null;
    return "node is only allowed for the plugin's xaas-lease.mjs save|get|clear";
  }

  if (!lease) return "no live lease: claim_next and save the lease before running commands";
  const worktree = realpathLoose(lease.worktree ?? "");
  const cwdReal = realpathLoose(ctx.leaseCwd);
  // Typed read-only sweep profile (XAAS_SWEEP=1, dispatched per run via
  // extra_env): READ-ONLY commands may target paths under the home directory
  // except the sensitive set — for fleet-wide inventory sweeps that must
  // observe many checkouts from one leased session. Writes, git state
  // changes, and every other rule are UNCHANGED; still fail-closed.
  const sweep = process.env.XAAS_SWEEP === "1";

  if (bin === "git") {
    let repo = cwdReal;
    let rest = args;
    if (rest[0] === "-C") {
      if (!rest[1]) return "git -C requires a path";
      repo = realpathLoose(path.resolve(cwdReal, rest[1]));
      rest = rest.slice(2);
    }
    if (!inside(worktree, repo)) {
      if (!sweep || !GIT_SWEEP_SUBS.has(rest[0])) return "git is only allowed inside the leased worktree";
      const denial = sweepPathDenial(repo);
      if (denial) return denial;
    }
    if (!GIT_SUBS.has(rest[0])) return `git ${rest[0] ?? ""} is not allowed (${[...GIT_SUBS].join(", ")} only)`;
    for (const a of rest) {
      if (GIT_FORBIDDEN.has(a) || a.startsWith("--git-dir") || a.startsWith("--work-tree") || a.startsWith("--output")) {
        return `git flag ${a} is not allowed`;
      }
    }
    return null;
  }

  if (READ_HELPERS.has(bin)) {
    if (!inside(worktree, cwdReal) && !sweep) return `${bin} is only allowed with the session cwd inside the leased worktree`;
    for (const a of args.filter((x) => !x.startsWith("-"))) {
      const target = realpathLoose(path.resolve(cwdReal, a));
      if (inside(worktree, target)) continue;
      if (sweep) {
        const denial = sweepPathDenial(target);
        if (denial) return denial;
        continue;
      }
      return `${bin} may only read inside the leased worktree`;
    }
    return null;
  }

  // `date` is the leased worker's only timestamp source — evidence law
  // needs it (observed 2026-09-26: a burn-in step requiring an ISO8601
  // timestamp had no clock available inside the allowlist).
  if (bin === "pwd" || bin === "echo" || bin === "date") return null;

  // `sh`/`bash` script execution, worktree-confined on every non-flag arg
  // (observed 2026-09-26: a step whose acceptance was "run the script and
  // confirm its output" had no lawful way to execute any file it wrote).
  if (bin === "sh" || bin === "bash") {
    if (!inside(worktree, cwdReal)) return `${bin} is only allowed with the session cwd inside the leased worktree`;
    for (const a of args.filter((x) => !x.startsWith("-"))) {
      if (!inside(worktree, realpathLoose(path.resolve(cwdReal, a)))) return `${bin} may only execute inside the leased worktree`;
    }
    return null;
  }

  return `${bin} is not an allowed command for a leased worker`;
}

function pathFor(input) {
  return input.file_path ?? input.filePath ?? input.notebook_path ?? input.path ?? null;
}

// Sweep-profile path law: under the home directory, never inside a
// sensitive dir. Writes never reach this function (write decisions keep
// their own worktree containment).
function sweepPathDenial(p) {
  if (!inside(realpathLoose(homedir()), p)) return "sweep reads must stay under the home directory";
  for (const d of SENSITIVE_HOME_DIRS) {
    if (inside(realpathLoose(path.join(homedir(), d)), p)) return `reading ${d} is not allowed even in sweep mode`;
  }
  return null;
}

function readPathDecision(input, ctx) {
  const p = pathFor(input);
  if (!p) return null;
  const real = realpathLoose(path.resolve(ctx.leaseCwd, p));
  if (inside(realpathLoose(HERE), real)) return null;
  for (const d of SENSITIVE_HOME_DIRS) {
    if (inside(realpathLoose(path.join(homedir(), d)), real)) return `reading ${d} is not allowed for a leased worker`;
  }
  return null;
}

function writePathDecision(input, lease, ctx) {
  const p = pathFor(input);
  if (!p) return "cannot determine the target path of this write";
  const worktree = realpathLoose(lease.worktree ?? "");
  const real = realpathLoose(path.resolve(worktree, p));
  if (!inside(worktree, real)) return `write target ${p} is outside the leased worktree`;
  if (path.relative(worktree, real).split(path.sep).includes(".git")) return "writes inside .git are not allowed";
  return null;
}

function pluginMcpServer(cfgPath) {
  // Plugin-registered servers live in the plugin's own .mcp.json (key
  // `mcpServers`), NOT flattened into the user config's `mcp.servers` — that
  // assumption denied every consequential call of a real leased worker
  // (observed 2026-09-26, burn-in tick 1) while the CLI's own loader, which
  // reads this same manifest, succeeded. HERE is .../<marketplace>/<name>/<version>/,
  // so the manifest is one level up from scripts/.
  const manifestPath = path.join(HERE, "..", ".mcp.json");
  const server = JSON.parse(readFileSync(manifestPath, "utf8"))?.mcpServers?.["xaas-execution"];
  if (!server?.url || !server?.headers?.Authorization) return null;
  // ${user_config.KEY} is the PLUGIN'S user-supplied options object —
  // config.json plugins.options."<name>@<marketplace>" — not the config
  // root (a root lookup yields "Bearer undefined" and a 401 the worker
  // cannot explain; observed 2026-09-26 burn-in tick 4). The plugin's own
  // name is static — this script ships inside it — and the cache and
  // source trees nest to different depths, so match the options key by
  // name prefix instead of by path arithmetic.
  const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));
  const optionsEntry = Object.entries(cfg?.plugins?.options ?? {}).find(
    ([k]) => k.split("@")[0] === "xaas-fabric"
  );
  const options = (optionsEntry && optionsEntry[1]) ?? {};
  const auth = server.headers.Authorization.replace(
    /\$\{user_config\.([^}]+)\}/g,
    (_, dotted) =>
      dotted
        .split(".")
        .reduce((acc, key) => (acc == null ? acc : acc[key]), options) ?? ""
  );
  if (!auth || /^Bearer (undefined|null|)?$/.test(auth) || /[$]\{user_config\./.test(auth)) {
    return null;
  }
  return { url: server.url, auth };
}

function mcpTarget() {
  if (process.env.XAAS_MCP_URL && process.env.XAAS_MCP_TOKEN) {
    return { url: process.env.XAAS_MCP_URL, auth: `Bearer ${process.env.XAAS_MCP_TOKEN}` };
  }
  const cfgPath = process.env.ZCODE_CONFIG_PATH ?? path.join(homedir(), ".zcode", "cli", "config.json");
  const fromPlugin = pluginMcpServer(cfgPath);
  if (fromPlugin) return fromPlugin;
  const server = JSON.parse(readFileSync(cfgPath, "utf8"))?.mcp?.servers?.["xaas-execution"];
  if (!server?.url || !server?.headers?.Authorization) throw new Error("xaas-execution MCP server is not configured");
  return { url: server.url, auth: server.headers.Authorization };
}

async function admit(lease, tool) {
  const { url, auth } = mcpTarget();
  const res = await fetch(url, {
    method: "POST",
    headers: { "content-type": "application/json", accept: "application/json, text/event-stream", authorization: auth },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: { name: "admit_tool", arguments: { lease_token: lease.lease_token, tool } },
    }),
    signal: AbortSignal.timeout(8000),
  });
  // Evidence in the refusal itself: a bare "admit_tool error" (observed in
  // the 2026-09-26 burn-in) hides whether auth, transport or the court
  // refused. Status + a body snippet ride along, token never does.
  const raw = await res.text();
  let body = null;
  try {
    body = JSON.parse(raw);
  } catch {
    body = null;
  }
  const text = body?.result?.content?.[0]?.text ?? "";
  if (res.status !== 200) {
    return { ok: false, reason: `admit_tool HTTP ${res.status}: ${raw.slice(0, 160)}` };
  }
  if (!body?.result || body.result.isError) {
    return { ok: false, reason: text || `admit_tool error: ${raw.slice(0, 160)}` };
  }
  const decision = JSON.parse(text)?.decision;
  if (decision !== "allow") return { ok: false, reason: text };
  return { ok: true };
}

async function main() {
  if (process.env.XAAS_WORKER !== "1") process.exit(0);

  const payload = JSON.parse(readFileSync(0, "utf8"));
  const tool = String(payload.toolName ?? payload.tool_name ?? "");
  const input = payload.toolInput ?? payload.tool_input ?? {};
  const leaseCwd = process.env.XAAS_LEASE_CWD ?? payload.cwd ?? process.cwd();
  const ctx = { tool, leaseCwd };

  if (!tool) return decide("deny", "hook payload carried no tool name", ctx);
  // Denied before any lease read or admit_tool HTTP call: no network edge
  // exists for these tools from a leased worker.
  if (DENY_TOOLS.has(tool)) {
    return decide(
      "deny",
      `FORBIDDEN_EXTERNAL_SEMANTIC_EDGE: ${tool} is not a lawful edge for a leased worker; required UltraCode -> SA2A -> resolve_capability (policy ${POLICY.source})`,
      ctx
    );
  }
  if (/^mcp__(plugin_xaas-fabric_)?xaas-execution__/.test(tool)) return decide("allow", "lease protocol tool", ctx);

  if (tool === "Agent" && process.env.XAAS_ALLOW_SUBAGENTS !== "1") {
    return decide(
      "deny",
      "subagent spawning is denied under XAAS_WORKER=1: a subagent's own tool calls (Bash, Write, ...) are not routed through PreToolUse, so they would bypass this gate",
      ctx
    );
  }

  const lease = readLease(leaseCwd);

  if (tool === "Bash") {
    const reason = bashDecision(String(input.command ?? ""), lease, ctx);
    return reason ? decide("deny", reason, ctx) : decide("allow", "bash allowlist", ctx);
  }

  if (tool === "Read" || tool === "Grep" || tool === "Glob") {
    const reason = readPathDecision(input, ctx);
    if (reason) return decide("deny", reason, ctx);
    if (!lease && PRE_LEASE_OK.has(tool)) return decide("allow", "read-only tool before lease", ctx);
  }

  if (LOCAL_ONLY.has(tool)) return decide("allow", "local-only tool", ctx);
  if (!lease) {
    return PRE_LEASE_OK.has(tool)
      ? decide("allow", "non-consequential tool before lease", ctx)
      : decide("deny", `no live lease: ${tool} needs a claimed, saved lease (claim_next, then xaas-lease.mjs save)`, ctx);
  }

  if (WRITE_TOOLS.has(tool)) {
    const reason = writePathDecision(input, lease, ctx);
    if (reason) return decide("deny", reason, ctx);
  }

  const verdict = await admit(lease, TOOL_MAP[tool] ?? tool);
  return verdict.ok
    ? decide("allow", "admit_tool allow", ctx)
    : decide("deny", `admit_tool refused ${tool}: ${verdict.reason}`, ctx);
}

if (process.argv[1] && realpathLoose(process.argv[1]) === realpathLoose(fileURLToPath(import.meta.url))) {
  main().catch((err) => {
    try {
      process.stdout.write(
        JSON.stringify({
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: `xaas-gate: internal error, failing closed: ${String(err?.message ?? err)}`,
          },
        }) + "\n"
      );
    } finally {
      process.exit(0);
    }
  });
}
