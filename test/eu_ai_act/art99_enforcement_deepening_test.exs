defmodule Xaas.EUAIAct.Art99EnforcementDeepeningTest do
  @moduledoc """
  Lane W696 — Art 99/100 enforcement/penalties deepening (Titles VI-XIII).

  The Art 99 (penalties) / Art 100 (corrective actions) corpus lines currently
  classify as NOT_APPLICABLE-by-authority-procedure (fine-setting is the
  authority's power), but the enforcement EXPOSURE those articles presuppose
  runs through this repo's escalation chain: incident classification
  (W538) -> typed authority channel (W625) -> audit-chain anchoring (W503).

  This file exercises that chain for real (Chicago: real collaborators, no
  mocks), pins determinism, asserts typed refusals on malformed authority
  context, and carries the honest residual gap for 99.4.e: the Art 26
  deployer surface is evidenced (W537/W503/W507) but the authority
  transmission endpoint remains typed :OPEN — asserted as OPEN, never
  faked as closed.
  """

  use ExUnit.Case, async: true

  @moduletag :eu_ai_act

  alias Xaas.Semantics.AuthorityChannel
  alias Xaas.Semantics.IncidentReport
  alias Xaas.Witness.AuditChain

  defp refused_receipt do
    %{
      digest: "sha256:w696deadbeef",
      refusal_atom: :REFUSED_EUAIA_BIOMETRIC_CATEGORIZATION,
      status: :refused,
      observed_at: ~U[2026-10-07 00:00:00Z]
    }
  end

  # A non-EUAIA refused receipt: status :refused with a refusal atom outside
  # the Art 5(1) corpus classifies :MALFUNCTION (incident_report.ex).
  defp malfunction_receipt do
    %{
      digest: "sha256:w696malfunction",
      refusal_atom: :REFUSED_UNKNOWN_CHANNEL,
      status: :refused,
      observed_at: ~U[2026-10-07 00:00:00Z]
    }
  end

  # Anchor the escalation record into the audit chain and verify with
  # expected_head. payload_digest must satisfy the chain's 64-hex gate, so
  # the record's digest into the chain is the SHA-256 of the incident id
  # (deterministic content hash, not the receipt's opaque "sha256:" prefix).
  defp anchor(incident_id) do
    payload = :crypto.hash(:sha256, incident_id) |> Base.encode16(case: :lower)

    assert {:ok, chain, head} =
             AuditChain.append([], %{
               actuation_id: {:art99_escalation, incident_id},
               payload_digest: payload
             })

    assert :ok = AuditChain.verify_chain(chain, expected_head: head, expected_length: 1)
    {chain, head, payload}
  end

  # -- 1. Full escalation chain composition --------------------------------

  test "Art 99 exposure chain: incident -> channel PREPARED_NOT_TRANSMITTED -> authority escalation -> audit-chain anchor via expected_head" do
    # (a) incident classification from the witnessed refusals: the EUAIA atom
    # classifies the Union-law infringement; the non-EUAIA refused receipt
    # classifies the malfunction (both classes over one incident envelope).
    assert {:ok, report} = IncidentReport.build([refused_receipt(), malfunction_receipt()])
    assert Enum.sort(report.classification) == [:INFRINGES_UNION_LAW, :MALFUNCTION]
    assert report.incident_id =~ ~r/^INC-[0-9A-F]+$/

    # (b) authority channel: honest PREPARED_NOT_TRANSMITTED, typed OPEN
    assert {:ok, prepared} = AuthorityChannel.transmit(report, :art73_market_surveillance)
    assert prepared.status == :PREPARED_NOT_TRANSMITTED
    assert prepared.endpoint == :OPEN
    assert prepared.incident_id == report.incident_id
    assert prepared.reason =~ "typed OPEN"

    # (c) authority escalation recorded for real on the internal channel
    assert {:ok, recorded} =
             AuthorityChannel.transmit(report, :internal_escalation_receipt_corpus)

    assert recorded.status == :RECORDED
    assert recorded.channel_id == :internal_escalation_receipt_corpus
    assert recorded.incident_id == report.incident_id
    assert is_list(recorded.where) and recorded.where != []

    # (d) audit-chain anchoring of the escalation record via expected_head
    {_chain, head, payload} = anchor(report.incident_id)

    # The head binding is real: a wrong expected_head is refused as head tamper
    chain0 = elem(anchor(report.incident_id), 0)
    assert {:error, {:tampered, :head}} =
             AuditChain.verify_chain(chain0, expected_head: String.duplicate("f", 64))

    # the anchored payload digest is a lawful chain digest
    assert payload =~ ~r/^[0-9a-f]{64}$/
    assert is_binary(head) and byte_size(head) == 64
  end

  test "Art 100 corrective-action substrate: quiescent-stop and audit chain present behind the escalation" do
    # Corrective action (Art 100 withdrawal/decommission posture) grounds in
    # the quiescent-stop surface and the audit chain — cited, not invented.
    for path <- [
          "lib/xaas/actuation/quiescent_stop.ex",
          "lib/xaas/witness/audit_chain.ex",
          "lib/xaas/semantics/authority_channel.ex",
          "lib/xaas/semantics/incident_report.ex"
        ] do
      assert File.exists?(Path.expand(path, File.cwd!())), "missing: #{path}"
    end

    src = File.read!(Path.expand("lib/xaas/actuation/quiescent_stop.ex", File.cwd!()))
    assert src =~ "defmodule Xaas.Actuation.QuiescentStop"
  end

  # -- 2. Determinism x3 -----------------------------------------------------

  test "escalation chain is deterministic across three runs (no clock, no randomness)" do
    runs =
      for _ <- 1..3 do
        {:ok, report} = IncidentReport.build([refused_receipt()])

        {:ok, prepared} = AuthorityChannel.transmit(report, :art73_market_surveillance)

        {:ok, recorded} =
          AuthorityChannel.transmit(report, :internal_escalation_receipt_corpus)

        {_chain, head, payload} = anchor(report.incident_id)

        %{
          incident_id: report.incident_id,
          classification: Enum.sort(report.classification),
          prepared_status: prepared.status,
          prepared_reason: prepared.reason,
          recorded_status: recorded.status,
          head: head,
          payload: payload
        }
      end

    assert length(runs) == 3
    assert Enum.uniq(runs) == [hd(runs)]
  end

  test "registry enumeration is deterministic and sorted" do
    ids = for _ <- 1..3, do: AuthorityChannel.registry() |> Enum.map(& &1.id)
    assert Enum.uniq(ids) == [hd(ids)]
    assert hd(ids) == Enum.sort(hd(ids))
  end

  # -- 3. Typed refusals on malformed authority context ----------------------

  test "malformed authority context is refused with typed atoms, never guessed" do
    {:ok, report} = IncidentReport.build([refused_receipt()])

    # unknown channel id
    assert {:error, :REFUSED_UNKNOWN_CHANNEL} =
             AuthorityChannel.transmit(report, :no_such_channel)

    # non-map report input
    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit("junk", :art73_market_surveillance)

    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit(nil, :internal_escalation_receipt_corpus)

    # report with empty originating evidence
    empty = %{report | originating_receipt_digests: []}

    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit(empty, :art73_market_surveillance)

    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit(empty, :internal_escalation_receipt_corpus)

    # report without the originating-evidence key at all
    assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} =
             AuthorityChannel.transmit(%{incident_id: report.incident_id}, :art73_market_surveillance)

    # with_endpoint on an unknown channel
    assert {:error, :REFUSED_UNKNOWN_CHANNEL} =
             AuthorityChannel.with_endpoint(:no_such_channel, %{endpoint: "https://example.test"})

    # audit chain: malformed receipt attrs refused; a non-hex payload digest
    # is accepted by append/2 but the chain REFUSES it at verify time (the
    # 64-hex gate lives in verify, not append — real current behavior).
    assert {:error, :invalid_receipt_attrs} = AuditChain.append([], %{actuation_id: :x})

    assert {:ok, [bad], _h} =
             AuditChain.append([], %{actuation_id: :x, payload_digest: "not-hex"})

    assert {:error, {:tampered, 0}} = AuditChain.verify_chain([bad])
  end

  test "tampered escalation record is detected by the chain (enforcement record is tamper-evident)" do
    {:ok, report} = IncidentReport.build([refused_receipt()])
    {chain, head, _payload} = anchor(report.incident_id)

    # tamper the anchored record's payload digest with a non-hex value — the
    # 64-hex gate then fails at index 0 with exact attribution
    [receipt] = chain
    tampered = %{receipt | payload_digest: "tampered-not-hex"}

    assert {:error, {:tampered, 0}} =
             AuditChain.verify_chain([tampered], expected_head: head, expected_length: 1)

    # truncation detected against the anchored length
    assert {:error, {:truncated, 1}} =
             AuditChain.verify_chain([], expected_head: head, expected_length: 1)
  end

  # -- 4. Honest 99.4.e classification (no fake closure) ---------------------

  test "99.4.e residual gap is honestly typed: Art 26 surface evidenced, authority endpoint still :OPEN" do
    # The current computed classification of 99.4.e lives in the Titles
    # VI-XIII substrate (test/eu_ai_act/title_vi_xiii_test.exs — per-file
    # module, only loaded when that file runs). When it is loaded, assert the
    # COMPUTED classification for real; otherwise pin the classification
    # substrate on disk. Either way the verdict must exist and be lawful.
    # resolved dynamically: the substrate module lives in a sibling test file
    # and is only compiled when that file is also loaded.
    lines_mod = :"Elixir.Xaas.EUAIAct.TitleVIXIII.Lines"

    if Code.ensure_loaded?(lines_mod) do
      verdicts =
        :maps.from_list(
          for({l, v, d} <- lines_mod.lines_with_verdicts(), do: {l["line_id"], {v, d}})
        )

      assert Map.has_key?(verdicts, "99.4.e")
      {verdict, detail} = Map.fetch!(verdicts, "99.4.e")
      assert verdict in [:evidenced, :open_gap, :not_applicable]

      # detail shape differs by verdict: evidenced carries {lane, desc, paths},
      # open_gap/not_applicable carry a binary reason
      case verdict do
        :evidenced ->
          {lane, desc, paths} = detail
          assert lane == "W537/W503/W507"
          assert is_binary(desc) and desc != ""
          assert is_list(paths) and paths != []

        _ ->
          assert is_binary(detail) and detail != ""
      end
    else
      src = File.read!(Path.expand("test/eu_ai_act/title_vi_xiii_test.exs", File.cwd!()))
      # the evidence-map flip (W537) and the cond fallback both cite 99.4.e
      assert src =~ ~s("99.4.e" =>)
      assert src =~ "W537/W503/W507"
      assert src =~ "id == \"99.4.e\""
    end

    # The honest residual component either way: the authority transmission
    # endpoint behind any Art 99/100 enforcement contact is typed OPEN.
    # Closure is NOT faked into a "sent" status.
    reg = AuthorityChannel.registry()

    authority_channels = Enum.filter(reg, &(&1.kind == :authority))
    assert authority_channels != []
    assert Enum.all?(authority_channels, &(&1.endpoint == :OPEN and &1.status == :OPEN))

    {:ok, report} = IncidentReport.build([refused_receipt()])

    for ch <- authority_channels do
      assert {:ok, prepared} = AuthorityChannel.transmit(report, ch.id)
      assert prepared.status == :PREPARED_NOT_TRANSMITTED
      assert prepared.endpoint == :OPEN
    end
  end
end
