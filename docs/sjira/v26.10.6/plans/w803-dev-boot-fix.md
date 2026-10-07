# W803 — dev-env server boot fix (w752 blocker F1)

Lane W803, repo `/Users/sac/xaas`, branch `feat/playwright-surface`, HEAD `a0723bf6`.
Writes: `config/dev.exs` (ash_a2a block) + this receipt. No commit (coordinator owns transitions).

## Change

`config/dev.exs` `receipt_store_ekv_opts`:
`cluster_size: 1` → `cluster_size: 3` with comment citing W752 F1 / W803.

Why 3 is the minimum lawful value: ash_a2a 26.10.4
`deps/ash_a2a/lib/ash_a2a/receipt_store.ex` `boot_check/1` — production rule set
(`production? = :production env OR AshA2A.SecurityProfile.strict?/0`, RFC-SA2A-007 comment at
line 142-143) refuses `Ekv` with `cluster_size < 3`
(`{:error, {:insufficient_cluster_size, n}}`). Dev sets `security_profile: :strict`, so dev
inherits the production rule set. The `authority_broker` Ekv `cluster_size: 1` is NOT gated by
the preflight (only the receipt store is), so it stays at 1 — W752's runtime
`Application.put_env` bypass changed only the receipt-store value and cleared the preflight.

## Falsifier (real boot)

```
PATH=$HOME/.asdf/shims:$PATH MIX_ENV=dev MIX_BUILD_ROOT=_build-laneW803-dev \
  INTERNAL_API_TOKEN=w803-boot mix phx.server
```

Boot tail (boot 3, after concurrent-lane compile interference cleared):

```
[info] [EKV AshA2A.Authority.Broker.Ekv] started (shards=8)
[info] AshIam.PolicyCache started with regex cache limit: 1000, policy cache limit: 500
[info] Xaas.Telemetry.OcelAshEmitter attached 95 real telemetry handlers across 19 real Ash domain(s)
[warning] Xaas.Sa2a.Bridge not started: "autofde" executable not found on PATH (...)
[info] Running XaasWeb.Endpoint with cowboy 2.19.0 at 127.0.0.1:4000 (http)
[info] Access XaasWeb.Endpoint at http://localhost:4000
```

No `security preflight refused`, no `insufficient_cluster_size` anywhere in the log
(`/tmp/w803-boot3.log`). The W752 F1 error
(`** (AshA2A.Authority.SecurityPreflight.Error) ... {:insufficient_cluster_size, 1}`) does not
reproduce. Server was then killed (PID kill, port 4000 freed).

## Concurrent-lane interference (typed, not mine)

1. First boot attempt: my own `timeout 900` wrapper SIGTERMed the fresh 920-file dev compile
   mid-way (`SIGTERM received - shutting down`, `/tmp/w803-boot1` = w803-boot.log). Lane error,
   recompiled without it.
2. Second attempt: another lane's untracked file
   `lib/xaas/operations/validations/incident_resolved_is_terminal.ex` (created mid-lane in the
   shared checkout) failed compile under dev
   (`struct Ash.Changeset.OriginalDataNotLoaded is undefined` →
   `== Type checking failed with errors ==`), blocking the boot before the preflight. The owning
   lane fixed it at ~05:05; boot 3 passed. The test-env court also hit the same file
   (`_build-laneW803` fresh test compile aborted). Not tree state at HEAD; not fixed by this lane.
3. My dev boot bound 127.0.0.1:4000 — the live native dev server was NOT running at the time
   (clean bind). Freed on kill. (Port-convention note for coordinator: W688 dev-e2e port is 4002;
   phx.server defaults to 4000.)

## Test-env non-regression

`MIX_ENV=test MIX_BUILD_ROOT=_build-laneW803 mix test test/xaas/ash_a2a_runtime_config_court_test.exs`

```
Finished in 0.05 seconds (0.00s async, 0.05s sync)
Result: 8 passed
```

Green — W720's court pins `runtime.exs` (prod), not `dev.exs`; the dev.exs edit is non-regressing.

## Verdict

ALIVE for the F1 config fix: real `MIX_ENV=dev` boot passes the ash_a2a strict preflight at the
changed dev.exs. F2 (dev-DB duplicate-epochs migration) is untouched and still open — dev boot
gets past the preflight but dev-convention e2e remains BLOCKED(F2) per W752.
