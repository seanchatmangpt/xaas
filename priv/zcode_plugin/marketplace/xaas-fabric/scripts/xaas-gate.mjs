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
import { readFileSync, realpathSync, appendFileSync, mkdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { tmpdir, homedir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const STATE_DIR = path.join(tmpdir(), "xaas-fabric");

const PRE_LEASE_OK = new Set(["Read", "Grep", "Glob", "TodoWrite", "Skill"]);
const LOCAL_ONLY = new Set(["Skill"]);
const WRITE_TOOLS = new Set(["Write", "Edit", "NotebookEdit", "MultiEdit"]);
const TOOL_MAP = { Agent: "Task", TaskOutput: "Task", TaskStop: "Task", MultiEdit: "Edit", NotebookEdit: "Edit" };
const GIT_SUBS = new Set(["add", "commit", "status", "diff", "log", "rev-parse", "show", "ls-files"]);
const GIT_FORBIDDEN = new Set(["-c", "--exec-path", "--namespace", "--no-index", "-F", "--file", "-t", "--template"]);
const READ_HELPERS = new Set(["ls", "cat", "head", "tail", "wc"]);
const SENSITIVE_HOME_DIRS = [".zcode", ".ssh", ".aws", ".gnupg", ".config", ".claude", ".docker", ".kube", ".netrc", ".npmrc"];

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

function readLease(leaseCwd) {
  for (const cwd of new Set([leaseCwd, realpathLoose(leaseCwd)])) {
    try {
      const lease = JSON.parse(readFileSync(stateFile(cwd, ".json"), "utf8"));
      const expiresAt = Date.parse(lease.lease_expires_at ?? "");
      if (lease && typeof lease.lease_token === "string" && lease.lease_token && expiresAt > Date.now()) {
        return lease;
      }
    } catch {
      // try the next candidate key
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

  if (bin === "git") {
    let repo = cwdReal;
    let rest = args;
    if (rest[0] === "-C") {
      if (!rest[1]) return "git -C requires a path";
      repo = realpathLoose(path.resolve(cwdReal, rest[1]));
      rest = rest.slice(2);
    }
    if (!inside(worktree, repo)) return "git is only allowed inside the leased worktree";
    if (!GIT_SUBS.has(rest[0])) return `git ${rest[0] ?? ""} is not allowed (add, commit, status, diff, log, rev-parse, show, ls-files only)`;
    for (const a of rest) {
      if (GIT_FORBIDDEN.has(a) || a.startsWith("--git-dir") || a.startsWith("--work-tree") || a.startsWith("--output")) {
        return `git flag ${a} is not allowed`;
      }
    }
    return null;
  }

  if (READ_HELPERS.has(bin)) {
    if (!inside(worktree, cwdReal)) return `${bin} is only allowed with the session cwd inside the leased worktree`;
    for (const a of args.filter((x) => !x.startsWith("-"))) {
      if (!inside(worktree, realpathLoose(path.resolve(cwdReal, a)))) return `${bin} may only read inside the leased worktree`;
    }
    return null;
  }

  if (bin === "pwd" || bin === "echo") return null;

  return `${bin} is not an allowed command for a leased worker`;
}

function pathFor(input) {
  return input.file_path ?? input.filePath ?? input.notebook_path ?? input.path ?? null;
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

function mcpTarget() {
  if (process.env.XAAS_MCP_URL && process.env.XAAS_MCP_TOKEN) {
    return { url: process.env.XAAS_MCP_URL, auth: `Bearer ${process.env.XAAS_MCP_TOKEN}` };
  }
  const cfgPath = process.env.ZCODE_CONFIG_PATH ?? path.join(homedir(), ".zcode", "cli", "config.json");
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
  const body = await res.json();
  const text = body?.result?.content?.[0]?.text ?? "";
  if (!body?.result || body.result.isError) return { ok: false, reason: text || "admit_tool error" };
  return JSON.parse(text)?.decision === "allow" ? { ok: true } : { ok: false, reason: text };
}

async function main() {
  if (process.env.XAAS_WORKER !== "1") process.exit(0);

  const payload = JSON.parse(readFileSync(0, "utf8"));
  const tool = String(payload.toolName ?? payload.tool_name ?? "");
  const input = payload.toolInput ?? payload.tool_input ?? {};
  const leaseCwd = process.env.XAAS_LEASE_CWD ?? payload.cwd ?? process.cwd();
  const ctx = { tool, leaseCwd };

  if (!tool) return decide("deny", "hook payload carried no tool name", ctx);
  if (/^mcp__(plugin_xaas-fabric_)?xaas-execution__/.test(tool)) return decide("allow", "lease protocol tool", ctx);

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
