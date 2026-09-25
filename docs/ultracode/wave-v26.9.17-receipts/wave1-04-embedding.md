# Wave 1 / Agent 4 — ZCode programmatic embedding surface (READ-ONLY map)

Repo: `/Users/sac/dev/zcode-cli` (pkg `zcode-app-cli` 3.11.2-25, bundled runtime `zcode` 0.16.5, `vendor/extraction.json` cliVersion 0.16.5, extractedAt 2026-09-17). Entry: `package.json:29-31` → `"bin": {"zcode": "bin/zcode.js"}`; `bin/zcode.js:1849` → `process.exitCode = await main(process.argv.slice(2))` (bundled `src/launcher.ts`). Verification: runtime `--help` executed, arg-parse probes executed with isolated `HOME` (no model turn launched, per constraint).

## 1. Headless / print mode — flags that actually work

### 1.1 Verified against runtime 0.16.5 (`node vendor/zcode.cjs --help`, exact text)

```text
  --prompt <text>  Run a single prompt without opening the TUI
  -p, --print      Run a positional prompt without opening the TUI
  --attach <path>  Attach a local file to --prompt; repeat for multiple files
  --cwd <path>     Run this command from the given directory
  --disallowedTools, --disallowed-tools <tools...>  Comma or space-separated list of tool names to deny (e.g. "Bash(git *) Edit")
  --mode <mode>    Permission mode for prompts: build, edit, plan, or yolo (default: yolo for --prompt)
  --resume <sessionId>  Resume a persisted session by sessionId (sess_...)
  --target <text>  Run or set the session goal in headless mode
  --target-replace Replace any existing session goal set by --target
  -c, --continue        Resume the latest session for the current directory
  --json           Print machine-readable JSON where supported
  --output-format <string>   (in extraction.json runtimeCapabilities; not in help text)
  --surface <surface>  Presentation surface for headless prompts/app-server: terminal or desktop
```

### 1.2 IMPORTANT: `--print` is advertised but rejected by the runtime parser

- Executed probe (isolated HOME): `zcode --print "hello"` → **exit 1**, stderr: `Unknown option '--print'. To specify a positional argument starting with a '-', place it after '--' ...` (followed by help dump).
- `zcode -p "hello"` → parsed fine; with isolated HOME it stopped cleanly pre-model: **exit 1**, stderr: `Error: Model config is missing. Create <HOME>/.zcode/cli/config.json with an explicit model provider before running ZCode.`
- `zcode -p` (no value) → `Option '-p, --prompt <value>' argument missing` + help, exit 1. Minified parser (`vendor/zcode.cjs`, `parseGlobalArgs`): `prompt:{short:"p",type:"string"}` — `-p` is the **short form of `--prompt`**, value-carrying. stdin is never read for the prompt; prompt must be an argv value.
- Docs drift: `README.md:366`, `docs/DEVELOPMENT.md:111` still show `zcode --print "..."`; `docs/CONFIGURATION.md:5-6` names "`--prompt`, `--print`, `-p`, and `--target`". The **launcher** recognizes `--print` (`src/launcher.ts:194-198`, boolean → agentInvocation) but forwards it and the runtime rejects it. Scheduler must use `--prompt` / `-p` / `--target` only.
- Empty prompt: `--prompt requires non-empty text.` (`vendor/zcode.cjs`, var `eUi`), exit 1.

### 1.3 Model selection

- **No `--model` flag exists** in `parseGlobalArgs`/help. Model = `model.main` in `~/.zcode/cli/config.json` (or project `zcode.json` / `.zcode/config.json` in `--cwd`). "A resumed session may retain its previous model" (`docs/CONFIGURATION.md:307-308`). `model.lite` serves subagent work (`docs/CONFIGURATION.md:213-214`).

### 1.4 Permission modes

