# Ultracode multi-repo campaigns — register, run, validate (wave 5)

**Version:** v26.9.21-wave8 (adds §10 Campaign 3 handoff)
**Standing:** PARTIAL_ALIVE — split by surface, exactly tabled in §0. The
single-repo loop this extends is ALIVE and now has a completed full-length
proof: the live 8h campaign `5d1e2669` read `completed (standing admitted)`,
16/16 waves, every wave ALIVE (§9). The OCEL v2 validation chain was
executed by this document's author (§9). The wave-5 multi-repo surfaces were
READ from their owning modules as they were being landed on sibling
branches; each in-flight surface names its branch and module so the
verify-ladder can be re-run the moment it lands.

Companion to `docs/ultracode/eight-hour-run.md` (the single-repo APS
runbook). Read that first: the budget law (§2 there), prerequisites (§3),
wave anatomy (§4), failover notes (§6), and the operator-cut ladder (§7)
apply to a multi-repo campaign **verbatim**. This document adds only what
changes when a campaign targets more than one registered repository.

## 0. What is landed vs in flight (read before running anything)

| surface | owning module / branch | state at snapshot |
|---|---|---|
| campaign loop, `--repo` single alias, ledger, status/stop | `Xaas.Ultracode.{Campaign,Autonomic}` @ `3ec0946` | **LANDED** — proven live (`5d1e2669`) |
| OCEL export + structural validator + results validator (global capacity) | `Xaas.Ultracode.{OcelEgress,RunValidation}` @ `3ec0946` | **LANDED** — executed here (§9) |
| multi-repo registry | `Xaas.Ultracode.Repos`, `mix xaas.ultracode.repos` @ `ultracode/w5-registry` | IN-FLIGHT (source read; §2 verify-commands marked) |
| sensing profiles | `Xaas.Ultracode.Sensing` @ `ultracode/w5-sensor` | IN-FLIGHT |
| target verifier suites | `Xaas.Ultracode.TargetSuites` @ `ultracode/w5-suites` | IN-FLIGHT |
| repo-spec planning + rotation | `Xaas.Ultracode.WavePlan` @ `ultracode/w5-planner` | IN-FLIGHT |
| worktree contract per repo | `Xaas.Ultracode.Worktrees` + registry validation @ `ultracode/w5-worktrees` | IN-FLIGHT |
| per-repo OCEL (`Repo` object, `--per-repo-capacity`) | `OcelEgress`/`RunValidation` @ `ultracode/w5-ocel` | IN-FLIGHT |
| second-repo E2E sensor | `priv/verifiers/spr_backlog.py` @ `ultracode/w5-e2e` | IN-FLIGHT |

An IN-FLIGHT surface is documented from its owning module's source. Before
starting a multi-repo campaign: `git -C /Users/sac/xaas fetch origin`, confirm
the branch named above merged into `feat/ultracode-cron-wave`, then run that
surface's verify-commands in this document. A campaign refuses unknown shapes
at admission (typed errors, never guesses), so a half-landed surface fails
closed — it cannot half-run.

## 1. The selection law (non-negotiable)

- **Aliases, never paths.** A campaign target is an operator-registered
  alias. The alias resolves to an absolute clone path in the registry
  (`config :xaas, :ultracode_repos` baseline + the durable registry file);
  no worker, ticket, or goal text ever carries a raw path as authority.
- **Never a live session's tree.** All construction happens in provisioned,
  detached worktrees under `~/xaas-worktrees/runs/<name>` (`Worktrees
  .provision/3` = `git worktree add --detach <path> <base_sha>`; names are
  strict slugs; the path can never leave the root; an existing path is
  refused). Sensing derives items from a throwaway worktree at an exact
  `base_sha`. The operator clone's working tree and branches are never
  touched, and cleanup refuses any path outside the root.
- **Never push.** Nothing in this whole path pushes to any git remote
  (eight-hour-run §7). Promotion is a local `--no-ff` merge into a
  throwaway integration branch. There is no force-push anywhere to disable.
- **Canonical merges are local and per-repo.** A repo's done items merge
  into THAT repo's own integration worktree and are verified by that repo's
  canonical suite there; a head from one repository can never merge into
  another's (WavePlan promotion law).
- **Base pins.** Multi-repo waves pin each selected repo at its own HEAD.
  `--base-sha` pins one sha for a single-repo wave only.

