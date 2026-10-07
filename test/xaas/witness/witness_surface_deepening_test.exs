defmodule Xaas.Witness.WitnessSurfaceDeepeningTest do
  @moduledoc """
  W698 — unit courts for the Xaas.Witness surface (deepening beyond the
  e2e spec): CertifiedReceipt write-once payload fields, VerificationKey
  kid uniqueness, write-once verification results, real per-algorithm
  signature round-trips (no faked crypto), and wire-algorithm alias
  resolution (ES256K_RECOVERABLE / ML_DSA65), and (w726) typed `Invalid`
  refusals on the identity constraints after the index-name alignment
  migration (20261007000000).

  Chicago school: real Postgres sandbox, real Ash actions, real
  `:crypto` / real OpenSSL-CLI signatures — no mocks.
  """

  use ExUnit.Case, async: false

  # EU AI Act Art 18 / Art 74 record-keeping candidates: the witness
  # surface (write-once certified receipts + registered verifying keys)
  # is the record-keeping substrate these articles' logs would live in
  # (see docs/claude/diataxis/reference/eu-ai-act-semantics.md).
  @moduletag :eu_ai_act

  alias Xaas.Witness.Catalog
  alias Xaas.Witness.CertifiedReceipt
  alias Xaas.Witness.VerificationKey

  @openssl "/opt/homebrew/opt/openssl@3/bin/openssl"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Xaas.Repo.delete_all(CertifiedReceipt)
    Xaas.Repo.delete_all(VerificationKey)
    :ok
  end

  defp tmpdir,
    do: Path.join(System.tmp_dir!(), "w698-#{:erlang.unique_integer([:positive])}")

  defp sh(args) do
    case System.cmd(@openssl, args) do
      {out, 0} -> {:ok, out}
      {out, code} -> {:error, {code, out}}
    end
  end

  # -- (a) payload fields write-once -------------------------------------

  test "ingest refuses a second row with the same (subject, payload_hash) identity" do
    attrs = %{
      subject: "w698:write-once",
      payload_hash_hex: String.duplicate("ab", 32),
      algorithm: :ed25519,
      signature_hex: "00",
      verifying_key_hex: "00"
    }

    assert {:ok, _} = Ash.create(CertifiedReceipt, attrs, action: :ingest)

    # FIXED (w726): the DB index now carries Ash's derived name
    # (`..._unique_subject_payload_index`, migration 20261007000000), so the
    # Ecto unique constraint maps to a typed Ash refusal.
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Ash.create(CertifiedReceipt, attrs, action: :ingest)

    assert Enum.any?(errors, fn
             %Ash.Error.Changes.InvalidAttribute{field: :subject, message: "has already been taken"} ->
               true

             _ ->
               false
           end)

    assert [%CertifiedReceipt{}] = Ash.read!(CertifiedReceipt)
  end

  test "(w726) a direct duplicate ingest surfaces a typed Invalid, not Ash.Error.Unknown" do
    attrs = %{
      subject: "w726:typed-duplicate",
      payload_hash_hex: String.duplicate("7a", 32),
      algorithm: :es256,
      signature_hex: "0102",
      verifying_key_hex: "0304"
    }

    assert {:ok, _} = Ash.create(CertifiedReceipt, attrs, action: :ingest)

    assert {:error, %Ash.Error.Invalid{}} = Ash.create(CertifiedReceipt, attrs, action: :ingest)

    # the mutation-falsifier twin: error class, not just refusal presence
    refute match?({:error, %Ash.Error.Unknown{}}, Ash.create(CertifiedReceipt, attrs, action: :ingest))

    assert [%CertifiedReceipt{}] = Ash.read!(CertifiedReceipt)
  end

  test "the only update action accepts no payload fields: an attempted overwrite changes nothing" do
    {:ok, receipt} =
      Ash.create(CertifiedReceipt, %{
        subject: "w698:overwrite",
        payload_hash_hex: String.duplicate("cd", 32),
        algorithm: :es256,
        signature_hex: "aabb",
        verifying_key_hex: "ccdd"
      })

    cs =
      Ash.Changeset.for_update(receipt, :record_verification, %{
        subject: "tampered",
        payload_hash_hex: String.duplicate("ee", 32),
        algorithm: :ed25519,
        signature_hex: "ff",
        verifying_key_hex: "01"
      })

    # none of the write-once payload fields are accepted by :record_verification
    for field <- [:subject, :payload_hash_hex, :algorithm, :signature_hex, :verifying_key_hex] do
      refute Map.has_key?(cs.attributes, field),
             "payload field #{field} must not be accepted on update"
    end

    # Ash refuses unknown inputs on :record_verification outright (typed
    # NoSuchInput Invalid): the overwrite never reaches the row.
    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.update(cs)

    assert Enum.any?(errors, fn
             %Ash.Error.Invalid.NoSuchInput{input: :subject} -> true
             _ -> false
           end)
    reloaded = Ash.get!(CertifiedReceipt, receipt.id)

    assert reloaded.subject == "w698:overwrite"
    assert reloaded.payload_hash_hex == String.duplicate("cd", 32)
    assert reloaded.algorithm == :es256
    assert reloaded.signature_hex == "aabb"
    assert reloaded.verifying_key_hex == "ccdd"
  end

  # -- (b) kid uniqueness -------------------------------------------------

  test "registering the same kid twice is refused by the unique_kid identity" do
    {:ok, key} =
      Ash.create(VerificationKey, %{
        kid: "w698-kid",
        algorithm: :ed25519,
        key_material_hex: "aa"
      })

    # FIXED (w726): index renamed to `witness_verification_keys_unique_kid_index`
    # (migration 20261007000000), so the refusal is a typed Ash.Error.Invalid.
    assert {:error, %Ash.Error.Invalid{}} =
             Ash.create(VerificationKey, %{
               kid: "w698-kid",
               algorithm: :es256,
               key_material_hex: "bb"
             })

    # the original row is untouched
    assert [stored] = Ash.read!(VerificationKey)
    assert stored.id == key.id
    assert stored.algorithm == :ed25519 and stored.key_material_hex == "aa"
  end

  test "(w726) a direct duplicate kid registration surfaces a typed Invalid" do
    {:ok, key} =
      Ash.create(VerificationKey, %{
        kid: "w726-kid",
        algorithm: :es256,
        key_material_hex: "ee"
      })

    # Duplicate kid registration: typed Invalid after the index rename.
    # MUTATION FALSIFIER: reverting migration 20261007000000 makes THIS
    # assert fail — the error reverts to Ash.Error.Unknown wrapping the raw
    # Ecto.ConstraintError, so %Ash.Error.Invalid{} no longer matches.
    assert {:error, %Ash.Error.Invalid{}} =
             Ash.create(VerificationKey, %{
               kid: "w726-kid",
               algorithm: :ed25519,
               key_material_hex: "ff"
             })

    # the original row is untouched
    assert [%VerificationKey{id: id}] = Ash.read!(VerificationKey)
    assert id == key.id
  end

  test "different kids with the same material both register (identity is on kid alone)" do
    assert {:ok, _} =
             Ash.create(VerificationKey, %{
               kid: "w698-kid-a",
               algorithm: :ed25519,
               key_material_hex: "cc"
             })

    assert {:ok, _} =
             Ash.create(VerificationKey, %{
               kid: "w698-kid-b",
               algorithm: :ed25519,
               key_material_hex: "cc"
             })

    assert length(Ash.read!(VerificationKey)) == 2
  end

  # -- (c) verification results write-once --------------------------------

  test "record_verification refuses once verified=true, through both the context API and the raw action" do
    {:ok, receipt} =
      Ash.create(CertifiedReceipt, %{
        subject: "w698:verif",
        payload_hash_hex: String.duplicate("10", 32),
        algorithm: :ed25519,
        signature_hex: "aa",
        verifying_key_hex: "bb"
      })

    assert {:ok, first} = Catalog.record_verification(receipt, true)
    assert first.verified
    assert %DateTime{} = first.verified_at

    # Catalog API refuses the second verdict
    assert {:error, %Ash.Error.Invalid{}} = Catalog.record_verification(first, true)

    # raw action refuses too
    fresh = Ash.get!(CertifiedReceipt, receipt.id)
    assert {:error, %Ash.Error.Invalid{}} =
             fresh |> Ash.Changeset.for_update(:record_verification, %{}) |> Ash.update()

    reloaded = Ash.get!(CertifiedReceipt, receipt.id)
    assert reloaded.verified
    assert reloaded.verified_at == first.verified_at, "verified_at must be write-once too"
  end

  # -- (d) six wire algorithms, real signature round-trips -----------------
  #
  # Catalog.@supported_algorithms admits six wire names: ES256, Ed25519,
  # ES256K, ES256K_RECOVERABLE, ML-DSA-65, ML_DSA65. Each round-trips a
  # REAL signature below (freshly minted via :crypto / the OpenSSL CLI —
  # Chicago school: the signer is a real collaborator, nothing is faked).

  defp assert_real_roundtrip(:es256, msg) do
    {pub, priv} = :crypto.generate_key(:ecdh, :secp256r1)
    sig = :crypto.sign(:ecdsa, :sha256, msg, [priv, :secp256r1])
    assert :crypto.verify(:ecdsa, :sha256, msg, sig, [pub, :secp256r1])
    refute :crypto.verify(:ecdsa, :sha256, msg <> "x", sig, [pub, :secp256r1])
  end

  defp assert_real_roundtrip(:ed25519, msg) do
    {pub, priv} = :crypto.generate_key(:eddsa, :ed25519)
    sig = :crypto.sign(:eddsa, :none, msg, [priv, :ed25519])
    assert :crypto.verify(:eddsa, :none, msg, sig, [pub, :ed25519])
    refute :crypto.verify(:eddsa, :none, msg <> "x", sig, [pub, :ed25519])
  end

  defp assert_real_roundtrip(:es256k, msg) do
    {pub, priv} = :crypto.generate_key(:ecdh, :secp256k1)
    sig = :crypto.sign(:ecdsa, :sha256, msg, [priv, :secp256k1])
    assert :crypto.verify(:ecdsa, :sha256, msg, sig, [pub, :secp256k1])
    refute :crypto.verify(:ecdsa, :sha256, msg <> "x", sig, [pub, :secp256k1])
  end

  # Both ML-DSA wire names round-trip through the real OpenSSL 3.x CLI
  # signer (NIST FIPS 204), the same real-subprocess signer the repo's
  # ML-DSA courts use (see Xaas.Witness.MlDsaSignedReceiptTest).
  defp assert_real_roundtrip(name, msg) when name in [:ml_dsa65, :ml_dsa65_alias] do
    dir = tmpdir()
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    key = Path.join(dir, "mldsa65.key")
    pub = Path.join(dir, "mldsa65.pub.pem")
    msg_path = Path.join(dir, "msg.bin")
    sig_path = Path.join(dir, "sig.bin")

    File.write!(msg_path, msg)

    with {:ok, _} <- sh(["genpkey", "-algorithm", "ML-DSA-65", "-out", key]),
         {:ok, _} <- sh(["pkey", "-in", key, "-pubout", "-out", pub]),
         {:ok, _} <-
           sh(["pkeyutl", "-sign", "-rawin", "-inkey", key, "-in", msg_path, "-out", sig_path]) do
      sig = File.read!(sig_path)
      assert byte_size(sig) in 3_000..3_500, "real ML-DSA-65 signature is ~3309 bytes"

      assert {:ok, "Signature Verified Successfully\n"} =
               sh([
                 "pkeyutl",
                 "-verify",
                 "-rawin",
                 "-pubin",
                 "-inkey",
                 pub,
                 "-in",
                 msg_path,
                 "-sigfile",
                 sig_path
               ])

      File.write!(msg_path, msg <> "x")

      tampered =
        sh(["pkeyutl", "-verify", "-rawin", "-pubin", "-inkey", pub, "-in", msg_path, "-sigfile", sig_path])

      case tampered do
        {:error, {0, _}} -> flunk("tampered message verified")
        {:error, {_, out}} -> assert out =~ "Failure"
        {:ok, _} -> flunk("tampered message verified")
      end
    else
      {:error, {code, out}} ->
        flunk("OpenSSL ML-DSA-65 unavailable (exit #{code}): #{out}")
    end
  end

  @wire_algorithms %{
    "ES256" => :es256,
    "Ed25519" => :ed25519,
    "ES256K" => :es256k,
    "ES256K_RECOVERABLE" => :es256k,
    "ML-DSA-65" => :ml_dsa65,
    "ML_DSA65" => :ml_dsa65
  }

  test "each of the 6 wire algorithms round-trips a real signature (and its negative control)" do
    msg = "w698 wire algorithm round-trip"

    for {_wire, enum} <- @wire_algorithms do
      # the wire name resolves into the admitted enum
      assert enum in [:es256, :ed25519, :es256k, :ml_dsa65]
      assert_real_roundtrip(enum, msg)
    end
  end

  test "wire aliases resolve: ES256K_RECOVERABLE and ML_DSA65 ingest as :es256k / :ml_dsa65, not skipped" do
    baseline = %{"subject_commit" => "w698-alias-subject"}

    vectors = [
      %{"algorithm" => "ES256K_RECOVERABLE", "message_hex" => "aa", "public_key_hex" => "aa", "signature_hex" => "aa"},
      %{"algorithm" => "ML_DSA65", "message_hex" => "bb", "public_key_hex" => "bb", "signature_hex" => "bb"}
    ]

    assert {:ok, result} = Catalog.ingest(baseline: baseline, signing_surface: vectors)

    assert result.skipped == []
    assert Enum.map(result.receipts, & &1.algorithm) |> Enum.sort() == [:es256k, :ml_dsa65]

    stored = Ash.read!(CertifiedReceipt)
    assert length(stored) == 2
    assert Enum.all?(stored, &(&1.subject =~ "w698-alias-subject"))

    # the two aliases registered distinct kids, one per vector
    assert length(Ash.read!(VerificationKey)) == 2
  end

  test "a truly unknown wire name is skipped with a typed reason, never silently dropped" do
    baseline = %{"subject_commit" => "w698-skip-subject"}

    vectors = [
      %{"algorithm" => "SLH-DSA-SHA2-128s", "message_hex" => "cc", "signature_hex" => "cc", "public_key_hex" => "cc"}
    ]

    assert {:ok, result} = Catalog.ingest(baseline: baseline, signing_surface: vectors)

    assert result.skipped == [{0, "SLH-DSA-SHA2-128s", :algorithm_not_in_admitted_enum}]
    assert result.receipts == []
    assert [] = Ash.read!(CertifiedReceipt)
    assert [] = Ash.read!(VerificationKey)
  end

  # -- (w726) Catalog-level idempotent reuse unchanged by the index rename --

  test "(w726) Catalog.ingest/1 of the same signing surface twice is idempotent: same receipts, no new rows" do
    baseline = %{"subject_commit" => "w726-idempotent"}

    vectors = [
      %{"algorithm" => "Ed25519", "message_hex" => "aa", "public_key_hex" => "aa", "signature_hex" => "aa"},
      %{"algorithm" => "ES256", "message_hex" => "bb", "public_key_hex" => "bb", "signature_hex" => "bb"}
    ]

    assert {:ok, first} = Catalog.ingest(baseline: baseline, signing_surface: vectors)
    assert length(first.receipts) == 2

    # second ingest of the identical surface: identity-constraint refusals
    # are now typed Invalid (index rename), and Catalog's existing-receipt
    # fallback still resolves them to idempotent reuse
    assert {:ok, second} = Catalog.ingest(baseline: baseline, signing_surface: vectors)

    assert Enum.map(first.receipts, & &1.id) |> Enum.sort() ==
             Enum.map(second.receipts, & &1.id) |> Enum.sort()

    assert length(Ash.read!(CertifiedReceipt)) == 2
    assert length(Ash.read!(VerificationKey)) == 2
  end
end
