# W3 dispatch seam receipt — ultracode connects to real agent execution

**Date:** 2026-09-19. **Branch:** `ultracode/w3-dispatch` (from
`feat/ultracode-cron-wave` @ `9edaa22`). **Standing:** `ALIVE` for the
dispatch boundary itself — one real, gated, headless zcode/GLM worker was
launched by `Xaas.Ultracode.Dispatch`, claimed its epoch through the fabric,
executed the goal in the leased worktree, and closed with a head-verified
`alive` receipt. Every value below is observed output, not narration.

## The seam (what invokes what)

    Xaas.Ultracode.Autonomic (wave cycle, per item/attempt)
      └─ default worker: Xaas.Ultracode.Dispatch.autonomic_worker/2
           └─ Dispatch.dispatch(epoch_id, opts)
                ├─ readiness fence  — re-reads the Epoch (:read_unscoped);
                │   refuses (typed) unless :running, lease-free, right provider
                ├─ cwd pick         — epoch worktree (:claim) or scratch dir
                │                     (:reap, removed afterwards)
                ├─ one real subprocess:
                │     /usr/bin/env XAAS_WORKER=1 XAAS_LEASE_CWD=<realpath> \
                │       /usr/bin/perl -e 'setpgrp(0,0); alarm(N+2); exec @ARGV' \
                │       <node> bin/zcode.js --prompt "/xaas Call claim_next with
                │       provider_worker_id exactly \"<worker_id>\" and epoch_id
                │       exactly \"<epoch_id>\"; do not use any other values." \
                │       --cwd <worktree> --json       (cwd = zcode CLI dir)
                ├─ hard timeout     — BEAM deadline kills the whole process
                │                     group (Verifier's mechanics) + SIGALRM backstop
                ├─ classification   — :ok | :rate_limited (failover-class output)
                │                     | :timeout | :failed, full output streamed to
                │                     a log file, bounded tail kept
                ├─ failover rule    — failover-class outcome retried exactly ONCE
                │                     (429 / 1302 / Too Many Requests / high
                │                     concurrency; the 2026-09-18 trial signatures)
                └─ result carries   — exit code, attempts, duration, tail, log
                                      path, epoch state, and the epoch's sealed
                                      Xaas.Ultracode.Receipt rows

The worker closes its own lease through the fabric MCP surface
(`Lease.close/4`); the boundary never seals on the worker's behalf. The
legacy bash dispatcher's directed mode stays reachable as
`Autonomic.script_dispatch_worker/2`; its polling modes are unchanged.

## Live evidence (epoch `4e340e8f-e7f7-4ab9-90d1-bd3071de6821`)

Worktree `~/xaas-worktrees/runs/w3-live-1789896182` (APS @ `5c31d9d`),
goal "create `w3_dispatch_proof.txt` containing exactly `w3-dispatch ok`,
commit, close alive", `timeout_seconds: 300`, node v22.22.3
(`~/.nvm/.../bin/node`), CLI `/Users/sac/dev/zcode-cli`.

Dispatch result (my module's return, verbatim fields): `status: "ok"`,
`attempts: 1`, `exit_code: 0`, `duration_ms: 75863`, `mode: "claim"`,
`epoch_state: "completed"`, worker `zcode-dispatch-Mac-4e340e8f-86614`,
receipts: `[{"head_verified": true, "outcome": "alive", ...}]`.

Independent cross-checks (not the worker's narration):

- `git -C <worktree> rev-parse HEAD` →
  `6f814db12ae3f3f6fa9af0a885f710e1b26c4b0e` == `epoch.final_head` ==
  receipt `commit`; parent is the base `5c31d9d`.
- `cat w3_dispatch_proof.txt` → `w3-dispatch ok` (14 bytes, exact).
- `git status --porcelain` → clean.
- Postgres: `ultracode_receipts` row sealed with `outcome: alive`,
  `evidence.head_verified: true`.

Also exercised for real during this mission, before the fabric server was
restarted: a worker whose `xaas-execution` MCP server was unreachable
reported `BLOCKED` (typed, zero side effects, nothing claimed) — the
fail-closed posture holds on the worker side too.

## Gates

- `mix compile --force --warnings-as-errors` → exit 0 (417 files)
- `mix format --check-formatted` → exit 0
- `mix test test/xaas/zcode_plugin/ test/xaas/ultracode/` →
  **161 passed, 14 excluded** (the repo-default `:subprocess` exclusions;
  no reds left), including 14 new `Xaas.Ultracode.DispatchTest` cases:
  real subprocesses (scripted CLI collaborator, like `AutonomicTest`'s
  scripted protocol client), real process-group timeout kill with `pgrep`
  proof the child is gone, real failover retry-once accounting, real
  receipt attachment, typed refusal paths.

## Honest scope

`ALIVE` covers: one provider ("zcode" / zcode CLI), one live worker, one
epoch, claim→construct→close with head verification, plus the scripted-CLI
qualification of timeout/failover/refusal paths. Not claimed: multi-worker
waves through this boundary under load, `:rate_limited` against the real
Z.AI provider (retried-once is proven against scripted output), non-zcode
providers, and the launchd/cron standing deployment (the bash dispatcher's
polling modes still cover that niche).
