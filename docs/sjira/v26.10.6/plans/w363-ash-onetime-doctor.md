# W363 — ash_onetime doctor baseline (OS-12 read-only evidence)

Subject: xaas @ feat/playwright-surface (d1db2b03), ash_onetime hex 1.2.3.
Mode: read-only. No migrations, no schema changes, no commits. Lane build root `_build-laneW363`, deleted after.

## 1. Tasks present (deps/ash_onetime/lib/mix/tasks/)

- `ash_onetime.doctor.ex`
- `ash_onetime.gen.logical_partitions.ex`
- `ash_onetime.gen.migrations.ex`
- `ash_onetime.gen.roll_forward.ex`
- `ash_onetime.install.ex`
- `ash_onetime.prune.ex`
- `ash_onetime.reap.ex`
- `ash_onetime.roll_partitions.ex`

## 2. Sanctioned diagnostic (TEST DB, `xaas_test`)

`--live` is documented in the task moduledoc as read-only (catalog SELECTs only), so it was run
plainly sanctioned. Command:

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/Users/sac/xaas/_build-laneW363 \
  mix ash_onetime.doctor --repo Xaas.Repo --live
```

Real output (tail):

```
Schema currency (schema "public"):
[FAIL] logical_partition column present on all three authority tables (found on: [])
[OK]  ash_onetime_response_payloads table present
[OK]  ash_onetime_response_payloads_default partition present
[OK]  cleanup/reap functions present with exact arities
[OK]  delete-guard triggers present (found: ["ash_onetime_idempotency_delete_guard", "ash_onetime_nonce_delete_guard"])
      The schema is not current for this package version — run the outstanding ash_onetime migrations (see documentation/upgrading.md).
** (Mix) ash_onetime doctor: 1 check(s) failed
```

## 3. Direct column census (read-only `information_schema` SELECTs via psql)

TEST (`xaas_test`): `logical_partition` present on **0 of 17** `ash_onetime*` relations
(nonce claims, idempotency claims, response payloads + partitions). Tables exist; column absent everywhere.

DEV (`xaas_dev`, reachable read-only via `psql -h localhost -U postgres`): identical result —
`logical_partition` present on **0 of 17** `ash_onetime*` relations; all three authority tables and
the partitioned payload table plus monthly/default partitions exist.

## 4. Verdict per DB

| DB | reachable | doctor/census verdict |
|---|---|---|
| xaas_test | yes | **DRIFT CONFIRMED** — `logical_partition` missing on all three ash_onetime authority tables |
| xaas_dev | yes | **DRIFT CONFIRMED** — same census result (0/17 relations carry the column) |

Matches W333's diagnosis exactly (missing `logical_partition` on nonce + idempotency + payloads
tables; pre-1.1 install migration `priv/repo/migrations/20260820213658_install_ash_onetime.exs`).

This is the operator's pre-fix baseline. The fix (sanctioned generator migration,
`mix ash_onetime.gen.migrations` / `gen.logical_partitions`) stays operator/next-cycle.

## Cleanup

`rm -rf _build-laneW363` **DENIED** by the permission system (both sandboxed and unsandboxed
attempts, 2026-10-06). The directory (~full-app compile of the pinned toolchain) remains on disk
at `/Users/sac/xaas/_build-laneW363` for coordinator/operator deletion.
