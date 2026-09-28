defmodule Xaas.Ultracode.Frontier do
  @moduledoc """
  Canonical runtime frontier snapshot for one Ultracode Run.

  The frontier is evidence about remaining executable work, not authority.
  A frontier-governed cycle horizon may close only when every closure count
  is observed as zero. Missing frontier evidence is UNKNOWN and must never be
  interpreted as an empty queue. Other Run lifecycle owners (for example a
  duration-budget session or an Autonomic item attempt) retain their own
  explicit terminal laws.
  """

  @schema "xaas.ultracode.frontier/1"
  @count_keys ~w(
    pending_work
    active_epochs
    unsettled_epochs
    unpublished_deltas
    unsatisfied_dependencies
  )

  @spec empty(String.t()) :: map()
  def empty(source \\ "runtime") do
    %{
      "schema" => @schema,
      "source" => source,
      "pending_work" => 0,
      "active_epochs" => 0,
      "unsettled_epochs" => 0,
      "unpublished_deltas" => 0,
      "unsatisfied_dependencies" => 0,
      "next_work_item" => nil,
      "metadata" => %{}
    }
    |> attach_digest()
  end

  @spec admit(map()) :: {:ok, map()} | {:error, term()}
  def admit(input) when is_map(input) do
    input = stringify_keys(input)

    snapshot = %{
      "schema" => Map.get(input, "schema", @schema),
      "source" => Map.get(input, "source", "runtime"),
      "pending_work" => Map.get(input, "pending_work"),
      "active_epochs" => Map.get(input, "active_epochs"),
      "unsettled_epochs" => Map.get(input, "unsettled_epochs"),
      "unpublished_deltas" => Map.get(input, "unpublished_deltas"),
      "unsatisfied_dependencies" => Map.get(input, "unsatisfied_dependencies"),
      "next_work_item" => Map.get(input, "next_work_item"),
      "metadata" => Map.get(input, "metadata", %{})
    }

    with :ok <- require_schema(snapshot),
         :ok <- require_source(snapshot),
         :ok <- require_counts(snapshot),
         :ok <- require_metadata(snapshot) do
      {:ok, attach_digest(snapshot)}
    end
  end

  def admit(_), do: {:error, :frontier_not_a_map}

  @spec from_run(struct()) :: {:ok, map()} | {:error, term()}
  def from_run(%{frontier_recorded_at: nil}), do: {:error, :frontier_unknown}

  def from_run(%{frontier: frontier, frontier_digest: expected, frontier_size: size})
      when is_map(frontier) and is_binary(expected) do
    with {:ok, snapshot} <- admit(frontier),
         true <- snapshot["digest"] == expected or {:error, :frontier_digest_mismatch},
         true <- snapshot["pending_work"] == size or {:error, :frontier_size_mismatch} do
      {:ok, snapshot}
    end
  end

  def from_run(_), do: {:error, :frontier_unknown}

  @spec closed?(map()) :: boolean()
  def closed?(snapshot) do
    Enum.all?(@count_keys, &(Map.get(snapshot, &1) == 0))
  end

  @spec digest(map()) :: String.t()
  def digest(snapshot) do
    payload =
      snapshot
      |> Map.drop(["digest"])
      |> canonical()
      |> Jason.encode!()

    "sha256:" <> (:crypto.hash(:sha256, payload) |> Base.encode16(case: :lower))
  end

  defp attach_digest(snapshot), do: Map.put(snapshot, "digest", digest(snapshot))

  defp require_schema(%{"schema" => @schema}), do: :ok
  defp require_schema(%{"schema" => other}), do: {:error, {:frontier_schema, other}}

  defp require_source(%{"source" => value})
       when is_binary(value) and byte_size(value) > 0,
       do: :ok

  defp require_source(_), do: {:error, :frontier_source}

  defp require_counts(snapshot) do
    case Enum.find(@count_keys, fn key ->
           value = Map.get(snapshot, key)
           not (is_integer(value) and value >= 0)
         end) do
      nil -> :ok
      key -> {:error, {:frontier_count, key, Map.get(snapshot, key)}}
    end
  end

  defp require_metadata(%{"metadata" => value}) when is_map(value), do: :ok
  defp require_metadata(_), do: {:error, :frontier_metadata}

  defp stringify_keys(map) do
    Map.new(map, fn {key, value} -> {to_string(key), value} end)
  end

  defp canonical(%{} = map) do
    map
    |> Enum.map(fn {key, value} -> [to_string(key), canonical(value)] end)
    |> Enum.sort_by(&hd/1)
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(value) when is_atom(value), do: Atom.to_string(value)
  defp canonical(value), do: value
end
