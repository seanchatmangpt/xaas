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

  Authority admission runs fail-closed, in `call/2`, before the request ever
  reaches `GenServer.call`/`Port.command/2`: the op is looked up against
  `Xaas.Sa2a.Generated.McpDescriptor.requires_authority?/1` (real, generated,
  fail-closed for any unregistered id -- see that module), and when it
  answers `true` a non-empty `authority` evidence map must be present or the
  call is refused with `{:error, :sa2a_authority_evidence_required}` without
  ever touching the port process. This mirrors the same
  `authority: Keyword.get(opts, :authority, %{})` /
  `is_map(authority) and map_size(authority) > 0` admission pattern already
  established for delegated actuation in `Xaas.Actuation.admit_authority/2`
  and for the CASTLE bridge in `Xaas.Castle.request/2`
  (`:castle_authority_evidence_required`) -- not a new convention.
  """

  use GenServer

  alias Xaas.Sa2a.Generated.McpDescriptor

  @port_command "autofde"
  @port_args ["beam-bridge"]
  @default_timeout_ms 15_000

  # -- client API --------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc """
  True when the `autofde` executable this bridge shells out to
  (`System.find_executable/1`) is actually on `PATH` in this environment.

  Used by `Xaas.Application` to decide, honestly and visibly, whether to
  include this GenServer in the supervision tree at all -- an environment
  without autofde-lab installed (e.g. a bare CI runner for this repo) must
  not fail application boot over a missing optional binary, but the gate
  itself must be real, not a silent no-op. See also the guard in `init/1`,
  which returns the same typed `{:executable_not_found, ...}` failure when
  this GenServer is started directly (bypassing the supervision-tree gate,
  e.g. from a test) against an environment where the binary is absent.
  """
  @spec available?() :: boolean()
  def available?(command \\ @port_command), do: System.find_executable(command) != nil

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

  @doc """
  The sole consequential DO edge -- see s2b:edge40 / edge catalog's
  `do_boundary?: true` row. `requires_authority?: true` in the generated MCP
  descriptor, so a non-empty `:authority` evidence map is required in
  `opts` or the call is refused before the port is ever touched -- see
  `call/2`.
  """
  @spec execute(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def execute(query, opts \\ []) do
    req =
      %{"op" => "sa2a_execute", "query" => query}
      |> maybe_put("compiled_rules", Keyword.get(opts, :compiled_rules))

    call(req, authority: Keyword.get(opts, :authority))
  end

  @spec replay(term(), String.t()) :: {:ok, map()} | {:error, term()}
  def replay(manifest, expected_hash) do
    call(%{"op" => "sa2a_replay", "manifest" => manifest, "expected_hash" => expected_hash})
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  @spec call(map(), keyword()) :: {:ok, map()} | {:error, term()}
  defp call(req, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout_ms)

    with :ok <- admit_authority(Map.get(req, "op"), Keyword.get(opts, :authority)) do
      GenServer.call(__MODULE__, {:request, req}, timeout)
    end
  end

  # -- authority admission -------------------------------------------------
  #
  # Fail-closed, and evaluated entirely before `GenServer.call/3` (hence
  # before `Port.command/2`) is ever reached -- a refusal here never starts
  # the port round trip. `McpDescriptor.requires_authority?/1` is the real,
  # generated, fail-closed lookup (unregistered ids answer `true`); the
  # non-empty-map check mirrors the established
  # `Xaas.Actuation.admit_authority/2` / `Xaas.Castle.request/2` pattern.
  defp admit_authority(op, authority) do
    if McpDescriptor.requires_authority?(op) do
      admit_authority_evidence(authority)
    else
      :ok
    end
  end

  defp admit_authority_evidence(authority) when is_map(authority) and map_size(authority) > 0,
    do: :ok

  defp admit_authority_evidence(_authority),
    do: {:error, :sa2a_authority_evidence_required}

  # -- server -------------------------------------------------------------

  @impl true
  def init(opts) do
    command = Keyword.get(opts, :port_command, @port_command)
    args = Keyword.get(opts, :port_args, @port_args)

    # Real, honest guard: `System.find_executable/1` returns `nil` when the
    # binary isn't on PATH, and `Port.open({:spawn_executable, nil}, ...)`
    # raises an opaque `%ErlangError{original: :enoent}` deep inside the
    # port driver (confirmed live) rather than failing this GenServer's
    # start in a way any caller (Xaas.Application's supervision tree, a
    # test's `start_supervised/2`) can pattern-match on. Fail explicitly
    # instead, via the normal `{:stop, reason}` init contract -- OTP turns
    # this into `{:error, {:executable_not_found, command}}` from
    # `start_link/1`, exactly like any other documented startup failure.
    case System.find_executable(command) do
      nil ->
        {:stop, {:executable_not_found, command}}

      executable ->
        port =
          Port.open({:spawn_executable, executable}, [
            :binary,
            {:args, args},
            {:line, 1_048_576},
            :exit_status
          ])

        {:ok, %{port: port, waiting: nil}}
    end
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
