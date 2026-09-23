defmodule Xaas.Ultracode.SemanticDriveTest do
  @moduledoc """
  Chicago qualification of the first no-LLM KNOWN episode
  (`Xaas.Ultracode.SemanticDrive`, `Xaas.Ultracode.SemanticDrive.Episode`,
  `mix xaas.episode`; GC-26.9.23 GC23-4..GC23-8, PRD PR-008..PR-012).

  Every collaborator is real:

    * the graph side is the ggen_igniter checkout named by
      `GGEN_IGNITER_DIR` -- real `mix semantic_jira.frontier` /
      `descriptor` / `xaas_receipt` / `reconcile` and `mix run` of
      `scripts/sa2a_route_task.exs` OS processes, compiled into a PRIVATE
      APFS clone of that checkout's `_build/test` (its build is never
      written);
    * the subject is a real `git clone --local` of that checkout's
      repository in a tmp dir, with a real episode branch made by
      `Episode.prepare/1` (git plumbing, deterministic drift commit);
    * XaaS runs on the real sandboxed Postgres (`Run`/`Epoch`/`Receipt`),
      the real `SemanticWork.materialize/2`, the real `RecipeWorker`
      (`recipe:mix-format`, the target toolchain), the real `Lease`
      fabric court and a real independent `Verifier.run/2` of the
      registered `ggen-igniter-format` suite;
    * the R projection is checked by the real fleet validator
      (`python3 ~/.claude/dfcm/validate_receipt.py`), the OCEL by the real
      `Xaas.Ultracode.Ocel.Validator` and by real `pm4py.read_ocel2_json`;
    * the no-LLM guard is exercised on real environments and a real
      executable named `claude` in a tmp PATH dir, and through a real
      `mix xaas.episode --check-env` subprocess under
      `docs/sjira/v26.9.23/courts/no_llm_env.sh`.

  Skips (never fails) when `GGEN_IGNITER_DIR` is unset or its checkout
  lacks the restored `mix semantic_jira.*` surface (FRI-T6).
  """

  use ExUnit.Case, async: false

  require Ash.Query

  alias Xaas.Ultracode.{Ocel.Validator, Run, SemanticDrive}
  alias Xaas.Ultracode.SemanticDrive.Episode

  @moduletag timeout: 1_200_000

  @ggen_dir System.get_env("GGEN_IGNITER_DIR")
  @drift "lib/ggen_igniter/semantic_jira/cli.ex"
  @validator Path.expand("~/.claude/dfcm/validate_receipt.py")
  @no_llm_env Path.expand("../../../docs/sjira/v26.9.23/courts/no_llm_env.sh", __DIR__)

  @moduletag skip:
               (cond do
                  is_nil(@ggen_dir) ->
                    "GGEN_IGNITER_DIR unset (the graph-side checkout under judgement)"

                  not File.regular?(
                    Path.join(@ggen_dir, "lib/mix/tasks/semantic_jira.descriptor.ex")
                  ) ->
                    "GGEN_IGNITER_DIR #{@ggen_dir} lacks the restored mix semantic_jira.* surface (FRI-T6)"

                  true ->
                    false
                end)

  setup_all do
    base = mktmp("drive-all")
    {:ok, repo} = Episode.repo_root(@ggen_dir)
    subject = Path.join(base, "subject")
    {_, 0} = System.cmd("git", ["clone", "-q", "--local", "--no-checkout", repo, subject])
    build = Path.join(base, "build")
    File.mkdir_p!(build)
    {_, 0} = System.cmd("cp", ["-cRp", Path.join(@ggen_dir, "_build/test"), build])
    head = git!(@ggen_dir, ["rev-parse", "HEAD"])
    on_exit(fn -> File.rm_rf(base) end)
    %{subject: subject, build: Path.join(build, "test"), base_sha: head}
  end

  setup %{subject: subject} do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    original = %{
      repos: Application.get_env(:xaas, :ultracode_repos),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      suites: Application.get_env(:xaas, :ultracode_verifier_suites)
    }

    on_exit(fn ->
      restore_env(:ultracode_repos, original.repos)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_verifier_suites, original.suites)
    end)

    root = canonical(mktmp("drive-runs"))
    Application.put_env(:xaas, :ultracode_repos, %{"ggen_igniter" => subject})
    Application.put_env(:xaas, :ultracode_worktree_root, root)

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      "ggen-igniter-format" => Mix.Tasks.Xaas.Episode.court_suite()
    })

    %{root: root}
  end

  # ------------------------------------------------------------------
  # the reference KNOWN episode, end to end
  # ------------------------------------------------------------------

  test "a prepared episode drives EP-A to ALIVE: equal hop digests, sealed + independently verified receipt, admitted R, conformant OCEL, closed frontier",
       ctx do
    name = episode_name("full")
    {facts, out} = prepare!(ctx, name)
    subject_sha = facts["subject_sha"]
    pin = Episode.branch(name) <> "-receipt"

    assert {:ok, summary} = drive(ctx, out, pin_ref: pin)

    assert summary["standing"] == "ALIVE"
    assert summary["order"] == "EP-A"
    assert summary["dependents"] == ["EP-B"]
    assert summary["frontier"] == %{"left" => ["EP-A"], "entered" => ["EP-B"]}
    assert summary["no_llm_guard"] == "passed"

    assert summary["provider"] == %{
             "provider" => "recipe",
             "executor" => "recipe-worker",
             "capability" => "recipe:mix-format"
           }

    refute File.exists?(Path.join(out, "refused.json"))

    for artifact <-
          ~w(hops.json receipt.json receipt.r.json ocel.json ocel2.json frontier_before.json frontier_after.json verification.json reconciler_receipt.json sa2a_task.json descriptor.json contract.json drive.json) do
      assert File.regular?(Path.join(out, artifact)), artifact
    end

    # GC23-4: five hops, one tuple digest and one request digest, replayable
    hops = read!(out, "hops.json")
    assert Enum.map(hops["hops"], & &1["hop"]) == SemanticDrive.hops()
    assert hops["hops"] |> Enum.map(& &1["digest"]) |> Enum.uniq() |> length() == 1
    assert hops["hops"] |> Enum.map(& &1["request_digest"]) |> Enum.uniq() |> length() == 1

    assert {:ok, %{"tuple_digest" => tuple_digest, "request_digest" => request_digest}} =
             SemanticDrive.verify_hops(hops)

    assert tuple_digest == summary["tuple_digest"]
    assert request_digest == summary["request_digest"]
    assert hd(hops["hops"])["request"]["work_order"] == "EP-A"

    assert hd(hops["hops"])["request"]["graph_digest"] ==
             Enum.find(
               read!(out, "frontier_before.json")["eligible"],
               &(&1["identity"] == "EP-A")
             )[
               "work_order_digest"
             ]

    # F2 on this run: a field mutated under its recorded digest, and a
    # consistent forgery at one hop, are both refused
    underneath = update_in(hops, ["hops", Access.at(1), "tuple", "postcondition"], &(&1 <> "!"))

    assert {:refused,
            %{
              "standing" => "REFUSED(tuple_digest_mismatch)",
              "broken_term" => "admission_vacuous",
              "hop" => "sa2a"
            }} = SemanticDrive.verify_hops(underneath)

    forged =
      update_in(hops, ["hops", Access.at(3)], fn hop ->
        tuple = Map.update!(hop["tuple"], "subject", &(&1 <> "#forged"))
        request = Map.update!(hop["request"], "subject", &(&1 <> "#forged"))

        Map.merge(hop, %{
          "tuple" => tuple,
          "digest" => Xaas.Sa2a.Route.digest(tuple),
          "request" => request,
          "request_digest" => SemanticDrive.request_digest(request)
        })
      end)

    assert {:refused,
            %{"reason" => "tuple_digest_mismatch", "hop" => "provider", "detail" => detail}} =
             SemanticDrive.verify_hops(forged)

    assert detail["field"] == "subject"

    # the live conservation law on this run's own carriers
    order = read!(out, "work.json")["work_orders"] |> hd()
    task = read!(out, "sa2a_task.json")
    contract = read!(out, "contract.json")
    assert {:ok, ^tuple_digest} = SemanticDrive.conserve(order, task, contract)

    mutated_task =
      update_in(task, ["input", Access.at(0), "data", "tuple", "postcondition"], &(&1 <> "!"))

    assert {:refused,
            %{
              "standing" => "REFUSED(tuple_digest_mismatch)",
              "detail" => %{"field" => "postcondition"}
            }} = SemanticDrive.conserve(order, mutated_task, contract)

    # GC23-5: the receipt's executor is the deterministic provider
    receipt = read!(out, "receipt.json")
    r = read!(out, "receipt.r.json")
    assert receipt["outcome"] == "alive"
    assert receipt["head_verified"] == true
    assert r["authority"]["actor"] == "recipe-worker"
    assert Enum.at(hops["hops"], 3)["executor"] == "recipe-worker"

    # GC23-6: one recipe-worker commit on the subject; the independent
    # court passed at the head and the revert falsifier killed it
    head = receipt["final_head"]
    assert git!(ctx.subject, ["rev-parse", head <> "^"]) == subject_sha
    assert git!(ctx.subject, ["log", "-1", "--format=%an", head]) == "recipe-worker"
    assert git!(ctx.subject, ["diff", "--name-only", subject_sha, head]) == @drift
    assert git!(ctx.subject, ["rev-parse", "refs/heads/" <> pin]) == head

    verification = read!(out, "verification.json")
    assert verification["independent"]["status"] == "pass"
    assert verification["independent"]["head"] == head
    assert verification["revert_falsifier"]["verdict"] == "killed"
    assert verification["revert_falsifier"]["court"]["status"] == "fail"

    # GC23-7: the R projection is ALIVE and ADMITTED by the fleet validator
    assert r["standing"]["value"] == "ALIVE"
    assert r["identity"]["subject_sha"] == head
    assert File.regular?(@validator), "fleet receipt validator missing at #{@validator}"

    {validated, code} =
      System.cmd("python3", [@validator, Path.join(out, "receipt.r.json")],
        stderr_to_stdout: true
      )

    assert code == 0, validated
    assert validated =~ "ADMITTED"

    # ... and the OCEL is conformant under the xaas court and pm4py
    assert {:ok, %{"event_count" => events}} =
             Validator.validate_file(Path.join(out, "ocel.json"))

    reached = summary["ocel"]["reached"]

    assert reached ==
             ~w(WorkOrderCreated CapabilityResolved LeaseAcquired ActuationStarted ActuationCompleted VerificationCompleted ReceiptSealed StandingChanged FrontierChanged)

    assert summary["ocel"]["equivalent"] == true

    {pm4py, 0} =
      System.cmd(
        "python3",
        [
          "-c",
          "import pm4py, sys; o = pm4py.read_ocel2_json(sys.argv[1]); " <>
            "print(len(o.events), ' '.join(sorted(o.events['ocel:activity'].unique())))",
          Path.join(out, "ocel2.json")
        ],
        stderr_to_stdout: true
      )

    [count | classes] = pm4py |> String.split("\n", trim: true) |> List.last() |> String.split()
    assert String.to_integer(count) == events
    assert Enum.sort(classes) == Enum.sort(reached)

    # GC23-8: EP-A left the frontier ALIVE, EP-B (fenced before) entered;
    # the ledger holds exactly that one transition
    before = read!(out, "frontier_before.json")
    after_frontier = read!(out, "frontier_after.json")
    assert ids(before["eligible"]) == ["EP-A"]
    assert "EP-B" in ids(before["blocked"])
    assert ids(after_frontier["eligible"]) == ["EP-B"]
    assert after_frontier["standings"] == %{"EP-A" => "ALIVE", "EP-B" => "UNKNOWN"}

    assert [%{"identity" => "EP-A", "from" => "UNKNOWN", "to" => "ALIVE"}] =
             out
             |> Path.join("ledger.ndjson")
             |> File.read!()
             |> String.split("\n", trim: true)
             |> Enum.map(&Jason.decode!/1)

    # the epoch and verification worktrees were removed
    assert File.ls!(ctx.root) == []
  end

  # ------------------------------------------------------------------
  # typed refusals
  # ------------------------------------------------------------------

  test "an unregistered capability is REFUSED(unregistered_capability) at resolution: no Run, no ledger change",
       ctx do
    {_facts, out} = prepare!(ctx, episode_name("unreg"))

    rewrite_order(out, "EP-A", fn row ->
      Map.put(row, "requires_capability", "recipe:not-registered")
    end)

    assert {:refused,
            %{
              "standing" => "REFUSED(unregistered_capability)",
              "broken_term" => "mu_on_O",
              "hop" => "resolve",
              "detail" => %{"capability" => "recipe:not-registered"}
            }} = drive(ctx, out)

    assert Ash.read!(Run, action: :read_unscoped, authorize?: false) == []
    assert File.read!(Path.join(out, "ledger.ndjson")) == ""
    assert %{"outcome" => %{"reason" => "unregistered_capability"}} = read!(out, "refused.json")
    refute File.exists?(Path.join(out, "receipt.json"))
  end

  test "an LLM credential or an LLM binary on PATH is REFUSED(llm_credential_present) before any hop",
       ctx do
    {_facts, out} = prepare!(ctx, episode_name("llm"))

    assert {:refused,
            %{
              "standing" => "REFUSED(llm_credential_present)",
              "broken_term" => "mu_on_O",
              "hop" => "guard",
              "detail" => %{"variables" => ["ANTHROPIC_API_KEY", "CLAUDECODE"], "binaries" => []}
            }} =
             drive(ctx, out,
               env: %{"ANTHROPIC_API_KEY" => "x", "CLAUDECODE" => "1", "PATH" => "/usr/bin:/bin"}
             )

    refute File.exists?(Path.join(out, "frontier_before.json"))
    assert %{"hops" => []} = read!(out, "refused.json")

    bin = mktmp("llm-bin")
    claude = Path.join(bin, "claude")
    File.write!(claude, "#!/bin/sh\nexit 0\n")
    File.chmod!(claude, 0o755)

    assert {:refused, %{"reason" => "llm_credential_present", "detail" => detail}} =
             SemanticDrive.no_llm_guard(%{"PATH" => "#{bin}:/usr/bin:/bin"})

    assert detail == %{"variables" => [], "binaries" => [claude]}
    assert :ok = SemanticDrive.no_llm_guard(%{"PATH" => "/usr/bin:/bin", "HOME" => bin})

    # the real task under the F3 court environment: clean passes, exposed refuses
    {clean, 0} = episode_env([], ["--check-env"])
    assert clean =~ ~s("no_llm_guard":"passed")
    {exposed, 3} = episode_env(["ANTHROPIC_API_KEY=x"], ["--check-env"])
    assert exposed =~ "REFUSED(llm_credential_present)"
  end

  test "a subject with no drift is REFUSED(no_delta) by the provider: no commit, no ledger change, EP-A stays on the frontier",
       ctx do
    {_facts, out} = prepare!(ctx, episode_name("nodelta"))
    pin = episode_name("nodelta-pin")

    # F4: the required consequence is absent from the subject
    rewrite_order(out, "EP-A", &Map.put(&1, "base_sha", ctx.base_sha))

    assert {:refused,
            %{
              "standing" => "REFUSED(no_delta)",
              "broken_term" => "R_missing_consequence",
              "hop" => "provider"
            }} = drive(ctx, out, pin_ref: pin)

    assert File.read!(Path.join(out, "ledger.ndjson")) == ""
    refused = read!(out, "refused.json")
    assert ids(refused["frontier_before"]["eligible"]) == ["EP-A"]
    assert Enum.map(refused["hops"], & &1["hop"]) == ~w(sjira sa2a xaas)

    {_, code} =
      System.cmd("git", ["-C", ctx.subject, "rev-parse", "--verify", "-q", "refs/heads/" <> pin])

    assert code != 0
    assert File.ls!(ctx.root) == []
  end

  test "Episode.prepare is deterministic and never moves a diverged branch", ctx do
    name = episode_name("prep")
    {facts, _out} = prepare!(ctx, name)
    {again, _out} = prepare!(ctx, name)
    assert again["subject_sha"] == facts["subject_sha"]

    assert git!(ctx.subject, [
             "show",
             "--format=%an|%ad",
             "--date=iso-strict",
             "-s",
             facts["subject_sha"]
           ]) ==
             "xaas-episode|2026-09-23T00:00:00Z"

    assert {:refused, %{"reason" => "branch_diverged", "broken_term" => "mu_unlawful"}} =
             Episode.prepare(
               repo: ctx.subject,
               name: name,
               base: ctx.base_sha,
               drift: "lib/ggen_igniter/semantic_jira/reconciler.ex",
               out_dir: mktmp("prep-diverged")
             )

    assert git!(ctx.subject, ["rev-parse", "refs/heads/" <> Episode.branch(name)]) ==
             facts["subject_sha"]

    assert {:refused, %{"reason" => "invalid_drift_path"}} =
             Episode.prepare(
               repo: ctx.subject,
               name: episode_name("bad"),
               base: ctx.base_sha,
               drift: "../outside.ex",
               out_dir: mktmp("prep-bad")
             )

    assert {:ok, "defmodule  A.B  do\n  x\nend\ndefmodule C do\nend\n"} =
             Episode.drift("defmodule A.B do\n  x\nend\ndefmodule C do\nend\n")

    assert Episode.drift("x = 1\n") == :no_drift_site
  end

  # ------------------------------------------------------------------
  # helpers
  # ------------------------------------------------------------------

  defp prepare!(ctx, name) do
    out = mktmp("episode-" <> name)

    {:ok, facts} =
      Episode.prepare(
        repo: ctx.subject,
        name: name,
        base: ctx.base_sha,
        drift: @drift,
        out_dir: out
      )

    {facts, out}
  end

  defp drive(ctx, out, opts \\ []) do
    SemanticDrive.drive(
      Keyword.merge(
        [
          ggen_igniter_dir: @ggen_dir,
          work_graph: Path.join(out, "work.json"),
          ledger: Path.join(out, "ledger.ndjson"),
          order: "EP-A",
          out_dir: out,
          ggen_build_path: ctx.build,
          env: clean_env()
        ],
        opts
      )
    )
  end

  # The guard judges the environment it is handed: the test process runs
  # under the operator's shell (which may hold model credentials), so the
  # drive is handed a real clean environment -- the one the F3 court builds.
  defp clean_env do
    System.get_env()
    |> Enum.reject(fn {name, _} ->
      name == "CLAUDECODE" or
        Enum.any?(SemanticDrive.llm_variables().prefixes, &String.starts_with?(name, &1))
    end)
    |> Map.new()
    |> Map.put("PATH", "/usr/bin:/bin")
  end

  defp episode_env(assignments, args) do
    System.cmd(
      "sh",
      [@no_llm_env | assignments] ++ ["--", "mix", "xaas.episode" | args],
      env: [{"MIX_ENV", "test"}],
      stderr_to_stdout: true,
      cd: File.cwd!()
    )
  end

  defp rewrite_order(out, identity, fun) do
    path = Path.join(out, "work.json")

    graph =
      path
      |> File.read!()
      |> Jason.decode!()
      |> Map.update!("work_orders", fn rows ->
        Enum.map(rows, fn row -> if row["identity"] == identity, do: fun.(row), else: row end)
      end)

    File.write!(path, Jason.encode!(graph))
  end

  defp episode_name(label),
    do: "t-#{label}-#{System.unique_integer([:positive])}"

  defp ids(entries), do: Enum.map(entries || [], & &1["identity"])

  defp read!(out, name), do: out |> Path.join(name) |> File.read!() |> Jason.decode!()

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)

  defp mktmp(label) do
    dir =
      Path.join(System.tmp_dir!(), "xaas-drive-#{label}-#{System.unique_integer([:positive])}")

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp canonical(path) do
    {out, 0} = System.cmd("pwd", ["-P"], cd: path)
    String.trim(out)
  end
