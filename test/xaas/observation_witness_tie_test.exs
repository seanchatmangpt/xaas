defmodule Xaas.ObservationWitnessTieTest do
  @moduledoc """
  W920 — cross-surface court tying the TemporalMemory Observation surface
  (W724-deepened deterministic replay verifier) to the Witness catalog
  (W709-durability'd ingest surface).

  The composition, read from the code before writing:

  - `Xaas.TemporalMemory.Changes.ComputeReceiptHash` computes
    `receipt_hash = hex(sha256(canonical_string))` where `canonical_string`
    is a key-sorted `k=v`-joined (`&`-separated) encoding of the bitemporal
    fields (`subject_type`, `subject_id`, `fact`, `valid_from`, `valid_to`,
    `observed_at`, `supersedes_id`).
  - `Xaas.Witness.Catalog.ingest/1` derives each `CertifiedReceipt`'s
    `payload_hash_hex = hex(sha256(vector["message_hex"]))` -- hashing the
    `message_hex` STRING's bytes.

  Therefore feeding the observation's canonical preimage string as the
  signing-surface `message_hex` yields a witness receipt whose
  `payload_hash_hex` is byte-identical to the observation's
  `receipt_hash` -- the two surfaces DO compose, with one typed
  composition constraint (see `typed_gaps/0` below and the lane receipt).

  Chicago discipline: real Postgres sandbox, real Ash `:observe` /
  `:supersede` / read actions, real `Catalog.ingest/1` and
  `record_verification/3`, assertions on reloaded rows. No mocks.

  No `@moduletag :eu_ai_act`: this is the campaign's own process-memory
  chain, not an Art-12 record-keeping boundary.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  alias Xaas.TemporalMemory.Observation
  alias Xaas.TemporalMemory.Replay
  alias Xaas.Witness.Catalog
  alias Xaas.Witness.CertifiedReceipt

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

  # Re-derivation of ComputeReceiptHash's canonical preimage from the
  # RELOADED row's public attributes (a real recomputation, not a stub --
  # the change module's private canonicalization mirrored from its source).
  defp canonical_preimage(o) do
    %{
      subject_type: o.subject_type,
      subject_id: o.subject_id,
      fact: o.fact || %{},
      valid_from: DateTime.to_iso8601(o.valid_from),
      valid_to: iso_or_nil(o.valid_to),
      observed_at: DateTime.to_iso8601(o.observed_at),
      supersedes_id: o.supersedes_id
    }
    |> canonical_json()
  end

  defp iso_or_nil(nil), do: nil
  defp iso_or_nil(%DateTime{} = d), do: DateTime.to_iso8601(d)

  defp canonical_json(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Enum.map(fn {k, v} -> [to_string(k), ?=, canonical_value(v)] end)
    |> Enum.intersperse(?&)
    |> IO.iodata_to_binary()
  end

  defp canonical_value(v) when is_map(v), do: canonical_json(v)
  defp canonical_value(v) when is_list(v), do: Enum.map_join(v, ",", &canonical_value/1)
  defp canonical_value(nil), do: "nil"
  defp canonical_value(v), do: to_string(v)

  defp sha256_hex(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp ingest_via_catalog!(subject, message, algorithm \\ "Ed25519") do
    Catalog.ingest(
      baseline: %{"subject_commit" => subject},
      signing_surface: [
        %{
          "algorithm" => algorithm,
          "message_hex" => message,
          "signature_hex" => "00",
          "public_key_hex" => "aa"
        }
      ]
    )
  end

  defp receipt_for(payload_hash) do
    CertifiedReceipt
    |> Ash.Query.filter(payload_hash_hex == ^payload_hash)
    |> Ash.read!()
  end

  # ---------------------------------------------------------------------------
  # (a) observation -> replay receipt_hash -> CertifiedReceipt via real Catalog
  # ---------------------------------------------------------------------------

  test "a real observation sequence's replay receipt hash is ingestable as a CertifiedReceipt payload via the real Catalog" do
    subject_id = unique_id("obs-witness-tie")
    t_valid = dt("2026-05-01T00:00:00.000000Z")

    o1 =
      observe!(%{
        subject_type: "deployment",
        subject_id: subject_id,
        fact: %{"phase" => "canary"},
        valid_from: t_valid
      })

    Process.sleep(2)

    o2 =
      supersede!(%{
        subject_type: "deployment",
        subject_id: subject_id,
        fact: %{"phase" => "stable"},
        valid_from: t_valid,
        supersedes_id: o1.id
      })

    # Pin the replay bound AFTER the correction so the full sequence is
    # knowable (W724's lesson: determinism is a property of a fixed bound).
    t_o_bound = DateTime.utc_now()

    # Replay the sequence deterministically at the pinned bound: the
    # reconstructed observation is the later-recorded correction.
    params = %{
      subject_type: "deployment",
      subject_id: subject_id,
      valid_time: t_valid,
      observation_time: t_o_bound
    }

    assert {:ok, receipt} = Replay.verify(params)
    assert receipt.observation.id == o2.id
    replay_hash = receipt.observation.receipt_hash
    assert replay_hash == o2.receipt_hash

    # The hash is a real function of the reloaded row: recompute the
    # canonical preimage from public attributes and check it reproduces
    # the persisted receipt_hash exactly.
    reloaded = Ash.get!(Observation, o2.id, authorize?: false)
    preimage = canonical_preimage(reloaded)
    assert sha256_hex(preimage) == replay_hash

    # Ingest that hash through the REAL Catalog: preimage as message_hex,
    # so the catalog's own derivation (sha256 of the message_hex string)
    # lands byte-identically on the observation's receipt_hash.
    assert {:ok, result} = ingest_via_catalog!("deployment:#{subject_id}", preimage)
    assert [witness_receipt] = result.receipts
    assert witness_receipt.payload_hash_hex == replay_hash
    assert witness_receipt.algorithm == :ed25519

    # Assert real persisted rows, not just the return value.
    assert [row] = receipt_for(replay_hash)
    assert row.id == witness_receipt.id
    assert row.payload_hash_hex == replay_hash
    assert String.starts_with?(row.subject, "deployment:#{subject_id}")

    # And the witness verification write-once path works on the tied row.
    assert {:ok, verified} = Catalog.record_verification(row, true)
    assert verified.verified == true
    assert %DateTime{} = verified.verified_at
  end

  # ---------------------------------------------------------------------------
  # (b) tampered sequence -> different hash -> distinguishable witness rows
  # ---------------------------------------------------------------------------

  test "a tampered observation sequence produces a different receipt hash and the witness catalog records distinguishable rows" do
    subject_id = unique_id("obs-witness-tamper")
    t_valid = dt("2026-06-01T00:00:00.000000Z")

    o_real =
      observe!(%{
        subject_type: "release",
        subject_id: subject_id,
        fact: %{"version" => "2.0.0"},
        valid_from: t_valid
      })

    o_tampered =
      observe!(%{
        subject_type: "release",
        subject_id: subject_id,
        fact: %{"version" => "2.0.0-tampered"},
        valid_from: t_valid
      })

    assert o_real.receipt_hash != o_tampered.receipt_hash

    params = %{subject_type: "release", subject_id: subject_id, valid_time: t_valid}

    # as_of's latest-known pick resolves to the LATER-recorded (tampered)
    # line; the point is the hashes are fully distinguishable either way.
    assert Replay.replay_matches?(params, o_tampered.receipt_hash)
    refute Replay.replay_matches?(params, o_real.receipt_hash)

    real_preimage = canonical_preimage(o_real)
    tampered_preimage = canonical_preimage(o_tampered)
    assert real_preimage != tampered_preimage

    assert {:ok, real_ingest} = ingest_via_catalog!("release:#{subject_id}", real_preimage)
    assert {:ok, tampered_ingest} = ingest_via_catalog!("release:#{subject_id}", tampered_preimage)

    [real_wr] = real_ingest.receipts
    [tampered_wr] = tampered_ingest.receipts

    assert real_wr.payload_hash_hex == o_real.receipt_hash
    assert tampered_wr.payload_hash_hex == o_tampered.receipt_hash
    assert real_wr.id != tampered_wr.id

    # The tampered lineage is distinguishable in the persisted table: two
    # separate rows, one per hash, no cross-contamination.
    assert [real_row] = receipt_for(o_real.receipt_hash)
    assert [tampered_row] = receipt_for(o_tampered.receipt_hash)
    assert real_row.id != tampered_row.id

    # Verifying the real witness leaves the tampered one unverified
    # (W709's tamper-distinguishability contract, carried across surfaces).
    assert {:ok, verified_real} = Catalog.record_verification(real_row, true)
    assert verified_real.verified == true

    reloaded_tampered = Ash.get!(CertifiedReceipt, tampered_wr.id)
    assert reloaded_tampered.verified == false
  end

  # ---------------------------------------------------------------------------
  # (c) determinism x2 across BOTH surfaces
  # ---------------------------------------------------------------------------

  test "replay determinism x2 carries through the catalog: identical hashes and an idempotent re-ingest" do
    subject_id = unique_id("obs-witness-det")
    t_valid = dt("2026-07-01T00:00:00.000000Z")

    o =
      observe!(%{
        subject_type: "capacity_plan",
        subject_id: subject_id,
        fact: %{"replicas" => 7},
        valid_from: t_valid
      })

    params = %{
      subject_type: "capacity_plan",
      subject_id: subject_id,
      valid_time: t_valid,
      observation_time: DateTime.utc_now()
    }

    assert {:ok, run1} = Replay.verify(params)
    assert {:ok, run2} = Replay.verify(params)
    assert run1.observation.receipt_hash == run2.observation.receipt_hash
    assert run1.observation.receipt_hash == o.receipt_hash

    preimage = canonical_preimage(o)
    assert {:ok, first} = ingest_via_catalog!("capacity_plan:#{subject_id}", preimage)
    assert {:ok, second} = ingest_via_catalog!("capacity_plan:#{subject_id}", preimage)

    # Determinism on the observation axis AND idempotent reuse on the
    # witness axis: the second ingest re-admits the same row (W709's
    # documented idempotency contract), never a duplicate.
    assert [first_wr] = first.receipts
    assert [second_wr] = second.receipts
    assert first_wr.id == second_wr.id

    assert rows = receipt_for(o.receipt_hash)
    assert length(rows) == 1
    assert hd(rows).payload_hash_hex == o.receipt_hash
  end
end
