defmodule Xaas.Receipt.RProjectionConsistencyTest do
  @moduledoc """
  Chicago qualification of `Xaas.Receipt.RProjection.consistency/2`, the
  GC23-7 receipt law (lane R1-X-COURTS; PRD GC23-7, PR-011; ARD sections 12
  and 26): an R projection the fleet validator ADMITS can still be
  internally inconsistent -- ALIVE over a false acceptance, a consequence
  commit that is not the subject's, files outside the order's path scope, a
  replay command the court never ran. Each is refused, typed.

  Every collaborator is real: a real git repository in a tmp dir (a base
  commit, an in-scope subject commit, an out-of-scope subject commit on a
  second branch, an unrelated commit on a third), the real suite declaration
  hashed by the real `Xaas.Ultracode.Verifier.argv_digest/1`, and -- when
  `GGEN_IGNITER_DIR` names the subject repository -- the committed reference
  episode `docs/sjira/v26.9.23/episodes/fmt-1` itself (skipped, named,
  otherwise).
  """

  use ExUnit.Case, async: true

  alias Xaas.Receipt.RProjection
  alias Xaas.Ultracode.Verifier

  @acc "https://ggen-igniter.dev/sjira/test#acceptance"
  @fal "https://ggen-igniter.dev/sjira/test#falsifier"
  @court "https://ggen-igniter.dev/sjira/test#court"
  @suite "consistency-format"
  @declaration %{
    steps: [
      %{
        id: "format",
        argv: ["mix", "format", "--check-formatted"],
        timeout_ms: 300_000,
        receipt: true
      }
    ]
  }

  @episode Path.expand("../../../docs/sjira/v26.9.23/episodes/fmt-1", __DIR__)
  @ggen_dir System.get_env("GGEN_IGNITER_DIR")

  setup do
    repo = Path.join(System.tmp_dir!(), "r-consistency-#{System.unique_integer([:positive])}")
    File.mkdir_p!(repo)
    on_exit(fn -> File.rm_rf(repo) end)

    git!(repo, ["init", "-q", "-b", "main"])
    write!(repo, "lib/a.ex", "defmodule A do\nend\n")
    write!(repo, "mix.lock", "%{}\n")
    base = commit!(repo, "base")

    write!(repo, "lib/a.ex", "defmodule A do\n  def a, do: :a\nend\n")
    subject = commit!(repo, "in-scope repair")

    git!(repo, ["checkout", "-q", "-b", "wide", base])
    write!(repo, "lib/a.ex", "defmodule A do\n  def b, do: :b\nend\n")
    write!(repo, "mix.lock", "%{wide: true}\n")
    wide = commit!(repo, "repair that also rewrites mix.lock")

    git!(repo, ["checkout", "-q", "-b", "side", base])
    write!(repo, "lib/side.ex", "defmodule Side do\nend\n")
    side = commit!(repo, "unrelated")

    order = %{
      "identity" => "EP-T",
      "base_sha" => base,
      "path_scope" => [".formatter.exs", "config", "lib", "mix.exs", "test"],
      "acceptance" => [@acc],
      "falsifiers" => [@fal],
      "required_courts" => [@court]
    }

    %{repo: repo, base: base, subject: subject, wide: wide, side: side, order: order}
  end

  defp r(ctx, head \\ nil, files \\ ["lib/a.ex"]) do
    head = head || ctx.subject
    digest = Verifier.argv_digest(@declaration)

    binding = %{"suite" => @suite, "step_id" => "format", "head" => head, "argv_sha256" => digest}

    %{
      "identity" => %{
        "subject" => "EP-T",
        "repo" => ctx.repo,
        "subject_sha" => head,
        "base_sha" => ctx.base
      },
      "authority" => %{
        "ceiling" => "CONSTRUCT",
        "grant" => "xaas-lease:epoch:t",
        "actor" => "recipe-worker"
      },
      "consequence" => %{"commits" => [head], "files_changed" => files, "remote_effects" => []},
      "replay" => %{
        "commands" => [
          %{
            "cmd" => "mix format --check-formatted",
            "cwd" => ctx.repo,
            "exit" => 0,
            "summary" => "pass"
          }
        ]
      },
      "standing" => %{"value" => "ALIVE", "derived_from" => "test"},
      "court" => %{
        "binding" => binding,
        "acceptance_results" => %{@acc => true},
        "falsifier_results" => %{@fal => "survived"},
        "court_results" => %{@court => Map.put(binding, "passed", true)}
      }
    }
  end

  defp judge(r, ctx, order \\ nil),
    do:
      RProjection.consistency(r,
        order: order || ctx.order,
        repo: ctx.repo,
        suites: %{@suite => @declaration}
      )

  test "a consistent ALIVE projection is CONSISTENT: observed commits and files, the bound command",
       ctx do
    assert {:ok, facts} = judge(r(ctx), ctx)
    assert facts["standing"] == "CONSISTENT"
    assert facts["r_standing"] == "ALIVE"
    assert facts["commits"] == [ctx.subject]
    assert facts["files"] == ["lib/a.ex"]
    assert facts["replay_command"] == "mix format --check-formatted"
  end

  test "ALIVE over a false acceptance, a refuted falsifier, a failed court or a missing acceptance IRI is REFUSED(alive_acceptance_false)",
       ctx do
    false_acc = put_in(r(ctx), ["court", "acceptance_results", @acc], false)
    refuted = put_in(r(ctx), ["court", "falsifier_results", @fal], "failed")
    failed_court = put_in(r(ctx), ["court", "court_results", @court, "passed"], false)
    missing = put_in(r(ctx), ["court", "acceptance_results"], %{})

    for mutant <- [false_acc, refuted, failed_court, missing] do
      typed = refused!(judge(mutant, ctx), "alive_acceptance_false", "admission_vacuous")
      assert [_ | _] = typed["detail"]["unwitnessed"]
    end

    # the acceptance law binds ALIVE only: an UNKNOWN projection may carry a false verdict
    unknown = false_acc |> put_in(["standing", "value"], "UNKNOWN")
    assert {:ok, %{"r_standing" => "UNKNOWN"}} = judge(unknown, ctx)
  end

  test "a consequence commit that is not the subject's -- the base, an unrelated commit, none -- is REFUSED(consequence_not_subject)",
       ctx do
    for commits <- [[ctx.base], [ctx.side], [ctx.subject, ctx.side], []] do
      mutant = put_in(r(ctx), ["consequence", "commits"], commits)

      assert {:refused,
              %{
                "standing" => "REFUSED(consequence_not_subject)",
                "broken_term" => "R_missing_consequence"
              }} =
               judge(mutant, ctx),
             inspect(commits)
    end
  end

  test "the subject set to its base has no commits of its own: REFUSED(consequence_not_subject)",
       ctx do
    at_base = r(ctx, ctx.base)
    assert {:refused, %{"reason" => "consequence_not_subject"}} = judge(at_base, ctx)
  end

  test "recorded files outside the order's path scope are REFUSED(consequence_outside_path_scope)",
       ctx do
    mutant = put_in(r(ctx), ["consequence", "files_changed"], ["mix.lock", "priv/secret.key"])

    assert {:refused,
            %{
              "standing" => "REFUSED(consequence_outside_path_scope)",
              "broken_term" => "R_missing_authority",
              "detail" => %{"outside" => ["mix.lock", "priv/secret.key"]}
            }} = judge(mutant, ctx)
  end

  test "a subject whose real diff leaves the path scope is refused even when the receipt omits the file",
       ctx do
    honest = r(ctx, ctx.wide, ["lib/a.ex", "mix.lock"])
    omitting = r(ctx, ctx.wide, ["lib/a.ex"])

    for mutant <- [honest, omitting] do
      assert {:refused,
              %{
                "reason" => "consequence_outside_path_scope",
                "detail" => %{"outside" => ["mix.lock"]}
              }} =
               judge(mutant, ctx)
    end
  end

  test "an in-scope file the subject never changed is REFUSED(consequence_not_observed)", ctx do
    mutant = put_in(r(ctx), ["consequence", "files_changed"], ["lib/a.ex", "lib/never.ex"])

    assert {:refused,
            %{
              "standing" => "REFUSED(consequence_not_observed)",
              "broken_term" => "R_missing_consequence",
              "detail" => %{"unobserved" => ["lib/never.ex"]}
            }} = judge(mutant, ctx)
  end

  test "a path scope entry covers the entry and its subtree, never a sibling with the same prefix",
       ctx do
    order = Map.put(ctx.order, "path_scope", ["li"])
    assert {:refused, %{"reason" => "consequence_outside_path_scope"}} = judge(r(ctx), ctx, order)
    order = Map.put(ctx.order, "path_scope", ["lib/a.ex"])
    assert {:ok, _} = judge(r(ctx), ctx, order)
  end

  test "a replay command the court never ran (`true`, another argv, none) is REFUSED(replay_command_unbound)",
       ctx do
    for cmd <- ["true", "mix format", "mix format --check-formatted && true"] do
      mutant = put_in(r(ctx), ["replay", "commands", Access.at(0), "cmd"], cmd)

      assert {:refused,
              %{
                "standing" => "REFUSED(replay_command_unbound)",
                "broken_term" => "R_missing_replay",
                "detail" => %{"court_commands" => ["mix format --check-formatted"]}
              }} = judge(mutant, ctx),
             cmd
    end

    none = put_in(r(ctx), ["replay", "commands"], [])
    assert {:refused, %{"reason" => "replay_command_unbound"}} = judge(none, ctx)
  end

  test "a court binding on another head, another declaration digest, a disagreeing court result or no binding is REFUSED(replay_command_unbound)",
       ctx do
    other_head = put_in(r(ctx), ["court", "binding", "head"], ctx.side)
    other_argv = put_in(r(ctx), ["court", "binding", "argv_sha256"], String.duplicate("a", 64))
    result_drift = put_in(r(ctx), ["court", "court_results", @court, "head"], ctx.side)
    unbound = update_in(r(ctx), ["court"], &Map.delete(&1, "binding"))

    for mutant <- [other_head, other_argv, result_drift, unbound] do
      refused!(judge(mutant, ctx), "replay_command_unbound", "R_missing_replay")
    end
  end

  test "a receipt for another order or base, an absent subject commit, a subject not descended from the base",
       ctx do
    assert {:refused,
            %{"reason" => "receipt_not_for_order", "broken_term" => "R_missing_identity"}} =
             judge(put_in(r(ctx), ["identity", "subject"], "EP-X"), ctx)

    assert {:refused, %{"reason" => "receipt_not_for_order"}} =
             judge(put_in(r(ctx), ["identity", "base_sha"], ctx.side), ctx)

    assert {:refused, %{"standing" => "BLOCKED:subject_unreachable", "broken_term" => "mu_on_O"}} =
             judge(r(ctx, String.duplicate("1", 40)), ctx)

    order = Map.put(ctx.order, "base_sha", ctx.side)
    mutant = put_in(r(ctx), ["identity", "base_sha"], ctx.side)
    assert {:refused, %{"reason" => "subject_not_descended"}} = judge(mutant, ctx, order)
  end

  describe "the committed reference episode fmt-1" do
    @describetag skip:
                   if(is_nil(@ggen_dir),
                     do: "GGEN_IGNITER_DIR unset (the subject repository of episode fmt-1)",
                     else: false
                   )

    setup do
      r = read!("receipt.r.json")
      row = read!("work.json")["work_orders"] |> Enum.find(&(&1["identity"] == "EP-A"))
      %{fmt: r, row: row}
    end

    test "its R projection is consistent with EP-A and the subject repository, under the registered suite",
         %{
           fmt: r,
           row: row
         } do
      assert {:ok, facts} = RProjection.consistency(r, order: row, repo: @ggen_dir)
      assert facts["r_standing"] == "ALIVE"
      assert facts["commits"] == r["consequence"]["commits"]
      assert facts["files"] == r["consequence"]["files_changed"]
      assert facts["replay_command"] == "mix format --check-formatted"
    end

    test "the four MSA mutants that escaped every court are refused, typed", %{fmt: r, row: row} do
      mutants = [
        {"alive_acceptance_false",
         update_in(r, ["court", "acceptance_results"], &Map.new(&1, fn {k, _} -> {k, false} end))},
        {"consequence_not_subject",
         put_in(r, ["consequence", "commits"], [r["identity"]["base_sha"]])},
        {"consequence_outside_path_scope",
         put_in(r, ["consequence", "files_changed"], ["mix.lock", "priv/secret.key"])},
        {"replay_command_unbound", put_in(r, ["replay", "commands", Access.at(0), "cmd"], "true")}
      ]

      for {reason, mutant} <- mutants do
        assert {:refused, %{"reason" => ^reason}} =
                 RProjection.consistency(mutant, order: row, repo: @ggen_dir)
      end
    end
  end

  # -- helpers ------------------------------------------------------------------

  defp refused!(result, reason, term) do
    assert {:refused, typed} = result
    assert typed["standing"] == "REFUSED(#{reason})"
    assert typed["reason"] == reason
    assert typed["broken_term"] == term
    typed
  end

  defp read!(name), do: Path.join(@episode, name) |> File.read!() |> Jason.decode!()

  defp write!(repo, rel, body) do
    path = Path.join(repo, rel)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, body)
  end

  defp commit!(repo, message) do
    git!(repo, ["add", "-A"])

    git!(repo, [
      "-c",
      "user.name=t",
      "-c",
      "user.email=t@t.invalid",
      "commit",
      "-q",
      "-m",
      message
    ])

    repo |> git!(["rev-parse", "HEAD"]) |> String.trim()
  end

  defp git!(repo, args) do
    {out, 0} = System.cmd("git", ["-C", repo | args], stderr_to_stdout: true)
    out
  end
end
