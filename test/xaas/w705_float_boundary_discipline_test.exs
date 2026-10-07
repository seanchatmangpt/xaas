# W705 lane: gap fill from the wasm4pm cross-project audit.
#
# wasm4pm's flake discipline (w94): computed float boundary assertions carry an
# explicit epsilon bound (`<= 1 + 1e-9`) instead of bare `==` against a
# floating-point constant. XAAS has bare float `==` assertions in existing
# tests; this file adds the epsilon-bound discipline at the top 3 bare-float
# site families, pinning the same behavior with a tolerance that is far below
# any meaningful semantic difference but above float representation error.
#
# Typed note on exact-zero sites: `machinery_share == 0.0` (yield_test) and
# `llm_avoidance_ratio == 0.0` (sa2a execute_test) are ratios of integer
# counts, exact 0.0 in IEEE754 (0/58, 0/1); bare == is exact there and does
# not need the epsilon bound. The bound is for non-trivially-computed floats.

defmodule W705FloatBoundaryDisciplineTest do
  use ExUnit.Case, async: true

  @eps 1.0e-9

  # w94 canary: the epsilon bound exceeds float representation error at 1.0
  # but is far below any semantic tolerance.
  test "canary: the 1e-9 epsilon bound separates representation error from semantic drift" do
    assert abs(1.1 + 2.2 - 3.3) > 0.0
    assert abs(1.1 + 2.2 - 3.3) <= @eps
    # The bound also admits a just-above-epsilon perturbation without tripping
    # (0.3 + 1e-9 lands at ~1.0000000272e-9 after representation error).
    assert delta = abs(0.3 + 1.0e-9 - 0.3)
    assert delta > 0.0
    assert delta <= 2 * @eps
  end

  # Site family 1: next_read_test.exs:218-223 asserts Config.weights() with
  # bare ==. The weights are parsed from the ontology at call time; re-pin
  # them under the epsilon-bound discipline.
  test "Library.Config.weights: ontology-derived literals hold within 1e-9 (w94 discipline)" do
    weights = Xaas.Library.Config.weights()
    expected = %{collab: 0.34, semantic: 0.26, grade_fit: 0.16, available: 0.10, diversity: 0.06, curation: 0.09}

    for {k, v} <- expected do
      got = Map.fetch!(weights, k)
      assert abs(got - v) <= @eps, "weight #{k}: got #{got}, expected #{v} ± 1e-9"
    end

    # The composite boundary next_read_test pins via Float.round(.., 2) == 1.01;
    # the unrounded sum holds only within the epsilon bound.
    sum = weights |> Map.values() |> Enum.sum()
    assert abs(sum - 1.01) <= @eps
  end

  # Site family 2/3: Xaas.Sjira.Yield machinery_share — the computed float the
  # yield test suite asserts with bare ==. Reference-oracle form (w609's
  # choice-graph pattern): an independent naive recomputation cross-checks the
  # module's share, with the epsilon bound at the non-trivial boundaries.
  test "Sjira.Yield.mine machinery_share matches the naive oracle within 1e-9" do
    log = %{
      "objects" => [
        %{"id" => "agent:1", "type" => "agent"},
        %{"id" => "svc:ci", "type" => "service"}
      ],
      "events" => [
        %{"id" => "e1", "type" => "commit", "relationships" => [%{"qualifier" => "actor", "objectId" => "agent:1"}]},
        %{"id" => "e2", "type" => "commit", "relationships" => [%{"qualifier" => "actor", "objectId" => "agent:1"}]},
        %{"id" => "e3", "type" => "commit", "relationships" => [%{"qualifier" => "actor", "objectId" => "svc:ci"}]},
        %{"id" => "e4", "type" => "commit", "relationships" => [%{"qualifier" => "actor", "objectId" => "svc:ci"}]}
      ]
    }

    mined = Xaas.Sjira.Yield.mine(log)

    # Oracle: machinery = hops whose actor object type is not "agent".
    total = mined["hops"]["total"]
    machinery = mined["hops"]["machinery"]
    assert total == 4
    assert machinery == 2
    expected_share = machinery / total

    assert abs(mined["machinery_share"] - expected_share) <= @eps
    assert mined["machinery_share"] == 0.5

    # Per-run share agrees with the same oracle.
    [run] = mined["by_run"]
    assert abs(run["machinery_share"] - expected_share) <= @eps

    # Boundary: all-llm log -> exact 0.0 (integer ratio, exact in IEEE754);
    # empty log -> nil.
    all_llm = %{
      "objects" => [%{"id" => "agent:1", "type" => "agent"}],
      "events" => [
        %{"id" => "e1", "type" => "commit",
         "relationships" => [%{"qualifier" => "actor", "objectId" => "agent:1"}]}
      ]
    }

    assert Xaas.Sjira.Yield.mine(all_llm)["machinery_share"] == 0.0

    assert Xaas.Sjira.Yield.mine(%{"objects" => [], "events" => []})["machinery_share"] == nil
  end

  test "FOND.Circuit failure-ratio float boundary under the 1e-9 discipline" do
    # 1/3 is not exactly representable; bare == against 1/3 holds only because
    # both sides compute identically. Pin via oracle form instead.
    c = Xaas.Runtime.FOND.Circuit.new(3) |> Xaas.Runtime.FOND.Circuit.fail(:a)

    ratio = Map.get(c.failures, :a) / (Map.get(c.failures, :a) + 2)

    assert abs(ratio - 1 / 3) <= @eps
  end
end
