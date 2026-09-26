defmodule Xaas.Ultracode.SubstitutionCourtTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.SubstitutionCourt
  alias Xaas.Ultracode.SubstitutionCourt.{PartPassport, QualificationReceipt, WorkIdentity}

  @d1 "sha256:" <> String.duplicate("1", 64)
  @d2 "sha256:" <> String.duplicate("2", 64)
  @d3 "sha256:" <> String.duplicate("3", 64)
  @d4 "sha256:" <> String.duplicate("4", 64)
  @d5 "sha256:" <> String.duplicate("5", 64)
  @sha_a String.duplicate("a", 40)
  @sha_b String.duplicate("b", 40)
  @sha_c String.duplicate("c", 40)
  @sha_d String.duplicate("d", 40)

  defp work(overrides \\ %{}) do
    struct!(
      WorkIdentity,
      Map.merge(
        %{
          work_order_id: "urn:work:1",
          exact_subject: "seanchatmangpt/xaas@#{@sha_a}",
          origin_authority: "sj:objective-code-work-authority",
          consequence_schema_digest: @d1,
          receipt_schema_digest: @d2,
          execution_manifest_digest: @d3
        },
        overrides
      )
    )
  end

  defp receipt(overrides \\ %{}) do
    struct!(
      QualificationReceipt,
      Map.merge(
        %{
          receipt_digest: @d3,
          verifier_evidence_digest: @d4,
          replay_digest: @d5,
          passed: true
        },
        overrides
      )
    )
  end

  defp passport(kind, id, sha, overrides \\ %{}) do
    struct!(
      PartPassport,
      Map.merge(
        %{
          part_id: id,
          kind: kind,
          exact_subject: "seanchatmangpt/#{id}@#{sha}",
          part_digest: @d3,
          producer_digest: @d4,
          consequence_schema_digest: @d1,
          receipt_schema_digest: @d2,
          authority_ceiling: [:observe, :select, :construct],
          qualification_receipt: receipt()
        },
        overrides
      )
    )
  end

  test "qualified provider replacement preserves semantic work identity" do
    original = passport(:provider, "provider-a", @sha_b)
    replacement = passport(:provider, "provider-b", @sha_c)

    assert {:ok, result} = SubstitutionCourt.qualify(work(), original, replacement)
    assert result.kind == :provider
    assert result.original_part == "provider-a"
    assert result.replacement_part == "provider-b"
    assert result.authority == "NONE"
    assert result.grants_do_authority == false
    assert result.work_identity_digest == SubstitutionCourt.work_identity_digest(work())
    assert result.receipt_digest =~ ~r/^sha256:[0-9a-f]{64}$/
  end

  test "qualified transport replacement is independent of provider replacement" do
    original = passport(:transport, "transport-wss", @sha_b)
    replacement = passport(:transport, "transport-http", @sha_c)

    assert {:ok, result} = SubstitutionCourt.qualify(work(), original, replacement)
    assert result.kind == :transport
    assert result.work_identity_digest == SubstitutionCourt.work_identity_digest(work())
  end

  test "provider and transport topology can change without changing WorkOrder identity" do
    work = work()
    provider_a = passport(:provider, "provider-a", @sha_b)
    provider_b = passport(:provider, "provider-b", @sha_c)
    transport_a = passport(:transport, "transport-a", @sha_b)
    transport_b = passport(:transport, "transport-b", @sha_d)

    semantic = SubstitutionCourt.work_identity_digest(work)

    refute SubstitutionCourt.topology_digest(work, provider_a, transport_a) ==
             SubstitutionCourt.topology_digest(work, provider_b, transport_b)

    assert semantic == SubstitutionCourt.work_identity_digest(work)
  end

  test "changing origin authority changes semantic WorkOrder identity" do
    refute SubstitutionCourt.work_identity_digest(work()) ==
             SubstitutionCourt.work_identity_digest(
               work(%{origin_authority: "sj:different-authority"})
             )
  end

  test "consequence and receipt schema drift refuse" do
    original = passport(:provider, "provider-a", @sha_b)

    assert {:error, :consequence_schema_drift} =
             SubstitutionCourt.qualify(
               work(),
               original,
               passport(:provider, "provider-b", @sha_c, %{
                 consequence_schema_digest: @d5
               })
             )

    assert {:error, :receipt_schema_drift} =
             SubstitutionCourt.qualify(
               work(),
               original,
               passport(:provider, "provider-b", @sha_c, %{
                 receipt_schema_digest: @d5
               })
             )
  end

  test "authority increase and DO laundering refuse" do
    narrowed =
      passport(:provider, "provider-a", @sha_b, %{
        authority_ceiling: [:observe, :select]
      })

    assert {:error, :authority_ceiling_increase} =
             SubstitutionCourt.qualify(
               work(),
               narrowed,
               passport(:provider, "provider-b", @sha_c)
             )

    assert {:error, :do_authority_laundering} =
             SubstitutionCourt.qualify(
               work(),
               passport(:provider, "provider-a", @sha_b),
               passport(:provider, "provider-b", @sha_c, %{
                 authority_ceiling: [:observe, :do]
               })
             )
  end

  test "failed or missing qualification receipt refuses before substitution" do
    original = passport(:provider, "provider-a", @sha_b)

    assert {:error, :qualification_not_pass} =
             SubstitutionCourt.qualify(
               work(),
               original,
               passport(:provider, "provider-b", @sha_c, %{
                 qualification_receipt: receipt(%{passed: false})
               })
             )

    assert {:error, :qualification_receipt_missing} =
             SubstitutionCourt.qualify(
               work(),
               original,
               passport(:provider, "provider-b", @sha_c, %{
                 qualification_receipt: nil
               })
             )
  end

  test "provider cannot substitute for transport and mutable subjects refuse" do
    assert {:error, :part_kind_mismatch} =
             SubstitutionCourt.qualify(
               work(),
               passport(:provider, "provider-a", @sha_b),
               passport(:transport, "transport-a", @sha_c)
             )

    assert {:error, :part_subject_not_exact} =
             SubstitutionCourt.qualify(
               work(),
               passport(:provider, "provider-a", @sha_b),
               passport(:provider, "provider-b", @sha_c, %{
                 exact_subject: "seanchatmangpt/provider-b@main"
               })
             )
  end
end
