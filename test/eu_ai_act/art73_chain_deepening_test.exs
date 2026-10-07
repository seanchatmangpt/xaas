defmodule Xaas.EUAIAct.Art73ChainDeepeningTest do
  @moduledoc """
  Lane W669 — Art. 73 serious-incident reporting chain deepening.

  Full chain over real modules, no mocks, seeded deterministic:

      receipts (typed refusal evidence, all three Art 73(1) trigger classes)
        -> IncidentReport.build (derived classification, per category)
        -> AuthorityChannel PREPARED_NOT_TRANSMITTED lifecycle (authority
           channel, operator endpoint binding, RECORDED contrast on the
           EVIDENCED internal channel)
        -> full witness chain: incident -> channel prep -> classification
           -> AuditChain (Jcs/SHA-256) hash stability + tamper latch

  Also asserts the typed refusals on malformed report inputs at every
  boundary (IncidentReport.build, AuthorityChannel.transmit).
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.AuthorityChannel
  alias Xaas.Semantics.IncidentReport
  alias Xaas.Witness.AuditChain

  @moduletag :eu_ai_act

  @epoch ~U[2026-10-07 00:00:00Z]
  @epoch_later ~U[2026-10-07 01:30:00Z]

  ## ------------------------------------------------------------------
  ## Seeded deterministic receipt fixtures (one per Art 73(1) class)
  ## ------------------------------------------------------------------

  # Art 73(1) "infringement of Union law": typed EUAIA refusal atom.
  defp infringement_receipt do
    %{
      digest: "sha256:" <> Base.encode16(:crypto.hash(:sha256, "w669-infringe"), padding: false),
      refusal_atom: :REFUSED_EUAIA_MANIPULATIVE,
      status: :refused,
      rights_harm: false,
      observed_at: @epoch
    }
  end

  # Art 73(1) "harm to fundamental rights": rights-harm evidence.
  defp rights_harm_receipt do
    %{
      digest: "sha256:" <> Base.encode16(:crypto.hash(:sha256, "w669-rights"), padding: false),
      refusal_atom: "REFUSED_OTHER_RIGHTS_HARM",
      status: :refused,
      rights_harm: true,
      observed_at: @epoch_later
    }
  end

  # Art 73(1) "malfunction / unauthorized actuation": non-EUAIA refusal on
  # an actuation receipt with error status.
  defp malfunction_receipt do
    %{
      digest: "sha256:" <> Base.encode16(:crypto.hash(:sha256, "w669-malfunction"), padding: false),
      refusal_atom: :REFUSED_PROVIDER_UNAVAILABLE,
      status: :error,
      rights_harm: false,
      observed_at: @epoch
    }
  end

  defp payload_digest(term) do
    Base.encode16(
      :crypto.hash(:sha256, :erlang.term_to_iovec(term)),
      padding: false,
      case: :lower
    )
  end

  defp hex64?(s) when is_binary(s), do: Regex.match?(~r/^[0-9a-f]{64}$/, s)
  defp hex64?(_), do: false

  ## ------------------------------------------------------------------
  ## Per-category classification derivation
  ## ------------------------------------------------------------------

  test "each Art 73(1) trigger class derives its classification atom" do
    # infringement of Union law — the admission-layer EUAIA refusal is the
    # admission surface working as designed, so it classifies ONLY as
    # :INFRINGES_UNION_LAW and never as :MALFUNCTION
    # (incident_report.ex @euaia_refusal_strings / maybe_add_malfunction/3)
    assert {:ok, r1} = IncidentReport.build([infringement_receipt()])
    assert r1.classification == [:INFRINGES_UNION_LAW]
    assert :MALFUNCTION not in r1.classification

    # harm to fundamental rights
    assert {:ok, r2} = IncidentReport.build([rights_harm_receipt()])
    assert :HARM_TO_RIGHTS in r2.classification
    assert :MALFUNCTION in r2.classification

    # malfunction / unauthorized actuation — status-only evidence suffices
    bare_error = %{digest: "d-w669", status: :refused}
    assert {:ok, r3} = IncidentReport.build([bare_error])
    assert r3.classification == [:MALFUNCTION]

    # refusal atom that is neither EUAIA nor rights-shaped, no status:
    # malfunction via the non-EUAIA refusal branch
    assert {:ok, r4} =
             IncidentReport.build([%{digest: "d-w669b", refusal_atom: :REFUSED_PLAIN}])

    assert r4.classification == [:MALFUNCTION]
  end

  test "multi-trigger receipt set: classification is sorted, unique union over all receipts" do
    receipts = [malfunction_receipt(), rights_harm_receipt(), infringement_receipt()]

    assert {:ok, report} = IncidentReport.build(receipts)

    assert report.classification ==
             [:HARM_TO_RIGHTS, :INFRINGES_UNION_LAW, :MALFUNCTION]

    assert report.classification == Enum.uniq(Enum.sort(report.classification))

    assert report.temporal.first_observed == @epoch
    assert report.temporal.last_observed == @epoch_later

    expected_digests = Enum.map(receipts, & &1.digest)
    assert report.originating_receipt_digests == expected_digests
    assert String.starts_with?(report.incident_id, "INC-")
  end

  test "determinism: same evidence set -> identical report for identical order" do
    receipts = [infringement_receipt(), rights_harm_receipt()]
    assert {:ok, a} = IncidentReport.build(receipts)
    assert {:ok, b} = IncidentReport.build(receipts)
    assert a == b

    # Real module behavior (incident_report.ex:80-82): incident_id hashes the
    # digest LIST in order, so a reordered evidence set derives a different
    # id while classification and digests follow the new order — derived,
    # order-following, deterministic.
    assert {:ok, c} = IncidentReport.build(Enum.reverse(receipts))
    assert c.incident_id != a.incident_id
    assert c.classification == a.classification
    assert c.originating_receipt_digests == Enum.reverse(a.originating_receipt_digests)
  end

  ## ------------------------------------------------------------------
  ## Typed refusals on malformed reports
  ## ------------------------------------------------------------------

  test "IncidentReport.build refuses empty and nil evidence with typed atom" do
    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} = IncidentReport.build([])
    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} = IncidentReport.build(nil)
  end

  test "AuthorityChannel.transmit refuses malformed report inputs, typed" do
    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit([], :art73_market_surveillance)

    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit(%{originating_receipt_digests: []},
               :art73_market_surveillance
             )

    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit(%{no_evidence: true}, :art73_market_surveillance)

    # a failed report tuple carries no evidence either (authority_channel.ex:188
    # normalize_report only accepts maps) — same typed refusal
    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit({:error, :REFUSED_EUAIA_MANIPULATIVE},
               :art73_market_surveillance
             )
  end

  ## ------------------------------------------------------------------
  ## AuthorityChannel PREPARED_NOT_TRANSMITTED lifecycle
  ## ------------------------------------------------------------------

  test "authority channel lifecycle: OPEN registry -> endpoint binding -> prepared transmit" do
    # registry carries the authority channels as typed OPEN
    reg = AuthorityChannel.registry()

    for id <- [:art73_market_surveillance, :corpus_3_49_transparency_family, :art27_1f_fria_notification] do
      channel = Enum.find(reg, &(&1.id == id))
      refute is_nil(channel)
      assert channel.kind == :authority
      assert channel.status == :OPEN
      assert channel.endpoint == :OPEN
    end

    assert {:ok, report} = IncidentReport.build([infringement_receipt()])

    # honest channel: PREPARED, never "sent"
    assert {:ok, prepared} =
             AuthorityChannel.transmit({:ok, report}, :art73_market_surveillance)

    assert prepared.status == :PREPARED_NOT_TRANSMITTED
    assert prepared.channel_id == :art73_market_surveillance
    assert prepared.incident_id == report.incident_id
    assert prepared.classification == report.classification
    assert is_binary(prepared.reason)
    assert is_nil(prepared.where)

    # operator seam: endpoint bound as data, channel stays OPEN, transmit
    # still prepares (never opens a socket) and carries the endpoint
    endpoint = %{endpoint: "https://msa.example.invalid/report", transport: :https}

    assert {:ok, reg2} =
             AuthorityChannel.with_endpoint(:art73_market_surveillance, endpoint)

    bound = Enum.find(reg2, &(&1.id == :art73_market_surveillance))
    assert bound.endpoint == endpoint
    assert bound.status == :OPEN

    assert {:ok, prepared2} =
             AuthorityChannel.transmit({:ok, report}, :art73_market_surveillance, [
               %{id: :art73_market_surveillance, kind: :authority, endpoint: endpoint}
             ])

    assert prepared2.status == :PREPARED_NOT_TRANSMITTED
    assert prepared2.endpoint == endpoint

    # unknown channel in the operator seam
    assert {:error, :REFUSED_UNKNOWN_CHANNEL} =
             AuthorityChannel.with_endpoint(:not_a_channel, endpoint)
  end

  test "EVIDENCED internal channel contrasts: RECORDED with cited paths" do
    assert {:ok, report} = IncidentReport.build([rights_harm_receipt()])

    assert {:ok, recorded} =
             AuthorityChannel.transmit(report, :internal_escalation_receipt_corpus)

    assert recorded.status == :RECORDED
    assert recorded.incident_id == report.incident_id
    assert recorded.classification == report.classification
    assert is_list(recorded.where) and recorded.where != []

    Enum.each(recorded.where, fn path -> assert File.exists?(Path.expand(path)) end)
  end

  ## ------------------------------------------------------------------
  ## Full witness chain: incident -> channel -> audit-hash stability
  ## ------------------------------------------------------------------

  test "end-to-end: classification survives channel prep and the audit hash is stable" do
    receipts = [infringement_receipt(), malfunction_receipt()]
    assert {:ok, report} = IncidentReport.build(receipts)

    # channel prep preserves the derived classification
    assert {:ok, prepared} =
             AuthorityChannel.transmit({:ok, report}, :corpus_3_49_transparency_family)

    assert prepared.classification == report.classification
    assert prepared.status == :PREPARED_NOT_TRANSMITTED

    # record the prepared event on the tamper-evident chain
    event = {prepared.incident_id, prepared.channel_id, prepared.classification}

    assert {:ok, chain, head} =
             AuditChain.append([], %{
               actuation_id: prepared.incident_id,
               payload_digest: payload_digest(event),
               sig_slot: {:w669, :art73_chain}
             })

    assert [%{t: 0, prev_hash: prev}] = chain
    assert prev == AuditChain.root_hash()
    assert hex64?(head)

    # link equation: H_0 = SHA256(JCS(R_0) <> root)
    assert head == AuditChain.hash_receipt(hd(chain), AuditChain.root_hash())
    assert :ok = AuditChain.verify_chain(chain, expected_length: 1, expected_head: head)

    # hash stability: appending the identical receipt again yields the
    # identical head — same evidence, same chain, no drift
    assert {:ok, chain_again, head_again} =
             AuditChain.append([], %{
               actuation_id: prepared.incident_id,
               payload_digest: payload_digest(event),
               sig_slot: {:w669, :art73_chain}
             })

    assert chain_again == chain
    assert head_again == head

    # second link extends; the two-link chain verifies clean
    assert {:ok, chain2, head2} =
             AuditChain.append(chain, %{
               actuation_id: {:w669, :transmission_prepared},
               payload_digest: payload_digest({head, prepared.incident_id})
             })

    assert Enum.at(chain2, 1).prev_hash == head
    assert :ok = AuditChain.verify_chain(chain2, expected_length: 2, expected_head: head2)
    assert AuditChain.martingale(chain2) == [1, 1]

    # tamper latch: content flip at link 0 attributes exactly and drops M
    tampered = put_in(hd(chain2).payload_digest, String.duplicate("aa", 64))
    tampered_chain = [tampered, Enum.at(chain2, 1)]

    assert {:error, {:tampered, 0}} =
             AuditChain.verify_chain(tampered_chain,
               expected_length: 2,
               expected_head: head2
             )

    assert AuditChain.martingale(tampered_chain) == [0, 0]
  end
end