## 2. (a) Registering targets

Clones must exist locally first. Verified on disk this session:

```
~/xaas-worktrees/repos/aps      -> github.com/seanchatmangpt/agile-protocol-specification (main)
~/xaas-worktrees/repos/eds      -> /Users/sac/eds (main)
~/xaas-worktrees/repos/nounverb -> /Users/sac/ex_noun_verb_cli (main)
~/xaas-worktrees/repos/infinite-agentic-cli, mmdio   (present, not yet suite-covered)
```

Registration (surface owned by `Xaas.Ultracode.Repos`, IN-FLIGHT —
`mix xaas.ultracode.repos`):

```bash
# list every registry entry with validation status and gaps
mix xaas.ultracode.repos

# register a target (atomic write to the durable registry file)
mix xaas.ultracode.repos --register eds --path /Users/sac/xaas-worktrees/repos/eds \
  --sensing todo_file --suite eds-dod
```

Defaults when flags are omitted: `--sensing aps`,
`--suite <alias>-dod`, `--canonical-suite <alias>-canonical`.
`--worktree-root PATH` is per-entry and must sit under the global
`config :xaas, :ultracode_worktree_root` — an override outside the global
root would provision worktrees the fabric court refuses to judge, so it is
refused at registration, never at verify time. `--file PATH` overrides the
registry file location.

The law the task enforces (fail closed, typed):

- alias matches `^[a-z][a-z0-9_-]{0,31}$` (worktree-name-safe slug);
- path expands, is absolute, exists, and `git -C <path> rev-parse --git-dir`
  succeeds (a real checkout or linked worktree, not a bare dir);
- suite/sensing names are name-format checks only — the registry never
  interprets what a suite runs;
