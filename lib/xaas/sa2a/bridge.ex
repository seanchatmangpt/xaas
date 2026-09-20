defmodule Xaas.Sa2a.Bridge do
  @moduledoc """
  Hand-written residue (see HANDWRITTEN.md): the `Port.open/2` process
  wrapper and JSON-lines encode/decode around it. No admitted pack renders
  this -- `sa2a-bridge-pack` (ggen-marketplace) generates only
  `Xaas.Sa2a.Generated.Contract`/`Xaas.Sa2a.Generated.EdgeCatalog`
  (`lib/xaas/generated/sa2a_bridge_*.ex`), which name this module by string
  (`s2b:fromPlane "Xaas.Sa2a.Bridge.validate"` etc.) without generating it,
  the same construct-only boundary `xaas-castle-bridge-pack` observes for
  `Xaas.Castle.Reactor`.

  Speaks the real newline-delimited JSON-lines port protocol
  `autofde_lab/beam/beam_port_bridge.py` implements: one JSON object per
  line in, one JSON object per line out, `{"op": ..., ...}` ->
  `{"ok": bool, ...}`. Uses `Port.open/2` with `{:line, ...}` framing, which
  matches that script's `for line in sys.stdin: ... sys.stdout.write(...)`
  read/flush loop exactly -- no length-prefix framing on either side.

  Only `execute/1` is a consequential DO edge (`s2b:edge40`,
  `port_op: "sa2a_execute"`, `do_boundary?: true` in the generated edge
  catalog); `validate/1`, `admit/2`, `plan/1`, `replay/2` are
  verify/admit/construct/receipt operations per
  `Xaas.Sa2a.Generated.EdgeCatalog.all/0`.
  """

  use GenServer

  @port_command "autofde"
  @port_args ["beam-bridge"]
  @default_timeout_ms 15_000

  # -- client API --------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @spec validate(keyword()) :: {:ok, map()} | {:error, term()}
  def validate(opts \\ []) do
    req =
      %{"op" => "sa2a_validate"}
      |> maybe_put("card_path", Keyword.get(opts, :card_path))
      |> maybe_put("profile", Keyword.get(opts, :profile))

    call(req)
  end

  @spec admit(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def admit(candidate_id, assertion, opts \\ []) do
    req =
      %{
        "op" => "sa2a_admit",
        "candidate_id" => candidate_id,
        "assertion" => assertion,
        "query_id" => Keyword.get(opts, :query_id, "q0"),
        "source" => Keyword.get(opts, :source, "xaas-sa2a-bridge"),
        "evidence" => Keyword.get(opts, :evidence, %{})
      }

    call(req)
  end

  @spec plan([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def plan(candidates, opts \\ []) when is_list(candidates) do
    req =
      %{
        "op" => "sa2a_plan",
        "candidates" => candidates,
        "plan_id" => Keyword.get(opts, :plan_id, "xaas_frontier_plan"),
        "ticks" => Keyword.get(opts, :ticks, 1000),
        "tokens" => Keyword.get(opts, :tokens, 50_000),
        "experiments" => Keyword.get(opts, :experiments, 10)
      }

    call(req)
  end

  @doc "The sole consequential DO edge -- see s2b:edge40 / edge catalog's do_boundary?: true row."
  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(query, opts \\ []) do
    req =
      %{"op" => "sa2a_execute", "query" => query}
      |> maybe_put("compiled_rules", Keyword.get(opts, :compiled_rules))

    call(req)
  end

  @spec replay(term(), String.t()) :: {:ok, map()} | {:error, term()}
  def replay(manifest, expected_hash) do
    call(%{"op" => "sa2a_replay", "manifest" => manifest, "expected_hash" => expected_hash})
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp call(req, timeout \\ @default_timeout_ms) do
    GenServer.call(__MODULE__, {:request, req}, timeout)
  end

  # -- server -------------------------------------------------------------

  @impl true
  def init(opts) do
    command = Keyword.get(opts, :port_command, @port_command)
    args = Keyword.get(opts, :port_args, @port_args)

    port =
      Port.open({:spawn_executable, System.find_executable(command)}, [
        :binary,
        {:args, args},
        {:line, 1_048_576},
        :exit_status
      ])

    {:ok, %{port: port, waiting: nil}}
  end

  @impl true
  def handle_call({:request, req}, from, %{port: port, waiting: nil} = state) do
    line = Jason.encode!(req)
    Port.command(port, line <> "\n")
    {:noreply, %{state | waiting: from}}
  end

  def handle_call({:request, _req}, _from, state) do
    {:reply, {:error, :bridge_busy}, state}
  end

  @impl true
  def handle_info({port, {:data, {:eol, line}}}, %{port: port, waiting: waiting} = state)
      when waiting != nil do
    reply =
      case Jason.decode(line) do
        {:ok, %{"ok" => true} = resp} -> {:ok, resp}
        {:ok, %{"ok" => false} = resp} -> {:error, resp}
        {:ok, resp} -> {:ok, resp}
        {:error, reason} -> {:error, {:invalid_json, reason, line}}
      end

    GenServer.reply(waiting, reply)
    {:noreply, %{state | waiting: nil}}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port, waiting: waiting} = state) do
    if waiting, do: GenServer.reply(waiting, {:error, {:port_exited, status}})
    {:stop, {:port_exited, status}, %{state | waiting: nil}}
  end
end
