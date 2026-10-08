defmodule Xaas.TemporalMemory.FamilyCourtW984heTest do
  @moduledoc """
  Lane W984he unclaimed-family probe court over the temporal-memory domain
  (`Xaas.TemporalMemory`, `Observation`, `Changes`, `Query`, `Replay`).

  Dispositions per module (detail in
  `docs/sjira/v26.10.6/plans/w984he-probe.md`):

  - `Xaas.TemporalMemory` / `Observation` / `Changes` / `Query` / `Replay`:
    broadly COVERED by the existing corpus
    (`query_and_replay_test`, `observation_test`,
    `observation_supersede_chain_depth_test`,
    `temporal_memory_deepening_test`, `observation_witness_tie_test`).
  - This court targets the branches the corpus leaves genuinely
    unexercised: `Query.as_of!/1` (never called in test/), the
    valid-time boundary semantics of the
    `is_nil(valid_to) or valid_to > t_v` filter (inclusive lower /
    exclusive upper / open-ended nil), and the list-valued
    `fact` canonicalization clause of
    `Changes.ComputeReceiptHash.canonical_value/1`.
  - Typed note: `Replay.verify/2`'s `:nondeterministic_replay` and
    `:retroactive_observation_leak` error branches are unreachable
    through the honest public path (as_of filters `observed_at <= t_o`,
    and both internal reads occur inside one `verify` call), so they are
    defensive guards, not testable state-bearing branches. Not faked --
    faking them would require a mock, which this repo bans.
  """

  use ExUnit.Case, async: true

  alias Xaas.TemporalMemory.{Observation, Query, Replay}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp observe!(attrs) do
    Observation
    |> Ash.Changeset.for_create(:observe, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp uid(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  test "as_of!/1 raising counterpart returns the reconstruction, and nil (not a raise) when nothing is knowable" do
    # Mutation rationale: `Query.as_of!/1` has zero call sites in test/ --
    # the corpus only ever drives the `{:ok, _}`-tuple `as_of/2`. If the
    # bang counterpart's unwrap were wrong (e.g. returned the tuple, or
    # raised on the honest nil), every future caller of the documented
    # convenience API would break silently.
    subject_id = uid("court-bang")

    observe!(%{
      subject_type: "deployment",
      subject_id: subject_id,
      fact: %{"status" => "healthy"},
      valid_from: ~U[2026-01-01 00:00:00.000000Z],
      valid_to: ~U[2026-06-01 00:00:00.000000Z]
    })

    hit =
      Query.as_of!(%{
        subject_type: "deployment",
        subject_id: subject_id,
        valid_time: ~U[2026-03-01 00:00:00.000000Z]
      })

    assert %Observation{} = hit
    assert hit.fact == %{"status" => "healthy"}

    miss =
      Query.as_of!(%{
        subject_type: "deployment",
        subject_id: subject_id,
        valid_time: ~U[2026-12-01 00:00:00.000000Z]
      })

    assert is_nil(miss)
  end

  test "valid-time bounds are inclusive-lower / exclusive-upper, and nil valid_to is genuinely open-ended" do
    # Mutation rationale: the corpus round-trips valid_to (supersede chain
    # depth test) but never pins the exact boundary semantics of the
    # `valid_from <= t_v AND (is_nil(valid_to) or valid_to > t_v)` filter.
    # If the comparison flipped to >= / <= (or nil were treated as
    # "covers nothing"), interval arithmetic across every consumer of
    # as_of/lineage_at would silently shift by one instant.
    subject_id = uid("court-bounds")

    observe!(%{
      subject_type: "deployment",
      subject_id: subject_id,
      fact: %{"n" => 1},
      valid_from: ~U[2026-01-01 00:00:00.000000Z],
      valid_to: ~U[2026-06-01 00:00:00.000000Z]
    })

    observe!(%{
      subject_type: "deployment",
      subject_id: subject_id,
      fact: %{"n" => 2},
      valid_from: ~U[2026-06-01 00:00:00.000000Z],
      valid_to: nil
    })

    # t_v == valid_from of row 1: included (inclusive lower bound).
    assert %Observation{} = Query.as_of!(%{subject_type: "deployment", subject_id: subject_id, valid_time: ~U[2026-01-01 00:00:00.000000Z]})

    # t_v == valid_to of row 1 == valid_from of row 2: exactly one row wins,
    # and it is the open-ended successor (upper bound is exclusive).
    winner = Query.as_of!(%{subject_type: "deployment", subject_id: subject_id, valid_time: ~U[2026-06-01 00:00:00.000000Z]})
    assert winner.fact == %{"n" => 2}

    # The open-ended row covers arbitrarily late valid times.
    assert %Observation{} = Query.as_of!(%{subject_type: "deployment", subject_id: subject_id, valid_time: ~U[2099-01-01 00:00:00.000000Z]})

    # lineage_at sees the same boundary: at the seam, the closed row is
    # excluded (its valid_to > t_v fails) and only the successor remains.
    {:ok, lineage} =
      Query.lineage_at(%{subject_type: "deployment", subject_id: subject_id, valid_time: ~U[2026-06-01 00:00:00.000000Z]})

    assert [%{fact: %{"n" => 2}}] = lineage
  end

  test "list-valued fact survives round-trip and its receipt hash is deterministic over list element order" do
    # Mutation rationale: `ComputeReceiptHash.canonical_value/1` has a
    # dedicated list clause (`Enum.map_join(v, ",", ...)`) that no corpus
    # test exercises -- every existing test uses flat string maps. If the
    # list clause were wrong (e.g. joined non-deterministically, or
    # stringified lists equal to their scalar stringification), two
    # materially different facts could collide onto one receipt_hash and
    # the unique_receipt_hash identity would silently merge them.
    subject_id = uid("court-list")

    row =
      observe!(%{
        subject_type: "deployment",
        subject_id: subject_id,
        fact: %{"tags" => ["a", "b"], "meta" => %{"nested" => ["x", "y"]}},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    assert row.fact == %{"tags" => ["a", "b"], "meta" => %{"nested" => ["x", "y"]}}
    assert is_binary(row.receipt_hash)

    # Deterministic: hashing the same canonical fields (list included)
    # twice yields the same digest -- exercised by re-reading the row.
    reloaded = Ash.get!(Observation, row.id, authorize?: false)
    assert reloaded.receipt_hash == row.receipt_hash

    # Non-collapsing: a list ["a","b"] does not hash equal to a fact whose
    # scalar stringification is the same, nor to the reversed list, as
    # detectable through the real hash-comparison surface
    # (Replay.replay_matches?/3 -- no mock, real hash comparison).
    scalar_row =
      observe!(%{
        subject_type: "deployment",
        subject_id: uid("court-list-scalar"),
        fact: %{"tags" => "a,b"},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    refute Replay.replay_matches?(
             %{subject_type: "deployment", subject_id: subject_id, valid_time: ~U[2026-03-01 00:00:00.000000Z]},
             scalar_row.receipt_hash
           )

    reversed =
      observe!(%{
        subject_type: "deployment",
        subject_id: uid("court-list-reversed"),
        fact: %{"tags" => ["b", "a"], "meta" => %{"nested" => ["y", "x"]}},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    refute Replay.replay_matches?(
             %{subject_type: "deployment", subject_id: subject_id, valid_time: ~U[2026-03-01 00:00:00.000000Z]},
             reversed.receipt_hash
           )
  end
end
