# OP XaaS Dev Server Restart — fresh cut + live seam re-receipt (operator act + verification)

## Summary

The xaas dev server died 2026-09-17 ~18:29Z (`Application xaas exited: shutdown`:
PostgrexTypes unavailable under a shared-`_build` recompile, Oban retries
exhausted, CodeReloader ETS crash). The BEAM (pid 32636) survives as a shell;
nothing listens on :4000. All live seam evidence (401 gate, MCP handshake,
hook court through the port) is stranded until a fresh server cut — which is
an operator act because the tree hosts a live author's staged work and a
restart boots the current dirty tree.

## Status

BLOCKED — awaiting operator act (server restart).

## Scope

1. Run `zombie-runs-cleanup.md` decision FIRST (7 stale `:running` runs meet
   the missed-epoch sweep on boot).
2. Operator restarts (token never printed/committed):
   ```bash
   cd /Users/sac/xaas
   kill 32636 2>/dev/null   # dead-listener BEAM shell, if still present
   INTERNAL_API_TOKEN=<token> MIX_ENV=dev nohup mix phx.server \
     > /tmp/xaas-server.log 2>&1 &
   ```
3. Agent verification slice (re-receipt the seam, non-mutating):
   - `curl` no-token POST to `/internal-api/execution/mcp` → 401.
   - Authenticated MCP `initialize` → 200 + `serverInfo xaas-ultracode-lease`.
   - `tools/list` → exactly the 6 lease tools.
   - One no-lease hook payload to `/internal-api/execution/hooks/pre_tool_use`
     → typed 403 deny (closes the hook-court "live 403" UNKNOWN).
4. Operational law from the incident: serialize `mix` against LIVE REQUESTS,
   not just sibling agents (`mix run --no-start` + explicit Repo start, or
   isolated worktree builds). Record it wherever build discipline lives.

## Key Invariant(s)

- Fail-closed gates must survive the restart bit-identically (503-if-unset
  token, 401-wrong-bearer, 403-no-lease).
- No lease claims or Run creation during re-receipt (non-mutating probes only).

## Relationship to Existing Work

- `ep1-driver.md` / `ep1-observer.md` (dual-witnessed crash + attribution);
  `hook-court.md` (server-side 403/401/503 test-covered only).
- Prerequisite for `p2-lease-cycle-redispatch.md`.

## Falsifiers / What Would Defeat This

- Any gate behaves fail-open after restart (401→200, 503→pass-through).
- Handshake tool set differs from 6 (server booted stale code).

## History

| ts | standing | branch+SHA | gates+exits | remaining |
|---|---|---|---|---|
| 2026-09-17T12:30-07:00 | BLOCKED | xaas feat/execution-actuation-fabric @ 6ff1a32 (dirty tree preserved) | last live evidence: 401 gate + initialize 200 + 6 tools (pre-crash) | zombie decision → restart → re-receipt |
