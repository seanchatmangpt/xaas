defmodule Xaas.Actuation.Middleware.AuditLogger do
  @moduledoc """
  Reactor.Middleware providing structured telemetry and lifecycle auditing
  for all actions entering the Ash.Reactor actuation control plane.
  """
  use Reactor.Middleware
  require Logger

  @impl true
  def init(context) do
    {:ok, Map.put_new(context, :reactor_start_time, System.monotonic_time(:microsecond))}
  end

  @impl true
  def complete(result, context) do
    duration_us =
      case Map.get(context, :reactor_start_time) do
        nil -> 0
        start -> System.monotonic_time(:microsecond) - start
      end

    Logger.debug("[Reactor.Audit] Succeeded in #{duration_us}µs")
    {:ok, result}
  end

  @impl true
  def error(errors, _context) do
    Logger.error("[Reactor.Audit] Failed with errors: #{inspect(errors)}")
    :ok
  end

  @impl true
  def event({:run_start, _args}, step, _context) do
    Logger.debug("[Reactor.Audit] Step starting: #{inspect(step.name)}")
    :ok
  end

  def event({:run_complete, _result}, step, _context) do
    Logger.debug("[Reactor.Audit] Step completed: #{inspect(step.name)}")
    :ok
  end

  def event(_event, _step, _context), do: :ok
end
