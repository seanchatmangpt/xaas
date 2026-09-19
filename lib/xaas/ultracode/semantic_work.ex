defmodule Xaas.Ultracode.SemanticWork do
  @moduledoc """
  Admits and materializes one canonical GALL semantic-work descriptor into
  the existing Ultracode Run/Epoch/Lease fabric.

  This module deliberately does not parse arbitrary RDF. The canonical RDF
  graph is admitted upstream and projected into this bounded descriptor. The
  descriptor MUST carry the canonical checkpoint IRI and graph digest, which
  are persisted on the Run and replayed into the receipt projection.

  Semantic identity is descriptive only. It grants no tool, mutation, push,
  publish, deploy, or external actuation authority.
  """

  alias Xaas.Ultracode.{Epoch, Run, Worktrees}

  @sha ~r/^[0-9a-f]{40}$/
  @digest ~r/^sha256:[0-9a-f]{64}$/

  @required ~w(checkpoint_iri graph_digest repository base_sha goal provider verifier_suite dependencies)a
  @keys %{
    "checkpoint_iri" => :checkpoint_iri,
    "graph_digest" => :graph_digest,
    "repository" => :repository,
    "base_sha" => :base_sha,
    "goal" => :goal,
    "provider" => :provider,
    "verifier_suite" => :verifier_suite,
    "dependencies" => :dependencies,
    "standing" => :standing
  }

  @type descriptor :: %{
          required(:checkpoint_iri) => String.t(),
          required(:graph_digest) => String.t(),
          required(:repository) => String.t(),
          required(:base_sha) => String.t(),
          required(:goal) => String.t(),
          required(:provider) => String.t(),
          required(:verifier_suite) => String.t(),
          required(:dependencies) => list()
        }

  @doc """
  Validates only facts required to enter Ultracode.

  Dependency entries must already carry ALIVE standing. UNKNOWN is not
  admitted, and missing values are typed refusals rather than defaults.
  """
  @spec admit(map()) :: {:ok, descriptor()} | {:error, term()}
  def admit(input) when is_map(input) do
    descriptor = normalize_keys(input)

    with :ok <- require_fields(descriptor),
         :ok <- require_string(descriptor, :checkpoint_iri),
         :ok <- require_match(descriptor, :graph_digest, @digest),
         :ok <- require_string(descriptor, :repository),
         :ok <- require_match(descriptor, :base_sha, @sha),
         :ok <- require_string(descriptor, :goal),
         :ok <- require_string(descriptor, :provider),
         :ok <- require_string(descriptor, :verifier_suite),
         :ok <- admit_dependencies(descriptor.dependencies) do
      {:ok, descriptor}
    end
  end

  def admit(_), do: {:error, {:refused_semantic_work, :not_a_map}}

  @doc """
  Materializes one admitted semantic checkpoint as a provider-pull Run and a
  running Epoch in an isolated exact-SHA worktree.

  The existing Lease module remains the only worker claim/close authority.
  """
  @spec materialize(map(), keyword()) :: {:ok, %{run: Run.t(), epoch: Epoch.t(), worktree: String.t()}} | {:error, term()}
  def materialize(input, opts \\ []) do
    with {:ok, descriptor} <- admit(input),
         name <- worktree_name(descriptor),
         {:ok, worktree} <- Worktrees.provision(descriptor.repository, descriptor.base_sha, name),
         {:ok, run} <- create_run(descriptor, opts),
         {:ok, epoch} <- create_epoch(descriptor, run, worktree) do
      {:ok, %{run: run, epoch: epoch, worktree: worktree}}
    end
  end

  @doc """
  Returns checkpoints whose dependencies are all ALIVE and whose own standing
  is UNKNOWN. This is a pure frontier query; it does not SELECT or DO.
  """
  @spec frontier([map()]) :: [map()]
  def frontier(checkpoints) when is_list(checkpoints) do
    Enum.filter(checkpoints, fn checkpoint ->
      checkpoint = normalize_keys(checkpoint)
      own = normalize_standing(Map.get(checkpoint, :standing))

      own == :unknown and
        case admit_dependencies(Map.get(checkpoint, :dependencies, [])) do
          :ok -> true
          _ -> false
        end
    end)
  end

  @doc """
  Deterministic, bounded RDF/PROV Turtle projection of a sealed Ultracode
  receipt. This projection does not upgrade standing; it serializes the
  standing already manufactured by the independent fabric verifier.
  """
  @spec receipt_turtle(map(), Run.t(), Epoch.t(), struct()) :: String.t()
  def receipt_turtle(checkpoint, run, epoch, receipt) do
    checkpoint = normalize_keys(checkpoint)
    receipt_iri = "urn:xaas:ultracode:receipt:" <> to_string(receipt.id)
    epoch_iri = "urn:xaas:ultracode:epoch:" <> to_string(epoch.id)
    run_iri = "urn:xaas:ultracode:run:" <> to_string(run.id)
    outcome = receipt.outcome |> to_string() |> String.upcase()

    [
      "@prefix gall: <https://semantic-a2a.dev/gall#> .",
      "@prefix prov: <http://www.w3.org/ns/prov#> .",
      "",
      "<#{escape_iri(receipt_iri)}> a gall:Receipt, prov:Entity ;",
      "  gall:checkpoint <#{escape_iri(checkpoint.checkpoint_iri)}> ;",
      "  gall:graphDigest \"#{escape_literal(checkpoint.graph_digest)}\" ;",
      "  gall:repository \"#{escape_literal(checkpoint.repository)}\" ;",
      "  gall:baseSha \"#{escape_literal(checkpoint.base_sha)}\" ;",
      "  gall:candidateSha \"#{escape_literal(epoch.final_head || "")}\" ;",
      "  gall:run <#{escape_iri(run_iri)}> ;",
      "  gall:epoch <#{escape_iri(epoch_iri)}> ;",
      "  gall:standing gall:#{outcome} ;",
      "  prov:wasGeneratedBy <#{escape_iri(epoch_iri)}> .",
      ""
    ]
    |> Enum.join("\n")
  end

  defp create_run(descriptor, opts) do
    attrs = %{
      goal: descriptor.goal,
      provider: descriptor.provider,
      verifier_suite: descriptor.verifier_suite,
      max_cycles: Keyword.get(opts, :max_cycles, 1),
      checkpoint_iri: descriptor.checkpoint_iri,
      graph_digest: descriptor.graph_digest,
      base_sha: descriptor.base_sha
    }

    Run
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create()
  end

  defp create_epoch(descriptor, run, worktree) do
    exact_subject = descriptor.checkpoint_iri <> "@" <> descriptor.graph_digest

    Epoch
    |> Ash.Changeset.for_create(
      :create,
      %{
        run_id: run.id,
        cycle: 0,
        exact_subject: exact_subject,
        state: :running,
        worktree: worktree
      },
      authorize?: false
    )
    |> Ash.create()
  end

  defp worktree_name(descriptor) do
    digest = String.replace_prefix(descriptor.graph_digest, "sha256:", "")
    "gall-" <> String.slice(digest, 0, 20)
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

  defp admit_dependencies(dependencies) when is_list(dependencies) do
    blocked =
      Enum.reject(dependencies, fn
        %{standing: standing} -> normalize_standing(standing) == :alive
        %{"standing" => standing} -> normalize_standing(standing) == :alive
        standing -> normalize_standing(standing) == :alive
      end)

    if blocked == [], do: :ok, else: {:error, {:refused_dependency, blocked}}
  end

  defp admit_dependencies(_), do: {:error, {:refused_semantic_work, :invalid_dependencies}}

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