- `--mode build|edit|plan|yolo`; runtime: `(default: yolo for --prompt)` — headless **auto-approves by default**. Invalid value: `Unsupported --mode value: X. Supported modes: build, edit, plan, yolo.`
- Config default (generated, `bin/zcode.js:49-55`): `"permission":{"mode":"build","allowedTools":[],"disallowedTools":[],"autoApproveHighRisk":false,"allowMediumRiskInAuto":false}`.
- Denylist: `--disallowedTools`/`--disallowed-tools` (variadic, `src/launcher.ts:46`). No interactive approval is possible in `-p` mode — there is no remote permission channel; the only guards are mode, denylist, config `permission.*`, and hooks (disabled by default).

### 1.5 Output formats (`--output-format`, values verified in bundle)

- Allowed: `text | json | stream-json` — `vendor/zcode.cjs`: `myn=["text","json","stream-json"]`; error text: `--output-format must be one of text, json, stream-json (received: X).`
- `--json` boolean: sets JSON where supported; without `--output-format`, JSON summary is emitted only if `--json` given (`h_n = outputFormat===void 0 ? e.json : outputFormat==="json"||"stream-json"`).
- `--json` output = pretty JSON + `\n` (`hc = JSON.stringify(e,null,2)`): `{sessionId, traceId?, turnId?, response, usage?, eventCount, workspaceHookTrust?}`.
- `stream-json` = **NDJSON events** on stdout: each line `JSON.stringify(mapSessionEvent(event))` (`vendor/zcode.cjs`, `U=a(j=>{e.stdout.write(...)},"writeStreamEvent")`); tool-call payload kinds `scheduled|progress|result|error|batch` plus model/stream-recovery/permission events. Final line:
  `{"type":"result","sessionId":...,"traceId":...,"turnId":?,"response":...,"usage":{...}?,"eventCount":N,"projection":{"status":...,"turnCount":N,"totalTokenCount":N,"contextUsed":...,"contextWindow":...}}`
- `text` (default): bare assistant response + `\n` on stdout (`vendor/zcode.cjs`: `(e.stdout.write(\`${c.response}\`),0)`).

### 1.6 Sessions, resume, cwd

- New session per headless run; `sessionId` returned in json/stream-json output; sessions persist in `~/.zcode/cli/db/db.sqlite` (default config `storage.sessionDbPath`).
- Resume: `--resume <sess_...>` or `-c`/`--continue` (latest session for the cwd). Resume runs **skip the launcher key-preflight** (`src/launcher.ts:263` — `invocation.resume` returns undefined), matching `docs/CONFIGURATION.md:14` "resumed headless sessions remain the runtime's responsibility".
- Working directory: `--cwd <path>` (launcher records it at `src/launcher.ts:179-180`), or set the child process cwd (contract `docs/HOST_INTEGRATION.md:38-39`).

### 1.7 Launcher-injected behavior a host will observe

- For every agent invocation (`--prompt`/`-p`/`--target`/`--print`) the launcher prepends `--browser-use=headless` unless overridden (`src/launcher.ts:43`, `withDefaultBrowserUse` `src/launcher.ts:269-281`). Requires a discoverable Chrome/Chromium; override with `--browser-use=headless --browser-executable <path>` (`README.md:377-380`). `--browser-use` only supports value `headless` (runtime normalizer).
- Launcher injects env (`src/launcher.ts:299-318`): `ZCODE_BASE_URL` (default `https://zcode.z.ai`), `ZCODE_MODEL_RETRY_MAX_RETRIES` (default "5"), `ZCODE_APP_CLI_EXECUTABLE/ENTRY/VERSION`; first-run TUI gets `ZCODE_CLI_FIRST_RUN=1` (`src/launcher.ts:294-297`).

## 2. Host integration contract (`docs/HOST_INTEGRATION.md`, "Contract version: 1")

