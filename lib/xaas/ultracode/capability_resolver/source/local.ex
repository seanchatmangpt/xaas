defmodule Xaas.Ultracode.CapabilityResolver.Source.Local do
  @moduledoc """
  The in-repo LOCAL capability source of the resolution court: witnesses
  of capabilities this repo's own fabric already holds. It always works
  in-repo (the autonomic loop already needs the database to create a Run,
  so a read failure here is a real closure-visibility failure and is
  reported `{:error, _}` -- the court fail-closes to `:unresolved`).

  Witnesses (all read through the OWNING modules' existing actions and
  vocabularies -- never a duplicate projection of their semantics):

    * `Xaas.Ultracode.Run` rows with a non-nil `capability_id` that
      reached `state: :completed` -- the `sj:capabilityId` names a
      capability the fleet has actually executed to completion. One
      candidate per distinct id.
    * `Xaas.Ultracode.CapitalCensus.Resolution` rows with
      `outcome: :resolved` (the census's own
      `ResolutionOutcome.resolved` vocabulary), joined to their
      `CapitalCensus.WorkOrder` -- a RESOLVED work order whose `subject`
      matches the canonical `sj:capabilityId` pattern witnesses that the
      capability it names exists (`receipt_ref` rides along as the
      witness evidence).

  NOT witnesses: `CapitalCensus.Gap` rows. A Gap is the DEMAND side
  (`required_closure`/`residual_shape` -- what the fleet still lacks), so
  it can never mint a capability candidate; the court's residual side is
  where gap-shaped facts would surface, and that is the item's own
  declared requirements, not the census's.

  A subject/`capability_id` that does not match the canonical pattern is
  not force-fitted: it simply mints no candidate (pattern admission is
  the court's own `admit_candidates/2`, which would fail the whole source
  otherwise -- so this source pre-admits and drops nothing silently that
  could have been a satisfier: non-matching ids are not capability ids
  under the pattern the court admits).
  """

  @behaviour Xaas.Ultracode.CapabilityResolver.Source

  require Ash.Query

  alias Xaas.Ultracode.CapitalCensus.Resolution
  alias Xaas.Ultracode.Run
  alias Xaas.Ultracode.SemanticWork

  @impl true
  def candidates(_item, _ctx) do
    with {:ok, run_ids} <- completed_run_capability_ids(),
         {:ok, census_ids} <- resolved_work_order_ids() do
      {:ok, Enum.uniq(run_ids ++ census_ids)}
    end
  end

  # Capabilities the fleet has executed to completion: distinct
  # `capability_id`s over completed Runs. The capability satisfies
  # requirements equal to its own id (the mechanical capability_id
  # equality rule; free-text goals are never force-matched). `:read_unscoped`
  # is Run's deliberately-global internal read action (`Run`'s primary
  # `:read` is tenant-enforced); the loop's own readers use the same one.
  defp completed_run_capability_ids do
    ids =
      Run
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(state == :completed and not is_nil(capability_id))
      |> Ash.Query.select(:capability_id)
      |> Ash.read!(authorize?: false)
      |> Enum.map(& &1.capability_id)
      |> Enum.uniq()
      |> Enum.sort()

    {:ok,
     Enum.map(ids, fn id ->
       %{capability_id: id, satisfies: [id], witness: {:run, :completed}}
     end)}
  rescue
    error -> {:error, {:run_read_failed, Exception.message(error)}}
  end

  # Resolved census work orders whose subject IS a capability id.
  defp resolved_work_order_ids do
    resolutions =
      Resolution
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(outcome == :resolved)
      |> Ash.read!(authorize?: false)

    work_orders =
      resolutions
      |> Enum.map(& &1.work_order_id)
      |> case do
        [] ->
          %{}

        work_order_ids ->
          Xaas.Ultracode.CapitalCensus.WorkOrder
          |> Ash.Query.for_read(:read)
          |> Ash.Query.filter(id in ^work_order_ids)
          |> Ash.read!(authorize?: false)
          |> Map.new(&{&1.id, &1})
      end

    candidates =
      resolutions
      |> Enum.flat_map(fn resolution ->
        case Map.fetch(work_orders, resolution.work_order_id) do
          {:ok, work_order} ->
            census_candidate(work_order, resolution.receipt_ref)

          :error ->
            []
        end
      end)
      |> Enum.uniq_by(& &1.capability_id)

    {:ok, candidates}
  rescue
    error -> {:error, {:census_read_failed, Exception.message(error)}}
  end

  # A subject that does not match the canonical `sj:capabilityId` pattern
  # is not force-fitted: it mints no candidate at all.
  defp census_candidate(work_order, receipt_ref) do
    if Regex.match?(SemanticWork.capability_id_pattern(), work_order.subject) do
      [
        %{
          capability_id: work_order.subject,
          satisfies: [work_order.subject],
          witness: {:census_resolution, :resolved},
          receipt: receipt_ref
        }
      ]
    else
      []
    end
  end
end
