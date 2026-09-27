defmodule Xaas.Ultracode.ProviderRegistry do
  @moduledoc """
  The provider registry + selection predicate for the execution fabric --
  closes `UNSUPPORTED(provider-selection:policy)`: before this module the
  only provider knowledge in the codebase was the hardcoded string
  `"zcode"` (`Dispatch`'s `:provider` default, `ExecutionFabricController`'s
  `claim_next` fallback, `ProviderHealth`'s implicit single-provider
  assumption) plus per-provider side registries that each carried ONE facet
  (`:ultracode_provider_tools` the tool vocabulary, `:ultracode_pool_capacity`
  the slot bound, `:ultracode_actuation_registry` the DO pairs). None of them
  could answer "which provider should run this work order, and under what
  ceiling" -- and there was no typed refusal for "no provider can".

  One config registry carries ALL facets per provider id, imitating the
  established `:ultracode_provider_tools` / `:ultracode_construction_recipes`
  Application-env convention (`config/config.exs`):

      config :xaas, :ultracode_providers, %{
        "zcode" => %{
          capabilities: ["construction", "gall_work"],
          transport: %{kind: "zcode_cli"},
          authority_ceiling: :construction,
          receipt_protocol: "gall.work-receipt/1",
          enabled: true,
          cost: 1,
          concurrency: 5
        }
      }

  Entry fields (all optional except the ones marked required -- a missing
  optional field means "unconstrained", never "zero"):

    * `capabilities` -- list of capability-id strings this provider satisfies.
      The CONTRACT law: a capability id's LEFT SEGMENT (`"provider:id"` up to
      the first `:`) is the only lawful provider identity in a request; see
      `capability_left_segment/1`.
    * `transport` -- opaque descriptor (map or string). The zcode-family
      transport MAY pin `:cli_dir` / `:node_path`; `Xaas.Ultracode.Dispatch`
      and `Xaas.Ultracode.ProviderHealth` consult that pin ahead of the app-env
      fallbacks. Any other shape is descriptor-only.
    * `authority_ceiling` -- one of `@authority_ranks` (`:none < :construction
      < :actuation`). Selection refuses a provider whose ceiling ranks below
      the work order's required authority. Unknown atoms rank NOWHERE and are
      refused (fail-closed, `UNKNOWN != REVERSIBLE`).
    * `receipt_protocol` -- free string naming the receipt shape the provider
      closes with (the fabric's own `Xaas.Ultracode.Receipt` is
      provider-neutral; this field is the provider's wire contract).
    * `enabled` -- `false` is the operator kill switch (`disable/1`): a
      disabled provider is INVISIBLE to selection (mid-episode provider
      disappearance routes work elsewhere or fails typed -- never a silent
      default and never a human wait).
    * `cost` -- non-negative number; the default selection policy orders by
      ascending cost (ties broken by provider id, so selection is
      deterministic).
    * `concurrency` -- advisory in-flight bound; informational here (the
      ENFORCED per-provider pool bound remains `Lease.pool_capacity/1` over
      `config :xaas, :ultracode_pool_capacity`), carried so operators see one
      registry, not two half-registries.

  Provider neutrality: NOTHING in this module writes a provider id into a
  work order, a receipt schema, a replay binding, or an authority grant.
  Selection READS provider descriptors; the chosen provider id travels only
  as the claim's `run.provider` / capability left-segment, exactly as the
  CONTRACT and the `aloop-episode-ontology-pack` (`aloop:WorkOrder`) require.
  """

  # Ranked authority vocabulary (lowest first). A provider may act up to its
  # ceiling; a work order requiring more than the ceiling is not satisfiable
  # by that provider. Unknown terms fail closed in `rank/1`.
  @authority_ranks [:none, :construction, :actuation]

  @typedoc "Provider id -- the registry map's key (free string, e.g. \"zcode\")."
  @type provider_id :: String.t()

  @type entry :: %{
          optional(:capabilities) => [String.t()],
          optional(:transport) => map() | String.t(),
          optional(:authority_ceiling) => atom(),
          optional(:receipt_protocol) => String.t(),
          optional(:enabled) => boolean(),
          optional(:cost) => number(),
          optional(:concurrency) => pos_integer()
        }

  @type required :: %{
          optional(:capabilities) => [String.t()],
          optional(:authority) => atom()
        }

  @spec authority_ranks :: [atom()]
  def authority_ranks, do: @authority_ranks

  # ------------------------------------------------------------------
  # Registry access
  # ------------------------------------------------------------------

  @doc """
  The whole registry from `config :xaas, :ultracode_providers`. Unset config
  is the EMPTY registry (fail-closed: nothing is selectable), not a default
  provider.
  """
  @spec registry() :: %{provider_id() => entry()}
  def registry do
    case Application.get_env(:xaas, :ultracode_providers) do
      %{} = reg -> reg
      _ -> %{}
    end
  end

  @doc """
  One provider's entry, or `{:error, {:unknown_provider, id}}` -- a typed
  lookup, never a synthesized default entry.
  """
  @spec lookup(provider_id()) :: {:ok, entry()} | {:error, {:unknown_provider, provider_id()}}
  def lookup(provider_id) when is_binary(provider_id) do
    case Map.fetch(registry(), provider_id) do
      {:ok, entry} -> {:ok, entry}
      :error -> {:error, {:unknown_provider, provider_id}}
    end
  end

  @doc """
  The default provider id used when a caller supplies none:
  `config :xaas, :ultracode_default_provider`, defaulting to `"zcode"` --
  the same default the fabric has always used, now named in ONE place
  instead of hardcoded at every call site.
  """
  @spec default_provider() :: provider_id()
  def default_provider do
    Application.get_env(:xaas, :ultracode_default_provider, "zcode")
  end

  # Operator kill switch / re-arm -- mutates the Application env registry the
  # same way the existing per-provider registries are mutated in operations
  # and tests (`Application.put_env` + restore). A disabled provider keeps its
  # registry entry (no config loss) but leaves every selection path.
  @doc """
  Disables `provider_id` in the live Application-env registry (the
  mid-episode disappearance operation: `enabled: false`). Returns the
  previous enabled state, or `{:error, {:unknown_provider, id}}`.
  """
  @spec disable(provider_id()) :: boolean() | {:error, {:unknown_provider, provider_id()}}
  def disable(provider_id), do: set_enabled(provider_id, false)

  @doc """
  Re-enables `provider_id` (undoes `disable/1`). Returns the previous state.
  """
  @spec enable(provider_id()) :: boolean() | {:error, {:unknown_provider, provider_id()}}
  def enable(provider_id), do: set_enabled(provider_id, true)

  defp set_enabled(provider_id, value) when is_binary(provider_id) do
    reg = registry()

    case Map.fetch(reg, provider_id) do
      {:ok, entry} ->
        previous = Map.get(entry, :enabled, true)
        entry = Map.put(entry, :enabled, value)
        Application.put_env(:xaas, :ultracode_providers, Map.put(reg, provider_id, entry))
        previous

      :error ->
        {:error, {:unknown_provider, provider_id}}
    end
  end

  # ------------------------------------------------------------------
  # Selection
  # ------------------------------------------------------------------

  @doc """
  Selects the provider for one unit of work: the qualifying providers are
  those whose entry is `enabled`, whose `capabilities` cover
  `required[:capabilities]`, and whose `authority_ceiling` ranks at or above
  `required[:authority]` (default `:construction`). Ordered by
  `opts[:policy]`:

    * `:cost` (default) -- ascending `cost` (missing cost = `0`), ties by id;
    * `:capability` -- descending capability count, ties by id;
    * `:name` -- ascending id.

  Returns `{:ok, provider_id, entry}` for the first qualifying provider, or
  the typed refusal `{:error, {:no_qualifying_provider, details}}` naming
  EVERY candidate's rejection reason -- never a silent default, never a
  best-guess fallback. An empty registry and an empty candidate list are the
  same typed refusal (nothing was selectable), distinguishable in `details`.
  """
  @spec select(required(), keyword()) ::
          {:ok, provider_id(), entry()} | {:error, {:no_qualifying_provider, [map()]}}
  def select(required, opts \\ []) when is_map(required) and is_list(opts) do
    required_caps = List.wrap(Map.get(required, :capabilities, []))
    required_authority = Map.get(required, :authority, :construction)
    policy = Keyword.get(opts, :policy, :cost)
    candidates = Keyword.get(opts, :candidates, nil) || Enum.sort(Map.keys(registry()))

    rejections =
      candidates
      |> Enum.map(fn provider_id ->
        {provider_id, judge(provider_id, required_caps, required_authority)}
      end)

    qualifying =
      for {provider_id, {:ok, entry}} <- rejections do
        {provider_id, entry}
      end

    case order(qualifying, policy) do
      [{provider_id, entry} | _] -> {:ok, provider_id, entry}
      [] -> {:error, {:no_qualifying_provider, rejections_map(rejections)}}
    end
  end

  @doc """
  Selects and CLAIMS in one step when a caller wants the fabric to route the
  work immediately: `select/2` over `required`, then
  `Xaas.Ultracode.Lease.claim_next_among/3` pinned to the chosen provider.
  Selection failure and claim failure are both typed; the claim is never
  silently re-routed past the selected provider (the caller decides whether
  to re-select -- that is `Lease.claim_next_among/3`'s own contract).
  """
  @spec select_and_claim(required(), String.t() | nil, keyword()) ::
          {:ok, Xaas.Ultracode.Epoch.t(), String.t(), Xaas.Ultracode.Run.t()}
          | {:error, term()}
  def select_and_claim(required, worker_id, opts \\ []) do
    {select_opts, claim_opts} = Keyword.split(opts, [:policy, :candidates])

    with {:ok, provider_id, _entry} <- select(required, select_opts) do
      Xaas.Ultracode.Lease.claim_next(provider_id, worker_id, claim_opts)
    end
  end

  # The per-candidate admission court: `{:ok, entry}` or the typed rejection
  # reason. Every branch is a named fact, so `select/2`'s refusal details can
  # name exactly why each provider lost.
  defp judge(provider_id, required_caps, required_authority) do
    case Map.fetch(registry(), provider_id) do
      :error ->
        {:error, :unknown_provider}

      {:ok, entry} ->
        cond do
          Map.get(entry, :enabled, true) != true ->
            {:error, :disabled}

          not satisfies_capabilities?(entry, required_caps) ->
            {:error, {:missing_capabilities, required_caps -- entry_capabilities(entry)}}

          # Fail-closed on BOTH terms: an entry with no (or a misspelled)
          # ceiling has NO rank -- it can satisfy only work requiring no
          # authority, never the reverse ("a missing optional field" never
          # degrades into an implicit grant). An unknown REQUIRED term is
          # likewise a typed rejection, never silently treated as :none.
          not ranked?(Map.get(entry, :authority_ceiling)) or
              not ranked?(required_authority) ->
            {:error, :unknown_authority_term}

          rank(Map.get(entry, :authority_ceiling)) < rank(required_authority) ->
            {:error, {:authority_ceiling_too_low, Map.get(entry, :authority_ceiling)}}

          true ->
            {:ok, entry}
        end
    end
  end

  # Capability satisfaction: the provider's declared capability list must
  # cover every required capability id. A provider with NO capabilities field
  # satisfies only the empty requirement (unconstrained-but-empty stays
  # honest: it did not declare what it cannot do).
  defp satisfies_capabilities?(_entry, []), do: true

  defp satisfies_capabilities?(entry, required_caps),
    do: required_caps -- entry_capabilities(entry) == []

  defp entry_capabilities(entry), do: List.wrap(Map.get(entry, :capabilities, []))

  # Rank lookup. Unknown authority terms have NO rank -- `ranked?/1` gates
  # before any comparison so an unknown term is a typed rejection, never a
  # silent pass through term-ordering comparison.
  defp rank(term) when term in @authority_ranks,
    do: Enum.find_index(@authority_ranks, &(&1 == term))

  defp rank(_unknown), do: nil

  defp ranked?(term), do: term in @authority_ranks

  defp order(qualifying, :cost) do
    Enum.sort_by(qualifying, fn {id, entry} -> {cost(entry), id} end)
  end

  defp order(qualifying, :capability) do
    Enum.sort_by(qualifying, fn {id, entry} -> {-length(entry_capabilities(entry)), id} end)
  end

  defp order(qualifying, :name), do: Enum.sort_by(qualifying, fn {id, _} -> id end)

  defp order(_qualifying, other),
    do: raise(ArgumentError, "unknown selection policy #{inspect(other)}")

  defp cost(entry), do: Map.get(entry, :cost, 0)

  defp rejections_map(rejections) do
    Enum.map(rejections, fn {provider_id, verdict} ->
      reason =
        case verdict do
          {:error, reason} -> reason
          reason -> reason
        end

      %{provider: provider_id, verdict: reason}
    end)
  end

  # ------------------------------------------------------------------
  # Capability-id law (CONTRACT: provider identity lives ONLY here)
  # ------------------------------------------------------------------

  @doc """
  The capability id's LEFT SEGMENT -- the one lawful place a provider
  identity may appear in a work order (`"zcode:fix-build"` -> `"zcode"`;
  a capability id with no `:` segment names a provider-neutral capability and
  returns it whole). Mirrors `aloop:Capability`'s own law in the
  `aloop-episode-ontology-pack`.
  """
  @spec capability_left_segment(String.t()) :: String.t()
  def capability_left_segment(capability_id) when is_binary(capability_id) do
    case String.split(capability_id, ":", parts: 2) do
      [left, _right] -> left
      [whole] -> whole
    end
  end
end
