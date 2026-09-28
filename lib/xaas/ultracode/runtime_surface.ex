defmodule Xaas.Ultracode.RuntimeSurface do
  @moduledoc """
  The UltraCode runtime surface law, compiled from the policy DATA
  `priv/ultracode/runtime_surface.json` (schema
  `xaas-ultracode-runtime-surface/v1`).

      ExternalSemanticPorts(UltraCode) = {SA2A, sJira}

  Local construction (filesystem, local shell, compiler, test runner,
  generator, local git) is a separate classified set. Every other external
  edge is refused with `{:forbidden_external_semantic_edge, diag}` naming
  the lawful route (`"required"`); consequential DO flows only through BRCE
  (`Xaas.Actuation.run/4`).

    * `admit_tool/2` -- per-tool admission. Refusal rows always win; a row is
      allowed iff `lease_admit` is true and the (optional) provider override
      lists it. The override can only NARROW, never add.
    * `admit_declaration/1` -- a generated surface declaration is a REQUEST
      intersected with policy, never authority: every edge outside policy is
      refused, one diag per offending edge.
    * `effective_surface/1` -- the deterministic surface a worker receives
      with its lease (string keys, JSON-ready), carrying `policy_digest`.

  The data is read at compile time (`@external_resource`); a malformed
  policy (wrong schema, a tool row missing a field, a consequence/mediation
  outside the vocabulary, a duplicate tool name) fails the build.
  """

  @policy_path Path.expand("../../../priv/ultracode/runtime_surface.json", __DIR__)
  @external_resource @policy_path

  @raw File.read!(@policy_path)
  @policy Jason.decode!(@raw)
  @digest "sha256:" <> Base.encode16(:crypto.hash(:sha256, @raw), case: :lower)

  @schema "xaas-ultracode-runtime-surface/v1"
  @required_fields ~w(name category consequence agent_visible mediated_by authority_required lease_admit refusal)
  @refusals [nil, "refused_no_authority", "forbidden_external_semantic_edge"]

  @tools @policy["tools"]
  @tool_index Map.new(@tools, &{&1["name"], &1})

  problems =
    [
      @policy["schema"] != @schema && "schema is #{inspect(@policy["schema"])}, not #{@schema}",
      map_size(@tool_index) != length(@tools) && "duplicate tool names",
      Enum.map(@tools, fn row ->
        cond do
          Enum.any?(@required_fields, &(not Map.has_key?(row, &1))) ->
            "#{inspect(row["name"])}: missing required field"

          row["consequence"] not in @policy["consequences"] ->
            "#{row["name"]}: unknown consequence #{inspect(row["consequence"])}"

          row["mediated_by"] not in @policy["mediations"] ->
            "#{row["name"]}: unknown mediation #{inspect(row["mediated_by"])}"

          row["refusal"] not in @refusals ->
            "#{row["name"]}: unknown refusal #{inspect(row["refusal"])}"

          row["refusal"] == "forbidden_external_semantic_edge" and not is_binary(row["required"]) ->
            "#{row["name"]}: forbidden_external_semantic_edge row lacks \"required\""

          row["refusal"] != nil and row["lease_admit"] == true ->
            "#{row["name"]}: refusal row is also lease_admit"

          true ->
            false
        end
      end)
    ]
    |> List.flatten()
    |> Enum.filter(& &1)

  if problems != [] do
    raise CompileError,
      description: "invalid #{@policy_path}: " <> Enum.join(problems, "; ")
  end

  @semantic_ports @policy["semantic_ports"]
  @local_primitives @policy["local_primitives"]
  @agent_tools for row <- @tools, row["lease_admit"] == true, do: row["name"]

  @type failure_diag :: %{String.t() => String.t() | nil}

  @doc "The decoded policy map."
  @spec policy() :: map()
  def policy, do: @policy

  @doc "Absolute path of the policy JSON."
  @spec policy_path() :: String.t()
  def policy_path, do: @policy_path

  @doc "`\"sha256:<64hex>\"` over the raw policy JSON bytes."
  @spec policy_digest() :: String.t()
  def policy_digest, do: @digest

  @doc "The only external semantic ports UltraCode may use."
  @spec semantic_ports() :: [String.t()]
  def semantic_ports, do: @semantic_ports

  @doc "The classified local construction primitives."
  @spec local_primitives() :: [String.t()]
  def local_primitives, do: @local_primitives

  @doc "Every classified tool row (string keys)."
  @spec tools() :: [map()]
  def tools, do: @tools

  @doc "The xaas-gate hook policy section."
  @spec gate_policy() :: map()
  def gate_policy, do: @policy["gate"]

  @doc "The worker environment policy section."
  @spec worker_env_policy() :: map()
  def worker_env_policy, do: @policy["worker_env"]

  @doc "Classify a tool name against the policy rows."
  @spec classify_tool(String.t()) :: {:ok, map()} | {:error, {:unknown_tool_class, String.t()}}
  def classify_tool(name) do
    case Map.fetch(@tool_index, name) do
      {:ok, row} -> {:ok, row}
      :error -> {:error, {:unknown_tool_class, name}}
    end
  end

  @doc """
  Admit one tool for a lease. `provider_override` (a list of names or nil)
  can only narrow the policy's lease-admitted set; a narrowed-out or
  non-lease-admitted row is `{:unknown_tool_class, name}`.
  """
  @spec admit_tool(String.t(), [String.t()] | nil) ::
          {:ok, %{decision: :allow}}
          | {:error, {:refused_no_authority, String.t()}}
          | {:error, {:forbidden_external_semantic_edge, failure_diag()}}
          | {:error, {:unknown_tool_class, String.t()}}
  def admit_tool(name, provider_override \\ nil) do
    with {:ok, row} <- classify_tool(name) do
      case row["refusal"] do
        "refused_no_authority" ->
          {:error, {:refused_no_authority, name}}

        "forbidden_external_semantic_edge" ->
          {:error, {:forbidden_external_semantic_edge, diag(name, row["required"])}}

        nil ->
          if row["lease_admit"] == true and
               (is_nil(provider_override) or name in provider_override) do
            {:ok, %{decision: :allow}}
          else
            {:error, {:unknown_tool_class, name}}
          end
      end
    end
  end

  @doc """
  Intersect a generated surface declaration with policy. `nil` yields the
  default surface. Any edge outside policy refuses the whole declaration with
  one diag per offending edge.
  """
  @spec admit_declaration(map() | nil) ::
          {:ok, map()} | {:error, {:forbidden_external_semantic_edge, [failure_diag()]}}
  def admit_declaration(nil), do: {:ok, default_surface()}

  def admit_declaration(decl) when is_map(decl) do
    ports = list(decl["semantic_ports"], @semantic_ports)
    prims = list(decl["local_primitives"], @local_primitives)
    direct = list(decl["direct_external"], [])
    tools = list(decl["tools"], @agent_tools)

    diags =
      Enum.map(ports -- @semantic_ports, &diag(&1, sa2a_required(&1))) ++
        Enum.map(direct, &diag(&1, sa2a_required(&1))) ++
        Enum.map(prims -- @local_primitives, &diag(&1, sa2a_required(&1))) ++
        Enum.flat_map(tools, &tool_diag/1)

    case diags do
      [] ->
        {:ok,
         default_surface()
         |> Map.merge(%{
           "semantic_ports" => ports,
           "local_primitives" => prims,
           "agent_tools" => tools,
           "provenance" => decl["provenance"]
         })}

      _ ->
        {:error, {:forbidden_external_semantic_edge, diags}}
    end
  end

  def admit_declaration(other),
    do: {:error, {:forbidden_external_semantic_edge, [diag(inspect(other), nil)]}}

  @doc "The effective surface handed to a leased worker (string keys)."
  @spec effective_surface(map()) :: map()
  def effective_surface(ctx) when is_map(ctx) do
    default_surface()
    |> Map.merge(%{
      "work_id" => ctx["work_id"],
      "subject" => %{
        "repo" => ctx["repo"],
        "base_sha" => ctx["base_sha"],
        "branch" => ctx["branch"]
      },
      # Never the bearer lease token: surfaces travel into receipts/OCEL.
      "lease_id" => ctx["lease_id"] || ctx["epoch_id"],
      "authority" => ctx["authority"] || "NONE",
      "env_keys" => ctx["env_keys"] || []
    })
  end

  defp default_surface do
    %{
      "schema" => @schema,
      "policy_digest" => @digest,
      "semantic_ports" => @semantic_ports,
      "local_primitives" => @local_primitives,
      "direct_external" => [],
      "agent_tools" => @agent_tools
    }
  end

  defp tool_diag(name) do
    case Map.fetch(@tool_index, name) do
      {:ok, %{"lease_admit" => true, "agent_visible" => true, "mediated_by" => "local"}} -> []
      {:ok, row} -> [diag(name, row["required"] || sa2a_required(name))]
      :error -> [diag(name, sa2a_required(name))]
    end
  end

  defp diag(to, required), do: %{"from" => "ultracode", "to" => to, "required" => required}

  defp sa2a_required(name), do: "UltraCode -> SA2A -> #{name}"

  defp list(nil, default), do: default
  defp list(l, _default) when is_list(l), do: Enum.map(l, &to_string/1)
  defp list(other, _default), do: [to_string(other)]
end