- Entry point: start published `zcode` executable, pass args unchanged: `zcode [arguments...]` (`:15-17`); "Hosts must not invoke `vendor/zcode.cjs` ... Those files are implementation details" (`:19-22`). "The launcher is a process boundary, not a library API" (`:24-25`).
- Streams: one PTY for interactive; "Do not ... parse ANSI screen output as an integration protocol"; non-interactive: "the command's documented output is the only supported machine interface" (`:27-37`).
- Signals: launcher forwards `SIGINT`, `SIGTERM`, (Unix) `SIGHUP`; "launcher returns the runtime's exit code. If the runtime exits because of a signal, the launcher uses the conventional `128 + signal number` status" (`:60-67`).
- Env table (`:73-78`): `ZCODE_NODE` (node executable override), `ZCODE_BASE_URL`, `ZCODE_MODEL_RETRY_MAX_RETRIES`, `ZCODE_TUI_RUNTIME_LOG` (bounded 2 MiB diagnostic log, rotated `.1`, default `~/.zcode/cli/tui-runtime.log` — `src/launcher.ts:44,361-389`; `docs/CONFIGURATION.md:363-375`).
- Version identity (`:92-97`): `zcode version` prints `zcode-app-cli <dist>` + `zcode-runtime <runtime>` (implemented `src/launcher.ts:121-130,476-485`).
- Host owns: install, workspace/env selection, PTY allocation, cancellation forwarding, exit capture, update/retention policy (`:103-111`). New machine-readable capabilities must be proposed as CLI output/contract bump, not scraped (`:126-128`).
- Reference host snippet (`:44-55`): `spawn("zcode", ["--cwd", workspace, ...args], { cwd: workspace, env: process.env, stdio: "inherit" })`.

## 3. app-server client (`src/app-server-client.ts`)

- Protocol: **one-shot NDJSON JSON-RPC-style** over stdio. Spawn `transport = {command: node, args: [<vendor/zcode.cjs>, "app-server"], cwd, env}` (`src/launcher.ts:512-523`), write a single line and close stdin:
  `child.stdin.end(\`${JSON.stringify({ id: 1, method: request.method, params: request.params })}\n\`)` (`src/app-server-client.ts:159`).
- Response: scan stdout lines for the JSON object with `id === 1` (`responseEnvelope`, `:102-116`); return `envelope.result`; envelope `{error:{code,message,data}}` → `AppServerRequestError` (`:172-177`); non-zero child exit → `AppServerProcessError` with preserved `exitCode` (`:179-181`, rationale `:78-84`); no envelope → generic Error.
- Bounds: stdout+stderr capped **16 MiB** (`maximumOutputBytes`, `:5`), overflow → SIGKILL + error; cancellation → `terminationSignal` (SIGTERM, or the abort reason signal) then **SIGKILL after 500 ms** (`forceTerminationDelayMilliseconds`, `:6,147-156`). `AppServerCancellationError` has `name:"AbortError"`, exitCode `128+signal` or default 130 (`:50-72`).
- Known methods (`src/plugin-protocol.ts:825-837`): `plugins/configure|describe|install|marketplace/add|marketplace/remove|marketplace/update|overview|referenceCatalog|restoreBuiltin|update|validate`. Params embed `workspace:{workspacePath, workspaceKey}` (`:838-844`). Contract tests: `test/app-server-client.test.ts:21-127` (envelope match, error code `-32602` passthrough, exit code 7 preserved, missing envelope, SIGTERM/SIGHUP cancellation exit 129).
- `zcode app-server` itself is described by the runtime as "Run the ZCode Protocol stdio app server" (long-lived), but this repo only exercises one request per spawn; no session-oriented methods are documented here.

## 4. Exit status / error semantics / timeouts

- Launcher returns the child exit code; `bin/zcode.js` sets `process.exitCode`. Signal death → `128 + signal number` (`signalExitCode`, `src/launcher.ts:320-324`; duplicated `src/app-server-client.ts:57-61`).
- Specific exits:
  - missing runtime bundle → 1 (`src/launcher.ts:469-474`);
  - launcher key-preflight rejection (new `-p/--prompt/--target`, only in the "unambiguously keyless Coding Plan" case, `src/prompt-preflight.ts:23-69`): stderr `Model access is not configured for <zai|bigmodel>. Run /login or /setup in zcode, or configure its API key before sending a prompt. No model request was sent.` → **1** (`src/launcher.ts:582-587`);
  - runtime's own gate (probe, isolated HOME): `Error: Model config is missing. Create <path> with an explicit model provider before running ZCode.` → 1;
  - TUI/runtime non-zero: `Error: ZCode runtime exited with status <code>. Diagnostics: <log path>` (`src/launcher.ts:391-396,434-436`);
  - plugin/app-server commands: `AppServerProcessError.exitCode` preserved; cancellation → 130 / `128+signal` (`src/plugin-cli.ts` catch `1316-1319`; test `test/plugin-cli.test.ts:94-101` returns 7);
  - OAuth login cancel → `128+signal` (`src/launcher.ts:331-333,574`).