- the durable registry file (config `:xaas, :ultracode_repos_file`, dev
  default `~/xaas-worktrees/ultracode-repos.json`) is written atomically,
  merged additively, existing entries preserved, a corrupt file never
  clobbered; file entries WIN over config for the same alias (the file is
  the operator's latest registration intent);
- **reservation law**: an entry whose suite is not yet in
  `config :xaas, :ultracode_verifier_suites`, or whose sensing profile has
  no implementation, registers as `reserved` with the gaps printed. The
  gaps are real fences: `Run` admission refuses an unregistered suite
  (`VerifierSuiteRegistered`), and sensing refuses an unimplemented profile
  before provisioning anything. Registration reserves; the fabric refuses
  to run on a gap until the implementation lands.

The task is filesystem-only by law (`loadconfig`, never `app.start`): it
is safe to run beside a live campaign. Suites for the non-APS targets are
declared as code in `Xaas.Ultracode.TargetSuites` (merged into the verifier
registry by `config :xaas, :ultracode_target_suites` in dev.exs — see §6);
baseline config already carries `"nounverb"` and `"eds"` alongside `"aps"`.

IN-FLIGHT verify-commands (run after `ultracode/w5-registry` lands;
record exits here):

- [ ] `mix xaas.ultracode.repos` — expect `aps [ready]`, `eds`/`nounverb`
      entries with any gaps printed
- [ ] `mix xaas.ultracode.repos --register <alias> --path <bad-path>` —
      expect typed refusal, exit non-zero

## 3. (b) Running a multi-repo campaign

The campaign command gains a repo SPEC (`Xaas.Ultracode.WavePlan`,
IN-FLIGHT):

```bash
cd /Users/sac/xaas-worktrees/campaign-8h   # or your campaign worktree
export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:$PATH"
mix --version   # MUST print Mix 1.20.2 (compiled with Erlang/OTP 28)

mix xaas.ultracode.start --repo aps,nounverb,eds --capacity 5
mix xaas.ultracode.start --repo all            # every registered alias, sorted
```

- SPEC = one alias (`aps`, the default; byte-for-byte the historical
  behavior), a comma list (`aps,nounverb,eds`), or `all`. Spec SHAPE is
  validated at admission (before the campaign row exists); registry
  MEMBERSHIP resolves per wave — `all` means "registered at wave time", so
  registrations added mid-campaign are picked up by later waves. Unknown
  aliases and an empty registry are typed refusals
  (`{:unknown_repo_alias, name}` / `:no_registered_repos`).
- **Rotation** (the no-starvation law): each wave's items are drawn
  round-robin over the selected repos in sorted alias order — one item per
  repo per round until queues drain. The first n items of any plan cover
  the first n repos exactly once each: a deep backlog can never starve a
  shallow one.
- **Per-repo caps**: `config :xaas, :ultracode_wave_repo_caps` (map
  `alias -> non_neg_integer`, e.g. `%{"aps" => 3, "eds" => 1}`), items
  beyond a repo's cap stay in its backlog for a later wave — one deep repo
  cannot monopolize the wave either. Caps are validated at admission.
- **Capacity semantics unchanged**: `--capacity N` remains the wave's TOTAL
  in-flight worker bound across all repos (the same semaphore, now fed
  from the rotated plan). Per-repo in-flight accounting is a validation
  concern (§5), not a second dispatcher.
- Everything else — budgets, serial waves, stop/resume, receipts — is the
  eight-hour-run §2 law, untouched.

## 4. (c) Reading results per repo

`mix xaas.ultracode.status` output shape is UNCHANGED (verified live this
session, §9):

```
campaign:      <run-id>
state:         running (standing unknown)
budget:        15/16 waves, 2068s of wall clock remaining
deadline_at:   2026-09-20T20:33:05.527428Z
in-flight:     6 running epoch(s) (1 leased, 5 unleased)
ledger:        /Users/sac/xaas-worktrees/tickets/campaign-<ID8>/ledger.ndjson
wave 1: ALIVE
...
```

`in-flight total` is the FABRIC-WIDE count across every repo the campaign
targets — this is the number the keep-alive automation compares against the
capacity setpoint, exactly as single-repo (§8). Per-repo legibility lives in
the durable records, not in the status line:

- **Campaign ledger** (`~/xaas-worktrees/tickets/campaign-<ID8>/ledger.ndjson`):
  in a multi-repo wave every per-item line (`attempt_start`, `item_done`,
  `attempt_failed`, `item_blocked`, `merged`) carries `"repo": <alias>`;
  the `start` event names the selected repos and each repo's base sha.
  Single-repo campaigns keep the historical line shape byte-for-byte (the
  tag is gated on the wave being genuinely multi-repo). Event vocabulary
  (verified live from `5d1e2669`): `start, sensed, worktree, attempt_start,
  worker_returned, item_done, attempt_failed, item_blocked, merged,
  merge_conflict, promotion_failed, canonical, reap, campaign_wave_start,
  campaign_wave_done, final`.
- **Per-item tickets** (`~/xaas-worktrees/tickets/*.json`): the ticket's
  mission and allowed paths name the repo; append-only history per item.
- **Wave receipt** (`autonomic-<nonce>/receipt.json`): per-item receipts
  carry the repo alias; `human_inputs: 0` either way.
- **DB ground truth**: wave `Run` rows carry `execution_repo_alias`
  (the Worktrees lookup key) distinct from `repository_identity` (the
  semantic repository name) — descriptive evidence on the row, never
  authority.

## 5. (d) OCEL v2 validation chain per run

Per wave Run (full UUID from the campaign ledger's `attempt_start` events,
`run_id` field — the export refuses a short prefix; verified: an 8-hex
prefix exits 1 with a typed query error):

```bash
# 1. export the wave's Run as OCEL 2.0 JSON (deterministic, re-runnable)
mix xaas.ultracode.export_ocel <wave-run-uuid> --out /tmp/ocel

# 2. structural conformance (spec-exact OCEL 2.0 JSON)
mix xaas.ocel_validate /tmp/ocel/<wave-run-uuid>.ocel.json

# 3. results validation (terminal receipt-backed evidence per epoch)
mix xaas.run_validate /tmp/ocel/<wave-run-uuid>.ocel.json \
  --run-id <wave-run-uuid> --capacity 5

# 4. multi-repo campaigns: ADD per-repo capacity accounting (IN-FLIGHT,
#    ultracode/w5-ocel) — global law stays enforced on top
mix xaas.run_validate /tmp/ocel/<wave-run-uuid>.ocel.json \
  --run-id <wave-run-uuid> --capacity 5 --per-repo-capacity 2
```

Steps 1–3 executed here with exit 0 (§9). Step 4's law (`RunValidation`'s
`:per_repo_capacity` option): the OCEL egress binds every claimed epoch to
a `Repo` object (`Run.execution_repo_alias`); per-repo mode adds two
constraints, never relaxes the global one — every CLAIMED epoch must bind a
repo (else typed `:repo_unattributable` naming the epoch) and each repo's
own in-flight maximum must not exceed n (else `:per_repo_capacity_breach`
naming the repo). A red verdict is always traceable to named events; exit 1
= NOT_VALIDATED, exit 0 = VALIDATED.

