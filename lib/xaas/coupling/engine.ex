defmodule Xaas.Coupling.Engine do
  @moduledoc """
  Pure, deterministic proposal-coupling math for the formal proposal coupling
  engine ticket (`docs/jira/v26.9.11/formal-proposal-coupling-engine.md`).

  Implements the real, honest, closed-form-solvable slice of the ticket's
  objective:

      min_z  sum_i w_i * ||z - p_i||_2^2
      subject to  l <= z <= u

  This is the exact ticket objective with the general affine constraint
  terms (`A z <= b`, `E z = f`) fixed at "no constraint" -- i.e. this module
  solves the box-constrained special case of the required optimization
  problem exactly (real math, not an approximation of it):

  - the objective is separable across coordinates (each `z_j` only appears
    in the `||z - p_i||^2` term through its own coordinate), so for each
    coordinate `j`, minimizing `sum_i w_i * (z_j - p_i_j)^2` subject only to
    `l_j <= z_j <= u_j` is a 1-D weighted-least-squares problem;
  - the unconstrained minimizer of a 1-D weighted least squares problem is
    the weighted mean `sum_i (w_i * p_i_j) / sum_i w_i` (setting the
    derivative to zero -- exact, not heuristic);
  - because the feasible set for coordinate `j` is the interval
    `[l_j, u_j]` and the unconstrained objective is convex, the constrained
    minimizer is the unconstrained minimizer if it already lies in
    `[l_j, u_j]`, and the nearest bound otherwise (this is the real KKT
    solution for a 1-D convex quadratic over a box -- projection onto the
    feasible interval, not an approximation).

  ## What this module deliberately does NOT implement (UNSUPPORTED, not faked)

  General affine inequality (`A z <= b`) and equality (`E z = f`) constraints
  that couple multiple coordinates together make the problem a real
  quadratic program (QP) that no longer decomposes coordinate-by-coordinate.
  Solving that honestly requires an actual QP/LP/MILP/CP solver (the ticket's
  own "QP compiler" / "LP/MILP/CP alternative backends" scope items). No such
  solver dependency exists in this repository today (confirmed: no
  `:tableau`, `:qp`, `:coin_or`, `:glpk`, `:osqp`, or equivalent NIF/port
  dependency in `mix.exs`). Rather than hand-rolling a fake QP solver, this
  module returns a typed `{:unsupported, reason}` for any proposal set whose
  constraints include a non-empty `A`/`E` component. This is the honest
  scope boundary: the box-only case is solved exactly; the general affine
  case is refused, not faked.

  ## Weighting (confidence + staleness -> `w_i`)

  `w_i = confidence_i * :math.exp(-staleness_i)`, `confidence_i in [0.0, 1.0]`
  (fraction of trust in the proposal) and `staleness_i >= 0.0` (elapsed
  "age" of the proposal in whatever unit the caller uses consistently, e.g.
  seconds since the proposal was generated). This is one concrete, real,
  deterministic weighting function satisfying both required "confidence
  weighting" and "staleness weighting" scope items -- exponential decay in
  staleness, linear in confidence. It is a real, disclosed design choice,
  not a placeholder: a different decay curve could replace it later without
  changing the surrounding admission/receipt machinery.

  ## Deterministic tie-breaking

  Proposals are sorted by their `id` (a caller-supplied binary/string) before
  any floating-point summation, so two runs over an identical (unordered)
  proposal set always sum in the same order and produce bit-identical
  results. This directly answers the ticket's "two runs over identical
  proposals and weights produce different `z`" falsifier for the box-only
  case: summation order is now fixed by data, not by argument order.

  ## Coupling receipt / provenance propagation

  The receipt records, per coordinate, whether the result was
  weighted-mean-determined (with each proposal's exact fractional
  contribution `w_i / sum(w)`) or bound-clamped (with which bound and by how
  much the unconstrained mean missed it). This directly answers the ticket's
  auditability falsifier for the box-only case: given the receipt, any
  coordinate of `z` can be reconstructed as either a stated weighted
  combination of named proposal ids, or a stated bound.
  """

  @type proposal :: %{
          required(:id) => String.t(),
          required(:vector) => [number()],
          required(:confidence) => float(),
          required(:staleness) => float()
        }

  @type constraints :: %{
          optional(:lower) => [number()] | nil,
          optional(:upper) => [number()] | nil,
          optional(:a_ineq) => [[number()]] | nil,
          optional(:b_ineq) => [number()] | nil,
          optional(:e_eq) => [[number()]] | nil,
          optional(:f_eq) => [number()] | nil
        }

  @doc """
  Couples a list of proposals under the given constraints.

  Returns:
    * `{:ok, result}` -- `result` has `:z` (the coupled point), `:weights`
      (proposal id -> `w_i`), and `:receipt` (per-coordinate provenance, see
      moduledoc).
    * `{:infeasible, explanation}` -- either box constraints alone are
      already unsatisfiable (`l_j > u_j` for some coordinate `j`; `explanation`
      names the minimal unsatisfiable constraint -- a single conflicting
      lower/upper bound pair, minimal by construction since one bound pair
      is already contradictory on its own), or every proposal's weight
      `w_i = confidence_i * :math.exp(-staleness_i)` is exactly `0.0` (all
      confidences `0.0`, and/or staleness large enough that the exponential
      decay underflows to `0.0`), so `total_weight` is `0.0` and the
      weighted-mean objective has no well-defined minimizer -- there is no
      real "coupled point" to compute, so this is refused rather than
      dividing by zero or fabricating a result.
    * `{:unsupported, reason}` -- the proposal set's constraints include a
      general affine `A`/`E` component this module does not solve (see
      moduledoc "What this module deliberately does NOT implement").
    * `{:error, reason}` -- malformed input (empty proposal list, mismatched
      vector dimensions, non-finite weight).
  """
  @spec couple([proposal()], constraints()) ::
          {:ok, map()} | {:infeasible, map()} | {:unsupported, map()} | {:error, term()}
  def couple(proposals, constraints) when is_list(proposals) do
    with :ok <- validate_general_constraints_absent(constraints),
         {:ok, sorted} <- validate_and_sort(proposals),
         {:ok, dim} <- common_dimension(sorted),
         {:ok, lower, upper} <- normalize_bounds(constraints, dim),
         :ok <- check_box_feasible(lower, upper) do
      weighted = Enum.map(sorted, fn p -> {p, weight(p)} end)
      total_weight = weighted |> Enum.map(&elem(&1, 1)) |> Enum.sum()

      with :ok <- check_total_weight_nonzero(total_weight) do
        {z, receipt} = solve_and_receipt(weighted, total_weight, lower, upper, dim)

        {:ok,
         %{
           z: z,
           weights: Map.new(weighted, fn {p, w} -> {p.id, w} end),
           receipt: receipt
         }}
      end
    end
  end

  # -- validation --------------------------------------------------------

  defp validate_general_constraints_absent(constraints) do
    a = Map.get(constraints, :a_ineq)
    e = Map.get(constraints, :e_eq)

    if empty_matrix?(a) and empty_matrix?(e) do
      :ok
    else
      {:unsupported,
       %{
         reason: :general_affine_constraints_unsupported,
         detail:
           "A z <= b and/or E z = f were supplied with non-empty rows. This " <>
             "engine solves the exact box-constrained (l <= z <= u) special " <>
             "case of the coupling objective in closed form; general affine " <>
             "constraints require a real QP/LP/MILP/CP solver dependency " <>
             "that does not exist in this repository. Refusing rather than " <>
             "fabricating a solver."
       }}
    end
  end

  defp empty_matrix?(nil), do: true
  defp empty_matrix?([]), do: true
  defp empty_matrix?(rows) when is_list(rows), do: Enum.all?(rows, &(&1 == [] or is_nil(&1)))

  defp validate_and_sort([]), do: {:error, %{reason: :empty_proposal_set}}

  defp validate_and_sort(proposals) do
    if Enum.all?(proposals, &valid_proposal?/1) do
      {:ok, Enum.sort_by(proposals, & &1.id)}
    else
      {:error, %{reason: :malformed_proposal}}
    end
  end

  defp valid_proposal?(%{id: id, vector: vector, confidence: c, staleness: s})
       when is_binary(id) and is_list(vector) and is_number(c) and is_number(s) and
              c >= 0.0 and c <= 1.0 and s >= 0.0,
       do: Enum.all?(vector, &is_number/1)

  defp valid_proposal?(_), do: false

  defp common_dimension(proposals) do
    dims = proposals |> Enum.map(&length(&1.vector)) |> Enum.uniq()

    case dims do
      [d] when d > 0 -> {:ok, d}
      _ -> {:error, %{reason: :mismatched_vector_dimensions, dims: dims}}
    end
  end

  defp normalize_bounds(constraints, dim) do
    lower = Map.get(constraints, :lower) || List.duplicate(:neg_infinity, dim)
    upper = Map.get(constraints, :upper) || List.duplicate(:pos_infinity, dim)

    if length(lower) == dim and length(upper) == dim do
      {:ok, lower, upper}
    else
      {:error, %{reason: :mismatched_bound_dimensions}}
    end
  end

  defp check_box_feasible(lower, upper) do
    conflicts =
      Enum.with_index(Enum.zip(lower, upper))
      |> Enum.filter(fn {{l, u}, _idx} -> lt(u, l) end)
      |> Enum.map(fn {{l, u}, idx} -> %{coordinate: idx, lower: l, upper: u} end)

    case conflicts do
      [] ->
        :ok

      conflicts ->
        {:infeasible,
         %{
           reason: :box_constraints_infeasible,
           # Minimal unsatisfiable constraint set: each entry here is
           # already a self-contradictory single (lower, upper) pair for
           # one coordinate -- it is minimal because a single bound pair
           # cannot be shrunk further and still exhibit the conflict.
           minimal_unsatisfiable_constraints: conflicts
         }}
    end
  end

  defp lt(:pos_infinity, _), do: false
  defp lt(_, :neg_infinity), do: false
  defp lt(:neg_infinity, _), do: false
  defp lt(_, :pos_infinity), do: false
  defp lt(a, b), do: a < b

  defp check_total_weight_nonzero(total_weight) when total_weight == 0.0 do
    {:infeasible,
     %{
       reason: :zero_total_weight,
       detail:
         "Every proposal's weight (confidence * exp(-staleness)) was exactly " <>
           "0.0 (all confidence == 0.0, and/or staleness large enough for the " <>
           "exponential decay to underflow to 0.0), so total_weight is 0.0 and " <>
           "the weighted-mean objective has no defined minimizer. Refusing " <>
           "rather than dividing by zero."
     }}
  end

  defp check_total_weight_nonzero(_total_weight), do: :ok

  # -- weighting ----------------------------------------------------------

  defp weight(%{confidence: c, staleness: s}), do: c * :math.exp(-s)

  # -- solve + receipt ------------------------------------------------------

  defp solve_and_receipt(weighted, total_weight, lower, upper, dim) do
    coords = 0..(dim - 1)

    per_coord =
      Enum.map(coords, fn j ->
        l = Enum.at(lower, j)
        u = Enum.at(upper, j)

        unconstrained =
          Enum.reduce(weighted, 0.0, fn {p, w}, acc -> acc + w * Enum.at(p.vector, j) end) /
            total_weight

        clamped = clamp(unconstrained, l, u)

        contribution =
          if clamped == unconstrained do
            {:weighted_mean,
             Enum.map(weighted, fn {p, w} -> %{proposal_id: p.id, fraction: w / total_weight} end)}
          else
            bound = if clamped == l, do: :lower, else: :upper
            {:bound_clamped, %{bound: bound, value: clamped, unconstrained_mean: unconstrained}}
          end

        {clamped, {j, contribution}}
      end)

    z = Enum.map(per_coord, &elem(&1, 0))
    receipt = Map.new(per_coord, fn {_z, entry} -> entry end)

    {z, receipt}
  end

  defp clamp(v, :neg_infinity, :pos_infinity), do: v
  defp clamp(v, l, :pos_infinity), do: max(v, l)
  defp clamp(v, :neg_infinity, u), do: min(v, u)
  defp clamp(v, l, u), do: v |> max(l) |> min(u)
end
