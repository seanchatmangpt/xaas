defmodule Xaas.Witness.CatalogTest do
  use ExUnit.Case, async: true

  alias Xaas.Witness.Catalog
  alias Xaas.Witness.CertifiedReceipt
  alias Xaas.Witness.VerificationKey

  @baseline_path Path.join(__DIR__, "fixtures/BASELINE.json")
  @kat_path Path.join(__DIR__, "fixtures/crypto_trust_kat.json")

  # Xaas.Repo runs in :manual sandbox mode; the checkout isolates writes made
  # during this test, but rows persisted by prior runs (e2e-w55 seeds, earlier
  # non-wrapped writes) are still visible to reads. Clear the witness tables
  # inside the checked-out sandbox (same pattern as witness_live_test) so the
  # catalog assertions are hermetic across runs.
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Xaas.Repo.delete_all(CertifiedReceipt)
    Xaas.Repo.delete_all(VerificationKey)
    :ok
  end

  defp signing_surface do
    @kat_path |> File.read!() |> Jason.decode!() |> Map.fetch!("corpus")
  end

  defp ingest do
    Catalog.ingest(baseline: @baseline_path, signing_surface: signing_surface())
  end

  test "ingest loads the real affidavit baseline + KAT signing surface into resources" do
    assert {:ok, result} = ingest()

    assert result.subject == "4f654d21f3863ad89a11a62325c1dbf875cf72df"
    # SHA-256 of the raw fixture bytes, recomputed independently here.
    expected_hash =
      :sha256 |> :crypto.hash(File.read!(@baseline_path)) |> Base.encode16(case: :lower)

    assert result.payload_hash_hex == expected_hash

    # 4 KAT vectors: ES256 + ML-DSA-65 admitted; the hybrid and SLH-DSA
    # vectors sit outside the admitted enum and are skipped, typed.
    assert length(result.receipts) == 2
    assert [%{algorithm: :es256}, %{algorithm: :ml_dsa65}] = result.receipts

    assert result.skipped == [
             {1, "ES256+ML-DSA-65", :algorithm_not_in_admitted_enum},
             {3, "SLH-DSA-SHA2-128s", :algorithm_not_in_admitted_enum}
           ]

    assert Enum.all?(result.receipts, fn r ->
             String.starts_with?(r.subject, result.subject <> ":")
           end)

    # verification keys registered idempotently per unique key material
    key_ids =
      VerificationKey
      |> Ash.read!()
      |> Enum.map(&{&1.algorithm, &1.key_material_hex})
      |> MapSet.new()

    assert MapSet.size(key_ids) == 2
    assert Enum.all?(Ash.read!(VerificationKey), &(&1.created_at != nil))
  end

  test "ingest is deterministic: re-ingesting the same fixtures re-derives the same payload hash and subjects" do
    {:ok, first} = ingest()
    {:ok, second} = ingest()

    assert first.payload_hash_hex == second.payload_hash_hex
    assert Enum.map(first.receipts, & &1.subject) == Enum.map(second.receipts, & &1.subject)
  end

  test "record_verification records a real verification result with verified_at" do
    {:ok, %{receipts: [es256_receipt | _]}} = ingest()

    refute es256_receipt.verified
    refute es256_receipt.verified_at

    now = DateTime.utc_now()
    assert {:ok, verified} = Catalog.record_verification(es256_receipt, true, now)

    assert verified.verified
    assert %DateTime{} = verified.verified_at
    assert DateTime.compare(verified.verified_at, now) in [:gt, :eq]

    # persisted, not just returned
    reloaded = Ash.get!(CertifiedReceipt, es256_receipt.id)
    assert reloaded.verified and reloaded.verified_at != nil
  end

  test "immutability: no update/destroy action exists on the payload surface" do
    {:ok, %{receipts: [receipt | _]}} = ingest()

    # the resource defines no general :update action and no :destroy
    assert_raise ArgumentError,
                 ~r/No such update action.*:update/,
                 fn ->
                   receipt
                   |> Ash.Changeset.for_update(:update, %{subject: "tampered"})
                   |> Ash.update()
                 end

    assert_raise ArgumentError, ~r/No such destroy action/, fn ->
      receipt |> Ash.Changeset.for_destroy(:destroy) |> Ash.destroy()
    end

    # and the payload fields are not accepted by the only update action
    assert %Ash.Changeset{} =
             cs = Ash.Changeset.for_update(receipt, :record_verification, %{subject: "tampered"})

    refute cs.attributes |> Map.has_key?(:subject)
  end

  test "verification results are write-once: re-verification is refused" do
    {:ok, %{receipts: [receipt | _]}} = ingest()

    assert {:ok, _} = Catalog.record_verification(receipt, true)

    {:ok, fresh} = Ash.get!(CertifiedReceipt, receipt.id) |> then(&{:ok, &1})
    assert fresh.verified

    assert {:error, %Ash.Error.Invalid{}} = Catalog.record_verification(fresh, true)

    # still exactly one verification timestamp, unchanged
    reloaded = Ash.get!(CertifiedReceipt, receipt.id)
    assert reloaded.verified_at == fresh.verified_at
  end

  test "list_by_algorithm lists ingested receipts by admitted algorithm" do
    {:ok, %{receipts: receipts}} = ingest()

    assert [%CertifiedReceipt{} = r] = Catalog.list_by_algorithm(:es256)
    assert r.signature_hex != ""

    assert [%CertifiedReceipt{}] = Catalog.list_by_algorithm(:ml_dsa65)
    assert [] = Catalog.list_by_algorithm(:ed25519)

    assert length(receipts) == 2
  end
end
