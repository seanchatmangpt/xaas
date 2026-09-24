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
  a real verifier suite and the real `Lease.claim_next`/`Lease.close` fabric
  court. The `compile` court is a REAL `mix compile` of the exact-head
  worktree (private APFS clones of this checkout's `deps` and `_build/test`,
  `env -i` allowlist, as the fabric verifier always runs steps); the `tests`
  and `chicago_no_mocks` courts remain fixture shell steps over the candidate
  head. The worker is a scripted protocol client; it stands in only for the
  model's judgment.

  Falsifier 1 (digest altered after admission) is attacked at the real
  `mix xaas.semantic.materialize` boundary with probes A (mismatch), B
  (envelope omitted), C (envelope altered consistently), D (every anchor
  stripped) and E (admitted snapshot edited), all against the descriptor the
  real graph-side admission emitted; falsifier 2 (a court that did not pass
  must not seal alive) with one candidate that fails the fixture `tests`
  court and one whose source does not compile.

  Not tagged `:subprocess` on purpose: it pays several nested BEAM boots (admit +
  project, the emission-guard refusal, two negative controls), two real
  `mix compile` runs per candidate epoch, and the work
  order's runnable check is the plain
  `mix test test/xaas/ultracode`, which must exercise this proof. Skips
  (never fails) when the ggen_igniter checkout is absent.

  Set `SJ001_EVIDENCE_DIR` to tap the sealed artifacts (admit verdict,
  descriptor, materialize output, receipt, replay, negative control) into a
  directory for the committed receipts; unset by default so ordinary runs
  never write into the repository.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, RecipeWorker, SemanticReceipt}
  alias Xaas.Ultracode.SemanticWork.AdmissionBinding

  @moduletag timeout: 1_200_000

  @project_root File.cwd!()
  @sjira_dir Path.join([@project_root, "docs", "sjira", "v26.9.21"])
  @order_path Path.join(@sjira_dir, "001-xaas-semantic-jira-e2e.md")
  @script Path.join(@sjira_dir, "e2e_project.exs")
  # the committed current-form descriptor fixture the SemanticWork tests attack;
  # produced only by RUNNING the projection (scripts/sj001_descriptor_fixture.exs)
  @fixture Path.join([
             @project_root,
             "test",
             "fixtures",
             "semantic_work",
             "sj-001-descriptor.json"
           ])
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
             "definition_digest" => definition,
             "digest_form" => "sjira-digest/2" = form
           } = admit

    assert digest =~ ~r/\Asha256:[0-9a-f]{64}\z/
    assert definition =~ ~r/\Asha256:[0-9a-f]{64}\z/

    descriptor = descriptor_path |> File.read!() |> Jason.decode!()

    # the committed fixture IS this producer's output, byte for byte (it is never
    # hand-edited; regenerate with scripts/sj001_descriptor_fixture.exs)
    assert File.read!(descriptor_path) == File.read!(@fixture),
           "#{@fixture} is not the current projection; regenerate it by running " <>
             "GGEN_IGNITER_DIR=#{@ggen_dir} mix run --no-start scripts/sj001_descriptor_fixture.exs"

    assert descriptor["digest_form"] == form
    assert descriptor["graph_digest"] == digest
    assert descriptor["admission_digest"] == digest
    assert descriptor["base_sha"] == order["base_sha"]
    assert descriptor["repository_identity"] == order["repository"]
    assert descriptor["execution_repo_alias"] == "sj001"
    assert descriptor["bridge"]["identity"] == "SJ-001"
    assert descriptor["bridge"]["definition_digest"] == definition
    assert descriptor["bridge"]["source_snapshot_digest"] == digest
    assert descriptor["admitted_work_order"]["work_order_digest"] == digest

    # XaaS recomputes the admitted digests itself, under the declared form, and
    # reproduces the graph's (the snapshot embeds the definition digest)
    assert AdmissionBinding.snapshot_digest(descriptor["admitted_work_order"], form) == digest

    assert AdmissionBinding.definition_digest(descriptor["admitted_work_order"], form) ==
             definition

    assert descriptor["admitted_work_order"]["definition_digest"] == definition
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
      ticket,
      "--binding",
      "snapshot"
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

    # all three required courts ran in order and passed; `compile` is a real
    # `mix compile` of the exact-head worktree
    assert step_statuses(export) == [
             {"compile", "pass"},
             {"tests", "pass"},
             {"chicago_no_mocks", "pass"}
           ]

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

    # at materialize, on what the REAL producer emitted. Every probe is refused
    # with a typed reason, with or without the envelope; nothing is provisioned.
    altered = flip(digest)
    tampered = Map.put(descriptor, "graph_digest", altered)
    bridge_only = Map.delete(descriptor, "admitted_work_order")

    stripped =
      descriptor
      |> Map.delete("admitted_work_order")
      |> Map.delete("admission_digest")
      |> update_in(["bridge"], &Map.delete(&1, "source_snapshot_digest"))
      |> Map.put("graph_digest", altered)

    probes = [
      {"a-graph-altered", tampered, ["--binding", "snapshot"], ~r/admission_digest_mismatch/},
      {"a-envelope-altered", %{descriptor | "admission_digest" => altered},
       ["--binding", "snapshot"], ~r/admission_digest_mismatch/},
      {"a-envelope-malformed", %{descriptor | "admission_digest" => "sha256:not-hex"},
       ["--binding", "snapshot"], ~r/invalid, :admission_digest/},
      {"b-no-envelope", Map.delete(tampered, "admission_digest"), ["--binding", "snapshot"],
       ~r/graph_digest_unbound, :admitted_work_order/},
      {"b-no-envelope-auto", Map.delete(tampered, "admission_digest"), [],
       ~r/graph_digest_unbound, :admitted_work_order/},
      {"b-bridge-anchor",
       bridge_only |> Map.put("graph_digest", altered) |> Map.delete("admission_digest"),
       ["--binding", "snapshot"], ~r/graph_digest_unbound, :bridge_source_snapshot_digest/},
      {"c-consistent", Map.put(tampered, "admission_digest", altered), ["--binding", "graph"],
       ~r/admission_anchor_disagree, :admitted_work_order, :admission_digest/},
      {"c-consistent-bridge",
       Map.put(bridge_only, "graph_digest", altered) |> Map.put("admission_digest", altered),
       ["--binding", "snapshot"],
       ~r/admission_anchor_disagree, :bridge_source_snapshot_digest, :admission_digest/},
      {"d-stripped", stripped, ["--binding", "snapshot"], ~r/admission_anchor_missing/},
      {"e-snapshot-edited",
       put_in(descriptor["admitted_work_order"]["title"], "edited after admission"),
       ["--binding", "snapshot"], ~r/admitted_snapshot_stale/}
    ]

    for {name, probe, extra_args, expected} <- probes do
      path = spill(base, "descriptor-probe-#{name}.json", probe)

      error =
        assert_raise Mix.Error, ~r/materialize refused/, fn ->
          Mix.Tasks.Xaas.Semantic.Materialize.run(["--descriptor", path | extra_args])
        end

      assert error.message =~ expected,
             "probe #{name}: expected #{inspect(expected)}, got: #{error.message}"
    end

    # -- falsifier 2: a court that did not pass never seals alive ---------------
    # (a) the fixture `tests` court fails: the candidate omits the worker note
    control_export =
      sealed_control(base, wo, "control", fn worktree -> commit_candidate(worktree, false) end)

    assert control_export["outcome"] == "build_broken"
    assert control_export["fabric_verifier"]["status"] == "fail"
    assert step_statuses(control_export) == [{"compile", "pass"}, {"tests", "fail"}]
    assert control_export["receipt_digest"] == SemanticReceipt.receipt_digest(control_export)

    # (b) the REAL compile court fails: the worker note is present (so the
    # fixture courts would pass) but a candidate source file does not compile
    broken_export =
      sealed_control(base, wo, "compile-broken", fn worktree ->
        commit_candidate(worktree, true, true)
      end)

    assert broken_export["outcome"] == "build_broken"
    assert broken_export["fabric_verifier"]["status"] == "fail"
    assert step_statuses(broken_export) == [{"compile", "fail"}]
    assert broken_export["receipt_digest"] == SemanticReceipt.receipt_digest(broken_export)

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
      "control" => control_export,
      "compile_broken" => broken_export
    })
  end

  # -- graph side ----------------------------------------------------------------

  # Same mechanics as SemanticCrown's ggen/3: run from the graph checkout's own
  # directory under the graph toolchain (`graph_toolchain/0`), no inherited
  # version override, output to a file, stdin /dev/null, perl alarm deadline.
  defp project(wo_path, out_path, extra_env) do
    toolchain = graph_toolchain()

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
          toolchain["mix"],
          "run",
          @script
        ],
        cd: @ggen_dir,
        env:
          [
            {"MIX_ENV", "test"},
            {"PATH", toolchain["path"] <> ":/usr/bin:/bin"},
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

  # The graph side runs under the GRAPH checkout's `.tool-versions` pin, Elixir
  # and Erlang (`RecipeWorker.toolchain/1`), never under this node's (the xaas
  # pin): the release builds the graph's `_build/test` under its own pin, and the
  # graph's dependencies do not compile under the xaas pin (observed at
  # ggen_igniter-int 3ed6a7a under Elixir 1.20.2: faker's string.ex SyntaxError).
  defp graph_toolchain do
    case RecipeWorker.toolchain(@ggen_dir) do
      {:ok, toolchain} -> toolchain
      {:error, reason} -> flunk("graph toolchain unresolved: #{inspect(reason)}")
    end
  end

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

  # One step per court the work order requires, run by the fabric verifier (not
  # the worker) inside the exact-head worktree, each halting the suite on its
  # first non-pass. `compile` is the REAL thing: the worktree is a fresh checkout
  # of the order's base_sha, so the step APFS-clones this checkout's `deps` and
  # `_build/test` into it (both are gitignored, so the tree the verifier checks
  # stays clean) and runs `mix compile`. It is non-vacuous: a candidate whose
  # source does not compile fails it. `tests` and `chicago_no_mocks` are still
  # fixture shell steps over the candidate head (a worker-note presence check
  # and a grep of the proof test), disclosed as such in the SJ-001 receipt.
  @proof_test "test/xaas/ultracode/semantic_jira_e2e_test.exs"
  @mock_pattern "Mo[x]|:mec[k]|unittest[.]mock|MagicMoc[k]|monkeypatc[h]"
  @compile_court """
  set -eu
  test -f mix.exs && test -f lib/xaas/ultracode/semantic_work.ex
  [ -d deps ] || cp -cR "$SJ001_DEPS_SRC" deps
  mkdir -p _build
  [ -d _build/test ] || cp -cR "$SJ001_BUILD_SRC" _build/test
  MIX_ENV=test mix compile --no-deps-check
  """

  defp suite do
    %{
      env: %{
        "PATH" => toolchain_path(),
        "LANG" => "en_US.UTF-8",
        "MIX_HOME" => System.get_env("MIX_HOME") || Path.join(System.user_home!(), ".mix"),
        "HEX_HOME" => System.get_env("HEX_HOME") || Path.join(System.user_home!(), ".hex"),
        "SJ001_DEPS_SRC" => Path.join(@project_root, "deps"),
        "SJ001_BUILD_SRC" => Path.join([@project_root, "_build", "test"])
      },
      max_output_bytes: 4096,
      steps: [
        step("compile", @compile_court, 900_000),
        step("tests", "test -s #{@proof_test} && test -f sj001-worker-note.md"),
        step(
          "chicago_no_mocks",
          "test -s #{@proof_test} && ! grep -Eq '#{@mock_pattern}' #{@proof_test}"
        )
      ]
    }
  end

  # The fabric runs steps under `env -i`: the toolchain must be on the explicit
  # PATH allowlist (the directories of the `mix` and `erl` this run uses).
  defp toolchain_path do
    ["mix", "erl", "git"]
    |> Enum.map(&(System.find_executable(&1) || flunk("#{&1} not on PATH")))
    |> Enum.map(&Path.dirname/1)
    |> Kernel.++(["/usr/bin", "/bin"])
    |> Enum.uniq()
    |> Enum.join(":")
  end

  defp step(id, script, timeout_ms \\ 20_000),
    do: %{id: id, argv: ["/bin/sh", "-c", script], timeout_ms: timeout_ms}

  defp step_statuses(export) do
    Enum.map(export["fabric_verifier"]["steps"], &{&1["id"], &1["status"]})
  end

  # One negative control: project a fresh descriptor under its own checkpoint,
  # materialize it through the real mix task, lease it, let `candidate` commit
  # into the worktree, and close claiming :alive so only the fabric's courts
  # can decide the outcome. Returns the exported sealed receipt.
  defp sealed_control(base, wo, label, candidate) do
    path = Path.join(base, "descriptor-#{label}.json")
    {0, %{"ok" => true}} = project(wo, path, [{"CHECKPOINT_SUFFIX", ":" <> label}])

    Mix.Tasks.Xaas.Semantic.Materialize.run(["--descriptor", path, "--binding", "snapshot"])
    assert_received {:mix_shell, :info, [line]}
    assert %{"epoch_id" => epoch_id, "worktree" => worktree} = Jason.decode!(line)

    {:ok, _claimed, token, _run} =
      Lease.claim_next("zcode", "sj001-#{label}", epoch_id: epoch_id)

    head = candidate.(worktree)

    {:ok, _epoch, _receipt} =
      Lease.close(token, head, :alive, %{"note" => "#{label} claims ALIVE"})

    assert {:ok, export} = SemanticReceipt.export(epoch_id)
    export
  end

  # The scripted worker's candidate: the note plus the proof test itself, so the
  # tests / chicago_no_mocks courts inspect a real changed test file at the head.
  defp commit_candidate(worktree, note?, broken? \\ false) do
    if note?,
      do: File.write!(Path.join(worktree, "sj001-worker-note.md"), "# SJ-001 worker note\n")

    # a source file that cannot compile: only the REAL compile court can see it
    if broken?,
      do:
        File.write!(
          Path.join(worktree, "lib/sj001_broken.ex"),
          "defmodule Sj001Broken do\n  def x(, do: end\n"
        )

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
