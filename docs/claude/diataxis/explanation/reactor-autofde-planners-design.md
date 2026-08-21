# Reactor Design: Orchestrating autofde-lab's Planners from xaas

Status: proposal, unimplemented. No `lib/` or `test/` code exists yet for anything described
here. Grounded against the real `~/autofde-lab` repo as it exists on this machine as of
2026-08-20 — file paths below were read directly, not invented.

## What actually exists in autofde-lab

`~/autofde-lab` is a real, large Python monorepo (a fork/adaptation of AIRBUS's
scikit-decide, package name `autofde_lab`). The planner families named in the task are real
and live at `~/autofde-lab/src/autofde_lab/hub/solver/`:

- `mcts/mcts.py` (954 lines) — MCTS, backed by `_MCTSSolver_`
- `riw/riw.py` (367 lines) — RIW, backed by `_RIWSolver_`
- `astar/astar.py` (290 lines) — A*, backed by `_AStarSolver_`
- `aostar/aostar.py` (288 lines) — AO*
- `lrtdp/lrtdp.py` (497 lines) — LRTDP
- `ilaostar/ilaostar.py` (292 lines) — a real LAO*-family solver (`ilaostar`)
- `martdp/martdp.py` (344 lines) — MARTDP (multi-agent RTDP)
- plus ~30 more (`bfws`, `iw`, `pomcp`, `despot`, `hsvi`, `vi`, ...) under the same directory.

Every one of these Python modules is a thin wrapper: it defines a scikit-decide `Solver`
subclass and, inside a `try:` block, does
`from autofde_lab.hub.__autofde_lab_hub_cpp import _MCTSSolver_ as mcts_solver` (same pattern
in `astar.py`, `riw.py`, `martdp.py`, `lrtdp.py`, and 22 others — verified by
`grep -l "hub_cpp"` across `hub/solver/*/*.py`). The actual search runs **in-process, inside
the Python interpreter**, via a compiled pybind11 C++ extension
(`autofde_lab.hub.__autofde_lab_hub_cpp`, built from `~/autofde-lab/cpp/`). There is no OS
subprocess boundary inside autofde-lab today between Python and the C++ search — this matters
for §1 below.

A real, already-existing multi-planner orchestrator is
`~/autofde-lab/src/autofde_lab/reasoning/planner_federation.py`. Its own module docstring
states directly:

> "This module computes candidate plans. It does not actuate, admit, or issue receipts — see
> `src/autofde_lab/CLAUDE.md`."

`~/autofde-lab/src/autofde_lab/CLAUDE.md` confirms this at the package level, under
"Non-authority": *"No admission, no broker, no actuation, no standing verdict... No plan
execution."* `planner_federation.py` currently federates only `Astar` and `FF`
(`SOLVER_NAMES = ("Astar", "FF")`), each under a per-solver wall-clock timeout via
`concurrent.futures`, with real, cited reasons in its own docstring for why `BFWS`/`IW`
(missing required constructor args) and `AOstar` (a real 60s hang observed on a 6-block
widened fixture) are excluded from the default set. This is the closest existing precedent
in the repo for "try planner A, fall back to planner B," though it currently races/collects
via a thread pool rather than an ordered fallback chain.

