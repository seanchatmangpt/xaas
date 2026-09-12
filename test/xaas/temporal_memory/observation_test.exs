defmodule Xaas.TemporalMemory.ObservationTest do
  @moduledoc """
  Real Chicago-style tests: real Ecto.Adapters.SQL.Sandbox-backed Postgres
  (Xaas.Repo), real Ash.create!/Ash.read! calls against the real
  `temporal_memory_observations` table. No mocks/stubs of any collaborator.
  """
  use ExUnit.Case, async: true

  alias Xaas.TemporalMemory.Observation

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp observe!(attrs) do
    Observation
    |> Ash.Changeset.for_create(:observe, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp supersede!(attrs) do
    Observation
    |> Ash.Changeset.for_create(:supersede, attrs)
    |> Ash.create!(authorize?: false)
  end

  test "observe creates a real row with a server-set observed_at, not a caller-supplied one" do
    before = DateTime.utc_now()

    obs =
      observe!(%{
        subject_type: "kanban_card",
        subject_id: "card-1",
        fact: %{"status" => "in_progress"},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    afterward = DateTime.utc_now()

    assert obs.subject_type == "kanban_card"
    assert obs.subject_id == "card-1"
    assert obs.fact == %{"status" => "in_progress"}
    assert obs.valid_from == ~U[2026-01-01 00:00:00.000000Z]
    assert is_nil(obs.valid_to)
    assert is_binary(obs.receipt_hash)
    assert String.length(obs.receipt_hash) == 64

    # observed_at is real server time, not something the caller could have
    # forged -- it falls strictly between two real DateTime.utc_now/0 calls
    # taken immediately around the create.
    assert DateTime.compare(obs.observed_at, before) in [:gt, :eq]
    assert DateTime.compare(obs.observed_at, afterward) in [:lt, :eq]

    persisted =
      Observation
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.id == obs.id))

    assert [%{id: id, fact: %{"status" => "in_progress"}}] = persisted
    assert id == obs.id
  end

  test "two observations with identical canonical fields produce different hashes because observed_at differs" do
    obs1 =
      observe!(%{
        subject_type: "kanban_card",
        subject_id: "card-2",
        fact: %{"status" => "todo"},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    # Force a real, distinct observed_at by sleeping past microsecond
    # resolution instead of faking the clock.
    Process.sleep(2)

    obs2 =
      observe!(%{
        subject_type: "kanban_card",
        subject_id: "card-2",
        fact: %{"status" => "todo"},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    refute obs1.receipt_hash == obs2.receipt_hash
    refute obs1.observed_at == obs2.observed_at
  end

  test "supersede requires supersedes_id" do
    assert {:error, %Ash.Error.Invalid{}} =
             Observation
             |> Ash.Changeset.for_create(:supersede, %{
               subject_type: "kanban_card",
               subject_id: "card-3",
               fact: %{"status" => "done"},
               valid_from: ~U[2026-01-01 00:00:00.000000Z]
             })
             |> Ash.create(authorize?: false)
  end

  test "supersede marks the prior observation's superseded_by_id without mutating its fact" do
    original =
      observe!(%{
        subject_type: "kanban_card",
        subject_id: "card-4",
        fact: %{"status" => "in_progress"},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    correction =
      supersede!(%{
        subject_type: "kanban_card",
        subject_id: "card-4",
        fact: %{"status" => "blocked"},
        valid_from: ~U[2026-01-01 00:00:00.000000Z],
        supersedes_id: original.id
      })

    reloaded_original = Ash.get!(Observation, original.id, authorize?: false)

    assert reloaded_original.superseded_by_id == correction.id
    # The prior row's own fact/valid_from/observed_at are byte-for-byte
    # untouched -- this is the non-destructive-correction invariant.
    assert reloaded_original.fact == %{"status" => "in_progress"}
    assert reloaded_original.observed_at == original.observed_at
    assert reloaded_original.receipt_hash == original.receipt_hash
  end
end
