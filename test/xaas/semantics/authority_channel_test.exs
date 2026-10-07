defmodule Xaas.Semantics.AuthorityChannelTest do
  @moduledoc """
  Chicago-style tests for the authority-channel registry: real structured
  data, real file-existence checks over cited paths, deterministic
  outputs, typed refusals. No mocks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.AuthorityChannel
  alias Xaas.Semantics.IncidentReport

  @open_basis "corpus 73.4-73.5 — no authority endpoint exists"

  defp witnessed_receipt do
    %{
      digest: "sha256:test-digest-1",
      refusal_atom: "REFUSED_EUAIA_MANIPULATIVE_HARM",
      status: :refused,
      observed_at: ~U[2026-10-01 00:00:00Z]
    }
  end

  defp built_report do
    {:ok, report} = IncidentReport.build([witnessed_receipt()])
    report
  end

  describe "registry/0 structure" do
    test "contains the 73.x / 3.49 / 27.1.f authority family plus the two real channels" do
      reg = AuthorityChannel.registry()

      ids = Enum.map(reg, & &1.id)

      assert ids == Enum.sort(ids)

      assert MapSet.subset?(
               MapSet.new([
                 :art73_market_surveillance,
                 :corpus_3_49_transparency_family,
                 :art27_1f_fria_notification,
                 :internal_escalation_receipt_corpus,
                 :board_audit_fiduciary
               ]),
               MapSet.new(ids)
             )
    end

    test "every channel has the complete structural shape" do
      for channel <- AuthorityChannel.registry() do
        assert is_atom(channel.id)
        assert channel.kind in [:authority, :internal, :board]
        assert is_binary(channel.article_basis) and channel.article_basis != ""
        assert channel.status in [:OPEN, :EVIDENCED]
        assert channel.endpoint == :OPEN or is_map(channel.endpoint)
        assert is_binary(channel.basis) and channel.basis != ""
        assert is_binary(channel.report_format) and channel.report_format != ""
      end
    end

    test "authority channels are typed OPEN with the typed basis" do
      for channel <- AuthorityChannel.registry(),
          channel.kind == :authority do
        assert channel.status == :OPEN
        assert channel.endpoint == :OPEN
        assert channel.basis == @open_basis
        assert channel.report_format == "Art 73 envelope per Xaas.Semantics.IncidentReport"
      end
    end

    test "real channels are EVIDENCED with cited paths that exist on disk" do
      for channel <- AuthorityChannel.registry(),
          channel.kind in [:internal, :board] do
        assert channel.status == :EVIDENCED
        assert is_list(channel.where) and channel.where != []

        for path <- channel.where do
          assert File.exists?(Path.join(File.cwd!(), path)),
                 "cited path missing: #{path}"
        end
      end
    end

    test "zero-config: registry/0 does not consult the application environment" do
      # No app-env key feeds the registry: passing no operator channels
      # yields the base registry, deterministically.
      assert AuthorityChannel.registry() == AuthorityChannel.registry()
    end
  end

  describe "operator seam" do
    test "with_endpoint/3 binds an operator endpoint as data, keeping the typed OPEN status" do
      endpoint = %{endpoint: "https://authority.example.eu/notify", transport: :https}

      {:ok, derived} =
        AuthorityChannel.with_endpoint(:art73_market_surveillance, endpoint)

      channel = Enum.find(derived, &(&1.id == :art73_market_surveillance))
      assert channel.endpoint == endpoint
      # The legal basis has not changed: still typed OPEN status, but the
      # envelope now travels with an address.
      assert channel.status == :OPEN
      assert channel.basis == @open_basis
    end

    test "with_endpoint/3 refuses an unknown channel id" do
      assert AuthorityChannel.with_endpoint(:no_such_channel, %{}) ==
               {:error, :REFUSED_UNKNOWN_CHANNEL}
    end

    test "registry/1 accepts operator channels as data" do
      operator = [
        %{
          id: :operator_supplied,
          kind: :authority,
          article_basis: "operator-supplied national authority",
          status: :OPEN,
          endpoint: :OPEN,
          basis: @open_basis,
          report_format: "Art 73 envelope per Xaas.Semantics.IncidentReport"
        }
      ]

      reg = AuthorityChannel.registry(operator)
      assert :operator_supplied in Enum.map(reg, & &1.id)
      assert :art73_market_surveillance in Enum.map(reg, & &1.id)
    end
  end

  describe "transmit/2" do
    test "internal channel records for real against the receipt corpus" do
      {:ok, result} =
        AuthorityChannel.transmit(built_report(), :internal_escalation_receipt_corpus)

      assert result.status == :RECORDED
      assert is_list(result.where) and result.where != []
      assert result.channel_id == :internal_escalation_receipt_corpus
      assert result.incident_id == built_report().incident_id
      assert :INFRINGES_UNION_LAW in result.classification
    end

    test "board channel records for real against the CRO evidence pack citations" do
      {:ok, result} = AuthorityChannel.transmit(built_report(), :board_audit_fiduciary)

      assert result.status == :RECORDED
      assert result.channel_id == :board_audit_fiduciary
      assert Enum.any?(result.where, &String.contains?(&1, "witness/"))
    end

    test "authority channels are honestly PREPARED, never transmitted" do
      for id <- [
            :art73_market_surveillance,
            :corpus_3_49_transparency_family,
            :art27_1f_fria_notification
          ] do
        {:ok, result} = AuthorityChannel.transmit(built_report(), id)

        assert result.status == :PREPARED_NOT_TRANSMITTED
        assert result.endpoint == :OPEN
        assert result.where == nil
        assert result.reason =~ "no authority endpoint exists"
        assert result.reason =~ "operator supplies endpoint data, no code change"
      end
    end

    test "PREPARED envelope carries an operator-bound endpoint as data without a socket" do
      endpoint = %{endpoint: "https://authority.example.eu/notify", transport: :https}
      {:ok, derived} = AuthorityChannel.with_endpoint(:art73_market_surveillance, endpoint)
      channel = Enum.find(derived, &(&1.id == :art73_market_surveillance))

      {:ok, result} = AuthorityChannel.transmit(built_report(), channel)

      assert result.status == :PREPARED_NOT_TRANSMITTED
      assert result.endpoint == endpoint
    end

    test "unknown channel id is refused, never guessed" do
      assert AuthorityChannel.transmit(built_report(), :no_such_channel) ==
               {:error, :REFUSED_UNKNOWN_CHANNEL}
    end

    test "report without evidence is refused with IncidentReport's typed refusal" do
      for id <- [:internal_escalation_receipt_corpus, :board_audit_fiduciary,
                 :art73_market_surveillance] do
        assert AuthorityChannel.transmit(
                 %{incident_id: "INC-EMPTY", originating_receipt_digests: []},
                 id
               ) == {:error, :REFUSED_NO_INCIDENT_EVIDENCE}
      end

      # An IncidentReport.build refusal passes through identically.
      {:error, refusal} = IncidentReport.build([])
      assert refusal == :REFUSED_NO_INCIDENT_EVIDENCE

      assert AuthorityChannel.transmit({:error, :REFUSED_NO_INCIDENT_EVIDENCE},
               :internal_escalation_receipt_corpus
             ) == {:error, :REFUSED_NO_INCIDENT_EVIDENCE}
    end
  end

  describe "determinism" do
    test "registry and transmit are pure functions of their inputs" do
      assert AuthorityChannel.registry() == AuthorityChannel.registry()
      report = built_report()

      assert AuthorityChannel.transmit(report, :art73_market_surveillance) ==
               AuthorityChannel.transmit(report, :art73_market_surveillance)

      assert AuthorityChannel.transmit(report, :internal_escalation_receipt_corpus) ==
               AuthorityChannel.transmit(report, :internal_escalation_receipt_corpus)
    end
  end
end