A real, working entry point exists for invoking this machinery from outside the Python
process: `~/autofde-lab/src/autofde_lab/fabric/cli.py`, a Typer app (`APP_NAME =
"autofde-lab-fabric"`), invoked as `python -m autofde_lab.fabric` (no `[project.scripts]`
console script is registered — the CLI's own top-of-file comment says so explicitly). A
sibling `~/autofde-lab/src/autofde_lab/fabric/mcp.py` exposes the same fabric over MCP. The
CLI is the natural process boundary for an Elixir Port to spawn against: JSON in via stdin or
argv, JSON out via stdout, a real OS process lifecycle to supervise.

**Important scope correction verified against the repo, not assumed:** a *different* package,
`~/autofde-lab/src/autofde_lab_planner/` (note: no `hub`, different tree, built for the
`sregym` Kubernetes-fault benchmark described in `docs/STATUS.md` passes 16-20), does **not**
stay read-only. Its `remediators/` directory (`pvc_storage_faults.py`, `flagd_drift.py`,
`coredns_fault.py`, `rbac_misconfig.py`, `object_reconstruction.py`) and one detector
(`host_port_conflict.py`) issue real `kubectl` commands against a live cluster — confirmed by
`docs/STATUS.md`'s own pass-16 language ("execute the corrective `kubectl` command") and by
`grep` hits for actuation-shaped code in that directory. **This design's compensation-scope
claim in §3 is about the classical search planners in `hub/solver/` and their
`planner_federation.py` orchestrator, which really are compute-only** (verified above) — it
does not extend to `autofde_lab_planner`, which is out of scope for this design and would
need its own, separate actuation-boundary treatment if xaas ever orchestrates it.

## 1. Why a Port, not a NIF

autofde-lab's planners are not lightweight function calls. `mcts.py`, `astar.py`, `riw.py`,
`lrtdp.py`, and `martdp.py` each hand control to a compiled C++ solver
(`_MCTSSolver_`/`_AStarSolver_`/`_RIWSolver_`/`_MARTDPSolver_`, from
`autofde_lab.hub.__autofde_lab_hub_cpp`) that runs an unbounded, potentially long (seconds to
minutes, per the planner-family literature these names come from — best-first search,
rollout-based MCTS, real-time DP) tree/graph search. Today, inside Python, this is already an
in-process C extension call: exactly the shape a BEAM NIF would replicate if xaas linked
against the same `.so`/pybind11 module directly.

A NIF is a direct, synchronous C call on a BEAM scheduler thread. The BEAM cooperative
scheduler assumes every NIF returns in about 1ms; a NIF that runs longer starves that
scheduler thread, and with it every other Erlang process scheduled onto it, for the NIF's
entire duration — the standard, well-documented downside of naive NIFs, exactly the class of
call these C++ solvers are (unbounded search, not fixed-cost work). Dirty schedulers reduce
but do not eliminate this risk, and still require the C++ side to cooperate with periodic
yield/cancellation checks that scikit-decide's `_MCTSSolver_`/`_AStarSolver_` were never
written to do (no CLAUDE.md invariant or code comment claims interruptibility for the
compiled hub solvers).

A Port (`Port.open({:spawn_executable, python_interpreter_path}, args: [...])`, or
`System.cmd`/`Rustler`-adjacent equivalents are explicitly rejected in favor of Port for the
same reason) puts the entire Python process — interpreter, C++ extension, and all — on the OS
side of a pipe. The BEAM scheduler only ever waits on port messages; it is never blocked by
whatever the Python/C++ side is doing. Killing a runaway planner is `Port.close/1` plus an OS
`kill`, not an unrecoverable scheduler stall. Given that autofde-lab's own solvers already
demonstrate CPU-bound, non-preemptible C++ compute as their normal operating mode (this is
not a hypothetical risk invented for this doc — it's the literal architecture at
`hub/solver/*/*.py`), a Port is the only choice consistent with xaas's existing "fix forward,
don't destabilize the runtime" discipline.

The real invocation shape: spawn `python -m autofde_lab.fabric plan --domain <path>
--solver <name> --timeout <n>` (or the fabric MCP server over stdio, if that framing is
preferred later) via `Port.open`, write a JSON planning request to stdin, read a JSON result
(or a length-prefixed stream of partial-plan events) from stdout, and treat any non-zero exit
or timeout as a step failure that Reactor's own retry/fallback machinery handles — not
something the Elixir side tries to introspect Python tracebacks for.

## 2. Reactor step-per-planner-family, ordered fallback

Ash Reactor step DSL: one `step` per planner family, executed as an **ordered fallback
chain**, not a parallel race.

```elixir
reactor do
  step :mcts_plan, XaasAutofde.Steps.RunPlanner do
    argument :domain_spec, input(:domain_spec)
    argument :planner, value("MCTS")
  end

  step :riw_plan, XaasAutofde.Steps.RunPlanner do
    argument :domain_spec, input(:domain_spec)
    argument :planner, value("RIW")
    # runs only if :mcts_plan's guard says the prior attempt didn't produce a usable plan
    guard {&plan_missing?/1, result(:mcts_plan)}
  end

  step :astar_plan, XaasAutofde.Steps.RunPlanner do
    argument :domain_spec, input(:domain_spec)
    argument :planner, value("Astar")
    guard {&plan_missing?/1, result(:riw_plan)}
  end

  # ... lrtdp_plan, martdp_plan, same shape
end
```

**Why ordered fallback, not racing every planner in parallel, for this domain specifically:**

- **Cost asymmetry, not latency-hiding.** Racing N planners in parallel means paying for N
  Python/C++ processes' worth of CPU on every single planning request, even the easy ones —
  and `planner_federation.py`'s own docstring already shows the cheap planners (`Astar`, `FF`)
  solving small/medium fixtures instantly while a more expensive one (`AOstar`) can run 60+
  real seconds without finishing. Ordered fallback (cheapest/most-likely-to-succeed first, per
  domain characteristics — MCTS for stochastic/large branching, RIW for structured
  goal-reaching under novelty pruning, A* only where the domain is confirmed deterministic
  with an admissible heuristic, per the builder-mixin types each solver module declares:
  `astar.py` requires `DeterministicTransitions`+`Goals`+`PositiveCosts`) spends compute only
  where it's needed, which matters when each attempt is a full OS process plus a
  potentially-minutes-long C++ search, not a cheap in-memory call.
- **A late planner's real value is "the cheap ones already told us something."** Racing throws
  away that information — every loser's partial work is simply discarded. An ordered chain can
  carry forward the failed attempt's diagnostic state (why did MCTS give up — budget exhausted?
  no path found within horizon?) as an argument to the next step, which the domain's own
  builder-type mismatches already make necessary: `bfws.py`/`iw.py` need a `state_features`
  constructor argument neither `Astar` nor `FF` supplies by default, so a real ordered design
  has to decide *which* domain characterization to hand the next planner, not just retry blindly.
