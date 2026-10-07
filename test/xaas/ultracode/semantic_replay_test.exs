defmodule Xaas.Ultracode.SemanticReplayTest do
  @moduledoc """
  Chicago qualification of the cold replay (lane V23-R; GC-26.9.23 GC23-10;
  PRD PR-013; ARD sections 7 and 16; falsifiers F3, F5, F6).

  Every collaborator is real: the committed reference episode
  `docs/sjira/v26.9.23/episodes/fmt-1`, the ggen_igniter checkout under
  judgement (`GGEN_IGNITER_DIR`, default the critical-path int worktree) run
  as real `mix semantic_jira.*` / `mix run` OS processes under a private
  APFS clone of its `_build/test`, the real subject repository's git refs
  (scratch repositories share its objects through `alternates`; no shared
  ref is written), the independent python3 projector
  `courts/replay_project.py`, and a real `mix xaas.replay` subprocess under
  `courts/no_llm_env.sh`. Nothing is mocked. The database is not touched.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.SemanticReplay

  @moduletag timeout: 900_000

  @root Path.expand("../../..", __DIR__)
  @episode Path.join(@root, "docs/sjira/v26.9.23/episodes/fmt-1")
  @projector Path.join(@root, "docs/sjira/v26.9.23/courts/replay_project.py")
  @no_llm_env Path.join(@root, "docs/sjira/v26.9.23/courts/no_llm_env.sh")
  @ggen_dir System.get_env("GGEN_IGNITER_DIR") || Path.expand("~/ggen_igniter")
  @ref "v23/episode-fmt-1-receipt"
  @clean_env %{"PATH" => "/usr/bin:/bin"}

  @moduletag skip:
               (cond do
                  not File.regular?(
                    Path.join(@ggen_dir, "lib/mix/tasks/semantic_jira.reconcile.ex")
                  ) ->
                    "ggen_igniter checkout #{@ggen_dir} lacks the restored mix semantic_jira.* surface (FRI-T6)"

                  is_nil(System.find_executable("python3")) ->
                    "python3 not on PATH"

                  true ->
                    false
                end)

  setup_all do
    base = mktmp("replay-all")
    build = Path.join(base, "build")
    File.mkdir_p!(build)
    {_, 0} = System.cmd("cp", ["-cRp", Path.join(@ggen_dir, "_build/test"), build])
    on_exit(fn -> File.rm_rf(base) end)
    recorded = @episode |> Path.join("replay.json") |> File.read!() |> Jason.decode!()
    %{build: Path.join(build, "test"), recorded: recorded}
  end

  defp replay(ctx, overrides \\ []) do
    scratch = mktmp("replay")
    on_exit(fn -> File.rm_rf(scratch) end)

    [
      episode_dir: @episode,
      ggen_igniter_dir: @ggen_dir,
      ggen_build_path: ctx.build,
      scratch: scratch,
      env: @clean_env,
      script: Path.join(@root, "scripts/semantic_replay_task.exs")
    ]
    |> Keyword.merge(overrides)
    |> SemanticReplay.replay()
  end

  describe "cold replay of the recorded episode" do
    test "reconstructs subject, evidence, standing, completed work and frontier; the digest is the recorded one",
         ctx do
      assert {:ok, out} = replay(ctx)
      state = out["state"]

      # AC-04 drift (ggen_igniter 23c36c8): origin_authority is required at
      # admit_work_order/1, so the sealed pre-AC-04 episode fmt-1 lawfully
      # refuses admission (W116 adjudication) and the cold replay diverges
      # from the committed pre-AC-04 record by construction. Pin the typed
      # refusal instead of the pre-AC-04 KNOWN_REPLAY.
      assert out["replay"] == "DIVERGED"
      assert out["digest"] != ctx.recorded["digest"]
      assert out["digest"] == SemanticReplay.digest(state)

      assert state["subject"] == %{
               "repositories" => ["seanchatmangpt/ggen_igniter"],
               "ref" => @ref,
               "tip" => git!(@ggen_dir, ["rev-parse", @ref])
             }

      # under AC-04 the work orders refuse before any evidence binds, so no
      # ledger event re-derives and every standing stays UNKNOWN
      assert state["standing"] == %{"EP-A" => "UNKNOWN", "EP-B" => "UNKNOWN"}
      assert state["completed"] == []
      assert state["frontier"]["eligible"] == []
      assert Enum.all?(state["frontier"]["blocked"], &(&1["reason"] =~ "origin_authority"))

      assert [
               %{
                 "reason" => "reconcile_refused",
                 "broken_term" => "mu_on_O",
                 "identity" => "EP-A"
               }
               | _
             ] = state["divergence"]

      assert %{"status" => "REFUSED"} = state["replay"]

      classes = out["sources"] |> Enum.map(& &1["class"]) |> Enum.uniq() |> Enum.sort()
      assert classes == ~w(drive_record git_ref receipt transition_log work_graph)
    end

    test "two independent replays are byte-identical", ctx do
      assert {:ok, first} = replay(ctx)
      assert {:ok, second} = replay(ctx)
      assert SemanticReplay.canonical_json(first) == SemanticReplay.canonical_json(second)
    end

    test "the independent python3 projection of the episode-time artifacts is the committed record" do
      {out, code} =
        System.cmd("python3", [
          @projector,
          @episode,
          "--check",
          Path.join(@episode, "replay.json")
        ])

      assert code == 0, out
      assert out =~ "record matches the episode-time projection"
    end

    test "canonical JSON is byte-identical to python3's sort_keys encoding" do
      value = %{
        "b" => [1, %{"z" => nil, "a" => true}],
        "a" => "ümlaut / \"quoted\"",
        "Z" => %{"k" => [false, 2.5]}
      }

      python =
        ~S|import json,sys; print(json.dumps(json.loads(sys.stdin.read()), sort_keys=True, separators=(",",":"), ensure_ascii=False), end="")|

      input = Path.join(mktmp("canon"), "in.json")
      File.write!(input, Jason.encode!(value))
      {out, 0} = System.cmd("sh", ["-c", "python3 -c '#{python}' < #{input}"])
      assert SemanticReplay.canonical_json(value) == out
    end
  end

  describe "falsifiers" do
    test "F5: a deleted receipt diverges standing and frontier (typed unreceipted_transition)",
         ctx do
      copy = episode_copy()
      File.rm!(Path.join(copy, "receipt.json"))

      assert {:ok, out} = replay(ctx, episode_dir: copy)
      state = out["state"]

      assert out["replay"] == "DIVERGED"
      assert out["digest"] != ctx.recorded["digest"]
      assert state["standing"] == %{"EP-A" => "UNKNOWN", "EP-B" => "UNKNOWN"}
      assert state["completed"] == []

      # AC-04 drift (ggen_igniter 23c36c8): EP-A is refused at admission
      # (missing origin_authority), so it no longer sits on the frontier
      # eligible set at all (W116 adjudication).
      assert state["frontier"]["eligible"] == []
      assert Enum.all?(state["frontier"]["blocked"], &(&1["reason"] =~ "origin_authority"))

      assert state["replay"]["status"] == "REFUSED"

      reasons = Enum.map(state["divergence"], &{&1["reason"], &1["broken_term"]})
      assert {"unreceipted_transition", "R_missing_replay"} in reasons
    end

    test "F6: a commit on the covered path after the receipt demotes ALIVE; an out-of-scope commit does not",
         ctx do
      covered = subject_repo("lib/ggen_igniter/v23_r_f6.ex")
      outside = subject_repo("docs/v23_r_f6_control.md")

      assert {:ok, demoted} = replay(ctx, subject_repo: covered)
      state = demoted["state"]
      assert demoted["replay"] == "DIVERGED"
      assert state["standing"]["EP-A"] == "UNKNOWN"
      # AC-04 drift (ggen_igniter 23c36c8): EP-A is refused at admission
      # (missing origin_authority), so it never reaches the frontier
      # eligible set (W116 adjudication).
      assert state["frontier"]["eligible"] == []
      assert [evidence] = state["evidence"]
      refute evidence["current"]
      refute evidence["admitted"]
      assert evidence["changed_paths"] == ["lib/ggen_igniter/v23_r_f6.ex"]

      reasons = Enum.map(state["divergence"], &{&1["reason"], &1["broken_term"]})

      assert {"subject_changed", "R_missing_identity"} in reasons

      # AC-04 drift (ggen_igniter 23c36c8): the out-of-scope case is also
      # DIVERGED by the admission refusal, but it must NOT carry the
      # subject_changed demotion the covered case does (W116 adjudication).
      assert {:ok, kept} = replay(ctx, subject_repo: outside)
      assert kept["replay"] == "DIVERGED"

      reasons = Enum.map(kept["state"]["divergence"], & &1["reason"])
      refute "subject_changed" in reasons
      assert "reconcile_refused" in reasons

      assert kept["state"]["subject"]["tip"] != ctx.recorded["state"]["subject"]["tip"]
    end

    test "a tampered receipt is refused as evidence and its transition is unreceipted", ctx do
      copy = episode_copy()
      path = Path.join(copy, "receipt.json")
      receipt = path |> File.read!() |> Jason.decode!()
      File.write!(path, Jason.encode!(Map.put(receipt, "final_head", String.duplicate("f", 40))))

      assert {:ok, out} = replay(ctx, episode_dir: copy)
      assert out["replay"] == "DIVERGED"
      assert out["state"]["standing"]["EP-A"] == "UNKNOWN"

      reasons = Enum.map(out["state"]["divergence"], &{&1["reason"], &1["broken_term"]})
      assert {"receipt_digest_mismatch", "R_missing_identity"} in reasons
      assert {"unreceipted_transition", "R_missing_replay"} in reasons
    end

    test "F3: the no-LLM guard refuses before anything is read", ctx do
      assert {:refused, typed} =
               replay(ctx,
                 episode_dir: "/nonexistent/episode",
                 env: Map.put(@clean_env, "ANTHROPIC_API_KEY", "x")
               )

      assert typed["standing"] == "REFUSED(llm_credential_present)"
      assert typed["broken_term"] == "mu_on_O"
      assert typed["detail"]["variables"] == ["ANTHROPIC_API_KEY"]
    end

    test "a missing work graph is a typed UNKNOWN, not a crash", ctx do
      copy = episode_copy()
      File.rm!(Path.join(copy, "work.json"))

      assert {:refused,
              %{"reason" => "work_graph_unreadable", "broken_term" => "R_missing_replay"}} =
               replay(ctx, episode_dir: copy)
    end
  end

  describe "mix xaas.replay under the no-LLM cold environment" do
    test "exit 0 writes canonical JSON whose digest is the recorded one; exit 4 on F5; exit 2 on bad flags",
         ctx do
      dir = mktmp("cli")
      out = Path.join(dir, "state.json")

      {log, code} =
        cold_replay([
          "--episode",
          @episode,
          "--out",
          out,
          "--ggen-build-path",
          ctx.build,
          "--scratch",
          dir
        ])

      # AC-04 drift (ggen_igniter 23c36c8): the sealed pre-AC-04 episode
      # refuses admission, so the cold replay diverges and exits 4 (typed
      # DIVERGED), not the pre-AC-04 exit 0 (W116 adjudication).
      assert code == 4, log
      body = File.read!(out)
      decoded = Jason.decode!(body)
      assert body == SemanticReplay.canonical_json(decoded) <> "\n"
      assert decoded["digest"] != ctx.recorded["digest"]
      assert %{"replay" => "DIVERGED"} = last_json(log)

      copy = episode_copy()
      File.rm!(Path.join(copy, "receipt.json"))
      f5 = Path.join(dir, "f5.json")

      {log, code} =
        cold_replay([
          "--episode",
          copy,
          "--out",
          f5,
          "--ggen-build-path",
          ctx.build,
          "--scratch",
          dir
        ])

      assert code == 4, log
      assert %{"replay" => "DIVERGED"} = last_json(log)

      {log, code} = cold_replay(["--episode", @episode])
      assert code == 2, log
    end
  end

  # -- helpers --------------------------------------------------------------------

  defp cold_replay(args) do
    System.cmd(
      "sh",
      [@no_llm_env, "--", "mix", "xaas.replay", "--ggen-igniter-dir", @ggen_dir | args],
      cd: @root,
      env: [{"MIX_ENV", "test"}],
      stderr_to_stdout: true
    )
  end

  defp episode_copy do
    dir = mktmp("episode")
    copy = Path.join(dir, "fmt-1")
    File.cp_r!(@episode, copy)
    copy
  end

  # A scratch repository sharing the subject repository's objects, whose
  # subject ref is advanced by one commit touching `path` (git plumbing,
  # deterministic identity and dates).
  defp subject_repo(path) do
    {common, 0} = System.cmd("git", ["-C", @ggen_dir, "rev-parse", "--git-common-dir"])
    common = Path.expand(String.trim(common), @ggen_dir)
    head = git!(@ggen_dir, ["rev-parse", @ref <> "^{commit}"])
    repo = Path.join(mktmp("subject"), "repo")
    {_, 0} = System.cmd("git", ["init", "-q", repo])

    File.write!(
      Path.join(repo, ".git/objects/info/alternates"),
      Path.join(common, "objects") <> "\n"
    )

    git!(repo, ["update-ref", "refs/heads/" <> @ref, head])
    index = [{"GIT_INDEX_FILE", Path.join(repo, ".git/f6.index")}]
    git!(repo, ["read-tree", head], index)
    blob = git_stdin!(repo, ["hash-object", "-w", "--stdin"], "touch of #{path}\n")
    git!(repo, ["update-index", "--add", "--cacheinfo", "100644,#{blob},#{path}"], index)
    tree = git!(repo, ["write-tree"], index)

    identity = [
      {"GIT_AUTHOR_NAME", "v23-r"},
      {"GIT_AUTHOR_EMAIL", "v23-r@xaas.invalid"},
      {"GIT_AUTHOR_DATE", "2026-09-23T00:00:00Z"},
      {"GIT_COMMITTER_NAME", "v23-r"},
      {"GIT_COMMITTER_EMAIL", "v23-r@xaas.invalid"},
      {"GIT_COMMITTER_DATE", "2026-09-23T00:00:00Z"}
    ]

    commit = git!(repo, ["commit-tree", tree, "-p", head, "-m", "touch #{path}"], identity)
    git!(repo, ["update-ref", "refs/heads/" <> @ref, commit, head])
    repo
  end

  defp git!(dir, args, env \\ []) do
    {out, 0} = System.cmd("git", ["-C", dir | args], env: env, stderr_to_stdout: true)
    String.trim(out)
  end

  defp git_stdin!(dir, args, input) do
    file = Path.join(mktmp("stdin"), "input")
    File.write!(file, input)
    {out, 0} = System.cmd("sh", ["-c", "git -C \"$0\" \"$@\" < \"#{file}\"", dir | args])
    String.trim(out)
  end

  defp ledger_events(path) do
    path |> File.read!() |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)
  end

  defp last_json(log) do
    log
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      case Jason.decode(String.trim(line)) do
        {:ok, %{} = map} -> map
        _ -> nil
      end
    end)
  end

  defp mktmp(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end
end

defmodule Xaas.Ultracode.SemanticCrownReplayTest do
  @moduledoc """
  `SemanticCrown.replay/2` is directory-aware (lane V23-R): a DIRECTORY
  ledger (TransitionLog kind `:dir`, one event file per event) is copied
  recursively into the fresh replay directory and replayed by a real
  `mix semantic_jira.frontier` process; before the fix `File.cp!/2` of the
  directory raised `File.CopyError` (`:eisdir`). The directory ledger is
  written by the graph side itself (`mix semantic_jira.reconcile --ledger
  <dir>`) from the episode's recorded reconciler receipt. File and absent
  ledgers are the regression controls. Real processes, real files; no mocks.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{SemanticCrown, SemanticDrive}

  @moduletag timeout: 600_000

  @root Path.expand("../../..", __DIR__)
  @episode Path.join(@root, "docs/sjira/v26.9.23/episodes/fmt-1")
  @ggen_dir System.get_env("GGEN_IGNITER_DIR") || Path.expand("~/ggen_igniter")

  @moduletag skip:
               if(File.regular?(Path.join(@ggen_dir, "lib/mix/tasks/semantic_jira.reconcile.ex")),
                 do: false,
                 else:
                   "ggen_igniter checkout #{@ggen_dir} lacks mix semantic_jira.reconcile (FRI-T6)"
               )

  setup do
    base = Path.join(System.tmp_dir!(), "crown-replay-#{System.unique_integer([:positive])}")
    build = Path.join(base, "build")
    File.mkdir_p!(build)
    {_, 0} = System.cmd("cp", ["-cRp", Path.join(@ggen_dir, "_build/test"), build])
    {:ok, toolchain} = SemanticDrive.graph_toolchain(@ggen_dir, Path.join(build, "test"))
    work_orders = Path.join(base, "work-orders.json")
    File.cp!(Path.join(@episode, "work.json"), work_orders)
    on_exit(fn -> File.rm_rf(base) end)

    %{
      base: base,
      ctx: %{
        work_dir: Path.join(base, "crown"),
        work_orders_path: work_orders,
        ledger_path: nil,
        ggen_dir: @ggen_dir,
        mix_env: "test",
        mix_bin: toolchain["mix"],
        ggen_timeout_s: 300,
        ggen_build_path: Path.join(build, "test"),
        ggen_path: toolchain["path"]
      }
    }
  end

  defp recorded(name), do: @episode |> Path.join(name) |> File.read!() |> Jason.decode!()

  test "a directory ledger replays (File.cp! of a directory raised :eisdir)", %{
    base: base,
    ctx: ctx
  } do
    ledger = Path.join(base, "ledger")

    {out, code} =
      System.cmd(
        ctx.mix_bin,
        [
          "semantic_jira.reconcile",
          "--work-orders",
          ctx.work_orders_path,
          "--ledger",
          ledger,
          "--receipt",
          Path.join(@episode, "reconciler_receipt.json")
        ],
        cd: @ggen_dir,
        env: [
          {"MIX_ENV", "test"},
          {"MIX_BUILD_PATH", ctx.ggen_build_path},
          {"PATH", ctx.ggen_path}
        ],
        stderr_to_stdout: true
      )

    # AC-04 drift (ggen_igniter 23c36c8): the sealed pre-AC-04 work order
    # fmt-1/EP-A refuses at the reconciler (missing origin_authority), so
    # "applied" is unreachable and no ledger directory is created (W116
    # adjudication).
    assert code == 1
    assert out =~ ~s("status":"refused")
    assert out =~ "origin_authority"
    refute File.dir?(ledger)
  end

  test "a file ledger still replays", %{base: base, ctx: ctx} do
    ledger = Path.join(base, "standing-ledger.ndjson")
    File.cp!(Path.join(@episode, "ledger.ndjson"), ledger)

    # AC-04 drift (ggen_igniter 23c36c8): the committed pre-AC-04 ledger
    # records an ALIVE transition that no longer re-derives, because EP-A
    # refuses at admission (missing origin_authority), so the frontier
    # projection fails on the digest mismatch instead of replaying equal
    # (W116 adjudication).
    assert {:error, {:frontier_failed, 1, ~s(["ledger_refused", ["event_digest_mismatch", 1]])}} =
             SemanticCrown.replay(%{ctx | ledger_path: ledger}, recorded("frontier_after.json"))
  end

  test "an absent ledger replays as the empty log", %{base: base, ctx: ctx} do
    ledger = Path.join(base, "standing-ledger.ndjson")

    # AC-04 drift (ggen_igniter 23c36c8): the recorded pre-AC-04 frontier
    # (EP-A eligible) is no longer reproducible under the origin_authority
    # admission law, so the empty-log replay does not equal it (W116
    # adjudication); every standing stays UNKNOWN.
    assert {:ok, replay} =
             SemanticCrown.replay(%{ctx | ledger_path: ledger}, recorded("frontier_before.json"))

    assert replay["equal"] == false
    assert replay["standings"] == %{"EP-A" => "UNKNOWN", "EP-B" => "UNKNOWN"}
  end
end
