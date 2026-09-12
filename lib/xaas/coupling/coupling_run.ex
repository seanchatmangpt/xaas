defmodule Xaas.Coupling.CouplingRun do
  @moduledoc """
  Real Ash admission/validation path for the formal proposal coupling engine
  ticket (`docs/jira/v26.9.11/formal-proposal-coupling-engine.md`).

  Persists an input proposal set + constraint set, runs it through
  `Xaas.Coupling.Engine.couple/2` (the real, closed-form box-constrained
  solver -- see that module's moduledoc), and stores whichever of the
  engine's four outcomes actually occurred:

  - `:solved` -- `z`, `weights`, and `receipt` are populated.
  - `:infeasible` -- box constraints conflict; `unsupported_reason` holds
    the minimal unsatisfiable constraint explanation.
  - `:unsupported` -- the proposal set required general affine (`A`/`E`)
    constraints this engine does not solve; `unsupported_reason` explains
    why, per the ticket's own falsifier about honest scope limits.
  - `:error` -- malformed input (empty set, mismatched dimensions).

  This resource is the "one concrete admission/validation path wired into
  the existing Ash/Reactor boundary" required by this ticket's implementation
  slice. It does not attempt the general QP/LP/MILP/CP backends, the full
  minimal-unsatisfiable-constraint-extraction machinery for the general
  affine case, or any Reactor-level orchestration across multiple coupling
  runs -- those remain out of scope for this pass (see `unsupported_reason`
  on any run whose constraints go beyond box bounds).
  """
  use Ash.Resource,
    domain: Xaas.Coupling,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("coupling_runs")
    repo(Xaas.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    # Canonical proposal representation: a list of
    # %{"id" => binary, "vector" => [number], "confidence" => float in
    # [0,1], "staleness" => float >= 0}. Stored as submitted, for
    # provenance/replay.
    attribute(:proposals, {:array, :map}, allow_nil?: false, public?: true)

    # Normalized constraint representation: optional "lower"/"upper" bound
    # vectors and optional "a_ineq"/"b_ineq"/"e_eq"/"f_eq" general affine
    # terms. Only the bound-only case is solved by this pass; a non-empty
    # a_ineq/e_eq produces status :unsupported (see moduledoc).
    attribute(:constraints, :map, allow_nil?: false, default: %{}, public?: true)

    attribute(:status, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: [:solved, :infeasible, :unsupported, :error]]
    )

    attribute(:z, {:array, :float}, allow_nil?: true, public?: true)
    attribute(:weights, :map, allow_nil?: true, public?: true)
    attribute(:receipt, :map, allow_nil?: true, public?: true)
    attribute(:unsupported_reason, :map, allow_nil?: true, public?: true)

    attribute(:requested_at, :utc_datetime_usec, allow_nil?: true, public?: true)

    timestamps()
  end

  actions do
    defaults([:read])

    create :couple do
      accept([:proposals, :constraints])

      change(fn changeset, _context ->
        raw_proposals = Ash.Changeset.get_attribute(changeset, :proposals) || []
        raw_constraints = Ash.Changeset.get_attribute(changeset, :constraints) || %{}

        proposals = Enum.map(raw_proposals, &normalize_proposal/1)
        constraints = normalize_constraints(raw_constraints)

        changeset
        |> Ash.Changeset.force_change_attribute(:requested_at, DateTime.utc_now())
        |> apply_engine_result(Xaas.Coupling.Engine.couple(proposals, constraints))
      end)
    end
  end

  # -- input normalization (accepts string- or atom-keyed maps, since JSON
  # transport and direct Elixir callers both need to work) -----------------

  defp normalize_proposal(p) do
    %{
      id: fetch(p, :id) |> to_string(),
      vector: fetch(p, :vector) || [],
      confidence: fetch(p, :confidence) * 1.0,
      staleness: fetch(p, :staleness) * 1.0
    }
  end

  defp normalize_constraints(c) do
    %{
      lower: fetch(c, :lower),
      upper: fetch(c, :upper),
      a_ineq: fetch(c, :a_ineq),
      b_ineq: fetch(c, :b_ineq),
      e_eq: fetch(c, :e_eq),
      f_eq: fetch(c, :f_eq)
    }
  end

  defp fetch(map, key) when is_map(map) do
    Map.get(map, key) || Map.get(map, to_string(key))
  end

  # -- engine result -> changeset --------------------------------------------

  defp apply_engine_result(changeset, {:ok, %{z: z, weights: weights, receipt: receipt}}) do
    changeset
    |> Ash.Changeset.force_change_attribute(:status, :solved)
    |> Ash.Changeset.force_change_attribute(:z, z)
    |> Ash.Changeset.force_change_attribute(:weights, weights)
    |> Ash.Changeset.force_change_attribute(:receipt, stringify_receipt(receipt))
  end

  defp apply_engine_result(changeset, {:infeasible, explanation}) do
    changeset
    |> Ash.Changeset.force_change_attribute(:status, :infeasible)
    |> Ash.Changeset.force_change_attribute(:unsupported_reason, stringify(explanation))
  end

  defp apply_engine_result(changeset, {:unsupported, explanation}) do
    changeset
    |> Ash.Changeset.force_change_attribute(:status, :unsupported)
    |> Ash.Changeset.force_change_attribute(:unsupported_reason, stringify(explanation))
  end

  defp apply_engine_result(changeset, {:error, explanation}) do
    changeset
    |> Ash.Changeset.force_change_attribute(:status, :error)
    |> Ash.Changeset.force_change_attribute(:unsupported_reason, stringify(explanation))
    |> Ash.Changeset.add_error(
      field: :proposals,
      message: "coupling engine rejected input: #{inspect(explanation)}"
    )
  end

  # :map attributes go through Jason encoding for JSONB storage -- atom
  # keys/values (e.g. `:lower`, `:neg_infinity`) round-trip fine through
  # Jason.encode but come back as strings on read, so normalize to strings
  # up front for a stable, inspectable stored shape.
  defp stringify(term) when is_map(term) do
    Map.new(term, fn {k, v} -> {to_string(k), stringify(v)} end)
  end

  defp stringify(term) when is_list(term), do: Enum.map(term, &stringify/1)

  defp stringify(term) when is_atom(term) and not is_boolean(term) and not is_nil(term),
    do: to_string(term)

  defp stringify(term), do: term

  defp stringify_receipt(receipt) do
    Map.new(receipt, fn {coord, {kind, detail}} ->
      {to_string(coord), %{"kind" => to_string(kind), "detail" => stringify(detail)}}
    end)
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass action(:couple) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end
end