- **Resource contention is real, not theoretical, for this workload.** Each planner family here
  is not a fast heuristic — it's a full OS process running an unbounded C++ search. N of them
  racing means N processes competing for the same CPU cores, which can make *all* of them
  slower than running one at a time, unlike racing genuinely cheap, I/O-bound calls (e.g., two
  HTTP requests to different mirrors) where racing is a pure latency win.
- **A saga's own compensation story is simpler with one live attempt at a time.** `compensate/4`
  (§3) only ever needs to know about one running port per Reactor run under ordered fallback;
  under parallel racing it would need to kill N-1 losers the instant a winner is found, which is
  a real, separate synchronization problem this design does not need to solve for the ordered
  case.

Each `RunPlanner` step's `run/3` opens the Port, waits for a result or the step's own timeout,
and returns `{:ok, plan}` or `{:error, reason}`; Reactor's `guard`/`where` step-skipping (or,
if version constraints make that unavailable, a switch step reading the accumulated results)
implements "on failure/timeout, try the next planner." `max_retries: 0` per step — retrying
the *same* planner family is not this chain's job; falling through to the next family is.

## 3. compensate/4 — scoped to port-process cleanup only

Every `RunPlanner` step's `compensate/4` does exactly one thing: if the Elixir-side port for
this step's attempt is still open when Reactor unwinds (this step's own crash, or a
later step's un-recoverable failure triggering saga-wide rollback), send the OS process a
kill signal and close the port. Nothing else.

```elixir
@impl true
def compensate(_reason, %{port: port, os_pid: os_pid}, _context, _options) do
  if Port.info(port) do
    System.cmd("kill", ["-TERM", to_string(os_pid)])
    Port.close(port)
  end
  :ok
end
```

