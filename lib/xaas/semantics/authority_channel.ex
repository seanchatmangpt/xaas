defmodule Xaas.Semantics.AuthorityChannel do
  @moduledoc """
  Typed registry of EU market-surveillance authority channels — the seam
  behind the largest OPEN_GAP family (corpus 3.49 / 73.x / 27.1.f: every
  family lacked the authority transmission endpoint). Honest structured
  data, zero-config, fail-closed.

  ## The gap this closes (as a typed surface, not an invention)

  The 19-item inventory's 73.x / 3.49 / 27.1.f family all reduce to one
  missing capability: *transmission of a serious-incident report to a
  market surveillance authority*. No such endpoint exists in this
  deployment. Inventing one would be dishonest; hiding the gap would be
  worse. So the registry carries every authority channel as structured
  data with `endpoint: :OPEN` and a typed basis string, while the two
  channels that ARE real (internal escalation into the receipt corpus,
  and the board/audit-fiduciary channel over the CRO evidence pack) are
  carried as EVIDENCED with cited paths.

  ## Zero-config fail-closed

  No app-env endpoints. `Application.get_env` is never consulted. When an
  operator later supplies a real endpoint, it enters the registry **as
  data** via `with_endpoint/3` (or by passing operator channels to
  `registry/1`), producing a derived registry — the code is never edited,
  and an unknown channel id is refused, never guessed
  (`:REFUSED_UNKNOWN_CHANNEL`).

  ## The operator seam (upgrading :OPEN to real transmission)

  `transmit/2` on an authority channel returns
  `{:ok, %{status: :PREPARED_NOT_TRANSMITTED, ...}}`. Upgrading to real
  wire transmission = the operator supplies endpoint data (e.g.
  `%{endpoint: "https://...", transport: :https}`) through
  `with_endpoint/3`; `transmit/2` still does not open sockets — it
  returns the prepared envelope plus the endpoint so the calling lane
  owns the transport decision. No code change is required to represent
  the endpoint; the transport act itself remains outside this module.

  This module is a semantics surface only. It never actuates, never opens
  a network connection, and is wired into no live route.
  """

  @typedoc """
  One channel in the registry. `:endpoint` is `:OPEN` (typed gap) or an
  operator-supplied endpoint map; `:basis` is the corpus citation; every
  `:OPEN` endpoint carries its typed basis.
  """
  @type channel :: %{
          required(:id) => atom(),
          required(:kind) => :authority | :internal | :board,
          required(:article_basis) => String.t(),
          required(:status) => :OPEN | :EVIDENCED,
          required(:endpoint) => :OPEN | map(),
          required(:basis) => String.t(),
          required(:report_format) => String.t(),
          optional(:where) => [String.t()]
        }

  @typedoc """
  An `Xaas.Semantics.IncidentReport` build (`{:ok, report}`) or the raw
  report map. Reports without originating evidence are refused with the
  same typed refusal `IncidentReport.build/2` uses.
  """
  @type report_input ::
          {:ok, Xaas.Semantics.IncidentReport.report()}
          | Xaas.Semantics.IncidentReport.report()
          | map()

  @typedoc "Typed refusal atoms."
  @type refusal ::
          :REFUSED_UNKNOWN_CHANNEL
          | :REFUSED_NO_INCIDENT_EVIDENCE

  @open_authority_basis "corpus 73.4-73.5 — no authority endpoint exists"

  @open_authority_format "Art 73 envelope per Xaas.Semantics.IncidentReport"

  ## ------------------------------------------------------------------
  ## Registry
  ## ------------------------------------------------------------------

  @doc """
  The typed registry. Deterministic (sorted by channel id). Zero-config:
  no app-env endpoints are consulted; operator channels may be supplied
  as data via the optional argument.
  """
  @spec registry([channel()]) :: [channel()]
  def registry(operator_channels \\ []) when is_list(operator_channels) do
    operator_channels
    |> Kernel.++(base_registry())
    |> Enum.map(&verify_paths/1)
    |> sort_channels()
  end

  @doc """
  Derives a registry with a real endpoint bound into the channel `id`.
  The endpoint is **data, not configuration**: the derived channel keeps
  `status: :OPEN` (the authority endpoint's legal basis has not changed)
  but carries the operator-supplied endpoint map so downstream lanes can
  decide transport. Unknown id → `{:error, :REFUSED_UNKNOWN_CHANNEL}`.
  """
  @spec with_endpoint(atom(), map(), [channel()]) ::
          {:ok, [channel()]} | {:error, :REFUSED_UNKNOWN_CHANNEL}
  def with_endpoint(id, endpoint, operator_channels \\ [])
      when is_atom(id) and is_map(endpoint) and is_list(operator_channels) do
    reg = registry(operator_channels)

    if Enum.any?(reg, &(&1.id == id)) do
      {:ok, Enum.map(reg, &bind_endpoint(&1, id, endpoint))}
    else
      {:error, :REFUSED_UNKNOWN_CHANNEL}
    end
  end

  ## ------------------------------------------------------------------
  ## Transmission
  ## ------------------------------------------------------------------

  @doc """
  Transmit a report over a channel (matched by id, or given as a channel
  map).

  - **internal / board** channels → `{:ok, %{status: :RECORDED, where:
    path-citations}}` — recorded against the cited receipt-corpus / CRO
    evidence-pack paths.
  - **authority** channels → `{:ok, %{status:
    :PREPARED_NOT_TRANSMITTED}}` — honest: the report is prepared, never
    silently "sent"; the endpoint is typed OPEN (or operator-bound data,
    still no socket opened here).
  - unknown channel → `{:error, :REFUSED_UNKNOWN_CHANNEL}`
  - report without originating evidence →
    `{:error, :REFUSED_NO_INCIDENT_EVIDENCE}` (same typed refusal
    `IncidentReport.build/2` uses for an empty receipt set).

  Deterministic: same inputs → same result; no clock, no randomness.
  """
  @spec transmit(report_input(), channel() | atom(), [channel()]) ::
          {:ok, map()} | {:error, refusal()}
  def transmit(report_input, channel_or_id, operator_channels \\ [])

  def transmit(report_input, id, ops) when is_atom(id) do
    case Enum.find(registry(ops), &(&1.id == id)) do
      nil -> {:error, :REFUSED_UNKNOWN_CHANNEL}
      channel -> transmit(report_input, channel)
    end
  end

  def transmit(report_input, %{kind: kind, where: where} = channel, _ops)
      when kind in [:internal, :board] do
    with {:ok, report} <- normalize_report(report_input) do
      {:ok,
       %{
         status: :RECORDED,
         where: where || [],
         channel_id: channel.id,
         incident_id: report.incident_id,
         classification: report.classification
       }}
    end
  end

  def transmit(report_input, %{kind: :authority} = channel, _ops) do
    with {:ok, report} <- normalize_report(report_input) do
      {:ok,
       %{
         status: :PREPARED_NOT_TRANSMITTED,
         where: nil,
         channel_id: channel.id,
         incident_id: report.incident_id,
         classification: report.classification,
         reason:
           "no authority endpoint exists — typed OPEN per corpus 73.4-73.5; " <>
             "upgrading to real transmission = operator supplies endpoint data, no code change",
         endpoint: channel.endpoint
       }}
    end
  end

  def transmit(_report_input, _other, _ops), do: {:error, :REFUSED_UNKNOWN_CHANNEL}

  ## ------------------------------------------------------------------
  ## Internals
  ## ------------------------------------------------------------------

  defp normalize_report({:ok, report}) when is_map(report), do: validate_report(report)
  defp normalize_report(report) when is_map(report), do: validate_report(report)
  defp normalize_report(_), do: {:error, :REFUSED_NO_INCIDENT_EVIDENCE}

  defp validate_report(%{originating_receipt_digests: digests} = report)
       when is_list(digests) do
    if digests == [] do
      {:error, :REFUSED_NO_INCIDENT_EVIDENCE}
    else
      {:ok, report}
    end
  end

  defp validate_report(_), do: {:error, :REFUSED_NO_INCIDENT_EVIDENCE}

  defp bind_endpoint(channel, id, endpoint) do
    if channel.id == id do
      %{channel | endpoint: endpoint}
    else
      channel
    end
  end

  defp verify_paths(channel) do
    case channel[:where] do
      nil ->
        channel

      paths ->
        # Cited paths are repo-relative and verified to exist at call
        # time — same discipline as OversightGovernance. A missing cited
        # path degrades the channel to typed :OPEN, so a drifted path can
        # never keep an EVIDENCED claim standing silently.
        missing = Enum.filter(paths, &not File.exists?(Path.join(File.cwd!(), &1)))

        if missing == [] do
          channel
        else
          %{
            channel
            | status: :OPEN,
              basis:
                "cited paths missing on disk: #{inspect(missing)} — channel degraded, typed OPEN"
          }
        end
    end
  end

  defp sort_channels(channels), do: Enum.sort_by(channels, & &1.id)

  ## ------------------------------------------------------------------
  ## Base registry (constant structured data)
  ## ------------------------------------------------------------------

  @authority_channels [
    %{
      id: :art73_market_surveillance,
      kind: :authority,
      article_basis: "Art 73(1) serious-incident notification to market surveillance authority",
      status: :OPEN,
      endpoint: :OPEN,
      basis: @open_authority_basis,
      report_format: @open_authority_format
    },
    %{
      id: :corpus_3_49_transparency_family,
      kind: :authority,
      article_basis: "corpus 3.49 family — transparency/incident seam",
      status: :OPEN,
      endpoint: :OPEN,
      basis: @open_authority_basis,
      report_format: @open_authority_format
    },
    %{
      id: :art27_1f_fria_notification,
      kind: :authority,
      article_basis: "Art 27(1)(f) FRIA notification seam",
      status: :OPEN,
      endpoint: :OPEN,
      basis: @open_authority_basis,
      report_format: @open_authority_format
    }
  ]

  @internal_board_channels [
    %{
      id: :internal_escalation_receipt_corpus,
      kind: :internal,
      article_basis: "Art 73(1) internal escalation — the witnessed receipt corpus",
      status: :EVIDENCED,
      endpoint: %{kind: :receipt_corpus, cited: true},
      basis:
        "EVIDENCED — IncidentReport.build over the witnessed receipt corpus " <>
          "(lib/xaas/semantics/incident_report.ex, lib/xaas/witness/)",
      report_format: @open_authority_format,
      where: [
        "lib/xaas/semantics/incident_report.ex",
        "lib/xaas/witness/audit_chain.ex",
        "lib/xaas/witness/certified_receipt.ex"
      ]
    },
    %{
      id: :board_audit_fiduciary,
      kind: :board,
      article_basis: "board / audit-fiduciary channel (CRO evidence pack)",
      status: :EVIDENCED,
      endpoint: %{kind: :cro_evidence_pack, cited: true},
      basis:
        "EVIDENCED — the CRO evidence pack over the certified-receipt witness chain " <>
          "(lib/xaas/witness/), per the OversightGovernance cited-source discipline",
      report_format: @open_authority_format,
      where: [
        "lib/xaas/witness/audit_chain.ex",
        "lib/xaas/witness/certified_receipt.ex",
        "lib/xaas/witness/catalog.ex",
        "lib/xaas/witness/verification_key.ex",
        "lib/xaas/semantics/oversight_governance.ex"
      ]
    }
  ]

  defp base_registry do
    @authority_channels ++ @internal_board_channels
  end
end
