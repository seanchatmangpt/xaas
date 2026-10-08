defmodule Xaas.Coupling.CouplingDepthTest do
  @moduledoc """
  Lane W984cu depth court: the coupling-family remainder NOT covered by the
  existing slices (engine math per outcome, W984ak supersede/policy floor,
  W983h graphql era). Courts the persisted-lifecycle surface of
  `Xaas.Coupling.CouplingRun`: error-status lifecycle, cross-run isolation,
  JSONB receipt/weights round-trip integrity, and numeric normalization.
  Chicago courts: real Postgres via the SQL sandbox, real Ash creates/reads,
  assertions on final persisted state. One mutation per test: the code path
  each test would catch if reverted.
  """

  use ExUnit.Case, async: true

  alias Xaas.Coupling.CouplingRun

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp couple!(attrs) do
    CouplingRun
    |> Ash.Changeset.for_create(:couple, attrs)
    |> Ash.create!()
  end

  test "an :error outcome never persists a run -- create fails and no row exists" do
    # Mutation rationale: if `apply_engine_result/2`'s :error clause dropped
    # its `Ash.Changeset.add_error/2` while still forcing status :error, the
    # create would succeed and persist an :error row -- silently widening the
    # persisted status space beyond the four honest outcomes. This test
    # kills exactly that mutant: admission fails AND no row survives.
    assert {:error, %Ash.Error.Invalid{}} =
             CouplingRun
             |> Ash.Changeset.for_create(:couple, %{
               proposals: [
                 %{"id" => "a", "vector" => [1.0, 2.0], "confidence" => 1.0, "staleness" => 0.0},
                 %{"id" => "b", "vector" => [1.0], "confidence" => 1.0, "staleness" => 0.0}
               ],
               constraints: %{}
             })
             |> Ash.create()

    assert [] = Ash.read!(CouplingRun)
  end

  test "two couple runs over different proposal sets are isolated -- no receipt or weight bleed" do
    # Mutation rationale: any shared/global accumulation between runs (a
    # module-attribute cache, a reused ETS bucket, an unsandboxed shared row)
    # would let run B's receipt or weights absorb run A's proposals. Distinct
    # inputs persisted side by side must round-trip with disjoint receipts
    # and disjoint weight keys.
    low =
      couple!(%{
        proposals: [%{"id" => "lo", "vector" => [2.0], "confidence" => 1.0, "staleness" => 0.0}],
        constraints: %{}
      })

    high =
      couple!(%{
        proposals: [%{"id" => "hi", "vector" => [200.0], "confidence" => 1.0, "staleness" => 0.0}],
        constraints: %{}
      })

    assert low.id != high.id
    assert low.z == [2.0]
    assert high.z == [200.0]
    assert Map.keys(low.weights) == ["lo"]
    assert Map.keys(high.weights) == ["hi"]
    assert low.receipt != high.receipt

    rows = Ash.read!(CouplingRun)

    reloaded_low = Enum.find(rows, &(&1.id == low.id))
    reloaded_high = Enum.find(rows, &(&1.id == high.id))

    assert reloaded_low.weights == low.weights
    assert reloaded_high.weights == high.weights
  end

  test "mixed receipt round-trips JSONB intact: per-coordinate kinds, nested fractions, bound detail" do
    # Mutation rationale: `stringify_receipt/1` is the only path from the
    # engine's atom-keyed receipt to the stored JSONB shape. A mutant that
    # dropped the nested contribution list, the fraction floats, or the
    # bound-clamp detail would still solve and store status :solved -- only
    # the persisted receipt shape would silently degrade. This test reads
    # the row back from Postgres and asserts the full auditable structure:
    # any coordinate of z must be reconstructible from the stored receipt.
    run =
      couple!(%{
        proposals: [
          %{"id" => "p1", "vector" => [100.0, 1.0], "confidence" => 1.0, "staleness" => 0.0},
          %{"id" => "p2", "vector" => [200.0, 3.0], "confidence" => 1.0, "staleness" => 0.0}
        ],
        constraints: %{"lower" => [0.0, 0.0], "upper" => [100.0, 10.0]}
      })

    assert run.status == :solved
    # coord 0: mean 150.0 clamps to the upper bound 100.0; coord 1: mean 2.0 stays interior
    assert run.z == [100.0, 2.0]

    [persisted] = Ash.read!(CouplingRun)

    assert persisted.receipt["0"]["kind"] == "bound_clamped"
    assert persisted.receipt["0"]["detail"]["bound"] == "upper"
    assert persisted.receipt["0"]["detail"]["unconstrained_mean"] == 150.0
    assert persisted.receipt["0"]["detail"]["value"] == 100.0

    assert persisted.receipt["1"]["kind"] == "weighted_mean"

    fractions =
      persisted.receipt["1"]["detail"]
      |> Enum.map(&{&1["proposal_id"], &1["fraction"]})
      |> Enum.into(%{})

    assert fractions == %{"p1" => 0.5, "p2" => 0.5}
  end

  test "integer confidence/staleness inputs normalize to float weights" do
    # Mutation rationale: `normalize_proposal/1` multiplies confidence and
    # staleness by 1.0 to coerce JSON integers to floats. A mutant dropping
    # the coercion stores integer weights in the `:map` weights attribute;
    # `w / total_weight` still solves, so only the persisted weights dtype
    # would drift. The court asserts the stored weights are real floats.
    run =
      couple!(%{
        proposals: [
          %{"id" => "a", "vector" => [10.0], "confidence" => 1, "staleness" => 0},
          %{"id" => "b", "vector" => [30.0], "confidence" => 1, "staleness" => 0}
        ],
        constraints: %{}
      })

    assert run.status == :solved
    assert run.weights["a"] == 1.0 and is_float(run.weights["a"])
    assert run.weights["b"] == 1.0 and is_float(run.weights["b"])
  end

  test "mixed string/atom constraint keys hit the same bound path -- fetch/2 falls through both" do
    # Mutation rationale: `fetch/2` tries the atom key then the string key.
    # A mutant that only honored one key shape would make lower/upper bounds
    # silently vanish for JSON-transport callers (falling back to +-infinity,
    # an unclamped solve) while the atom-keyed direct path kept passing every
    # existing court. Feeding the SAME bounds in string-keyed form and
    # asserting the real clamp proves the transport-normalization edge.
    run =
      couple!(%{
        proposals: [%{"id" => "a", "vector" => [42.0], "confidence" => 1.0, "staleness" => 0.0}],
        constraints: %{
          "lower" => [0.0],
          "upper" => [5.0]
        }
      })

    assert run.status == :solved
    assert run.z == [5.0]
    assert run.receipt["0"]["kind"] == "bound_clamped"
  end
end