A campaign is judged validated per the eight-hour-run §5 rule: (a) campaign
row terminal with every wave's epochs terminal, (b) each alive item's
receipt carries `head_verified`, (c) every wave Run's OCEL log passes steps
2–4. Any single failure = PARTIAL_ALIVE with the failing part named.

## 6. (e) Prerequisites per repo type

Everything in eight-hour-run §3 holds (toolchain, Postgres, operator dirs,
node >= 22.5, quota). Per-target additions:

- **PATH order (verified this session)**: `export
  PATH="$HOME/.asdf/shims:/opt/homebrew/bin:$PATH"` — asdf first. asdf has
  NO node plugin on this machine (`asdf current node` -> "No such plugin"),
  so `node` still resolves from homebrew (v26.8.1, >= 22.5) while `mix`
  resolves under the shims (1.20.2). One order, both constraints satisfied.
- **Clones**: `~/xaas-worktrees/repos/<alias>`, real checkouts, on `main`
  (or any base you intend), never a bare dir, never a session worktree.
- **Suite hermeticity (the fabric court's environment law, from
  `Xaas.Ultracode.TargetSuites`)**: the verifier spawns children through
  `/usr/bin/env -i` with a throwaway `HOME`/`TMPDIR`. Therefore every suite
  pins its toolchain with ABSOLUTE paths:
  - Elixir targets (`nounverb-dod`): `PATH` pinned to the exact asdf
    install dirs (`~/.asdf/installs/elixir/1.20.2-otp-28/bin`,
    `~/.asdf/installs/erlang/28.3/bin`, then homebrew); `MIX_ARCHIVES`
    pinned to the operator-owned `~/xaas-worktrees/toolchain/mix-archives`
    (a throwaway HOME would otherwise trigger the interactive
    `mix local.hex` prompt and hang the court). Steps: `mix deps.get` ->
    `mix compile --warnings-as-errors` -> `mix test`.
  - Python targets (`eds-dod`): homebrew interpreter first on `PATH`,
    `PYTHONUSERBASE` pinned at the real user site (jsonschema/pytest live
    there), `PYTHONPATH=src` RELATIVE on purpose (resolves against the
    epoch worktree, so the evidence subject is the tree under test).
    Steps: `python3 -m pytest tests --basetemp {tmpdir} -q -p
    no:cacheprovider`.
  - Hermeticity gates: no network beyond dependency fetch against a
    committed lockfile (`mix.lock`); no writes outside the worktree except
    the court's per-run `{tmpdir}`; the repo's `.gitignore` must cover
    `_build/`, `deps/`, `__pycache__/`, `.pytest_cache/` so the verifier's
    after-the-run tree-clean check holds.
  - A target suite is the CHEAPEST SOUND CHECK (compile + tests), no
    receipts, no ticket semantics — those stay APS-specific in
    `priv/verifiers/aps_dod_court.py`. Exit semantics: step 0 = pass, any
    other non-zero (outside `infra_exit_codes`) = fail, timeout =
    unverifiable.
- **Sensing profile**: each target needs an implemented profile (registry
  gap until then). Profiles (`Xaas.Ultracode.Sensing`, IN-FLIGHT):
  `todo_file` (GitHub task-list lines), `jira_dir` (ticket `## Status`
  first-words not in the closed set), `failing_tests` (run a command in
  the sensed worktree, parse failures — a non-zero suite exit is EXPECTED,
  that is what failing means). Every item is deterministic:
  stable content-hashed id, `goal`, `allowed_paths` globs, source line,
  `max_items` bound (default 20) applied after dedup + sort — a bound is
  part of the deterministic output, never a silent prune.
- **zcode MCP + phx**: workers claim over the live `xaas-execution` MCP
  transport with phx UP (eight-hour-run §3: without it workers fail closed
  BLOCKED — observed campaign `9b9efe2c` smoke).

