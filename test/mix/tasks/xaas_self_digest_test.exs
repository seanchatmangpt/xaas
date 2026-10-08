defmodule Mix.Tasks.Xaas.SelfDigestTest do
  @moduledoc """
  Chicago qualification of `mix xaas.self_digest`: the real task against
  a real telemetry fixture and sandboxed Postgres. Success prints the JSON
  receipt; a refusal raises (non-zero exit).
  """

  use Xaas.DataCase, async: false

  import ExUnit.CaptureIO

  require Ash.Query

  alias Xaas.Ultracode.CapitalCensus.WorkOrder

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    tmp = Path.join(System.tmp_dir!(), "self-digest-task-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)
    %{tmp: tmp}
  end

  test "prints the JSON receipt and admits the recurring self-work order", %{tmp: tmp} do
    path = Path.join(tmp, "loop.ndjson")
    now = DateTime.utc_now()

    File.write!(
      path,
      for i <- 1..3 do
        Jason.encode!(%{
          "ts" => DateTime.add(now, -i * 60, :second) |> DateTime.to_iso8601(),
          # Literal atom reference: guarantees :worker_unclosed exists in the
          # VM before the task's String.to_existing_atom/1 sees the line,
          # independent of whether the FrontierOutcome type module has loaded.
          "outcome" => Atom.to_string(:worker_unclosed),
          "step" => "dispatch",
          "residual_shape" => "gate_without_firing"
        }) <> "\n"
      end
    )

    out =
      capture_io(fn ->
        Mix.Tasks.Xaas.SelfDigest.run([
          "--telemetry",
          path,
          "--out-dir",
          Path.join(tmp, "out"),
          "--window",
          "60"
        ])
      end)

    summary = Jason.decode!(out)
    assert summary["subject"] == "ultracode-self-digest"
    assert summary["frontier_episodes"] == 3
    assert [%{"created" => true}] = summary["created_work_orders"]

    # Scoped to this suite's own subject (W984ep flake-class fix): the shared
    # xaas_test work_orders table can carry committed foreign rows, so an
    # unscoped read is only stable on a quiet DB.
    assert [%{classification: :verification, subject: "ultracode-self-digest"}] =
             WorkOrder
             |> Ash.Query.filter(subject == "ultracode-self-digest")
             |> Ash.read!(authorize?: false)
  end

  test "--no-admit reports without persisting", %{tmp: tmp} do
    path = Path.join(tmp, "loop.ndjson")

    File.write!(
      path,
      for i <- 1..3 do
        Jason.encode!(%{
          "ts" => DateTime.add(DateTime.utc_now(), -i * 60, :second) |> DateTime.to_iso8601(),
          "outcome" => Atom.to_string(:blocked),
          "step" => "dispatch",
          "residual_shape" => "generator_unmanufactured"
        }) <> "\n"
      end
    )

    out =
      capture_io(fn ->
        Mix.Tasks.Xaas.SelfDigest.run(["--telemetry", path, "--out-dir", tmp, "--no-admit"])
      end)

    assert [_ticket] = Jason.decode!(out)["admitted_work_orders"]

    # W984ep flake-class fix: scope to this suite's subject instead of
    # asserting global table emptiness on the shared xaas_test DB.
    assert WorkOrder
           |> Ash.Query.filter(subject == "ultracode-self-digest")
           |> Ash.read!(authorize?: false) == []
  end

  test "a refusal raises (non-zero exit)", %{tmp: tmp} do
    capture_io(:stderr, fn ->
      assert_raise Mix.Error, ~r/xaas.self_digest refused/, fn ->
        Mix.Tasks.Xaas.SelfDigest.run(["--telemetry", Path.join(tmp, "absent.ndjson")])
      end
    end)
  end
end
