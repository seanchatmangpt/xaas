defmodule Xaas.Changes.FamilyCourtW984ieTest do
  @moduledoc """
  Lane W984ie unclaimed-family probe: shared Ash change modules not under an
  owned domain subdir and not directly courted elsewhere.

  Dispositions (see docs/sjira/v26.10.6/plans/w984ie-probe.md):
  - `Xaas.Operations.Changes.SetPreviousStatus` — COVERED (W968c court,
    test/xaas/operations/capability_liveness_deepening_test.exs).
  - `Xaas.Ocel.Changes.RelateEventToObjects` — two genuinely unexercised
    state-bearing branches courted here with real Postgres, real Ash
    actions, real changesets; zero mocks.

  Mutation rationale per test below.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.Ocel.{Event, EventObject, Object}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp register_object!(attrs) do
    Object
    |> Ash.Changeset.for_create(:register, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp record_event(attrs) do
    Event
    |> Ash.Changeset.for_create(:record, attrs)
    |> Ash.create(authorize?: false)
  end

  describe "Xaas.Ocel.Changes.RelateEventToObjects" do
    test "string-keyed object relations are admitted and persisted with their qualifier" do
      # Mutation rationale: kills a mutant that deletes the string-key
      # clauses (valid_relation?/1 %{"object_id" => id} and the Map.get
      # fallbacks in create_relations/2) — the event would be refused or
      # persisted with the wrong qualifier, both observable in real state.
      object = register_object!(%{object_type: "Order", ocel_id: "order-w984ie-1"})

      assert {:ok, event} =
               record_event(%{
                 event_type: "ship",
                 ocel_id: "ev-w984ie-strkey",
                 occurred_at: DateTime.utc_now(),
                 object_relations: [
                   %{"object_id" => object.id, "qualifier" => "subject"},
                   %{object_id: object.id, qualifier: "resource"}
                 ]
               })

      relations =
        EventObject
        |> Ash.Query.filter(event_id == ^event.id)
        |> Ash.read!(authorize?: false)

      # qualifier is a real string attribute on the persisted rows
      assert %{"subject" => 1, "resource" => 1} =
               Enum.frequencies_by(relations, & &1.qualifier)
    end

    test "a string-keyed relation missing object_id is refused before any row is written" do
      # Mutation rationale: kills a mutant that drops the valid_relation?/1
      # catch-all false clause — a string-keyed malformed relation would be
      # silently accepted and the event persisted with zero real relations.
      _object = register_object!(%{object_type: "Order", ocel_id: "order-w984ie-2"})

      assert {:error, %Ash.Error.Invalid{}} =
               record_event(%{
                 event_type: "bad",
                 ocel_id: "ev-w984ie-strkey-bad",
                 occurred_at: DateTime.utc_now(),
                 object_relations: [%{"qualifier" => "subject"}]
               })

      refute Event
             |> Ash.Query.filter(ocel_id == "ev-w984ie-strkey-bad")
             |> Ash.read_one!(authorize?: false)
    end

    test "a relation referencing a nonexistent object_id fails the EventObject write and rolls back the whole event" do
      # Mutation rationale: kills a mutant that swallows the {:halt, {:error,
      # error}} branch in create_relations/2 (e.g. returns {:cont, {:ok, event}}
      # on relation failure) — the event would persist with a missing relation,
      # violating the transactional invariant the module's moduledoc claims.
      register_object!(%{object_type: "Order", ocel_id: "order-w984ie-3"})

      assert {:error, _error} =
               record_event(%{
                 event_type: "ship",
                 ocel_id: "ev-w984ie-rollback",
                 occurred_at: DateTime.utc_now(),
                 object_relations: [
                   %{object_id: Ash.UUID.generate(), qualifier: "subject"}
                 ]
               })

      refute Event
             |> Ash.Query.filter(ocel_id == "ev-w984ie-rollback")
             |> Ash.read_one!(authorize?: false)
    end
  end
end
