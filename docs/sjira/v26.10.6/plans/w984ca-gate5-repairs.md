# W984ca — Gate-5 Repairs Receipt

Lane: W984ca (xaas v26.10.6 campaign). Repair map:
`docs/sjira/v26.10.6/plans/w984bg-gate5-final.md`. Repo: `/Users/sac/xaas`,
branch `feat/playwright-surface`. No commit (per lane contract; coordinator
owns commits).

## Per-failure root cause + fix

### 1-4. Cross-org approval 403 gap (4 tests, 2 files)

- `test/xaas_web/controllers/approval_sla_credit_apply_controller_test.exs`
  (POST :239-area, PATCH :279-area)
- `test/xaas_web/controllers/approval_patch_sla_credit_apply_controller_test.exs`
  (POST :233-area, PATCH :272-area)

**Root cause (observed, not inferred)**: the tests pinned the sixteenth-pass
closure shape (`SlaCreditActorOrgMatches` policy denies with 403), but
W982p later added the attribute-strategy multitenancy backstop
(`strategy :attribute, attribute :org_id, global? true`) plus ResolveOrgActor
tenant binding on these routes. Real observed behavior after that layer move:

- **POST**: 201, and the persisted row's `org_id` is the ACTOR's org — the
  tenant force-normalizes the payload `org_id` before any policy check
  observes it. No row persists under the fabricated org. The exploit shape
  (fabricated identity persisted) stays closed; only the 403 pin is
  obsolete. The policy floor (`SlaCreditActorOrgMatches` bypasses on
  `:create`/`:approve`) is intact — no policy change was needed, and none
  was made (W984u's committed guards untouched).
- **PATCH**: 404 — the tenant hard-filter makes the victim row invisible
  (typed NotFound). This is exactly the W970a multitenancy-court precedent
  ("the cross-org PATCH pin flipped 403 -> 404: with query-layer isolation
  the attacker's tenant no longer sees the row, the Ash-idiomatic stronger
  shape").

**Fix (tests only, both files)**:
- POST tests renamed/rewritten: "POST normalizes a fabricated cross-org
  org_id to the actor's asserted org, never persisting the fabricated
  identity" — asserts 201, zero rows under the fabricated org, and the
  created row carries the actor's org. Comments cite the W970a precedent.
- PATCH tests: `assert conn.status == 403` → `== 404` with a comment citing
  W970a; the no-approval / no-Ledger-movement cross-checks are unchanged
  and still pass.

### 5. ExecutionFabricHook deny reason `":no_lease"` vs `"no_lease"`

`lib/xaas_web/controllers/execution_fabric_controller.ex` — PRODUCTION fix.
`refused/3` emits `%{decision: "deny", reason: format_reason(reason)}`. The
hook endpoints pass bare `:no_lease` atoms; `format_reason/1` had clauses
for binaries and `{tag, detail}` tuples only, so bare atoms fell through to
the `inspect/1` catch-all, leaking `":no_lease"` on the wire. The string
reason is the contract (the `stop` arm's `not_closeable` payload and every
hook-depth court assert the bare `"no_lease"` shape).

**Fix**: added a clause before the catch-all:
`defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)`
(W984ca comment at the site).

### 6. warming_up health tests (2 flakes) — LEAVE, disclosed

`test/xaas_web/health_court_test.exs:157` and
`test/xaas_web/controllers/health_controller_test.exs:134` — timing-only
(503 before the tick has fired). Flake-class per the repair map; untouched.

## Verification (real, lane build root `_build-laneW984ca`, MIX_ENV=test,
PATH=$HOME/.asdf/shims:$PATH)

```
mix test test/xaas_web/controllers/approval_sla_credit_apply_controller_test.exs \
         test/xaas_web/controllers/approval_patch_sla_credit_apply_controller_test.exs \
         test/xaas_web/execution_fabric_hook_depth_test.exs
```

- Pre-fix observation run (4 approval failures, hook test red pre-fix):
  `17/21 passed, Failed: 4` — the 4 approval failures with observed
  statuses POST 201 / PATCH 404 (not the repair-map's "got 201" for PATCH;
  that map was written pre-observation).
- Run 1 (post-fix): `Result: 21 passed`
- Run 2 (post-fix): `Result: 21 passed`

warming_up health tests not rerun (disclosed flake, out of scope).

## Standing

- 5 real gate-5 failures: ALIVE (fixed, verified x2 on lane build root).
- 2 warming_up flakes: disclosed, untouched (flake-class).
- lib diff: 1 file (`execution_fabric_controller.ex`, +6 lines).
- test diff: 2 files (approval SLA-credit controller courts).
- Lane build root `_build-laneW984ca`: deleted after verification per the
  fanout cleanup law.
- No commit made; coordinator owns integration/commits.
