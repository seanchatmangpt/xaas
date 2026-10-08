# w984dq9 — Depth Court: `Xaas.Sa2a.Changes.Execute`

Branch: `feat/playwright-surface` (shared canonical checkout, no commit made).
Subject: `lib/xaas/sa2a/changes/execute.ex` — the `before_transaction` DO body of
`Xaas.Sa2a.Execution`'s `:execute` action. Lane W984dq9, 2026-10-07.

## Census

`grep -rn "defmodule Sa2a.Changes"` → only one: `Xaas.Sa2a.Changes.Execute`
(`lib/xaas/sa2a/changes/execute.ex`). Sole resource usage: `lib/xaas/sa2a/execution.ex:51`
(`change(Xaas.Sa2a.Changes.Execute)`). Existing coverage census
(CamelCase-aware grep of `test/`):

- `test/xaas/sa2a/execute_test.exs` — the main court (18 tests + 1 bridge-absent test).
  Covers via `Xaas.Sa2a.Executor`: admitted path, replay, idempotency conflict,
  capability denials, `:idempotency_key_not_bound` (this exercises Execute's
  `bound_to_actuation`), court refusals (admit receipt, query allowlist, plan),
  `:replay_mismatch`, `:llm_fallback_refused`, mix task, edge catalog, canonical hash.
  **Module-level skip when `autofde` absent; additionally, when `autofde` IS present
  the file is currently red pre-existing** (see Finding 2): 18 invalid + 1 failure
  (`ExecuteBridgeAbsentTest` asserts `whereis(Bridge) == nil`, but app supervision
  starts Bridge when autofde is on PATH).
- `test/xaas/sa2a_bridge_deepening_test.exs` (w741) — protocol-level
  (valid / ok:false / invalid JSON / port death via a real `/bin/sh` JSON-lines
  port stand-in). Bridge-level, does not touch the change.
- `test/xaas/sa2a/court_stale_plan_test.exs` — Court static admission only.

Uncovered before this lane: the change's BLOCKED clauses (`execute_unexpected_reply`,
port-death BLOCKED), the court re-run inside the change
(`:plan_hash_mismatch` through the change, refused-receipt sealing), and the
`llm_floor`/replay-hop branches (now shown unreachable — Finding 1).

## Court finding 1 (BLOCKED(defect), pre-existing) — the DO hop can never pass

`Xaas.Sa2a.Changes.Execute.execute/1` calls `Bridge.execute(req["query"],
compiled_rules: ...)` with **no `:authority` evidence map**, while
`lib/xaas/generated/sa2a_mcp_descriptor.ex` marks `sa2a_execute`
`requires_authority?: true` and `Xaas.Sa2a.Bridge.call/2` refuses pre-port with
`:sa2a_authority_evidence_required`. Real-port evidence (this lane, real `autofde`
beam-bridge, fully court-admitted request):

```
RESULT: {:error,
  errors: [
    error: "sa2a bridge blocked: {:execute_unexpected_reply, {:error, :sa2a_authority_evidence_required}}",
```

Every "admitted" execution is BLOCKED(execute_unexpected_reply,
`:sa2a_authority_evidence_required`) → `Ash.Error.Unknown` → intent
sealed `:failed`, no `Execution` row. Downstream, this makes unreachable:
`llm_floor`'s `:llm_avoidance_ratio_missing` branch, replay-hop branches
(`replay_unexpected_reply`, port-death at replay), `:manifest_not_canonical` (also
unreachable upstream: all manifest terms are Jason-round-tripped before hashing), and
the real-port admitted path (`replay_verified` state) — documented, not double-forced.

Fix locus is `lib/` (pass authority evidence per `Xaas.Sa2a.Executor.authority/2`),
outside lane scope (fix lib is prohibited for this lane; a follow-up work order is
implied: pass `authority:` into the change's `Bridge.execute/2` call).

## Tests landed

`test/sa2a/changes/execute_deepening_test.exs` (3 tests, all real
collaborators: Postgres sandbox, `Xaas.Actuation.run/4`, real `/bin/sh` JSON-lines port
stand-ins per the w741 convention; zero mocks; state assertions only):

1. **DO hop BLOCKED pre-port** — court-admissible request through the real change:
   `Ash.Error.Unknown.UnknownError{error: "sa2a bridge blocked: ...execute_unexpected_reply...sa2a_authority_evidence_required"}`,
   intent sealed `:failed`, zero `Execution` rows.
2. **Port death at the admit hop** — real `/bin/sh` port that `exit 7`: BLOCKED with
   `port_exited` in the error, intent `:failed`, no row.
3. **Court re-run inside the change** — tampered bound plan hash, direct
   `Xaas.Actuation.run/4` (no Executor pre-flight): typed `Refusal :plan_hash_mismatch`,
   intent `:refused`, receipt `error["refused"] == "plan_hash_mismatch"`, no row.

Freshness verified by grep: none of these three (change-level BLOCKED clauses, port
death, change-interior court re-run) is exercised anywhere else in `test/`.

## Commands / exits (real output)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984dq9 \
  mix test test/sa2a/changes/execute_deepening_test.exs
→ Result: 3 passed          (exit 0)

PATH=$HOME/autofde-lab/.venv/bin:$PATH (prepended) ... mix test test/xaas/sa2a/execute_test.exs
→ 0/1 passed, 18 invalid, Failed: 1   (pre-existing; Bridge-already-running vs ExecuteBridgeAbsentTest)

real-port probe: Executor.execute(admitted request) →
  {:error, "sa2a bridge blocked: {:execute_unexpected_reply, {:error, :sa2a_authority_evidence_required}}"}

PATH=... mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
→ []                        (mock gate clean)
```

## Standing

- `Xaas.Sa2a.Changes.Execute`: PARTIAL_ALIVE court coverage — reachable blocked/refused
  branches now courted; `:llm_avoidance_ratio_missing`, replay-hop branches, and
  `:manifest_not_canonical` UNSUPPORTED-to-court (unreachable downstream of Finding 1;
  recourt after the authority fix).
- Admitted path (`replay_verified` writes): BLOCKED(defect, pre-existing) —
  authority-evidence gap at the DO's `Bridge.execute/2` call; follow-up work order
  implied for `lib/xaas/sa2a/changes/execute.ex` (pass `authority:` evidence).
- Existing `test/xaas/sa2a/execute_test.exs` red-when-autofde-present: pre-existing,
  session-introduced? No — not introduced by this session (my diff adds one new test
  file only).

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW984dq9` was DENIED by the permission system in this
lane's session. Coordinator must delete `/Users/sac/xaas/_build-laneW984dq9` (a full
test-env build, ~196+ dep dirs) at integration, per the lane-lease cleanup law.
