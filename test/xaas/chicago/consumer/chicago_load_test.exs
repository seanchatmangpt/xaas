defmodule Xaas.Chicago.LoadTest do
  @moduledoc """
  Consumer-lane load/identity-validation tests (resolution R4 scope 5).

  The fixture is a synthesized R2-shaped machine projection explicitly labeled
  "not a render". `priv/chicago/` does NOT exist at this SHA — every facade
  refusal below is the real fail-closed path against the live repository
  state, so no test can pass merely because a render exists.

  Anti-vacuity: each identity law is exercised as a pair — the clean fixture
  loads, the single-field mutant is refused with the exact typed reason.
  """

  use ExUnit.Case, async: true

  alias Xaas.Chicago
  alias Xaas.Chicago.{Case, Layer, Projection, Subject}

  @machine_fixture Path.expand("fixtures/chicago.machine.fixture.json", __DIR__)
  @executive_fixture Path.expand("fixtures/chicago.executive.fixture.json", __DIR__)

  setup do
    tmp = Path.join(System.tmp_dir!(), "chicago-load-#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    %{tmp: tmp}
  end

  defp write_mutant(%{tmp: tmp}, fun) do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()
    mutated = fun.(doc)
    path = Path.join(tmp, "mutant-#{:erlang.unique_integer([:positive])}.json")
    File.write!(path, Jason.encode!(mutated))
    path
  end

  defp assert_refused(path, expected_reason) when is_atom(expected_reason) do
    assert {:refused, {:chicago_projection_invalid, {^path, reason}}} =
             Projection.load(:machine, path)

    assert reason == expected_reason or match?({^expected_reason, _}, reason)
    reason
  end

  defp assert_refused(path, {atom, detail}) do
    assert {:refused, {:chicago_projection_invalid, {^path, reason}}} =
             Projection.load(:machine, path)

    assert match?({^atom, _}, reason)
    if detail != :any, do: assert(reason == {atom, detail})
    reason
  end

  # -- clean path ------------------------------------------------------------

  test "synthesized machine fixture loads and validates" do
    assert {:ok, machine} = Projection.load(:machine, @machine_fixture)
    assert Subject.matches?(machine["subject"])
    assert length(machine["layers"]) == 10
    assert length(machine["cases"]) == 10
  end

  test "executive fixture loads and validates" do
    assert {:ok, executive} = Projection.load(:executive, @executive_fixture)
    assert executive["projectionType"] == "executive"
  end

  test "layer/case helpers serve over a loaded fixture projection" do
    assert {:ok, machine} = Chicago.load_projection(:machine, @machine_fixture)

    assert Enum.map(Layer.list(machine), & &1["id"]) ==
             ~w(sjira graphlaw sa2a pplan xaas ex4pm beam4pm affidavit ashsurface marketplace)

    assert {:ok, %{}} = Layer.fetch(machine, :sjira)
    assert {:refused, {:chicago_layer_unknown, "castle"}} = Layer.fetch(machine, "castle")
    assert Layer.standing(Enum.at(machine["layers"], 0)) == "UNKNOWN"

    assert {:ok, %{}} = Case.fetch(machine, "CHI-CASE-001")

    assert {:refused, {:chicago_case_unknown, "CHI-CASE-999"}} =
             Case.fetch(machine, "CHI-CASE-999")

    assert {:ok, subject} = Chicago.subject()
    assert subject == Subject.literal()
  end

  test "case request baseline composes from a projection case" do
    {:ok, machine} = Chicago.load_projection(:machine, @machine_fixture)
    {:ok, case_1} = Case.fetch(machine, "CHI-CASE-001")

    request = Case.request_from_case(case_1, %{amount: 50})
    assert request[:subject] == Subject.literal()
    assert request[:authority_claim] == "NONE"
  end

  # -- identity laws (each mutant flips the verdict) --------------------------

  test "generated: false is refused", ctx do
    path = write_mutant(ctx, fn d -> put_in(d["generated"], false) end)
    assert_refused(path, :generated_not_true)
  end

  test "authority claim DO is refused", ctx do
    path = write_mutant(ctx, fn d -> put_in(d["authorityClaim"], "DO") end)
    assert_refused(path, :authority_claim_not_none)
  end

  test "subject drift is refused", ctx do
    path =
      write_mutant(ctx, fn d ->
        put_in(d["subject"], "urn:chicago:agentic-payment:purchase-002")
      end)

    assert_refused(path, {:subject_mismatch, "urn:chicago:agentic-payment:purchase-002"})
  end

  test "projection type mismatch is refused", ctx do
    path = write_mutant(ctx, fn d -> put_in(d["projectionType"], "verification") end)
    assert_refused(path, {:projection_type_mismatch, "verification"})
  end

  test "foreign generator identity is refused", ctx do
    path = write_mutant(ctx, fn d -> put_in(d["generatorIdentity"], "hand-render@26.10.1") end)
    assert_refused(path, {:generator_identity_mismatch, "hand-render@26.10.1"})
  end

  test "sourceDigests must be an array of {path, sha256}", ctx do
    path = write_mutant(ctx, fn d -> put_in(d["sourceDigests"], "not-an-array") end)
    assert_refused(path, :source_digests_not_array)

    path2 =
      write_mutant(ctx, fn d ->
        put_in(d["sourceDigests"], [%{"path" => "x", "sha256" => "zz"}])
      end)

    assert_refused(path2, :source_digest_entry_invalid)
  end

  # -- machine body laws -------------------------------------------------------

  test "rootGoal missing a required field is refused", ctx do
    path = write_mutant(ctx, fn d -> pop_in(d["rootGoal"]["baseSha"]) |> elem(1) end)
    assert_refused(path, :root_goal_invalid)
  end

  test "swapping a required id for a successor slug drops the required set", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()
    doc = update_in(doc["layers"], fn [first | rest] -> [%{first | "id" => "castle"} | rest] end)
    path = Path.join(ctx.tmp, "castle.json")
    File.write!(path, Jason.encode!(doc))
    # successor ids are known (render carries 12), so the refusal is the
    # missing-required-layer set check, not id knowledge
    assert_refused(path, {:layer_set_invalid, {:missing, [:sjira]}})
  end

  test "genuinely unknown layer id is refused", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()
    doc = update_in(doc["layers"], fn [first | rest] -> [%{first | "id" => "warp9"} | rest] end)
    path = Path.join(ctx.tmp, "warp9.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:unknown_layer_id, "warp9"})
  end

  test "missing required layer is refused", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()
    doc = update_in(doc["layers"], fn ls -> Enum.reject(ls, &(&1["id"] == "sjira")) end)
    path = Path.join(ctx.tmp, "no-sjira.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:layer_set_invalid, {:missing, [:sjira]}})
  end

  test "duplicate layer is refused", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()
    doc = update_in(doc["layers"], fn [first | rest] -> [first, first | rest] end)
    path = Path.join(ctx.tmp, "dup.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:layer_set_invalid, :duplicate})
  end

  test "layer with non-boolean required is refused", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()

    doc =
      update_in(doc["layers"], fn [first | rest] -> [%{first | "required" => "yes"} | rest] end)

    path = Path.join(ctx.tmp, "optional.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:layer_invalid, "sjira"})
  end

  test "successor layer with required: false loads (render carries 12 ids)", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()

    doc =
      update_in(doc["layers"], fn layers ->
        layers ++
          [
            %{
              "id" => "wasm4pm",
              "identifier" => "CHI-111-WASM4PM",
              "label" => "WASM process mining",
              "repository" => "seanchatmangpt/wasm4pm",
              "pathScope" => "",
              "boundaryClass" => "Successor",
              "authorityCeiling" => "CONSTRUCT",
              "capabilityId" => "wasm4pm:qri",
              "evidenceHorizon" => "EXECUTED_VERIFIED",
              "required" => false,
              "status" => "UNKNOWN",
              "evidenceRefs" => [],
              "receiptRefs" => []
            }
          ]
      end)

    path = Path.join(ctx.tmp, "successor.json")
    File.write!(path, Jason.encode!(doc))
    assert {:ok, _} = Projection.load(:machine, path)
  end

  test "layer with non-array evidenceRefs is refused", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()

    doc =
      update_in(doc["layers"], fn [first | rest] ->
        [%{first | "evidenceRefs" => "ev-1"} | rest]
      end)

    path = Path.join(ctx.tmp, "refs.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:layer_invalid, "sjira"})
  end

  # -- case laws (standing tripwires, R8/R9) -----------------------------------

  test "case with candidateOnly: false is refused (a case is never an observation)", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()

    doc =
      update_in(doc["cases"], fn [first | rest] ->
        [%{first | "candidateOnly" => false} | rest]
      end)

    path = Path.join(ctx.tmp, "observed.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:case_invalid, "CHI-CASE-001"})
  end

  test "case with pre-judged standing is refused (hardcoded-outcome tripwire)", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()

    doc =
      update_in(doc["cases"], fn [first | rest] ->
        [%{first | "observedStanding" => "ALIVE"} | rest]
      end)

    path = Path.join(ctx.tmp, "alleged-alive.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:case_invalid, "CHI-CASE-001"})
  end

  test "case with drifted subject is refused", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()

    doc =
      update_in(doc["cases"], fn [first | rest] ->
        [%{first | "subject" => "urn:other"} | rest]
      end)

    path = Path.join(ctx.tmp, "case-subject.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:case_invalid, "CHI-CASE-001"})
  end

  test "duplicate case id is refused", ctx do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()
    doc = update_in(doc["cases"], fn [first | rest] -> [first, first | rest] end)
    path = Path.join(ctx.tmp, "dup-case.json")
    File.write!(path, Jason.encode!(doc))
    assert_refused(path, {:case_id_duplicate, :duplicate})
  end

  # -- transport failures ------------------------------------------------------

  test "missing projection file is refused with its path" do
    path =
      Path.join(System.tmp_dir!(), "chicago-absent-#{:erlang.unique_integer([:positive])}.json")

    assert {:refused, {:chicago_projection_missing, ^path}} = Projection.load(:machine, path)
  end

  test "invalid JSON is refused with a decode reason", ctx do
    path = Path.join(ctx.tmp, "broken.json")
    File.write!(path, "{\"generated\": true,")

    assert {:refused, {:chicago_projection_invalid, {^path, {:json_decode, _}}}} =
             Projection.load(:machine, path)
  end

  # -- round-trip law ----------------------------------------------------------

  test "encode(load(fixture)) round-trips to an identical validated document" do
    {:ok, loaded} = Projection.load(:machine, @machine_fixture)
    reencoded = Jason.encode!(loaded)

    roundtrip_path =
      Path.join(
        System.tmp_dir!(),
        "chicago-roundtrip-#{:erlang.unique_integer([:positive])}.json"
      )

    File.write!(roundtrip_path, reencoded)

    assert {:ok, reloaded} = Projection.load(:machine, roundtrip_path)
    assert reloaded == loaded

    Projection.clear_memo(:machine, roundtrip_path)
  end

  # -- memoization -------------------------------------------------------------

  test "load_memoized serves the first result until cleared" do
    path =
      Path.join(System.tmp_dir!(), "chicago-memo-#{:erlang.unique_integer([:positive])}.json")

    File.write!(path, File.read!(@machine_fixture))

    assert {:ok, first} = Projection.load_memoized(:machine, path)

    # mutate the file on disk: the memo still serves the first result
    File.write!(path, "{\"broken\": true}")
    assert {:ok, ^first} = Projection.load_memoized(:machine, path)

    # cleared: the new content is valid JSON but not a render -> typed refusal
    :ok = Projection.clear_memo(:machine, path)

    assert {:refused, {:chicago_projection_invalid, {^path, :generated_not_true}}} =
             Projection.load_memoized(:machine, path)

    Projection.clear_memo(:machine, path)
  end

  # -- honest compile-time: facade against the LIVE repository state -----------

  test "facade loads the committed render (integration: priv/chicago landed)" do
    Chicago.reload()

    assert {:ok, machine} = Chicago.machine()
    assert machine["generated"] == true
    assert machine["authorityClaim"] == "NONE"
    assert machine["subject"] == "urn:chicago:agentic-payment:purchase-001"
    assert machine["projectionType"] == "machine"
    assert %{"sha256" => _, "path" => _} = hd(machine["sourceDigests"])
    assert machine["generatorIdentity"] =~ "chicago-xaas-surface-pack@"
    assert length(machine["layers"]) == 12

    assert {:ok, layers} = Chicago.layers()
    assert length(layers) == 10

    assert {:ok, cases} = Chicago.cases()
    assert length(cases) == 10
    assert Enum.all?(cases, fn c -> c["candidateOnly"] == true end)

    assert {:ok, replay} = Chicago.replay()
    assert is_map(replay)

    assert {:ok, verification} = Chicago.verification()
    assert verification["authorityClaim"] == "NONE"

    assert {:ok, executive} = Chicago.executive()
    assert executive["authorityClaim"] == "NONE"
  end

  test "required_layers and subject are projection-independent" do
    assert {:ok, ids} = Chicago.required_layers()
    assert length(ids) == 10

    assert {:ok, subject} = Chicago.subject()
    assert Subject.matches?(subject)
  end
end
