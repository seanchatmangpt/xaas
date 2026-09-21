defmodule Xaas.Ultracode.SemanticJiraE2ETest do
  @moduledoc """
  SJ-001: the committed end-to-end proof that one REAL Semantic Jira work
  order from docs/sjira/v26.9.21 flows admit -> materialize -> receipt ->
  replay through this repository's own surface.

  Chicago-style: every collaborator is real except the model. The graph side
  is the operator's ggen_igniter checkout (`GGEN_IGNITER_DIR`, default
  `~/ggen_igniter`): nested `mix run` OS processes (stdin /dev/null, output to
  a file, perl-alarm deadline, as `SemanticCrown` does; compiled into a private
  APFS clone of the graph checkout's `_build/test` so shared builds are never
  written) run `docs/sjira/v26.9.21/e2e_project.exs`, which executes the real
  `GgenIgniter.SemanticJira.admit_work_order/1` and projects the execution
  descriptor. The Xaas side is the real `mix xaas.semantic.materialize` /
  `mix xaas.semantic.receipt` tasks, real sandboxed Postgres, a real clone
  of this exact checkout, a real git worktree at the work order's base_sha,
  a real shell verifier suite and the real `Lease.claim_next`/`Lease.close`
  fabric court. The worker is a scripted protocol client; it stands in only
  for the model's judgment.

  Not tagged `:subprocess` on purpose: it pays three nested BEAM boots (admit +
  project, the emission-guard refusal, the negative control) and the work
  order's runnable check is the plain
  `mix test test/xaas/ultracode`, which must exercise this proof. Skips
  (never fails) when the ggen_igniter checkout is absent.

  Set `SJ001_EVIDENCE_DIR` to tap the sealed artifacts (admit verdict,
  descriptor, materialize output, receipt, replay, negative control) into a
  directory for the committed receipts; unset by default so ordinary runs
  never write into the repository.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, SemanticReceipt}

  @moduletag timeout: 1_200_000

  @project_root File.cwd!()
  @sjira_dir Path.join([@project_root, "docs", "sjira", "v26.9.21"])
  @order_path Path.join(@sjira_dir, "001-xaas-semantic-jira-e2e.md")
  @script Path.join(@sjira_dir, "e2e_project.exs")
  @ggen_dir System.get_env("GGEN_IGNITER_DIR") || "/Users/sac/ggen_igniter"
  @semantic_jira Path.join([@ggen_dir, "lib", "ggen_igniter", "semantic_jira.ex"])

  @moduletag skip:
               (cond do
                  not File.regular?(@semantic_jira) ->
                    "ggen_igniter checkout with SemanticJira missing at #{@ggen_dir}"

                  not File.regular?(@script) ->
                    "e2e projection script missing at #{@script}"

                  true ->
                    false
                end)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo, ownership_timeout: 1_200_000)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    original = %{
      repos: Application.get_env(:xaas, :ultracode_repos),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      tickets: Application.get_env(:xaas, :ultracode_ticket_dir)
    }

    # A real clone of THIS exact checkout, so Worktrees.provision can never
    # touch the operator's working tree, and the base_sha committed in the
    # work order is reachable exactly as admitted.
    base = mktmp("sj001")
    clone_graph_build(base)
    clone = Path.join(base, "xaas")
    {_, 0} = System.cmd("git", ["clone", "-q", @project_root, clone], stderr_to_stdout: true)

    Application.put_env(:xaas, :ultracode_repos, %{"sj001" => clone})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))
    Application.put_env(:xaas, :ultracode_verifier_suites, %{"sjira-e2e" => suite()})

    on_exit(fn ->
      restore_env(:ultracode_repos, original.repos)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_verifier_suites, original.suites)
      restore_env(:ultracode_ticket_dir, original.tickets)
    end)

    %{base: base, clone: clone}
  end

  test "SJ-001 flows admit -> materialize -> receipt -> replay; both falsifiers are refused",
       %{base: base} do
    order = front_matter()
    assert order["identity"] == "SJ-001"

    # exact-subject coherence: the admitted base is an ancestor of this head
    {_, 0} =
      System.cmd("git", ["merge-base", "--is-ancestor", order["base_sha"], "HEAD"],
        cd: @project_root,
        stderr_to_stdout: true
      )

    # -- graph side: one real OS-process admission and projection --------------
    wo = Path.join(base, "work-order.json")
    descriptor_path = Path.join(base, "descriptor.json")
    File.write!(wo, Jason.encode!(order))

    {0, admit} = project(wo, descriptor_path, [])

    assert %{
             "ok" => true,
             "identity" => "SJ-001",
             "work_order_digest" => digest,
             "definition_digest" => definition
           } = admit

    assert digest =~ ~r/\Asha256:[0-9a-f]{64}\z/
    assert definition =~ ~r/\Asha256:[0-9a-f]{64}\z/

    descriptor = descriptor_path |> File.read!() |> Jason.decode!()

    assert descriptor["graph_digest"] == digest
    assert descriptor["admission_digest"] == digest
    assert descriptor["base_sha"] == order["base_sha"]
    assert descriptor["repository_identity"] == order["repository"]
    assert descriptor["execution_repo_alias"] == "sj001"
    assert descriptor["bridge"]["identity"] == "SJ-001"
    assert descriptor["bridge"]["definition_digest"] == definition
    assert descriptor["bridge"]["source_snapshot_digest"] == digest
    assert descriptor["bridge"]["requires"]["courts"] == order["required_courts"]

    # -- materialize through the real mix task ----------------------------------
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    ticket = Path.join(base, "ticket.json")

    File.write!(
      ticket,
      Jason.encode!(%{"schemaVersion" => "sjira-ticket/1", "identity" => "SJ-001"})
    )

    Mix.Tasks.Xaas.Semantic.Materialize.run([
      "--descriptor",
      descriptor_path,
      "--ticket-file",
      ticket
    ])

    assert_received {:mix_shell, :info, [line]}

    assert %{"run_id" => run_id, "epoch_id" => epoch_id, "worktree" => worktree} =
             Jason.decode!(line)

    assert File.dir?(worktree)
    assert git!(worktree, ["rev-parse", "HEAD"]) == order["base_sha"]

    epoch = Ash.get!(Epoch, epoch_id, action: :read_unscoped, authorize?: false)
    assert epoch.state == :running

    # THE binding: the Run's exact subject is the admitted work-order snapshot
    assert epoch.exact_subject == "urn:semantic-jira:work-order:SJ-001@" <> digest

    ticket_dir = Application.fetch_env!(:xaas, :ultracode_ticket_dir)
    assert File.read!(Path.join(ticket_dir, "#{run_id}.json")) == File.read!(ticket)

    # -- the worker: scripted protocol client over the real lease ---------------
    {:ok, _claimed, token, _run} = Lease.claim_next("zcode", "sj001-worker", epoch_id: epoch_id)

    head = commit_candidate(worktree, true)

    {:ok, _epoch, _receipt} = Lease.close(token, head, :alive, %{"note" => "SJ-001 worker done"})

    # -- seal the receipt through the real mix task ------------------------------
    receipt_path = Path.join(base, "receipt.json")

    Mix.Tasks.Xaas.Semantic.Receipt.run(["--epoch", epoch_id, "--out", receipt_path])

    assert_received {:mix_shell, :info, [printed]}
    export = Jason.decode!(printed)
    assert export == receipt_path |> File.read!() |> Jason.decode!()

    assert export["outcome"] == "alive"
    assert export["final_head"] == head
    assert export["head_verified"] == true
    assert export["fabric_verifier"]["status"] == "pass"
    assert export["bridge"]["identity"] == "SJ-001"

    closing =
      Receipt
      |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
      |> Ash.read!(authorize?: false)
      |> Enum.find(&Map.has_key?(&1.evidence, "head_verified"))

    assert closing.outcome == :alive
    assert closing.evidence["head_verified"] == true

    # -- replay: the sealed digest reproduces from the file and from the database
    assert export["receipt_digest"] == SemanticReceipt.receipt_digest(export)

    replayed = receipt_path |> File.read!() |> Jason.decode!()
    file_replay = SemanticReceipt.receipt_digest(replayed)

    assert {:ok, again} = SemanticReceipt.export(epoch_id)
    assert file_replay == export["receipt_digest"]
    assert again["receipt_digest"] == export["receipt_digest"]

    # -- falsifier 1: a digest altered after admission is refused twice ----------
    # at the emitter: a fresh admission no longer matches the held digest
    {1, %{"ok" => false, "stage" => "emission_guard"}} =
      project(wo, Path.join(base, "descriptor-altered.json"), [
        {"EXPECTED_DIGEST", flip(digest)}
      ])

    refute File.exists?(Path.join(base, "descriptor-altered.json"))

    # at materialize: the descriptor's two digest copies disagree
    assert_raise Mix.Error, ~r/materialize refused.*admission_digest_mismatch/, fn ->
      altered = %{descriptor | "graph_digest" => flip(digest)}

      Mix.Tasks.Xaas.Semantic.Materialize.run([
        "--descriptor",
        spill(base, "descriptor-altered-2.json", altered)
      ])
    end

    assert_raise Mix.Error, ~r/materialize refused.*admission_digest_mismatch/, fn ->
      tampered = %{descriptor | "admission_digest" => flip(digest)}

      Mix.Tasks.Xaas.Semantic.Materialize.run([
        "--descriptor",
        spill(base, "descriptor-altered-3.json", tampered)
      ])
    end

    assert_raise Mix.Error, ~r/materialize refused.*invalid.*admission_digest/, fn ->
      malformed = %{descriptor | "admission_digest" => "sha256:not-hex"}

      Mix.Tasks.Xaas.Semantic.Materialize.run([
        "--descriptor",
        spill(base, "descriptor-altered-4.json", malformed)
      ])
    end

    # -- falsifier 2: a failing court seals build_broken, never alive ------------
    control_path = Path.join(base, "descriptor-control.json")
    {0, %{"ok" => true}} = project(wo, control_path, [{"CHECKPOINT_SUFFIX", ":control"}])

    Mix.Tasks.Xaas.Semantic.Materialize.run(["--descriptor", control_path])

    assert_received {:mix_shell, :info, [control_line]}

    assert %{"epoch_id" => control_epoch_id, "worktree" => control_worktree} =
             Jason.decode!(control_line)

    {:ok, _c, control_token, _} =
      Lease.claim_next("zcode", "sj001-control", epoch_id: control_epoch_id)

    # the control candidate omits the note: the fabric's `tests` court must fail
    control_head = commit_candidate(control_worktree, false)

    {:ok, _, _} =
      Lease.close(control_token, control_head, :alive, %{"note" => "control claims ALIVE"})

    assert {:ok, control_export} = SemanticReceipt.export(control_epoch_id)
    assert control_export["outcome"] == "build_broken"
    assert control_export["fabric_verifier"]["status"] == "fail"
    assert control_export["receipt_digest"] == SemanticReceipt.receipt_digest(control_export)

    tap_evidence(%{
      "admit" => admit,
      "descriptor" => descriptor,
      "materialize" => Jason.decode!(line),
      "receipt" => export,
      "replay" => %{
        "file_replay_digest" => file_replay,
        "db_reexport_digest" => again["receipt_digest"],
        "sealed_digest" => export["receipt_digest"]
      },
      "control" => control_export
    })
  end

  # -- graph side ----------------------------------------------------------------

  # Same mechanics as SemanticCrown's ggen/3: run through the asdf shim from
  # the graph checkout's own directory, no inherited version override, output
  # to a file, stdin /dev/null, perl alarm deadline.
  defp project(wo_path, out_path, extra_env) do
    out_file =
      Path.join(System.tmp_dir!(), "sj001-ggen-#{System.unique_integer([:positive])}.out")

    runner = ~S(out="$1"; shift; exec "$@" >"$out" 2>&1 </dev/null)

    {_, code} =
      System.cmd(
        "/bin/sh",
        [
          "-c",
          runner,
          "sh",
          out_file,
          "perl",
          "-e",
          "alarm shift; exec @ARGV or exit 127",
          "900",
          mix_bin(),
          "run",
          @script
        ],
        cd: @ggen_dir,
        env:
          [
            {"MIX_ENV", "test"},
            {"MIX_BUILD_PATH", Process.get(:sj001_graph_build)},
            {"ASDF_ELIXIR_VERSION", nil},
            {"ASDF_ERLANG_VERSION", nil},
            {"WO", wo_path},
            {"OUT", out_path}
          ] ++ extra_env
      )

    out = File.read!(out_file)
    File.rm!(out_file)
    {code, last_json(out)}
  end

  # The toolchain on PATH is the one that built the graph checkout's `_build`;
  # the asdf shim resolves the graph repo's `.tool-versions` pin instead (a
  # different OTP), which recompiles the whole graph tree cold on every run.
  defp mix_bin, do: System.find_executable("mix") || flunk("mix not on PATH")

  # The graph process compiles into a private APFS clone of the graph
  # checkout's `_build/test`, so this proof never writes into a build directory
  # other workflows share. Falls back to a cold private build if no clone source.
  defp clone_graph_build(base) do
    source = Path.join([@ggen_dir, "_build", "test"])
    target = Path.join(base, "ggen-build")

    if File.dir?(source) do
      {_, 0} = System.cmd("cp", ["-cR", source, target], stderr_to_stdout: true)
    else
      File.mkdir_p!(target)
    end

    Process.put(:sj001_graph_build, target)
    target
  end

  defp last_json(out) do
    out
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      line = String.trim(line)

      if String.starts_with?(line, "{") do
        case Jason.decode(line) do
          {:ok, %{} = decoded} -> decoded
          _ -> nil
        end
      end
    end)
  end

  # -- fixtures --------------------------------------------------------------------

  defp front_matter do
    [_, json] = Regex.run(~r/\A---\n(.*?)\n---/s, File.read!(@order_path))
    Jason.decode!(json)
  end

  # One real shell step per court the work order requires, run by the fabric
  # verifier (not the worker) inside the exact-head worktree. The steps are
  # non-vacuous: each fails when the candidate head lacks what it inspects.
  @proof_test "test/xaas/ultracode/semantic_jira_e2e_test.exs"
  @mock_pattern "Mo[x]|:mec[k]|unittest[.]mock|MagicMoc[k]|monkeypatc[h]"

  defp suite do
    %{
      env: %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"},
      max_output_bytes: 4096,
      steps: [
        step("compile", "test -f mix.exs && test -f lib/xaas/ultracode/semantic_work.ex"),
        step("tests", "test -s #{@proof_test} && test -f sj001-worker-note.md"),
        step(
          "chicago_no_mocks",
          "test -s #{@proof_test} && ! grep -Eq '#{@mock_pattern}' #{@proof_test}"
        )
      ]
    }
  end

  defp step(id, script),
    do: %{id: id, argv: ["/bin/sh", "-c", script], timeout_ms: 20_000}

  # The scripted worker's candidate: the note plus the proof test itself, so the
  # tests / chicago_no_mocks courts inspect a real changed test file at the head.
  defp commit_candidate(worktree, note?) do
    if note?,
      do: File.write!(Path.join(worktree, "sj001-worker-note.md"), "# SJ-001 worker note\n")

    File.mkdir_p!(Path.join(worktree, Path.dirname(@proof_test)))
    File.cp!(Path.join(@project_root, @proof_test), Path.join(worktree, @proof_test))
    git!(worktree, ["add", "-A"])
    git!(worktree, ["commit", "-q", "-m", "sj-001 candidate"], commit_env())
    git!(worktree, ["rev-parse", "HEAD"])
  end

  defp spill(base, name, descriptor) do
    path = Path.join(base, name)
    File.write!(path, Jason.encode!(descriptor))
    path
  end

  # Flip one hex digit: still matches the sha256 regex, so only the digest
  # BINDING (not the format check) can catch it.
  defp flip("sha256:" <> <<first, rest::binary>>) do
    flipped = if first == ?0, do: ?1, else: ?0
    "sha256:" <> <<flipped, rest::binary>>
  end

  defp tap_evidence(evidence) do
    case System.get_env("SJ001_EVIDENCE_DIR") do
      nil ->
        :ok

      dir ->
        File.mkdir_p!(dir)

        for {name, value} <- evidence do
          File.write!(Path.join(dir, "#{name}.json"), Jason.encode!(value, pretty: true))
        end

        :ok
    end
  end

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-sj001-#{label}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp commit_env do
    [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]
  end

  defp git!(dir, args, env \\ []) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true, env: env)
    String.trim(out)
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)
end
