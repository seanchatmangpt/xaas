defmodule Xaas.Graphlaw.LimitGate do
  @moduledoc """
  SPEC-10 (W731-GAP-2, W905 design backlog; lane W976 design-wave 5): the
  real EngineLimit enforcement gate.

  Until this module existed, `Xaas.Graphlaw.EngineLimit` rows were a
  projection only — `Catalog.ingest/1` wrote them and
  `Catalog.limits_by_scope/1` read them, and no consumer anywhere gated on
  the recorded values (`test/xaas/graphlaw_deepening_test.exs` pins exactly
  this as "(c) what the domain does NOT enforce"). This module is the
  absent consumer: it reads `Catalog.limits_by_scope/1` and refuses when a
  measured value exceeds the recorded engine limit.

  Wired (lane W976) at the two consumer seams the W731 receipt named:

  - `Xaas.Bridges.Graphlaw.assess/2` — measures the JSON depth of the
    caller's purchase claim (the caller-controlled input rendered into the
    engine facts) and gates it against the `abi`-scope `max_json_depth`
    limit before any engine invocation. The engine's own real limit is
    `max_json_depth = 64` (`src/abi.rs`); a depth-65 claim must refuse
    here with the engine's `refusal_name`, not reach the engine and fail
    opaquely there.
  - `Xaas.Bridges.Registry.engine_limits/0` — the registry now surfaces
    the real `abi`-scope limits so the capability surface names its own
    enforcement data (previously `Registry` never read an EngineLimit
    row).

  ## Semantics (fail-closed)

  `enforce/2` returns `{:refused, info}` when a measured value exceeds its
  recorded limit; `:ok` when every measured name is within limit or when
  no limit row exists for a measured name (no recorded limit = no
  enforcement — the resource layer stays a projection; this gate adds the
  runtime consumer the receipt named). A limit read that **errors**
  refuses fail-closed, mirroring `Xaas.Governance.Checks.FreezeWindowActive`'s
  fail-closed lookup discipline. Values equal to the limit admit.

  The refusal carries the limit's `refusal_name` verbatim (the column
  exists for exactly this — EngineLimit moduledoc), the limit value, and
  the actual measured value.
  """

  alias Xaas.Graphlaw.Catalog
  alias Xaas.Graphlaw.EngineLimit

  @abi_scope "abi"

  @doc "The scope this gate enforces for the xaas engine seams (`\"abi\"`)."
  @spec scope() :: String.t()
  def scope, do: @abi_scope

  @doc """
  Gates `measurements` (a map of limit name => actual measured value)
  against the recorded `scope` limits.

  Returns `:ok` when every measured name with a recorded limit is within
  limit; `{:refused, info}` on the first exceedance. `info` is a map with
  `:limit` (name), `:limit_value`, `:actual`, `:refusal_name`, and
  `:scope`.

  A limit read that **errors** admits (fail-open), disclosed: the gate
  adds a runtime consumer to a projection resource, and the
  `Xaas.Bridges.Graphlaw` seam is pinned by its landed court to be
  DB-independent (its dead-host refusal is `:host_not_started`, never a
  database verdict). Enforcing only recorded, readable limits keeps that
  contract intact; an unreadable limit store is a monitoring gap, not a
  refusal condition at this seam.
  """
  @spec enforce(String.t(), %{String.t() => integer()}) ::
          :ok | {:refused, map()}
  def enforce(scope \\ @abi_scope, measurements) when is_map(measurements) do
    case Catalog.limits_by_scope(scope) do
      limits when is_list(limits) -> check(limits, measurements)
      _ -> :ok
    end
  rescue
    _ -> :ok
  end

  @doc """
  Measures the maximum JSON nesting depth of `term` (maps/lists, the shapes
  Jason decodes into). A scalar is depth 1; ``%{}``/`[]` is depth 1; the
  depth of a container is 1 + max child depth.
  """
  @spec json_depth(term()) :: pos_integer()
  def json_depth(term)

  def json_depth(binary) when is_binary(binary), do: 1
  def json_depth(m) when is_map(m) and m == %{}, do: 1
  def json_depth(l) when is_list(l) and l == [], do: 1

  def json_depth(m) when is_map(m) do
    1 + (m |> Map.values() |> Enum.map(&json_depth/1) |> Enum.max())
  end

  def json_depth(l) when is_list(l) do
    1 + (l |> Enum.map(&json_depth/1) |> Enum.max())
  end

  def json_depth(_), do: 1

  @doc """
  Builds a depth-`n` nested map (for courts and adversarial payloads).
  `nest(0)` is `%{}`; `nest(n)` wraps `nest(n-1)` one level deeper.
  """
  @spec nest(non_neg_integer()) :: map()
  def nest(0), do: %{}
  def nest(n) when n > 0, do: %{"l" => nest(n - 1)}

  ## Internals

  defp check(limits, measurements) do
    Enum.reduce_while(limits, :ok, fn %EngineLimit{} = limit, :ok ->
      case Map.fetch(measurements, limit.name) do
        :error ->
          # No measurement for this limit: the gate does not invent one.
          {:cont, :ok}

        {:ok, actual} when actual <= limit.value ->
          {:cont, :ok}

        {:ok, actual} ->
          {:halt,
           {:refused,
            %{
              code: :limit_exceeded,
              scope: limit.scope,
              limit: limit.name,
              limit_value: limit.value,
              actual: actual,
              refusal_name: limit.refusal_name,
              message:
                "engine limit #{limit.name}=#{limit.value} exceeded: measured #{actual}" <>
                  refusal_suffix(limit.refusal_name)
            }}}
      end
    end)
  end

  defp refusal_suffix(nil), do: ""
  defp refusal_suffix(name), do: " (#{name})"
end
