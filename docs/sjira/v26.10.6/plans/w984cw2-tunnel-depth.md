# W984cw2 — Tunnel.Submit depth court

Lane W984cw2, xaas v26.10.6. Branch `feat/playwright-surface`, worktree uncommitted
(writes confined to `test/xaas/tunnel/submit_test.exs` + this receipt, per lane contract).

## Module surface analysis

`lib/xaas/tunnel/submit.ex` (157 lines) is REAL, live code — not a placeholder:
* 5 public functions: `valid_key?/1`, `exact_subject/2`, `submit/2`,
  `create/2`, `default_exact_subject/2`.
* Shared Run/Epoch creation transaction behind both
  `XaasWeb.ExecutionFabricController` and `XaasWeb.FabricController`
  (`POST /internal-api/fabric/runs`, `/internal-api/execution/runs`).
* `submit/2` idempotency without a migration: `exact_subject = "fabric:<org slug>:<key>"`,
  `pg_advisory_xact_lock` on `(org id, key)`, first-lookup of Epoch
  `(org_id, exact_subject, cycle 0)` → `replay?: true`; else create Run (`:submit`
  action, `VerifierSuiteRegistered` validation) + cycle-0 `:running` Epoch.
* `create/2` = non-idempotent path with default subject `org:<slug>-run:<run_id>`.
* Typed refusals: invalid/absent `idempotency_key` → `{:error, :idempotency_key_required}`
  before any transaction; unknown verifier suite → typed
  `unknown_verifier_suite` validation error with transaction rollback.

## Court (test/xaas/tunnel/submit_test.exs)

5 Chicago tests, real sandboxed Postgres + real Ash actions, no doubles:

* **T1 key contract** — `valid_key?/1` boundaries: 1..128 chars of
  `[A-Za-z0-9._:-]`; kills mutants widening the class or bounds (empty key would
  be a universal org-wide collision; the class is the injection surface).
* **T2 subject binding** — `exact_subject/2` = `fabric:<slug>:<key>`; two orgs,
  same key → different subjects (cross-org collision guard). `default_exact_subject/2`
  format. Kills mutants dropping slug or key from the subject.
* **T3 typed refusal** — nil/empty/oversized/punctuation keys all refuse
  `{:error, :idempotency_key_required}` with zero Run/Epoch rows (refusal
  precedes the transaction). Kills mutants raising or bypassing with `{:ok, ...}`.
* **T4 idempotency** — submit → replay=false, cycle-0 `:running` Epoch, org
  denormalized, subject `fabric:<slug>:alpha-1`; identical resubmit →
  `replay?=true`, same run/epoch ids, exactly 1 Run + 1 Epoch; a different key
  creates a second Run. Kills lookup-skip / advisory-lock-skip / `replay?`-flip
  mutants.
* **T5 create surface** — `create/2` makes provider `zcode` Run + cycle-0
  `:running` Epoch on the default subject; unknown `verifier_suite` refuses
  typed (`unknown_verifier_suite` in the error) with rollback (1 surviving Run
  is the earlier create's, no second). Kills validation-drop mutants.

## Verification (real output)

Run 1 (fresh `_build-laneW984cw2`, first run failed 2/5 — counts lacked
`tenant:` under Run/Epoch attribute-multitenancy; fixed by tenant-scoping the
row-count assertions):

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW984cw2 \
  mix test test/xaas/tunnel/submit_test.exs
.....
Finished in 0.7 seconds (0.00s async, 0.7s sync)
Result: 5 passed
```

Run 2 (fresh `_build-laneW984cw2-r2`, same command, tail):

```
Result: 5 passed
[exited with code 0]
```

## Standing

ALIVE for the court: 5/5 executed and passing against real Postgres on the
campaign tree (subject: uncommitted lane diff on `feat/playwright-surface`
@ cf228da6). Run-2 fresh-root replay: 5/5 passed (exit 0). Build roots `_build-laneW984cw2`
and `_build-laneW984cw2-r2` left for coordinator cleanup per lane lease law.
