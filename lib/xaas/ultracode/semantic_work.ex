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

  alias Xaas.Ultracode.{CourtReceipt, Epoch, Run, SemanticWaveTrigger, Worktrees}
  alias Xaas.Ultracode.SemanticWork.AdmissionBinding

  @sha ~r/^[0-9a-f]{40}$/
  @digest ~r/^sha256:[0-9a-f]{64}$/
  @repo_identity ~r/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/
  @repo_alias ~r/^[A-Za-z0-9_.-]{1,128}$/
  # The canonical `sj:capabilityId` pattern (e.g. "recipe:mix-format") --
  # byte-identical source to `Run.capability_id`'s `match` constraint and the
  # v26.9.23 wave contract. Compiled `:dollar_endonly` so `$` means end of
  # string as in the SHACL/XSD reading of the same pattern: PCRE's default
  # `$` also matches before a trailing newline ("recipe:x\n").
  @capability_id_source "^[a-z0-9][a-z0-9_.-]*:[a-z0-9][a-z0-9_.:-]*$"
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
    "standing" => :standing,
    "court_map" => :court_map,
    "admission_digest" => :admission_digest,
    "admitted_work_order" => :admitted_work_order,
    "bridge" => :bridge,
    "capability" => :capability
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
          required(:dependencies) => [dependency()],
          optional(:court_map) => map()
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

  ## The emitter contract (what ggen / the canonical producer must send)

  `admit/1` (and therefore `materialize/2`) accepts a string- OR atom-keyed
  map carrying EXACTLY these 11 required fields (line-anchored at
  `@required` above and validated field-by-field in `admit/1`'s `with`
  chain; the `@keys` mapping right below defines the accepted string
  aliases -- notably `"repository"` is accepted as an alias for
  `repository_identity`):

    | field                  | type / format                                | validation                |
    |------------------------|----------------------------------------------|---------------------------|
    | `work_order_iri`       | string, absolute IRI (must contain `:`)      | `require_iri/2`           |
    | `checkpoint_iri`       | string, absolute IRI (must contain `:`)      | `require_iri/2`           |
    | `graph_digest`         | `"sha256:" <> 64 lowercase hex`              | `@digest` regex           |
    | `admission_digest`     | optional; valid digest AND equal to `graph_digest` when present | `optional_admission_digest/1` |
    | `admitted_work_order`  | optional; admitted snapshot, digest recomputed by XaaS | `AdmissionBinding.verify/2` |
    | `repository_identity`  | `"owner/repo"` (`[A-Za-z0-9_.-]+/...`)       | `@repo_identity` regex    |
    | `execution_repo_alias` | 1-128 of `[A-Za-z0-9_.-]` (Worktrees key)    | `@repo_alias` regex       |
    | `base_sha`             | exactly 40 lowercase hex (a git SHA)         | `@sha` regex              |
    | `goal`                 | nonempty string (worker instructions)        | `require_string/2`        |
    | `provider`             | nonempty string (e.g. `"zcode"`)             | `require_string/2`        |
    | `verifier_suite`       | nonempty string, operator-registered name    | `require_string/2`        |
    | `execution_policy`     | `:continuous_epoch_run | :autonomic_wave_attempt` (atoms or strings) | `admit_execution_policy/1` |
    | `dependencies`         | list (may be empty) of typed receipt edges   | `admit_dependencies/1`    |

  Each dependency needs `work_order_iri` (IRI), `required_standing` and
  `observed_standing` (only `ALIVE` is satisfiable), `receipt_iri` (IRI)
  and `receipt_digest` (`sha256:` hex); duplicates by work-order identity
  are refused. An optional top-level `"standing"` key is passed through
  by the key normalization and otherwise ignored: standing is never
  granted by admission. An optional `"admission_digest"` key is the
  integrity envelope for producers that bind the descriptor to one
  admission snapshot (`graph_digest` := the admission's work-order
  digest): when present it must be a valid digest AND equal
  `graph_digest`. The envelope alone is only a second in-band copy, so
  the falsifier "materialize accepts a WorkOrder whose digest was
  altered after admission" does NOT rest on it (an omitted envelope, or
  one altered together with `graph_digest`, would defeat it); it rests
  on the XaaS-side digest binding below. The envelope is admission-time
  only and never persisted (the Run schema is unchanged).

  ## Digest binding (fail-closed, recomputed on the XaaS side)

  `admit/2` verifies the descriptor's digests against anchors XaaS
  recomputes or reads itself, so a tamper is refused with a typed reason
  WITH OR WITHOUT the envelope (contract:
  `Xaas.Ultracode.SemanticWork.AdmissionBinding`):

    * optional `"admitted_work_order"`: the producer's admitted snapshot
      (the exact map `GgenIgniter.SemanticJira.admit_work_order/1`
      returned). XaaS recomputes its digest from its own content; a stale
      digest, or a descriptor `base_sha` / `repository_identity` /
      `work_order_iri` / `goal` / `checkpoint_iri` / `dependencies` / bridge
      field (incl. `bridge.subject` and `bridge.requires`) that is not the
      snapshot's projection, is refused;
    * `bridge.source_snapshot_digest`: the real bridge's per-work-order
      snapshot digest, a second anchor that must agree with the first;
    * option `binding:`, declared by the TRUSTED caller and never by the
      descriptor. The DEFAULT (no `binding:` option) is verify-when-present:
      a carried snapshot is fully checked (self-consistent, anchor-agreeing,
      fields the snapshot determines) and an anchor-less descriptor keeps
      today's behavior with the graph digest unbound. `:snapshot` forces the
      graph digest to bind to the admission anchors (this is what the
      materialize boundary pins); `:graph` is the
      explicit opt-out for a producer whose `graph_digest` is graph-wide (the
      digest the real `Descriptor.build/4` emits over every definition
      digest): `graph_digest` is then bound only by a pin. There is no
      content-selected mode: `:auto` is refused
      (`{:invalid_binding_option, :auto}`), because a guard the descriptor can
      switch off by deleting its own snapshot is not a guard;
    * options `expected_graph_digest:` / `expected_snapshot_digest:`, the
      OUT-OF-BAND trust roots (an operator's admission record). They are the
      only anchors a tamperer cannot rewrite together with the descriptor;
      without one, a fully re-forged self-consistent descriptor is
      indistinguishable from the real one.

  Refusals are typed: `{:error, {:refused_semantic_work, reason}}` /
  `{:error, {:refused_dependency, reason}}` /
  `{:error, {:unsupported_required_standing, value}}` /
  `{:error, {:refused_court_map, reason}}`.

  ## The optional court_map (fabric court-receipt contract)

  An OPTIONAL 12th field, `"court_map"`, carries the work order's
  minted acceptance/falsifier/court IRIs together with the one machine-
  checkable predicate each maps to (see
  `Xaas.Ultracode.CourtReceipt` for the exact shape, the verdict
  vocabulary, and the fail-closed law). It is stored on the Run at
  materialization (`court_map` attribute) and consumed ONLY by the fabric
  at close time, so the sealed receipt can carry
  `acceptance_results`/`falsifier_results` keyed by the work order's own
  IRIs (`promote/3`'s acceptance/falsifiers/courts checks) without the
  worker ever supplying them. Absent = today's behavior; present but
  malformed = typed refusal.
  """
  @spec admit(map(), keyword()) :: {:ok, descriptor()} | {:error, term()}
  def admit(input, opts \\ [])

  def admit(input, opts) when is_map(input) and is_list(opts) do
    descriptor = normalize_keys(input)

    with {:ok, binding} <- AdmissionBinding.options(opts),
         :ok <- require_fields(descriptor),
         :ok <- require_iri(descriptor, :work_order_iri),
         :ok <- require_iri(descriptor, :checkpoint_iri),
         :ok <- require_match(descriptor, :graph_digest, @digest),
         :ok <- optional_admission_digest(descriptor),
         :ok <- require_match(descriptor, :repository_identity, @repo_identity),
         :ok <- require_match(descriptor, :execution_repo_alias, @repo_alias),
         :ok <- require_match(descriptor, :base_sha, @sha),
         :ok <- require_string(descriptor, :goal),
         :ok <- require_string(descriptor, :provider),
         :ok <- require_string(descriptor, :verifier_suite),
         :ok <- optional_bridge(descriptor),
         :ok <- optional_capability(descriptor),
         :ok <- AdmissionBinding.verify(descriptor, binding),
         {:ok, policy} <- admit_execution_policy(descriptor.execution_policy),
         {:ok, dependencies} <- admit_dependencies(descriptor.dependencies),
         {:ok, court_map} <- CourtReceipt.admit(Map.get(descriptor, :court_map)) do
      {:ok,
       descriptor
       |> Map.put(:execution_policy, policy)
       |> Map.put(:dependencies, dependencies)
       |> Map.put(:court_map, court_map)}
    end
  end

  def admit(_input, _opts), do: {:error, {:refused_semantic_work, :not_a_map}}

  @doc """
  Materializes one already-selected semantic work order into the existing
  Ultracode lifecycle.

  Both execution policies use the single admitted Run.:start path. The only
  lawful variation is timing:

    * :continuous_epoch_run leaves the first Epoch :expected for AshOban/tick;
    * :autonomic_wave_attempt immediately applies the existing Epoch.:start
      transition so a bounded wave controller can lease it now.

  ## Event-driven dispatch (wave-6 law)

  On SUCCESS, a `:autonomic_wave_attempt` materialization enqueues the
  semantic-wave dispatch IMMEDIATELY: `Xaas.Ultracode.SemanticWaveTrigger.
  enqueue/1` runs INSIDE this function's `Xaas.Repo.transaction`, so the
  wave Oban job and the ready Epoch commit atomically (transactional
  outbox -- the job can never exist without its work, and an insert
  failure rolls the whole materialization back). The `*/30` `:semantic_wave`
  cron on `Xaas.Ultracode.Run` stays as the WATCHDOG for a missed event;
  it is no longer the primary dispatch clock.

  The exact-SHA worktree is provisioned from execution_repo_alias, never from
  repository_identity. Failure after worktree creation rolls back DB state and
  cleans the worktree.

  Returns `{:ok, %{run:, epoch:, worktree:, wave: trigger_receipt}}` where
  `wave` is `Xaas.Ultracode.SemanticWaveTrigger`'s enqueue receipt
  (`enqueued?`/`deduped?`/`policy_gated?`/`job_id`).
  """
  @spec materialize(map(), keyword()) ::
          {:ok, %{run: Run.t(), epoch: Epoch.t(), worktree: String.t(), wave: map()}}
          | {:error, term()}
  def materialize(input, opts \\ []) do
    # the materialize boundary is strict: unless the trusted caller pinned a
    # mode, the descriptor's graph digest must bind to its admission anchors
    with {:ok, descriptor} <- admit(input, Keyword.put_new(opts, :binding, :snapshot)),
         name <- worktree_name(descriptor),
         {:ok, worktree} <-
           Worktrees.provision(descriptor.execution_repo_alias, descriptor.base_sha, name) do
      case Xaas.Repo.transaction(fn ->
             with {:ok, result} <- create_started_run(descriptor, worktree, opts),
                  {:ok, wave} <- SemanticWaveTrigger.enqueue(descriptor) do
               Map.put(result, :wave, wave)
             else
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
      court_map: Map.get(descriptor, :court_map),
      base_sha: descriptor.base_sha,
      semantic_bridge: Map.get(descriptor, :bridge),
      capability_id: Map.get(descriptor, :capability)
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

  # Collision-free per repo+work-order: the alias slug AND the alias are both
  # folded into the derived name via Worktrees.epoch_worktree_name/2, so two
  # repos sharing the global worktree root can never collide on one path.
  defp worktree_name(descriptor) do
    subject =
      Enum.join(
        [descriptor.work_order_iri, descriptor.checkpoint_iri, descriptor.graph_digest],
        "|"
      )

    "gall-" <> Worktrees.epoch_worktree_name(descriptor.execution_repo_alias, subject)
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

  # The bridge is opaque to XaaS: only "absent or a JSON object" is checked.
  defp optional_bridge(map) do
    case Map.get(map, :bridge) do
      nil -> :ok
      %{} = bridge when not is_struct(bridge) -> :ok
      _ -> {:error, {:refused_semantic_work, {:invalid, :bridge}}}
    end
  end

  @doc """
  The compiled canonical `sj:capabilityId` pattern the optional `capability`
  descriptor field is admitted against (source
  `#{@capability_id_source}`, `:dollar_endonly`).
  """
  @spec capability_id_pattern() :: Regex.t()
  def capability_id_pattern, do: Regex.compile!(@capability_id_source, [:dollar_endonly])

  # Optional `capability` (the work order's `sj:capabilityId`): absent = no
  # deterministic recipe; present = a NAME the recipe registry resolves at
  # claim time (`Xaas.Ultracode.RecipeWorker`), never a command.
  defp optional_capability(map) do
    case Map.get(map, :capability) do
      nil ->
        :ok

      value when is_binary(value) and byte_size(value) <= 128 ->
        if Regex.match?(capability_id_pattern(), value),
          do: :ok,
          else: {:error, {:refused_semantic_work, {:invalid, :capability}}}

      _ ->
        {:error, {:refused_semantic_work, {:invalid, :capability}}}
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

  # Opt-in integrity envelope for descriptor producers that bind the
  # execution to one admission snapshot (graph_digest := the admission's
  # work-order digest): `admission_digest` is then a second, independent copy
  # of that same digest, and a descriptor whose digest was altered after
  # admission fails closed HERE, at the materialize boundary. Absent (or nil)
  # = today's behavior. Admission-time only; never persisted.
  defp optional_admission_digest(map) do
    case Map.get(map, :admission_digest) do
      nil ->
        :ok

      admission when is_binary(admission) ->
        cond do
          not Regex.match?(@digest, admission) ->
            {:error, {:refused_semantic_work, {:invalid, :admission_digest}}}

          admission != map.graph_digest ->
            {:error, {:refused_semantic_work, {:admission_digest_mismatch, admission}}}

          true ->
            :ok
        end

      _ ->
        {:error, {:refused_semantic_work, {:invalid, :admission_digest}}}
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
