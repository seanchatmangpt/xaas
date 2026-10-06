defmodule Xaas.Security do
  @moduledoc """
  Estate security posture domain: ingests security-scan summaries
  (sobelow / hex.audit / trivy / mutation / red team) as `Xaas.Security.Finding`
  records and rolls them up into `Xaas.Security.Posture` aggregates.

  Ingest contract: `ingest/1` accepts a decoded summary map with a
  `"repo"`, optional `"scan_date"` (ISO8601 string), and a `"findings"`
  list; each finding carries `"severity"`, `"source"`, `"file"`,
  optional `"line"`, `"description"`, optional `"disposition"`
  (default `pending`), optional `"court_ref"`, optional
  `"discovered_at"` (ISO8601 string).
  """

  use Ash.Domain,
    otp_app: :xaas,
    extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(Xaas.Security.Finding)
    resource(Xaas.Security.Posture)
  end

  alias Xaas.Security.Finding
  alias Xaas.Security.Posture

  @dispositioned ~w(fixed accepted_typed refused_by_design)a

  @doc """
  Ingests a security scan summary (decoded JSON map) into Finding records
  plus one Posture aggregate row. Returns `{:ok, posture}` or
  `{:error, reason}`. Also accepts a path to a JSON file.
  """
  def ingest(summary) when is_map(summary) do
    findings =
      Enum.map(summary["findings"] || [], fn f ->
        Finding
        |> Ash.Changeset.for_create(:ingest, %{
          severity: atomize(f["severity"]),
          source: atomize(f["source"]),
          file: f["file"],
          line: f["line"],
          description: f["description"],
          disposition: atomize(f["disposition"] || "pending"),
          court_ref: f["court_ref"],
          discovered_at: parse_dt(f["discovered_at"])
        })
        |> Ash.create!()
      end)

    counts = Enum.frequencies_by(findings, & &1.severity)

    posture =
      Posture
      |> Ash.Changeset.for_create(:register, %{
        repo: summary["repo"],
        scan_date: parse_dt(summary["scan_date"]),
        total_findings: length(findings),
        critical_count: Map.get(counts, :critical, 0),
        high_count: Map.get(counts, :high, 0),
        medium_count: Map.get(counts, :medium, 0),
        low_count: Map.get(counts, :low, 0),
        info_count: Map.get(counts, :info, 0),
        dispositioned_count: Enum.count(findings, &(&1.disposition in @dispositioned)),
        green: Enum.all?(findings, &(&1.disposition in @dispositioned))
      })
      |> Ash.create!()

    {:ok, posture}
  end

  def ingest(path) when is_binary(path), do: path |> File.read!() |> Jason.decode!() |> ingest()

  @doc """
  Returns the aggregate posture across every ingested scan:
  `%{total_findings:, high_count:, medium_count:, low_count:,
  dispositioned_count:, green:}` where `green` is true only if every
  ingested scan was green (only dispositioned findings count toward green).
  """
  def posture_summary do
    postures = Ash.read!(Posture)

    %{
      total_findings: Enum.sum(Enum.map(postures, & &1.total_findings)),
      high_count: Enum.sum(Enum.map(postures, & &1.high_count)),
      medium_count: Enum.sum(Enum.map(postures, & &1.medium_count)),
      low_count: Enum.sum(Enum.map(postures, & &1.low_count)),
      dispositioned_count: Enum.sum(Enum.map(postures, & &1.dispositioned_count)),
      green: postures != [] and Enum.all?(postures, & &1.green)
    }
  end

  defp atomize(nil), do: nil

  defp atomize(v) when is_binary(v) do
    String.to_existing_atom(v)
  rescue
    # unknown enum value: pass the binary through so Ash's one_of
    # constraint refuses it as a typed validation error
    ArgumentError -> v
  end

  defp parse_dt(nil), do: nil

  defp parse_dt(%DateTime{} = dt), do: dt

  defp parse_dt(bin) when is_binary(bin) do
    {:ok, dt, 0} = DateTime.from_iso8601(bin)
    dt
  end
end
