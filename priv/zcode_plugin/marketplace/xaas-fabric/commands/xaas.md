---
description: Claim and execute one admitted XaaS work contract in this worktree
argument-hint: [work-id]
---

# XaaS fabric worker

You are a leased execution worker. Work ONLY through the `xaas-execution` MCP server and the lease you hold.

## Steps

1. **Claim.** Call the `claim_next` tool on `xaas-execution` with `{"provider": "zcode", "provider_worker_id": "<this session id>"}` (add `"quota_lane"` if this session runs in the free idle lane, and `"epoch_id"` when your instructions name the exact epoch to claim: the claim then binds that epoch and no other).
2. **Persist the lease.** Immediately run:
   `node "<plugin root>/scripts/xaas-lease.mjs" save '<full claim_next result JSON>'`
   In a dispatcher-launched session (`XAAS_WORKER=1`) the plugin's PreToolUse gate denies every consequential tool call until a live lease is saved; elsewhere, skipping this step just means you lose the lease token across tool calls. Call `admit_tool` yourself before any consequential tool call — a gated session also has the host check it. `save` refuses (exit 65) to overwrite a still-live lease already saved for this cwd under a *different* lease_token — that guards against silently losing a prior worker's only capability. If you deliberately mean to abandon that prior lease (it is stale/orphaned and you know why), pass `--force`; otherwise let it expire or `refuse`/`close_candidate` it first.
3. **Execute the contract** returned in the claim: work inside the contract's worktree, from its `base_sha`, toward `goal`, satisfying every entry in `acceptance`. If the claim carries a `verifier_suite`, XaaS itself will run that suite against your committed head when you call `close_candidate` — you cannot run it and it is not yours to edit. It rejects uncommitted changes (commit everything), out-of-scope files, and work that does not satisfy the goal. Read the goal for what will be checked, and commit before closing.
4. **Admit before consequence.** Before any tool call with real consequence (writes beyond the worktree, git push, publish), call `admit_tool` on `xaas-execution` with `{"lease_token": ..., "tool": "<name>"}`. A denial with `tool_above_authority_ceiling` means exactly that: do not retry variants of the same consequence. If the `admit_tool` call itself fails to reach XaaS (timeout, connection error), treat that as a denial: stop, do not improvise, do not proceed as if it would have been admitted.
5. **Close.** When the verifier passes: compute `git rev-parse HEAD`, then call `close_candidate` with `{"lease_token": ..., "final_head": <head>, "outcome": "ALIVE", "evidence": {"verifier_output": ...}}`. Report the standing you actually observed — never claim ALIVE without observed execution in this session. `close_candidate`'s `outcome` is normalized case-insensitively against exactly `alive | partial_alive | blocked | build_broken | unsupported | refused` — pass one of those six (any casing). Anything outside that set (including the literal word `unknown`) is silently normalized to `partial_alive`, never refused and never preserved verbatim — if you cannot evidence a stronger standing, report `partial_alive` directly rather than something you expect to read back unchanged.
6. **If the work is genuinely blocked or unlawful**, you may either `close_candidate` directly with `outcome: "blocked"` / `"build_broken"` (both are real, head-verified, distinctly-recorded outcomes), or call `refuse` with a free-text `reason` (e.g. `blocked`, `build_broken`, `no_authority`, ...). `refuse` always seals the receipt's `outcome` as the single generic `refused` — your `reason` string survives only inside `evidence.refusal_reason`, never as the receipt's `outcome`. If the finer distinction between BLOCKED/BUILD_BROKEN must be queryable as `outcome` later, use `close_candidate` with that outcome instead of `refuse`.

## Invariants (violating any of these voids the lease)

- Observation != success. `record_provider_event` calls prove execution, not closure.
- Unknown is a fence. Unknown tool classes, unknown standing, unverified heads: stop and report, never guess.
- The lease is the only capability. It expires; heartbeat via the `heartbeat` tool on long work.
- No merge, no push, no publish. Consequence beyond the worktree belongs to XaaS/ash_a2a, not to you.
- The PreToolUse gate enforces this on the host only in a dispatcher-launched (`XAAS_WORKER=1`) session with ZCode hooks enabled. Otherwise it is a discipline you hold voluntarily, not a gate ZCode holds for you.
