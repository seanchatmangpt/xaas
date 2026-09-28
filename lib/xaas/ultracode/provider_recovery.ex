defmodule Xaas.Ultracode.ProviderRecovery do
  @moduledoc """
  Runtime provider recovery for the UltraCode execution fabric: a typed
  failure classifier plus a per-provider circuit breaker.

  `Xaas.Ultracode.ProviderHealth` is static preflight only (is the CLI
  installed, is node resolvable). This module is the RUNTIME half: every
  real `Xaas.Ultracode.Dispatch` outcome is `record/2`ed here, classified by
  `classify/1` into one typed failure class, and folded into a per-provider
  breaker:

      :closed --N consecutive breaker-class failures--> :open
      :open   --backoff elapsed-------------------------> :half_open (probe)
      :half_open --success--> :closed
      :half_open --failure--> :open (backoff doubled, capped)

  Configuration (Application env, overridable per server via `start_link/1`
  opts):

    * `:ultracode_provider_breaker_threshold` (default 3) -- consecutive
      breaker-class failures that open a closed breaker;
    * `:ultracode_provider_breaker_base_ms` (default 60_000) -- first open
      backoff; each half-open failure doubles it, capped at 30 minutes.

  Reads (`state/2`, `available?/2`, `snapshot/1`) hit a public ETS table and
  never call the server, so a selection path never blocks on it. When the
  server is not running every read answers "closed / available" -- recovery
  is an optimization over dispatch, never a new single point of failure.

  Every state change emits the telemetry event
  `[:xaas, :ultracode, :provider_recovery, :transition]` with measurements
  `%{count: 1}` and metadata `%{provider, from, to, class}`.

  The clock is injectable (`now_ms: (-> integer())`) -- a real function
  argument, so tests drive breaker time deterministically without mocks.
  """

  use GenServer

  @type class ::
          :rate_limited
          | :overloaded
          | :auth
          | :malformed
          | :unavailable
          | :crash
          | :timeout
          | :ok

  @type breaker_state :: :closed | :open | :half_open

  @default_threshold 3
  @default_base_ms 60_000
  @cap_ms 30 * 60 * 1000

  # Classes that count toward opening the breaker. `:malformed` is a
  # request-side defect (bad epoch, bad opts): the provider did nothing
  # wrong, so it neither opens nor closes the breaker.
  @breaker_classes [:rate_limited, :overloaded, :auth, :unavailable, :crash, :timeout]

  @overloaded_regex ~r/High concurrency usage/i
  # Same families as Dispatch's @failover_regex (verbatim from
  # scripts/xaas-glm-failover-dispatcher.sh) plus a bare GLM 1302 code.
  @rate_regex ~r/"code"\s*:\s*"?1302|\b1302\b|HTTP 429|status(Code)?[": ]+429|Too Many Requests/
  @auth_regex ~r/\bHTTP 40[13]\b|status(Code)?[": ]+40[13]\b|"code"\s*:\s*"?40[13]\b|\b40[13]\b|invalid[ _-]?api[ _-]?key|\bUnauthorized\b|\bForbidden\b/i

  @event [:xaas, :ultracode, :provider_recovery, :transition]

  @doc "The telemetry event name emitted on every breaker transition."
  @spec event() :: [atom()]
  def event, do: @event

  @doc "Failure classes that advance the breaker toward `:open`."
  @spec breaker_classes() :: [class()]
  def breaker_classes, do: @breaker_classes

  # ------------------------------------------------------------------
  # Classification (pure)
  # ------------------------------------------------------------------

  @doc """
  Maps a `Dispatch` result, a `Dispatch.autonomic_worker/2` return, an
  error tuple, or raw provider output text to one typed class.

      iex> Xaas.Ultracode.ProviderRecovery.classify({:ok, %{status: :ok, output_tail: "done"}})
      :ok

      iex> Xaas.Ultracode.ProviderRecovery.classify("Too Many Requests (HTTP 429)")
      :rate_limited

      iex> Xaas.Ultracode.ProviderRecovery.classify(~s({"error":{"code":"1302","message":"High concurrency usage of this API"}}))
      :overloaded

      iex> Xaas.Ultracode.ProviderRecovery.classify({:error, {:spawn_failed, "enoent"}})
      :unavailable

      iex> Xaas.Ultracode.ProviderRecovery.classify({:ok, %{status: :timeout, output_tail: ""}})
      :timeout
  """
  @spec classify(term()) :: class()
  def classify({:ok, %{status: status} = result}),
    do: classify_status(status, Map.get(result, :output_tail, ""))

  def classify(%{status: status} = result),
    do: classify_status(status, Map.get(result, :output_tail, ""))

  def classify(:ok), do: :ok
  def classify(:rate_limited), do: :rate_limited
  def classify(:timeout), do: :timeout

  def classify({:error, {:spawn_failed, _}}), do: :unavailable
  def classify({:error, {:node_unavailable, _}}), do: :unavailable
  def classify({:error, {:dispatch_crashed, _}}), do: :crash
  def classify({:error, {:dispatch_timeout, _}}), do: :timeout

  def classify({:error, {:dispatch_failed, _code, tail}}) when is_binary(tail),
    do: classify_status(:failed, tail)

  def classify({:error, _other}), do: :malformed

  def classify(text) when is_binary(text) do
    case text_class(text) do
      nil -> :ok
      class -> class
    end
  end

  def classify(_other), do: :malformed

  defp classify_status(:ok, _tail), do: :ok
  defp classify_status(:timeout, _tail), do: :timeout

  defp classify_status(:rate_limited, tail) do
    if is_binary(tail) and Regex.match?(@overloaded_regex, tail),
      do: :overloaded,
      else: :rate_limited
  end

  defp classify_status(:failed, tail) when is_binary(tail), do: text_class(tail) || :crash
  defp classify_status(:failed, _tail), do: :crash
  defp classify_status(_unknown, _tail), do: :malformed

  defp text_class(text) do
    cond do
      Regex.match?(@overloaded_regex, text) -> :overloaded
      Regex.match?(@rate_regex, text) -> :rate_limited
      Regex.match?(@auth_regex, text) -> :auth
      true -> nil
    end
  end

  # ------------------------------------------------------------------
  # Server
  # ------------------------------------------------------------------

  @doc """
  Starts the recovery server. Opts: `:name` (atom, default `__MODULE__`;
  also names the ETS table), `:now_ms` (0-arity clock, default monotonic
  ms), `:threshold`, `:base_ms`, `:cap_ms`.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, Keyword.put(opts, :name, name), name: name)
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc """
  Records one dispatch outcome for `provider`. Classifies it and advances
  the breaker. Returns the provider's breaker state after the record, or
  `:not_running` when the server is absent (never raises).
  """
  @spec record(String.t(), term(), atom()) :: breaker_state() | :not_running
  def record(provider, result, server \\ __MODULE__) when is_binary(provider) do
    if Process.whereis(server) do
      GenServer.call(server, {:record, provider, classify(result)})
    else
      :not_running
    end
  catch
    :exit, _ -> :not_running
  end

  @doc """
  The effective breaker state of `provider`: an `:open` breaker whose
  backoff has elapsed reads as `:half_open`. Unknown providers and an
  absent server read `:closed`.
  """
  @spec state(String.t(), atom()) :: breaker_state()
  def state(provider, server \\ __MODULE__) do
    case lookup(server, provider) do
      {entry, clock} -> effective(entry, clock.())
      nil -> :closed
    end
  end

  @doc "True unless `provider`'s breaker is `:open` (half-open admits a probe)."
  @spec available?(String.t(), atom()) :: boolean()
  def available?(provider, server \\ __MODULE__), do: state(provider, server) != :open

  @doc "Every tracked provider's breaker record, with effective state."
  @spec snapshot(atom()) :: %{String.t() => map()}
  def snapshot(server \\ __MODULE__) do
    case table_clock(server) do
      nil ->
        %{}

      clock ->
        now = clock.()

        server
        |> :ets.tab2list()
        |> Enum.flat_map(fn
          {{:provider, provider}, entry} ->
            [{provider, Map.put(entry, :state, effective(entry, now))}]

          _ ->
            []
        end)
        |> Map.new()
    end
  rescue
    ArgumentError -> %{}
  end

  defp lookup(server, provider) do
    case table_clock(server) do
      nil ->
        nil

      clock ->
        case :ets.lookup(server, {:provider, provider}) do
          [{_, entry}] -> {entry, clock}
          [] -> nil
        end
    end
  rescue
    ArgumentError -> nil
  end

  defp table_clock(server) do
    if is_atom(server) and :ets.whereis(server) != :undefined do
      case :ets.lookup(server, :clock) do
        [{:clock, clock}] -> clock
        [] -> nil
      end
    end
  end

  defp effective(%{state: :open, open_until: until}, now) when now >= until, do: :half_open
  defp effective(%{state: state}, _now), do: state

  @impl true
  def init(opts) do
    name = Keyword.fetch!(opts, :name)
    clock = Keyword.get(opts, :now_ms, fn -> System.monotonic_time(:millisecond) end)

    table = :ets.new(name, [:named_table, :set, :protected, read_concurrency: true])
    :ets.insert(table, {:clock, clock})

    {:ok,
     %{
       table: table,
       clock: clock,
       threshold:
         Keyword.get_lazy(opts, :threshold, fn ->
           Application.get_env(:xaas, :ultracode_provider_breaker_threshold, @default_threshold)
         end),
       base_ms:
         Keyword.get_lazy(opts, :base_ms, fn ->
           Application.get_env(:xaas, :ultracode_provider_breaker_base_ms, @default_base_ms)
         end),
       cap_ms: Keyword.get(opts, :cap_ms, @cap_ms)
     }}
  end

  @impl true
  def handle_call({:record, provider, class}, _from, s) do
    now = s.clock.()

    entry =
      case :ets.lookup(s.table, {:provider, provider}) do
        [{_, entry}] -> entry
        [] -> fresh(s)
      end

    # Materialize an elapsed backoff as the half-open probe window first.
    entry =
      if entry.state == :open and now >= entry.open_until do
        transition(provider, entry, :half_open, class)
      else
        entry
      end

    next = step(entry, class, now, s)
    next = if next.state != entry.state, do: transition(provider, entry, next, class), else: next
    next = Map.merge(next, %{last_class: class, last_at: now})

    :ets.insert(s.table, {{:provider, provider}, next})
    {:reply, next.state, s}
  end

  defp fresh(s),
    do: %{state: :closed, failures: 0, backoff_ms: s.base_ms, open_until: nil, last_class: nil}

  # :malformed -- request-side defect, no breaker movement.
  defp step(entry, :malformed, _now, _s), do: entry

  defp step(entry, :ok, _now, s),
    do: %{entry | state: :closed, failures: 0, backoff_ms: s.base_ms, open_until: nil}

  defp step(%{state: :closed} = entry, class, now, s) when class in @breaker_classes do
    failures = entry.failures + 1

    if failures >= s.threshold do
      %{
        entry
        | state: :open,
          failures: failures,
          backoff_ms: s.base_ms,
          open_until: now + s.base_ms
      }
    else
      %{entry | failures: failures}
    end
  end

  defp step(%{state: :half_open} = entry, class, now, s) when class in @breaker_classes do
    backoff = min(entry.backoff_ms * 2, s.cap_ms)

    %{
      entry
      | state: :open,
        failures: entry.failures + 1,
        backoff_ms: backoff,
        open_until: now + backoff
    }
  end

  defp step(%{state: :open} = entry, class, _now, _s) when class in @breaker_classes,
    do: %{entry | failures: entry.failures + 1}

  defp transition(provider, from, to, class) when is_atom(to),
    do: transition(provider, from, %{from | state: to}, class)

  defp transition(provider, from, %{state: to} = next, class) do
    :telemetry.execute(@event, %{count: 1}, %{
      provider: provider,
      from: from.state,
      to: to,
      class: class
    })

    next
  end
end
