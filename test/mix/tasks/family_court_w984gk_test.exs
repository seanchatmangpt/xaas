defmodule Mix.Tasks.FamilyCourtW984gkTest do
  @moduledoc """
  W984gk unclaimed-family court over `lib/mix/tasks/` tasks with no direct
  test coverage. Chicago style: real Mix task modules invoked in-process,
  real filesystem side effects asserted, real typed failures on bad input.
  Zero mocks.

  Mutation rationale per test (what change in the task source would flip
  this test to red): stated in each test's comment.

  Skipped-by-design (not courtable without touching lanes' in-flight files
  or destructive global state):

    * `xaas.export_refusal_ledger` — writes the sibling-modified tracked
      artifact `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json`
      (lib/xaas/operations/refusal_ledger_export.ex is lane-modified).
    * `xaas.autonomy.audit`'s violation leg and `xaas.autonomy.audit`
      bad-opts leg — `System.halt(1)` would kill the ExUnit VM.
    * `xaas.autonomic.*`, `xaas.autonomy.stress`, `xaas.ultracode.stop`,
      `xaas.ultracode.drain` — mutate real fleet/process state
      (fabric redeploy, tick loops, run lifecycle writes).
  """

  use Xaas.DataCase, async: false

  import ExUnit.CaptureIO

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)

    tmp = Path.join(System.tmp_dir!(), "w984gk-#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp)
    on_exit(fn -> File.rm_rf!(tmp) end)

    %{tmp: tmp}
  end

  # ---------------------------------------------------------------------------
  # xaas.doctor — uncovered, pure-filesystem census task
  # ---------------------------------------------------------------------------

  @tag :w984gk
  # The lane_leases census walk is capped per lane (200 files — W984il) — the unbounded
  # version exceeded 600s against 100+ orphaned _build-lane* roots (W984gk fix).
  @tag timeout: 120_000
  test "xaas.doctor emits parseable JSON census with all six checks; mock_gate passes" do
    out =
      capture_io(fn ->
        Mix.Tasks.Xaas.Doctor.run([])
      end)

    # Mutation rationale: removing a check from run/1's checks list, or
    # renaming any check's `name` atom string, flips this red.
    json =
      out
      |> String.split("\n")
      |> Enum.reject(&(&1 == ""))
      |> List.last()
      |> Jason.decode!()

    names = Enum.map(json["checks"], & &1["name"])

    assert names == [
             "mock_gate",
             "eu_ai_act_compile",
             "lane_leases",
             "eu_ai_act_file_count",
             "eu_ai_act_case_count",
             "receipt_census"
           ]

    assert Enum.all?(json["checks"], &(&1["status"] in ["pass", "fail", "warn"]))

    # The doctor IS the mock gate — on this tree it must pass.
    assert %{"status" => "pass"} = Enum.find(json["checks"], &(&1["name"] == "mock_gate"))
  end

  # ---------------------------------------------------------------------------
  # xaas.wd.fa_eval — uncovered, file-writing task
  # ---------------------------------------------------------------------------

  @tag :w984gk
  test "xaas.wd.fa_eval writes a real JSON evaluation report to the given path", %{tmp: tmp} do
    path = Path.join(tmp, "fa-eval.json")

    out =
      capture_io(fn ->
        Mix.Tasks.Xaas.Wd.FaEval.run([path])
      end)

    # Mutation rationale: a change to Evaluation.offline_report/0's shape or
    # the output filename contract flips the decode/exists assertions red.
    assert File.exists?(path)
    assert String.contains?(out, "WD_FA_EVALUATION=#{path}")
    report = Jason.decode!(File.read!(path))
    assert is_map(report) and map_size(report) > 0
  end

  # ---------------------------------------------------------------------------
  # xaas.wd.stogaf_receipt — uncovered, deterministic receipt writer
  # ---------------------------------------------------------------------------

  @tag :w984gk
  test "xaas.wd.stogaf_receipt writes UNKNOWN_SUBJECT_SHA when env unset", %{tmp: tmp} do
    path = Path.join(tmp, "stogaf-unknown.json")

    System.delete_env("STOGAF_SUBJECT_SHA")
    # Mutation rationale: dropping the env fallback to UNKNOWN_SUBJECT_SHA
    # (or not writing the sha into the receipt) flips this red.
    out =
      capture_io(fn ->
        Mix.Tasks.Xaas.Wd.StogafReceipt.run([path])
      end)

    assert String.contains?(out, "STOGAF_RECEIPT=#{path}")
    receipt = Jason.decode!(File.read!(path))
    assert receipt |> Jason.encode!() |> String.contains?("UNKNOWN_SUBJECT_SHA")
  end

  @tag :w984gk
  test "xaas.wd.stogaf_receipt falls back gracefully on an EMPTY env var (w984gk defect fix)", %{
    tmp: tmp
  } do
    path = Path.join(tmp, "stogaf-empty.json")

    # W984gk court finding: Receipt.build/1 requires a non-empty binary;
    # before the fix, STOGAF_SUBJECT_SHA="" crashed the task with
    # FunctionClauseError instead of using the UNKNOWN_SUBJECT_SHA fallback.
    System.put_env("STOGAF_SUBJECT_SHA", "")

    try do
      out =
        capture_io(fn ->
          Mix.Tasks.Xaas.Wd.StogafReceipt.run([path])
        end)

      assert String.contains?(out, "STOGAF_RECEIPT=#{path}")
      assert File.read!(path) |> String.contains?("UNKNOWN_SUBJECT_SHA")
    after
      System.delete_env("STOGAF_SUBJECT_SHA")
    end
  end

  @tag :w984gk
  test "xaas.wd.stogaf_receipt binds the receipt to STOGAF_SUBJECT_SHA when set", %{tmp: tmp} do
    path = Path.join(tmp, "stogaf-bound.json")
    sha = "deadbeef" <> String.duplicate("0", 56)

    System.put_env("STOGAF_SUBJECT_SHA", sha)
    # Mutation rationale: breaking Receipt.build/1's sha binding (constant
    # sha, dropped field, wrong value) flips this red.
    try do
      capture_io(fn ->
        Mix.Tasks.Xaas.Wd.StogafReceipt.run([path])
      end)

      assert File.exists?(path)
      assert File.read!(path) |> String.contains?(sha)
    after
      System.delete_env("STOGAF_SUBJECT_SHA")
    end
  end

  # ---------------------------------------------------------------------------
  # xaas.receipts — uncovered operator read path (real Ash read, sandboxed DB)
  # ---------------------------------------------------------------------------

  @tag :w984gk
  test "xaas.receipts reports no receipts for an epoch with none" do
    epoch_id = Ash.UUID.generate()

    out =
      capture_io(fn ->
        Mix.Tasks.Xaas.Receipts.run([epoch_id])
      end)

    # Mutation rationale: changing the empty-result message or the
    # `:for_epoch` read path selection flips this red.
    assert String.contains?(out, "No receipts found for epoch #{epoch_id}.")
  end

  @tag :w984gk
  test "xaas.receipts refuses a non-UUID epoch id via the typed error path" do
    # Mutation rationale: silently accepting a non-UUID (or crashing instead
    # of the typed {:error, reason} shell error) flips this red.
    out =
      capture_io(:stderr, fn ->
        Mix.Tasks.Xaas.Receipts.run(["not-a-uuid"])
      end)

    assert String.contains?(out, "Could not read receipts")
  end

  # ---------------------------------------------------------------------------
  # xaas.internal_api_token — uncovered; usage refusal + list on empty sandbox
  # ---------------------------------------------------------------------------

  @tag :w984gk
  test "xaas.internal_api_token raises typed usage error with no subcommand" do
    # Mutation rationale: relaxing the usage Mix.raise (e.g. defaulting to a
    # subcommand) flips this red.
    assert_raise Mix.Error, ~r/usage:/, fn ->
      Mix.Tasks.Xaas.InternalApiToken.run([])
    end
  end

  @tag :w984gk
  test "xaas.internal_api_token list reports the empty ledger" do
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :auto)

    out =
      try do
        capture_io(fn ->
          Mix.Tasks.Xaas.InternalApiToken.run(["list"])
        end)
      after
        Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
      end

    # Mutation rationale: changing the empty-ledger message or the
    # authorize?: false read path flips this red.
    assert String.contains?(out, "No InternalApiToken rows exist yet.")
  end

  # ---------------------------------------------------------------------------
  # xaas.autonomy.audit — uncovered standing-window tripwire (alive leg only;
  # System.halt legs unrunnable in-process)
  # ---------------------------------------------------------------------------

  @tag :w984gk
  test "xaas.autonomy.audit reports ALIVE over an empty sandbox window" do
    out =
      capture_io(fn ->
        Mix.Tasks.Xaas.Autonomy.Audit.run(["--window-minutes", "5"])
      end)

    # Mutation rationale: a standing computation change (e.g. alive only when
    # epochs_audited > 0, or inverted UAR/DCR polarity) flips this red.
    assert String.contains?(out, "standing: ALIVE (UAR=0, DCR=0)")
  end

  # ---------------------------------------------------------------------------
  # xaas.ultracode.status — uncovered; typed failure with no campaign rows
  # ---------------------------------------------------------------------------

  @tag :w984gk
  test "xaas.ultracode.status raises a typed failure when no campaign exists" do
    # Mutation rationale: swallowing the {:error, _} from Campaign.status(nil)
    # (printing instead of Mix.raise) flips this red.
    assert_raise Mix.Error, ~r/campaign status failed/, fn ->
      Mix.Tasks.Xaas.Ultracode.Status.run([])
    end
  end
end
