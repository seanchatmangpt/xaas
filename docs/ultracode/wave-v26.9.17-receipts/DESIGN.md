# DESIGN.md — Binding integration design: XaaS Ultracode ↔ ZCode

Wave 1, agent 9. Read-only basis: /tmp/uzc/wave1-01..08 + spot verification this session
(2026-09-16): config.json auth-shape classified (no token printed), endpoint probed
(401 fail-closed confirmed on GET and POST), installed-plugin drift diffed, xaas branch
state read (`feat/execution-actuation-fabric` @ `fd68647`, 9 dirty files).
Constraints honored: zero modifications to /Users/sac/xaas, /Users/sac/dev/zcode-cli, ~/.zcode.

Milestone falsifier being designed for: **the epoch loop survives deleting the hourly
Claude routine** (`trig_01X4MaMBcr9DuFhVVZjJuLbQ`, c4-architecture.md:148;
`Remove(ClaudeCode) ⇒ Behavior(Ultracode) = Unchanged`, c4-architecture.md:17-25).

---

## 1. State matrix

Standing vocabulary per 法 証: ALIVE requires observed execution against the exact
admitted subject in-session; inspection ≠ execution. "ALIVE (code)" below means
test-proven but not yet exercised live from the bridge.

| # | Component | Lives at | Standing | Evidence |
|---|---|---|---|---|
| 1 | Lease kernel `Xaas.Ultracode.Lease` (claim/renew/admit_tool/close/refuse) | `/Users/sac/xaas/lib/xaas/ultracode/lease.ex` | ALIVE (code) — tests prove claim→admit→close, refusals, head-verification; zero production Runs yet | wave1-01 §1.4 (lease.ex:59-81,149-159,190-213); lease_test.exs:86-167; wave1-03 §4 |
| 2 | Execution fabric MCP endpoint `POST /internal-api/execution/mcp` | `/Users/sac/xaas/lib/xaas_web/controllers/execution_fabric_controller.ex` (router.ex:83) | PARTIAL_ALIVE — ConnCase-proven (controller_test:57-107); endpoint live on :4000 returns 401 fail-closed (probed this session); controller has UNCOMMITTED working-tree edits | wave1-01 §3.1; wave1-02 §1a; this session curl 401; `git status` |
| 3 | Hooks endpoint `POST /internal-api/execution/hooks/:event` | same controller (router.ex:82) | PARTIAL_ALIVE — same gate + tests; server-side fixes (flat body, `post_tool_use_failure` URL) uncommitted | wave1-01 §3.1; HANDWRITTEN.md:47-50 (Shrunk, "uncommitted in working tree") |
| 4 | Plugin templates `priv/templates/zcode_plugin/**` (14 files) | `/Users/sac/xaas/priv/templates/zcode_plugin/` | PARTIAL_ALIVE — 7 files fixed in working tree, uncommitted | `git status` this session; HANDWRITTEN.md:14,47-50 |
| 5 | Rendered plugin `generated/xaas-zcode-plugin/` | `/Users/sac/xaas/generated/xaas-zcode-plugin/` | STALE — hook scripts match the PRE-fix installed copy (nested `event:{}` body; `post_tool_failure.mjs` posts to wrong segment `post_tool_use`); not re-rendered after template fixes | drift diff this session (installed ≡ generated, both pre-fix) |
| 6 | Installed plugin `xaas-fabric` | `~/.zcode/cli/plugins/marketplaces/xaas-fabric-marketplace/xaas-zcode-plugin/` | PARTIAL_ALIVE — present + enabled + hooks auto-enabled; hook scripts STALE (see #5); `zcode plugins install` path BLOCKED by confirmed ZCode 3.11.2-25 bug (install hardcodes empty env-substitution context → bearer secret never resolves at install) | config.json `plugins.enabledPlugins` (verified); HANDWRITTEN.md:27-33 |
| 7 | User-scope MCP registration `mcp.servers.xaas-execution` | `~/.zcode/cli/config.json:91-97` | ALIVE — http transport, url `http://localhost:4000/internal-api/execution/mcp`, Authorization **LITERAL_TOKEN** (classified, not printed); end-to-end MCP connectivity from live ZCode 3.11.2-25 confirmed 2026-09-16 | wave1-05 §0; HANDWRITTEN.md:24-26; this session shape check |
| 8 | Hooks config `hooks.enabled: true` (7 event arrays, empty) | `~/.zcode/cli/config.json:138-154` | ALIVE (config) — plugin hooks supply the matchers; config-file arrays empty | wave1-05 §0, §3 |
| 9 | AshOban tick loop (`* * * * *` → `:tick` → Reactor) | `/Users/sac/xaas/lib/xaas/ultracode/run.ex:44-61`, `reactor.ex:61-105` | ALIVE in dev — `RUN_REACHED_COMPLETED_UNATTENDED`, two live trials, zero external Reactor calls; PRODUCTION_LIVE = UNKNOWN | wave1-02 §2 (PROGRESS.md:228-233,448-449) |
| 10 | Run admission (`create`/`:start`) | run.ex:97-145 | PARTIAL_ALIVE — works in BEAM only; **no HTTP route creates/starts a Run** (load-bearing gap) | wave1-01 §3.3; wave1-02 §1c |
| 11 | Provider-pull lane (`Run.provider = "zcode"` → `:await_provider`) | run.ex:179-181; epoch_reactor.ex:113-117 | ALIVE (code); zero production Runs use it | wave1-01 §1.1, §2; wave1-03 §4 |
| 12 | Receipt sealing + policy wall | `/Users/sac/xaas/lib/xaas/ultracode/receipt.ex` | ALIVE (code) — seal-only policy; external reads = DB / ocel_summary / telemetry only | wave1-01 §1.3, §5 |
| 13 | zcode headless surface (`-p`/`--prompt`, `--output-format stream-json`, `--cwd`, `--resume`) | `/Users/sac/dev/zcode-cli` (runtime 0.16.5) | ALIVE — probes executed this wave; `--print` BROKEN despite docs; no `--model` flag | wave1-04 §1.1-1.2, §1.5 |
| 14 | zcode unattended model auth | `~/.zcode/cli/config.json` (`provider.zai`, `model.main` set — verified this session) | ALIVE on this host (config-path); env-only key UNKNOWN | wave1-04 §5.1 (docs CONFIGURATION.md:216-218); this session provider/model check |
| 15 | Consequence fence (`admit_tool` refuses Bash/git_push/publish) | lease.ex:44-46 | ALIVE — verified in source this session; tripwire tests lease_test.exs:86-98 | wave1-06 §2; this session sed of lease.ex:44-46 |

Net: the seam is real and half-qualified. The unqualified residue is exactly the
ledger's paydown item 1 (HANDWRITTEN.md:22-33): hook event names, plugin-root
expansion, .mcp.json env-header support at runtime — plus the two hygiene/staleness
defects found this session (#5, #7-token).

---

## 2. Pareto frontier — three integration options

Applicability first (法 柵): each option is applicable to a different question.
None dominates; the frontier is genuine.

### Option A — Qualify the existing seam in situ (live zcode session drives the lease cycle)

- **Shape**: use exactly what exists — user-scope MCP entry (#7) + installed plugin
  (#6) + a live interactive `zcode` session invoking `mcp__xaas-execution__*` tools;
  hooks re-rendered and refreshed but treated as defense-in-depth, not load-bearing.
- **Prerequisites**: dev server `:4000` with `INTERNAL_API_TOKEN` set; a provider-pull
  Run admitted by operator one-liner (`mix run -e`, the only lawful admission path
  today, #10); `ZCODE_XAAS_TOKEN` exported in the session; re-render `generated/`
  from fixed templates and refresh the installed plugin copy (manual copy — install
  path blocked, HANDWRITTEN.md:27-33); commit the working-tree fixes first (operator
  cut — they are 産面 edits already ledgered).
- **Proves**: P1+P2 falsifiers — MCP handshake from real runtime (partially proven
  already, HANDWRITTEN.md:24-26), first `provider=zcode` lease
  claimed→admitted→head-verified-closed with a Receipt row, zero Bash. Also
  qualifies plugin-root expansion + hook event names empirically.
- **Cannot**: run unattended (a human opens the session); create/Start Runs; satisfy
  the deletion falsifier alone.
- **Reversibility**: highest of the actuation options — no new lib code; config and
  rendered-artifact refresh only; `git checkout` + re-render undoes everything.
- **Effort**: S (hours). Mostly verification + re-render.

### Option B — Unattended direction: XaaS-side dispatch of headless `zcode -p` workers at the `:await_provider` seam

- **Shape**: XaaS-side dispatcher (Oban worker or mix task) spawns
  `zcode --cwd <epoch worktree> --output-format stream-json -p "<claim, construct
  within fence, close_candidate>"` per claimed epoch; worker loop mirrors the plugin's
  `/xaas` command (wave1-05 §2). Fleet governed by dispatcher-enforced ≤16 ceiling
  (no CLI knob exists — wave1-08 §1), top-up-only saturation, [1302] transparent
  retry, 20-min reap (wave1-08 RUNBOOK).
- **Prerequisites**: Option A complete (seam qualified); unattended model auth probed
  (wave1-04 §5.1: env-only key may not satisfy the runtime gate — must be probed with
  a real key; fallback is inline apiKey in config, mode 600); a Run-admission
  mechanism (the #10 gap) — see phased plan P4; worktree discipline per epoch
  (wave1-08 §3).
- **Proves**: P3+P4 — a full epoch executed by zcode, and ultimately the deletion
  falsifier: the loop completes epochs (and, with the admission worker, admits new
  Runs) with no Claude routine cycles.
- **Cannot**: do anything in the consequence class — Bash/git_push/publish refused by
  the court (lease.ex:46); integration merges stay operator/rider-serialized (法 並).
- **Reversibility**: medium — new 産面 files on the xaas side (dispatcher, admission
  worker), each needing a ledger row; removal is `git rm` but the code is real debt.
- **Effort**: M→L (dispatcher + admission path + capacity governor + falsifier run).

### Option C — Lighter query-only surface (`/ultracode` command + MCP reads, no hooks)

- **Shape**: one user-scope file `~/.zcode/commands/ultracode.md` (frontmatter:
  `description`, `argument-hint`; body instructs the agent to call
  `mcp__xaas-execution__*` / read `ocel_summary`); no plugin, no hooks, no lease.
- **Prerequisites**: only #7 (already ALIVE).
- **Proves**: observation lane — runs/epochs state readable from any session;
  cheapest high-information gate first (法 証).
- **Cannot**: actuate anything; does not advance the milestone falsifier by itself;
  receipts are policy-walled so reads go through DB/ocel_summary, not Ash.
- **Reversibility**: absolute — delete one file.
- **Effort**: XS (minutes).

### Frontier reading (no single best)

- A dominates on evidence-per-risk and is a hard prerequisite for B (never build a
  dispatcher on an unqualified seam — 法 偽).
- B is the only option that reaches the milestone falsifier; it is unjustified until
  A's falsifiers pass.
- C is the cheapest standing tripwire and should exist regardless (observability for
  every later phase); it composes with A and B rather than competing.

---

## 3. Recommendation + phased plan

**Recommendation: A → B, with C folded in at P0.** Rationale (法 柵: the change
preserving the most lawful options): A spends almost nothing and converts the
half-alive seam into receipted evidence; every option B prerequisite is either built
by A or falsified by A cheaply. B then extends the qualified seam with the minimum
new 産面 surface (dispatcher + admission), which is the only route to the deletion
falsifier. Skipping A to build B first would couple "dispatcher bugs" with "seam
bugs" in one unattributable failure — the canonical five-defects-zero-compile-errors
shape.

**The Run-admission gap (#10)** is handled explicitly per phase: P1–P2 need no Run
from HTTP; P3 admits the Run by named operator cut (`mix run -e` = the operator's
fresh authority, recorded in the receipt); P4 closes the gap with a ledgered
XaaS-side admission worker through Ash validations (never a hand-written DB insert,
never a second hand-edited projection of the Run table). Each phase records the
failed edge "no HTTP create/start route" until P4 lands, so the gap stays visible.

| Phase | Falsifier (explicit, binary) | Admission-gap handling | Option |
|---|---|---|---|
| **P0** | `git status` on /Users/sac/xaas clean after operator-authorized commit of the 9 dirty files; `generated/` re-rendered (diff vs templates empty); installed plugin copy byte-equal to `generated/` | n/a | A prep |
| **P1** | MCP `initialize` + `tools/list` handshake returns the 6 tools (`claim_next heartbeat admit_tool record_provider_event close_candidate refuse`) from a live `zcode` runtime session, receipted in this wave's log; no-token probe still 401 | none needed — handshake is lease-free | A |
| **P2** | One `provider="zcode"` lease: `claim_next` → `admit_tool("Edit")` allow → one file edit in the epoch worktree → `close_candidate(final_head)` → row in `ultracode_receipts` with `outcome=alive`, `evidence.head_verified=true`; **zero Bash invocations in the session** (also proven negatively: `admit_tool("Bash")` → typed refusal) | Run admitted by operator `mix run -e` one-liner; the exact command + SHA pasted into the receipt (operator's fresh cut, 権) | A |
| **P3** | One full epoch advanced by the loop itself: operator admits Run (max_cycles=1, provider=zcode) → tick 1 creates Epoch `:expected` → tick moves `:start`→`:running` → tick hits `:await_provider` → zcode session claims → closes head-verified → next tick's NextEpoch transitions Run → `:completed/:admitted`. Falsified if any Reactor step was manually invoked | Same operator admission; epoch flow itself must be Oban-cron-only (observe `oban_jobs` rows as evidence) | A |
| **P4** | **Deletion falsifier**: with the cloud routine producing zero new cycles for a declared window (≥3 epochs or 24h, whichever longer), the loop still completes epochs end-to-end: XaaS-side dispatcher spawns headless `zcode -p` workers that claim/construct/close, and the ledgered admission worker admits new Runs from ticket files. `Remove(ClaudeCode) ⇒ Behavior(Ultracode) = Unchanged` observed, not argued | Gap closed in-repo: admission worker (ledger row, Ash-validated) + optional internal-api route only if the worker proves insufficient (route needs its own admission through Path A courts — out of P4 scope unless required) | B |

P1 may partially pass already (HANDWRITTEN.md:24-26 — MCP connectivity confirmed
ALIVE 2026-09-16); it must be re-receipted against the post-P0 refreshed tree, since
that note predates the template fixes.

---

## 4. Exact change list per phase, per side

Legend: 法面 vs 産面 per 界. Every new/changed 産面 file gets a HANDWRITTEN.md row
(format: `path | semantic element | missing capability | intended owner pack | date`).
Existing paydown plan: HANDWRITTEN.md:20-41 (qualify plugin vs ZCode 3.11.2 → promote
`zcode-plugin-pack` → extract `ultracode-actuation-lease-pack`).

### P0 — commit fixes + refresh projections (xaas side; operator-authorized commit)

| Change | Side | Path |
|---|---|---|
| Commit 9 dirty files (controller, 6 templates, HANDWRITTEN.md, tests) | 産面 | `/Users/sac/xaas/lib/xaas_web/controllers/execution_fabric_controller.ex`, `/Users/sac/xaas/priv/templates/zcode_plugin/**` (6 files), `/Users/sac/xaas/HANDWRITTEN.md`, `/Users/sac/xaas/test/xaas_web/execution_fabric_controller_test.exs` |
| Re-render plugin | 法面→projection | `mix xaas.gen_zcode_plugin --endpoint http://localhost:4000 --token-env ZCODE_XAAS_TOKEN --output generated/xaas-zcode-plugin` (task at `/Users/sac/xaas/lib/mix/tasks/xaas.gen_zcode_plugin.ex`) |
| Refresh installed copy (install path BLOCKED by ZCode bug) | 産面 (consumer) | `rsync` `generated/xaas-zcode-plugin/` → `~/.zcode/cli/plugins/marketplaces/xaas-fabric-marketplace/xaas-zcode-plugin/` (manual copy is itself a ledgered deviation until the install bug is fixed — see rows below) |

Ledger rows (add to `/Users/sac/xaas/HANDWRITTEN.md` Active):
```
~/.zcode/cli/plugins/marketplaces/xaas-fabric-marketplace/ (manual install copy) | installed ZCode plugin projection | zcode 3.11.2-25 plugins install cannot resolve plugin env secrets (empty substitution context); manual copy until fixed | zcode-plugin-pack (install-path fact) | 2026-09-16
```
(existing rows for templates/generator/controller/lease/tests already cover the rest.)

### P1 — MCP handshake receipt (no file changes; evidence only)

- Session probe from live zcode: `mcp__xaas-execution__*` visible; `tools/list` = 6.
- `~/.zcode/cli/config.json`: **no edit in P1** (token hygiene is P0-parallel, §5).
- Receipt: command, tool list, exit/status into wave log.

### P2 — first lease cycle, zero Bash (no new files; one operator cut)

- Operator (BEAM): `mix run -e` admitting Run `{goal, max_cycles: 1, provider: "zcode"}`
  with `:start exact_subject: <worktree git rev-parse HEAD>` (convention:
  run_start_test.exs:28-30, wave1-01 §6).
- Session: claim_next → admit_tool("Edit") → edit → heartbeat if >30min
  (lease.ex:42) → close_candidate.
- Verify: `select * from ultracode_receipts order by sealed_at desc limit 1` —
  outcome alive, head_verified true (DB read is the lawful external channel, #12).
- HANDWRITTEN.md: append Shrunk row: paydown item 1 MCP+close-cycle qualification
  `| close-cycle qualified live (claim→admit→close, head_verified) | 2026-09-16`-style
  entry; do NOT delete Active rows yet (hooks still unqualified).

### P3 — full epoch via cron only (no new files)

- Same operator admission; all advancement via Oban cron. Evidence: `oban_jobs` rows +
  `ultracode_epochs.final_head` + Receipt. Session may claim only after `:await_provider`.
- No code changes; failing this phase falsifies #9's dev-only ALIVE or the seam —
  preserve command/exit/diagnostic (法 証).

### P4 — dispatcher + admission (new 産面 files, each with a ledger row)

| Change | Side | Path | Ledger row (add to Active) |
|---|---|---|---|
| Run-admission worker: creates+starts a provider-pull Run per queued ticket goal, Ash-validated, `exact_subject` = worktree HEAD | 産面 | `/Users/sac/xaas/lib/xaas/ultracode/run_admission_worker.ex` (+ test `/Users/sac/xaas/test/xaas/ultracode/run_admission_worker_test.exs`) | `lib/xaas/ultracode/run_admission_worker.ex \| autonomous Run admission from ticket goals \| no admitted pack expresses Run admission as a workflow step \| ggen-marketplace ultracode-actuation-lease-pack \| <date>` |
| ZCode dispatcher: per `:await_provider` epoch, spawn `zcode --cwd <worktree> --output-format stream-json -p "<claim/construct/close>"`; enforces ≤16 in-flight, top-up-only, [1302] retry, 20-min reap (wave1-08 RUNBOOK) | 産面 | `/Users/sac/xaas/lib/mix/tasks/xaas.ultracode.dispatch_zcode.ex` | `lib/mix/tasks/xaas.ultracode.dispatch_zcode.ex \| headless zcode executor dispatch at the await_provider seam \| no admitted pack expresses external executor dispatch/capacity governing \| zcode-plugin-pack family extension \| <date>` |
| Unattended auth profile (if probe fails env-only): pin inline apiKey, mode 600, no commit of secrets | consumer config | `~/.zcode/cli/config.json` (mode 600; secrets never enter VCS, 法 源) | row only if a wrapper file is needed (see §5 option 2) |

Paydown linkage (same-change rule, 法 帳): P4's two new rows grow the ledger; the
paydown plan gains: "P4 dispatcher/admission fold into `ultracode-actuation-lease-pack`
+ `zcode-plugin-pack` at next pack admission; hook-qualification residue of paydown
item 1 closes at P3 receipt." Ledger grows only with this plan attached.

---

## 5. Token hygiene — the literal Authorization header

**Current state (verified this session)**: `~/.zcode/cli/config.json`
`mcp.servers.xaas-execution.headers.Authorization` = LITERAL_TOKEN (classified, not
printed). Cause (wave1-05 §1, :55, diagnosing-mcp SKILL.md:35): **config-file MCP
servers do not expand `${VAR}` templates — only plugin-provided MCP servers do**
(`$CLAUDE_PLUGIN_ROOT`, `$ZCODE_PLUGIN_ROOT`, `$user_config.KEY`, env vars). So the
user-scope entry forced the literal form; the plugin's `.mcp.json` twin already uses
`"Bearer ${ZCODE_XAAS_TOKEN}"` (verified in installed plugin + generated/).

**Remediation options** (Pareto, cheapest gate first):

1. **Promote the plugin twin, demote the user entry (recommended).** Delete
   `mcp.servers.xaas-execution` from config.json; export `ZCODE_XAAS_TOKEN` in the
   operator shell/login env; the plugin server (already registered via enabled
   `xaas-fabric`) supplies the same endpoint with `${ZCODE_XAAS_TOKEN}` expansion.
   Precedence note (wave1-05 §5, :101): user scope currently overrides the plugin
   twin, so removal *promotes* the plugin entry — the exact intended flip.
   Fail-closed: unset env → `Bearer ` → 401, never a silent open. **Caveat**: the
   HANDWRITTEN install-time bug (config.json twin note, HANDWRITTEN.md:27-33) breaks
   substitution *at install time*; whether *runtime* expansion works for an already
   installed plugin is UNKNOWN → P0.5 probe: remove user entry, `ZCODE_XAAS_TOKEN=… zcode`
   then tools/list. This single probe fixes both scope and hygiene if it passes
   (cites wave1-05 §1 pitfall + §5 precedence).
2. **Stdio wrapper server** (fallback if 1's runtime expansion is broken by the same
   bug): register a stdio server in config.json whose `command` is a small exec
   script that reads `ZCODE_XAAS_TOKEN` from the inherited environment and bridges
   to the HTTP endpoint. Env passthrough needs no template expansion. Cost: one new
   産面 file + ledger row + one extra hop; keeps config.json secret-free.
3. **Keep literal, minimize blast radius** (weakest, last resort): rotate to a
   dedicated least-privilege internal token, chmod 600 config.json, ensure the file
   is excluded from every synced/committed tree (wave1-05 §5 last bullet). The
   deviation remains on the books.

Whichever passes: the loser form is removed in the same change; receipt records the
probe. Secrets never enter version control (法 源) — `ZCODE_XAAS_TOKEN` value stays
in operator env only.

---

## 6. REFUSED boundaries + risk register

### What the bridge must NEVER do without a fresh operator cut (権)

- **Consequence class**: git push, PR open/merge, publish, deploy, delete, spend,
  external disclosure (c4-architecture.md:100-120 via wave1-06 §2). Concretely
  enforced today: `admit_tool` refuses `Bash git_push publish` and all unknown
  classes (lease.ex:44-46 — verified in source; tripwires lease_test.exs:86-98).
- **No fence-widening**: widening the allow-list or adding a configurable authority
  ceiling requires `AuthorityCeiling` modeled as a real field + real check
  (epoch_reactor.ex:50-56 demands this explicitly) plus a fresh operator authority
  cut crossing Path A's `Proposal → Admission → Authority → DO → Receipt`
  (wave1-06 §5). A request naming authority is not authority.
- **No second projection**: never hand-edit `generated/` or the installed plugin to
  fix behavior — edit the templates and re-render (法 器; the P0 staleness defect
  #5 exists precisely because a render was skipped, not because a template was wrong).
- **No hand-written Run/Epoch/Receipt rows** in the DB — admission goes through Ash
  actions; bypass receipts = fabricated evidence (wave1-02 §4 row 4).
- **git discipline**: bridge commits live on purpose branches in epoch worktrees;
  integration = at most ONE gated `--no-ff` merge per cycle, writer-free checkout,
  red gate → reset + BLOCKED (法 並 rider law; wave1-08 §3-4). Never assume `main`.

### Capacity fit (並; wave1-08)

- Heavyweight flash ≤16 in-flight, fleet-wide, **enforced by the dispatcher** (no CLI
  knob exists — wave1-08 §1). Saturation by top-up only; never bulk-burst.
- `[1302]` isolated incidents → transparent re-dispatch (same ticket, fresh process,
  counts as top-up); storm signature (incidents/hour scaling with load) → stop,
  drain minutes, resume half pace; repeat → halve. In-process retry left at default
  (`ZCODE_MODEL_RETRY_MAX_RETRIES=5`, launcher.ts:42).
- Reap at 20-min worktree silence; lease TTL 30 min is the hard backstop
  (lease.ex:42,70) — a forfeited epoch records the typed refusal honestly.

### Top 5 failure modes + mitigations

| # | Failure mode | Likelihood today | Mitigation |
|---|---|---|---|
| 1 | **Stale plugin artifacts**: hooks in installed copy + `generated/` carry pre-fix bugs (nested `event:{}` bodies; `post_tool_failure` → wrong URL) — observed this session | CERTAIN until P0 | P0 re-render + manual refresh + byte-equal diff gate; permanent guard: render-freshness check (diff generated vs templates) added to paydown item 1's gate list |
| 2 | **Lease expiry mid-construction** (TTL 30 min, no heartbeat) → epoch forfeited, typed refusal recorded | medium for long epochs | heartbeat cadence ≤10 min in worker loop + dispatcher reap at 20 min (wave1-08); refusal receipt is honest evidence, not an error to suppress |
| 3 | **Unattended auth gate**: env-only model key may not satisfy the runtime headless gate (docs CONFIGURATION.md:216-218 via wave1-04 §5.1) → P4 workers die at launch | unknown until probed | P4-entry probe with real key before building the dispatcher; fallback inline apiKey mode 600; `ZCODE_NODE` ≥22.19 pinned (wave1-04 §5.6) |
| 4 | **Token leak / scope confusion**: literal bearer in config.json (#7); two twin server entries with precedence surprises (user overrides plugin, wave1-05 §5) | present now | §5 remediation option 1 + P0.5 probe; one entry survives; config.json excluded from synced trees |
| 5 | **Run-admission gap closed unsafely** (hand-rolled HTTP route or DB insert bypassing validations/courts to make P4 "easier") | design pressure at P4 | admission only via Ash actions in the ledgered worker; any HTTP route goes through Path A admission + its own authority cut; failed edge stays recorded until then |

(Residual: [1302] storms → runbook above; Oban queue saturation `default: 10`
(config.exs:73-83) is far below 16 and serializes epochs per run anyway —
reactor.ex:77-95 serial `Enum.map`, one wave per run per minute, wave1-08 §2.)

---

## Evidence appendix — this session's verifications

- `~/.zcode/cli/config.json`: `mcp.servers` = {xaas-execution}, type http, url
  `http://localhost:4000/internal-api/execution/mcp`, Authorization classified
  LITERAL_TOKEN; `enabledPlugins` = {xaas-fabric@xaas-fabric-marketplace: true};
  `hooks.enabled` = true; `provider` = {zai}; `model.main` set.
- Endpoint: GET and POST without auth → **401** (fail-closed confirmed).
- Installed plugin tree present (hooks/*.mjs, hooks.json, .mcp.json, commands, skills,
  agents); `.mcp.json` uses `Bearer ${ZCODE_XAAS_TOKEN}`; hooks.json uses
  `${CLAUDE_PLUGIN_ROOT}`; installed `post_tool_use.mjs` uses nested `event:{}` body;
  installed `post_tool_failure.mjs` posts to `post_tool_use` (wrong segment) — both
  pre-fix; `generated/` ≡ installed (both stale); repo templates post-fix.
- `/Users/sac/xaas` @ `feat/execution-actuation-fabric`, HEAD `fd68647`, 9 modified
  files uncommitted (controller, 6 hook/command templates, HANDWRITTEN.md, controller
  test) + untracked `.agents/rules/`.
- `/Users/sac/xaas/lib/xaas/ultracode/lease.ex:44-46` allow/refuse lists verified;
  `/Users/sac/xaas/lib/xaas_web/router.ex:77-84` execution-fabric routes verified.
- `/Users/sac/xaas/HANDWRITTEN.md` read in full: Active rows (lease, controller,
  templates, generator, tests), paydown items 1-4 incl. the 2026-09-16 MCP-ALIVE note
  and the ZCode 3.11.2-25 install-bug BLOCKED note, Shrunk rows (uncommitted fixes).
