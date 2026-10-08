defmodule Xaas.Chicago.LayerDeepeningTest do
  @moduledoc """
  W984dq8 court over `Xaas.Chicago.Layer` — the chicago family's contract-layer
  registry (the only lib-side consumer is `Xaas.Chicago.View`; `fetch/2`,
  `standing/1`, `list/1`, `required_keys/0`, and `known?/1` had zero direct
  coverage).

  Real machine projections, no mocks.

  Mutation rationale per test (what mutation each test kills):

    1. kills a mutation reordering the ten contract ids or demoting a required
       id into `@successor_ids` (or vice versa);
    2. kills a mutation dropping an id from `@labels` (label/1 raises
       MapFetchError) or breaking `known?/1`'s binary/atom duality;
    3. kills a mutation of `list/1`'s `Map.fetch!` (missing required layer
       would crash) or its required-order mapping;
    4. kills a mutation of `fetch/2` returning `{:ok, nil}` instead of the
       typed refusal `{:refused, {:chicago_layer_unknown, id}}`;
    5. kills a mutation of `standing/1` inheriting a sibling layer's status or
       defaulting to anything other than "UNKNOWN" per R8.
  """

  use ExUnit.Case, async: true

  alias Xaas.Chicago.Layer

  @machine %{
    "layers" =>
      Enum.map(Layer.required_ids() ++ Layer.successor_ids(), fn id ->
        %{
          "id" => Atom.to_string(id),
          "identifier" => "chi:layer-#{id}",
          "label" => "Layer #{id}",
          "repository" => "~/#{id}",
          "pathScope" => "lib",
          "boundaryClass" => "sibling",
          "authorityCeiling" => "CONSTRUCT",
          "capabilityId" => "cap.#{id}",
          "evidenceHorizon" => "26.10"
        }
      end)
  }

  test "1: required ids are the ten contract ids in fixed R2/R4 presentation order" do
    assert Layer.required_ids() == [
             :sjira,
             :graphlaw,
             :sa2a,
             :pplan,
             :xaas,
             :ex4pm,
             :beam4pm,
             :affidavit,
             :ashsurface,
             :marketplace
           ]

    assert :wasm4pm in Layer.successor_ids() and :castle in Layer.successor_ids()
    assert Layer.required_ids() -- Layer.successor_ids() == Layer.required_ids()
  end

  test "2: every id has a label and known?/1 is atom/binary dual, false for unknown" do
    for id <- Layer.required_ids() ++ Layer.successor_ids() do
      assert is_binary(Layer.label(id))
      assert Layer.known?(id)
      assert Layer.known?(Atom.to_string(id))
    end

    refute Layer.known?(:nonexistent_layer)
    refute Layer.known?("nonexistent_layer")
    refute Layer.known?(42)
  end

  test "3: list/1 returns machine layers in required contract order, not projection order" do
    assert [%{"id" => "sjira"}, %{"id" => "graphlaw"} | _] = layers = Layer.list(@machine)
    assert Enum.map(layers, & &1["id"]) == Enum.map(Layer.required_ids(), &Atom.to_string/1)

    # Successor layers ride in the projection but are excluded from the surface.
    refute "wasm4pm" in Enum.map(layers, & &1["id"])
    refute "castle" in Enum.map(layers, & &1["id"])

    # A missing required layer crashes loudly (Map.fetch!), never silently reorders.
    assert_raise KeyError, fn ->
      Layer.list(%{"layers" => [%{"id" => "graphlaw"}]})
    end
  end

  test "4: fetch/2 known id yields the layer; unknown id yields the typed refusal" do
    assert {:ok, %{"id" => "graphlaw"}} = Layer.fetch(@machine, :graphlaw)
    assert {:ok, %{"id" => "graphlaw"}} = Layer.fetch(@machine, "graphlaw")

    assert {:refused, {:chicago_layer_unknown, :nonexistent_layer}} =
             Layer.fetch(@machine, :nonexistent_layer)

    assert {:refused, {:chicago_layer_unknown, "nope"}} = Layer.fetch(@machine, "nope")
  end

  test "5: standing derives from the layer's own status only, defaulting to UNKNOWN" do
    # No status key anywhere in the projection: every layer stands UNKNOWN per R2/R8.
    assert Enum.all?(Layer.list(@machine), fn layer -> Layer.standing(layer) == "UNKNOWN" end)

    # Sibling status must not leak: only the annotated layer carries it.
    annotated =
      Map.update!(@machine, "layers", fn layers ->
        List.update_at(layers, 0, &Map.put(&1, "status", "ALIVE"))
      end)

    layers = Layer.list(annotated)
    assert Layer.standing(hd(layers)) == "ALIVE"
    assert Enum.all?(tl(layers), fn layer -> Layer.standing(layer) == "UNKNOWN" end)

    assert Layer.standing(%{}) == "UNKNOWN"
  end
end
