defmodule Xaas.Sjira.SuccessorTest do
  @moduledoc """
  Chicago-style qualification of the GC23-12 successor pipeline (lane V23-H;
  PRD section 12, ARD section 24 M9): the real committed successor artifacts
  in docs/sjira/v26.9.23/successor/, the real `Xaas.Sa2a.Route` and the real
  `:ultracode_construction_recipes` registry for `classify/1`, the real
  `courts/successor_law.py` and `courts/successor_acceptance.sh` as `python3`
  and `sh` OS processes over real tmp git repositories, and -- with the
  ggen_igniter checkout (GGEN_IGNITER_DIR, else the int worktree; named skip
  when absent) -- the real intake: `mix run` of the work-graph script,
  `mix semantic_jira.frontier` and `mix semantic_jira.descriptor` as OS
  processes in that checkout, recomputed byte for byte against the committed
  intake. No mocks, no stubs.
  """
  use ExUnit.Case, async: false

  alias Xaas.Sjira.Successor

  @repo Path.expand("../../..", __DIR__)
  @dir Path.join(@repo, "docs/sjira/v26.9.23/successor")
  @courts Path.join(@repo, "docs/sjira/v26.9.23/courts")
  @prose_rel "docs/sjira/v26.9.23/successor/v26.9.24-wbpr.md"
  @ggen_dir System.get_env("GGEN_IGNITER_DIR") || "/Users/sac/wt/v26922/fri/ggen_igniter-int"
  @ggen_ready File.regular?(Path.join(@ggen_dir, "lib/mix/tasks/semantic_jira.descriptor.ex")) and
                File.regular?(
                  Path.join(@ggen_dir, "lib/ggen_igniter/semantic_jira/bootstrap/graph.ex")
                )

  defp tmp_dir(prefix) do
    dir = Path.join(System.tmp_dir!(), "#{prefix}_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp rows do
    Path.join(@dir, "intake/work.json")
    |> File.read!()
    |> Jason.decode!()
    |> Map.fetch!("work_orders")
  end

  # The environment the in-process intake's no-LLM guard judges: this test
  # process's own environment minus every model-credential variable and every
  # PATH directory holding a `claude`/`zcode` executable (the graph-side OS
  # processes additionally run with those variables unset and the resolved
  # toolchain PATH, `SemanticDrive.graph_side/3`).
  defp no_llm_env do
    llm = Xaas.Ultracode.SemanticDrive.llm_variables()

    path =
      (System.get_env("PATH") || "")
      |> String.split(":", trim: true)
      |> Enum.reject(fn dir -> Enum.any?(~w(claude zcode), &File.exists?(Path.join(dir, &1))) end)
      |> Enum.join(":")

    System.get_env()
    |> Enum.reject(fn {name, _} ->
      name in llm.names or Enum.any?(llm.prefixes, &String.starts_with?(name, &1))
    end)
    |> Map.new()
    |> Map.put("PATH", path)
  end

  defp git(dir, args) do
    System.cmd(
      "git",
      [
        "-C",
        dir,
        "-c",
        "user.email=v23h@example.org",
        "-c",
        "user.name=v23h",
        "-c",
        "commit.gpgsign=false" | args
      ],
      stderr_to_stdout: true
    )
  end

  # ------------------------------------------------------------------ classify/1

  test "classify: the committed successor rows are typed UNSUPPORTED(provider_capability), never an error" do
    assert [_ | _] = rows = rows()

    for row <- rows do
      assert {:ok, item} = Successor.classify(row)
      assert item["standing"] == "UNSUPPORTED(provider_capability)"
      assert item["reason"] == "provider_capability"
      assert item["capability"] == "recipe:ggen-sync"
      assert item["resolve"] == "refused:unregistered_capability"
      refute item["capability"] in item["registered_capabilities"]
      assert item["tuple_digest"] == row["tuple_digest"]
      assert item["classification"] == "Successor"
    end
  end

  test "classify: a registered capability routes KNOWN (still UNKNOWN standing); construct:unassigned is UNKNOWN" do
    row = hd(rows())
    assert "recipe:mix-format" in Successor.registered_capabilities()

    known =
      row |> Map.put("requires_capability", "recipe:mix-format") |> Map.delete("tuple_digest")

    assert {:ok, item} = Successor.classify(known)
    assert item["route"] == "KNOWN"
    assert item["standing"] == "UNKNOWN"
    assert item["resolved"] == %{"provider" => "recipe", "recipe_id" => "mix-format"}

    unassigned =
      row |> Map.put("requires_capability", "construct:unassigned") |> Map.delete("tuple_digest")

    assert {:ok, item} = Successor.classify(unassigned)
    assert item["standing"] == "UNKNOWN"
    assert item["reason"] == "capability_unassigned"
  end

  test "classify: a tuple the route cannot admit, or a digest that moved, is a typed refusal" do
    row = hd(rows())

    assert {:refused, refused} = Successor.classify(Map.delete(row, "postcondition"))
    assert refused["standing"] == "REFUSED(tuple_refused)"
    assert refused["broken_term"] == "admission_vacuous"

    assert {:refused, refused} = Successor.classify(Map.put(row, "postcondition", "moved"))
    assert refused["standing"] == "REFUSED(tuple_digest_mismatch)"
    assert refused["detail"]["row_tuple_digest"] == row["tuple_digest"]
  end

  test "intake: an exposed model credential is REFUSED(llm_credential_present) before anything runs" do
    env = Map.put(no_llm_env(), "ANTHROPIC_API_KEY", "x")

    assert {:refused, refused} =
             Successor.intake(
               dir: @dir,
               ggen_igniter_dir: @ggen_dir,
               env: env,
               out_dir: tmp_dir("v23h_f3")
             )

    assert refused["standing"] == "REFUSED(llm_credential_present)"
    assert refused["broken_term"] == "mu_on_O"
    assert refused["detail"]["variables"] == ["ANTHROPIC_API_KEY"]
  end

  # ------------------------------------------------------------------ successor_law.py

  test "successor_law.py admits the committed successor and refuses a smuggled WorkOrder (real python3)" do
    law = Path.join(@courts, "successor_law.py")
    {out, code} = System.cmd("python3", [law, "--xaas", @repo], stderr_to_stdout: true)
    assert code == 0, out
    assert out =~ "L5 compiler output: 7 WorkOrders = 7 required"
    assert out =~ "L9 intake: frontier 7 eligible"

    goal = File.read!(Path.join(@dir, "goal.ttl"))

    smuggled =
      Path.join(tmp_dir("v23h_law"), "goal.ttl")
      |> tap(
        &File.write!(&1, goal <> "\nv23:WO-HAND a sj:WorkOrder ; sj:checkpointOf v23:GC24-2 .\n")
      )

    {out, code} =
      System.cmd("python3", [law, "--xaas", @repo, "--successor-goal", smuggled],
        stderr_to_stdout: true
      )

    assert code == 1
    assert out =~ "REFUSED: GC23-12 L1 hand-authored WorkOrder in the successor goal graph"
  end

  # ------------------------------------------------------------------ successor_acceptance.sh

  test "successor_acceptance.sh: only a committed ACCEPTED naming the prose digest accepts (real git, real sh)" do
    repo = tmp_dir("v23h_accept")
    dir = Path.join(repo, "docs/sjira/v26.9.23/successor")
    File.mkdir_p!(dir)
    File.cp!(Path.join(@repo, @prose_rel), Path.join(repo, @prose_rel))
    accepted = Path.join(dir, "ACCEPTED")
    script = Path.join(@courts, "successor_acceptance.sh")
    judge = fn -> System.cmd("sh", [script, repo], stderr_to_stdout: true) end

    sha =
      Base.encode16(:crypto.hash(:sha256, File.read!(Path.join(repo, @prose_rel))), case: :lower)

    {_, 0} = git(repo, ["init", "-q"])

    # the prose is not committed: nothing to accept
    assert {out, 1} = judge.()
    assert out =~ "REFUSED: GC23-12 successor prose"

    {_, 0} = git(repo, ["add", "-A"])
    {_, 0} = git(repo, ["commit", "-q", "-m", "prose"])

    assert {out, 77} = judge.()

    assert out =~
             ~r/^BLOCKED\(operator_acceptance\): .*ACCEPTED is absent \(broken_term R_missing_authority\)$/m

    File.write!(accepted, "sha256:#{sha}\n")
    assert {out, 77} = judge.()
    assert out =~ "exists but is not committed"

    File.write!(accepted, "sha256:#{String.duplicate("0", 64)}\n")
    {_, 0} = git(repo, ["add", "-A"])
    {_, 0} = git(repo, ["commit", "-q", "-m", "stale"])
    assert {out, 77} = judge.()
    assert out =~ "(stale acceptance) (broken_term R_missing_authority)"

    File.write!(accepted, "accepted by the operator: sha256:#{sha}\n")
    {_, 0} = git(repo, ["commit", "-q", "-am", "accept"])
    assert {out, 0} = judge.()
    assert out =~ "ACCEPTED: GC23-12 successor prose sha256:#{sha}"

    # a local edit of the accepted file after the commit is not the operator's act
    File.write!(accepted, "sha256:#{sha}\nedited\n")
    assert {out, 77} = judge.()
    assert out =~ "differs from its committed bytes"
  end

  # ------------------------------------------------------------------ the real intake

  describe "the real intake against the ggen_igniter checkout" do
    if not @ggen_ready do
      @describetag skip:
                     "ggen_igniter checkout #{@ggen_dir} lacks mix semantic_jira.descriptor or Bootstrap.Graph"
    end

    @tag timeout: 600_000
    test "Successor.check/1 recomputes the committed intake byte for byte (real graph-side mix processes)" do
      assert {:ok, summary} =
               Successor.check(dir: @dir, ggen_igniter_dir: @ggen_dir, env: no_llm_env())

      assert summary["check"] == "outputs recompute byte-identically"
      assert summary["standing"] == "UNSUPPORTED(provider_capability)"
      assert summary["work_orders"] == 7
      assert summary["eligible"] == 7
      assert summary["items"] == %{"UNSUPPORTED(provider_capability)" => 7}

      resolution = Path.join(@dir, "intake/resolution.json") |> File.read!() |> Jason.decode!()
      frontier = Path.join(@dir, "intake/frontier.json") |> File.read!() |> Jason.decode!()
      descriptor = Path.join(@dir, "intake/descriptor.json") |> File.read!() |> Jason.decode!()
      first = hd(frontier["eligible"])["identity"]
      assert resolution["first"]["order"] == first
      assert descriptor["bridge"]["identity"] == first
      assert descriptor["provider"] == "recipe"
    end

    @tag timeout: 600_000
    test "a drifted committed output is REFUSED(output_drift) naming the file" do
      out = tmp_dir("v23h_drift")

      for name <- Successor.outputs(),
          do: File.cp!(Path.join([@dir, "intake", name]), Path.join(out, name))

      File.write!(Path.join(out, "resolution.json"), "{}\n")

      assert {:refused, refused} =
               Successor.check(
                 dir: @dir,
                 ggen_igniter_dir: @ggen_dir,
                 out_dir: out,
                 env: no_llm_env()
               )

      assert refused["standing"] == "REFUSED(output_drift)"
      assert refused["detail"]["files"] == ["resolution.json"]
    end
  end
end
