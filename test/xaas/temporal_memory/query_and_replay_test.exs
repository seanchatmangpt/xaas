defmodule Xaas.TemporalMemory.QueryAndReplayTest do
  @moduledoc """
  Real Chicago-style tests exercising the ticket's stated invariant --
  `Replay(d_t, O_<=t) = d_t` -- and its named falsifiers, against a real
  Postgres-backed `Xaas.TemporalMemory.Observation` table. No mocks.
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

  defp supersede!(attrs) do
    Observation
    |> Ash.Changeset.for_create(:supersede, attrs)
    |> Ash.create!(authorize?: false)
  end

  test "as_of reconstructs the observation covering a valid-time bound" do
    subject_id = "deployment-#{System.unique_integer([:positive])}"

    observe!(%{
      subject_type: "deployment",
      subject_id: subject_id,
      fact: %{"status" => "healthy"},
      valid_from: ~U[2026-01-01 00:00:00.000000Z],
      valid_to: ~U[2026-06-01 00:00:00.000000Z]
    })

    {:ok, found} =
      Query.as_of(%{
        subject_type: "deployment",
        subject_id: subject_id,
        valid_time: ~U[2026-03-01 00:00:00.000000Z]
      })

    assert found.fact == %{"status" => "healthy"}

    {:ok, out_of_range} =
      Query.as_of(%{
        subject_type: "deployment",
        subject_id: subject_id,
        valid_time: ~U[2026-12-01 00:00:00.000000Z]
      })

    assert is_nil(out_of_range)
  end

  test "falsifier: a retroactive observation never leaks into a reconstruction bounded before it was recorded" do
    subject_id = "incident-#{System.unique_integer([:positive])}"

    # A first observation, recorded now, valid from the start of the year.
    first =
      observe!(%{
        subject_type: "incident",
        subject_id: subject_id,
        fact: %{"severity" => "sev3"},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    t_o_before_retroactive_write = DateTime.utc_now()
    Process.sleep(2)

    # A retroactive correction: recorded *now* (observed_at = now), but
    # claiming to have been valid earlier than `first` -- exactly the
    # "retroactive observation" the ticket's falsifier names.
    _retroactive =
      supersede!(%{
        subject_type: "incident",
        subject_id: subject_id,
        fact: %{"severity" => "sev1"},
        valid_from: ~U[2026-01-01 00:00:00.000000Z],
        supersedes_id: first.id
      })

    # Reconstructing "as known at t_o_before_retroactive_write" must not see
    # the retroactive sev1 correction -- it was not yet knowable then.
    {:ok, reconstructed} =
      Query.as_of(%{
        subject_type: "incident",
        subject_id: subject_id,
        valid_time: ~U[2026-01-15 00:00:00.000000Z],
        observation_time: t_o_before_retroactive_write
      })

    assert reconstructed.fact == %{"severity" => "sev3"}
    refute reconstructed.fact == %{"severity" => "sev1"}
  end

  test "falsifier: correction is a new event, not a silent overwrite -- prior belief remains reconstructable" do
    subject_id = "capacity-plan-#{System.unique_integer([:positive])}"

    original =
      observe!(%{
        subject_type: "capacity_plan",
        subject_id: subject_id,
        fact: %{"replicas" => 3},
        valid_from: ~U[2026-01-01 00:00:00.000000Z]
      })

    t_o_after_original = DateTime.utc_now()
    Process.sleep(2)

    supersede!(%{
      subject_type: "capacity_plan",
      subject_id: subject_id,
      fact: %{"replicas" => 5},
      valid_from: ~U[2026-01-01 00:00:00.000000Z],
      supersedes_id: original.id
    })

    {:ok, before_correction} =
      Query.as_of(%{
        subject_type: "capacity_plan",
        subject_id: subject_id,
        valid_time: ~U[2026-01-01 00:00:00.000000Z],
        observation_time: t_o_after_original
      })

    {:ok, after_correction} =
      Query.as_of(%{
        subject_type: "capacity_plan",
        subject_id: subject_id,
        valid_time: ~U[2026-01-01 00:00:00.000000Z]
      })

    assert before_correction.fact == %{"replicas" => 3}
    assert after_correction.fact == %{"replicas" => 5}
  end

  test "falsifier: temporal query API answers valid-time and observation-time as independent axes" do
    subject_id = "budget-#{System.unique_integer([:positive])}"

    old =
      observe!(%{
        subject_type: "budget",
        subject_id: subject_id,
        fact: %{"cap" => 100},
        valid_from: ~U[2026-01-01 00:00:00.000000Z],
        valid_to: ~U[2026-02-01 00:00:00.000000Z]
      })

    _new =
      observe!(%{
        subject_type: "budget",
        subject_id: subject_id,
        fact: %{"cap" => 200},
        valid_from: ~U[2026-02-01 00:00:00.000000Z]
      })

    # "what was true at t_v" for the earlier interval, independent of t_o.
    {:ok, valid_then} =
      Query.as_of(%{
        subject_type: "budget",
        subject_id: subject_id,
        valid_time: ~U[2026-01-15 00:00:00.000000Z]
      })

    assert valid_then.fact == %{"cap" => 100}

    # "what did we know at t_o" bounded to just after the first write only.
    {:ok, known_then} =
      Query.as_of(%{
        subject_type: "budget",
        subject_id: subject_id,
        valid_time: ~U[2026-01-15 00:00:00.000000Z],
        observation_time: old.observed_at
      })

    assert known_then.fact == %{"cap" => 100}
  end

  test "Replay.verify: deterministic reconstruction matches the stated invariant Replay(d_t, O_<=t) = d_t" do
    subject_id = "release-#{System.unique_integer([:positive])}"

    observe!(%{
      subject_type: "release",
      subject_id: subject_id,
      fact: %{"version" => "1.0.0"},
      valid_from: ~U[2026-01-01 00:00:00.000000Z]
    })

    {:ok, receipt} =
      Replay.verify(%{
        subject_type: "release",
        subject_id: subject_id,
        valid_time: ~U[2026-01-02 00:00:00.000000Z]
      })

    assert receipt.observation.fact == %{"version" => "1.0.0"}

    # replay_matches?/3 -- comparing a fresh reconstruction against a
    # previously captured receipt_hash.
    assert Replay.replay_matches?(
             %{
               subject_type: "release",
               subject_id: subject_id,
               valid_time: ~U[2026-01-02 00:00:00.000000Z]
             },
             receipt.observation.receipt_hash
           )

    refute Replay.replay_matches?(
             %{
               subject_type: "release",
               subject_id: subject_id,
               valid_time: ~U[2026-01-02 00:00:00.000000Z]
             },
             "0000000000000000000000000000000000000000000000000000000000000000"
           )
  end

  test "Replay.verify returns {:ok, %{observation: nil, ...}} honestly when nothing is knowable, not an error" do
    {:ok, receipt} =
      Replay.verify(%{
        subject_type: "release",
        subject_id: "never-observed-#{System.unique_integer([:positive])}",
        valid_time: ~U[2026-01-02 00:00:00.000000Z]
      })

    assert is_nil(receipt.observation)
  end
end
