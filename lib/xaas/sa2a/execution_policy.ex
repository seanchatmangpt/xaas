defmodule Xaas.Sa2a.ExecutionPolicy do
  @moduledoc """
  Machine admission policy for the SA2A `sa2a_execute` DO edge.

  Replaces the human "may this run?" decision with a declared, testable allowlist. The
  policy is data (`config :xaas, Xaas.Sa2a.ExecutionPolicy`), read by
  `Xaas.Sa2a.Court`; an absent or empty policy admits nothing (deny by default).

      config :xaas, Xaas.Sa2a.ExecutionPolicy,
        classes: [
          %{id: "workorder-resolution", match: {:prefix, "workorder:"},
            bind_work_order: true, max_query_bytes: 512}
        ],
        admitted_standings: ["KNOWN"],
        min_llm_avoidance_ratio: 1.0,
        max_compiled_rules: 64

  A query is admitted only if it matches one declared class (`{:exact, [q]}`,
  `{:prefix, p}`, or `{:regex, source}`); `bind_work_order: true` additionally requires
  the query text to name the work order under execution. `min_llm_avoidance_ratio: 1.0`
  refuses any result the port had to resolve through its LLM-fallback path.
  """

  @type class :: %{
          required(:id) => String.t(),
          required(:match) =>
            {:exact, [String.t()]} | {:prefix, String.t()} | {:regex, String.t()},
          optional(:bind_work_order) => boolean(),
          optional(:max_query_bytes) => pos_integer()
        }

  @type t :: %{
          classes: [class()],
          admitted_standings: [String.t()],
          min_llm_avoidance_ratio: number(),
          max_compiled_rules: non_neg_integer()
        }

  @defaults %{
    classes: [],
    admitted_standings: ["KNOWN"],
    min_llm_avoidance_ratio: 1.0,
    max_compiled_rules: 64
  }

  @doc "The configured policy merged over the deny-by-default defaults."
  @spec config() :: t()
  def config, do: :xaas |> Application.get_env(__MODULE__, []) |> normalize()

  @spec normalize(keyword() | map()) :: t()
  def normalize(policy) when is_list(policy), do: policy |> Map.new() |> normalize()
  def normalize(policy) when is_map(policy), do: Map.merge(@defaults, policy)

  @doc """
  Admits `query` for `work_order_id` under `policy`, returning the matching class.

  Unknown or malformed queries are a typed refusal, never a crash.
  """
  @spec admit_query(term(), String.t(), t()) ::
          {:ok, class()} | {:error, {:refused, atom(), term()}}
  def admit_query(query, work_order_id, policy \\ config())

  def admit_query(query, work_order_id, policy) when is_binary(query) do
    policy = normalize(policy)

    case Enum.find(policy.classes, &class_matches?(&1, query)) do
      nil ->
        {:error, {:refused, :query_not_allowlisted, query}}

      class ->
        cond do
          byte_size(query) > Map.get(class, :max_query_bytes, 512) ->
            {:error, {:refused, :query_too_long, byte_size(query)}}

          Map.get(class, :bind_work_order, true) and not String.contains?(query, work_order_id) ->
            {:error, {:refused, :query_not_bound_to_work_order, work_order_id}}

          true ->
            {:ok, class}
        end
    end
  end

  def admit_query(query, _work_order_id, _policy),
    do: {:error, {:refused, :query_not_allowlisted, query}}

  defp class_matches?(%{match: {:exact, queries}}, query), do: query in queries
  defp class_matches?(%{match: {:prefix, prefix}}, query), do: String.starts_with?(query, prefix)

  defp class_matches?(%{match: {:regex, source}}, query) do
    case Regex.compile(source) do
      {:ok, regex} -> Regex.match?(regex, query)
      {:error, _} -> false
    end
  end

  defp class_matches?(_class, _query), do: false
end
