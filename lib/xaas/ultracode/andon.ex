defmodule Xaas.Ultracode.Andon do
  @moduledoc """
  The Andon cord: a minimal GenServer + ETS record of epistemic-horizon
  trips (loops-of-loops spec L4).

  When a loop exhausts its horizon (the crown's `execute/6`, the drive's
  frontier_after halt, a pplan `PolicySupervisor` horizon refusal mapped by
  `Xaas.Ultracode.ConvergenceReceipt`), the loop calls `trip/2`: the cord
  is pulled, the trip is recorded (cord_id, reason, receipt digest) in an
  ETS table owned by this process, and the CALLING loop stops itself. The
  cord is the record; the halting loop is the trip's consequence.

  ## Honest scoping (documented, per the spec's own boundary note)

  The spec's "trip the OTP supervisor tree" is satisfied here by the
  recorded cord + the calling process halting that order's loop + the
  FAILED_CONVERGENCE receipt. This is deliberately NOT a full supervisor
  restart cascade: no child of the supervision tree is killed or restarted
  by a trip, because a restart cascade is a production-topology decision
  (which children restart, under which strategy, with which backoff) that
  this repo has not made. The cord + halting loop + receipt is the
  testable core; a future cascade would CONSUME the cord (`tripped?/1` is
  exactly the state a restart policy would read), never mint it.

  ## Opt-in supervision

  Default boots are unchanged: `Xaas.Ultracode.AndonSupervisor` starts this
  process only when `config :xaas, :andon_enabled, true` is set. When Andon is not
  running, `trip/2` is a no-op (the receipt still exists -- minting is not
  gated on the cord) and `tripped?/1` reads false. The crown and the drive
  call `trip/2` unconditionally; the no-op is the disabled path.
  """

  use GenServer

  @table __MODULE__
  @schema "xaas/ultracode-andon/v1"

  @typedoc "One recorded trip."
  @type trip :: %{
          required(:cord_id) => String.t(),
          required(:reason) => String.t(),
          optional(:receipt_digest) => String.t() | nil,
          optional(:tripped_at) => DateTime.t()
        }

  @doc "The trip-record schema marker."
  @spec schema() :: String.t()
  def schema, do: @schema

  @doc "Starts the Andon (supervised via `Xaas.AndonSupervisor`)."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, Keyword.take(opts, [:name]), name: opts[:name] || @table)
  end

  # The ETS table is public read so tripped?/1 never needs a GenServer.call.
  @impl true
  def init(opts) do
    :ets.new(@table, [:set, :named_table, :public, read_concurrency: true])
    {:ok, %{name: opts[:name] || @table}}
  end

  @doc """
  Pulls the cord for `cord_id`: records `{cord_id, reason, receipt_digest,
  tripped_at}` in the ETS and returns `:ok`. `detail` is the reason binary,
  or a map with `"reason"` and optional `"receipt_digest"` (the minted
  receipt's `horizon_witness`).

  No-op `:ok` when Andon is not running (no ETS table) -- the disabled
  path, exactly as the opt-in supervision contract requires.
  """
  @spec trip(String.t(), String.t() | map()) :: :ok
  def trip(cord_id, detail) when is_binary(cord_id) and (is_binary(detail) or is_map(detail)) do
    if table_alive?() do
      entry = %{
        cord_id: cord_id,
        reason: reason(detail),
        receipt_digest: digest(detail),
        tripped_at: DateTime.utc_now()
      }

      true = :ets.insert(@table, {cord_id, entry})
      :ok
    else
      :ok
    end
  end

  @doc """
  True iff `cord_id` has been tripped on this node (Andon running). False
  when Andon is not running: an unstarted cord has recorded nothing.
  """
  @spec tripped?(String.t()) :: boolean()
  def tripped?(cord_id) when is_binary(cord_id) do
    if table_alive?() do
      case :ets.lookup(@table, cord_id) do
        [{_cord, _entry}] -> true
        [] -> false
      end
    else
      false
    end
  end

  @doc """
  The recorded trip for `cord_id` (`{:ok, trip}`) or `:error` (not tripped,
  or Andon not running).
  """
  @spec trip_record(String.t()) :: {:ok, trip()} | :error
  def trip_record(cord_id) when is_binary(cord_id) do
    if table_alive?() do
      case :ets.lookup(@table, cord_id) do
        [{_cord, entry}] -> {:ok, entry}
        [] -> :error
      end
    else
      :error
    end
  end

  @doc "Every recorded trip, sorted by cord id."
  @spec trips() :: [trip()]
  def trips do
    if table_alive?() do
      @table |> :ets.tab2list() |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.cord_id)
    else
      []
    end
  end

  # -- helpers -----------------------------------------------------------------

  defp reason(detail) when is_binary(detail), do: detail

  defp reason(detail) when is_map(detail),
    do: detail[:reason] || detail["reason"] || "unspecified"

  defp digest(detail) when is_map(detail),
    do: detail[:receipt_digest] || detail["receipt_digest"]

  defp digest(_detail), do: nil

  # Andon is "running" iff its ETS table exists AND its owner process is
  # alive -- a dead owner with a leftover table is not a running Andon.
  defp table_alive? do
    case :ets.info(@table, :owner) do
      :undefined -> false
      pid -> Process.alive?(pid)
    end
  end
end
