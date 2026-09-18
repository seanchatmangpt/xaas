defmodule Mix.Tasks.Xaas.Autonomic.Controls do
  @shortdoc "Live negative controls: the fabric court must reject every crafted bad candidate"

  @moduledoc """
  Falsifiers for the autonomic definition of done, run against the LIVE fabric.

  Each control provisions a real worktree, seeds a Run/Epoch/ticket exactly as
  the autonomic loop does, claims the epoch over the real HTTP MCP surface,
  builds one crafted candidate, and closes it over HTTP claiming `alive`. The
  sealed receipt is then read back from the database and compared with the
  outcome and gate the control expects. A control that is not rejected for the
  expected reason is a failure of the definition of done itself, and the task
  exits non-zero.

      INTERNAL_API_TOKEN=... mix xaas.autonomic.controls

  Options: `--repo ALIAS` (default `aps`), `--endpoint URL`
  (default `http://localhost:4000/internal-api/execution/mcp`). Worktrees and
  the report are left under the operator worktree/ticket roots for inspection.
  Requires a running server with the `aps-dod` suite registered, and the same
  database.
  """

  use Mix.Task

  alias Xaas.Ultracode.{Autonomic, Epoch, Receipt, Worktrees}

  @good ~S'''
  import json
  import unittest
  from pathlib import Path

  import jsonschema

  SCHEMA = json.loads(
      (Path(__file__).resolve().parents[1] / "contracts" / "standing.schema.json").read_text()
  )
  VALID = ["ALIVE", "PARTIAL_ALIVE", "BLOCKED", "BUILD_BROKEN", "UNKNOWN", "UNSUPPORTED", "REFUSED"]


  class StandingContract(unittest.TestCase):
      def setUp(self):
          self.validator = jsonschema.Draft202012Validator(SCHEMA)

      def test_alive_is_accepted(self):
          self.assertTrue(self.validator.is_valid("ALIVE"))

      def test_every_named_standing_is_accepted(self):
          for value in VALID:
              self.assertTrue(self.validator.is_valid(value), value)

      def test_lowercase_is_rejected(self):
          self.assertFalse(self.validator.is_valid("alive"))

      def test_unnamed_standing_is_rejected(self):
          self.assertFalse(self.validator.is_valid("DONE"))

      def test_non_string_is_rejected(self):
          self.assertFalse(self.validator.is_valid(1))
  '''

  @vacuous ~S'''
  import unittest


  class StandingContract(unittest.TestCase):
      def test_alive(self):
          pass

      def test_blocked(self):
          pass

      def test_refused(self):
          pass

      def test_unknown(self):
          pass
  '''

  # Only negatives: never asserts that ALIVE is accepted, so the court's
  # "drop the ALIVE enum member" mutant survives.
  @non_killing ~S'''
  import json
  import unittest
  from pathlib import Path

  import jsonschema

  SCHEMA = json.loads(
      (Path(__file__).resolve().parents[1] / "contracts" / "standing.schema.json").read_text()
  )


  class StandingContract(unittest.TestCase):
      def setUp(self):
          self.validator = jsonschema.Draft202012Validator(SCHEMA)

      def test_lowercase_is_rejected(self):
          self.assertFalse(self.validator.is_valid("alive"))

      def test_unnamed_standing_is_rejected(self):
          self.assertFalse(self.validator.is_valid("DONE"))

      def test_non_string_is_rejected(self):
          self.assertFalse(self.validator.is_valid(1))

      def test_list_is_rejected(self):
          self.assertFalse(self.validator.is_valid(["ALIVE"]))
  '''

  @test_file "tests/test_contract_standing.py"

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args, strict: [repo: :string, endpoint: :string])

    Mix.Task.run("app.start")
    {:ok, _} = Application.ensure_all_started(:inets)

    token = System.get_env("INTERNAL_API_TOKEN") || Mix.raise("INTERNAL_API_TOKEN is required")
    endpoint = Keyword.get(opts, :endpoint, "http://localhost:4000/internal-api/execution/mcp")
    provider = "zcode-controls"

    ctx =
      Autonomic.new_ctx(
        repo: Keyword.get(opts, :repo, "aps"),
        provider: provider,
        capacity: 1,
        only: ["contract-standing"]
      )

    File.mkdir_p!(ctx.out_dir)
    {:ok, [item]} = Autonomic.sense(ctx)
    http = %{endpoint: endpoint, token: token}

    results = Enum.map(controls(), &run_control(&1, item, ctx, http))

    for r <- results do
      mark = if r.pass, do: "PASS", else: "FAIL"

      Mix.shell().info(
        "#{mark}  #{String.pad_trailing(r.id, 18)} expected #{r.expect}  observed outcome=#{r.outcome} " <>
          "verifier=#{r.verifier_status} gates=#{inspect(r.failed_gates)} #{r.note}"
      )
    end

    path = Path.join(ctx.out_dir, "controls.json")
    File.write!(path, Jason.encode!(%{base_sha: ctx.base_sha, controls: results}, pretty: true))
    Mix.shell().info("controls report: #{path}")

    if Enum.any?(results, &(not &1.pass)) do
      Mix.raise(
        "negative controls FAILED: the definition of done accepted or mis-typed a bad candidate"
      )
    end
  end

  # id, what the worker builds, whether it commits, the head it claims, and the
  # sealed result the fabric MUST produce.
  defp controls do
    [
      %{
        id: "positive",
        files: %{@test_file => @good},
        expect: "alive / pass",
        outcome: :alive,
        gate: nil
      },
      %{
        id: "vacuous",
        files: %{@test_file => @vacuous},
        expect: "build_broken / CHI-ASSERT",
        outcome: :build_broken,
        gate: "CHI-ASSERT"
      },
      %{
        id: "mock-import",
        files: %{@test_file => @good <> "\nfrom unittest import mock\n"},
        expect: "build_broken / CHI-MOCK",
        outcome: :build_broken,
        gate: "CHI-MOCK"
      },
      %{
        id: "protected-edit",
        files: %{@test_file => @good, "contracts/standing.schema.json" => :append_space},
        expect: "build_broken / CHI-SCOPE",
        outcome: :build_broken,
        gate: "CHI-SCOPE"
      },
      %{
        id: "out-of-scope",
        files: %{@test_file => @good, "tests/extra_helper.py" => "VALUE = 1\n"},
        expect: "build_broken / CHI-SCOPE",
        outcome: :build_broken,
        gate: "CHI-SCOPE"
      },
      %{
        id: "non-killing",
        files: %{@test_file => @non_killing},
        expect: "build_broken / CHI-MUTATION",
        outcome: :build_broken,
        gate: "CHI-MUTATION"
      },
      %{
        id: "uncommitted",
        files: %{@test_file => @good},
        commit: false,
        expect: "build_broken / uncommitted changes",
        outcome: :build_broken,
        reason: "worker_left_uncommitted_changes"
      },
      %{
        id: "wrong-head",
        files: %{@test_file => @good},
        claim_head: String.duplicate("b", 40),
        expect: "build_broken / head mismatch",
        outcome: :build_broken,
        head_verified: false
      }
    ]
  end

  defp run_control(control, item, ctx, http) do
    name = "aps-control-#{control.id}-#{ctx.nonce}"
    {:ok, worktree} = Worktrees.provision(ctx.repo, ctx.base_sha, name)
    {_run, epoch} = Autonomic.create_run_and_epoch(item, worktree, 1, [], ctx)

    claim =
      mcp(http, "claim_next", %{
        provider: ctx.provider,
        provider_worker_id: "control-#{control.id}",
        epoch_id: epoch.id
      })

    build_candidate(worktree, control)
    head = Map.get(control, :claim_head) || git!(worktree, ["rev-parse", "HEAD"])

    mcp(http, "close_candidate", %{
      lease_token: claim["lease_token"],
      final_head: head,
      outcome: "alive",
      evidence: %{"note" => "control #{control.id} claims ALIVE"}
    })

    observed(control, epoch)
  end

  defp build_candidate(worktree, control) do
    for {path, content} <- control.files do
      full = Path.join(worktree, path)
      File.mkdir_p!(Path.dirname(full))

      case content do
        :append_space -> File.write!(full, File.read!(full) <> " ")
        text -> File.write!(full, text)
      end
    end

    if Map.get(control, :commit, true) do
      env = [
        {"GIT_AUTHOR_NAME", "control"},
        {"GIT_AUTHOR_EMAIL", "c@c"},
        {"GIT_COMMITTER_NAME", "control"},
        {"GIT_COMMITTER_EMAIL", "c@c"}
      ]

      {_, 0} = System.cmd("git", ["-C", worktree, "add", "-A"], env: env, stderr_to_stdout: true)

      {_, 0} =
        System.cmd("git", ["-C", worktree, "commit", "-q", "-m", "control candidate"],
          env: env,
          stderr_to_stdout: true
        )
    end
  end

  defp observed(control, %Epoch{id: id}) do
    receipt =
      Receipt
      |> Ash.Query.for_read(:for_epoch, %{epoch_id: id})
      |> Ash.read!(authorize?: false)
      |> Enum.find(&Map.has_key?(&1.evidence, "head_verified"))

    fv = (receipt && receipt.evidence["fabric_verifier"]) || %{}
    failures = get_in(fv, ["court_receipt", "observation", "failures"]) || []
    failed_gates = Enum.map(failures, & &1["id"])
    outcome = receipt && receipt.outcome

    checks = [
      outcome == control.outcome,
      is_nil(control[:gate]) or control.gate in failed_gates,
      is_nil(control[:reason]) or String.contains?(to_string(fv["reason"]), control.reason),
      is_nil(control[:head_verified]) or
        (receipt && receipt.evidence["head_verified"]) == control.head_verified,
      control.outcome != :alive or
        (fv["status"] == "pass" and get_in(fv, ["court_receipt", "standing"]) == "ALIVE")
    ]

    %{
      id: control.id,
      expect: control.expect,
      pass: receipt != nil and Enum.all?(checks),
      outcome: outcome,
      verifier_status: fv["status"],
      failed_gates: failed_gates,
      receipt_id: receipt && receipt.id,
      epoch_id: id,
      note: if(receipt, do: "", else: "NO CLOSING RECEIPT")
    }
  end

  defp mcp(http, tool, args) do
    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: %{name: tool, arguments: args}
      })

    {:ok, {{_, 200, _}, _headers, resp}} =
      :httpc.request(
        :post,
        {String.to_charlist(http.endpoint),
         [{~c"authorization", String.to_charlist("Bearer " <> http.token)}], ~c"application/json",
         body},
        [{:timeout, 300_000}],
        body_format: :binary
      )

    %{"result" => %{"content" => [%{"text" => text}]}} = Jason.decode!(resp)
    Jason.decode!(text)
  end

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end
end
