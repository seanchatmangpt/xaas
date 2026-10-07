defmodule Xaas.Witness.CatalogDurabilityTest do
  @moduledoc """
  Durability court for the `Xaas.Witness.Catalog` ingest path (affidavit
  mutation-baseline JSON -> `CertifiedReceipt` rows).

  EU AI Act anchor: Art. 12 record-keeping / Art. 74 post-market
  monitoring class -- automatically generated logs over a pinned subject
  must be durable, tamper-distinguishable, and attributable to the
  verification key actually used.
  """

  use ExUnit.Case, async: true

  # EU AI Act Art. 12 record-keeping / Art. 74 post-market monitoring class
  @moduletag :eu_ai_act

  alias Xaas.Witness.Catalog
  alias Xaas.Witness.CertifiedReceipt
  alias Xaas.Witness.VerificationKey

  @baseline_path Path.join(__DIR__, "fixtures/BASELINE.json")
  @kat_path Path.join(__DIR__, "fixtures/crypto_trust_kat.json")

  # Xaas.Repo runs in :manual sandbox mode; clear the witness tables inside
  # the checked-out sandbox so assertions are hermetic (same pattern as
  # catalog_test).
  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Xaas.Repo.delete_all(CertifiedReceipt)
    Xaas.Repo.delete_all(VerificationKey)
    :ok
  end

  defp signing_surface do
    @kat_path |> File.read!() |> Jason.decode!() |> Map.fetch!("corpus")
  end

  defp ingest(opts \\ []) do
    baseline = Keyword.get(opts, :baseline, @baseline_path)
    surface = Keyword.get(opts, :signing_surface, signing_surface())

    Catalog.ingest(baseline: baseline, signing_surface: surface)
  end

  defp sha256_hex(bytes), do: Base.encode16(:crypto.hash(:sha256, bytes), case: :lower)

  defp receipt_rows do
    CertifiedReceipt |> Ash.read!() |> Enum.sort_by(& &1.subject)
  end

  # (a) full baseline-JSON ingest creates the exact expected row set, and a
  # second identical ingest is idempotent: same payload hash, no duplicate
  # rows (the real contract is idempotent reuse, not duplicate refusal --
  # `existing_receipt/1` re-admits a matching (subject, payload_hash) row).
  test "baseline ingest creates the exact expected rows; re-ingest is idempotent" do
    assert {:ok, first} = ingest()

    expected_hash = sha256_hex(File.read!(@baseline_path))
    assert first.payload_hash_hex == expected_hash

    rows = receipt_rows()
    assert length(rows) == 2
    assert Enum.map(rows, & &1.algorithm) == [:es256, :ml_dsa65]
    # receipt payload hashes are SHA-256 of each KAT vector's message_hex
    kat = signing_surface()

    expected_payload_hashes =
      [Enum.at(kat, 0), Enum.at(kat, 2)] |> Enum.map(&sha256_hex(&1["message_hex"])) |> Enum.sort()

    assert Enum.map(rows, & &1.payload_hash_hex) == expected_payload_hashes
    assert Enum.all?(rows, &String.starts_with?(&1.subject, first.subject <> ":"))

    assert {:ok, second} = ingest()

    assert second.payload_hash_hex == first.payload_hash_hex
    assert receipt_rows() == rows
  end

  # (b) tampered baseline bytes: the real contract records distinguishable
  # hashes, it does not refuse. `baseline_payload_hash/1` hashes the raw
  # file bytes when a path is given, so a single flipped byte yields a
  # different `payload_hash_hex` on the ingest result (the receipt rows
  # themselves hash the KAT vector message, not the baseline bytes).
  test "tampered baseline bytes produce a distinguishable payload hash" do
    {:ok, %{payload_hash_hex: clean_hash}} = ingest()

    tampered =
      @baseline_path
      |> File.read!()
      |> String.replace("4f654d21", "4f654d22", global: false)

    assert tampered != File.read!(@baseline_path)

    path =
      Path.join(System.tmp_dir!(), "w709-baseline-#{System.unique_integer([:positive])}.json")

    File.write!(path, tampered)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, %{payload_hash_hex: tampered_hash}} = ingest(baseline: path)
    # subject_commit is unchanged, only the byte-level hash moved
    assert tampered_hash != clean_hash
    assert byte_size(tampered_hash) == 64
  end

  # (c) verification key rotation: two distinct key materials under the same
  # algorithm register two distinct kids; each receipt carries the
  # verifying key actually used, and verifying one receipt's standing does
  # not move the other's.
  test "key rotation: standing follows the key actually used" do
    kat = signing_surface()
    # admitted vectors sit at corpus indices 0 (ES256) and 2 (ML-DSA-65);
    # indices 1 and 3 are outside the admitted enum
    es256_vector = Enum.at(kat, 0)
    ml_dsa_vector = Enum.at(kat, 2)

    # kid v1: the fixture ES256 key material; kid v2: same algorithm, new material
    rotated_vector = Map.put(es256_vector, "public_key_hex", String.duplicate("ab", 32))

    assert {:ok, %{receipts: [v1_receipt, _ | _] = receipts}} =
             ingest(signing_surface: [es256_vector, ml_dsa_vector, rotated_vector])

    kids = VerificationKey |> Ash.read!() |> Enum.map(& &1.kid) |> Enum.sort()
    assert length(kids) == 3

    assert {:ok, verified_v1} = Catalog.record_verification(v1_receipt, true)
    assert verified_v1.verified

    # the rotated-key receipt is untouched by v1's verification
    rotated_receipt = Enum.find(receipts, &(&1.verifying_key_hex == String.duplicate("ab", 32)))
    assert %CertifiedReceipt{} = rotated_receipt
    refute Ash.get!(CertifiedReceipt, rotated_receipt.id).verified

    assert {:ok, verified_v2} = Catalog.record_verification(rotated_receipt, true)

    # each receipt's standing is bound to the key material it was ingested with
    assert verified_v1.verifying_key_hex == es256_vector["public_key_hex"]
    assert verified_v2.verifying_key_hex == String.duplicate("ab", 32)
    assert verified_v1.verifying_key_hex != verified_v2.verifying_key_hex

    reloaded = receipt_rows()
    assert Enum.count(reloaded, & &1.verified) == 2
  end

  # (d) unknown algorithm at ingest: the real contract is a typed skip in
  # `:skipped` (`:algorithm_not_in_admitted_enum`), never a silent drop and
  # never a row.
  test "unknown algorithm is typed-skipped, no row created" do
    unknown = %{
      "algorithm" => "DILITHIUM2",
      "message_hex" => "deadbeef",
      "signature_hex" => "cafe",
      "public_key_hex" => "beef"
    }

    assert {:ok, result} = ingest(signing_surface: [unknown])

    assert result.skipped == [{0, "DILITHIUM2", :algorithm_not_in_admitted_enum}]
    assert result.receipts == []
    assert receipt_rows() == []
    assert Ash.read!(VerificationKey) == []
  end
end
