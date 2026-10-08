defmodule Xaas.Chicago.FamilyCourtW984enTest do
  @moduledoc """
  W984en unclaimed-family probe court over `lib/xaas/chicago/`.

  Family census (7 modules): Case/Court/View/RenderTask/Layer are covered
  (court suite, view suite, render-task suite, W984dq8 layer suite). The
  remaining state-bearing surface is `Xaas.Chicago.Projection`'s fail-closed
  missing-key refusal branches (absent `subject`/`projectionType`/
  `generatorIdentity`/`sourceDigests` keys, non-object JSON, absent rootGoal,
  empty/non-array layer and case sets) and `Xaas.Chicago.Subject`'s negative
  `matches?/1` branches — none of which any existing suite asserts with the
  exact typed reason.

  Chicago discipline: the real loader over real files; each test is a
  single-field mutation of the committed fixture, so the clean fixture loads
  while the mutant is refused — the mutation IS the falsifier.
  """

  use ExUnit.Case, async: true

  alias Xaas.Chicago.{Projection, Subject}

  @machine_fixture Path.expand("consumer/fixtures/chicago.machine.fixture.json", __DIR__)

  setup do
    tmp = Path.join(System.tmp_dir!(), "chicago-w984en-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf(tmp) end)
    %{tmp: tmp}
  end

  defp write_mutant(tmp, fun) do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()
    mutated = fun.(doc)
    path = Path.join(tmp, "mutant-#{:erlang.unique_integer([:positive])}.json")
    File.write!(path, Jason.encode!(mutated))
    path
  end

  defp assert_refused(path, expected) do
    assert {:refused, {:chicago_projection_invalid, {^path, reason}}} =
             Projection.load(:machine, path)

    assert reason == expected or match?({^expected, _}, reason)

    reason
  end

  # -- Projection: missing-key fail-closed branches ---------------------------

  test "subject key absent is refused :subject_missing (not conflated with mismatch)", %{tmp: tmp} do
    # Mutation rationale: deleting the key (not drifting it) exercises the
    # missing-key clause, distinct from the already-covered subject_mismatch.
    path = write_mutant(tmp, &Map.delete(&1, "subject"))
    assert_refused(path, :subject_missing)
  end

  test "projectionType key absent is refused :projection_type_missing", %{tmp: tmp} do
    path = write_mutant(tmp, &Map.delete(&1, "projectionType"))
    assert_refused(path, :projection_type_missing)
  end

  test "generatorIdentity key absent is refused :generator_identity_missing", %{tmp: tmp} do
    path = write_mutant(tmp, &Map.delete(&1, "generatorIdentity"))
    assert_refused(path, :generator_identity_missing)
  end

  test "sourceDigests key absent is refused :source_digests_missing", %{tmp: tmp} do
    path = write_mutant(tmp, &Map.delete(&1, "sourceDigests"))
    assert_refused(path, :source_digests_missing)
  end

  test "top-level JSON array (not object) is refused :not_object", %{tmp: tmp} do
    # Mutation rationale: Jason.decode succeeds on `[...]`; only the loader's
    # object-shape clause stands between it and a KeyError deep in validation.
    path = Path.join(tmp, "array.json")

    machine = @machine_fixture |> File.read!() |> Jason.decode!()

    File.write!(path, Jason.encode!([machine["subject"]]))

    assert {:refused, {:chicago_projection_invalid, {^path, :not_object}}} =
             Projection.load(:machine, path)
  end

  test "rootGoal absent is refused {:root_goal_invalid, :absent}", %{tmp: tmp} do
    path = write_mutant(tmp, &Map.delete(&1, "rootGoal"))
    assert_refused(path, {:root_goal_invalid, :absent})
  end

  test "empty layers array is refused {:layer_set_invalid, :empty}", %{tmp: tmp} do
    path = write_mutant(tmp, &Map.put(&1, "layers", []))
    assert_refused(path, {:layer_set_invalid, :empty})
  end

  test "layers as non-array is refused {:layer_set_invalid, :not_array}", %{tmp: tmp} do
    path = write_mutant(tmp, &Map.put(&1, "layers", %{"id" => "sjira"}))
    assert_refused(path, {:layer_set_invalid, :not_array})
  end

  test "cases as non-array is refused {:case_set_invalid, :not_array}", %{tmp: tmp} do
    path = write_mutant(tmp, &Map.put(&1, "cases", "all-good"))
    assert_refused(path, {:case_set_invalid, :not_array})
  end

  test "layer status as non-binary non-nil (number) is refused {:layer_invalid, id}", %{tmp: tmp} do
    # Mutation rationale: valid_status?/1 admits binaries and nil only; a
    # numeric status (JSON permits) must fail the layer-object clause.
    path =
      write_mutant(tmp, fn doc ->
        update_in(doc, ["layers", Access.all(), "status"], fn s ->
          if s == "UNKNOWN", do: 3, else: s
        end)
      end)

    assert {:refused, {:chicago_projection_invalid, {^path, {:layer_invalid, _id}}}} =
             Projection.load(:machine, path)
  end

  # -- Subject: negative matches? branches ------------------------------------

  test "Subject.matches? refuses non-binary and drifted literals" do
    # Mutation rationale: the covered suites only assert the positive match;
    # both negative clauses (type guard, literal equality) are unexercised.
    refute Subject.matches?(nil)
    refute Subject.matches?(42)
    refute Subject.matches?("urn:chicago:agentic-payment:purchase-002")
    assert Subject.matches?(Subject.literal())
  end

  test "Subject.literal is the stable purchase-001 identity" do
    assert Subject.literal() == "urn:chicago:agentic-payment:purchase-001"
  end
end
