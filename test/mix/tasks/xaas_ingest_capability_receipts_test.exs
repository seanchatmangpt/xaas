defmodule Mix.Tasks.Xaas.IngestCapabilityReceiptsTest do
  @moduledoc """
  Real end-to-end test: writes a real temp receipt.jsonl file, shells out to
  a real `mix xaas.ingest_capability_receipts <path>` subprocess (real
  System.cmd/3, real DB env vars), then asserts the real rows now exist in
  Postgres via a real Ash.read!.

  This test does NOT use the sandbox (the ingest runs in a separate OS
  process/BEAM VM via System.cmd, so a sandbox checkout in this test process
  would not apply to it); instead it uses distinctive capability names and
  cleans up the rows it creates afterward.
  """
  use ExUnit.Case, async: false

  alias Xaas.Operations.CapabilityLivenessReceipt

  @capabilities [
    "weaver.e2e.ingest.alpha",
    "weaver.e2e.ingest.beta",
    "weaver.e2e.ingest.gamma"
  ]

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto)

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto)

      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability in @capabilities))
      |> Enum.each(&Ash.destroy!(&1, authorize?: false))

      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  test "mix xaas.ingest_capability_receipts ingests a real receipt.jsonl into real Postgres" do
    tmp_dir = Path.join(System.tmp_dir!(), "xaas_ingest_e2e_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    receipt_path = Path.join(tmp_dir, "receipt.jsonl")

    rows = [
      %{
        "capability" => "weaver.e2e.ingest.alpha",
        "authority" => "otel-weaver-v2",
        "status" => "ALIVE",
        "executed" => true,
        "exit_code" => 0,
        "subject" => "e2e-commit-alpha",
        "detail" => "real e2e row alpha"
      },
      %{
        "capability" => "weaver.e2e.ingest.beta",
        "authority" => "otel-weaver-v2",
        "status" => "PARTIAL",
        "executed" => true,
        "exit_code" => 1,
        "subject" => "e2e-commit-beta",
        "detail" => "real e2e row beta"
      },
      %{
        "capability" => "weaver.e2e.ingest.gamma",
        "authority" => "otel-weaver-v2",
        "status" => "BLOCKED",
        "executed" => false,
        "exit_code" => 2,
        "subject" => "e2e-commit-gamma",
        "detail" => "real e2e row gamma"
      }
    ]

    File.write!(
      receipt_path,
      Enum.map_join(rows, "\n", &Jason.encode!/1) <> "\n"
    )

    env = [
      {"DEV_DB_USERNAME", System.get_env("DEV_DB_USERNAME", "postgres")},
      {"DEV_DB_PASSWORD", System.get_env("DEV_DB_PASSWORD", "postgres")},
      {"DEV_DB_HOSTNAME", System.get_env("DEV_DB_HOSTNAME", "localhost")},
      {"DEV_DB_PORT", System.get_env("DEV_DB_PORT", "5432")},
      {"MIX_ENV", "test"}
    ]

    {output, exit_status} =
      System.cmd("mix", ["xaas.ingest_capability_receipts", receipt_path],
        cd: File.cwd!(),
        env: env,
        stderr_to_stdout: true
      )

    assert exit_status == 0, "mix xaas.ingest_capability_receipts failed:\n#{output}"
    assert output =~ "Ingested 3/3 real capability-liveness rows"

    persisted =
      CapabilityLivenessReceipt
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.capability in @capabilities))
      |> Enum.sort_by(& &1.capability)

    assert length(persisted) == 3

    [alpha, beta, gamma] = persisted

    assert alpha.capability == "weaver.e2e.ingest.alpha"
    assert alpha.status == "ALIVE"
    assert alpha.exit_code == 0
    assert alpha.subject == "e2e-commit-alpha"

    assert beta.capability == "weaver.e2e.ingest.beta"
    assert beta.status == "PARTIAL"
    assert beta.exit_code == 1

    assert gamma.capability == "weaver.e2e.ingest.gamma"
    assert gamma.status == "BLOCKED"
    assert gamma.executed == false
    assert gamma.exit_code == 2

    File.rm_rf!(tmp_dir)
  end
end
