defmodule Xaas.A2a.Catalog do
  @moduledoc """
  Context over the A2A agent-card projection (`Xaas.A2a.Agent`,
  `Xaas.A2a.Task`).

  `ingest/1` accepts any of:

    * a file path (binary containing a path to a real served card file),
    * a raw card JSON binary,
    * an already-decoded card map,

  and upserts one `Agent` per card. Accepts both wire (camelCase:
  `supportedInterfaces`, `inputModes`) and snake_case key shapes, matching
  `AshA2A.Protocol.AgentCard`'s struct surface. Upsert is keyed on `name`,
  so re-ingesting the same card is idempotent. Malformed input produces a
  typed `{:error, %Xaas.A2a.Catalog.Error{}}`, never an exception crossing
  the boundary.
  """

  require Ash.Query

  alias Xaas.A2a.Agent
  alias Xaas.A2a.Task

  defmodule Error do
    @moduledoc "Typed agent-card ingest error."
    defexception([:reason, :detail])

    @type t :: %__MODULE__{reason: :invalid_json | :invalid_card, detail: term}

    def message(%__MODULE__{reason: reason, detail: detail}) do
      "agent-card ingest refused (#{reason}): #{inspect(detail)}"
    end
  end

  @doc "All ingested agents, ordered by name."
  @spec list_agents() :: [Agent.t()]
  def list_agents do
    Agent
    |> Ash.Query.sort(:name)
    |> Ash.read!(authorize?: false)
  end

  @doc "Fetch one agent by card name (primary key). Raises when absent."
  @spec get_agent!(String.t()) :: Agent.t()
  def get_agent!(name), do: Ash.get!(Agent, name, authorize?: false)

  @doc """
  Case-insensitive search for agents whose skills mention `term` — matching
  against skill `id`, `name`, `description`, and `tags`.
  """
  @spec search_by_skill(String.t()) :: [Agent.t()]
  def search_by_skill(term) when is_binary(term) do
    needle = String.downcase(term)

    list_agents()
    |> Enum.filter(fn agent ->
      Enum.any?(agent.skills, fn skill ->
        fields = [
          skill["id"],
          skill["name"],
          skill["description"],
          skill["tags"]
        ]

        Enum.any?(fields, fn
          nil -> false
          binary when is_binary(binary) -> String.contains?(String.downcase(binary), needle)
          tags when is_list(tags) -> Enum.any?(tags, &tag_matches?(&1, needle))
        end)
      end)
    end)
  end

  defp tag_matches?(tag, needle) when is_binary(tag),
    do: String.contains?(String.downcase(tag), needle)

  defp tag_matches?(_, _), do: false

  @doc "All tasks for one agent (by card name), ordered by task_id."
  @spec tasks_for_agent(String.t()) :: [Task.t()]
  def tasks_for_agent(agent_id) do
    Task
    |> Ash.Query.filter(agent_id == ^agent_id)
    |> Ash.Query.sort(:task_id)
    |> Ash.read!(authorize?: false)
  end

  @doc "Create a task bound to an agent."
  @spec create_task(map()) :: Task.t()
  def create_task(attrs) do
    Task
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  @doc """
  Ingest an agent card (path | raw JSON binary | decoded map). Returns
  `{:ok, count}` of agents now in the projection.
  """
  @spec ingest(String.t() | map()) :: {:ok, non_neg_integer()} | {:error, Error.t()}
  def ingest(path) when is_binary(path) do
    if File.regular?(path) do
      with {:ok, body} <- File.read(path), do: ingest(body)
    else
      ingest_as_json(path)
    end
  end

  def ingest(%{"name" => _, "description" => _} = card) do
    with :ok <- validate_card(card) do
      upsert_agent!(card)
      {:ok, Enum.count(list_agents())}
    end
  end

  def ingest(other), do: {:error, %Error{reason: :invalid_card, detail: other}}

  defp ingest_as_json(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> ingest(decoded)
      {:error, reason} -> {:error, %Error{reason: :invalid_json, detail: reason}}
    end
  end

  # -- ingesters -------------------------------------------------------------

  defp validate_card(card) do
    if is_binary(card["name"]) and is_binary(card["description"]) and is_binary(card_url(card)) do
      :ok
    else
      {:error, %Error{reason: :invalid_card, detail: {:bad_field_types, card["name"]}}}
    end
  end

  # v1 wire cards may carry the endpoint only as `supportedInterfaces[0].url`
  # (the spec's own L1008 example does); accept a top-level `url` too.
  defp card_url(card) do
    case card_key(card, "url") do
      url when is_binary(url) ->
        url

      _ ->
        card
        |> interfaces()
        |> Enum.find_value(& &1["url"])
    end
  end

  defp upsert_agent!(card) do
    attrs = %{
      name: card["name"],
      url: card_url(card),
      description: card["description"],
      version: card_key(card, "version"),
      skills: skills(card),
      transport_bindings: interfaces(card)
    }

    case Ash.get(Agent, attrs.name, authorize?: false) do
      {:ok, existing} ->
        existing
        |> Ash.Changeset.for_update(:update, Map.delete(attrs, :name), authorize?: false)
        |> Ash.update!(authorize?: false)

      _ ->
        Agent
        |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
        |> Ash.create!(authorize?: false)
    end
  end

  # Cards on the wire are camelCase (`supportedInterfaces`); snake_case
  # (`supported_interfaces`) is accepted for struct-shaped input.
  defp card_key(card, key) do
    case Map.get(card, key) do
      nil -> Map.get(card, camelize(key))
      value -> value
    end
  end

  defp camelize(snake) do
    [first | rest] = String.split(snake, "_")
    String.downcase(first) <> Enum.map_join(rest, &String.capitalize/1)
  end

  defp skills(card), do: normalize_list(card_key(card, "skills"))

  defp interfaces(card) do
    card
    |> card_key("supported_interfaces")
    |> normalize_list()
    |> Enum.map(fn iface ->
      %{
        "url" => iface["url"],
        "protocolBinding" => iface["protocolBinding"] || iface["protocol_binding"],
        "protocolVersion" => iface["protocolVersion"] || iface["protocol_version"]
      }
    end)
  end

  defp normalize_list(nil), do: []
  defp normalize_list(list) when is_list(list), do: list
  defp normalize_list(_), do: []
end
