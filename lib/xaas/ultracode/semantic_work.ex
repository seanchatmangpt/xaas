defmodule Xaas.Ultracode.SemanticWork do
  @moduledoc """
  Admits and materializes one canonical semantic-work execution descriptor into
  the existing Ultracode Run/Epoch/Lease fabric.

  The canonical work graph and frontier live upstream. XaaS consumes a bounded
  execution projection; it does not re-select graph frontier or reinterpret RDF.
  Semantic identity is descriptive only and grants no tool, mutation, push,
  publish, deploy, merge, or external actuation authority.
  """

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, Run, Worktrees}

  @sha ~r/^[0-9a-f]{40}$/
  @digest ~r/^sha256:[0-9a-f]{64}$/
  @repo_identity ~r/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/
  @repo_alias ~r/^[A-Za-z0-9_.-]{1,128}$/
  @execution_policies [:continuous_epoch_run, :autonomic_wave_attempt]

  @required ~w(
    work_order_iri
    checkpoint_iri
    graph_digest
    repository_identity
    execution_repo_alias
    base_sha
    goal
    provider
    verifier_suite
    execution_policy
    dependencies
  )a

  @keys %{
    "work_order_iri" => :work_order_iri,
    "checkpoint_iri" => :checkpoint_iri,
    "graph_digest" => :graph_digest,
    "repository" => :repository_identity,
    "repository_identity" => :repository_identity,
    "execution_repo_alias" => :execution_repo_alias,
    "base_sha" => :base_sha,
    "goal" => :goal,
    "provider" => :provider,
    "verifier_suite" => :verifier_suite,
    "execution_policy" => :execution_policy,
    "dependencies" => :dependencies,
    "standing" => :standing
  }

  @dependency_keys %{
    "work_order_iri" => :work_order_iri,
    "required_standing" => :required_standing,
    "observed_standing" => :observed_standing,
    "receipt_iri" => :receipt_iri,
    "receipt_digest" => :receipt_digest
  }

  @type dependency :: %{
          required(:work_order_iri) => String.t(),
          required(:required_standing) => :alive,
          required(:observed_standing) => :alive,
          required(:receipt_iri) => String.t(),
          required(:receipt_digest) => String.t()
        }

  @type descriptor :: %{
          required(:work_order_iri) => String.t(),
          required(:checkpoint_iri) => String.t(),
          required(:graph_digest) => String.t(),
          required(:repository_identity) => String.t(),
          required(:execution_repo_alias) => String.t(),
          required(:base_sha) => String.t(),
          required(:goal) => String.t(),
          required(:provider) => String.t(),
          required(:verifier_suite) => String.t(),
          required(:execution_policy) => :continuous_epoch_run | :autonomic_wave_attempt,
          required(:dependencies) => [dependency()]
        }

  @doc """
  Admits only the execution facts XaaS needs.

  Dependencies are typed upstream receipt edges. Every dependency must name the
  upstream work-order identity, the required and observed standing, and the
  exact receipt identity + digest. This runtime currently supports ALIVE as the
  only satisfiable required dependency standing; UNKNOWN is never treated as
  eligibility.

  Frontier selection itself is deliberately absent from this module. A canonical
  graph producer selects the frontier and projects an execution descriptor here.
  """
  @spec admit(map()) :: {:ok, descriptor()} | {:error, term()}
  def admit(input) when is_map(input) do
    descriptor = normalize_keys(input)

    with :ok <- require_fields(descriptor),
         :ok <- require_iri(descriptor, :work_order_iri),
         :ok <- require_iri(descriptor, :checkpoint_iri),
         :ok <- require_match(descriptor, :graph_digest, @digest),
         :ok <- require_match(descriptor, :repository_identity, @repo_identity),
         :ok <- require_match(descriptor, :execution_repo_alias, @repo_alias),
         :ok <- require_match(descriptor, :base_sha, @sha),
         :ok <- require_string(descriptor, :goal),
         :ok <- require_string(descriptor, :provider),
         :ok <- require_string(descriptor, :verifier_suite),
         {:ok, policy} <- admit_execution_policy(descriptor.execution_policy),
         {:ok, dependencies} <- admit_dependencies(descriptor.dependencies) do
      {:ok,
       descriptor
       |> Map.put(:execution_policy, policy)
       |> Map.put(:dependencies, dependencies)}
    end
  end

  def admit(_), do: {:error, {:refused_semantic_work, :not_a_map}}

  @doc """
  Materializes one already-selected semantic work order into the existing
  Ultracode lifecycle.

  Both execution policies use the single admitted Run.:start path. The only
  lawful variation is timing:

    * :continuous_epoch_run leaves the first Epoch :expected for AshOban/tick;
    * :autonomic_wave_attempt immediately applies the existing Epoch.:start
      transition so a bounded wave controller can lease it now.

  The exact-SHA worktree is provisioned from execution_repo_alias, never from
  repository_identity. Failure after worktree creation rolls back DB state and
  cleans the worktree.
  """
  @spec materialize(map(), keyword()) ::
          {:ok, %{run: Run.t(), epoch: Epoch.t(), worktree: String.t()}} | {:error, term()}
  def materialize(input, opts \\ []) do
    with {:ok, descriptor} <- admit(input),
         name <- worktree_name(descriptor),
         {:ok, worktree} <-
           Worktrees.provision(descriptor.execution_repo_alias, descriptor.base_sha, name) do
      case Xaas.Repo.transaction(fn ->
             case create_started_run(descriptor, worktree, opts) do
               {:ok, result} -> result
               {:error, reason} -> Xaas.Repo.rollback(reason)
             end
           end) do
        {:ok, result} ->
          {:ok, result}

        {:error, reason} ->
          _ = Worktrees.cleanup(descriptor.execution_repo_alias, worktree)
          {:error, reason}
      end
    end
  end

  @doc """
  Deterministic RDF/PROV projection of a sealed Ultracode receipt.

  It serializes standing already manufactured by the independent fabric court;
  it cannot upgrade standing or authority. Upstream dependency receipts are
  represented as prov:wasDerivedFrom edges.
  """
  @spec receipt_turtle(map(), Run.t(), Epoch.t(), struct()) :: String.t()
  def receipt_turtle(checkpoint, run, epoch, receipt) do
    checkpoint = normalize_keys(checkpoint)
    receipt_iri = "urn:xaas:ultracode:receipt:" <> to_string(receipt.id)
    epoch_iri = "urn:xaas:ultracode:epoch:" <> to_string(epoch.id)
    run_iri = "urn:xaas:ultracode:run:" <> to_string(run.id)
    outcome = receipt.outcome |> to_string() |> String.upcase()

    dependencies =
      checkpoint
      |> Map.get(:dependencies, [])
      |> Enum.map(&normalize_dependency/1)

    dependency_edges =
      Enum.map(dependencies, fn dependency ->
        "  prov:wasDerivedFrom <#{escape_iri(dependency.receipt_iri)}> ;"
      end)

    dependency_receipts =
      Enum.flat_map(dependencies, fn dependency ->
        [
          "<#{escape_iri(dependency.receipt_iri)}> a gall:Receipt, prov:Entity ;",
          "  gall:receiptDigest \"#{escape_literal(dependency.receipt_digest)}\" .",
          ""
        ]
      end)

    lines =
      [
        "@prefix gall: <https://semantic-a2a.dev/gall#> .",
        "@prefix prov: <http://www.w3.org/ns/prov#> .",
        "",
        "<#{escape_iri(receipt_iri)}> a gall:Receipt, prov:Entity ;",
        "  gall:workOrder <#{escape_iri(checkpoint.work_order_iri)}> ;",
        "  gall:checkpoint <#{escape_iri(checkpoint.checkpoint_iri)}> ;",
        "  gall:graphDigest \"#{escape_literal(checkpoint.graph_digest)}\" ;",
        "  gall:repositoryIdentity \"#{escape_literal(checkpoint.repository_identity)}\" ;",
        "  gall:executionRepoAlias \"#{escape_literal(checkpoint.execution_repo_alias)}\" ;",
        "  gall:executionPolicy \"#{escape_literal(checkpoint.execution_policy)}\" ;",
        "  gall:baseSha \"#{escape_literal(checkpoint.base_sha)}\" ;",
        "  gall:candidateSha \"#{escape_literal(epoch.final_head || "")}\" ;",
        "  gall:run <#{escape_iri(run_iri)}> ;",
        "  gall:epoch <#{escape_iri(epoch_iri)}> ;",
        "  gall:standing gall:#{outcome} ;"
      ] ++
        dependency_edges ++
        [
          "  prov:wasGeneratedBy <#{escape_iri(epoch_iri)}> .",
          ""
        ] ++ dependency_receipts

    Enum.join(lines, "\n")
  end

  defp create_started_run(descriptor, worktree, opts) do
    exact_subject = descriptor.work_order_iri <> "@" <> descriptor.graph_digest

    with {:ok, run} <- create_run(descriptor, opts),
         {:ok, started_run} <-
           run
           |> Ash.Changeset.for_update(
             :start,
             %{exact_subject: exact_subject, worktree: worktree},
             authorize?: false
           )
           |> Ash.update(),
         {:ok, epoch} <- first_epoch(started_run.id),
         {:ok, epoch} <- apply_execution_policy(epoch, descriptor.execution_policy) do
      {:ok, %{run: started_run, epoch: epoch, worktree: worktree}}
    end
  end

  defp create_run(descriptor, opts) do
    attrs = %{
      goal: descriptor.goal,
      provider: descriptor.provider,
      verifier_suite: descriptor.verifier_suite,
      max_cycles: Keyword.get(opts, :max_cycles, 1),
      work_order_iri: descriptor.work_order_iri,
      checkpoint_iri: descriptor.checkpoint_iri,
      graph_digest: descriptor.graph_digest,
      repository_identity: descriptor.repository_identity,
      execution_repo_alias: descriptor.execution_repo_alias,
      execution_policy: descriptor.execution_policy,
      dependency_evidence: dependency_evidence(descriptor.dependencies),
      base_sha: descriptor.base_sha
    }

    Run
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create()
  end

  defp first_epoch(run_id) do
    Epoch
    |> Ash.Query.for_read(:read_unscoped)
    |> Ash.Query.filter(run_id == ^run_id and cycle == 0)
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, %Epoch{} = epoch} -> {:ok, epoch}
      {:ok, nil} -> {:error, {:refused_semantic_work, :first_epoch_missing}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_execution_policy(epoch, :continuous_epoch_run), do: {:ok, epoch}

  defp apply_execution_policy(epoch, :autonomic_wave_attempt) do
    epoch
    |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
    |> Ash.update()
  end

  defp worktree_name(descriptor) do
    subject =
      Enum.join(
        [descriptor.work_order_iri, descriptor.checkpoint_iri, descriptor.graph_digest],
        "|"
      )

    suffix =
      :crypto.hash(:sha256, subject)
      |> Base.encode16(case: :lower)
      |> String.slice(0, 20)

    "gall-" <> suffix
  end

  defp dependency_evidence(dependencies) do
    Map.new(dependencies, fn dependency ->
      {dependency.work_order_iri,
       %{
         "required_standing" => "ALIVE",
         "observed_standing" => "ALIVE",
         "receipt_iri" => dependency.receipt_iri,
         "receipt_digest" => dependency.receipt_digest
       }}
    end)
  end

  defp normalize_keys(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      normalized =
        case key do
          key when is_atom(key) -> key
          key when is_binary(key) -> Map.get(@keys, key, key)
        end

      Map.put(acc, normalized, value)
    end)
  end

  defp normalize_dependency(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {key, value}, acc ->
      normalized =
        case key do
          key when is_atom(key) -> key
          key when is_binary(key) -> Map.get(@dependency_keys, key, key)
        end

      Map.put(acc, normalized, value)
    end)
  end

  defp normalize_dependency(other), do: other

  defp require_fields(map) do
    missing = Enum.reject(@required, &Map.has_key?(map, &1))
    if missing == [], do: :ok, else: {:error, {:refused_semantic_work, {:missing, missing}}}
  end

  defp require_string(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> :ok
      _ -> {:error, {:refused_semantic_work, {:invalid, key}}}
    end
  end

  defp require_iri(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" ->
        if String.contains?(value, ":"),
          do: :ok,
          else: {:error, {:refused_semantic_work, {:invalid, key}}}

      _ ->
        {:error, {:refused_semantic_work, {:invalid, key}}}
    end
  end

  defp require_match(map, key, regex) do
    case Map.get(map, key) do
      value when is_binary(value) ->
        if Regex.match?(regex, value),
          do: :ok,
          else: {:error, {:refused_semantic_work, {:invalid, key}}}

      _ ->
        {:error, {:refused_semantic_work, {:invalid, key}}}
    end
  end

  defp admit_execution_policy(value) when value in @execution_policies, do: {:ok, value}
  defp admit_execution_policy("continuous_epoch_run"), do: {:ok, :continuous_epoch_run}
  defp admit_execution_policy("autonomic_wave_attempt"), do: {:ok, :autonomic_wave_attempt}

  defp admit_execution_policy(value),
    do: {:error, {:refused_semantic_work, {:invalid_execution_policy, value}}}

  defp admit_dependencies(dependencies) when is_list(dependencies) do
    normalized = Enum.map(dependencies, &normalize_dependency/1)

    with :ok <- admit_dependency_shapes(normalized),
         :ok <- refuse_duplicate_dependencies(normalized) do
      {:ok, normalized}
    end
  end

  defp admit_dependencies(_), do: {:error, {:refused_semantic_work, :invalid_dependencies}}

  defp admit_dependency_shapes(dependencies) do
    Enum.reduce_while(dependencies, :ok, fn dependency, :ok ->
      case admit_dependency(dependency) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp admit_dependency(%{} = dependency) do
    required = ~w(work_order_iri required_standing observed_standing receipt_iri receipt_digest)a
    missing = Enum.reject(required, &Map.has_key?(dependency, &1))

    cond do
      missing != [] ->
        {:error, {:refused_dependency, {:missing, missing}}}

      not valid_iri?(dependency.work_order_iri) ->
        {:error, {:refused_dependency, {:invalid, :work_order_iri}}}

      normalize_standing(dependency.required_standing) != :alive ->
        {:error, {:unsupported_required_standing, dependency.required_standing}}

      normalize_standing(dependency.observed_standing) != :alive ->
        {:error, {:refused_dependency, {:standing, dependency.work_order_iri}}}

      not valid_iri?(dependency.receipt_iri) ->
        {:error, {:refused_dependency, {:invalid, :receipt_iri}}}

      not (is_binary(dependency.receipt_digest) and
               Regex.match?(@digest, dependency.receipt_digest)) ->
        {:error, {:refused_dependency, {:invalid, :receipt_digest}}}

      true ->
        :ok
    end
  end

  defp admit_dependency(other), do: {:error, {:refused_dependency, {:invalid, other}}}

  defp refuse_duplicate_dependencies(dependencies) do
    ids = Enum.map(dependencies, & &1.work_order_iri)

    if length(ids) == MapSet.size(MapSet.new(ids)),
      do: :ok,
      else: {:error, {:refused_dependency, :duplicate_work_order_identity}}
  end

  defp valid_iri?(value), do: is_binary(value) and value != "" and String.contains?(value, ":")

  defp normalize_standing(value) when value in [:alive, "ALIVE", "alive"], do: :alive
  defp normalize_standing(value) when value in [:unknown, "UNKNOWN", "unknown", nil], do: :unknown
  defp normalize_standing(value), do: value

  defp escape_literal(value) do
    value
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\r", "\\r")
  end

  defp escape_iri(value) do
    value
    |> to_string()
    |> String.replace(">", "%3E")
    |> String.replace("<", "%3C")
  end
end
