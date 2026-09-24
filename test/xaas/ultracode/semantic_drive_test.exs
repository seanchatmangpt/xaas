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

    assert detail == %{
             "variables" => [],
             "binaries" => [claude],
             "providers" => ["claude-code"],
             "unadmitted" => []
           }

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
  # under the operator's shell (which may hold model credentials and any
  # number of unadmitted variables), so the drive is handed this process's
  # environment projected onto the fail-closed no-LLM policy -- the names the
  # F3 court builds (priv/no_llm/policy.json).
  defp clean_env do
    SemanticDrive.no_llm_environment(System.get_env())
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
      checkout("absent", fn manifest ->
        {_elixir, otp} = elem(manifest, 1)
        put_elem(manifest, 1, {"0.0.0-absent", otp})
      end)

    assert {:ok, t} = SemanticDrive.graph_toolchain(dir, build)
    refute t["source"] == "build_manifest"
    assert t["build_compiler"]["elixir"] == "0.0.0-absent"
    assert t["build_manifest_unused"] =~ "no Elixir 0.0.0-absent install"
    assert_runs(t)
  end

  test "a build compiled on another OTP release falls back to the pin (an ERTS switch recompiles everything)" do
    {dir, build} =
      checkout("otp", fn manifest ->
        {elixir, _otp} = elem(manifest, 1)
        put_elem(manifest, 1, {elixir, ~c"1"})
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

defmodule Xaas.Ultracode.SemanticDriveNoLlmGuardTest do
  @moduledoc """
  Chicago qualification of the fail-closed no-LLM guard (lane R1-X-GUARD;
  GC-26.9.23 GC23-5, PRD PR-009, ARD F3): `SemanticDrive.no_llm_guard/1`
  over `Xaas.Ultracode.NoLlmPolicy`, compiled from the policy DATA
  `priv/no_llm/policy.json` that `docs/sjira/v26.9.23/courts/no_llm_env.sh`
  also builds the court environment from.

  Driver-verified defect this module falsifies: the guard was a hard-coded
  denylist, so `%{"GEMINI_API_KEY" => "x", "OPENROUTER_API_KEY" => "y",
  "PATH" => "/usr/bin"}` returned `:ok` while `ANTHROPIC_API_KEY` was
  refused.

  Every collaborator is real: the provider table is read from the data file
  on disk by this test (not from the module under test), provider binaries
  are real executables in tmp PATH dirs, the builder is the real
  `no_llm_env.sh` in a real `sh` process, and the task is a real
  `mix xaas.episode --check-env` OS process under it. No database, no
  graph-side checkout: this module never skips.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{NoLlmPolicy, SemanticDrive}

  # real `mix xaas.episode` OS processes (4 in one test) on a machine shared
  # with other executors: the 60 s ExUnit default timed one out at load ~100
  @moduletag timeout: 600_000

  @root Path.expand("../../..", __DIR__)
  @policy_file Path.join(@root, "priv/no_llm/policy.json")
  @no_llm_env Path.join(@root, "docs/sjira/v26.9.23/courts/no_llm_env.sh")
  @secret "r1-x-guard-secret-value-9f2c"

  defp data, do: @policy_file |> File.read!() |> Jason.decode!()

  defp admitted_env do
    data()["environment"]
    |> Map.new(&{&1["name"], "v"})
    |> Map.put("PATH", "/usr/bin:/bin")
  end

  defp refused!(env) do
    assert {:refused, typed} = SemanticDrive.no_llm_guard(env)
    assert typed["broken_term"] == "mu_on_O"
    assert typed["hop"] == "guard"
    assert typed["standing"] == "REFUSED(#{typed["reason"]})"
    refute Jason.encode!(typed) =~ @secret, "a refusal must name variables, never values"
    typed
  end

  defp tmp_dir(label) do
    dir = Path.join(System.tmp_dir!(), "no-llm-#{label}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp parse_env(out) do
    out
    |> String.split("\n", trim: true)
    |> Map.new(fn line ->
      [name, value] = String.split(line, "=", parts: 2)
      {name, value}
    end)
  end

  defp builder(assignments, command, caller_env \\ []) do
    System.cmd("sh", [@no_llm_env | assignments] ++ ["--" | command],
      env: caller_env,
      stderr_to_stdout: true,
      cd: @root
    )
  end

  test "the guard is compiled from the policy data on disk" do
    assert NoLlmPolicy.path() == @policy_file
    assert NoLlmPolicy.policy() == data()

    assert NoLlmPolicy.admitted() ==
             data()["environment"] |> Enum.map(& &1["name"]) |> Enum.sort()

    assert length(data()["providers"]) >= 18
  end

  test "the driver-verified defect: GEMINI_API_KEY and OPENROUTER_API_KEY are refused like ANTHROPIC_API_KEY" do
    typed =
      refused!(%{
        "GEMINI_API_KEY" => @secret,
        "OPENROUTER_API_KEY" => @secret,
        "PATH" => "/usr/bin"
      })

    assert typed["standing"] == "REFUSED(llm_credential_present)"

    assert typed["detail"] == %{
             "variables" => ["GEMINI_API_KEY", "OPENROUTER_API_KEY"],
             "binaries" => [],
             "providers" => ["google-gemini", "openrouter"],
             "unadmitted" => []
           }

    anthropic = refused!(%{"ANTHROPIC_API_KEY" => @secret, "PATH" => "/usr/bin:/bin"})
    assert anthropic["standing"] == "REFUSED(llm_credential_present)"
    assert anthropic["detail"]["variables"] == ["ANTHROPIC_API_KEY"]
    assert anthropic["detail"]["providers"] == ["anthropic"]
  end

  test "every provider variable of the data file is refused REFUSED(llm_credential_present), naming the provider" do
    rows =
      for provider <- data()["providers"],
          variable <-
            Enum.map(provider["prefixes"], &(&1 <> "R1_GUARD_PROBE")) ++ provider["names"],
          do: {provider["id"], variable}

    assert length(rows) >= 40

    for {id, variable} <- rows do
      typed = refused!(Map.put(admitted_env(), variable, @secret))
      assert typed["standing"] == "REFUSED(llm_credential_present)", variable
      assert typed["detail"]["variables"] == [variable]
      assert id in typed["detail"]["providers"], inspect({id, variable, typed["detail"]})
      assert typed["detail"]["unadmitted"] == []
    end
  end

  test "every provider binary of the data file on PATH is refused, naming the provider" do
    dir = tmp_dir("bin")

    for provider <- data()["providers"], binary <- provider["binaries"] do
      file = Path.join(dir, binary)
      File.write!(file, "#!/bin/sh\nexit 0\n")

      # not executable: no refusal (the check is on executables, not names)
      File.chmod!(file, 0o644)

      assert :ok =
               SemanticDrive.no_llm_guard(
                 Map.put(admitted_env(), "PATH", dir <> ":/usr/bin:/bin")
               )

      File.chmod!(file, 0o755)
      typed = refused!(Map.put(admitted_env(), "PATH", dir <> ":/usr/bin:/bin"))
      assert typed["standing"] == "REFUSED(llm_credential_present)", binary
      assert typed["detail"]["binaries"] == [file]
      assert provider["id"] in typed["detail"]["providers"], inspect({binary, typed["detail"]})
      File.rm!(file)
    end
  end

  test "an arbitrary variable no provider claims is refused REFUSED(unadmitted_environment)" do
    typed = refused!(Map.put(admitted_env(), "XAAS_R1_GUARD_UNLISTED_TOKEN", @secret))
    assert typed["standing"] == "REFUSED(unadmitted_environment)"

    assert typed["detail"] == %{
             "variables" => [],
             "binaries" => [],
             "providers" => [],
             "unadmitted" => ["XAAS_R1_GUARD_UNLISTED_TOKEN"]
           }

    # a provider variable beside it: the credential standing wins, both named
    mixed =
      refused!(
        admitted_env()
        |> Map.put("XAAS_R1_GUARD_UNLISTED_TOKEN", @secret)
        |> Map.put("MISTRAL_API_KEY", @secret)
      )

    assert mixed["standing"] == "REFUSED(llm_credential_present)"
    assert mixed["detail"]["variables"] == ["MISTRAL_API_KEY"]
    assert mixed["detail"]["unadmitted"] == ["XAAS_R1_GUARD_UNLISTED_TOKEN"]
  end

  test "the allowlisted environment passes; the admitted projection of this process's environment passes" do
    assert :ok = SemanticDrive.no_llm_guard(admitted_env())
    assert :ok = SemanticDrive.no_llm_guard(%{})

    projected =
      SemanticDrive.no_llm_environment(Map.put(System.get_env(), "GROQ_API_KEY", @secret))

    assert :ok = SemanticDrive.no_llm_guard(projected)
    assert Map.keys(projected) -- NoLlmPolicy.admitted() == []
  end

  test "unset_unadmitted/1: a real child process inherits only admitted names" do
    caller =
      Map.merge(System.get_env(), %{"GEMINI_API_KEY" => @secret, "XAAS_R1_UNLISTED" => "1"})

    unset = NoLlmPolicy.unset_unadmitted(caller)
    assert {"GEMINI_API_KEY", nil} in unset
    assert {"XAAS_R1_UNLISTED", nil} in unset
    refute Enum.any?(unset, fn {name, _} -> name in NoLlmPolicy.admitted() end)

    {out, 0} =
      System.cmd("/usr/bin/env", [],
        env: [{"GEMINI_API_KEY", @secret}, {"XAAS_R1_UNLISTED", "1"}] ++ unset
      )

    assert Map.keys(parse_env(out)) -- NoLlmPolicy.admitted() == []
  end

  test "no_llm_env.sh and the guard agree: the built environment passes, a caller credential does not survive, an assignment is refused" do
    caller =
      for e <- data()["environment"], e["origin"] == "caller_if_set", do: {e["name"], "set"}

    {out, 0} =
      builder([], ["/usr/bin/env"], caller ++ [{"GEMINI_API_KEY", @secret}, {"CLAUDECODE", "1"}])

    built = parse_env(out)
    assert :ok = SemanticDrive.no_llm_guard(built)
    refute Map.has_key?(built, "GEMINI_API_KEY")
    refute Map.has_key?(built, "CLAUDECODE")

    for {name, _} <- caller, do: assert(built[name] == "set", name)

    for e <- data()["environment"],
        e["origin"] in ["builder", "caller_or_default"],
        do: assert(Map.has_key?(built, e["name"]), e["name"])

    # every PATH directory is free of every provider binary of the data file
    for dir <- String.split(built["PATH"], ":"),
        provider <- data()["providers"],
        binary <- provider["binaries"],
        do: refute(File.exists?(Path.join(dir, binary)), Path.join(dir, binary))

    {out, 0} = builder(["GEMINI_API_KEY=x"], ["/usr/bin/env"])
    exposed = refused!(parse_env(out))
    assert exposed["standing"] == "REFUSED(llm_credential_present)"
    assert exposed["detail"]["variables"] == ["GEMINI_API_KEY"]

    # a PATH directory holding a provider binary makes the builder refuse (UNKNOWN, 75)
    dir = tmp_dir("dirty")

    for tool <- ~w(git python3),
        do: File.ln_s!(System.find_executable(tool), Path.join(dir, tool))

    File.write!(Path.join(dir, "ollama"), "#!/bin/sh\nexit 0\n")
    File.chmod!(Path.join(dir, "ollama"), 0o755)
    # resolved through symlinks, git/python3 live elsewhere: the dirty dir never reaches PATH
    {out, 0} = builder([], ["/usr/bin/env"], [{"PATH", dir <> ":" <> System.get_env("PATH")}])
    refute parse_env(out)["PATH"] =~ dir
    # a real tool file IN the dirty dir: refused
    File.rm!(Path.join(dir, "git"))
    File.cp!(System.find_executable("git") |> resolve(), Path.join(dir, "git"))
    File.chmod!(Path.join(dir, "git"), 0o755)
    {out, 75} = builder([], ["/usr/bin/env"], [{"PATH", dir <> ":" <> System.get_env("PATH")}])
    assert out =~ "UNKNOWN: no_llm_env: #{resolve_dir(dir)} holds ollama"
  end

  test "the real task under the F3 court environment: clean passes; GEMINI_API_KEY, ANTHROPIC_API_KEY and an unlisted variable are refused (exit 3)" do
    task = ["mix", "xaas.episode", "--check-env"]
    mix_env = [{"MIX_ENV", "test"}]

    {clean, 0} = builder([], task, mix_env)
    assert clean =~ ~s("no_llm_guard":"passed")

    for {assignment, standing, field, name} <- [
          {"GEMINI_API_KEY=x", "REFUSED(llm_credential_present)", "variables", "GEMINI_API_KEY"},
          {"ANTHROPIC_API_KEY=x", "REFUSED(llm_credential_present)", "variables",
           "ANTHROPIC_API_KEY"},
          {"XAAS_R1_UNLISTED=x", "REFUSED(unadmitted_environment)", "unadmitted",
           "XAAS_R1_UNLISTED"}
        ] do
      {out, 3} = builder([assignment], task, mix_env)
      typed = out |> String.split("\n", trim: true) |> List.last() |> Jason.decode!()
      assert typed["standing"] == standing, out
      assert typed["broken_term"] == "mu_on_O"
      assert typed["detail"][field] == [name]
    end
  end

  defp resolve(file) do
    case File.read_link(file) do
      {:ok, link} -> file |> Path.dirname() |> Path.join(link) |> Path.expand() |> resolve()
      {:error, _} -> file
    end
  end

  defp resolve_dir(dir) do
    {out, 0} = System.cmd("sh", ["-c", "cd \"$1\" && pwd -P", "sh", dir])
    String.trim(out)
  end
end
