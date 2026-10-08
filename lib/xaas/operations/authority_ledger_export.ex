defmodule Xaas.Operations.AuthorityLedgerExport do
  @moduledoc """
  Operator-facing authority and refusal receipt export (v26.10.7 WP-1,
  Ash/OS-14, EU AI Act Art. 12(3)): a canonical-JSON bundle of

    (a) the typed refusal-code vocabulary — the refusal-ledger variants
        from `docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json` (the
        same source of truth `Xaas.Semantics.AiroRiskMapping` projects),
    (b) audit-log authority entries (`Xaas.Operations.AuditLogEntry`) and
        actuation receipts (`Xaas.Operations.ActuationReceipt`) within an
        optional `--since` window, and
    (c) a Merkle root over the sorted entries (SHA-256; BLAKE3 is not in
        deps — substitution disclosed here and in the bundle payload as
        `"hash_algorithm": "sha256"`).

  Canonical form: RFC 8785 JCS via `Xaas.Semantics.Jcs` (the same facade
  `Xaas.Witness.AuditChain` uses), so bundle bytes are reproducible: no
  wall-clock timestamp, no map-order dependence — entries are sorted by
  `{source, id}` and the bundle map is JCS-sorted at encode time.

  Typed refusals: an empty ledger (zero entries after the `:since`
  filter) is a typed error, never an empty-success bundle:

      {:error, {:empty_ledger, %{entries: 0, refusal_variants: m, since: dt | nil}}}

  Pure reads over the real repo (Chicago): no process, no mock. The mix
  task `mix xaas.export_authority_ledger` is a thin shell over this
  module.
  """

  alias Xaas.Operations.{ActuationReceipt, AuditLogEntry}
  alias Xaas.Semantics.AiroRiskMapping

  # W984ci minimal cross-lane unblock (compile-freeze SLA, disclosed in
  # lane receipt): the `^pin` pins below only compile inside the
  # Ash.Query.filter macro, which must be required in this plain module
  # (it is not auto-imported by `use Ash.Resource` here).
  require Ash.Query

  @ledger_version 1
  @hash_algorithm "sha256"

  @type bundle_result ::
          {:ok,
           %{
             bundle: map(),
             canonical_json: binary(),
             merkle_root: String.t()
           }}
          | {:error, {:empty_ledger, map()}}
          | {:error, {:refusal_ledger_unreadable, String.t()}}

  @doc """
  Build the bundle. `opts`:

    * `:since` — `DateTime` or `nil` (all rows).

  Reads the real refusal-ledger file and real AuditLogEntry /
  ActuationReceipt rows (reads are `authorize?: false` — the
  operator-facing internal surface, mirroring how
  `Xaas.Governance.Changes.WriteAuditLogEntry` writes internally).
  """
  @spec bundle(keyword()) :: bundle_result()
  def bundle(opts \\ []) do
    since = Keyword.get(opts, :since)

    with {:ok, variants} <- refusal_variants(),
         {:ok, entries} <- authority_entries(since) do
      if entries == [] do
        {:error,
         {:empty_ledger,
          %{entries: 0, refusal_variants: length(variants), since: since}}}
      else
        leaves = entry_leaves(entries)
        root = merkle_root(Enum.map(leaves, &elem(&1, 1)))

        bundle = %{
          "hash_algorithm" => @hash_algorithm,
          "ledger_version" => @ledger_version,
          "merkle_root" => root,
          "since" => datetime_json(since),
          "refusal_variants" => Enum.map(variants, &variant_json/1),
          "entries" => Enum.map(leaves, fn {entry, leaf} ->
            Map.put(entry, "leaf_hash", leaf)
          end)
        }

        {:ok, %{bundle: bundle, canonical_json: encode(bundle), merkle_root: root}}
      end
    end
  end

  @doc """
  Court replay path: recompute the Merkle root from a decoded bundle.
  Leaves are `sha256(JCS(entry-without-"leaf_hash"))` in the bundle's
  stored entry order (which is the sorted order at emit time); pairwise
  SHA-256, odd leaf duplicated.
  """
  @spec recompute_root(map()) :: {:ok, String.t()} | {:error, :malformed_bundle}
  def recompute_root(%{"entries" => entries}) when is_list(entries) do
    if Enum.all?(entries, &is_map/1) do
      leaves =
        Enum.map(entries, fn entry ->
          entry |> Map.delete("leaf_hash") |> sha256_jcs()
        end)

      {:ok, merkle_root(leaves)}
    else
      {:error, :malformed_bundle}
    end
  end

  def recompute_root(_), do: {:error, :malformed_bundle}

  @doc """
  Leaf construction: entries sorted by `{source, id}`; each leaf is
  `sha256(JCS(entry))`. Returns `[{entry_map, leaf_hex}]` in sorted
  order.
  """
  @spec entry_leaves([map()]) :: [{map(), String.t()}]
  def entry_leaves(entries) do
    entries
    |> Enum.sort_by(&{&1["source"], &1["id"]})
    |> Enum.map(fn entry -> {entry, sha256_jcs(entry)} end)
  end

  @doc """
  H = SHA256(left <> right); odd trailing leaf is duplicated (Bitcoin /
  Certificate-Transparency idiom). One leaf: the leaf itself. Zero
  leaves: 64 hex zeros (the `Xaas.Witness.AuditChain` root idiom).
  """
  @spec merkle_root([String.t()]) :: String.t()
  def merkle_root([]), do: String.duplicate("0", 64)
  def merkle_root(leaves), do: reduce_level(leaves)

  defp reduce_level([single]), do: single
  defp reduce_level(level), do: reduce_level(pair_level(level))

  defp pair_level([a, b | rest]), do: [hash_pair(a, b) | pair_level(rest)]
  defp pair_level([a]), do: [hash_pair(a, a)]
  defp pair_level([]), do: []

  defp hash_pair(a, b), do: sha256_raw(a <> b)

  # -- internals --

  defp refusal_variants do
    case AiroRiskMapping.variants() do
      [] -> {:error, {:refusal_ledger_unreadable, AiroRiskMapping.ledger_path()}}
      variants -> {:ok, variants}
    end
  end

  defp authority_entries(since) do
    audit_rows = read_audit(since)
    receipt_rows = read_receipts(since)

    entries =
      Enum.map(audit_rows, &audit_entry_json/1) ++
        Enum.map(receipt_rows, &receipt_entry_json/1)

    {:ok, entries}
  end

  defp read_audit(nil), do: Ash.read!(AuditLogEntry, authorize?: false)

  # occurred_at is the public authority timestamp on AuditLogEntry
  # (Ash 3 query filters may only reference public attributes;
  # inserted_at/started_at are private create_timestamps).
  defp read_audit(%DateTime{} = dt) do
    AuditLogEntry
    |> Ash.Query.new()
    |> Ash.Query.filter(occurred_at >= ^dt)
    |> Ash.Query.sort(occurred_at: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp read_receipts(nil), do: Ash.read!(ActuationReceipt, authorize?: false)

  # started_at is public on ActuationReceipt; filtering on the private
  # inserted_at would raise "Invalid reference" (Ash 3 public-filter rule).
  defp read_receipts(%DateTime{} = dt) do
    ActuationReceipt
    |> Ash.Query.new()
    |> Ash.Query.filter(started_at >= ^dt)
    |> Ash.Query.sort(started_at: :asc)
    |> Ash.read!(authorize?: false)
  end

  defp audit_entry_json(%AuditLogEntry{} = row) do
    %{
      "source" => "audit_log_entry",
      "id" => row.id,
      "occurred_at" => datetime_json(row.occurred_at),
      "authority" => %{
        "actor_id" => row.actor_id,
        "actor_description" => row.actor_description,
        "action" => row.action,
        "org_id" => row.org_id
      },
      "subject" => %{
        "resource_type" => row.resource_type,
        "resource_id" => row.resource_id
      },
      "metadata" => metadata_json(row.metadata)
    }
  end

  defp receipt_entry_json(%ActuationReceipt{} = row) do
    %{
      "source" => "actuation_receipt",
      "id" => row.id,
      "occurred_at" => datetime_json(row.started_at),
      "authority" => %{
        "status" => to_string(row.status),
        "resource_module" => row.resource_module,
        "action" => row.action,
        "subject_id" => row.subject_id
      },
      "subject" => %{
        "ontology_class_iri" => row.ontology_class_iri,
        "ontology_projection_hash" => row.ontology_projection_hash,
        "input_hash" => row.input_hash,
        "result_hash" => row.result_hash,
        "replay_token" => row.replay_token
      },
      "metadata" => %{}
    }
  end

  defp variant_json(%{variant: variant, sites: sites}) do
    %{"variant" => variant, "sites" => Enum.sort(sites || [])}
  end

  defp variant_json(%{variant: variant}), do: %{"variant" => variant, "sites" => []}

  defp metadata_json(metadata) when is_map(metadata), do: stringify(metadata)
  defp metadata_json(_), do: %{}

  defp stringify(map) when is_map(map) do
    Map.new(map, fn {k, v} ->
      {to_string(k), stringify_value(v)}
    end)
  end

  defp stringify_value(%{} = m), do: stringify(m)
  defp stringify_value(v) when is_list(v), do: Enum.map(v, &stringify_value/1)
  defp stringify_value(v) when is_atom(v) and not is_boolean(v), do: to_string(v)
  defp stringify_value(v), do: v

  defp datetime_json(nil), do: nil
  defp datetime_json(%DateTime{} = dt), do: DateTime.to_iso8601(dt)

  defp encode(term), do: Xaas.Semantics.Jcs.encode(term)

  defp sha256_jcs(term), do: sha256_raw(encode(term))

  defp sha256_raw(iodata),
    do: :crypto.hash(:sha256, iodata) |> Base.encode16(case: :lower)
end