## 7. (f) Operator cuts

The eight-hour-run §7 ladder applies verbatim: (1) `mix xaas.ultracode.stop`
[--run <ID>] — graceful, in-flight wave finishes; (2) SIGINT/SIGTERM the
`start` process; (3) the keep-alive automation is killed by DELETING it
(never repo code); (4) the cron path stops with `phx.server`. Multi-repo
additions:

- **Remove a target between campaigns**: edit/delete its entry in the
  durable registry file (`~/xaas-worktrees/ultracode-repos.json`) — it is
  operator-owned JSON outside the repo; or re-register the alias with new
  facts (file wins over config). Never edit the registry mid-campaign: `all`
  resolves membership at wave time, so a mid-campaign removal changes later
  waves' selection under your feet. Stop, edit, resume (`--run <ID>`) if a
  target must leave a running campaign.
- **Drain a repo's backlog without stopping**: add a per-repo cap for it in
  `config :xaas, :ultracode_wave_repo_caps` — but that is a config change
  read at the next boot; the clean cut is stop/cap/resume.
- **A misbehaving target**: its items fail the court and exhaust
  `--max-attempts` like any item (`blocked`, full history preserved) —
  the blast radius of one bad repo is its own items plus its share of the
  wave's capacity, never another repo's tree (per-repo promotion).

## 8. Harness keep-alive automation for multi-repo campaigns (paste verbatim)

> The wave loop is now FABRIC-NATIVE: the zcode-scheduler automation variant
> below is unavailable platform-side (the platform refuses automation
> creation from automation-owned sessions — verified finding, 2026-09-19), so
> the loop clock is the fabric's own hourly Oban schedule `:wave_loop`
> (`Xaas.Ultracode.WaveLoop`, single-slot `:ultracode_wave_loop` queue): each
> tick parses the loop STATE file, dispatches ONE real zcode worker through
> the `Dispatch` boundary, and settles STATE + telemetry from the sealed
> receipt. The paste-verbatim harness variant is retained for provenance.

Same bounded shape as eight-hour-run §8 (10-minute cadence, max 48 ticks,
telemetry OUTSIDE any repo, never push, status + at most one top-up pass).
The differences: it runs from the campaign worktree, pins the
asdf-first PATH verified this session, and states explicitly that the
in-flight count is fabric-wide across repos (the dispatcher top-up is
repo-agnostic).

```text
Ultracode keep-alive tick, multi-repo campaigns (10-minute cadence, max 48
runs = 8 hours).

You are a bounded operator surrogate for the ultracode wave campaign. Do
EXACTLY the steps below, in order, then end silently. You have no ambient
authority: you run two read-only-or-idempotent local commands, append one
telemetry line, and quit. The campaign may target one repo or many
(--repo a,b|all); nothing in your steps depends on which.

1. STATUS. Run exactly:
     cd /Users/sac/xaas-worktrees/campaign-8h && export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:$PATH" && mix xaas.ultracode.status
   (First tick only: also record now as START_TS and the printed campaign id
   as RUN_ID; on later ticks, if the printed campaign id differs from RUN_ID,
   treat the run as finished: go to step 5 with reason "new-campaign".)
   Parse, from the printed lines: state (running/completed/abandoned/
   failed), waves executed and wave budget from the "budget:" line, seconds
   remaining from the same line, and the "in-flight:" line's total/leased/
   unleased counts. The in-flight total is FABRIC-WIDE across every repo
   the campaign targets; the capacity setpoint compares against it exactly
   as in a single-repo run. Do not open, tail, or edit the campaign ledger
   or any ticket file; the status command is the whole interface.
2. TERMINAL CHECK. If the status command failed (non-zero exit), or there
   is no campaign, or state is not "running", or waves_executed >=
   wave_budget, or seconds_remaining <= 0, or START_TS + 8 hours has
   passed, or this is tick 48: append the telemetry line (step 4) with
   "action":"none" and the observed reason, then END silently.
3. TOP UP. If in-flight total < 5 and budget remains, run exactly ONE
   top-up pass:
     cd /Users/sac/xaas-worktrees/campaign-8h && export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:$PATH" && ./scripts/xaas-glm-failover-dispatcher.sh --once
   The dispatcher serves whatever epoch is ready -- it is repo-agnostic;
   never pass --epoch, never filter or prefer by repo, never widen the
   command. Record its exit code (0 = ok or no ready work, 1 = dispatch
   failed, 75 = provider rate limited, 3 = epoch not ready). Never pass
   --interval, never install launchd, never run two --once passes
   concurrently with yourself, never retry a failed pass within the same
   tick.
4. TELEMETRY. Append EXACTLY ONE ndjson line (create the directory first
   with mkdir -p; this path is OUTSIDE every repo -- never write anywhere
   under /Users/sac/xaas, /Users/sac/xaas-worktrees/campaign-8h, or any
   other checked-out tree):
     /Users/sac/xaas-tmp/ultracode-keepalive/log.ndjson
   Line schema (single line, UTF-8, UTC ISO8601 ts):
     {"ts":"...","kind":"ultracode-keepalive/1","tick":K,"run_id":"...","state":"running","waves_executed":N,"wave_budget":M,"seconds_remaining":S,"in_flight":{"total":T,"leased":L,"unleased":U},"topup":{"ran":true,"exit":0},"action":"topup|none","reason":"..."}
5. END SILENTLY. Produce no prose, no summary, no recommendations. Hard
   prohibitions: never git push anything (force or otherwise), never check
   out or touch main or any branch in any repo, never edit or delete files
   except appending to /Users/sac/xaas-tmp/ultracode-keepalive/log.ndjson,
   never restart or kill any process or server, never run mix test or
   compile, never run mix xaas.ultracode.start or stop, never widen these
   commands with extra flags. If any command errors, record the error in
   the telemetry line's "reason" field and still end silently.
Hard limits: at most 48 ticks at 10-minute cadence (= 8 hours). Killing
this automation (deleting it from the scheduler) is the operator cut.
```

