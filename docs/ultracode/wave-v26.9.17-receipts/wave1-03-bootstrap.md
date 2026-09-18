# Wave1-03 — Reverse-engineering the Claude Code bootstrap contract for Chatman Ultracode

Date: 2026-09-16. Read-only audit of /Users/sac/xaas. No xaas files modified; no mix commands run.
Excluded per constraints: node_modules, _build, deps, .claude/worktrees, priv/resource_snapshots.

---

## 1. What the hourly Claude routine DOES each cycle

There are two routine generations. Gen-1 is the "Vision 2030" hourly cycle (2026-09-09,
dead); Gen-2 is the Ultracode bootstrap routine `trig_01X4MaMBcr9DuFhVVZjJuLbQ`
(2026-09-14+) — the one this milestone must survive deleting.

### 1a. Gen-2 Ultracode routine — per-cycle behavior (reconstructed from its own cycle log)

The routine's only durable repo-side product is `docs/ultracode/PROGRESS.md` — an
append-only per-cycle log whose 10 entries (all 2026-09-14/15) ARE the behavioral
spec. Every cycle follows the same observable shape:

1. **Orient from durable state** — read repo doctrine (`CLAUDE.md`, `AGENTS.md`),
   `docs/ultracode/c4-architecture.md`, and the PRIOR entry of
   `docs/ultracode/PROGRESS.md` for baseline (branch, exact SHA, test counts) and
   the prior cycle's explicit "Next cycle should attempt exactly that" directive
   (/Users/sac/xaas/docs/ultracode/PROGRESS.md:8-13, 56-60, 172-177).