- Timeouts: **no wall-clock timeout exists at any layer** — scheduler must enforce its own (kill via SIGTERM/SIGINT; forwarded to runtime, `src/launcher.ts:417-426`). In-process knobs: config `network.timeout` (default 180000 ms) and `modelStream.idleTimeoutMs` (default 60000) (`config.example.json`; `docs/CONFIGURATION.md:348-356`), `ZCODE_MODEL_RETRY_MAX_RETRIES` (default 5, auth/invalid-request non-retryable, `docs/CONFIGURATION.md:340-361`). OAuth callback wait default 5×60 s (`src/darwin-oauth-callback.ts:303` `defaultTimeoutMs = 5 * 6e4`). app-server request waits until exit or abort (`src/app-server-client.ts:162-166`).

## 5. Missing / blockers for unattended scheduler invocation

1. **Auth bootstrap is the main blocker.** Three paths (`docs/CONFIGURATION.md:104-119`): (a) Z.AI OAuth — macOS-only (`src/zai-oauth.ts:122-129`), needs a browser and the `zcode://zai-auth/callback` URL-scheme callback landing on the same Mac; `login --no-browser` prints the URL but cannot complete headless; 5-min timeout; not schedulable. (b) Coding Plan API key via `/login` in the TUI — interactive. (c) **Scriptable path**: pre-write `~/.zcode/cli/config.json` (mode 600) with `provider.<id>.options.apiKey` inline (`docs/CONFIGURATION.md:152-218`). Caveat quoted: "The no-login TUI path currently requires a non-empty `options.apiKey` in the local config; an environment-only API key does not satisfy the upstream login gate" (`:216-218`). Whether an env-only key (e.g. `ANTHROPIC_API_KEY`-style, which the preflight honors as a bypass signal, `src/prompt-preflight.ts:29-33`) satisfies the *runtime* headless gate is UNKNOWN — must be probed with a real key.
2. **`--print` is broken** despite being documented (`README.md:366,372-374`; `docs/DEVELOPMENT.md:111`); runtime 0.16.5 rejects it. Use `-p`/`--prompt`.
3. **No model override flag** in headless; per-run model selection requires rewriting `model.main` in config or a project `zcode.json` per workspace.
4. **No remote permission approval** for headless turns: default `--mode yolo` auto-approves everything; safe unattended profile must pass explicit `--mode build|plan` + `--disallowed-tools`. Hooks (`PermissionRequest` event) exist in config but default `hooks.enabled=false`.
5. **No wall-clock timeout / no daemon API**: nothing in the public surface can start, steer, or cancel a session over the app-server protocol (only `plugins/*` methods are defined, `src/plugin-protocol.ts:825-837`). Cancellation = signals to the process; progress observability = `stream-json` lines only.
6. **Node >= 22.19 required** (`package.json:74-76`); runtime needs `node:sqlite`. Default PATH node may be older (probe: node v20.13 fails with `No such built-in module: node:sqlite`). Scheduler should set `ZCODE_NODE=/path/to/node22+`.
7. Scheduler hygiene: set `ZCODE_DISABLE_UPDATE_CHECK=1`/`NO_UPDATE_NOTIFIER=1` (`README.md:75-79`) and optionally `ZCODE_DISABLE_MODEL_CATALOG_REFRESH=1` or `CI=1` (`docs/CONFIGURATION.md:64-66`); pin the package version (contract `:84-88`).
8. `setup-pending` marker (`~/.zcode/cli/setup-pending`) "survives non-interactive commands (`zcode plugin list`, `zcode -p …`, `app-server`, …)" (`docs/CONFIGURATION.md:70-75`) — harmless headless, but the wizard appears on the next interactive start until configured.

