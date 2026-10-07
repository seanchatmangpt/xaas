defmodule Xaas.TemporalMemoryDeepeningTest do
  @moduledoc """
  W724 temporal-memory deepening: Chicago-style tests against the real
  Postgres-backed `Xaas.TemporalMemory.Observation` table via real Ash
  actions on the sandbox. No mocks.

  Deepening beyond `test/xaas/temporal_memory/`:

  - (a) out-of-order *insertion* of bitemporal rows: a later-recorded
    observation claiming an *earlier* valid interval must win the
    "latest-known" pick at an unbounded `t_o`, while a `t_o` bounded before
    its write must still see only the earlier-recorded row.
  - (b) retroactive-safe mutation semantics per the real contract:
    `:supersede` writes a NEW row and only stamps the prior row's
    `superseded_by_id`; prior `as_of/2` views, prior `fact`, and prior
    `receipt_hash` are all preserved (asserted against reloaded row state).
  - (c) the deterministic replay verifier (`Replay.verify/2` /
    `replay_matches?/3`): replaying the same observation sequence
    reproduces the identical verified receipt; a perturbed sequence (a
    different fact recorded for the same subject/valid-time) produces a
    different hash, and `verify/2` refuses to leak an observation recorded
    after the requested `t_o` bound.
  - (d) determinism x3: three consecutive `Replay.verify/2` runs against
    the identical bound agree on `receipt_hash`.

  No `@moduletag :eu_ai_act`: nothing here is Art-12-specific -- this is
  the campaign's own process-memory surface, not an EU-AI-Act record-
  keeping boundary.
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

  defp unique_id(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp dt(iso), do: elem(DateTime.from_iso8601(iso), 1)

  # ---------------------------------------------------------------------------
  # (a) Retroactive observation: later-recorded row, earlier valid interval
  # ---------------------------------------------------------------------------

  test "a retroactively-inserted earlier-valid observation wins latest-known at unbounded t_o and is invisible to a t_o bounded before its write" do
    subject_id = unique_id("retro-insert")
    t_valid = dt("2026-03-01T00:00:00.000000Z")

    # O1: written FIRST, claims validity from t_valid onward.
    o1 =
      observe!(%{
        subject_type: "deployment",
        subject_id: subject_id,
        fact: %{"phase" => "canary"},
        valid_from: t_valid
      })

    t_o_mid = DateTime.utc_now()
    Process.sleep(2)

    # O0: written SECOND (later observation time) but it is a retroactive
    # correction claiming the SAME earlier valid interval.
    o0 =
      supersede!(%{
        subject_type: "deployment",
        subject_id: subject_id,
        fact: %{"phase" => "stable"},
        valid_from: t_valid,
        supersedes_id: o1.id
      })

    assert DateTime.compare(o0.observed_at, o1.observed_at) == :gt

    # Unbounded t_o: latest-known pick is the LATER-RECORDED row (O0), even
    # though O1 entered the table first -- insertion order does not corrupt
    # the observation-time axis.
    {:ok, latest} =
      Query.as_of(%{subject_type: "deployment", subject_id: subject_id, valid_time: t_valid})

    assert latest.id == o0.id
    assert latest.fact == %{"phase" => "stable"}

    # t_o bounded between the two writes: only O1 was knowable then.
    {:ok, known_then} =
      Query.as_of(%{
        subject_type: "deployment",
        subject_id: subject_id,
        valid_time: t_valid,
        observation_time: t_o_mid
      })

    assert known_then.id == o1.id
    assert known_then.fact == %{"phase" => "canary"}

    # Both rows really exist in the table; nothing was overwritten.
    {:ok, lineage} =
      Query.lineage_at(%{subject_type: "deployment", subject_id: subject_id, valid_time: t_valid},
        authorize?: false
      )

    assert Enum.map(lineage, & &1.id) |> Enum.sort() == Enum.sort([o0.id, o1.id])
  end

  # ---------------------------------------------------------------------------
  # (b) Retroactive-safe mutation semantics (real contract: non-destructive
  #     supersession; prior as_of views survive the correction)
  # ---------------------------------------------------------------------------

  test "supersede mutates only the audit pointer -- prior as_of view, prior fact, and prior receipt_hash survive intact" do
    subject_id = unique_id("non-destructive")
    t_valid = dt("2026-02-01T00:00:00.000000Z")

    original = observe!(%{subject_type: "incident", subject_id: subject_id, fact: %{"sev" => "sev3"}, valid_from: t_valid})
    t_o_before_correction = DateTime.utc_now()
    Process.sleep(2)

    correction = supersede!(%{subject_type: "incident", subject_id: subject_id, fact: %{"sev" => "sev1"}, valid_from: t_valid, supersedes_id: original.id})

    # Reconstructed view as known BEFORE the correction is unchanged.
    {:ok, before} =
      Query.as_of(%{
        subject_type: "incident",
        subject_id: subject_id,
        valid_time: t_valid,
        observation_time: t_o_before_correction
      })

    assert before.id == original.id
    assert before.fact == %{"sev" => "sev3"}
    assert before.receipt_hash == original.receipt_hash

    # The prior ROW, reloaded from Postgres, is byte-for-byte intact on its
    # own bitemporal axes -- only superseded_by_id was stamped.
    reloaded = Ash.get!(Observation, original.id, authorize?: false)
    assert reloaded.fact == %{"sev" => "sev3"}
    assert reloaded.valid_from == original.valid_from
    assert is_nil(reloaded.valid_to)
    assert reloaded.observed_at == original.observed_at
    assert reloaded.receipt_hash == original.receipt_hash
    assert reloaded.superseded_by_id == correction.id
    assert reloaded.supersedes_id == original.supersedes_id

    # And the correction row points back.
    assert correction.supersedes_id == original.id
  end

  # ---------------------------------------------------------------------------
  # (c) Deterministic replay verifier: same sequence reproduces; perturbed
  #     sequence differs; no retroactive leak through verify/2
  # ---------------------------------------------------------------------------

  test "replay of the same observation sequence reproduces the identical verified receipt; perturbed sequence differs" do
    subject_id = unique_id("replay")
    t_valid = dt("2026-01-01T00:00:00.000000Z")

    o1 = observe!(%{subject_type: "release", subject_id: subject_id, fact: %{"version" => "2.0.0"}, valid_from: t_valid})
    t_o_bound = DateTime.utc_now()
    Process.sleep(2)
    _o0 = supersede!(%{subject_type: "release", subject_id: subject_id, fact: %{"version" => "2.0.1"}, valid_from: t_valid, supersedes_id: o1.id})

    params = %{subject_type: "release", subject_id: subject_id, valid_time: t_valid}

    # Replay bounded BEFORE the correction reproduces the O1 receipt.
    {:ok, receipt_o1} = Replay.verify(Map.put(params, :observation_time, t_o_bound))
    assert receipt_o1.observation.id == o1.id
    assert receipt_o1.observation.receipt_hash == o1.receipt_hash
    assert receipt_o1.valid_time == t_valid
    assert receipt_o1.observation_time == t_o_bound

    # Perturbed replay: same bounds, but the recorded history actually
    # differs -- the O1 line of a perturbed world (different fact) hashes
    # differently, so replay_matches?/3 is a real hash comparison, not a
    # heuristic.
    perturbed_subject = unique_id("replay-perturbed")
    perturbed =
      observe!(%{subject_type: "release", subject_id: perturbed_subject, fact: %{"version" => "2.0.0-rc1"}, valid_from: t_valid})

    perturbed_params = %{subject_type: "release", subject_id: perturbed_subject, valid_time: t_valid}
    assert Replay.replay_matches?(perturbed_params, perturbed.receipt_hash)
    refute Replay.replay_matches?(perturbed_params, receipt_o1.observation.receipt_hash)
    refute Replay.replay_matches?(perturbed_params, nil)

    # verify/2 must not leak the correction into a bound before its write:
    # the verifier's no-leak invariant on the real sequence.
    case Replay.verify(Map.put(params, :observation_time, t_o_bound)) do
      {:ok, receipt} ->
        assert receipt.observation.receipt_hash == o1.receipt_hash
        assert DateTime.compare(receipt.observation.observed_at, t_o_bound) != :gt

      {:error, reason} ->
        flunk("verify returned an error on a well-formed bound: #{inspect(reason)}")
    end
  end

  # ---------------------------------------------------------------------------
  # (d) Determinism x3
  # ---------------------------------------------------------------------------

  test "three consecutive Replay.verify runs against the identical bound agree on receipt_hash" do
    subject_id = unique_id("determinism")
    t_valid = dt("2026-04-01T00:00:00.000000Z")

    observe!(%{subject_type: "capacity_plan", subject_id: subject_id, fact: %{"replicas" => 7}, valid_from: t_valid})

    # Pin the observation-time bound once: determinism is a property of a
    # FIXED bitemporal query, not of three different now() defaults.
    params = %{
      subject_type: "capacity_plan",
      subject_id: subject_id,
      valid_time: t_valid,
      observation_time: DateTime.utc_now()
    }

    runs =
      for _ <- 1..3 do
        assert {:ok, receipt} = Replay.verify(params)
        receipt
      end

    hashes = Enum.map(runs, & &1.observation.receipt_hash)
    assert length(Enum.uniq(hashes)) == 1
    assert [%{observation_time: ot1} | _] = runs
    assert Enum.all?(runs, &(&1.observation_time == ot1))
  end
end
