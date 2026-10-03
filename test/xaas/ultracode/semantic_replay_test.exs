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

  v26.10.2 epoch note: the episode corpus under `docs/sjira/v26.9.23/` is
  FROZEN evidence (`FROZEN-CORPUS.md`; `work.json` is sha256-anchored in the
  episode's `replay.json` `projected_from`). Its committed event verifies
  only under the deprecated pre-v26.10.1 digest rule and its work orders
  predate the post-G1 origin law, so the cold replay no longer reproduces the
  recorded KNOWN_REPLAY — it diverges with typed refusals
  (`reconcile_refused`, `transition_log_refused`), which is exactly what the
  tests at this epoch assert. The corpus is never regenerated.
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
    @tag :frozen_corpus_refusal
    test "the frozen v26.9.23 episode replays as typed refusals, not KNOWN_REPLAY", ctx do
      assert {:ok, out} = replay(ctx)
      state = out["state"]

      # FROZEN-CORPUS.md: docs/sjira/v26.9.23/ is read-only evidence, never
      # regenerated. At the v26.10.2 epoch the recorded state is no longer
      # re-derivable from it, and the divergence is typed:
      #   1. reconcile_refused — the kernel refuses the frozen reconciler
      #      receipt against the frozen work orders (post-G1 origin law: the
      #      orders lack origin_authority; a live copy carrying it cannot
      #      reconcile either, because the frozen receipt binds the frozen
      #      order bytes by definition digest — `no_matching_work_order`);
      #   2. transition_log_refused — the frozen ledger's event verifies only
      #      under the deprecated pre-v26.10.1 digest rule, which
      #      TransitionLog.fetch/1 does not verify (event_digest/1 only).
      assert out["replay"] == "DIVERGED"
      assert out["digest"] != ctx.recorded["digest"]
      assert out["digest"] == SemanticReplay.digest(state)

      assert state["divergence"] == [
               %{
                 "broken_term" => "mu_on_O",
                 "detail" => %{
                   "exit" => 1,
                   "reason" => [
                     "refused",
                     ["refused_work_order", ["missing_required_field", "origin_authority"]]
                   ],
                   "receipt" => "receipt.json"
                 },
                 "identity" => "EP-A",
                 "reason" => "reconcile_refused"
               },
               %{
                 "broken_term" => "R_missing_replay",
                 "detail" => %{
                   "reason" => %{
                     "exit" => 1,
                     "reason" => ["ledger_refused", ["event_digest_mismatch", 1]]
                   }
                 },
                 "identity" => nil,
                 "reason" => "transition_log_refused"
               }
             ]

      assert state["standing"] == %{"EP-A" => "UNKNOWN", "EP-B" => "UNKNOWN"}
      assert state["completed"] == []
      assert state["frontier"]["eligible"] == []

      assert state["subject"] == %{
               "repositories" => ["seanchatmangpt/ggen_igniter"],
               "ref" => @ref,
               "tip" => git!(@ggen_dir, ["rev-parse", @ref])
             }

      assert state["replay"]["status"] == "REFUSED"

      assert %{
               "reason" => [
                 "replay_refused",
                 [
                   "identity_mismatch",
                   [
                     %{
                       "expected" => ["ledger_tail:" <> recorded_tail],
                       "field" => "consequence_set",
                       "observed" => ["ledger_tail:" <> zero_tail]
                     },
                     %{
                       "expected" => %{"EP-A" => "ALIVE"},
                       "field" => "standing_projection",
                       "observed" => %{}
                     }
                   ]
                 ]
               ]
             } = state["replay"]

      [committed] = ledger_events(Path.join(@episode, "ledger.ndjson"))
      assert recorded_tail == committed["event_digest"]
      assert zero_tail == "sha256:" <> String.duplicate("0", 64)

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
    @tag :frozen_corpus_refusal
    test "F5: a deleted receipt is an unreceipted transition, over the frozen corpus's own typed refusals",
         ctx do
      copy = episode_copy()
      File.rm!(Path.join(copy, "receipt.json"))

      assert {:ok, origin} = replay(ctx)
      assert {:ok, out} = replay(ctx, episode_dir: copy)
      state = out["state"]

      # FROZEN-CORPUS.md: the frozen corpus is never regenerated, so this
      # epoch's F5 runs over the frozen corpus's own typed refusals (see the
      # describe block's epoch note). The deletion still diverges typed on
      # top: the committed transition is unreceipted (R_missing_replay).
      assert out["replay"] == "DIVERGED"

      assert {"unreceipted_transition", "R_missing_replay", "EP-A"} in divergence_triples(state)
      assert {"transition_log_refused", "R_missing_replay", nil} in divergence_triples(state)

      assert state["standing"] == %{"EP-A" => "UNKNOWN", "EP-B" => "UNKNOWN"}
      assert state["completed"] == []
      assert state["frontier"]["eligible"] == []

      # the frozen, undeleted episode is exactly the two frozen refusals
      assert divergence_triples(origin["state"]) == [
               {"reconcile_refused", "mu_on_O", "EP-A"},
               {"transition_log_refused", "R_missing_replay", nil}
             ]
    end

    @tag :frozen_corpus_refusal
    test "F6: a commit on the covered path still diverges subject identity; an out-of-scope commit does not",
         ctx do
      covered = subject_repo("lib/ggen_igniter/v23_r_f6.ex")
      outside = subject_repo("docs/v23_r_f6_control.md")

      assert {:ok, covered_out} = replay(ctx, subject_repo: covered)
      assert {:ok, outside_out} = replay(ctx, subject_repo: outside)

      # FROZEN-CORPUS.md: both arms diverge typed at this epoch (frozen
      # refusals); the property that survives is the subject-identity one: a
      # covered-path commit adds subject_changed (R_missing_identity), an
      # out-of-scope commit does not.
      for {out, changed?} <- [{covered_out, true}, {outside_out, false}] do
        state = out["state"]
        assert out["replay"] == "DIVERGED"

        reasons =
          Enum.map(state["divergence"], &{&1["reason"], &1["broken_term"], &1["identity"]})

        assert {"subject_changed", "R_missing_identity", "EP-A"} in reasons == changed?
      end
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
    @tag :frozen_corpus_refusal
    test "exit 4 writes canonical JSON naming the frozen corpus's typed refusals; exit 2 on bad flags",
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

      # FROZEN-CORPUS.md: the frozen episode can no longer produce a
      # KNOWN_REPLAY (exit 0); it diverges typed (exit 4) instead, and the
      # written state still is canonical JSON over the typed divergence.
      assert code == 4, log
      body = File.read!(out)
      decoded = Jason.decode!(body)
      assert body == SemanticReplay.canonical_json(decoded) <> "\n"
      assert decoded["digest"] != ctx.recorded["digest"]
      assert %{"replay" => "DIVERGED"} = last_json(log)

      assert Enum.map(
               decoded["state"]["divergence"],
               &{&1["reason"], &1["broken_term"], &1["identity"]}
             ) == [
               {"reconcile_refused", "mu_on_O", "EP-A"},
               {"transition_log_refused", "R_missing_replay", nil}
             ]

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

  # The (reason, broken_term, identity) of every divergence entry — the typed
  # skeleton the honest frozen-corpus assertions match on (entries carry a
  # `detail` map with the kernel's own refusal shape on top).
  defp divergence_triples(state) do
    Enum.map(state["divergence"], &{&1["reason"], &1["broken_term"], &1["identity"]})
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

  v26.10.2 epoch note: the episode corpus under `docs/sjira/v26.9.23/` is
  FROZEN evidence (its `FROZEN-CORPUS.md` freeze law; `work.json` is
  sha256-anchored in the episode's `replay.json` `projected_from`). The live
  work-order copy this module feeds the graph side carries the pack's
  admitted `sj:CodeWorkAuthority` (the post-G1 origin law requires it; the
  frozen file is never edited), and the ledgers replayed from the frozen
  corpus assert their typed refusal rather than a KNOWN_REPLAY: the frozen
  v26.9.23 events verify only under the deprecated pre-v26.10.1 digest rule,
  which `TransitionLog.fetch/1` does not verify (it stamps and checks
  `event_digest/1` only).
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{SemanticCrown, SemanticDrive}

  @moduletag timeout: 600_000

  @root Path.expand("../../..", __DIR__)
  @episode Path.join(@root, "docs/sjira/v26.9.23/episodes/fmt-1")
  @ggen_dir System.get_env("GGEN_IGNITER_DIR") || Path.expand("~/ggen_igniter")

  # The pack's admitted sj:CodeWorkAuthority — the same pinned IRI
  # `Xaas.Ultracode.SemanticDrive.Episode.origin_authority/0` stamps; the
  # frozen episode orders predate the origin law, so the live copy carries it.
  @origin_authority "https://ggen-igniter.dev/ontology/semantic-jira#objective-code-work-authority"

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

    # The frozen corpus is never edited (FROZEN-CORPUS.md; work.json is
    # sha-anchored in replay.json's projected_from) — the LIVE work-order copy
    # the graph side reads gets the post-G1 origin_authority injected here.
    work_orders =
      live_work_orders!(Path.join(@episode, "work.json"), Path.join(base, "work-orders.json"))

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

  # The frozen episode's work orders predate the post-G1 origin law (kernel
  # reconcile refuses `missing_required_field: origin_authority`). The corpus
  # is never edited (FROZEN-CORPUS.md freeze law; work.json is sha256-anchored
  # in replay.json's projected_from): the LIVE work-order copy used by the
  # graph side carries the pack's admitted sj:CodeWorkAuthority instead.
  defp live_work_orders!(source, dest) do
    graph =
      source
      |> File.read!()
      |> Jason.decode!()
      |> Map.update!("work_orders", fn orders ->
        Enum.map(orders, &Map.put(&1, "origin_authority", @origin_authority))
      end)

    File.write!(dest, Jason.encode!(graph))
    dest
  end

  test "a directory ledger is copied whole (File.cp! of a directory raised :eisdir) and its frozen events refuse typed",
       %{
         base: base,
         ctx: ctx
       } do
    # The frozen reconciler receipt binds the FROZEN work-order bytes by
    # definition digest — even against a live copy carrying origin_authority
    # the kernel reconcile refuses (`no_matching_work_order`), so no live
    # ledger can be reconciled from the frozen corpus. The directory-ledger
    # copy regression (:eisdir) is therefore exercised at the copy level:
    # the frozen file-ledger's event, one file per event (`:dir` kind).
    ledger = Path.join(base, "ledger")
    File.mkdir_p!(ledger)

    @episode
    |> Path.join("ledger.ndjson")
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.with_index(1)
    |> Enum.each(fn {event, seq} -> File.write!(Path.join(ledger, "#{seq}.json"), event) end)

    assert File.dir?(ledger)

    # FROZEN-CORPUS.md: the frozen v26.9.23 event verifies only under the
    # deprecated pre-v26.10.1 digest rule, which TransitionLog.fetch/1 does
    # not verify (event_digest/1 only). The freeze law's lawful treatment is
    # the typed refusal, never regeneration.
    assert {:error, {:frontier_failed, 1, reason}} =
             SemanticCrown.replay(%{ctx | ledger_path: ledger}, recorded("frontier_after.json"))

    assert reason =~ "ledger_refused"
    assert reason =~ "event_digest_mismatch"

    # the directory ledger itself was copied whole into the replay directory
    # (before the V23-R fix, File.cp! of a directory raised :eisdir here)
    copied = Path.join([ctx.work_dir, "replay", "ledger"])
    assert File.dir?(copied)
    assert File.ls!(copied) |> Enum.filter(&String.ends_with?(&1, ".json")) |> length() == 1
  end

  test "the frozen file ledger refuses typed: its event verifies only under the legacy digest rule",
       %{
         base: base,
         ctx: ctx
       } do
    ledger = Path.join(base, "standing-ledger.ndjson")
    File.cp!(Path.join(@episode, "ledger.ndjson"), ledger)

    # FROZEN-CORPUS.md: the v26.9.23 event is read-only evidence verifying
    # only under the pre-v26.10.1 rule, which TransitionLog.fetch/1 does not
    # verify (it stamps and checks event_digest/1 only). The freeze law's
    # lawful treatment is the typed refusal, never regeneration.
    assert {:error, {:frontier_failed, 1, reason}} =
             SemanticCrown.replay(%{ctx | ledger_path: ledger}, recorded("frontier_after.json"))

    assert reason =~ "ledger_refused"
    assert reason =~ "event_digest_mismatch"
  end

  test "an absent ledger replays as the empty log", %{base: base, ctx: ctx} do
    ledger = Path.join(base, "standing-ledger.ndjson")
    before = recorded("frontier_before.json")

    assert {:ok, replay} = SemanticCrown.replay(%{ctx | ledger_path: ledger}, before)

    # FROZEN-CORPUS.md: the live work-order copy carries origin_authority, so
    # the frontier's eligible entry embeds the live orders' definition/
    # work_order digests — different bytes than the frozen frontier_before
    # record, hence `equal` is false. The rule-stable projection (standings,
    # empty-log tail) is what this epoch asserts.
    assert replay["equal"] == false
    assert replay["standings"] == before["standings"]
    assert replay["ledger_tail"] == before["ledger_tail"]
  end
end
