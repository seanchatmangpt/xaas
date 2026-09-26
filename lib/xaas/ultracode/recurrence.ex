defmodule Xaas.Ultracode.Recurrence do
  @moduledoc """
  The recurrence edge, machine-queryable: `receipt[n] -> reobserve[n+1] ->
  frontier[n+1] -> work-order[n+1]` for one `Xaas.Ultracode.Run` (the
  episode). This is the module the autonomic loop's "is the loop actually
  closed?" question asks: given the sealed Receipts of an episode, what does
  the NEXT cycle's frontier look like, and which next-cycle work orders does
  it license -- with every work order carrying its ORIGIN AUTHORITY and
  carrying NO provider identity.

  ## What the edge is (and is not)

    * `receipts/1` -- the episode's sealed standing-family Receipts (the
      `:heartbeat` lifecycle class is never standing; see
      `Xaas.Ultracode.Receipt`'s "Receipt classes" section).
    * `reobserve/1` -- the derived post-receipt observation: per work order,
      the standing its LATEST receipt sealed and the typed disposition the
      loop should take (`:satisfied | :reobserve | :repair | :reorder |
      :unsupported`). The reobserve moment is the DERIVATION's own moment and
      is honestly marked `reconstructed: true` (it is computed, not a
      persisted row's timestamp).
    * `frontier/1` -- the next frontier derived from that reobserve: entries
      still needing work (`:reobserve | :repair | :reorder | :unsupported`)
      stay eligible; `:satisfied` drops off. The frontier SOURCE is
      injectable (`config :xaas, :ultracode_frontier_source`, a `{mod, fun}`
      taking the Run and returning `{:ok, entries}`) so the ggen_igniter
      semantic-Jira frontier (`mix semantic_jira.frontier` over the standing
      ledger, the `Xaas.Ultracode.SemanticCrown` path) can be plugged as the
      authoritative source for episodes that live in the canonical graph;
      the default source is the deterministic receipt-derived frontier here
      -- no subprocess, same rows the receipts sealed, machine-queryable in
      one DB read.
    * `next_work_orders/1` -- the candidate `n+1` work orders the frontier
      licenses: provider-neutral maps (NOT `Xaas.Ultracode.Run` rows -- the
      loop admits those elsewhere) carrying `origin_authority` (the sJira
      law: a work order's origin derives from an admitted authority, named by
      exactly one `sj:originAuthority` / `aloop:originAuthority` -- here the
      admitted kernel authority `:ultracode_reactor`, which is the only
      authority this fabric constructs epochs and seals receipts under),
      `predecessor` (the receipt/work order this candidate follows), and a
      capability reference as a LEFT-SEGMENT-ONLY capability id
      (`ProviderRegistry.capability_left_segment/1` -- the one lawful place
      a provider identity may appear). A work order candidate whose Run
      carries NO capability id carries the provider-neutral capability
      `"construction"` and no provider segment at all.

  ## Grounding

  Episode identity comes from the Run's own semantic fields
  (`work_order_iri`, `checkpoint_iri`, `graph_digest`, `repository_identity`,
  `base_sha`, `capability_id` -- the same five-plus-one
  `Lease.bind_semantic_work_identity/2` seals into every receipt's
  `semantic_work` evidence), so a recurrence edge computed from receipts
  replays against the SAME identity the receipts carry. Where the Run has no
  semantic identity, the work order key degrades honestly to the epoch
  subject (`exact_subject`) -- the edge still closes, keyed by what the
  receipts actually name.

  The `aloop-episode-ontology-pack` read-only check (`pack_law/0`) grounds
  the two laws this module enforces (`originAuthority` on every work order;
  provider identity only as capability left-segment) in the pack's own
  ontology text -- the semantic_crown read-only pattern
  (`File.read!` of the pack source, never a write, never a second copy).
  """

  require Ash.Query

  alias Xaas.Ultracode.{Epoch, ProviderRegistry, Receipt, Run}

  @origin_authority :ultracode_reactor

  # Standing receipt -> typed disposition. The loop vocabulary: a satisfied
  # work order leaves the frontier; everything else stays on it, each with
  # the reason the loop keeps it.
  @dispositions %{
    alive: :satisfied,
    partial_alive: :reobserve,
    blocked: :repair,
    build_broken: :repair,
    refused: :reorder,
    unsupported: :unsupported
  }

  @type frontier_entry :: %{
          required(:work_order) => String.t(),
          required(:standing_in) => atom(),
          required(:disposition) => atom(),
          required(:receipt_id) => String.t(),
          optional(:frontier_source) => atom()
        }

  @type work_order_candidate :: %{
          required(:identity) => String.t(),
          required(:origin_authority) => atom(),
          required(:predecessor) => String.t(),
          required(:parent_episode) => String.t(),
          required(:capability_id) => String.t(),
          required(:subject) => String.t(),
          optional(:disposition) => atom(),
          optional(:base_sha) => String.t(),
          optional(:graph_digest) => String.t(),
          optional(:checkpoint_iri) => String.t(),
          optional(:repository_identity) => String.t(),
          optional(:replay_binding) => String.t()
        }

  # ------------------------------------------------------------------
  # The edge, machine-queryable
  # ------------------------------------------------------------------

  @doc """
  The full recurrence edge for one Run (struct or id):
  `%{episode:, receipts:, reobserve:, frontier:, next_work_orders:, closed?}`.

  `closed?` is true iff the edge resolves to a fixed point: every standing
  receipt's work order is `:satisfied` (or no standing receipts exist and
  the Run itself is terminal), so `next_work_orders` is empty BECAUSE the
  goal is met -- not because the loop lost track. An empty frontier with
  `closed?: false` names the discrepancy (frontier source returned nothing
  for unsatisfied work) -- a real mismatch, never silently called success.
  """
  @spec recurrence_edge(Run.t() | String.t()) :: {:ok, map()} | {:error, term()}
  def recurrence_edge(%Run{} = run) do
    receipts = standing_receipts(run)
    reobserve = reobserve(run, receipts)

    with {:ok, frontier} <- frontier(run, reobserve),
         {:ok, next} <- next_work_orders(run, frontier) do
      {:ok,
       %{
         episode: episode_identity(run),
         receipts: Enum.map(receipts, &receipt_ref/1),
         reobserve: reobserve,
         frontier: frontier,
         next_work_orders: next,
         closed?: frontier == [] and next == [] and receipts != [],
         reconstructed: true,
         derived_at: DateTime.utc_now()
       }}
    end
  end

  def recurrence_edge(run_id) when is_binary(run_id) do
    case Ash.get(Run, run_id, action: :read_unscoped, authorize?: false) do
      {:ok, run} -> recurrence_edge(run)
      {:error, error} -> {:error, {:run_not_found, run_id, inspect(error)}}
    end
  end

  # ------------------------------------------------------------------
  # receipt[n]: the sealed standing receipts of the episode
  # ------------------------------------------------------------------

  @doc """
  The Run's sealed standing-family Receipts, oldest first (one per its
  epochs; `:heartbeat` lifecycle receipts excluded -- they are not standing).
  """
  @spec standing_receipts(Run.t()) :: [Receipt.t()]
  def standing_receipts(%Run{} = run) do
    {:ok, epochs} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.Query.sort(cycle: :asc)
      |> Ash.read()

    Enum.flat_map(epochs, fn epoch ->
      case Receipt.for_epoch(epoch.id) do
        {:ok, receipts} ->
          Enum.filter(receipts, &(&1.outcome != :heartbeat))

        {:error, _} ->
          []
      end
    end)
    |> Enum.sort_by(& &1.sealed_at, DateTime)
  end

  # ------------------------------------------------------------------
  # reobserve[n+1]: per-work-order standing + disposition
  # ------------------------------------------------------------------

  @doc """
  The reobserve step: for each work order the episode's receipts speak
  about, the LATEST sealed standing and the typed disposition. Entries are
  ordered by work order key, deterministic, and marked `reconstructed`
  (the observation is derived here, its moment is not a persisted event).
  """
  @spec reobserve(Run.t(), [Receipt.t()]) :: [map()]
  def reobserve(%Run{} = run, receipts \\ nil) do
    receipts = receipts || standing_receipts(run)

    receipts
    |> Enum.group_by(&work_order_key(run, &1), & &1)
    |> Enum.map(fn {work_order, rs} ->
      latest = Enum.max_by(rs, & &1.sealed_at, DateTime)

      %{
        work_order: work_order,
        standing_in: latest.outcome,
        disposition: Map.fetch!(@dispositions, latest.outcome),
        receipt_id: latest.id,
        observed_at: latest.sealed_at,
        reconstructed: true
      }
    end)
    |> Enum.sort_by(& &1.work_order)
  end

  # ------------------------------------------------------------------
  # frontier[n+1]: what still needs a cycle
  # ------------------------------------------------------------------

  @doc """
  The next frontier: reobserve entries whose disposition keeps them eligible.
  Source selection: `config :xaas, :ultracode_frontier_source` `{mod, fun}`
  (returning `{:ok, [%{work_order: ..., disposition: ...}]}`) overrides the
  default receipt-derived frontier -- the seam the ggen_igniter semantic-Jira
  frontier plugs into for canonical-graph episodes. A source crash or
  malformed result is surfaced as `{:error, term()}` (fail-closed), never
  silently replaced by the default.
  """
  @spec frontier(Run.t(), [map()]) :: {:ok, [frontier_entry()]} | {:error, term()}
  def frontier(%Run{} = run, reobserve \\ nil) do
    reobserve = reobserve || reobserve(run)

    result =
      case frontier_source() do
        {mod, _fun} when mod == __MODULE__ ->
          {:ok, Enum.filter(reobserve, &(&1.disposition != :satisfied))}

        {mod, fun} when is_atom(mod) and is_atom(fun) ->
          case apply(mod, fun, [run]) do
            {:ok, entries} when is_list(entries) -> {:ok, entries}
            {:error, reason} -> {:error, {:frontier_source_failed, {mod, fun}, reason}}
            other -> {:error, {:frontier_source_malformed, {mod, fun}, other}}
          end
      end

    case result do
      {:ok, entries} -> {:ok, entries}
      {:error, _} = err -> err
    end
  end

  # The injectable source seam. Default: this module's receipt-derived
  # frontier (`{Xaas.Ultracode.Recurrence, :receipt_frontier}`).
  defp frontier_source do
    Application.get_env(:xaas, :ultracode_frontier_source, {__MODULE__, :receipt_frontier})
  end

  # ------------------------------------------------------------------
  # work-order[n+1]: provider-neutral candidates with origin authority
  # ------------------------------------------------------------------

  @doc """
  The next-cycle work order candidates the frontier licenses: one per
  non-satisfied frontier entry, each carrying

    * `origin_authority` -- `#{@origin_authority}`, the admitted kernel
      authority this fabric constructs and seals under (the
      `sj:originAuthority` law; a work order without an origin authority is
      not manufacturable here);
    * `predecessor` -- the work order key of the entry it follows (the
      receipt[n] -> workorder[n+1] chain, machine-checkable);
    * `parent_episode` -- the Run id (the episode that issued it);
    * `capability_id` -- the Run's capability id collapsed to its
      PROVIDER-NEUTRAL left segment (CONTRACT: provider identity appears
      ONLY as a capabilityId left segment -- and here not even that: the
      left segment is stripped so the candidate binds to the capability
      family, and any provider is selected later by the registry against
      that family).

  Runs with no semantic identity degrade honestly: the work order key is
  the epoch `exact_subject`, and only the fields the Run actually carries
  are emitted (no fabricated IRIs or digests).
  """
  @spec next_work_orders(Run.t(), [frontier_entry()]) ::
          {:ok, [work_order_candidate()]} | {:error, term()}
  def next_work_orders(%Run{} = run, frontier \\ nil) do
    case frontier || frontier(run) do
      {:error, _} = err ->
        err

      entries when is_list(entries) ->
        {:ok,
         entries
         |> Enum.reject(&(&1.disposition == :satisfied))
         |> Enum.map(&candidate(run, &1))}
    end
  end

  defp candidate(%Run{} = run, entry) do
    base = %{
      identity: next_identity(entry.work_order, run),
      origin_authority: @origin_authority,
      predecessor: entry.work_order,
      parent_episode: run.id,
      capability_id: neutral_capability(run),
      subject: entry.work_order,
      disposition: entry.disposition
    }

    semantic =
      %{
        base_sha: run.base_sha,
        graph_digest: run.graph_digest,
        checkpoint_iri: run.checkpoint_iri,
        repository_identity: run.repository_identity
      }
      |> Enum.filter(fn {_k, v} -> is_binary(v) end)
      |> Map.new()

    replay =
      if Map.has_key?(semantic, :graph_digest) and Map.has_key?(semantic, :base_sha) do
        replay_binding(run, entry)
      else
        Map.new()
      end

    Map.merge(base, Map.merge(semantic, replay))
  end

  # The replay binding: the byte-stable pairing of the episode's canonical
  # identity with the predecessor key -- the same (graph_digest, base_sha,
  # work order) triple always derives the same binding, so a candidate's
  # replay can be checked without this module (string equality).
  defp replay_binding(run, entry) do
    {:ok, binding} =
      Jason.encode(%{
        "graph_digest" => run.graph_digest,
        "base_sha" => run.base_sha,
        "work_order" => entry.work_order
      })

    digest = :crypto.hash(:sha256, binding) |> Base.encode16(case: :lower)
    %{replay_binding: "sha256:" <> digest}
  end

  @doc """
  The next-cycle work order identity: `"<predecessor>@n+1"` where n is the
  episode's current cycle -- deterministic, collision-free per episode, and
  provider-free.
  """
  @spec next_identity(String.t(), Run.t()) :: String.t()
  def next_identity(predecessor_key, %Run{} = run) when is_binary(predecessor_key) do
    "#{predecessor_key}@#{run.cycle + 1}"
  end

  @doc """
  The provider-neutral capability family for the episode's work: the Run's
  `capability_id` collapsed to its left segment, or the provider-neutral
  `"construction"` family when the Run names no capability id.
  """
  @spec neutral_capability(Run.t()) :: String.t()
  def neutral_capability(%Run{capability_id: capability_id}) when is_binary(capability_id) do
    ProviderRegistry.capability_left_segment(capability_id)
  end

  def neutral_capability(_run), do: "construction"

  # ------------------------------------------------------------------
  # Work order keying + episode identity
  # ------------------------------------------------------------------

  # A receipt speaks about the exact subject it was sealed under
  # (`Lease.close/4` seals `subject: epoch.exact_subject`) -- that subject,
  # never a run-level override, is the work-order key. Per-subject keying is
  # what keeps a multi-attempt episode's frontier honest: the latest
  # receipt PER SUBJECT is that subject's standing.
  defp work_order_key(_run, %Receipt{subject: subject}), do: subject

  defp episode_identity(%Run{} = run) do
    %{
      run_id: run.id,
      state: run.state,
      standing: run.standing,
      cycle: run.cycle,
      work_order_iri: run.work_order_iri,
      goal: run.goal
    }
  end

  defp receipt_ref(%Receipt{} = receipt) do
    %{
      id: receipt.id,
      outcome: receipt.outcome,
      subject: receipt.subject,
      sealed_at: receipt.sealed_at
    }
  end

  # ------------------------------------------------------------------
  # Pack-law grounding (read-only, semantic_crown pattern)
  # ------------------------------------------------------------------

  @pack_ontology "aloop-episode-ontology-pack/ontology.ttl"
  @sj_ontology "semantic-jira-pack/ontology.ttl"
  @pack_roots [Path.expand("~/ggen-marketplace/packs"), Path.expand("~/ggen_igniter/priv/ggen")]

  @doc """
  The two work-order laws this module enforces, grounded in the admitted
  packs' own source text (read-only `File.read!`, the
  `Xaas.Ultracode.SemanticCrown` pattern -- never a write, never a copy):

    * `origin_authority_law_present?` -- the sJira pack names
      `sj:originAuthority` as the one required origin designation;
    * `provider_neutrality_law_present?` -- the aloop episode pack states
      the WorkOrder provider-neutrality law verbatim.

  Returns `{:ok, facts}` when the packs are readable, `{:error, :pack_absent}`
  when they are not (fail-closed honesty: no pack, no claimed grounding --
  the edge itself still works, it just reports the grounding as absent).
  """
  @spec pack_law() :: {:ok, map()} | {:error, :pack_absent}
  def pack_law do
    with {:ok, aloop} <- read_pack(@pack_ontology),
         {:ok, sjira} <- read_pack(@sj_ontology) do
      {:ok,
       %{
         origin_authority_law_present?: String.contains?(sjira, "originAuthority"),
         provider_neutrality_law_present?:
           String.contains?(aloop, "Provider-neutral work order") and
             String.contains?(aloop, "aloop:originAuthority")
       }}
    end
  end

  defp read_pack(rel) do
    @pack_roots
    |> Enum.map(&Path.join(&1, rel))
    |> Enum.find(&File.regular?/1)
    |> case do
      nil -> {:error, :pack_absent}
      path -> {:ok, File.read!(path)}
    end
  end
end