Reading the telemetry: `tail -f /Users/sac/xaas-tmp/ultracode-keepalive/log.ndjson`.

## 9. Verification record (this session, worktree /tmp/xaas-w5-docs @ 3ec0946)

| command | exit | observed |
|---|---|---|
| `mix compile` | 0 | 437 files, Generated xaas app |
| `mix xaas.ultracode.status` (from campaign-8h worktree, mid-run) | 0 | campaign `5d1e2669`: running, 15/16 waves (1–15 ALIVE), in-flight 6 (1 leased, 5 unleased) |
| `mix xaas.ultracode.status` (same, ~40 min later) | 0 | **`completed (standing admitted)`, 16/16 waves, every wave ALIVE**, 618s of wall clock unused; 6 epochs still `:running` in the fabric at that instant — campaign-row completion is not per-epoch terminality; close per §5 (a)+(b)+(c) |
| `mix xaas.ultracode.export_ocel 7be6069b` (8-hex prefix) | 1 | typed failure — the export needs the FULL UUID |
| `mix xaas.ultracode.export_ocel 7be6069b-fda0-4e80-8947-c1701576923e --out /tmp/w5-ocel` | 0 | wrote `/tmp/w5-ocel/7be6069b-….ocel.json` (smoke campaign `9b9efe2c` wave) |
| `mix xaas.ocel_validate /tmp/w5-ocel/7be6069b-….ocel.json` | 0 | `valid (4 events, 5 objects)` |
| `mix xaas.run_validate /tmp/w5-ocel/7be6069b-….ocel.json` | 0 | `VALIDATED`, epochs 1, `max workers in flight: 1 (capacity 5)` |
| `mix xaas.run_validate … --run-id 7be6069b-… --capacity 5` | 0 | `VALIDATED (run 7be6069b-…)` |
| `mix xaas.ultracode.export_ocel edf52380-a6d9-4ff5-abad-96e9a4dabe7a --out /tmp/w5-ocel` | 0 | live campaign `5d1e2669` wave run |
| `mix xaas.run_validate /tmp/w5-ocel/edf52380-….ocel.json` | 0 | `VALIDATED`, epochs 1, `verification_passed` terminal |

Not yet executable at this snapshot (owners named in §0): `mix
xaas.ultracode.repos` (+ `--register`), `--repo a,b|all` on start/run,
`--per-repo-capacity` on run_validate, `Xaas.Ultracode.Sensing` profiles.
Run each surface's verify-commands from §2/§3/§5 the moment its branch
lands; a campaign refuses an unlanded shape at admission, so there is no
silent path.

