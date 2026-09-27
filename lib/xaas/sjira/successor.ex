defmodule Xaas.Sjira.Successor do
  @moduledoc """
  Successor intake (GC-26.9.23 gate GC23-12, Semantic Self-Hosting; PRD
  section 12, ARD sections 5.5, 9 and 24 M9; lane V23-H).

  ## Retired edge: prose -> WorkOrder (v26.9.25 post-tag hardening, X1)

  The intake ran the no-LLM closed loop over `<dir>/compiled/orders.ttl`, the
  output of ggen_igniter `mix semantic_jira.compile_prose`. ggen_igniter
  retired that compiler in dc2724263b7c955f23cd3e1a7407f3665e2a022e
  (`Prose -/-> WorkOrder`): prose is observation-only, `mix
  semantic_jira.observe_prose` emits only UNKNOWN candidate propositions with
  `sj:authorityClaim "NONE"`, and a WorkOrder originates only from an
  admitted `origin_authority` pinned by an `sj:AuthorityTrustRoot` of the
  canonical semantic-jira-pack ontology (G1, ggen_igniter
  647db5f208b7ec88c84f0dc7d70925b4dec330f9).

  `intake/1` and `check/1` therefore run the no-LLM guard (F3) and then return
  a typed `UNSUPPORTED(provider_capability)` (reason `compile_prose_retired`,
  broken term `mu_on_O`: manufacture from unadmitted prose, RFC-0004 section
  39 class `CAPABILITY_GAP`) naming the successor surface -- no graph-side
  process runs and nothing is written. The committed
  `docs/sjira/v26.9.23/successor/{compiled,intake}` artifacts stay as
  historical receipts of the retired edge; they are never recomputed.

  ## Typed successor items

  `classify/1` still turns a work-order row into a successor item, never an
  error:

    * `Route.resolve/1` refuses `:unregistered_capability` for a canonical
      capability no registry entry serves -> `UNSUPPORTED(provider_capability)`;
    * the compiler's placeholder `construct:unassigned` -> `UNKNOWN`
      (`capability_unassigned`);
    * a registered capability -> `UNKNOWN` with `"route": "KNOWN"` and the
      provider (resolvable, not executed).

  The item's tuple digest is `Route.digest/1` of `Route.tuple(:order, row)`
  and must equal the row's `tuple_digest`; a difference is
  `REFUSED(tuple_digest_mismatch)` (broken term `admission_vacuous`). A row
  whose tuple the route cannot admit is `REFUSED(tuple_refused)`.
  """

  alias Xaas.Sa2a.Route
  alias Xaas.Ultracode.SemanticDrive

  @outputs ~w(work.json frontier.json descriptor.json resolution.json)
  @unassigned "construct:unassigned"
  @retired_in "dc2724263b7c955f23cd3e1a7407f3665e2a022e"
  @pin_head "647db5f208b7ec88c84f0dc7d70925b4dec330f9"

  @type typed :: %{required(String.t()) => term()}

  @doc "The files the retired intake wrote (historical receipts, never recomputed)."
  @spec outputs() :: [String.t()]
  def outputs, do: @outputs

  @doc """
  The retired intake. Runs the no-LLM guard (`REFUSED(llm_credential_present)`
  / `REFUSED(unadmitted_environment)` when it refuses), then returns
  `{:unsupported, typed}`: `UNSUPPORTED(provider_capability)`, reason
  `compile_prose_retired`, with the successor pointer (`successor/0`). No
  graph-side process runs and `:out_dir` is never written.
  """
  @spec intake(keyword()) :: {:unsupported, typed()} | {:refused, typed()}
  def intake(opts) do
    with :ok <- SemanticDrive.no_llm_guard(Keyword.get(opts, :env, System.get_env())) do
      {:unsupported, retired("intake")}
    end
  end

  @doc """
  The retired byte-identical recompute: the same answer as `intake/1` (the
  committed outputs cannot be recomputed without the retired compiler).
  """
  @spec check(keyword()) :: {:unsupported, typed()} | {:refused, typed()}
  def check(opts) do
    with :ok <- SemanticDrive.no_llm_guard(Keyword.get(opts, :env, System.get_env())) do
      {:unsupported, retired("check")}
    end
  end

  @doc """
  The successor of the retired prose -> WorkOrder edge, with durable locators
  (CE23-9 grammar).
  """
  @spec successor() :: map()
  def successor do
    %{
      "observation_surface" => "mix semantic_jira.observe_prose",
      "observation_output" =>
        "propositions.ttl only: sj:candidateStanding UNKNOWN, sj:authorityClaim NONE",
      "work_origin" =>
        "a WorkOrder originates only from an admitted origin_authority pinned by an sj:AuthorityTrustRoot of the canonical semantic-jira-pack ontology",
      "locators" => [
        "git:seanchatmangpt/ggen_igniter@#{@retired_in}:lib/mix/tasks/semantic_jira.observe_prose.ex",
        "git:seanchatmangpt/ggen_igniter@#{@pin_head}:priv/ggen/semantic-jira-pack/ontology.ttl"
      ]
    }
  end

  defp retired(hop) do
    typed(
      "UNSUPPORTED(provider_capability)",
      "compile_prose_retired",
      "mu_on_O",
      hop,
      %{
        "capability" => "semantic_jira.compile_prose",
        "retired_in" => "git:seanchatmangpt/ggen_igniter@#{@retired_in}",
        "rfc0004_s39" => "CAPABILITY_GAP",
        "law" => "prose is observation-only; prose never originates a WorkOrder",
        "successor" => successor()
      }
    )
  end

  @doc """
  Classifies one work-order row as a typed successor item (see the
  moduledoc). `{:ok, item}` or `{:refused, typed}` when the row's tuple is
  not admissible or its digest differs from the row's recorded
  `tuple_digest`.
  """
  @spec classify(map()) :: {:ok, map()} | {:refused, typed()}
  def classify(%{} = row) do
    case Route.tuple(:order, row) do
      {:ok, tuple} ->
        digest = Route.digest(tuple)

        if row["tuple_digest"] in [nil, digest] do
          {:ok, item(row, tuple, digest, Route.resolve(tuple))}
        else
          {:refused,
           typed(
             "REFUSED(tuple_digest_mismatch)",
             "tuple_digest_mismatch",
             "admission_vacuous",
             "route",
             %{
               "order" => row["identity"],
               "row_tuple_digest" => row["tuple_digest"],
               "route_tuple_digest" => digest
             }
           )}
        end

      {:refused, reason} ->
        {:refused,
         typed("REFUSED(tuple_refused)", "tuple_refused", "admission_vacuous", "route", %{
           "order" => row["identity"],
           "reason" => inspect(reason)
         })}
    end
  end

  defp item(row, tuple, digest, resolution) do
    capability = tuple["capability"]

    base = %{
      "order" => row["identity"],
      "iri" => row["iri"],
      "checkpoint_of" => row["checkpoint_of"],
      "capability" => capability,
      "provider" => capability |> String.split(":", parts: 2) |> hd(),
      "tuple_digest" => digest,
      "classification" => "Successor",
      "resolver" => "Xaas.Sa2a.Route.resolve/1"
    }

    case resolution do
      {:ok, {provider, recipe_id}} ->
        Map.merge(base, %{
          "resolve" => "ok",
          "route" => "KNOWN",
          "standing" => "UNKNOWN",
          "reason" => "provider_registered",
          "resolved" => %{"provider" => provider, "recipe_id" => recipe_id}
        })

      {:refused, :unregistered_capability} when capability == @unassigned ->
        Map.merge(base, %{
          "resolve" => "refused:unregistered_capability",
          "route" => "UNKNOWN",
          "standing" => "UNKNOWN",
          "reason" => "capability_unassigned"
        })

      {:refused, :unregistered_capability} ->
        Map.merge(base, %{
          "resolve" => "refused:unregistered_capability",
          "route" => "UNSUPPORTED",
          "standing" => "UNSUPPORTED(provider_capability)",
          "reason" => "provider_capability",
          "registered_capabilities" => registered_capabilities()
        })
    end
  end

  @doc "Capability ids the `:ultracode_construction_recipes` registry names, sorted."
  @spec registered_capabilities() :: [String.t()]
  def registered_capabilities do
    case Application.get_env(:xaas, :ultracode_construction_recipes, %{}) do
      %{} = map ->
        map |> Map.keys() |> Enum.map(&to_string/1)

      list when is_list(list) ->
        Enum.flat_map(list, fn
          {key, _value} -> [to_string(key)]
          %{} = entry -> [entry[:capability_id] || entry["capability_id"]]
          _other -> []
        end)

      _other ->
        []
    end
    |> Enum.reject(&is_nil/1)
    |> Enum.sort()
  end

  # -- helpers --------------------------------------------------------------------

  @doc "Canonical JSON: keys sorted recursively, pretty, trailing newline."
  @spec encode(term()) :: String.t()
  def encode(term), do: Jason.encode!(canonical(term), pretty: true) <> "\n"

  defp canonical(%{} = map) when not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(other), do: other

  defp typed(standing, reason, broken_term, hop, detail) do
    %{
      "standing" => standing,
      "reason" => reason,
      "broken_term" => broken_term,
      "hop" => hop,
      "detail" => detail
    }
  end
end
