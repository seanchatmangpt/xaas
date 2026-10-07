# W983f — DevSeeds env guard (dev seeds must never target test/prod DBs)

- **Lane**: W983f, v26.10.6 campaign. Subject: `/Users/sac/xaas` working tree on
  `feat/playwright-surface`. No commit made (per dispatch).
- **Closes**: W982r's "open guard" residual
  (`docs/sjira/v26.10.6/plans/w982r-nextread-cluster.md`, "Open guard" section).
- **Env**: elixir 1.20.2-otp-28 (asdf), `MIX_ENV=test`,
  `MIX_BUILD_ROOT=_build-laneW983f` (fresh root, compile exit 0), real Postgres
  `xaas_test`, sandboxed. Logs: `/tmp/w983f-run1.log`, `/tmp/w983f-probe*.log`
  (probe scratch partially cleaned; see residuals).

## Diff (2 files + this receipt; no commit)

1. `lib/xaas/dev_seeds.ex` — env guard at the top of `run/0`
   (`refute_non_dev_target!/0`), fully commented. Typed refusal:
   `Mix.raise "REFUSED(dev_seeds, env=#{env}) -- dev seeds must never target a
   test/prod database ..."`. Allowed paths:
   - `Mix.env() == :dev` — the lawful `mix run priv/repo/seeds.exs` path
     (`mix ecto.setup`, mix.exs:288).
   - `Mix.env() == :test` AND the calling process holds a real
     `Ecto.Adapters.SQL.Sandbox` ownership checkout (manager mode `:manual` +
     `self() in manager.checkouts`). This keeps `test/xaas/dev_seeds_test.exs`'s
     three pre-existing real-DB courts green (they call `run/0` in :test env
     under `Sandbox.checkout/1`) — the sandbox rollback IS the
     pollution-prevention mechanism. Probe: `Xaas.Repo |> Ecto.Adapter.lookup_meta()
     |> Map.fetch!(:pid) |> :sys.get_state()` — same manager resolution
     `Ecto.Adapters.SQL.Sandbox.mode/2` itself uses (the sandbox ETS table is
     unnamed in this db_connection version, so the ETS-lookup probe does not
     exist; the manager state probe was verified live, see falsifiers).
   - Every other env refused unconditionally.
2. `test/xaas/dev_seeds_env_guard_test.exs` (new, permanent court, 2 tests):
   - Refusal court: after a real `Sandbox.checkout`, an unsandboxed caller
     (raw `spawn`, deliberately not a Task — Tasks inherit `$callers`, which
     the ownership manager consults and which would make the Task
     sandbox-covered) must raise `%Mix.Error{}` matching `REFUSED(dev_seeds`
     and `env=test`, and the real `library_books` count is asserted equal
     before/after (no rows written). Real DB, no mocks.
   - Availability court: a sandboxed `:test` caller still runs `run/0`
     successfully (guards the guard against over-refusing the existing
     courts).

## Spec deviation, disclosed

Dispatch spec: "refuse when `Mix.env() != :dev`" (pure env gate). Implemented:
env gate + one sanctioned exception (sandbox-owned :test callers). Reason:
`test/xaas/dev_seeds_test.exs` (untouchable under this lane's write bounds)
calls `run/0`/`approve_seeded_pending!/0` in :test env under a real sandbox
checkout; a pure env gate turns those 3 courts red (witnessed: first run after
the pure-env gate was `Result: 0/5 passed` with 3 `dev_seeds_test.exs`
refusals, kept in `/tmp/w983f-run1.log` — superseded by the passing rerun of
the same path). The exception does not open any leak: the allowed :test path
requires an active sandbox ownership checkout, whose teardown rollback is
exactly the mechanism that prevents commits. The actual leak shape (bare
`mix run`, :auto ownership mode, no checkout) is refused in both the court and
a live falsifier.

## Caller audit (grep of lib/, test/, priv/, mix.exs — real grep output)

| caller | path class | verdict under guard |
|---|---|---|
| `priv/repo/seeds.exs:16,30` (`run/0`, `approve_seeded_pending!/0`) | dev (`mix ecto.setup` / `mix run priv/repo/seeds.exs`, Mix.env :dev) | allowed |
| `test/xaas/dev_seeds_test.exs` (3 tests, run/0 + approve_seeded_pending!) | test, sandboxed | allowed (sandbox-owner branch) |
| `test/xaas/dev_seeds_env_guard_test.exs` (this lane) | test, both shapes | refusal + sandboxed both witnessed |
| `priv/repo/seed_persona_grants.exs` | comment-only mention, no call | n/a |

`approve_seeded_pending!/0` calls `run/0` internally, so it inherits the
guard. No aliases, mix tasks, or lib/ callers exist.

## Run evidence (real tails, fresh root `_build-laneW983f`)

- Run 1 (after final guard shape):
  `PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983f
  mix test test/xaas/dev_seeds_env_guard_test.exs test/xaas/dev_seeds_test.exs`
  → `Result: 5 passed` (Finished in 2.3 seconds).
- Run 2 (same command): `Result: 5 passed` (Finished in 1.1 seconds).
- Live leak-shape falsifier:
  `MIX_ENV=test MIX_BUILD_ROOT=_build-laneW983f mix run -e
  'Xaas.DevSeeds.run()'` → `** (Mix) REFUSED(dev_seeds, env=test) -- dev
  seeds must never target a test/prod database ...` (typed refusal, no rows
  written).
- Interim-state evidence (disclosed): the first court run under the pure-env
  gate was `Result: 0/5 passed` (3 refusals in dev_seeds_test.exs, 2 in the
  new court before the raw-spawn/no-Task fix and manager-state probe); the
  interim ETS-table probe was empirically falsified (`ArgumentError: ... does
  not refer to an existing ETS table` — the sandbox ownership ETS table is
  unnamed in this db_connection version) and replaced with the manager-state
  probe.

## Standing

- **PARTIAL_ALIVE**. Refusal witnessed on the exact leak subject (bare
  `MIX_ENV=test mix run` → typed `REFUSED`, court 5/5 ×2) — ALIVE for the
  test-env surface.
- Not witnessed: the `:dev` allow path (no dev-env mix run was executed —
  dev compiles are barred during this campaign per standing memory
  `no-dev-compile-during-campaign`); the `:prod` refusal (same gate, untested
  in a real prod boot). Guard branch `env == :dev -> :ok` is a literal return.
- Guard shape: `env == :dev -> :ok; env == :test and sandbox_owner?() -> :ok;
  true -> REFUSED`.

## Residuals

1. `_build-laneW983f` NOT deleted — `rm -rf` was denied by the session
   permission system (two attempts). Left for the coordinator per dispatch
   ("delete when done, else leave for coordinator"). Disk cost ~2-3 GB.
2. Probe scratch `/tmp/w983f_probe*.exs`, `/tmp/w983f-probe*.log`,
   `/tmp/w983f-mixrun.log` not removed (same denial). Harmless temp files.
3. The court's refusal test asserts `env=test` in the message; a hypothetical
   :prod boot is unwitnessed (covered by the same `true ->` clause).