end

defmodule Xaas.Ultracode.SemanticDriveToolchainTest do
  @moduledoc """
  Chicago qualification of `Xaas.Ultracode.SemanticDrive.graph_toolchain/2`,
  the graph-side toolchain resolution shared by the drive and the GC23-8
  court (`mix xaas.episode --graph-toolchain`). Needs no ggen_igniter
  checkout, so it never skips:

    * the build-manifest branch reads the REAL manifest the real Mix wrote
      for this very test run (`_build/test/lib/xaas/.mix/compile.elixir_scm`)
      and runs the resolved `mix` as a real subprocess on the resolved PATH;
    * the fallback branches read manifests in Mix's own term format (the
      real manifest decoded, one field changed, re-encoded) in real tmp
      build dirs, and a real `mix --version` subprocess.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.SemanticDrive

  @xaas_root Path.expand("../../..", __DIR__)

  test "a build compiled by this node's Elixir on this ERTS resolves to that Elixir (source build_manifest), and it runs" do
    build = Mix.Project.build_path()
    assert {:ok, t} = SemanticDrive.graph_toolchain(@xaas_root, build)

    assert t["source"] == "build_manifest"
    assert t["elixir"] == System.version()

    assert t["build_compiler"] == %{
             "elixir" => System.version(),
             "otp" => to_string(:erlang.system_info(:otp_release))
           }

    assert t["build_manifest"] == Path.join([build, "lib", "xaas", ".mix", "compile.elixir_scm"])
    assert t["erlang"] == to_string(:erlang.system_info(:otp_release))
    assert String.starts_with?(t["path"], Path.dirname(t["mix"]) <> ":")

    {out, 0} =
      System.cmd(t["mix"], ["--version"],
        env: [{"PATH", t["path"]}, {"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    assert out =~ "Mix #{System.version()}"
  end

  test "a build compiled by an Elixir with no install falls back to the checkout's pin, recording why" do
    {dir, build} =
      checkout("absent", fn {vsn, {_elixir, otp}, scm} ->
        {vsn, {"0.0.0-absent", otp}, scm}
      end)

    assert {:ok, t} = SemanticDrive.graph_toolchain(dir, build)
    refute t["source"] == "build_manifest"
    assert t["build_compiler"]["elixir"] == "0.0.0-absent"
    assert t["build_manifest_unused"] =~ "no Elixir 0.0.0-absent install"
    assert_runs(t)
  end

  test "a build compiled on another OTP release falls back to the pin (an ERTS switch recompiles everything)" do
    {dir, build} =
      checkout("otp", fn {vsn, {elixir, _otp}, scm} ->
        {vsn, {elixir, ~c"1"}, scm}
      end)

    assert {:ok, t} = SemanticDrive.graph_toolchain(dir, build)
    refute t["source"] == "build_manifest"
    assert t["build_manifest_unused"] =~ "compiled on OTP 1"
    assert_runs(t)
  end

  # A real asdf Erlang install whose OTP release differs from this node's,
  # with a real `<vsn>-otp-<release>` Elixir install for it (e.g. the
  # ggen_igniter pin 1.18.4-otp-27 judged from an OTP 28 xaas node).
  @asdf Path.expand(System.get_env("ASDF_DATA_DIR") || "~/.asdf")
  @node_otp to_string(:erlang.system_info(:otp_release))
  @foreign (for erl <- Enum.sort(Path.wildcard(Path.join(@asdf, "installs/erlang/*/releases/*"))),
                otp = Path.basename(erl),
                otp != @node_otp,
                File.exists?(Path.join([Path.dirname(Path.dirname(erl)), "bin", "erl"])),
                ex <- Enum.sort(Path.wildcard(Path.join(@asdf, "installs/elixir/*-otp-#{otp}"))),
                File.exists?(Path.join([ex, "bin", "mix"])) do
              {Path.dirname(Path.dirname(erl)), otp,
               ex |> Path.basename() |> String.split("-otp-") |> hd()}
            end)
           |> List.last()

  @tag skip:
         if(@foreign == nil,
           do: "no asdf Erlang install of another OTP release with a matching Elixir install"
         )
  test "a build compiled on another OTP release runs under an installed ERTS of that release (source build_manifest)" do
    {install, otp, elixir} = @foreign

    # The manifest in the shape the pinned Mix (1.18/1.19) writes, as in the
    # real ggen_igniter-int `_build/test`: {1, {"1.18.4", ~c"27"}, Mix.SCM.Path}.
    {dir, build} =
      checkout("foreign", fn real -> {1, {elixir, String.to_charlist(otp)}, elem(real, 2)} end)

    assert {:ok, t} = SemanticDrive.graph_toolchain(dir, build)
    assert t["source"] == "build_manifest"
    assert t["elixir"] == elixir
    assert t["erlang"] == otp
    assert t["erl"] == Path.join([install, "bin", "erl"])
    assert t["erts"] =~ "build_manifest OTP #{otp}"

    # A fresh MIX_HOME (durable configuration, as the courts pass it): the
    # ambient archives belong to the node's Elixir, not the resolved one.
    mix_home = Path.join(dir, "mix_home")
    File.mkdir_p!(mix_home)

    {out, 0} =
      System.cmd(t["mix"], ["--version"],
        env: [{"PATH", t["path"]}, {"MIX_ENV", "test"}, {"MIX_HOME", mix_home}],
        stderr_to_stdout: true
      )

    assert out =~ "Mix #{elixir}"

    {out, 0} =
      System.cmd(
        t["erl"],
        ["-noshell", "-eval", "io:format(\"~s\", [erlang:system_info(otp_release)]), halt()."],
        env: [{"PATH", t["path"]}]
      )

    assert out == otp
  end

  test "no build at all falls back to the pin" do
    {dir, _build} = checkout("none", & &1)
    empty = Path.join(dir, "_build/elsewhere")

    assert {:ok, t} = SemanticDrive.graph_toolchain(dir, empty)
    refute t["source"] == "build_manifest"
    assert t["build_compiler"] == nil
    assert t["build_manifest_unused"] =~ "no readable build manifest"
    assert_runs(t)
  end

  # A tmp checkout (mix.exs naming app :demo_graph, no .tool-versions) with
  # a build dir whose manifest is the REAL xaas manifest, transformed.
  defp checkout(label, transform) do
    dir =
      Path.join(System.tmp_dir!(), "xaas-graph-tc-#{label}-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(dir) end)
    File.mkdir_p!(dir)

    File.write!(
      Path.join(dir, "mix.exs"),
      "defmodule Demo.MixProject do\n  def project, do: [app: :demo_graph]\nend\n"
    )

    real =
      [Mix.Project.build_path(), "lib", "xaas", ".mix", "compile.elixir_scm"]
      |> Path.join()
      |> File.read!()
      |> :erlang.binary_to_term()

    build = Path.join(dir, "_build/test")
    manifest = Path.join([build, "lib", "demo_graph", ".mix", "compile.elixir_scm"])
    File.mkdir_p!(Path.dirname(manifest))
    File.write!(manifest, :erlang.term_to_binary(transform.(real)))
    {dir, build}
  end

  defp assert_runs(t) do
    {out, 0} =
      System.cmd(t["mix"], ["--version"],
        env: [{"PATH", t["path"]}, {"MIX_ENV", "test"}],
        stderr_to_stdout: true
      )

    assert out =~ "Mix "
  end
end
