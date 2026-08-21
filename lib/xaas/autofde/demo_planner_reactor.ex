defmodule Xaas.Autofde.DemoPlannerReactor.PortRegistry do
  @moduledoc """
  Real, tiny public-ETS-backed registry used to hand a spawned OS port/pid from a
  `RunScript` step's `run/3` (which owns the live `Port.t()`) across to that same
  step's `compensate/4` (which only ever receives the step's `arguments`, not
  `run/3`'s local state) so `compensate/4` can find and kill the real process.

  A second table (`@audit`) records what `compensate/4` actually did to the real
  process, purely so tests can verify the real cleanup happened after
  `Reactor.run/2` has already returned.

  Reactor runs each step's `run/3`/`compensate/4` inside a short-lived async
  `Task`. ETS tables are owned by the process that creates them and are destroyed
  when that owner process exits — so these tables must NOT be lazily created
  inside a step's own transient Task (a real bug hit and fixed while building
  this: the table would vanish the moment the owning step's Task finished,
  taking the just-recorded audit entry with it). Instead this module is a tiny,
  free-standing `GenServer` started with `GenServer.start/3` (unlinked, no
  supervisor dependency) the first time any step needs it; it outlives every
  individual step's Task and holds the tables for the life of the runtime.
  """

  use GenServer

  @table :xaas_demo_planner_port_registry
  @audit :xaas_demo_planner_port_audit

  @spec ensure_started! :: :ok
  def ensure_started! do
    case GenServer.whereis(__MODULE__) do
      nil ->
        case GenServer.start(__MODULE__, :ok, name: __MODULE__) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
        end

      _pid ->
        :ok
    end
  end

  @impl GenServer
  def init(:ok) do
    :ets.new(@table, [:named_table, :public, :set])
    :ets.new(@audit, [:named_table, :public, :set])
    {:ok, %{}}
  end

  @spec put(String.t(), port(), non_neg_integer() | nil) :: true
  def put(request_id, port, os_pid) do
    ensure_started!()
    :ets.insert(@table, {request_id, port, os_pid})
  end

  @spec get(String.t()) :: {port(), non_neg_integer() | nil} | nil
  def get(request_id) do
    ensure_started!()

    case :ets.lookup(@table, request_id) do
      [{^request_id, port, os_pid}] -> {port, os_pid}
      [] -> nil
    end
  end

  @spec delete(String.t()) :: true
  def delete(request_id) do
    ensure_started!()
    :ets.delete(@table, request_id)
  end

  @spec record_kill(String.t(), non_neg_integer() | nil, :closed | :already_dead) :: true
  def record_kill(request_id, os_pid, outcome) do
    ensure_started!()
    :ets.insert(@audit, {request_id, os_pid, outcome})
  end

  @spec get_audit(String.t()) :: {non_neg_integer() | nil, :closed | :already_dead} | nil
  def get_audit(request_id) do
    ensure_started!()

    case :ets.lookup(@audit, request_id) do
      [{^request_id, os_pid, outcome}] -> {os_pid, outcome}
      [] -> nil
    end
  end
end

