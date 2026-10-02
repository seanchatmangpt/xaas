defmodule Xaas.Bridges.Sa2a do
  @moduledoc """
  SA2A bridge: evidence reader for a court receipt. Nothing else.

  This bridge reads a receipt document and reports it with provenance. It never
  synthesizes evidence and never relabels standing: whatever the receipt claims,
  the bridge's own standing is `"UNKNOWN"` unless this session itself executed
  the subject — a read is not an execution. While the receipt's subject SHA
  differs from the repository pin, the mismatch is the provenance; the reading
  stays UNKNOWN (R8).
  """

  @default_receipt_path "docs/sjira/v26.10.1/court-receipt.json"

  @doc "Default receipt path, relative to the repository root."
  def default_receipt_path, do: @default_receipt_path

  @doc """
  Reads the court receipt and binds it to the current subject pin.

  `opts`:

    * `:path` — receipt file (default `XAAS_COURT_RECEIPT` env, else
      `#{@default_receipt_path}`);
    * `:pin` — the expected subject SHA (default `XAAS_SUBJECT_SHA` env, else
      the repository HEAD resolved by `Xaas.Bridges.head_sha/0`).

  The returned map always carries `standing: "UNKNOWN"`. `provenance` names why:
  `:receipt_not_found`, `:receipt_unreadable`, `:receipt_subject_mismatch` (with
  both SHAs), or `:receipt_subject_match` (with the receipt's own standing
  reported verbatim under `receipt_standing` — reported, never adopted).
  """
  @spec court_receipt(keyword()) :: {:unknown, map()}
  def court_receipt(opts \\ []) when is_list(opts) do
    path = receipt_path(opts)
    pin = pin(opts)
    base = Xaas.Bridges.envelope(Xaas.Bridges.subject(), "sa2a court receipt", :unknown)

    with {:ok, body} <- read_receipt(path),
         {:ok, receipt} <- decode(body) do
      receipt_subject = receipt_subject_sha(receipt)

      if is_binary(receipt_subject) and is_binary(pin) and receipt_subject == pin do
        {:unknown,
         %{
           base
           | evidence_ref: "sa2a.court_receipt:" <> path,
             provenance: %{
               reason: :receipt_subject_match,
               path: path,
               pin: pin,
               receipt_subject_sha: receipt_subject,
               receipt_standing: receipt_standing(receipt),
               receipt_hash: receipt_hash(receipt)
             }
         }}
      else
        {:unknown,
         %{
           base
           | evidence_ref: "sa2a.court_receipt:" <> path,
             provenance: %{
               reason: :receipt_subject_mismatch,
               path: path,
               pin: pin,
               receipt_subject_sha: receipt_subject
             }
         }}
      end
    else
      {:error, reason} ->
        {:unknown,
         %{
           base
           | provenance: %{
               reason: reason,
               path: path,
               pin: pin
             }
         }}
    end
  end

  defp receipt_path(opts) do
    opts[:path] || System.get_env("XAAS_COURT_RECEIPT") || @default_receipt_path
  end

  defp pin(opts) do
    case Keyword.fetch(opts, :pin) do
      {:ok, pin} -> pin
      :error -> System.get_env("XAAS_SUBJECT_SHA") || Xaas.Bridges.head_sha()
    end
  end

  defp read_receipt(path) do
    case File.read(path) do
      {:ok, body} -> {:ok, body}
      {:error, :enoent} -> {:error, :receipt_not_found}
      {:error, _reason} -> {:error, :receipt_unreadable}
    end
  end

  defp decode(body) do
    case Jason.decode(body) do
      {:ok, %{} = receipt} -> {:ok, receipt}
      _ -> {:error, :receipt_unreadable}
    end
  end

  defp receipt_subject_sha(receipt) do
    receipt["subject_sha"] || receipt["subjectSha"] || receipt["subject"] ||
      receipt["baseSha"] || receipt["base_sha"]
  end

  defp receipt_standing(receipt), do: receipt["standing"] || receipt["status"]

  defp receipt_hash(receipt), do: receipt["receipt_hash"] || receipt["hash"] || receipt["sha256"]
end
