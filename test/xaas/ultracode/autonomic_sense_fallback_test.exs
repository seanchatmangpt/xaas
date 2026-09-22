defmodule Xaas.Ultracode.AutonomicSenseFallbackTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Qualifies the sense stage's FALLBACK LAW (the wave-5-A2 finding): the
  launch path's sensing used to be script-backed ONLY, so a repo without a
  fitting backlog script hard-failed the fallback ("no contracts/ directory",
  typed exit 2) and failed its WHOLE multi-repo wave, while the registry's
  `sensing:` names pointed at nothing.

  The law under test, per repo per wave:

    1. a registered backlog script that EXITS 0 wins, unchanged;
    2. ELSE the registry entry's `sensing:` name drives the deterministic
       profile sensing of `Xaas.Ultracode.Sensing` over the same provisioned
       tree;
    3. ELSE the stage refuses TYPED (script error + profile gap).

  Everything here is real: real git fixture repos, the real provisioned
  worktrees, the REAL `aps_backlog.py` default script executing (and really
  exiting 2 on a contracts-less repo), and the real `nounverb_backlog.py`
  executing to exit 0. Nothing mocked.
  """

  alias Xaas.Ultracode.Autonomic

  @moduletag :subprocess
  @moduletag timeout: 120_000

  @moduletag skip:
               if(System.find_executable("python3") == nil,
                 do: "python3 not on PATH",
                 else: false
               )

  setup do
    _ = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    keys = [
      :ultracode_repos,
      :ultracode_repos_file,
      :ultracode_worktree_root,
      :ultracode_ticket_dir,
      :ultracode_backlog_scripts,
      :ultracode_sensing_profiles
    ]

    original = for key <- keys, into: %{}, do: {key, Application.get_env(:xaas, key)}

    base = mktmp("sense-fallback")

    fx =
      build_repo(Path.join(base, "fx"), %{
        "docs/sjira/v1/open-a.md" => """
        # SJ-A: wire the thing

        ## Status

        PARTIAL_ALIVE — work remains.

        ## History

        2026-09-20 | PARTIAL_ALIVE | feat/x @abc | compile 0 | half the scope
        """,
        "docs/sjira/v1/open-b.md" => """
        # SJ-B: consume the pack

        ## Status

        UNSUPPORTED — no admitted pack expresses this yet.
        """,
        "docs/sjira/v1/done-c.md" => """
        # SJ-C: already landed

        ## Status

        ALIVE — landed as abc123.
        """,
        "docs/sjira/v1/no-status.md" => """
        # SJ-D

        Prose only; the older convention has no Status section.
        """
      })

    gy =
      build_repo(Path.join(base, "gy"), %{
        "lib/ex_noun_verb_cli/cli.ex" => """
        defmodule Gy.Cli do
          def ping do
            :pong
          end

          def pong(a, b) do
            {:ok, a, b}
          end
        end
        """
      })

    Application.put_env(:xaas, :ultracode_repos, %{
      "fx" => %{
        "path" => fx,
        "sensing" => "fx-jira",
        "suite" => "fx-dod",
        "canonical_suite" => nil
      },
      "gy" => %{
        "path" => gy,
        "sensing" => "gy-jira",
        "suite" => "gy-dod",
        "canonical_suite" => nil
      }
    })

    Application.delete_env(:xaas, :ultracode_repos_file)
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))
    Application.put_env(:xaas, :ultracode_backlog_scripts, %{})
    Application.put_env(:xaas, :ultracode_sensing_profiles, %{})

    on_exit(fn ->
      for {key, value} <- original do
        if is_nil(value),
          do: Application.delete_env(:xaas, key),
          else: Application.put_env(:xaas, key, value)
      end

      File.rm_rf(base)
    end)

    %{base: base, fx: fx, gy: gy}
  end

  test "a failing backlog script falls back to the registered sensing profile, deterministically" do
    Application.put_env(:xaas, :ultracode_sensing_profiles, %{
      "fx-jira" => %{
        "type" => "jira_dir",
        "dir" => "docs/sjira",
        "closed" => ["ALIVE"],
        "max_items" => 2
      }
    })

    ctx = Autonomic.new_ctx(repo: "fx")

    # The default aps script REALLY runs here and REALLY exits 2 (no
    # contracts/ in the fixture) -- the exact condition that used to fail
    # the repo outright.
    assert {:ok, items} = Autonomic.sense(ctx)

    # Bound applied after dedup + id sort; provenance is the profile's dir;
    # only OPEN tickets became items (ALIVE closed, status-less skipped).
    assert length(items) == 2
    assert items == Enum.sort_by(items, & &1["id"])
    assert Enum.all?(items, &(&1["id"] =~ ~r/\Ajira-[a-z0-9-]+-[0-9a-f]{6}\z/))

    assert Enum.all?(items, &String.starts_with?(&1["source"]["file"], "docs/sjira/"))
    refute Enum.any?(items, &(&1["source"]["file"] =~ "done-c"))
    refute Enum.any?(items, &(&1["source"]["file"] =~ "no-status"))

    for item <- items do
      assert is_binary(item["goal"]) and item["goal"] != ""
      assert item["allowed_paths"] == ["*"]
      assert Map.has_key?(item, "mutants")
    end

    # The fallback is EVIDENCE on the wave ledger, not a silent recovery.
    assert File.exists?(ctx.ledger)

    events =
      ctx.ledger |> File.stream!() |> Enum.map(&Jason.decode!/1) |> Enum.map(& &1["event"])

    assert "sense_fallback" in events

    # Deterministic through the fallback: a second wave over the same base
    # sha yields byte-identical item ids (new nonce, new worktree).
    assert {:ok, items_again} = Autonomic.sense(Autonomic.new_ctx(repo: "fx"))
    assert Enum.map(items_again, & &1["id"]) == Enum.map(items, & &1["id"])

    # Both sense worktrees were cleaned up: nothing leaked into the run root.
    assert sense_worktrees_left() == []
  end

  test "a backlog script that exits 0 still wins over the registered profile" do
    # gy's REAL script exits 0 (the fixture has thin-coverage public defs),
    # and its registered profile points at a dir the repo does not even
    # HAVE -- proving the profile is never consulted on script success.
    Application.put_env(:xaas, :ultracode_backlog_scripts, %{"gy" => "nounverb_backlog.py"})

    Application.put_env(:xaas, :ultracode_sensing_profiles, %{
      "gy-jira" => %{"type" => "jira_dir", "dir" => "docs/sjira"}
    })

    ctx = Autonomic.new_ctx(repo: "gy")

    assert {:ok, items} = Autonomic.sense(ctx)
    assert items != []
    assert Enum.all?(items, &(&1["id"] =~ ~r/\Anounverb-neg-/))
    refute Enum.any?(items, &(&1["id"] =~ ~r/\Ajira-/))

    # Script success writes NOTHING to the wave ledger -- in particular no
    # fallback event (the ledger file is only created by run/1 or the
    # fallback itself).
    refute File.exists?(ctx.ledger)
    assert sense_worktrees_left() == []
  end

  test "a script failure with an UNIMPLEMENTED sensing name is a typed refusal" do
    # No script for fx (aps default fails), and "fx-jira" maps to nothing.
    # SINGLE-repo sense returns the refusal unwrapped (the
    # {:sense_failed, repo, reason} wrapper is the multi-repo wave's).
    ctx = Autonomic.new_ctx(repo: "fx")

    assert {:error,
            {:sense_refused, {:backlog_failed, 2, _script_tail},
             {:unknown_sensing_profile, "fx-jira"}}} = Autonomic.sense(ctx)

    assert sense_worktrees_left() == []
  end

  test "a multi-repo wave survives one repo's script failure via the profile fallback" do
    # THE FINDING: fx used to hard-fail the fallback (aps exit 2) and fail
    # the whole wave. Now fx falls back to its profile while gy's real
    # script still wins -- one wave, BOTH repos sensed.
    Application.put_env(:xaas, :ultracode_backlog_scripts, %{"gy" => "nounverb_backlog.py"})

    Application.put_env(:xaas, :ultracode_sensing_profiles, %{
      "fx-jira" => %{"type" => "jira_dir", "dir" => "docs/sjira", "closed" => ["ALIVE"]},
      "gy-jira" => %{"type" => "jira_dir", "dir" => "docs/sjira"}
    })

    ctx = Autonomic.new_ctx(repo: "fx,gy")

    assert {:ok, items} = Autonomic.sense(ctx)
    assert items != []

    repos = items |> Enum.map(& &1["repo"]) |> Enum.uniq() |> Enum.sort()
    assert repos == ["fx", "gy"]

    assert Enum.any?(items, &(&1["repo"] == "fx" and &1["id"] =~ ~r/\Ajira-/))
    assert Enum.any?(items, &(&1["repo"] == "gy" and &1["id"] =~ ~r/\Anounverb-neg-/))

    assert sense_worktrees_left() == []
  end

  # ------------------------------------------------------------------
  # Fixtures + helpers: real git repos, real tmp
  # ------------------------------------------------------------------

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-#{label}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end

  defp build_repo(dir, files) do
    git_identity = [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]

    File.mkdir_p!(dir)
    {_, 0} = System.cmd("git", ["init", "-q", "-b", "main"], env: git_identity, cd: dir)

    for {path, content} <- files do
      full = Path.join(dir, path)
      File.mkdir_p!(Path.dirname(full))
      File.write!(full, content)
      {_, 0} = System.cmd("git", ["add", path], env: git_identity, cd: dir)
    end

    {_, 0} = System.cmd("git", ["commit", "-q", "-m", "init"], env: git_identity, cd: dir)
    dir
  end

  defp sense_worktrees_left do
    root = Application.fetch_env!(:xaas, :ultracode_worktree_root)

    case File.ls(root) do
      {:ok, entries} -> entries
      {:error, _} -> []
    end
  end
end