## 6. Exact example command lines for an Elixir/XaaS scheduler

```bash
# identity probe (cheap, no model call)
zcode version                                   # -> "zcode-app-cli X\nzcode-runtime 0.16.5"
zcode doctor --json                             # runtime packaging inspection

# one-shot prompt, text result on stdout, exit 0 = success
zcode --cwd /path/to/repo --prompt "Explain this repository"

# machine-readable single summary (pretty JSON: sessionId/response/usage/eventCount)
zcode --cwd /path/to/repo --output-format json --prompt "fix the failing test in src/foo.ts"

# epoch-loop surface: NDJSON event stream; final line type:"result" carries projection token totals
zcode --cwd /path/to/repo --output-format stream-json --prompt "run mix test and fix failures"

# constrained unattended profile (do NOT rely on default yolo for production)
zcode --cwd /path/to/repo --mode build --disallowed-tools "Bash(git push) Bash(mix deps.get)" \
  --output-format json --prompt "…"

# epoch continuation: resume by id (json output's sessionId) or latest-in-cwd
zcode --cwd /path/to/repo --resume sess_abc123 --output-format stream-json --prompt "next epoch step"
zcode --cwd /path/to/repo --continue --output-format json --prompt "continue"

# goal-style headless run
zcode --cwd /path/to/repo --target "make the suite green" --target-replace --output-format json

# env the scheduler should pin
ZCODE_NODE=/usr/local/node22/bin/node ZCODE_DISABLE_UPDATE_CHECK=1 \
  ZCODE_MODEL_RETRY_MAX_RETRIES=3 ZCODE_TUI_RUNTIME_LOG=/tmp/zc-tui.log \
  zcode --cwd … --output-format stream-json …

# plugins (launcher-owned, app-server NDJSON under the hood)
zcode plugins list --json && zcode plugins discover --json

# cancellation: Port/spawn the process, then SIGTERM (exit 143) or SIGINT (exit 130)
```

Elixir shape: `Port.open({:spawn_executable, zcode_bin}, [:exit_status, :use_stdio, :stderr_to_stdout, {:args, ["--cwd", dir, "--output-format", "stream-json", "--prompt", prompt]}])`, read line-delimited JSON, `Port.monitor`/`sys.get_status` for exit; for kill use `Port.command(port, <<255, 246>>)`-equivalent via a SIGTERM-capable wrapper (`:exec` or `Port` + `kill`). Note stderr_to_stdout mixing breaks stdout NDJSON purity — keep stderr separate and log it to `ZCODE_TUI_RUNTIME_LOG`-style file.

## Key file:line index

- `docs/HOST_INTEGRATION.md:8,15-25,27-39,60-67,73-78,92-99,103-116` — contract v1
- `src/launcher.ts:43-46,47-70,179-181,194-206,233-244,259-267,269-281,294-318,320-324,391-396,468-474,512-523,582-589` — flags, browser-use injection, env, exit codes, preflight gate
- `src/app-server-client.ts:5-6,8-30,32-55,102-116,118-190` — NDJSON protocol, caps, cancellation, error classes
- `src/plugin-protocol.ts:825-844` — method table + workspace param
- `src/prompt-preflight.ts:23-69` — keyless-Coding-Plan headless gate + bypasses (env regex, project zcode.json/.zcode/config.json/.env)
- `src/zai-oauth.ts:9-12,56-67,122-129,146-161` — OAuth flow (macOS-only, `--json`/`--no-browser`, 5-min callback wait)
- `bin/zcode.js:12-125` (default config: permission/network/modelStream/hooks), `bin/zcode.js:1849` (entry)
- `vendor/extraction.json` — runtimeCapabilities.cli.globalOptions (authoritative option table); cliVersion 0.16.5
- `docs/CONFIGURATION.md:3-16,104-119,152-218,310-318,338-361,363-375` — auth paths, headless, timeouts, diagnostics
- `test/app-server-client.test.ts:21-127`, `test/plugin-cli.test.ts:94-101` — protocol/exit-code contract examples
