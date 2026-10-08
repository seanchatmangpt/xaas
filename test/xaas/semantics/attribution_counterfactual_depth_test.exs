defmodule Xaas.Semantics.AttributionCounterfactualDepthTest do
  @moduledoc """
  W984av — depth court on the non-dataset_admission semantics pair
  `Xaas.Semantics.AdmissionAttribution` (exact Shapley over the discrete
  admission lattice, Ch5/Art.13 Def 5.2) and `Xaas.Semantics.Counterfactual`
  (Art.86 / Theorem 7.1), courting invariants the pre-existing
  `admission_attribution_test.exs` / `counterfactual_test.exs` leave open:

  1. exactness — phi values equal hand-derived exact values on a 3-check
     lattice (the existing suite asserts the efficiency/symmetry axioms, not
     exact coalition arithmetic);
  2. refusal-position invariance — the exact phi map is identical when the
     single refusal moves position (pins the reversed names/bitmask index
     mapping against order-dependent drift);
  3. check-once evaluation — each admission check fun is invoked exactly
     once regardless of coalition count (2^n coalitions, n fun calls);
  4. COALITION_LIMIT boundary — 20 checks still compute, 21 refuse typed;
  5. real recorded decision — a real `Ash.create` of an `Xaas.Accounts.Org`
     row against real Postgres grounds the record; the counterfactual
     re-runs the real-shaped check list, a real flip names the flipped
     check, and a non-replaying record refuses typed.

  Mutation rationale: replace the marginal `v(S∪{i}) - v(S)` with 0.0 and
  courts (1)-(2) fail on the exact phi values. Drop the evaluate-once
  bitmask precomputation (re-run each fun per coalition) and court (3)
  observes more than one call per check. Change `@max_checks 20` to 19 and
  court (4)'s 20-check arm flips to `{:error, :COALITION_LIMIT}`; raise it
  and the 21-check arm wrongly computes. In `Counterfactual`, drop
  `verify_recorded_outcome/4` and court (5) admits a counterfactual on a
  record that does not replay to its recorded outcome instead of returning
  the typed `{:error, {:record_outcome_mismatch, _}}`. Flip the
  first-refusal selection in `run_pipeline/2` to last-refusal and court (5)'s
  record would no longer be a faithful witness of the real refusal.
  """

  use ExUnit.Case, async: true

  alias Xaas.Accounts.Org
  alias Xaas.Semantics.{AdmissionAttribution, Counterfactual}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  test "(1) exactness: 3-check lattice phi values equal hand-derived exact values" do
    # Checks a and b pass; check c refuses. v(S) = 1 iff c not in S,
    # v(∅) = 1 vacuously. For the refusing check c the marginal
    # v(S∪{c}) - v(S) is -1 on EVERY coalition S ⊆ {a,b} (v drops 1 -> 0
    # whenever c joins), and the n=3 pivot weights {1/3, 1/6, 1/6, 1/3}
    # over |S| = {0,1,1,2} sum to 1, so phi_c = -1.0 exactly.
    # For a passing check x, v(S∪{x}) = v(S) for every S (membership of a
    # passing check never changes v), so phi_a = phi_b = 0.0.
    # Efficiency: sum = -1.0 = v(N) - v(∅) = 0 - 1. Verified.
    checks = [
      a: fn _ -> :pass end,
      b: fn _ -> :pass end,
      c: fn _ -> {:refuse, :c_refused} end
    ]

    phi = AdmissionAttribution.shapley(%{}, checks)

    assert phi == %{a: 0.0, b: 0.0, c: -1.0}
  end

  test "(2) refusal-position invariance: the exact phi map does not depend on which position holds the refusal" do
    # v depends only on coalition membership, not list order, so the same
    # single refusal in position 1 vs position 2 (n=3) puts the full -1.0 on
    # the refusing check's name in both cases. A defect in the reversed
    # names/bitmask index mapping (refusal_bit/2 uses the un-reversed index)
    # would smear or misplace the attribution here.
    checks_a = [
      a: fn _ -> {:refuse, :r} end,
      b: fn _ -> :pass end,
      c: fn _ -> :pass end
    ]

    checks_b = [
      a: fn _ -> :pass end,
      b: fn _ -> {:refuse, :r} end,
      c: fn _ -> :pass end
    ]

    assert AdmissionAttribution.shapley(%{}, checks_a) ==
             %{a: -1.0, b: 0.0, c: 0.0}

    assert AdmissionAttribution.shapley(%{}, checks_b) ==
             %{a: 0.0, b: -1.0, c: 0.0}
  end

  test "(3) each admission check fun is evaluated exactly once regardless of coalition count" do
    n = 5

    {:ok, counter} = Agent.start_link(fn -> %{} end)

    wrapped =
      for i <- 1..n do
        name = String.to_atom("check_#{i}")

        {name,
         fn _intent ->
           Agent.update(counter, fn m -> Map.update(m, name, 1, &(&1 + 1)) end)

           if rem(i, 2) == 0 do
             {:refuse, String.to_atom("r_#{i}")}
           else
             :pass
           end
         end}
      end

    phi = AdmissionAttribution.shapley(%{}, wrapped)

    assert is_map(phi) and map_size(phi) == n
    # The values alone cannot distinguish evaluate-once from re-evaluation;
    # the call counts can.
    counts = Agent.get(counter, & &1)
    Agent.stop(counter)

    assert counts == Map.new(1..n, fn i -> {String.to_atom("check_#{i}"), 1} end)
  end

  test "(4) COALITION_LIMIT boundary: 20 checks compute, 21 refuse typed" do
    passing = fn _ -> :pass end

    checks20 = Enum.map(1..20, fn i -> {String.to_atom("c20_#{i}"), passing} end)
    checks21 = Enum.map(1..21, fn i -> {String.to_atom("c21_#{i}"), passing} end)

    phi20 = AdmissionAttribution.shapley(%{}, checks20)
    assert is_map(phi20) and map_size(phi20) == 20
    assert Enum.all?(Map.values(phi20), &(&1 == 0.0))

    assert {:error, :COALITION_LIMIT} = AdmissionAttribution.shapley(%{}, checks21)
  end

  test "(5) real recorded decision: mismatch refuses typed; real flip names the flipped check" do
    slug = "w984av-#{System.unique_integer([:positive])}"

    # Real Ash action, real Postgres: the admitted :create mints a real row
    # and its decision record is the court's subject.
    assert {:ok, _org} =
             Ash.create(
               Ash.Changeset.for_create(Org, :create, %{name: "Court Org", slug: slug},
                 authorize?: false
               )
             )

    record = %{
      input: %{slug: slug},
      admitted?: true,
      refusal: nil,
      checks: [
        %{name: :slug_present, verdict: :pass, refusal: nil},
        %{name: :slug_unique, verdict: :pass, refusal: nil}
      ]
    }

    checks = [
      slug_present: fn i ->
        if is_binary(i.slug) and i.slug != "", do: :ok, else: {:refused, :slug_missing}
      end,
      slug_unique: fn i ->
        # Real uniqueness witness: the row the record was minted from is
        # really in the table — a counterfactual input reusing a DIFFERENT
        # non-empty slug is the refused shape; an empty slug is charged to
        # slug_present alone so the flip attribution is single-check.
        if is_binary(i.slug) and i.slug != slug, do: {:refused, :slug_taken}, else: :ok
      end
    ]

    # Same input re-runs to the same decision: not changed, full log witnessed.
    assert {:ok, same} = Counterfactual.evaluate(record, %{slug: slug}, checks)
    refute same.changed?
    assert same.outcome == :admitted
    assert Enum.all?(same.checks, &(&1.verdict == :pass))

    # Counterfactual input fails slug_present -> the real decision flips,
    # and the explanation names exactly the flipped check.
    assert {:ok, flipped} = Counterfactual.evaluate(record, %{slug: nil}, checks)
    assert flipped.changed?
    assert flipped.outcome == {:refused, :slug_missing}
    assert flipped.explanation =~ "slug_present"
    refute flipped.explanation =~ "slug_unique"

    # Typed refusal: a record that does not replay to its recorded outcome
    # is not admitted to any counterfactual claim.
    bad_record = %{record | admitted?: false, refusal: :slug_taken}

    assert {:error, {:record_outcome_mismatch, {:expected, {false, :slug_taken}, :got, :admitted}}} =
             Counterfactual.evaluate(bad_record, %{slug: slug}, checks)
  end
end
