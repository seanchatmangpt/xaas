defmodule Xaas.Ultracode.LegacyRecoverySensingTest do
  use ExUnit.Case, async: true

  alias Xaas.Ultracode.Sensing

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "xaas-legacy-sensing-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(root)
    System.cmd("git", ["init", "-q", root])
    File.write!(Path.join(root, "seed.txt"), "seed\n")
    System.cmd("git", ["-C", root, "add", "."])

    System.cmd("git", [
      "-C",
      root,
      "-c",
      "user.name=XaaS Test",
      "-c",
      "user.email=xaas-test@example.invalid",
      "commit",
      "-q",
      "-m",
      "seed"
    ])

    on_exit(fn -> File.rm_rf(root) end)
    %{root: root}
  end

  test "legacy_recovery is a first-class deterministic sensing profile", %{root: root} do
    digest = String.duplicate("e", 64)

    report = %{
      "schema" => "beam4pm-legacy-equivalence/1",
      "subject" => "orders.cancel",
      "legacy_identity" => "legacy@abc",
      "candidate_identity" => "candidate@def",
      "equivalent" => false,
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
    System.cmd("git", ["-C", root, "add", "court.json"])

    System.cmd("git", [
      "-C",
      root,
      "-c",
      "user.name=XaaS Test",
      "-c",
      "user.email=xaas-test@example.invalid",
      "commit",
      "-q",
      "-m",
      "court"
    ])

    profile = %{
      "type" => "legacy_recovery",
      "file" => "court.json",
      "allowed_paths" => ["lib/**", "test/**"],
      "max_items" => 10
    }

    assert {:ok, first} = Sensing.derive(profile, root)
    assert {:ok, second} = Sensing.derive(profile, root)

    assert first == second
    assert first["schemaVersion"] == "xaas-sensing/1"
    assert first["profile"] == "legacy_recovery"
    assert [%{"id" => "legacy-0-eeeeeeeeeeee"} = item] = first["items"]
    assert item["source"]["court_receipt"] == digest
    assert item["allowed_paths"] == ["lib/**", "test/**"]
  end
end