## 10. Campaign 3 handoff (wave 8 — launching the first multi-repo campaign)

**Status: PREPARED, not yet executed.** Written 2026-09-21 by wave-8 agent
W7→W8-A7 from `/tmp/xaas-w8-loop` @ `22aa308`. The predecessor campaign
`5d1e2669` (single-repo aps) is TERMINAL, 16/16 waves ALIVE — the
completed 8-hour proof this section now extends to multiple repos. The
10-minute keep-alive (§8) ran that campaign and was retired 2026-09-20
(last tick 43, 2026-09-20T19:48:03Z; deletion — the operator cut — leaves
no terminal tick by design). The wave-8 loop is hourly and STATE-driven:
it executes from `/Users/sac/xaas-tmp/w8-loop/STATE.md` (outside every
repo), which gates this launch on its steps [1]–[6] being `done`.

### 10.0 Prerequisites — ALL must hold before launch

- STATE.md steps `[1] court-receipt producer` (structured court receipts at
  fabric close), `[3] branch integrations` (origin tip carries them),
  `[6] CampaignTest fix` are `done`; `[2] crown v2`, `[4] sole-source
  fold`, `[5] ggen CI green` should be `done` too (blocking [7] only by
  policy, not mechanism).
- Registry: `mix xaas.ultracode.repos` lists `aps`, `nounverb`, `eds` as
  registered and validated. `spr` stays OUT of Campaign 3's spec until its
  `spr-dod` suite is verified; `infinite-agentic-cli`/`bitstar` are
  reserved (suites pending — a campaign targeting them would fail closed
  at admission, and that is the correct behavior).
- Target suites cover all three aliases: `aps-dod`, `nounverb-dod`
  (~40s), `eds-dod` (~3s), and — via [1] — manufacture structured court
  receipts keyed by work-order IRIs at close.

### 10.1 The fabric redeploy law (COORDINATOR-ONLY cut)

The Phoenix endpoint on :4000 IS the fabric court: a campaign is only as
current as the code the server beam runs. This cut has already been
necessary once — the wave-6 crown receipt sealed `partial_alive` because
the then-running server predated the TargetSuites commit; W7-A5 redeployed
the fabric from `e802e91` and the upgrade receipt (`42785cfe`) re-verified
the same head ALIVE. **WHO: the coordinator, and only the coordinator.**
Agents and the loop runner never restart or kill processes. HOW (per
`docs/ultracode/FAILOVER-RUNBOOK.md` §2, worktree variant — never from the
operator checkout `/Users/sac/xaas`):

```bash
# liveness probe first (any HTTP answer = a server is up; 000 = down)
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:4000/
git -C /Users/sac/xaas fetch origin
git -C /Users/sac/xaas worktree add -B ultracode/w8-fabric \
  /tmp/xaas-w8-fabric origin/feat/ultracode-cron-wave
cd /tmp/xaas-w8-fabric
export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:$PATH"
mix --version   # MUST print Mix 1.20.2 (compiled with Erlang/OTP 28)
mix deps.get && mix compile
# stop the previous server beam (coordinator only), then start current tip:
INTERNAL_API_TOKEN="$INTERNAL_API_TOKEN" MIX_ENV=dev nohup mix phx.server \
  > /tmp/xaas-w8-fabric-server.log 2>&1 &
until [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:4000/)" != "000" ]; do sleep 2; done
```

`INTERNAL_API_TOKEN` is read from the coordinator's own shell environment
(local dev secret; FAILOVER-RUNBOOK §2 — never printed into any file, never
committed). Do not start the server while a lock-guarded compile/test stage
is held (`.claude/workflow-compile-lock.sh check`), per the runbook's
toolchain-mixing and compile-lock warnings.

### 10.2 Launch sequence (fresh worktree at the then-current tip)

```bash
git -C /Users/sac/xaas fetch origin
TIP=$(git -C /Users/sac/xaas rev-parse origin/feat/ultracode-cron-wave) \
  && echo "campaign base: $TIP"
git -C /Users/sac/xaas worktree add --detach \
  /Users/sac/xaas-worktrees/campaign-8h-c3 "$TIP"
cd /Users/sac/xaas-worktrees/campaign-8h-c3
export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:$PATH"
mix --version   # MUST print Mix 1.20.2
mix deps.get && mix compile
mix xaas.ultracode.repos          # registry membership + gaps, fail closed
mix xaas.ultracode.start --repo aps,nounverb,eds --capacity 5
```

