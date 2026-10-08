defmodule Xaas.Semantics.GraphlawPool do
  @moduledoc """
  Product-path singleton for the pinned graphlaw WASM kernel
  (`Xaas.Semantics.GraphlawWasm`).

  Closes the W638 disclosed gap ("no supervisor child spec added; transport
  only"): before this module, `Xaas.Semantics.GraphlawWasm` had zero production
  callers — the assess path went `Xaas.Bridges.Graphlaw.assess/2` ->
  `AshGraphLaw.law/3` -> `AshGraphLaw.Pool` (the dep's own wasmex host), never
  through the xaas-side pinned transport.

  Contract:

    * `invoke/2` lazily boots ONE pinned instance from `priv/graphlaw.wasm`
      under the `priv/graphlaw.wasm.sha256` pin (fail-closed digest admission)
      and holds it for the process lifetime. The wasmex instance is linked to
      this GenServer, so it dies with the pool.
    * `invoke/2` returns `{:ok, response_map}` (decoded JSON) or
      `{:error, %Xaas.Actuation.Refusal{}}` — the transport's own typed
      refusals, never papered over.
    * A lazy start failure is returned as the typed refusal (`:digest_mismatch`,
      `:digest_unpinned`, `:invalid_wasm`, ...) and stays sticky until the next
      `reset/0`: an artifact that fails admission must not be retried per call.
    * The pool is a serializing pool-of-one: `gl_alloc`/`gl_call`/`gl_free`
      transactions run inside the GenServer, one at a time. Throughput is one
      core; correctness is exact-artifact identity. (Disclosed: not a
      throughput component.)

  Note: this module is lazily started (`ensure_started/1` inside the call
  handler), NOT added to the application supervision tree — the supervision
  wiring is coordinator-owned and was out of this lane's file scope. A pool
  that was never called is never started; the first `invoke/2` pays the
  compile cost.
  """

  use GenServer

  alias Xaas.Semantics.GraphlawWasm

  @artifact GraphlawWasm.artifact_path()
  @default_timeout_ms 5_000

  defstruct [:instance, :error]

  # -- public API ----------------------------------------------------------

  @doc """
  Invokes the pinned kernel with `request` (JSON map) via
  `GraphlawWasm.invoke/3`. `opts` pass through (`:timeout` in ms, default
  #{@default_timeout_ms}).
  """
  @spec invoke(map(), keyword()) :: {:ok, map()} | {:error, Xaas.Actuation.Refusal.t()}
  def invoke(request, opts \\ []) when is_map(request) and is_list(opts) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        with {:ok, pid} <- ensure_pool() do
          call_invoke(pid, request, opts)
        end

      pid ->
        call_invoke(pid, request, opts)
    end
  end

  @doc "The digest the pool's instance was booted from, or the sticky refusal."
  @spec info() :: {:ok, %{artifact_digest: String.t(), artifact_path: String.t()}} | {:error, Xaas.Actuation.Refusal.t()}
  def info do
    case GenServer.whereis(__MODULE__) do
      nil ->
        with {:ok, pid} <- ensure_pool() do
          GenServer.call(pid, :info, 30_000)
        end

      pid ->
        GenServer.call(pid, :info, 30_000)
    end
  end

  @doc """
  Drops the sticky start error (if any) so the next `invoke/2` re-attempts
  admission. A no-op while the pool is healthy.
  """
  @spec reset() :: :ok
  def reset do
    case whereis_or_start() do
      {:ok, pid} -> GenServer.call(pid, :reset, 30_000)
      _ -> :ok
    end
  end

  # -- GenServer -----------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(_opts), do: {:ok, %__MODULE__{}}

  @impl true
  def handle_call({:invoke, request, opts}, _from, state) do
    case ensure_started(state) do
      {:ok, instance, state} ->
        case GraphlawWasm.invoke(instance, request, opts) do
          {:ok, _} = ok ->
            {:reply, ok, state}

          {:error, %Xaas.Actuation.Refusal{code: code}} = error
          when code in [:call_trapped, :call_timeout, :abi_failure] ->
            # The instance's linear memory may be in an unknown state after a
            # trap/timeout; recycle instead of reusing it.
            {:reply, error, %{state | instance: nil, error: nil}}

          {:error, _} = error ->
            {:reply, error, state}
        end

      {:error, refusal} = error ->
        {:reply, error, %{state | error: refusal}}
    end
  end

  @impl true
  def handle_call(:info, _from, state) do
    case ensure_started(state) do
      {:ok, instance, state} ->
        {:reply, {:ok, Map.take(instance, [:artifact_digest, :artifact_path])}, state}

      {:error, refusal} ->
        {:reply, {:error, refusal}, %{state | error: refusal}}
    end
  end

  @impl true
  def handle_call(:reset, _from, state), do: {:reply, :ok, %{state | error: nil}}

  # -- internals -----------------------------------------------------------

  defp call_invoke(pid, request, opts) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms) + 5_000
    GenServer.call(pid, {:invoke, request, opts}, timeout)
  end

  defp ensure_pool do
    case whereis_or_start() do
      {:ok, pid} -> {:ok, pid}
      _ -> {:error, pool_unavailable()}
    end
  end

  defp whereis_or_start do
    case GenServer.whereis(__MODULE__) do
      nil -> start_link()
      pid -> {:ok, pid}
    end
  end

  defp ensure_started(%{instance: nil, error: nil} = state), do: boot(state)

  defp ensure_started(%{instance: nil, error: %Xaas.Actuation.Refusal{}} = state),
    do: {:error, state.error}

  defp ensure_started(%{instance: instance} = state), do: {:ok, instance, state}

  defp boot(state) do
    case GraphlawWasm.start(@artifact) do
      {:ok, instance} ->
        {:ok, instance, %{state | instance: instance, error: nil}}

      {:error, %Xaas.Actuation.Refusal{}} = error ->
        error
    end
  end

  defp pool_unavailable do
    Xaas.Actuation.Refusal.new(:pool_unavailable, %{
      message: "graphlaw wasm pool could not be started"
    })
  end
end
