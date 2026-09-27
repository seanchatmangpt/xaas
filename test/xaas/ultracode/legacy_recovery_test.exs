defmodule Xaas.Ultracode.LegacyRecoveryTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.LegacyRecovery

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "xaas-legacy-recovery-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf(root) end)
    %{root: root}
  end

  test "counterexamples become deterministic repair work", %{root: root} do
    digest = String.duplicate("a", 64)

    report = %{
      "schema" => "beam4pm-legacy-equivalence/1",
      "subject" => "orders.cancel",
      "legacy_identity" => "legacy@abc",
      "candidate_identity" => "candidate@def",
      "equivalent" => false,
      "verdict" => "COUNTEREXAMPLE",
      "counterexamples" => [
        %{
          "index" => 0,
          "legacy" => %{"outcome" => "cancelled"},
          "candidate" => %{"outcome" => "pending"}
        }
      ],
      "receipt_digest" => digest,
      "authority_ceiling" => "OBSERVE"
    }

    File.write!(Path.join(root, "court.json"), Jason.encode!(report))

    assert {:ok, [item]} = LegacyRecovery.items(root, "court.json", ["lib/**", "test/**"])
    assert item["id"] == "legacy-0-aaaaaaaaaaaa"
    assert item["allowed_paths"] == ["lib/**", "test/**"]
    assert item["min_new_tests"] == 1
    assert item["source"]["subject"] == "orders.cancel"
    assert item["source"]["court_receipt"] == digest
    assert item["goal"] =~ "rerun the beam4pm equivalence court"

    assert {:ok, [same]} = LegacyRecovery.items(root, "court.json", ["lib/**", "test/**"])
    assert same == item
  end

  test "equivalent reports produce no repair work", %{root: root} do
    report = %{
      "schema" => "beam4pm-legacy-equivalence/1",
      "subject" => "orders.cancel",
      "equivalent" => true,
      "counterexamples" => [],
      "receipt_digest" => String.duplicate("b", 64),
      "authority_ceiling" => "OBSERVE"
    }

    File.write!(Path.join(root, "court.json"), Jason.encode!(report))
    assert {:ok, []} = LegacyRecovery.items(root, "court.json", ["*"])
  end

  test "a contradictory or authority-escalated report is refused", %{root: root} do
    report = %{
      "schema" => "beam4pm-legacy-equivalence/1",
      "subject" => "orders.cancel",
      "equivalent" => true,
      "counterexamples" => [%{"index" => 0}],
      "receipt_digest" => String.duplicate("c", 64),
      "authority_ceiling" => "OBSERVE"
    }

    File.write!(Path.join(root, "court.json"), Jason.encode!(report))

    assert {:error, :legacy_court_contradictory_equivalence} =
             LegacyRecovery.items(root, "court.json", ["*"])

    File.write!(
      Path.join(root, "court.json"),
      Jason.encode!(%{report | "authority_ceiling" => "DO"})
    )
    assert {:error, :malformed_legacy_court_report} =
             LegacyRecovery.items(root, "court.json", ["*"])
  end
end
