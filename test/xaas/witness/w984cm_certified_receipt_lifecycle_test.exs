defmodule Xaas.Witness.W984cmCertifiedReceiptLifecycleTest do
  @moduledoc """
  W984cm — depth court on the witness-family remainder NOT covered by the
  existing slice (catalog_test, catalog_durability_test,
  witness_surface_deepening_test, ml_dsa_signed_receipt_test, audit_chain
  courts) nor by W984bn's audit_chain batch:

    * subject-collision semantics: the `unique_subject_payload` identity
      is composite, so a same-subject/different-payload re-ingest is
      ADMITTED as a second row (a distinct (subject, payload_hash) pair)
      while a full-pair re-ingest stays idempotent;
    * verdict polarity: `Catalog.record_verification/2,3` records an
      AFFIRMATIVE verdict regardless of the boolean passed, and the
      caller-supplied `at` timestamp is never persisted (verified_at is
      action-minted — callers cannot forge the verification instant);
    * the `one_of` algorithm enum typed refusal on BOTH resources
      (no existing court feeds a non-admitted algorithm atom);
    * cross-baseline VerificationKey idempotency (same key material under
      two distinct subject_commits -> exactly one key row, both receipts
      sharing its material).

  Chicago school: real Postgres sandbox, real Ash actions, no mocks.
  """

  use ExUnit.Case, async: false

  @moduletag :w984cm

  alias Xaas.Witness.Catalog
  alias Xaas.Witness.CertifiedReceipt
  alias Xaas.Witness.VerificationKey

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Xaas.Repo.delete_all(CertifiedReceipt)
    Xaas.Repo.delete_all(VerificationKey)
    :ok
  end

  defp vector(algorithm, msg_hex),
    do: %{
      "algorithm" => algorithm,
      "message_hex" => msg_hex,
      "signature_hex" => "aa",
      "public_key_hex" => "bb"
    }

  # -- (1) subject-collision semantics ------------------------------------

  test "re-ingest of the same derived subject with a DIFFERENT payload hash is ADMITTED: identity binds (subject, payload_hash) as a pair, not subject alone" do
    base = %{"subject_commit" => "w984cm-conflict"}

    assert {:ok, first} = Catalog.ingest(baseline: base, signing_surface: [vector("Ed25519", "aa")])
    assert length(first.receipts) == 1

    # same subject_commit + same algorithm + same index => same derived
    # subject, but message_hex differs => payload_hash_hex differs. The
    # unique_subject_payload identity is COMPOSITE, so the create is
    # admitted — the (W698-courted) duplicate refusal fires only when BOTH
    # pair members match, and the idempotent-reuse fallback never triggers.
    assert {:ok, second} = Catalog.ingest(baseline: base, signing_surface: [vector("Ed25519", "bb")])

    # the result lists only THIS ingest's admissions, not prior rows
    assert length(second.receipts) == 1

    rows = Ash.read!(CertifiedReceipt)

    assert length(rows) == 2, "the table now holds both pair-distinct rows"
    assert Enum.all?(rows, &(&1.subject == "w984cm-conflict:ed25519:0"))

    hashes = rows |> Enum.map(& &1.payload_hash_hex) |> Enum.sort()
    assert hashes == Enum.uniq(hashes), "the two rows carry distinct payload hashes"

    # MUTATION FALSIFIER: if the identity were narrowed to subject alone
    # (a one-line constraint regression), the second ingest would be
    # refused and the table would stay at 1 row.
    assert Enum.map(second.receipts, & &1.payload_hash_hex) --
             Enum.map(first.receipts, & &1.payload_hash_hex)
             |> length() == 1

    # and the second pair re-ingests idempotently: no third row
    assert {:ok, third} = Catalog.ingest(baseline: base, signing_surface: [vector("Ed25519", "bb")])

    assert length(third.receipts) == 1
    assert length(Ash.read!(CertifiedReceipt)) == 2
  end

  # -- (2) verdict polarity + timestamp authority --------------------------

  test "record_verification records an AFFIRMATIVE verdict even when passed false, and the caller-supplied timestamp is never persisted" do
    {:ok, receipt} =
      Ash.create(CertifiedReceipt, %{
        subject: "w984cm:polarity",
        payload_hash_hex: String.duplicate("5a", 32),
        algorithm: :es256,
        signature_hex: "aa",
        verifying_key_hex: "bb"
      })

    before = DateTime.utc_now()

    # the action accepts [] and its change ignores the verification_result
    # context entirely: the only outcome it can mint is verified=true
    assert {:ok, recorded} = Catalog.record_verification(receipt, false)
    assert recorded.verified == true
    assert %DateTime{} = recorded.verified_at

    # caller-supplied `at` is ignored: verified_at is action-minted
    assert {:ok, receipt2} =
             Ash.create(CertifiedReceipt, %{
               subject: "w984cm:timestamp",
               payload_hash_hex: String.duplicate("5b", 32),
               algorithm: :es256,
               signature_hex: "aa",
               verifying_key_hex: "bb"
             })

    forged = ~U[2000-01-01 00:00:00.000000Z]

    assert {:ok, recorded2} = Catalog.record_verification(receipt2, true, forged)
    # MUTATION FALSIFIER: if the change ever reads the caller context's
    # verified_at, this assert fails (verified_at would be 2000-01-01).
    assert DateTime.compare(recorded2.verified_at, before) == :gt,
           "verified_at must be minted by the action, not taken from the caller"

    reloaded = Ash.get!(CertifiedReceipt, receipt2.id)
    assert DateTime.compare(reloaded.verified_at, before) == :gt

    # both rows are now write-once-locked against any further verdict
    assert {:error, %Ash.Error.Invalid{}} = Catalog.record_verification(recorded, true)
    assert {:error, %Ash.Error.Invalid{}} = Catalog.record_verification(recorded2, false)
  end

  # -- (3) algorithm enum one_of typed refusals ----------------------------

  test "a non-admitted algorithm atom is a typed Invalid refusal on BOTH CertifiedReceipt.ingest and VerificationKey.register" do
    assert {:error, %Ash.Error.Invalid{errors: errors}} =
             Ash.create(CertifiedReceipt, %{
               subject: "w984cm:bad-alg",
               payload_hash_hex: String.duplicate("7c", 32),
               algorithm: :rsa2048,
               signature_hex: "aa",
               verifying_key_hex: "bb"
             })

    assert Enum.any?(errors, fn
             %Ash.Error.Changes.InvalidAttribute{field: :algorithm} -> true
             _ -> false
           end)

    # and the row was never written
    assert [] = Ash.read!(CertifiedReceipt)

    assert {:error, %Ash.Error.Invalid{errors: key_errors}} =
             Ash.create(VerificationKey, %{
               kid: "w984cm-bad-alg-kid",
               algorithm: :rsa2048,
               key_material_hex: "cc"
             })

    assert Enum.any?(key_errors, fn
             %Ash.Error.Changes.InvalidAttribute{field: :algorithm} -> true
             _ -> false
           end)

    assert [] = Ash.read!(VerificationKey)

    # MUTATION FALSIFIER: if the one_of constraint were dropped from either
    # resource, BOTH create calls would succeed — each assert on the typed
    # refusal AND the empty-table assert fails.
  end

  # -- (4) cross-baseline key idempotency ----------------------------------

  test "the same key material under two distinct subject_commits registers exactly one key and both receipts share its material" do
    assert {:ok, first} =
             Catalog.ingest(
               baseline: %{"subject_commit" => "w984cm-xbase-1"},
               signing_surface: [vector("Ed25519", "aa")]
             )

    assert {:ok, second} =
             Catalog.ingest(
               baseline: %{"subject_commit" => "w984cm-xbase-2"},
               signing_surface: [vector("Ed25519", "aa")]
             )

    # one physical key row despite two independent registrations
    assert [%VerificationKey{} = key] = Ash.read!(VerificationKey)
    assert key.algorithm == :ed25519 and key.key_material_hex == "bb"

    # both receipts exist (distinct subjects) and share the key material
    assert [r1, r2] = Enum.sort_by(Ash.read!(CertifiedReceipt), & &1.subject)
    assert r1.subject == "w984cm-xbase-1:ed25519:0"
    assert r2.subject == "w984cm-xbase-2:ed25519:0"
    assert r1.verifying_key_hex == r2.verifying_key_hex

    # the derived kid is deterministic from (algorithm, material): both
    # ingests resolve to the SAME kid, which is why the row count is 1
    expected_kid = "ed25519-" <> binary_part(Base.encode16(:crypto.hash(:sha256, "ed25519:bb"), case: :lower), 0, 16)
    assert key.kid == expected_kid

    # MUTATION FALSIFIER: if kid/2 were unstable (e.g. salted or
    # timestamp-seeded), the second registration would NOT hit the
    # unique_kid identity, and the key row count would be 2.
    assert first.keys == :registered and second.keys == :registered
  end

  # -- (5) skipped-vector reporting stays exact under mixed surfaces -------

  test "mixed admitted/skipped surfaces report exact typed skip tuples and leave no partial state for the skipped indices" do
    base = %{"subject_commit" => "w984cm-mixed"}

    vectors = [
      vector("ES256", "aa"),
      vector("DILITHIUM3", "bb"),
      vector("ML-DSA-65", "cc"),
      vector("RSA-PSS-SHA256", "dd"),
      vector("Ed25519", "ee")
    ]

    assert {:ok, result} = Catalog.ingest(baseline: base, signing_surface: vectors)

    # skipped indices refer to the ORIGINAL vector positions, typed
    assert result.skipped == [
             {1, "DILITHIUM3", :algorithm_not_in_admitted_enum},
             {3, "RSA-PSS-SHA256", :algorithm_not_in_admitted_enum}
           ]

    # receipts preserve original ordering across the skipped gaps
    assert Enum.map(result.receipts, & &1.algorithm) == [:es256, :ml_dsa65, :ed25519]

    stored = Enum.sort_by(Ash.read!(CertifiedReceipt), & &1.subject)

    assert Enum.map(stored, & &1.subject) == [
             "w984cm-mixed:ed25519:4",
             "w984cm-mixed:es256:0",
             "w984cm-mixed:ml_dsa65:2"
           ]

    # skipped vectors contribute no keys: one key per admitted vector,
    # even though ES256 and ML-DSA-65 materials differ
    assert length(Ash.read!(VerificationKey)) == 3

    # MUTATION FALSIFIER: if skipped/1 indexed after filtering admitted
    # vectors, the first tuple would be {0, "DILITHIUM3", ...} — the exact
    # index assertion above fails.
  end
end
