defmodule Xaas.Witness.MlDsaSignedReceiptTest do
  @moduledoc """
  w405/W510 — a REAL ML-DSA-65-signed receipt witnessed end to end.

  Chain: receipt payload map → JCS canonical bytes (the same `Jcs.encode/1`
  used by `Xaas.Deployment.ReleaseSnapshot.portable_digest/1`, release_snapshot.ex:356)
  → signed by a REAL ML-DSA-65 key via the OpenSSL 3.6 CLI
  (`pkeyutl -sign -rawin`, NIST FIPS 204) → verified against the stored
  verifying key, plus the negative control (a tampered payload MUST fail
  verification).

  The signer is the OpenSSL CLI as a real subprocess (Chicago school: real
  collaborator, no stubs — the pinned ash_affidavit wasm ABI exposes no
  key-consuming sign/verify op for ML_DSA65; `AshAffidavit.Signing.Keys` is
  exercised as the real host-side key gate in test 3).

  The witnessed artifact is then persisted through the existing witness
  surfaces: `Xaas.Witness.CertifiedReceipt` (`:ingest` +
  `:record_verification`) and `Xaas.Witness.AuditChain` with the real
  OpenSSL verification as the receipt's `sig` callback.
  """

  use ExUnit.Case, async: false

  alias Xaas.Witness.AuditChain
  alias Xaas.Witness.CertifiedReceipt

  @openssl "/opt/homebrew/opt/openssl@3/bin/openssl"

  defp sh(args, opts \\ []) do
    case System.cmd(@openssl, args, opts) do
      {out, 0} -> {:ok, out}
      {out, code} -> {:error, {code, out}}
    end
  end

  defp tmpdir do
    Path.join(System.tmp_dir!(), "w510-mldsa-#{:erlang.unique_integer([:positive])}")
  end

  defp mint_keypair(dir) do
    key = Path.join(dir, "mldsa65.key")
    pub_pem = Path.join(dir, "mldsa65.pub.pem")
    pub_der = Path.join(dir, "mldsa65.pub.der")

    File.touch!(key)
    File.touch!(pub_pem)
    File.touch!(pub_der)

    with {:ok, _} <- sh(["genpkey", "-algorithm", "ML-DSA-65", "-out", key]),
         {:ok, _} <- sh(["pkey", "-in", key, "-pubout", "-out", pub_pem]),
         {:ok, _} <- sh(["pkey", "-in", key, "-pubout", "-outform", "DER", "-out", pub_der]) do
      {:ok, %{priv: key, pub_pem: pub_pem, pub_der: pub_der}}
    end
  end

  defp sign(priv_path, msg_path, canonical) do
    File.write!(msg_path, canonical)
    sig_path = Path.join(Path.dirname(msg_path), "sig.bin")

    with {:ok, _} <-
           sh(["pkeyutl", "-sign", "-rawin", "-inkey", priv_path, "-in", msg_path, "-out", sig_path]) do
      {:ok, File.read!(sig_path)}
    end
  end

  # This OpenSSL build's pkeyutl has no -inform: convert DER SPKI -> PEM first.
  defp der_to_pem(dir, name, der_path) do
    pem_path = Path.join(dir, name)

    with {:ok, _} <-
           sh(["pkey", "-pubin", "-inform", "DER", "-in", der_path, "-out", pem_path]) do
      {:ok, pem_path}
    end
  end

  defp write_and_verify(pub_der_path, dir, canonical) do
    msg_path = Path.join(dir, "msg.bin")
    sig_path = Path.join(dir, "sig.bin")
    File.write!(msg_path, canonical)

    with {:ok, pub_pem} <- der_to_pem(dir, "verify.pub.pem", pub_der_path),
         {:ok, _} <-
           sh([
             "pkeyutl",
             "-verify",
             "-rawin",
             "-pubin",
             "-inkey",
             pub_pem,
             "-in",
             msg_path,
             "-sigfile",
             sig_path
           ]) do
      :valid
    else
      {:error, {code, out}} = e ->
        cond do
          code == 0 -> :valid
          out =~ "Signature Verification Failure" -> :invalid
          true -> e
        end
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Xaas.Repo.delete_all(CertifiedReceipt)
    dir = tmpdir()
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  defp receipt_payload(subject) do
    %{
      "receipt_version" => "w510-mldsa65",
      "subject" => subject,
      "algorithm" => "ML-DSA-65",
      "payload_hash_hex" => Base.encode16(:crypto.hash(:sha256, subject), case: :lower),
      "issued_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
    }
  end

  defp subject_for(dir), do: "xaas:witness:w510:#{Path.basename(dir)}"

  @tag :witness
  test "real ML-DSA-65 keypair signs the JCS-canonical receipt payload and verifies" do
    dir = tmpdir()
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    payload = receipt_payload(subject_for(dir))
    canonical = :erlang.iolist_to_binary(Jcs.encode(payload))
    assert is_binary(canonical)

    assert {:ok, keys} = mint_keypair(dir)
    msg_path = Path.join(dir, "msg.bin")

    assert {:ok, sig} = sign(keys.priv, msg_path, canonical)

    # Real FIPS 204 signature: ~3309 bytes for ML-DSA-65.
    assert byte_size(sig) in 3_000..3_500

    File.write!(Path.join(dir, "sig.bin"), sig)
    assert write_and_verify(keys.pub_der, dir, canonical) == :valid
  end

  @tag :witness
  test "a tampered payload fails ML-DSA-65 verification (negative control)" do
    dir = tmpdir()
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    payload = receipt_payload(subject_for(dir))
    canonical = :erlang.iolist_to_binary(Jcs.encode(payload))

    assert {:ok, keys} = mint_keypair(dir)
    msg_path = Path.join(dir, "msg.bin")
    assert {:ok, sig} = sign(keys.priv, msg_path, canonical)
    File.write!(Path.join(dir, "sig.bin"), sig)

    # Tamper: different subject => different JCS bytes => same sig must reject.
    tampered = receipt_payload(subject_for(dir) <> "-tampered")
    tampered_canonical = :erlang.iolist_to_binary(Jcs.encode(tampered))
    refute tampered_canonical == canonical

    assert write_and_verify(keys.pub_der, dir, tampered_canonical) == :invalid
  end

  @tag :witness
  test "the ML_DSA65 key is admitted by the ash_affidavit JWKS gate and an unknown alg refused" do
    dir = tmpdir()
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    assert {:ok, keys} = mint_keypair(dir)
    der = File.read!(keys.pub_der)

    jwks = %{
      "keys" => [
        %{"kid" => "w510-mldsa", "kty" => "AKP", "alg" => "ML_DSA65", "x" => Base.url_encode64(der, padding: false)}
      ]
    }

    assert {:ok, [key]} = AshAffidavit.Signing.Keys.from_jwks(jwks)
    assert key["alg"] == "ML_DSA65"
    assert {:ok, ^key} = AshAffidavit.Signing.Keys.select([key], "w510-mldsa")

    # Closed algorithm set: ML_DSA65 is in it, and the gate refuses outsiders.
    assert "ML_DSA65" in AshAffidavit.Signing.Keys.algorithms()

    outsider = %{"kid" => "bad", "kty" => "OKP", "alg" => "RSA-OAEP"}
    assert {:ok, [bad_key]} = AshAffidavit.Signing.Keys.from_jwks(%{"keys" => [outsider]})
    assert {:error, %AshAffidavit.Refusal{code: :bad_field}} =
             AshAffidavit.Signing.Keys.select([bad_key], "bad")
  end

  @tag :witness
  test "the ML-DSA-65-signed receipt persists through CertifiedReceipt and drives the audit chain" do
    dir = tmpdir()
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    payload = receipt_payload(subject_for(dir))
    canonical = :erlang.iolist_to_binary(Jcs.encode(payload))
    payload_hash = Base.encode16(:crypto.hash(:sha256, canonical), case: :lower)

    assert {:ok, keys} = mint_keypair(dir)
    msg_path = Path.join(dir, "msg.bin")
    assert {:ok, sig} = sign(keys.priv, msg_path, canonical)
    File.write!(Path.join(dir, "sig.bin"), sig)
    pub_der_hex = Base.encode16(File.read!(keys.pub_der), case: :lower)
    sig_hex = Base.encode16(sig, case: :lower)

    subject = subject_for(dir)

    assert {:ok, receipt} =
             Ash.create(CertifiedReceipt, %{
               subject: subject,
               payload_hash_hex: payload_hash,
               algorithm: :ml_dsa65,
               signature_hex: sig_hex,
               verifying_key_hex: pub_der_hex
             })

    # Read back: the write-once fields survived a real persistence round trip.
    assert [stored] = Ash.read!(CertifiedReceipt)
    assert stored.algorithm == :ml_dsa65
    assert stored.signature_hex == sig_hex
    assert stored.verifying_key_hex == pub_der_hex
    refute stored.verified

    # Verify the STORED hex material against the STORED payload hash (not
    # just in-memory values): re-canonicalize from the payload and check.
    sig_path = Path.join(dir, "verify.sig")
    File.write!(sig_path, Base.decode16!(stored.signature_hex, case: :lower))
    pub_der_path = Path.join(dir, "verify.pub.der")
    File.write!(pub_der_path, Base.decode16!(stored.verifying_key_hex, case: :lower))
    assert {:ok, pub_pem} = der_to_pem(dir, "verify.pub.pem", pub_der_path)

    verify_fn = fn %{payload_digest: digest} ->
      stored_msg = Path.join(dir, "chain.msg")
      File.write!(stored_msg, canonical)

      openssl_ok? =
        case sh([
               "pkeyutl",
               "-verify",
               "-rawin",
               "-pubin",
               "-inkey",
               pub_pem,
               "-in",
               stored_msg,
               "-sigfile",
               sig_path
             ]) do
          {:ok, _} -> true
          {:error, _} -> false
        end

      # The chain's link check is shape-only; payload binding lives here:
      # the real ML-DSA-65 verdict AND digest equality with the signed payload.
      openssl_ok? and digest == stored.payload_hash_hex
    end

    # The receipt's sig callback is the REAL OpenSSL verification.
    {:ok, [chain_receipt] = chain, head} =
      AuditChain.append([], %{
        actuation_id: subject,
        payload_digest: payload_hash,
        sig_slot: "w510-mldsa65",
        sig: verify_fn
      })

    assert is_binary(head)

    # The real-signed chain verifies: link hashes + the real ML-DSA-65 sig.
    assert :ok = AuditChain.verify_chain(chain)

    # A receipt whose sig callback rejects: chain refuses with :invalid_signature.
    tamper_fn = fn _r -> false end
    bad_receipt = %AuditChain{
      t: 0,
      actuation_id: subject,
      payload_digest: payload_hash,
      prev_hash: AuditChain.root_hash(),
      sig_slot: "w510",
      sig: tamper_fn
    }

    assert {:error, :invalid_signature} = AuditChain.verify_chain([bad_receipt])

    # A tampered payload digest under the REAL sig callback: the callback
    # rejects (digest != the digest bound to the ML-DSA-65 signature).
    bad_digest = %AuditChain{
      bad_receipt
      | sig: verify_fn,
        payload_digest: String.replace(payload_hash, "0", "1", global: false)
    }

    assert {:error, :invalid_signature} = AuditChain.verify_chain([bad_digest])

    # Verification result is write-once on the resource.
    assert {:ok, _} = Ash.update(stored, %{}, action: :record_verification)
    assert [%{verified: true}] = Ash.read!(CertifiedReceipt)
    assert {:error, _} = Ash.update(hd(Ash.read!(CertifiedReceipt)), %{}, action: :record_verification)
  end
end
