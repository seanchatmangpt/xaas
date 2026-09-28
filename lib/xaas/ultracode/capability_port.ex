defmodule Xaas.Ultracode.CapabilityPort do
  @moduledoc """
  The agent-facing SA2A capability port of the UltraCode runtime surface:

      UltraCode -> SA2A -> resolve_capability(capability, constraints)

  A leased worker asks the port for a capability by NAME; the port binds the
  request to the lease's subject (repo/base_sha/branch are always taken from
  the lease context, never from the wire) and delegates the decision to the
  mandatory capability-resolution court
  (`Xaas.Ultracode.CapabilityResolver.resolve_item/2`). The court's sealed
  receipt rides on the returned handle as provenance.

  This module holds NO provider code and NO fallback: it never calls a model,
  an HTTP API, or a shell. When the court cannot name a capability the answer
  is a typed failure (`Xaas.Ultracode.RuntimeSurface.Failure`) plus one
  capability-gap record -- never a direct external edge. A worker that wants
  the external world after a failure is still refused by
  `RuntimeSurface.admit_tool/2` (e.g. `WebFetch` =>
  `forbidden_external_semantic_edge`).

  ## Verdict -> port answer

    * `:reuse` / `:compose` -- a bound handle (`"state" => "bound"`).
    * `:frontier` / `:generate` / `:extend` -- `NO_CAPABILITY` (the closure
      was fully witnessed and holds no satisfier) + gap record.
    * `:unresolved` -- `CAPABILITY_UNAVAILABLE` when a counted source errored
      or skipped (the closure could not be seen), `NO_CAPABILITY` when no
      counted source answered at all; + gap record.

  ## Consequence

  A capability whose id matches `@external_capability_patterns`
  or that is not provably local (recipe/local namespace, or a local verb) is
  consequential: its handle
  carries `"authority_requirement" => "brce"` and
  `"invocation_contract" => "actuate"` -- it is invocable ONLY through the
  existing actuate tool (`Lease.actuate/2` -> `Xaas.Actuation.run/4`). All
  other capabilities are `"none"` / `"local"`.

  ## Source injection

  The court selects its witnesses through its own config seam
  (`config :xaas, :ultracode_capability_sources`); the port does not add a
  second seam. `opts[:resolver_ctx]` is passed through as the court's `ctx`
  (e.g. `%{capability_full_closure: false}`).
  """

  alias Xaas.Ultracode.CapabilityResolver
  alias Xaas.Ultracode.CapabilityResolver.Receipt
  alias Xaas.Ultracode.RuntimeSurface
  alias Xaas.Ultracode.RuntimeSurface.Failure

  # Fail-closed classification (court F8: a closed list of external verbs
  # missed open_pull_request/tag_version/ship_to_prod/republish). A
  # capability is LOCAL only when it is a construction recipe or every verb
  # segment is a known local read/verify/construct verb AND no segment names
  # an external effect; everything else is consequential (BRCE / actuate).
  @external_verbs ~w(publish push deploy merge release external open tag ship
                     republish write send post create delete update notify comment
                     upload approve close transition assign)
  @local_verbs ~w(inspect read retrieve list query get verify check format lint
                  test compile render generate diff status fmt)
  @local_namespaces ~w(recipe local)
  @external_verb_source "(^|[:_.-])(#{Enum.join(@external_verbs, "|")})($|[:_.-])"

  @subject_keys ["repo", "base_sha"]

  @type handle :: %{String.t() => term()}

  @doc """
  Resolve `capability` for the leased work in `lease_ctx` (the string-keyed
  map from `Lease.lease_context/1`). Returns a bound handle or a failure map.
  """
  @spec resolve(map(), String.t(), map() | nil, keyword()) ::
          {:ok, handle()} | {:error, Failure.t()}
  def resolve(lease_ctx, capability, constraints \\ %{}, opts \\ [])

  def resolve(lease_ctx, capability, constraints, opts)
      when is_map(lease_ctx) and is_binary(capability) do
    constraints = constraints || %{}
    subject = subject(lease_ctx)

    with :ok <- check_claimed_subject(subject, constraints["subject"]) do
      item = %{
        "id" => lease_ctx["work_id"] || lease_ctx["run_id"],
        "repo" => subject["repo"],
        "capability_id" => capability
      }

      receipt = CapabilityResolver.resolve_item(item, resolver_ctx(opts))
      answer(receipt, lease_ctx, capability, subject, constraints, opts)
    end
  end

  def resolve(_lease_ctx, capability, _constraints, _opts),
    do:
      {:error,
       Failure.new(:no_capability, %{
         "reason" => "invalid_request",
         "capability" => inspect(capability)
       })}

  @doc """
  Re-check a bound handle against the CURRENT lease context result. A lease
  that is no longer live (or a different lease token) revokes the handle
  (`UNAUTHORIZED`, details `"reason" => "revoked"`); a moved base revokes it
  as `STALE_SUBJECT`.
  """
  @spec check_handle(handle(), {:ok, map()} | {:error, term()}) :: :ok | {:error, Failure.t()}
  def check_handle(handle, {:error, reason}) when is_map(handle),
    do: {:error, revoked(handle, %{"cause" => inspect(reason)})}

  def check_handle(%{"lease_token" => token} = handle, {:ok, %{"lease_token" => token} = ctx}) do
    bound = get_in(handle, ["subject", "base_sha"])
    observed = ctx["base_sha"]

    if bound == observed do
      :ok
    else
      {:error, Failure.new(:stale_subject, %{"bound" => bound, "observed" => observed})}
    end
  end

  def check_handle(handle, {:ok, _ctx}) when is_map(handle),
    do: {:error, revoked(handle, %{"cause" => "lease_token_mismatch"})}

  @doc """
  Append one capability-gap record (one JSON line) to `opts[:gap_path]`, or
  `config :xaas, :ultracode_capability_gap_path`, or the tmp default.
  """
  @spec record_gap(map(), keyword()) :: :ok
  def record_gap(entry, opts \\ []) when is_map(entry) do
    path = gap_path(opts)

    line =
      entry
      |> Map.take(["capability", "work_id", "repo", "code", "at"])
      |> Map.put_new("at", DateTime.to_iso8601(DateTime.utc_now()))
      |> Jason.encode!()

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, line <> "\n", [:append])
    :ok
  end

  @doc "Count gap records per capability in the NDJSON file at `path`."
  @spec gap_stats(String.t()) :: %{String.t() => non_neg_integer()}
  def gap_stats(path) when is_binary(path) do
    case File.read(path) do
      {:ok, body} ->
        body
        |> String.split("\n", trim: true)
        |> Enum.flat_map(fn line ->
          case Jason.decode(line) do
            {:ok, %{"capability" => capability}} when is_binary(capability) -> [capability]
            _ -> []
          end
        end)
        |> Enum.frequencies()

      {:error, _} ->
        %{}
    end
  end

  @doc "The consequential capability-id patterns (publish/push/deploy/merge/...)."
  @spec external_capability_patterns() :: [Regex.t()]
  def external_capability_patterns, do: [Regex.compile!(@external_verb_source)]

  @doc "True when `capability_id` is consequential (BRCE / actuate only)."
  @spec consequential?(String.t()) :: boolean()
  def consequential?(capability_id) when is_binary(capability_id) do
    Regex.match?(Regex.compile!(@external_verb_source), capability_id) or
      not local_capability?(capability_id)
  end

  defp local_capability?(capability_id) do
    case String.split(capability_id, ":", parts: 2) do
      [ns, _] when ns in @local_namespaces ->
        true

      [_ns, name] ->
        segments = String.split(name, ~r/[:_.-]/, trim: true)
        segments != [] and Enum.any?(segments, &(&1 in @local_verbs))

      _ ->
        false
    end
  end

  # ------------------------------------------------------------------

  defp answer(
         %Receipt{class: class} = receipt,
         lease_ctx,
         capability,
         subject,
         constraints,
         _opts
       )
       when class in [:reuse, :compose] do
    capability_id =
      case receipt.selected_capabilities do
        [single] -> single
        _ -> capability
      end

    consequential? = consequential?(capability_id) or consequential?(capability)

    {:ok,
     %{
       "capability_id" => capability_id,
       "requested" => capability,
       "selected" => receipt.selected_capabilities,
       "subject" => subject,
       "constraints" => constraints,
       "authority_requirement" => if(consequential?, do: "brce", else: "none"),
       "invocation_contract" => if(consequential?, do: "actuate", else: "local"),
       "provenance" => %{
         "resolution_class" => Atom.to_string(class),
         "receipt" => Receipt.to_json_map(receipt),
         "policy_digest" => RuntimeSurface.policy_digest()
       },
       "lease_token" => lease_ctx["lease_token"],
       "work_id" => lease_ctx["work_id"],
       "state" => "bound"
     }}
  end

  defp answer(%Receipt{} = receipt, lease_ctx, capability, subject, _constraints, opts) do
    failure = failure_for(receipt, capability)

    record_gap(
      %{
        "capability" => capability,
        "work_id" => lease_ctx["work_id"],
        "repo" => subject["repo"],
        "code" => failure["code"]
      },
      opts
    )

    {:error, failure}
  end

  defp failure_for(%Receipt{class: :unresolved} = receipt, capability) do
    counted =
      Enum.filter(receipt.sources_queried, fn {_name, status} ->
        Map.get(status, :counted, true)
      end)

    failed = Enum.filter(counted, fn {_name, s} -> s.status in [:error, :skipped] end)

    base = %{
      "capability" => capability,
      "resolution_class" => "unresolved",
      "policy_digest" => RuntimeSurface.policy_digest()
    }

    case failed do
      [] ->
        Failure.new(:no_capability, Map.put(base, "reason", "no_source_answered"))

      _ ->
        sources =
          Map.new(failed, fn {name, s} ->
            detail =
              case s.status do
                :error -> Failure.from_term(s.detail)
                :skipped -> %{"skipped" => inspect(s.detail)}
              end

            {name, %{"status" => Atom.to_string(s.status), "detail" => detail}}
          end)

        Failure.new(:capability_unavailable, Map.put(base, "sources", sources))
    end
  end

  defp failure_for(%Receipt{class: class} = receipt, capability) do
    Failure.new(:no_capability, %{
      "capability" => capability,
      "resolution_class" => Atom.to_string(class),
      "residual" => receipt.residual_requirements || [],
      "policy_digest" => RuntimeSurface.policy_digest()
    })
  end

  defp subject(lease_ctx) do
    %{
      "repo" => lease_ctx["repo"],
      "base_sha" => lease_ctx["base_sha"],
      "branch" => lease_ctx["branch"]
    }
  end

  # A claimed subject on the wire is a CLAIM: every key it names must equal
  # the lease-bound subject, else PROVENANCE_MISMATCH. It never replaces it.
  defp check_claimed_subject(_subject, nil), do: :ok

  defp check_claimed_subject(subject, claimed) when is_map(claimed) do
    mismatched =
      Enum.filter(@subject_keys, fn key ->
        Map.has_key?(claimed, key) and claimed[key] != subject[key]
      end)

    case mismatched do
      [] ->
        :ok

      keys ->
        {:error,
         Failure.new(:provenance_mismatch, %{
           "keys" => keys,
           "bound" => Map.take(subject, keys),
           "claimed" => Map.take(claimed, keys)
         })}
    end
  end

  defp check_claimed_subject(_subject, claimed),
    do:
      {:error,
       Failure.new(:provenance_mismatch, %{"claimed" => inspect(claimed), "reason" => "not_a_map"})}

  defp revoked(handle, extra) do
    Failure.new(
      :unauthorized,
      Map.merge(
        %{"reason" => "revoked", "capability_id" => handle["capability_id"]},
        extra
      )
    )
  end

  defp resolver_ctx(opts) do
    case Keyword.get(opts, :resolver_ctx) do
      ctx when is_map(ctx) -> ctx
      ctx when is_list(ctx) -> Map.new(ctx)
      _ -> %{}
    end
  end

  defp gap_path(opts) do
    Keyword.get(opts, :gap_path) ||
      Application.get_env(
        :xaas,
        :ultracode_capability_gap_path,
        Path.join(System.tmp_dir!(), "xaas-capability-gaps.ndjson")
      )
  end
end