This is deliberately narrow, and the narrowness is the point given what §"What actually
exists" verified: the classical planners this design orchestrates
(`hub/solver/{mcts,riw,astar,aostar,lrtdp,martdp,...}`) and their existing
`planner_federation.py` orchestrator are real, confirmed compute-only — no admission, no
actuation, no external side effect beyond returning a plan. There is nothing in their
own process for `compensate/4` to "undo" except the process itself: no Kubernetes objects
were mutated, no file was written outside the process's own temp scratch space, no external
system was called. Killing the OS process **is** the complete, correct compensation for this
step. A design that tried to give `compensate/4` more responsibility (e.g., "undo whatever the
planner did") would be solving a problem that, per the verified evidence above, does not exist
for these planner families — and would be actively wrong if later pointed at
`autofde_lab_planner`'s `remediators/` (§"What actually exists"), which does run real
`kubectl` mutations and would need a genuinely different, non-trivial compensation design
(likely: don't compensate mutations after the fact at all, gate them behind a separate
Reactor step with its own human/policy approval before they run) — explicitly out of scope
here.

## 4. Example Reactor module skeleton (illustrative only, not wired into the app)

```elixir
defmodule XaasAutofde.Reactors.PlanWithFallback do
  @moduledoc """
  Illustrative skeleton only. Not registered with any Ash domain, not
  referenced from any route or Oban worker. See
  docs/claude/diataxis/explanation/reactor-autofde-planners-design.md.
  """
  use Reactor

  input :domain_spec  # JSON-serializable description of the planning problem
  input :python_bin    # absolute path to the venv's python, e.g. from Application config

  step :mcts_plan do
    argument :domain_spec, input(:domain_spec)
    argument :python_bin, input(:python_bin)

    run fn %{domain_spec: domain_spec, python_bin: python_bin}, _context ->
      args = ["-m", "autofde_lab.fabric", "plan", "--solver", "MCTS", "--timeout", "30"]
      port = Port.open({:spawn_executable, python_bin}, [
        :binary, :exit_status, args: args
      ])
      os_pid = Keyword.fetch!(Port.info(port), :os_pid)
      Port.command(port, Jason.encode!(domain_spec))

      receive do
        {^port, {:data, json}} ->
          Port.close(port)
          {:ok, Jason.decode!(json)}
        {^port, {:exit_status, status}} when status != 0 ->
          {:error, {:planner_exited, "MCTS", status}}
      after
        30_000 ->
          System.cmd("kill", ["-TERM", to_string(os_pid)])
          Port.close(port)
          {:error, {:planner_timeout, "MCTS"}}
      end
    end

    compensate fn _reason, _args, _context, _options ->
      # process is already dead/closed by the timeout/exit branches above in
      # this simplified sketch; a real implementation carries {port, os_pid}
      # in step state so compensate/4 can reach them independent of which
      # branch of `run` returned.
      :ok
    end
  end

  # riw_plan, astar_plan, lrtdp_plan, martdp_plan: same shape, each guarded
  # to run only if every earlier step failed to produce a usable plan.

  return :mcts_plan  # or a final step that picks whichever attempt succeeded
end
```

This is deliberately a sketch: real error-branch/state-passing for `compensate/4` (the comment
above names the gap honestly — a real implementation needs the port/os_pid available to
`compensate/4` regardless of which `run/3` branch returned), real backoff between chain
attempts, and real JSON schema for `domain_spec` are all left to an actual implementation PR,
not asserted as done here.

## 5. What is genuinely undecided / deferred

- **Where does a plan get persisted?** No `Xaas.Autofde.PlanningRun` (or similarly-named) Ash
  resource exists in this codebase today. Whether one should — with a `json_api routes do`
  block, given `docs/claude/diataxis/reference/http-api-surface.md`'s existing 44-resource
  precedent — versus keeping planning ephemeral (compute-on-request, return the plan in the
  HTTP response, never store it) is undecided. If persisted, this new resource is not
  financial-ledger or auth/PII data by nature, so the "never blindly wire routes" prohibition
  in this repo's `CLAUDE.md` would not automatically apply — but the deny-by-default policy
  floor still would, and a first-pass authorization design has not been done.
- **Which `domain_spec` schema autofde-lab's fabric CLI actually expects on stdin** — this
  design read `fabric/cli.py`'s app scaffolding but did not read every `DecisionRequest`
  field in `fabric/models.py` deeply enough to commit to a wire schema here.
- **Whether the Python side should be the already-existing `fabric/mcp.py` MCP server instead
  of the Typer CLI** — both are real, both exist; an MCP-over-stdio Port has a cleaner
  request/response framing than parsing CLI stdout, but wiring an MCP client into a Reactor
  step is a separate design decision not resolved here.
- **How planner selection maps to `domain_spec` characteristics.** §2 gestures at "MCTS for
  stochastic/large branching, A* only where deterministic+admissible-heuristic" based on the
  builder-mixin types each solver module declares (`Markovian`, `DeterministicTransitions`,
  `Goals`, `PositiveCosts`, etc.), but a real selection/ordering policy — and whether it's
  static per Reactor definition or computed per request — is not designed here.
- **Whether `autofde_lab_planner`'s actuating remediators (§"What actually exists") are ever
  meant to be reachable from xaas at all.** This design deliberately excludes them; if a
  future task asks for that, it needs its own actuation-boundary and approval-gate design, not
  an extension of this one's `compensate/4` scope.
- **Process pool / concurrency limits.** Nothing here addresses how many concurrent Python
  Ports xaas would tolerate under real load, or whether a `NimblePool`-style pre-warmed
  interpreter pool is worth the complexity versus `Port.open` per request.

## See Also

- `docs/claude/diataxis/reference/ash-configuration.md` — real, current domain/extension setup
- `docs/claude/diataxis/reference/http-api-surface.md` — real HTTP route precedent this design
  would follow if a `PlanningRun` resource is ever added
- `docs/ASH-MIGRATION-PLAN.md` — standing deferred-decision discipline this doc follows
- `~/autofde-lab/src/autofde_lab/CLAUDE.md` — the source-of-truth "compute plans, don't
  actuate" invariant this design's §3 depends on
- `~/autofde-lab/docs/STATUS.md` — real, dated status of autofde-lab's planners and the
  separate, actuating `autofde_lab_planner` benchmark driver this design excludes
