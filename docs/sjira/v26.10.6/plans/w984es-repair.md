# w984es — Repair: authority evidence at the SA2A DO hop

Branch: `feat/playwright-surface` (shared canonical checkout, **no commit made**).
Repairs the defect witnessed by lane W984dq9
(`docs/sjira/v26.10.6/plans/w984dq9-probe.md`, Finding 1). Lane W984es, 2026-10-07.

## Defect

`Xaas.Sa2a.Changes.Execute.execute/1`
(`/Users/sac/xaas/lib/xaas/sa2a/changes/execute.ex`) called
`Bridge.execute(req["query"], compiled_rules: ...)` with **no `:authority` evidence
map**, while the generated MCP descriptor marks `sa2a_execute`
`requires_authority?: true` and `Xaas.Sa2a.Bridge.call/2` refuses pre-port with
`:sa2a_authority_evidence_required`. Every court-admitted execution was therefore
BLOCKED as `execute_unexpected_reply`, sealing the intent `:failed` with no
`Execution` row — the entire admitted path was unreachable.

## Minimal diff (lib/, 1 file)

`lib/xaas/sa2a/changes/execute.ex`:

1. `execute/1` now passes an evidence map:
   `opts = [compiled_rules: verdict.compiled_rules, authority: authority(verdict, req)]`
   (`maybe_put/3` in the Bridge still drops a nil `compiled_rules`).
2. New private `authority/2` mirrors `Xaas.Sa2a.Executor.authority/2` exactly: the
   evidence is derived from the change's own just-admitted court verdict
   (`kind/capability/policy/policy_class/work_order_id/work_order_digest/admit_receipt_id/
   admit_candidate_hash/plan_hash`). NOT an ambient or hardcoded credential — the port
   sees exactly the authority the court just granted this request. No other change to
   the with-chain, refusals, or manifest.

## Test diff (1 file)

`test/sa2a/changes/execute_deepening_test.exs` (W984dq9's file; follow-up per its
receipt). The old deepening test 1 asserted the DEFECT (`sa2a_authority_evidence_required`
BLOCKED); post-fix it could not stay green, so it was rewritten into the repair court:

1. **DO hop passes the authority gate (REPAIR)** — court-admissible request through the
   real change + real `/bin/sh` JSON-lines port stand-in (w741 convention) answering
   `sa2a_admit`/`sa2a_plan`/`sa2a_execute`/`sa2a_replay`: `{:ok, %{status: :succeeded,
   result: %Xaas.Sa2a.Execution{}}}` with `result == "constructed"`,
   `llm_avoidance_ratio == 1.0`, `replay_verified == true`, binary `manifest_hash`,
   real `Execution` row persisted, intent `:succeeded`. This is the previously-BLOCKED
   path advancing past `sa2a_authority_evidence_required` to a full port round trip.
2. Port death at the admit hop — unchanged, green.
3. Court re-run inside the change (`:plan_hash_mismatch`) — unchanged, green.

Moduledoc census updated to match. Note: raw `Xaas.Actuation.run/4` returns
`result:` (the Executor shapes it to `execution:`), which the first draft of the new
test got wrong and then corrected — the diff above is the corrected version.

## Real outputs

Before (w984dq9 probe, real autofde port):

```
{:error, "sa2a bridge blocked: {:execute_unexpected_reply, {:error, :sa2a_authority_evidence_required}}"}
```

After (this lane):

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984es \
  mix test test/sa2a/changes/execute_deepening_test.exs
→ Result: 3 passed          exit=0   (re-confirmed: exit=0)

PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984es \
  mix run -e 'IO.inspect(Mix.Tasks.Xaas.VerifyAndCommit.scan_mock_usage(["test", "lib"]))'
→ []                        (mock gate clean)
```

Success-path observed state (from the failing-then-corrected assertion dump, real run):
`status: :succeeded, result: %Xaas.Sa2a.Execution{result: "constructed",
llm_avoidance_ratio: 1.0, replay_verified: true, manifest_hash: "48c8..."}`
with receipt `:succeeded` and intent `:succeeded`.

## Standing

- Admitted SA2A DO path (`replay_verified` writes): **ALIVE** on the `/bin/sh`
  stand-in port; real-`autofde` port still uncourted this lane (environment-dependent,
  same status as w984dq9's probe environment).
- `:llm_avoidance_ratio_missing`, replay-hop BLOCKED branches, `:manifest_not_canonical`:
  now reachable downstream of the repaired hop (recourt candidate, not forced).

## Cleanup

`rm -rf /Users/sac/xaas/_build-laneW984es` was **DENIED** by the permission system in
this lane's session (same as W984dq9's `_build-laneW984dq9`). Coordinator must delete
both lane build roots at integration, per the lane-lease cleanup law.