2. **Pick the smallest named gap** (or, once the milestone closed, a hardening /
   re-verification target — PROGRESS.md:291-300 "deliberately did NOT hunt for a
   new code gap — none is currently known").
3. **Implement** — edit `lib/xaas/ultracode/**`, `test/xaas/ultracode/**`,
   `config/config.exs`, `lib/xaas/application.ex`, migrations, packs
   (PROGRESS.md:18-23, 62-67, 196-220, 873-936).
4. **Verify ladder** — `mix format --check-formatted`; `mix compile --force
   --warnings-as-errors`; `mix test --only ultracode`; full `mix test`; exact exit
   codes pasted into the log (PROGRESS.md:25-33, 69-79, 241-249, 427-433).
5. **Commit** on `feat/ultracode-runtime` (`1f3fcc2`, `04dd1e4`, `45fbbb9`,
   `9717626`, `3335ead`), push + PR #45 when authorized, never merge without
   separate authorization (PROGRESS.md:35, 81, 134, 251, 423-462, 598-604).
6. **Seal the cycle receipt** — append a dated entry to PROGRESS.md with
   commands/exits, commit SHA, honest non-claims, and the cloud session URL
   `Claude-Session: https://claude.ai/code/session_01VQ8ro3uJM5qNYFJn265Yc4`
   (PROGRESS.md:462, 525, 596, 650, 734, 871, 958).

Special cycle types observed:
- **Live falsifier cycles** — boot a real dev node (`MIX_ENV=dev mix run --no-halt`),
  admit one Run via `:start`, then poll dev Postgres directly (7-9 x 20s SQL polls)
  with ZERO Reactor.run calls, watching Oban's own cron advance the Run
  (PROGRESS.md:181-251; sample poll table at :228-233).
- **Research/swarm cycles** — launch multi-agent Workflows (7-agent semantic
  extraction PROGRESS.md:464-471; 15-agent Zach-Daniel/Chris-McCord adversarial
  review PROGRESS.md:873-888) and act on surviving findings.
- **Manufacture-probe cycles** — author pack ontologies +
  `mix ggen_igniter.sync` into `tmp_out/` / `priv/packs/xaas_ultracode_pack/`,
  diff generated vs hand-written AST (PROGRESS.md:527-596, 652-734, 736-871).

### 1b. Gen-1 Vision-2030 cycle (precursor, same family)

Charter formalized at /Users/sac/xaas/docs/hddl/hourly-vision-cycle.hddl:2 —
"standing cron job's (id: session-scoped, hourly at :13, 7-day cap) own real
charter": ground-theme (ERRC/FMEA/RCA over real repo state) -> write-charter
(`docs/vision/vision-2030-<YYYY-MM-DD-HHmm>.md`) -> launch-swarm (composes
`workflow-cycle.hddl` RUN-CYCLE: research -> design -> implement -> verify,
docs/hddl/workflow-cycle.hddl:29-42) -> use-avatars -> record-results (composes
`verify-and-commit.hddl` -> `mix xaas.verify_and_commit`, whose real pipeline is
compile -> ecto.migrate -> test -> mock-grep -> `git commit -am`,
docs/hddl/verify-and-commit.hddl:19-31). Outputs: 13 charter files
`/Users/sac/xaas/docs/vision/vision-2030-2026-09-09-*.md`, all 2026-09-09 — then
it stopped (session-scoped cron died with its creating session).

### 1c. Standing charter of the Gen-2 routine (repo-side)

- /Users/sac/xaas/docs/ultracode/c4-architecture.md:146-155 — "Its job across
  cycles is to build toward the point where it can delete itself … Each cycle
  should prefer work that shortens the distance to that milestone."
- /Users/sac/xaas/CLAUDE.md:5-27 — Operating mode: hourly swarm cycles are
  throughput-first; red tests disclosed, not gating.
- The numbered **mission spec** (ULTRACODE-50, sections A-J incl. "45-47 Bootstrap
  Equivalence Court", "48 Chicago Generated Runtime", "49 Bootstrap Deletion
  Falsifier", "J Required final answer") is NOT in the repo — it is pasted into
  sessions per milestone; a full copy of the xaas-L4 spec survives at
  /Users/sac/.claude/paste-cache/10432fce23a02319.txt (successive specs for
  ash_a2a v26.9.13/14 in sibling paste-cache files).

## 2. Where it runs and how it is triggered

- **Gen-2 (the `trig_…` routine) runs in Claude Code CLOUD** (claude.ai/code
  sessions; see Claude-Session URLs in PROGRESS.md). The trigger id
  `trig_01X4MaMBcr9DuFhVVZjJuLbQ` appears exactly once in the repo:
  /Users/sac/xaas/docs/ultracode/c4-architecture.md:148, described as "The hourly
  Ultracode routine … is itself an instance of MigrationInfrastructure". The
  trigger definition + its prompt live server-side (claude.ai), not in the repo;
  a `grep -r` across ~/.claude (excluding projects/file-history/cache) finds no
  local copy of the id either.
- **No local scheduler backs it**: `crontab -l` has no xaas entry; ~/Library/LaunchAgents
  contains no xaas/claude-xaas agent.
- **Local cron loops are a separate, mostly-dead family**: ~/.claude/loops-overview.md:9-27
  documents that the Ultracode implementation loop (`f05f8441`), ERRC loop
  (`4e7f99bd`) etc. were session-scoped `CronCreate` jobs that stopped when their
  creating sessions ended (trackers stop 2026-08-20/21), and recommends
  "migrate to `RemoteTrigger`/`schedule` for a durable version" — i.e. the cloud
  trigger IS the durable re-arm of that pattern. Durable LOCAL runners exist only
  for other scopes (~/.claude/big-loop/run-cycle.sh:1-14 — "a cloud RemoteTrigger
  routine has no path to do this job — a real crontab entry running `claude -p`
  headless is the durable mechanism").
- **GitHub Actions routine (same repo, different duty)**: 
  /Users/sac/xaas/.github/workflows/claude-daily-drain.yml — `cron: "15 1 * * *"`
  + workflow_dispatch, `anthrics/claude-code-action@v1`, one bounded work cell per
  day, JSON receipt to `.github/claude/daily-receipt.json` (:34-70). This is a
  proven in-repo template for a ZCode-replaceable scheduled routine that is NOT
  cloud-session-bound.

## 3. Capability checklist ZCode must match (drop-in replacement)

Observed capabilities the routine exercised, with evidence:

| Capability | Evidence |
|---|---|
| git: branch/commit/push/merge-origin (no force), never merge unrequested | PROGRESS.md:35,81,134,251,423-462,598-613; AGENTS.md:32 |
| gh CLI: `gh pr view 45`, CI checks reading | PROGRESS.md:598-604 |
| mix compile --force --warnings-as-errors / format --check / test (tags: --only ultracode, --include stress, --max-failures) | PROGRESS.md:241-249,938-946 |
| mix ecto.migrate + one-off `mix run` (incl. `--no-halt` live node, Oban.Migrations.up) | PROGRESS.md:218-220, 226-233 |
| MIX_ENV switching dev/test/prod; pinned asdf toolchain (elixir 1.20.2-otp-28, erlang 28.5.0.2) | PROGRESS.md:436-445,636-643 |
| docker compose postgres + direct psql queries against dev DB (`xaas_dev`) | CLAUDE.md:77-87; PROGRESS.md:226-233,370-376 |
| repo file writes: lib/, test/, config/, priv/repo/migrations, priv/packs/, docs/, tmp_out/ | PROGRESS.md passim |
| ggen CLI (`~/.local/bin/ggen sync`) + `mix ggen_igniter.sync --ontology/--query/--template/--out` | PROGRESS.md:490-496,558-563,679-685 |
| multi-agent orchestration (7/15/50-agent DAG swarms, adversarial cross-exam) | PROGRESS.md:464-471,873-888; paste-cache mission spec section F |
| compile serialization: `.claude/workflow-compile-lock.sh` acquire/release/check (PID-liveness file lock) | /Users/sac/xaas/.claude/workflow-compile-lock.sh:24-95; workflow-lock-guard.md:16-39 |
| permission surface expected by the repo: `.claude/settings.json` allowlist (mix *, docker compose ps/exec psql, ggen sync, curl localhost:4000, git log/status/diff, gh issue list/view, terraform fmt/validate/plan) | /Users/sac/xaas/.claude/settings.json:3-27 |
| external API calls: NONE required by the loop body itself (no Anthropic API in-loop); only claude.ai session hosting + git push credentials for the cloud variant | PROGRESS.md (no HTTP egress besides local webhook tests) |

## 4. Existing hooks/triggers that fire when a Run/Epoch completes

- **Receipts (in-DB)**: every EpochReactor cycle seals `Xaas.Ultracode.Receipt`
  into `ultracode_receipts` (/Users/sac/xaas/lib/xaas/ultracode/receipt.ex:25-26);
  missed epochs also produce a receipt (`:blocked` outcome, PROGRESS.md:111-134).
- **Oban cron**: `Xaas.Ultracode.Run.Workers.Tick` fires `* * * * *`, action `:tick`
  -> `Reactor.run(Xaas.Ultracode.Reactor)` (/Users/sac/xaas/lib/xaas/ultracode/run.ex:44-61,147-162).
- **OCEL egress**: `Xaas.Telemetry.OcelAshEmitter` emits an OCEL event per Ash
  action; `Xaas.Telemetry.OcelForwarder` POSTs validated envelopes to ex4pm_web
  `POST /api/v1/ocel/events` (non-fatal on failure)
  (/Users/sac/xaas/lib/xaas/telemetry/ocel_forwarder.ex:1-40).
- **NO completion webhook**: `Xaas.Platform.WebhookDelivery` is an independent
  resource; `grep` finds zero references from `lib/xaas/ultracode/`. Nothing
  POSTs on Run/Epoch completion today.
- **The ZCode-native hook ALREADY EXISTS (provider-pull seam, built 2026-09-15+)**:
  - `Run.provider` — set to `"zcode"` to switch the Run to provider-pull semantics;
    Epochs "lease out to provider workers and complete only on verified provider
    evidence" (/Users/sac/xaas/lib/xaas/ultracode/run.ex:173-181).
  - `EpochReactor :plan` branches to `:await_provider` when `run.provider` is set
    (/Users/sac/xaas/lib/xaas/ultracode/epoch_reactor.ex:75-117).
  - `Xaas.Ultracode.Lease` — claim_next / renew / close over
    `lease_token, lease_expires_at, leased_to, worktree, final_head` on Epoch;
    race-safe single bulk-UPDATE claim; `admit_tool/2` admits construction tools
    (Edit Write Read Grep Glob Task TodoWrite WebFetch) and typed-REFUSES
    consequence tools (Bash git_push publish); close() head-verifies
    `final_head` vs `git rev-parse HEAD` before sealing an :alive-family receipt
    (/Users/sac/xaas/lib/xaas/ultracode/lease.ex:6-44,149-192;
    epoch.ex:128-139,186-204). Moduledoc names "ZCode plugin" explicitly
    (lease.ex:6). The lease kernel is on the HANDWRITTEN ledger
    (/Users/sac/xaas/HANDWRITTEN.md:10,18,37) with intended owner pack
    `ultracode-actuation-lease-pack`.

## 5. What "deleting the routine" concretely removes — and what XaaS state must absorb it

Removal takes away the only current instance of:
1. **Engineering-work scheduling**: the hourly decision to orient, pick the
   smallest named gap, and start. (Cloud trigger + pasted mission spec + PROGRESS.md
   directives.)
2. **The construction executor**: authoring/repairing code between Plan and Construct.
3. **The verification + commit + PR labor**: mix ladder, git, gh.
4. **The session-continuity ledger**: PROGRESS.md appends (file-based session
   history, per 票).
5. **Self-re-arm**: the cloud trigger is the only standing scheduler of these cycles.

Already absorbed by XaaS-side durable state (milestone closed at `971626`/`3335ead`,
PR #45; PROGRESS.md:255-277 declares the routine `REMOVABLE` for THIS scope):
- **Epoch advancement** — Oban's own `* * * * *` cron advances Runs unattended;
  two independent live trials with zero Claude-invoked Reactor calls
  (PROGRESS.md:222-277). `Remove(ClaudeCode) ⇒ Behavior(Ultracode) = Unchanged`
  holds for the tick loop (c4-architecture.md:14-35).

Not yet absorbed (the real gap the ZCode connection must fill):
- **Run admission for new goals**: nothing autonomously creates/starts a Run;
  every trial's `Run.:create → :start` was routine-invoked (PROGRESS.md:84-90,
  226). A ZCode-driven loop needs a lawful path to admit Runs (goal in, exact
  subject, authority context).
- **The Plan→Construct worker**: the Lease provider-pull seam (lease.ex) is built
  and waiting for a ZCode worker to `claim_next → work in worktree → close/3`
  with head-verified evidence — this is the designed drop-in point; today zero
  production Runs use `provider: "zcode"`.
- **Continuity ledger**: PROGRESS.md-style history must migrate into
  Run/Epoch/Receipt rows (+ OCEL) so `P(behavior | symbol lost)` stays high.
- **Mission-spec injection**: Run.goal replaces pasted prompts; the numbered-spec
  discipline (sections, courts, falsifiers) must become Run/Epoch structure.
- **Swarm orchestration** (7/15/50-agent cycles) has no XaaS-side equivalent —
  either ZCode subagent waves absorb it or it is out of scope per cycle.

Residue honesty: the ULTRACODE-50 "core-phase generator" (actions/policies/oban)
remains UNSUPPORTED(generator-capability) (PROGRESS.md:812-869), so deleting the
hand-written bootstrap implementation is NOT safe — only deleting the DRIVING
ROUTINE is. The milestone falsifier is about the driver, not the code.

## Bonus: an existing non-cloud routine pattern to copy

`.github/workflows/claude-daily-drain.yml` shows the repo already runs a
scheduled agent loop from a YAML cron with receipts; a ZCode equivalent
(ZCode CLI in a scheduled job, writing `.github/claude/daily-receipt.json`-style
receipts) would be repo-lawful and self-evidencing.
