defmodule Xaas.Operations.AuthorityLedgerExportTest do
  @moduledoc """
  W603 Chicago court for `mix xaas.export_authority_ledger` /
  `Xaas.Operations.AuthorityLedgerExport` (v26.10.7 WP-1, OS-14 /
  Art. 12(3)).

  Real rows, real repo, real file (the refusal-ledger source of truth),
  no mock. Proven properties:

    1. Determinism: the same real rows produce byte-identical canonical
       bundle JSON on two independent runs (no wall clock, no map-order
       dependence).
    2. Root replay: the Merkle root recomputed from the emitted bundle
       (leaves = sha256(JCS(entry-without-leaf_hash))) equals the emitted
       root, on the module surface AND on the real
       `mix xaas.export_authority_ledger --out` bytes.
    3. Typed refusal: an empty selection window is a typed
       `{:error, {:empty_ledger, detail}}`, never an empty-success
       bundle — module surface AND a real mix task run raising the typed
       `REFUSED(empty_authority_ledger, ...)` Mix.Error. The empty window
       is real: `since: 2999-01-01` selects zero entries (the shared test
       DB durably holds committed rows from other runs, so an unfiltered
       empty table is not an honest fixture here).
    4. `--since` window: rows older than the window are excluded.
    5. Mutation rationale (survived-kill):
       - content sensitivity: rewriting one entry's subject byte flips
         the bundle root;
       - guard removal: without the empty-window guard the module would
         return an empty-success bundle; the court asserts the typed
         error, killing that mutant.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.{ActuationReceipt, AuthorityLedgerExport, AuditLogEntry}
  alias Xaas.Marketplace.Provider

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp unique_suffix, do: System.unique_integer([:positive])

  defp create_audit_row!(attrs \\ %{}) do
    Ash.create!(
      AuditLogEntry,
      Map.merge(
        %{
          action: "governance.approval_dr_failover.approve",
          resource_type: "ApprovalDrFailover",
          resource_id: "res-w603-#{unique_suffix()}",
          org_id: "org-w603",
          actor_id: "operator-w603",
          actor_description: "W603 court operator",
          occurred_at: DateTime.utc_now(),
          metadata: %{"court" => "w603"}
        },
        attrs
      ),
      action: :create,
      authorize?: false
    )
  end

  # Real intent + receipt through the actuation kernel (the same admitted
  # causal-certificate idiom causal_admission_test.exs qualifies), because
  # ActuationReceipt :prepare validates the belongs_to intent exists.
  defp create_receipt_row! do
    provider = Xaas.Generator.create_provider!(%{name: "W603 Provider", org_id: "org-w603"})
    key = "w603-export-#{unique_suffix()}"

    {:ok, result} =
      Xaas.Actuation.run(
        Provider,
        :actuate_status,
        %{status: :active},
        subject_id: provider.id,
        idempotency_key: key,
        authorize?: false,
        authority: %{
          kind: "test_authority",
          causal: %{
            required: true,
            status: :admitted,
            strategy: :backdoor,
            verifier: "kgc-causal-verifier:v1",
            dag_proof_hash: "sha256:dag-proof-fixture",
            assumptions_hash: "sha256:assumptions-fixture",
            placebo_result_hash: "sha256:placebo-fixture",
            falsifier:
              "reject if the admitted adjustment set no longer d-separates treatment and outcome"
          }
        }
      )

    result.receipt
  end

  # A genuinely empty selection window: the shared test DB durably holds
  # committed rows from other runs, so the honest empty-ledger fixture is
  # a future `since` (zero entries in window), not an empty table.
  @empty_since ~U[2999-01-01 00:00:00Z]

  test "bundle bytes are deterministic across two independent runs" do
    create_audit_row!()
    create_receipt_row!()

    {:ok, first} = AuthorityLedgerExport.bundle([])
    {:ok, second} = AuthorityLedgerExport.bundle([])

    assert first.canonical_json == second.canonical_json
    assert first.merkle_root == second.merkle_root
    assert first.canonical_json != ""
  end

  test "bundle carries the refusal vocabulary, both entry sources, and the disclosed hash algorithm" do
    create_audit_row!()
    create_receipt_row!()

    {:ok, %{bundle: bundle}} = AuthorityLedgerExport.bundle([])

    assert bundle["hash_algorithm"] == "sha256"
    assert bundle["ledger_version"] == 1
    assert bundle["since"] == nil

    variants = Enum.map(bundle["refusal_variants"], & &1["variant"])
    assert length(variants) >= 1
    assert Enum.all?(variants, &is_binary/1)
    assert Enum.sort(variants) == Enum.uniq(Enum.sort(variants))
    assert length(variants) == length(Xaas.Semantics.AiroRiskMapping.variants())

    sources =
      bundle["entries"]
      |> Enum.map(& &1["source"])
      |> Enum.uniq()
      |> Enum.sort()

    assert sources == ["actuation_receipt", "audit_log_entry"]
  end

  test "root recomputes from the emitted bundle" do
    create_audit_row!()
    create_receipt_row!()

    {:ok, %{bundle: bundle, merkle_root: root}} = AuthorityLedgerExport.bundle([])

    assert {:ok, ^root} = AuthorityLedgerExport.recompute_root(bundle)
  end

  test "root is content-sensitive: rewriting one entry's subject byte flips the root" do
    create_audit_row!()
    create_receipt_row!()

    {:ok, %{bundle: bundle, merkle_root: root}} = AuthorityLedgerExport.bundle([])

    mutated =
      Map.update!(bundle, "entries", fn [entry | rest] ->
        entry
        |> Map.update!("subject", &Map.put(&1, "resource_id", "tampered-w603"))
        |> then(&[&1 | rest])
      end)

    assert {:ok, mutated_root} = AuthorityLedgerExport.recompute_root(mutated)
    assert mutated_root != root
  end

  test "--since window excludes older rows" do
    old =
      create_audit_row!(%{
        action: "old.action",
        resource_id: "old-#{unique_suffix()}",
        occurred_at: ~U[2020-01-01 00:00:00Z]
      })

    create_audit_row!()

    cutoff = ~U[2025-01-01 00:00:00Z]
    {:ok, %{bundle: bundle}} = AuthorityLedgerExport.bundle(since: cutoff)

    ids = Enum.map(bundle["entries"], & &1["id"])
    assert old.id not in ids
    assert bundle["since"] == DateTime.to_iso8601(cutoff)
    assert length(ids) >= 1
  end

  test "empty selection window is a typed error, not an empty-success bundle (module surface)" do
    assert {:error, {:empty_ledger, detail}} = AuthorityLedgerExport.bundle(since: @empty_since)
    assert detail.entries == 0
    assert detail.refusal_variants >= 1
    assert detail.since == @empty_since
  end

  test "empty window raises the typed REFUSED via a real mix task run" do
    Mix.Task.run("app.start")

    assert_raise Mix.Error, ~r/REFUSED\(empty_authority_ledger/, fn ->
      Mix.Tasks.Xaas.ExportAuthorityLedger.run(["--since", "2999-01-01T00:00:00Z"])
    end
  end

  test "mix task writes deterministic bytes to --out (x2 fresh)" do
    create_audit_row!()
    create_receipt_row!()

    n = unique_suffix()
    path1 = Path.join(System.tmp_dir!(), "w603-bundle-1-#{n}.json")
    path2 = Path.join(System.tmp_dir!(), "w603-bundle-2-#{n}.json")

    on_exit(fn ->
      File.rm(path1)
      File.rm(path2)
    end)

    Mix.Tasks.Xaas.ExportAuthorityLedger.run(["--out", path1])
    Mix.Tasks.Xaas.ExportAuthorityLedger.run(["--out", path2])

    bytes1 = File.read!(path1)
    bytes2 = File.read!(path2)
    assert bytes1 == bytes2 and bytes1 != ""

    decoded = Jason.decode!(bytes1)
    assert {:ok, root} = AuthorityLedgerExport.recompute_root(decoded)
    assert root == decoded["merkle_root"]
  end

  test "invalid --since is a typed refusal, not a crash" do
    Mix.Task.run("app.start")

    assert_raise Mix.Error, ~r/REFUSED\(invalid_since/, fn ->
      Mix.Tasks.Xaas.ExportAuthorityLedger.run(["--since", "not-a-timestamp"])
    end
  end
end
