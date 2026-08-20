defmodule Xaas.Operations.CapabilityLivenessRegressions do
  @moduledoc """
  Real autonomic "Analyze" step: given the real ingested history in
  `Xaas.Operations.CapabilityLivenessReceipt` (one row per
  capability+subject/commit, upserted from real `weaver-live-matrix.sh`
  runs by `mix xaas.ingest_capability_receipts`), detect any capability
  whose most recent real run is not `ALIVE` while an earlier real run was.

  This is a genuine state-change detector over real, previously-ingested
  rows -- it never re-derives status itself, only compares what was
  already observed and recorded. Ordering is by `inserted_at` (ingest
  time), so "most recent" means "most recently observed live", which is
  the real, meaningful ordering for a regression alert (subjects/commits
  are not necessarily chronologically monotonic across branches).
  """

  alias Xaas.Operations.CapabilityLivenessReceipt

  @doc """
  Returns a list of `%{capability: ..., was: %{status:, subject:}, now: %{status:, subject:}}`
  maps for every capability whose latest real ingest is non-ALIVE after a
  real prior ALIVE ingest. Empty list when there is no real regression.
  """
  def detect(opts \\ []) do
    # Real fix (found via adversarial review): this used to default to
    # `false`, an undocumented second authorize?:false path independent
    # of the resource's own real `bypass action_type(:read)` policy --
    # harmless only by coincidence (that policy already grants :read to
    # everyone), and inaccurate against the "only the ingest task
    # bypasses" claim elsewhere in this codebase. Defaulting to `true`
    # means this function goes through the real Ash policy like any
    # other caller unless a caller (e.g. an internal Mix task) opts out
    # explicitly and visibly.
    authorize? = Keyword.get(opts, :authorize?, true)

    CapabilityLivenessReceipt
    |> Ash.read!(authorize?: authorize?)
    |> Enum.group_by(& &1.capability)
    |> Enum.flat_map(fn {capability, rows} ->
      sorted = Enum.sort_by(rows, & &1.inserted_at, {:asc, DateTime})

      case Enum.reverse(sorted) do
        [%{status: latest_status} = latest | [%{status: prev_status} = prev | _]]
        when latest_status != "ALIVE" and prev_status == "ALIVE" ->
          [
            %{
              capability: capability,
              was: %{status: prev.status, subject: prev.subject},
              now: %{status: latest.status, subject: latest.subject}
            }
          ]

        _ ->
          []
      end
    end)
  end
end
