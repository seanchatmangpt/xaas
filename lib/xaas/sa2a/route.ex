defmodule Xaas.Sa2a.Route do
  @moduledoc """
  G5 SA2A conservation (GC-FRI-0800): one work-order tuple, three hops.

  A work order crosses three representations on its way to execution:

    1. the sJira work order -- a `wo.json` row (snake_case) carrying the
       GC-FRI-0800 tuple fields (`postcondition`, `requires_capability`,
       `exclusions`, `consequence_class`, ...);
    2. the SA2A task -- the map `GgenIgniter.SemanticA2A.task_from_work_order/2`
       returns, whose `input` carries one data part with schema
       `"semantic-jira/route-tuple/v1"` holding the tuple in A2A camelCase;
    3. the XaaS semantic epoch contract -- a descriptor that
       `Xaas.Ultracode.SemanticWork.admit/1` admits, carrying the tuple in its
       opaque `bridge` object (next to the bridge's existing `subject` and
       `evidence_ceiling`).

  `tuple/1` normalizes each representation to the vocabulary-contract tuple
  (string keys, exactly `fields/0`); `digest/1` is the contract's tuple digest:
  `"sha256:" <> hex(sha256(canonical JSON))`, canonical JSON being the tuple
  as one JSON object with sorted keys, compact separators, UTF-8 unescaped and
  `exclusions` sorted -- the same bytes as Python's
  `json.dumps(t, sort_keys=True, separators=(",", ":"), ensure_ascii=False)`.

  `conserve/3` admits a route only when the three digests are equal; any
  difference is refused as `broken_term: "admission_vacuous"` naming the first
  differing contract field, because a hop that changed the tuple would make the
  upstream admission say nothing about what executes.

  `resolve/1` maps a capability id (`"recipe:<id>"`) to its provider through
  the `config :xaas, :ultracode_construction_recipes` registry (read-only).
  Nothing here grants authority, selects frontier, or actuates.

  Capability typing is the open `sj:capabilityId` form `provider:id`, not the
  closed GALL vocabulary `AshA2A.Gall.Capability` (Read, Write, Edit, Commit,
  Push, Publish, Deploy, Merge). The two are disjoint: GALL refuses every
  `provider:id` name (`decode("recipe:mix-format") == :error`, ash_a2a
  26.9.21), and a GALL label is refused here as a capability id. The ash_a2a
  xaas pins (26.9.12) does not ship `AshA2A.Gall` at all. What a recipe may
  do in GALL terms (requires/forbids) belongs to its registry entry, not to
  the conserved tuple.
  """

  alias Xaas.Ultracode.SemanticWork

  @fields ~w(subject postcondition capability evidence_ceiling authority_ceiling consequence_class exclusions)

  @route_schema "semantic-jira/route-tuple/v1"

  # Receipt-class vocabulary, mirrored from ggen_igniter
  # `GgenIgniter.SemanticJira.receipt_classes/0` (lib/ggen_igniter/semantic_jira.ex).
  @consequence_classes ~w(manufacture projection authority_preparation actuation verification postcondition replay publication deployment)

  # `sj:capabilityId` shape, e.g. "recipe:mix-format" (provider:id).
  @capability ~r/\A([a-z0-9][a-z0-9_.-]*):([a-z0-9][a-z0-9_.:-]*)\z/

  @snake_keys %{
    "subject" => "subject",
    "postcondition" => "postcondition",
    "capability" => "requires_capability",
    "evidence_ceiling" => "evidence_ceiling",
    "authority_ceiling" => "authority_ceiling",
    "consequence_class" => "consequence_class",
    "exclusions" => "exclusions"
  }

  @task_keys %{
    "subject" => "subject",
    "postcondition" => "postcondition",
    "capability" => "requiresCapability",
    "evidence_ceiling" => "evidenceCeiling",
    "authority_ceiling" => "authorityCeiling",
    "consequence_class" => "consequenceClass",
    "exclusions" => "exclusions"
  }

  @type field :: String.t()
  @type route_tuple :: %{required(String.t()) => String.t() | [String.t()]}
  @type hop :: :order | :task | :epoch
  @type tuple_refusal ::
          {:missing_field, field()}
          | {:invalid_field, field()}
          | {:ambiguous_tuple_carrier, pos_integer()}
          | {:epoch_contract, term()}
          | :unrecognized_representation

  @doc "The vocabulary-contract tuple fields, in comparison order."
  @spec fields() :: [field()]
  def fields, do: @fields

  @doc "The data-part schema that carries the tuple inside an SA2A task."
  @spec route_schema() :: String.t()
  def route_schema, do: @route_schema

  @doc """
  Normalizes an sJira work order, an SA2A task, or a XaaS epoch contract to the
  contract tuple. The representation is recognized by shape: `"taskId"` marks
  an SA2A task, `work_order_iri` an epoch contract, `subject` a work order.
  """
  @spec tuple(term()) :: {:ok, route_tuple()} | {:refused, tuple_refusal()}
  def tuple(representation) do
    case kind(representation) do
      {:ok, hop} -> tuple(hop, representation)
      :error -> {:refused, :unrecognized_representation}
    end
  end

  @doc "Normalizes `representation` read as the given hop's representation."
  @spec tuple(hop(), term()) :: {:ok, route_tuple()} | {:refused, tuple_refusal()}
  def tuple(:order, %{} = order) when not is_struct(order),
    do: order |> string_keys() |> project(@snake_keys)

  def tuple(:task, %{} = task) when not is_struct(task) do
    with {:ok, carried} <- task_tuple(string_keys(task)) do
      project(carried, @task_keys)
    end
  end

  def tuple(:epoch, %{} = epoch) when not is_struct(epoch) do
    with {:ok, admitted} <- admit_epoch(epoch),
         {:ok, bridge} <- epoch_capability(admitted) do
      project(bridge, @snake_keys)
    end
  end

  def tuple(hop, _other) when hop in [:order, :task, :epoch],
    do: {:refused, :unrecognized_representation}

  @doc """
  The contract tuple digest: `"sha256:" <> lowercase hex` over the canonical
  JSON of exactly the contract fields (sorted keys, compact, exclusions sorted).
  """
  @spec digest(route_tuple()) :: String.t()
  def digest(%{} = route_tuple) do
    tuple = string_keys(route_tuple)

    encoded =
      @fields
      |> Enum.map(fn
        "exclusions" = field -> {field, tuple |> Map.fetch!(field) |> Enum.sort()}
        field -> {field, Map.fetch!(tuple, field)}
      end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Jason.OrderedObject.new()
      |> Jason.encode!()

    "sha256:" <> (:crypto.hash(:sha256, encoded) |> Base.encode16(case: :lower))
  end

  @doc """
  Resolves a capability id (or a contract tuple carrying one) to its provider.

  Only `recipe:<id>` capabilities resolve, and only when the
  `:ultracode_construction_recipes` registry holds an entry for them. The
  registry may be a map or a list; an entry matches when its key is the full
  capability id or the bare recipe id, or when its value is a map whose
  `capability_id` is the capability id. The recipe id returned is the entry
  value's `id` when present, otherwise the bare recipe id.
  """
  @spec resolve(String.t() | route_tuple()) ::
          {:ok, {String.t(), String.t()}} | {:refused, :unregistered_capability}
  def resolve(%{} = route_tuple) when not is_struct(route_tuple),
    do: route_tuple |> string_keys() |> Map.get("capability") |> resolve()

  def resolve(capability_id) when is_binary(capability_id) do
    with [_, "recipe", recipe] <- Regex.run(@capability, capability_id),
         {:ok, recipe_id} <- lookup(registry(), capability_id, recipe) do
      {:ok, {"recipe", recipe_id}}
    else
      _ -> {:refused, :unregistered_capability}
    end
  end

  def resolve(_other), do: {:refused, :unregistered_capability}

  @doc """
  Admits the route only when the work order, the SA2A task and the XaaS epoch
  contract normalize to tuples with one digest.

  Returns `:ok`, or `{:refused, %{broken_term: "admission_vacuous", field: f}}`
  naming the first contract field (in `fields/0` order) that differs across the
  hops or that a hop drops or malforms. A representation that is not the
  expected hop, or an epoch contract `SemanticWork.admit/1` refuses, is refused
  with its own `broken_term` and the `hop`.
  """
  @spec conserve(map(), map(), map()) :: :ok | {:refused, map()}
  def conserve(order, task, epoch) do
    with {:ok, order_tuple} <- hop(:order, order),
         {:ok, task_tuple} <- hop(:task, task),
         {:ok, epoch_tuple} <- hop(:epoch, epoch) do
      tuples = [order_tuple, task_tuple, epoch_tuple]

      if tuples |> Enum.map(&digest/1) |> Enum.uniq() |> length() == 1 do
        :ok
      else
        field =
          Enum.find(@fields, fn f -> tuples |> Enum.map(& &1[f]) |> Enum.uniq() |> tl() != [] end)

        {:refused, %{broken_term: "admission_vacuous", field: field}}
      end
    end
  end

  # -- internals -------------------------------------------------------------

  defp hop(hop, representation) do
    case tuple(hop, representation) do
      {:ok, tuple} ->
        {:ok, tuple}

      {:refused, {kind, field}} when kind in [:missing_field, :invalid_field] ->
        {:refused, %{broken_term: "admission_vacuous", field: field}}

      {:refused, {:epoch_contract, reason}} ->
        {:refused, %{broken_term: "epoch_contract_refused", hop: hop, reason: reason}}

      {:refused, {:ambiguous_tuple_carrier, count}} ->
        {:refused, %{broken_term: "ambiguous_tuple_carrier", hop: hop, reason: count}}

      {:refused, :unrecognized_representation} ->
        {:refused, %{broken_term: "unrecognized_representation", hop: hop}}
    end
  end

  # `SemanticWork.admit/1` admits the executed `capability` against the same
  # canonical `sj:capabilityId` pattern this module types the tuple with
  # (FRI-T2's optional_capability, merged after FRI-T4). Its refusal of that
  # one field IS this contract's invalid capability field -- reported as
  # `{:invalid_field, "capability"}` like at every other hop, not as an
  # opaque epoch-contract refusal. Every other admission refusal stays
  # `{:epoch_contract, reason}`.
  defp admit_epoch(epoch) do
    case SemanticWork.admit(epoch) do
      {:ok, admitted} ->
        {:ok, admitted}

      {:error, {:refused_semantic_work, {:invalid, :capability}}} ->
        {:refused, {:invalid_field, "capability"}}

      {:error, reason} ->
        {:refused, {:epoch_contract, reason}}
    end
  end

  # The epoch hop's capability is the descriptor's top-level `capability` (the
  # `sj:capabilityId` the recipe worker resolves and executes); a descriptor
  # without one may carry it as the bridge's `requires_capability`. When both
  # are present they must agree, or the hop carries two capabilities.
  defp epoch_capability(admitted) do
    bridge = admitted |> Map.get(:bridge) |> string_keys()
    top = Map.get(admitted, :capability, Map.get(admitted, "capability"))

    case {top, Map.get(bridge, "requires_capability")} do
      {nil, _carried} -> {:ok, bridge}
      {top, nil} -> {:ok, Map.put(bridge, "requires_capability", top)}
      {same, same} -> {:ok, bridge}
      {_top, _other} -> {:refused, {:invalid_field, "capability"}}
    end
  end

  defp kind(%{} = map) when not is_struct(map) do
    keys = map |> Map.keys() |> MapSet.new(&to_string/1)

    cond do
      MapSet.member?(keys, "taskId") -> {:ok, :task}
      MapSet.member?(keys, "work_order_iri") -> {:ok, :epoch}
      MapSet.member?(keys, "subject") -> {:ok, :order}
      true -> :error
    end
  end

  defp kind(_other), do: :error

  # The tuple rides in exactly one `"kind" => "data"` input part whose data
  # carries the route schema; a task without one carries no tuple at all.
  defp task_tuple(task) do
    carriers =
      task
      |> Map.get("input")
      |> List.wrap()
      |> Enum.map(&string_keys/1)
      |> Enum.filter(&(&1["kind"] == "data"))
      |> Enum.map(&string_keys(&1["data"]))
      |> Enum.filter(&(&1["schema"] == @route_schema))

    case carriers do
      [] -> {:ok, %{}}
      [carrier] -> {:ok, string_keys(carrier["tuple"])}
      many -> {:refused, {:ambiguous_tuple_carrier, length(many)}}
    end
  end

  defp project(source, keys) do
    Enum.reduce_while(@fields, {:ok, %{}}, fn field, {:ok, acc} ->
      case admit_field(field, Map.get(source, Map.fetch!(keys, field))) do
        {:ok, value} -> {:cont, {:ok, Map.put(acc, field, value)}}
        {:refused, _} = refused -> {:halt, refused}
      end
    end)
  end

  # sj:exclusion is 0..n: an absent list is the empty list.
  defp admit_field("exclusions", nil), do: {:ok, []}

  defp admit_field("exclusions", list) when is_list(list) do
    if Enum.all?(list, &nonempty?/1),
      do: {:ok, Enum.sort(list)},
      else: {:refused, {:invalid_field, "exclusions"}}
  end

  defp admit_field(field, nil), do: {:refused, {:missing_field, field}}

  defp admit_field("capability", %{} = capability) when not is_struct(capability),
    do: admit_field("capability", string_keys(capability)["capability_id"])

  defp admit_field("capability" = field, value) do
    if is_binary(value) and Regex.match?(@capability, value),
      do: {:ok, value},
      else: {:refused, {:invalid_field, field}}
  end

  defp admit_field("consequence_class" = field, value) do
    if value in @consequence_classes,
      do: {:ok, value},
      else: {:refused, {:invalid_field, field}}
  end

  defp admit_field(field, value) do
    if nonempty?(value), do: {:ok, value}, else: {:refused, {:invalid_field, field}}
  end

  defp nonempty?(value), do: is_binary(value) and String.trim(value) != ""

  defp registry, do: Application.get_env(:xaas, :ultracode_construction_recipes, %{})

  defp lookup(registry, capability_id, recipe) when is_map(registry) or is_list(registry) do
    registry
    |> Enum.map(&entry/1)
    |> Enum.find_value(:error, fn
      {key, value} when key in [capability_id, recipe] ->
        {:ok, entry_id(value) || recipe}

      {_key, %{} = value} ->
        if string_keys(value)["capability_id"] == capability_id,
          do: {:ok, entry_id(value) || recipe}

      _ ->
        nil
    end)
  end

  defp lookup(_registry, _capability_id, _recipe), do: :error

  defp entry({key, value}) when is_binary(key) or is_atom(key), do: {to_string(key), value}
  defp entry(%{} = value) when not is_struct(value), do: {nil, value}
  defp entry(_other), do: {nil, nil}

  defp entry_id(%{} = value) when not is_struct(value) do
    case string_keys(value)["id"] do
      id when is_binary(id) and id != "" -> id
      id when is_atom(id) and id not in [nil, true, false] -> Atom.to_string(id)
      _ -> nil
    end
  end

  defp entry_id(_value), do: nil

  defp string_keys(%{} = map) when not is_struct(map),
    do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp string_keys(_other), do: %{}
end
