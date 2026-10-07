# W741 — SA2A bridge/Executor error-surface deepening — RECEIPT

- **Lane**: W741 (xaas v26.10.6 campaign)
- **Subject**: `/Users/sac/xaas` @ `feat/playwright-surface`, HEAD `a0723bf61a1c6058bdcd2d0202c9519840182a5e` (canonical checkout, uncommitted: this lane's new test file only)
- **Date**: 2026-10-07
- **Artifacts**: `test/xaas/sa2a_bridge_deepening_test.exs` (new, untracked, NOT committed per lane instructions)

## What was manufactured

`test/xaas/sa2a_bridge_deepening_test.exs` — one file, 14 tests, Chicago-style (real OS
subprocesses, real GenServer, real `Port.open/2` JSON-lines framing; zero mocks;
mock grep clean — only the moduledoc mention of "no mocks").

### (a) Port bridge — real external process

A real `#!/bin/sh` script (written to tmp, `chmod 755`, spawned through the
bridge's actual mechanism: `Port.open({:spawn_executable, ...})` with
`{:line, 1048576}` framing), emitting valid → ok:false → malformed → exit 5
in sequence over one port:

1. valid JSON line → `{:ok, %{"ok" => true, "ack" => "valid"}}` (exact payload)
2. peer `ok:false` line → exact error map `{:error, %{"ok" => false, "code" => "refused_by_peer"}}`
3. malformed line → `{:error, {:invalid_json, %Jason.DecodeError{}, "not-json-at-all"}}` — note: the `{:line, N}` framing delivers the payload **without** the trailing newline (assumption that it included it was falsified by run — corrected in test)
4. process death mid-stream (`exit 5`) → exact `{:error, {:port_exited, 5}}`, and the owning GenServer exits (`wait_until(not alive?)` — stop is async relative to the reply; a `refute alive?` immediately after the reply was falsified by run)
5. post-death call: the ExUnit supervisor restarts the `:permanent` child (observed: fresh pid + fresh port + fresh script instance round-trips `{"ok":true}`); restart is supervisor policy, not bridge behavior — asserted as the fresh-incarnation clean round-trip

Plus:

- authority admission is fail-closed **before any port process exists**: `execute/2` with `%{}`/`nil` authority → `{:error, :sa2a_authority_evidence_required}` with `whereis(Bridge) == nil` throughout; with real authority evidence the same call exits `:noproc` — proof the refusal is admission-side, not transport-side
- init guard: `start_supervised` with a nonexistent `port_command` → `{:error, {{:executable_not_found, path}, _child_spec}}` (the wrapped `{:stop, ...}` init contract, incl. ExUnit's child-spec wrapper)

### (b) Executor

- real call, sandbox-harmless: `Executor.execute/2` with bridge down → exact `{:error, {:blocked, :bridge_not_running}}`
- `ensure_bridge(true)` without `autofde` on PATH → exact `{:error, {:blocked, {:autofde_not_on_path, "export PATH=$HOME/autofde-lab/.venv/bin:$PATH"}}}` (env-conditional test; autofde absent here)
- sole-Actuation-caller + authority-context source pin: the only file under `lib/xaas/sa2a/` whose source matches `Xaas.Actuation.run(` (call-site with paren, so docstring `run/4` mentions don't count) is `executor.ex`; the `authority/2` machine-policy map (`kind: "machine_policy"`, `capability: "sa2a_executor"`, `policy: "Xaas.Sa2a.ExecutionPolicy"`, `policy_class/admit_receipt_id/admit_candidate_hash/plan_hash` from the verdict, `authorize?: true`, `idempotency_key`) is pinned line-by-line in source

### (c) computation/route artifact validation

- **exactly-one-kind-data-part rule** (`Xaas.Sa2a.Route.task_tuple/1`, via `tuple(:task, ...)`/`conserve/3`) against the real generated fixture `test/fixtures/sa2a_route/sa2a_task.json`:
  - zero route-schema data parts → `{:refused, {:missing_field, "subject"}}`
  - exactly one → `{:ok, tuple}` with binary subject/capability
  - two → `{:refused, {:ambiguous_tuple_carrier, 2}}`; `conserve/3` wraps it as exact `{:refused, %{broken_term: "ambiguous_tuple_carrier", hop: :task, reason: 2}}`
  - a part with `kind: "file"` never carries the tuple → `{:refused, {:missing_field, "subject"}}`
- **order_formal/2** (`Xaas.Semantics.PlanningAdvice`, `lib/xaas/semantics/computation.ex:265` — note the backlog item called this "computation.ex", it lives under `lib/xaas/semantics/`, not `lib/xaas/sa2a/`): ranks score desc, ties by ref asc (0.91 tie → `failover` before `rollback`, falsified my initial guess), filters advice refs to the formal set (advised-but-not-formal `not-formal` dropped), appends the un-advised formal remainder in its original order; duplicated formal refs → `{:error, :formal_candidate_refs_must_be_unique}`; empty advice keeps formal order `{:ok, ["b", "a"]}`

## Real command tails

```
$ PATH=$HOME/.asdf/shims:$PATH MIX_ENV=test MIX_BUILD_ROOT=_build-laneW741 \
    mix test test/xaas/sa2a_bridge_deepening_test.exs --include subprocess
Finished in 1.1 seconds (0.00s async, 1.1s sync)
Result: 14 passed

$ ... (stability rerun)
Result: 14 passed
```

Two consecutive full-green runs. Prior runs' failures (9 → 1 → 0) were test-side
expectation corrections against real observed behavior, each disclosed above.

## Falsifiers run

- exact-payload asserts on all four port-reply classes (would fail on any framing/decode drift)
- `refute whereis` before every bridge start (would fail if an ambient bridge leaked in)
- `wait_until(not alive?)` on the port-death pid (would fail if the GenServer survived its port)
- :noproc probe proving the authority refusal fires before the port exists
- sole-caller source pin `callers == ["executor.ex"]` (would fail if any sibling gains an Actuation call site)
- exact typed terms for Executor BLOCKED paths and Route ambiguous-carrier

## Standing

- Bridge JSON-lines protocol four reply classes: **ALIVE** (real port, exact terms, 2 green runs)
- Bridge authority-before-port + init typed failure: **ALIVE**
- Executor BLOCKED typed paths + sole-caller/authority-context source pin: **ALIVE (source pin for the authority map; live term asserts for BLOCKED paths)**
- Route exactly-one-kind-data-part + conserve typed wrap: **ALIVE** (real generated fixture `sa2a_task.json`)
- PlanningAdvice.order_formal/2 semantics: **ALIVE** (real calls)

## Typed gaps / UNSUPPORTED

- **Port death → supervision restart** is a supervisor-policy fact, not a bridge
  fact. The bridge contract asserted is: reply `{:error, {:port_exited, 5}}` +
  owning GenServer exits. What happens after (restart vs :noproc) depends on the
  restart option; production restart policy is Xaas.Application's, not exercised.
  → gap typed UNSUPPORTED(supervision_policy_not_exercised)
- **A real `autofde beam-bridge` subprocess** was not used (binary not on PATH in
  this environment); the real documented `beam_port_bridge.py` protocol is
  exercised through a real sh script over the identical `{:line, N}` JSON-lines
  contract. → typed UNSUPPORTED(autofde_binary_absent), same class as the
  existing `bridge_authority_subprocess_chicago_test.exs` (`cat` stand-in).
- **Full `Executor.execute` to a sealed receipt** (Court.admit → DO → replay) was
  not driven (needs the live port + seeded admit/plan reproducibility); asserted
  instead: BLOCKED path live, authority map pinned in source. → typed gap
  UNSUPPORTED(full_do_path_not_driven)
- Executor authority-context construction is asserted as a source pin, not a live
  term. → typed gap UNSUPPORTED(authority_map_source_pin_only)
- `@tag :autofde_env_probe` test is environment-conditional (skips itself if
  `autofde` is on PATH).
- One transient environment failure during the run: a sibling lane's in-flight
  edit to `lib/xaas/ocel.ex` broke compilation ~3 min (syntax error at
  ocel.ex:36, resolved by that lane); fixed forward, not this lane's file.

## Falsifier for this receipt

```
mix test test/xaas/sa2a_bridge_deepening_test.exs --include subprocess
```
ceasing to pass (any of the 14) refutes the ALIVE standings above.