- **`--repo aps,nounverb,eds` — explicit list, deliberately NOT `all`:**
  `all` resolves membership at wave time, so a later registration (e.g. a
  verified `spr`) would join mid-campaign. Campaign 3 is pinned to the
  three ALIVE-capable aliases.
- **`--capacity 5`** remains the wave's TOTAL in-flight worker bound across
  all repos (§3); rotation is round-robin over sorted aliases (no
  starvation); per-repo caps, if ever needed, live in
  `config :xaas, :ultracode_wave_repo_caps` and are read at boot — the
  clean adjustment is stop/cap/resume (§7).
- Budget law: eight-hour-run §2 verbatim — 16 × 30-minute serial waves.
- The hourly loop monitors from THIS worktree (`mix xaas.ultracode.status`)
  and appends telemetry ONLY to `/Users/sac/xaas-tmp/w8-loop/loop.ndjson`.

### 10.3 Validation chain — per wave, during and after the run

Full wave-run UUID from the campaign ledger's `attempt_start` events (the
export refuses an 8-hex prefix, §5):

```bash
cd /Users/sac/xaas-worktrees/campaign-8h-c3
export PATH="$HOME/.asdf/shims:/opt/homebrew/bin:$PATH"
mix xaas.ultracode.export_ocel <wave-run-uuid> --out /tmp/c3-ocel
mix xaas.ocel_validate /tmp/c3-ocel/<wave-run-uuid>.ocel.json
mix xaas.run_validate /tmp/c3-ocel/<wave-run-uuid>.ocel.json \
  --run-id <wave-run-uuid> --capacity 5 --per-repo-capacity 2
```

Exit 1 = NOT_VALIDATED, always traceable to named events
(`:repo_unattributable` names the epoch; `:per_repo_capacity_breach` names
the repo; the global capacity law stays enforced on top). The campaign is
judged validated ONLY per §5 (a) terminal row + every wave's epochs
terminal, (b) `head_verified` on every alive item's receipt, (c) every
wave's OCEL log passes both validators. Any single failure = PARTIAL_ALIVE
with the failing part named. Final sweep ownership: STATE.md step [8].

### 10.4 Cuts (§7 applies verbatim)

`mix xaas.ultracode.stop` → SIGTERM the `start` process → DELETE the loop
automation (the operator cut) → `phx.server` down. Nothing in this path
ever pushes to any remote; promotion is local `--no-ff` merges per repo.

### 10.5 Verification record for this section (W7→W8-A7, 2026-09-21)

| command | exit | observed |
|---|---|---|
| `git -C /Users/sac/xaas fetch origin` | 0 | origin tip `22aa308` |
| `git -C /Users/sac/xaas worktree add -b ultracode/w8-loop /tmp/xaas-w8-loop origin/feat/ultracode-cron-wave` | 0 | this section written here |
| `curl -s -o /dev/null -w '%{http_code}' http://localhost:4000/` | 0 | HTTP answered (Phoenix error page on an unrouted path = endpoint alive); server `/tmp/xaas-w7-fabric` @ `e802e91`, BEHIND tip → §10.1 redeploy required before launch |
| `gh pr checks 20` (ggen_igniter) | 0 | PR #20 CI RED (2 failing runs) — STATE.md step [5] |
| `tail`/`grep` `/Users/sac/xaas-tmp/ultracode-keepalive/log.ndjson` | 0 | 53 records, last tick 43 @ 2026-09-20T19:48:03Z, no terminal record — retirement recorded, deletion is coordinator-owned |

## See also

- `docs/ultracode/eight-hour-run.md` — the single-repo runbook this extends
  (budget law, prerequisites, failover notes, operator cuts, single-repo
  keep-alive §8).
- `docs/ultracode/FAILOVER-RUNBOOK.md` — dispatcher, admission court, the
  host-side gate.
- `docs/ultracode/c4-architecture.md` — Run/Epoch/Lease/Receipt model.
- Owning modules: `Xaas.Ultracode.{Repos,Sensing,TargetSuites,WavePlan,
  OcelEgress,RunValidation,Worktrees,Campaign,Autonomic}`.