defmodule Xaas.Autofde.DemoPlannerReactor.RunScript do
  @moduledoc """
  Real `Reactor.Step` that proves the design doc's Port-not-NIF mechanics against a
  real, trivial external script standing in for an autofde-lab planner:

    * `run/3` spawns the real script via `Port.open({:spawn_executable, ...})` (not
      `:spawn` — the design doc's own rationale: `:spawn_executable` gives us a real
      OS pid we can `kill -TERM` directly, `:spawn` shells out through `/bin/sh -c`
      first), writes the real numeric input to the port's stdin, and reads the real
      stdout/exit status back.
    * `compensate/4` is invoked for real by Reactor whenever `run/3` returns
      `{:error, _}`. It looks the live port back up (via `PortRegistry`, since
      `compensate/4` only receives `arguments`, not `run/3`'s local state), confirms
      the process is real and still alive via `Port.info/1`, sends a real
      `kill -TERM`, closes the port, and records what it did so a test can verify the
      real OS process is actually gone afterward.
    * `compensate/4` returns `{:continue, {:failed, label}}` rather than `:ok` — per
      Reactor's own `step_runner.ex` (`handle_compensate_result({:continue, value}, ...)`
      -> `{:ok, value, []}`), this makes Reactor treat the step as having *succeeded*
      with that marker value instead of aborting/rolling back the whole run. That is
      the real mechanism `Xaas.Autofde.DemoPlannerReactor`'s ordered-fallback `where`
      guard reads to decide whether to run the fallback step.
  """

  use Reactor.Step

  alias Xaas.Autofde.DemoPlannerReactor.PortRegistry

  @impl true
  def run(%{script: script, input: input, request_id: request_id}, _context, options) do
    timeout_ms = Keyword.get(options, :timeout_ms, 5_000)

    port =
      Port.open({:spawn_executable, script}, [:binary, :exit_status, :use_stdio, args: []])

    os_pid =
      case Port.info(port, :os_pid) do
        {:os_pid, pid} -> pid
        _ -> nil
      end

    PortRegistry.put(request_id, port, os_pid)
    Port.command(port, "#{input}\n")

    result = collect(port, "", timeout_ms)

    case result do
      {:ok, output} ->
        # Real success: the port has already exited on its own, nothing left to
        # compensate, so the registry entry is cleaned up here.
        PortRegistry.delete(request_id)
        {:ok, String.trim(output)}

      {:error, {:timeout, output}} ->
        # Real, still-running process: our own wait timed out but the OS process
        # was never told to stop. Deliberately leave the registry entry in place
        # so `compensate/4` finds a genuinely live port/process to kill (verified
        # in `DemoPlannerReactorTest` via a real `ps` liveness check both before
        # and after compensation).
        {:error, {:script_timeout, timeout_ms, String.trim(output)}}

      {:error, {status, output}} ->
        # Real failure: deliberately leave the registry entry in place so
        # `compensate/4` (invoked next, by Reactor itself) can find the real port
        # and confirm/clean it up. `Port.info/1` will already return `nil` here
        # since the OS process has exited, but `compensate/4` still owns closing
        # the Elixir-side port and recording the real audit trail.
        {:error, {:script_failed, status, String.trim(output)}}
    end
  end

  @impl true
  def compensate(_reason, %{request_id: request_id} = arguments, _context, _options) do
    label = Map.get(arguments, :label, :unknown)

    case PortRegistry.get(request_id) do
      nil ->
        :ok

      {port, os_pid} ->
        outcome =
          if Port.info(port) do
            if os_pid, do: System.cmd("kill", ["-TERM", to_string(os_pid)], stderr_to_stdout: true)

            try do
              Port.close(port)
              :closed
            rescue
              # Real, legitimate race: the OS process's own death (from the
              # `kill -TERM` above, or having already exited between our
              # `Port.info/1` check and this call) can invalidate the port out
              # from under us before we get to close it ourselves. That is
              # still a fully-compensated outcome -- the process is gone
              # either way -- so it's recorded as such rather than crashing
              # `compensate/4`.
              ArgumentError -> :already_dead
            end
          else
            :already_dead
          end

        PortRegistry.record_kill(request_id, os_pid, outcome)
        PortRegistry.delete(request_id)

        {:continue, {:failed, label}}
    end
  end

  defp collect(port, acc, timeout_ms) do
    receive do
      {^port, {:data, data}} -> collect(port, acc <> data, timeout_ms)
      {^port, {:exit_status, 0}} -> {:ok, acc}
      {^port, {:exit_status, status}} -> {:error, {status, acc}}
    after
      timeout_ms -> {:error, {:timeout, acc}}
    end
  end
end

defmodule Xaas.Autofde.DemoPlannerReactor do
  @moduledoc """
  Real, minimal Reactor workflow proving the step/compensate/ordered-fallback
  mechanics described in
  `docs/claude/diataxis/explanation/reactor-autofde-planners-design.md`, against a
  real OS port spawning a trivial real script — not autofde-lab's actual planners
  (deliberately out of scope here; see the design doc for why).

  Shape: `:primary_plan` runs first. If its real script exits 0, its real stdout is
  the reactor's result and `:fallback_plan` is skipped via its `where` guard. If its
  real script exits non-zero, `run/3` returns `{:error, _}`, Reactor calls the step's
  real `compensate/4` (which really kills the spawned OS process), `compensate/4`'s
  `{:continue, {:failed, :primary}}` return lets Reactor continue rather than abort
  the whole run, and `:fallback_plan`'s `where` guard sees that marker and runs the
  real fallback script instead.
  """

  use Reactor

  input :run_id
  input :number
  input :primary_script
  input :fallback_script

  step :primary_plan, Xaas.Autofde.DemoPlannerReactor.RunScript do
    argument :script, input(:primary_script)
    argument :input, input(:number)
    argument :request_id, input(:run_id), transform: &(&1 <> "-primary")
    argument :label, value(:primary)
    max_retries 0
  end

  step :fallback_plan, Xaas.Autofde.DemoPlannerReactor.RunScript do
    argument :script, input(:fallback_script)
    argument :input, input(:number)
    argument :request_id, input(:run_id), transform: &(&1 <> "-fallback")
    argument :label, value(:fallback)
    argument :primary_result, result(:primary_plan)
    where &__MODULE__.fallback_needed?/1
    max_retries 0
  end

  step :final do
    argument :primary_result, result(:primary_plan)
    argument :fallback_result, result(:fallback_plan)

    run fn
      %{fallback_result: fallback_result}, _ when is_binary(fallback_result) ->
        {:ok, %{source: :fallback, value: fallback_result}}

      %{primary_result: primary_result}, _ when is_binary(primary_result) ->
        {:ok, %{source: :primary, value: primary_result}}

      _args, _ ->
        {:ok, %{source: :none, value: nil}}
    end
  end

  return :final

  @doc false
  def fallback_needed?(%{primary_result: {:failed, _label}}), do: true
  def fallback_needed?(_), do: false
end
