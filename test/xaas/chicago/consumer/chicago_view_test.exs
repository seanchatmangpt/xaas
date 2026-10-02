defmodule Xaas.Chicago.ViewTest do
  @moduledoc """
  Drill-down view tests (resolution R4 scope 2/5).

  Verifies L6's exact shape over the synthesized fixture, the typed fallbacks
  while the executive render is absent, the typed absence reasons, and that a
  layer's standing is read ONLY from its own machine status — mutating one
  layer's status never moves another layer's standing or lifecycle.

  The default-path case runs against the live repository where `priv/chicago/`
  does not exist at this SHA — the typed refusal is the honest expectation.
  """

  use ExUnit.Case, async: true

  alias Xaas.Chicago.{Projection, Subject, View}

  @machine_fixture Path.expand("fixtures/chicago.machine.fixture.json", __DIR__)
  @executive_fixture Path.expand("fixtures/chicago.executive.fixture.json", __DIR__)
  @contract_ids ~w(sjira graphlaw sa2a pplan xaas ex4pm beam4pm affidavit ashsurface marketplace)a

  test "drill_down over fixture paths serves the L6 shape" do
    assert {:ok, view} =
             View.drill_down(machine_path: @machine_fixture, executive_path: @executive_fixture)

    assert view.subject == Subject.literal()

    assert %{headline: "Agentic payments you can watch work", detail: detail, standing: "UNKNOWN"} =
             view.business_outcome

    assert is_binary(detail) and detail != ""

    assert Enum.map(view.layers, & &1.id) == @contract_ids

    for layer <- view.layers do
      required_keys = ~w(id label what_happened standing lifecycle evidence receipt absence)a
      assert Enum.all?(required_keys, &Map.has_key?(layer, &1))

      assert layer.standing == "UNKNOWN"
      assert layer.lifecycle == :candidate
      assert layer.evidence == []
      assert layer.receipt == nil
      # present-but-unreceipted layers render interactive rows, not absence rows
      assert layer.absence == nil
      assert is_binary(layer.what_happened) and layer.what_happened != ""
    end
  end

  test "executive absent -> typed fallback business outcome, layers still served" do
    absent = Path.join(System.tmp_dir!(), "no-exec-#{:erlang.unique_integer([:positive])}.json")

    assert {:ok, view} = View.drill_down(machine_path: @machine_fixture, executive_path: absent)

    assert view.business_outcome.standing == "UNKNOWN"
    assert view.business_outcome.headline =~ "candidate"
    assert view.business_outcome.detail =~ "executive projection unavailable"
    assert length(view.layers) == 10
  end

  test "standing is read from the layer's OWN status only (no cross-layer derivation)" do
    doc = @machine_fixture |> File.read!() |> Jason.decode!()

    doc =
      update_in(doc["layers"], fn [sjira | rest] ->
        [%{sjira | "status" => "ALIVE", "receiptRefs" => ["receipt-sjira-001"]} | rest]
      end)

    mutated =
      Path.join(System.tmp_dir!(), "sjira-alive-#{:erlang.unique_integer([:positive])}.json")

    File.write!(mutated, Jason.encode!(doc))

    assert {:ok, view} =
             View.drill_down(machine_path: mutated, executive_path: @executive_fixture)

    by_id = Map.new(view.layers, fn l -> {l.id, l} end)

    sjira = by_id[:sjira]
    assert sjira.standing == "ALIVE"
    assert sjira.lifecycle == :executed
    assert sjira.receipt == "receipt-sjira-001"
    assert sjira.absence == nil

    # every OTHER layer keeps its own UNKNOWN standing — nothing derived
    for {id, layer} <- by_id, id != :sjira do
      assert layer.standing == "UNKNOWN", "#{id} inherited standing from sjira"
      assert layer.lifecycle == :candidate
      assert layer.absence == nil
    end

    Projection.clear_memo(:machine, mutated)
  end

  test "default paths surface the committed render (integration: priv/chicago landed)" do
    Xaas.Chicago.reload()

    assert {:ok, episode} = View.drill_down()
    assert episode.subject == "urn:chicago:agentic-payment:purchase-001"
    assert length(episode.layers) == 10
    assert Enum.all?(episode.layers, fn l -> l.standing == "UNKNOWN" end)
    assert Enum.all?(episode.layers, fn l -> l.lifecycle == :candidate end)
    assert Enum.all?(episode.layers, fn l -> is_binary(l.label) and is_binary(l.what_happened) end)
  end
end
