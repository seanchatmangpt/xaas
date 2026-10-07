defmodule Xaas.Semantics.AuthorityChannelIncidentWitnessTest do
  @moduledoc """
  Lane W635 — 73.6.s2 internal-escalation end-to-end witness (Chicago).

  Full chain, real collaborators, no mocks:

      EuAiActAdmission.admit (real refusal)
        -> refused-receipt record
        -> IncidentReport.build (classification derivation)
        -> AuthorityChannel.transmit on the internal_escalation channel (RECORDED)
        -> AuditChain.append of the escalation event
        -> verify_chain :ok + martingale monotonicity (tamper kills M)
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.AuthorityChannel
  alias Xaas.Semantics.EuAiActAdmission
  alias Xaas.Semantics.IncidentReport
  alias Xaas.Witness.AuditChain

  @channel :internal_escalation_receipt_corpus

  # A genuinely violating Art. 5(1)(a) candidate — the admission surface
  # must refuse it with the exact typed atom.
  @violating_candidate %{
    id: "cand-w635",
    techniques: [:deceptive],
    purpose: :match_making,
    data_domains: [:public_professional_profiles]
  }

  test "73.6.s2: refusal -> classification -> escalation -> tamper-evident record, chain :ok" do
    # -- Stage 1: real typed refusal from the admission surface ----------
    assert {:error, refusal_atom} = EuAiActAdmission.admit(@violating_candidate)
    assert refusal_atom == :REFUSED_EUAIA_MANIPULATIVE
    assert refusal_atom in EuAiActAdmission.refusal_atoms()

    # -- Stage 2: refused-receipt record over the corpus shape ----------
    receipt = %{
      digest:
        "sha256:" <>
          Base.encode16(:crypto.hash(:sha256, "w635-escalation-receipt"), padding: false),
      refusal_atom: refusal_atom,
      status: :refused,
      rights_harm: false,
      observed_at: ~U[2026-10-06 00:00:00Z]
    }

    # -- Stage 3: IncidentReport.build classifies from the evidence ------
    assert {:ok, report} = IncidentReport.build([receipt])

    assert is_binary(report.incident_id) and String.starts_with?(report.incident_id, "INC-")
    assert [receipt.digest] == report.originating_receipt_digests
    assert :INFRINGES_UNION_LAW in report.classification
    assert report.classification == Enum.uniq(Enum.sort(report.classification))
    assert :MALFUNCTION not in report.classification or receipt.status in [:refused, :error]

    assert report.temporal.first_observed == ~U[2026-10-06 00:00:00Z] and
             report.temporal.last_observed == ~U[2026-10-06 00:00:00Z]

    # determinism: same evidence -> same incident id
    assert {:ok, report_again} = IncidentReport.build([receipt])
    assert report_again.incident_id == report.incident_id

    # -- Stage 4: internal escalation over the EVIDENCED channel ---------
    channel = Enum.find(AuthorityChannel.registry(), &(&1.id == @channel))
    refute is_nil(channel)
    assert channel.kind == :internal
    assert channel.status == :EVIDENCED

    assert {:ok, transmitted} = AuthorityChannel.transmit({:ok, report}, @channel)
    assert transmitted.status == :RECORDED
    assert transmitted.channel_id == @channel
    assert transmitted.incident_id == report.incident_id
    assert transmitted.classification == report.classification
    assert is_list(transmitted.where) and transmitted.where != []

    # honest-channel contrast: authority channels stay PREPARED, never "sent"
    assert {:ok, prepared} = AuthorityChannel.transmit({:ok, report}, :art27_1f_fria_notification)
    assert prepared.status == :PREPARED_NOT_TRANSMITTED

    # typed refusals hold at the channel boundary
    assert {:error, :REFUSED_UNKNOWN_CHANNEL} =
             AuthorityChannel.transmit({:ok, report}, :nonexistent_channel)

    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit({:error, :REFUSED_EUAIA_MANIPULATIVE}, @channel)

    # -- Stage 5: tamper-evident record of the escalation -----------------
    payload_digest =
      Base.encode16(
        :crypto.hash(:sha256, :erlang.term_to_iovec({transmitted.incident_id, receipt.digest})),
        padding: false,
        case: :lower
      )

    assert {:ok, chain = [r0], head} =
             AuditChain.append([], %{
               actuation_id: transmitted.incident_id,
               payload_digest: payload_digest,
               sig_slot: {:w635, @channel}
             })

    assert r0.t == 0
    assert r0.prev_hash == AuditChain.root_hash()
    assert r0.actuation_id == transmitted.incident_id
    assert r0.payload_digest == payload_digest
    assert regex_64hex?(head)

    # link equation: H_1 = SHA256(JCS(R_0) <> H_0)
    assert head == AuditChain.hash_receipt(r0, AuditChain.root_hash())

    assert :ok = AuditChain.verify_chain(chain, expected_length: 1, expected_head: head)
    assert AuditChain.martingale(chain) == [1]

    # -- Stage 6: monotone martingale — tamper flips M to 0 permanently --
    # two-link chain: M stays [1, 1] clean
    assert {:ok, chain2, head2} =
             AuditChain.append(chain, %{
               actuation_id: {:w635, :second_link},
               payload_digest: payload_digest
             })

    assert [r0, r1] = chain2

    assert r1.prev_hash == head
    assert :ok = AuditChain.verify_chain(chain2, expected_length: 2, expected_head: head2)
    assert AuditChain.martingale(chain2) == [1, 1]

    # content tamper at position 0: exact attribution + latch to 0 (monotone
    # non-increasing, Theorem 4.1); the last link is content-unverifiable
    # without expected_head (documented limitation) — so tamper link 0.
    tampered_link0 = put_in(r0.payload_digest, String.duplicate("ff", 64))
    tampered_chain = [tampered_link0, Enum.at(chain2, 1)]

    assert {:error, {:tampered, 0}} =
             AuditChain.verify_chain(tampered_chain,
               expected_length: 2,
               expected_head: head2
             )

    assert AuditChain.martingale(tampered_chain) == [0, 0]
  end

  defp regex_64hex?(s) when is_binary(s), do: Regex.match?(~r/^[0-9a-f]{64}$/, s)
  defp regex_64hex?(_), do: false
end
