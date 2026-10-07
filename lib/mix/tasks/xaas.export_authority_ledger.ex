defmodule Mix.Tasks.Xaas.ExportAuthorityLedger do
  @shortdoc "Exports a canonical-JSON authority + refusal receipt bundle (Art. 12(3))"

  @moduledoc """
  Operator-facing authority/refusal receipt export (v26.10.7 WP-1,
  OS-14 / EU AI Act Art. 12(3)). Thin shell over
  `Xaas.Operations.AuthorityLedgerExport`: emits one RFC 8785
  JCS-canonical JSON bundle containing

    (a) the typed refusal-code vocabulary (refusal-ledger variants,
        source of truth `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json`),
    (b) audit-log authority entries + actuation receipts within an
        optional `--since` ISO-8601 window, and
    (c) a SHA-256 Merkle root over the sorted entries (BLAKE3 is not in
        deps; substitution disclosed — bundle field
        `"hash_algorithm": "sha256"`).

      mix xaas.export_authority_ledger [--since ISO8601] [--out PATH]

  Default output: stdout. `--out PATH` writes the bundle bytes to a file
  and prints the path instead.

  Typed refusals (non-zero exit via `Mix.raise`, the repo's typed
  refusal convention):

    * empty ledger (zero entries after the `--since` filter):
      `REFUSED(empty_authority_ledger, detail: %{...})`
    * unreadable refusal-ledger source file:
      `REFUSED(refusal_ledger_unreadable, detail: %{path: ...})`
    * unparseable `--since`: `REFUSED(invalid_since, detail: %{value: ...})`
  """

  use Mix.Task

  alias Xaas.Operations.AuthorityLedgerExport

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _positional, invalid} =
      OptionParser.parse(args, strict: [since: :string, out: :string])

    case invalid do
      [] -> :ok
      _ -> Mix.raise("REFUSED(invalid_option, detail: #{inspect(invalid)})")
    end

    since =
      case opts[:since] do
        nil ->
          nil

        raw ->
          case DateTime.from_iso8601(raw) do
            {:ok, dt, _offset} -> dt
            {:error, reason} ->
              Mix.raise("REFUSED(invalid_since, detail: %{value: #{inspect(raw)}, reason: #{inspect(reason)}})")
          end
      end

    case AuthorityLedgerExport.bundle(since: since) do
      {:ok, %{canonical_json: json}} ->
        emit(json, opts[:out])

      {:error, {:empty_ledger, detail}} ->
        Mix.raise("REFUSED(empty_authority_ledger, detail: #{inspect(detail)})")

      {:error, {:refusal_ledger_unreadable, path}} ->
        Mix.raise("REFUSED(refusal_ledger_unreadable, detail: %{path: #{inspect(path)}})")
    end
  end

  defp emit(json, nil), do: Mix.shell().info(json)

  defp emit(json, path) do
    File.write!(path, json)
    Mix.shell().info(path)
  end
end
