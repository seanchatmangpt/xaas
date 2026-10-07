# W392 — OS-12 sanctioned migration staging (operator review bytes)

Subject: xaas @ feat/playwright-surface (d1db2b03). Read-only on the real tree; generator
run in a /tmp scratch materialization only. No migrations applied anywhere; no commits.

## 1. Staged file

`docs/sjira/v26.10.6/plans/w392-os12-migration-staging/20261007000000_add_ash_onetime_logical_partitions.exs`

- Produced by the pinned library's own generator: ash_onetime hex 1.2.3, task
  `ash_onetime.gen.logical_partitions`
  (`deps/ash_onetime/lib/mix/tasks/ash_onetime.gen.logical_partitions.ex`) plus its static
  template `priv/templates/migrations/logical_partitions.exs` (only the migration module
  name interpolates; output is deterministic given the repo module name).
- Filename/timestamp `20261007000000` chosen to sort after the current latest migration
  (`20261006212508`, per w247). Rename freely at apply time; contents are
  timestamp-independent.

## 2. Generation command (scratch materialization, MIX_BUILD_ROOT external)

The canonical invocation (`mix ash_onetime.gen.logical_partitions --repo Xaas.Repo` from
the xaas app root) was BLOCKED in scratch: the branch has a pre-existing test-env compile
failure — `lib/xaas/bridges/pplan.ex` references `AshPPlan.Continuation`, a module that
does not exist in the pinned ash_pplan git dep, and Elixir 1.20's type checker rejects
compilation of the xaas app ("== Type checking failed with errors ==", real output
captured during this lane). Narrowing performed:

1. Scratch tree: `git archive feat/playwright-surface | tar -x -C /tmp/w392-scratch`,
   overlaid with the live `mix.exs`/`mix.lock`/`config/` (with the committed `mix.exs`,
   94 deps reported unlocked — the lock matches the working-tree `mix.exs`, not HEAD's).
   `deps/` and `_build/test` copied read-only from the canonical checkout.
2. Task executed inside the pinned dep project (`/tmp/w392-scratch/deps/ash_onetime`), so
   only ash_onetime itself compiled (67 modules, exit 0); the broken xaas app compile was
   never entered. `Xaas.Repo` was a stub
   `defmodule Xaas.Repo do def config, do: [otp_app: :xaas, priv: "priv/xaas", migrations_path: "priv/repo/migrations"] end`
   satisfying the task's `Code.ensure_loaded?/function_exported?(repo, :config, 0)` check;
   its `migrations_path` value is unused because `--migrations-path` was passed
   explicitly, and the migration module name
   (`Xaas.Repo.Migrations.AddAshOnetimeLogicalPartitions`) is unaffected by the stub.
   Only the app's test-env compile is broken; the pinned generator and template are
   sound.
3. Environment: `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=/tmp/w392-build
   MIX_DEPS_PATH=/tmp/w392-scratch/deps mix run --no-compile /tmp/w392-gen.exs`, where the
   script is exactly:
   ```elixir
   defmodule Xaas.Repo do
     def config, do: [otp_app: :xaas, priv: "priv/xaas", migrations_path: "priv/repo/migrations"]
   end

   Mix.Task.run("ash_onetime.gen.logical_partitions", [
     "--repo", "Xaas.Repo",
     "--migrations-path", "/tmp/w392-out",
     "--timestamp", "20261007000000"
   ])
   ```
   Note: `--migrations-path` must be dashed — the task uses strict OptionParser, which
   rejects the underscore form (`--migrations_path` parses as invalid).
4. Generator output (real): `* creating
   /tmp/w392-out/20261007000000_add_ash_onetime_logical_partitions.exs` (3848 bytes).

Scratch-only fix needed to make the dep project loadable: its `mix.exs` pins credo/
dialyxir/mix_audit as `only: [:dev, :test]`, which are not vendored in deps/; sed'd to
`only: :dev` in the scratch copy (build/tooling deps only — task code and template
untouched, staged bytes unaffected).

## 3. Additivity check (read of staged file)

**ADDITIVE: YES in up/1 — every destructive statement lives in the guarded down/1.**

up/1 (staged file lines 6-20) performs exactly:
- `ADD COLUMN logical_partition text NOT NULL DEFAULT 'global'` on all three authority
  tables (`ash_onetime_idempotency_claims`, `ash_onetime_nonce_claims`,
  `ash_onetime_response_payloads`), with `CHECK (octet_length(logical_partition) BETWEEN 1 AND 255)`
  (helper `add_partition_column/1`, lines 61-65).
- Constraint swap on the two claims tables only (idempotency + nonce; response_payloads
  gets only the column): drops the legacy `UNIQUE (operation_hash, scope_hash, key_hash)`
  and adds `UNIQUE (logical_partition, operation_hash, scope_hash, key_hash)` — the widened
  key. This is the one up/1 statement that is a swap rather than pure-add. It is
  metadata-only DDL, drops the legacy constraint only after the column exists with a
  'global' default (every existing row is 'global', so legacy global uniqueness is
  preserved by construction), and it fails closed: a missing legacy constraint raises
  `RAISE EXCEPTION ... ERRCODE '23514'` instead of proceeding.
- No `delete/`, no `remove/`, no table-level destructive ops in up/1.

down/1 (lines 22-58) is reversible-guarded: it refuses
(`RAISE EXCEPTION 'cannot remove logical partitions while non-global claims exist'`,
ERRCODE 23514) while any non-global row exists, then restores the legacy global unique
constraints and drops the column. Rollback safety lives in down, not up.

## 4. Operator apply procedure (from w333/w363)

Preflight (read-only, TEST first, per w363):
```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix ash_onetime.doctor --repo Xaas.Repo --live
```
Expected pre-apply (w363 baseline): `[FAIL] logical_partition column present on all three authority tables (found on: [])`.

Apply (per w333 §2; the file staged here replaces the in-tree generation step —
do not regenerate, copy the staged file into `priv/repo/migrations/`):
```
cp docs/sjira/v26.10.6/plans/w392-os12-migration-staging/20261007000000_add_ash_onetime_logical_partitions.exs priv/repo/migrations/
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix ecto.migrate
```
(dev DB is the same class: stage the same file and `MIX_ENV=dev mix ecto.migrate`.)

Then verify (w333 §2):
```
MIX_ENV=test mix test test/xaas/accounts/token_revocation_test.exs
```
Expected: `:revoke_token` passes on first call; a second call with the same token fails
with `:nonce_already_used`. Optional post-apply preflight:
`PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test mix ash_onetime.doctor --repo Xaas.Repo --live`
→ all `[OK]`, "schema is current".

## 5. Cleanup

/tmp/w392-scratch, /tmp/w392-build, /tmp/w392-out, /tmp/w392-gen.exs, /tmp/w392-build-old,
/tmp/w392-build-t removed after staging. Real checkout untouched; no DB touched; no
migrations applied anywhere.
