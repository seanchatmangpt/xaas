defmodule Xaas.Ultracode.SensingTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Chicago-style qualification of generic profile-driven backlog sensing: real
  git fixture repositories, real files, a REAL failing ExUnit suite executed
  as a child process. Nothing mocked.
  """

  alias Xaas.Ultracode.Sensing

  @id_charset ~r/\A[A-Za-z0-9._:-]+\z/

  setup do
    # run_uid law (dispatch_test): unique_integer restarts per BEAM; wall-clock
    # qualify so concurrent `mix test` VMs never share this dir.
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-sensing-test-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    %{base: dir}
  end

  # ----------------------------------------------------------------------
  # todo_file
  # ----------------------------------------------------------------------

  describe "todo_file profile" do
    test "derives one item per unchecked task, with provenance and stable ids", %{base: base} do
      repo =
        init_repo(base, %{
          "TODO.md" => """
          # Things

          - [x] already done
          - plain bullet, not a task
          - [ ] fix the login loop
          - [ ]  add tests for signup
          """
        })

      {:ok, doc} = Sensing.derive(%{"type" => "todo_file"}, repo)

      assert doc["schemaVersion"] == "xaas-sensing/1"
      assert doc["profile"] == "todo_file"
      assert doc["head"] == git!(repo, ["rev-parse", "HEAD"])
      assert length(doc["items"]) == 2

      [a, b] = doc["items"]
      assert a["id"] < b["id"]

      for item <- doc["items"] do
        assert item["id"] =~ @id_charset
        assert item["id"] =~ ~r/\Atodo-[a-z0-9-]+-[0-9a-f]{6}\z/
        assert Map.has_key?(item, "goal")
        assert item["allowed_paths"] == ["*"]
        assert item["mutants"] == []
        assert is_binary(item["goal"]) and item["goal"] != ""
      end

      login = Enum.find(doc["items"], &(&1["source"]["text"] =~ "login"))
      assert login["source"]["file"] == "TODO.md"
      # Heredoc line 1 is the empty line right after the opening quotes; the
      # login task sits on physical line 5 of the file content.
      assert login["source"]["line"] == 5
      assert login["source"]["text"] == "- [ ] fix the login loop"
      assert login["goal"] =~ "TODO.md"
      assert login["goal"] =~ "fix the login loop"

      # The checked box and the plain bullet produced nothing.
      refute Enum.any?(doc["items"], &(&1["source"]["text"] =~ "already done"))
      refute Enum.any?(doc["items"], &(&1["source"]["text"] =~ "plain bullet"))
    end

    test "ids are content-stable: moving the line keeps the id, editing it changes the id", %{
      base: base
    } do
      repo =
        init_repo(base, %{
          "TODO.md" => "- [ ] fix the login loop\n- [ ] second task\n"
        })

      {:ok, before} = Sensing.derive(%{"type" => "todo_file"}, repo)
      login_id = Enum.find(before["items"], &(&1["source"]["text"] =~ "login"))["id"]

      # Move the login task DOWN (unrelated line added above): same content.
      commit_file(
        repo,
        "TODO.md",
        "- [ ] new first task\n- [ ] fix the login loop\n- [ ] second task\n"
      )

      {:ok, after_move} = Sensing.derive(%{"type" => "todo_file"}, repo)
      assert Enum.find(after_move["items"], &(&1["source"]["text"] =~ "login"))["id"] == login_id
      assert after_move["head"] != before["head"]

      # EDIT the content: the id must change (the work changed).
      commit_file(
        repo,
        "TODO.md",
        "- [ ] new first task\n- [ ] fix the login loop NOW\n- [ ] second task\n"
      )

      {:ok, after_edit} = Sensing.derive(%{"type" => "todo_file"}, repo)
      refute Enum.find(after_edit["items"], &(&1["source"]["text"] =~ "login"))["id"] == login_id
    end

    test "derivation is deterministic: two runs are byte-identical", %{base: base} do
      repo = init_repo(base, %{"TODO.md" => "- [ ] b task\n- [ ] a task\n"})

      {:ok, d1} = Sensing.derive(%{"type" => "todo_file"}, repo)
      {:ok, d2} = Sensing.derive(%{"type" => "todo_file"}, repo)
      assert Jason.encode!(d1) == Jason.encode!(d2)
    end

    test "max_items bounds the output after the deterministic id sort", %{base: base} do
      repo =
        init_repo(base, %{
          "TODO.md" => "- [ ] task c\n- [ ] task b\n- [ ] task a\n"
        })

      {:ok, doc} = Sensing.derive(%{"type" => "todo_file", "max_items" => 2}, repo)
      assert length(doc["items"]) == 2
      ids = Enum.map(doc["items"], & &1["id"])
      assert ids == Enum.sort(ids)
    end

    test "duplicate task lines dedup to one id; max_items binds AFTER dedup + sort", %{
      base: base
    } do
      repo =
        init_repo(base, %{
          "TODO.md" => "- [ ] same task\n- [ ] same task\n- [ ] task b\n- [ ] task a\n"
        })

      # Four lines, three distinct ids (the duplicate collapses), then the
      # bound: the output is the deduped, id-sorted head -- never a silent
      # prune of distinct work.
      {:ok, doc} = Sensing.derive(%{"type" => "todo_file", "max_items" => 3}, repo)

      assert length(doc["items"]) == 3
      assert length(Enum.filter(doc["items"], &(&1["source"]["text"] =~ "same task"))) == 1

      ids = Enum.map(doc["items"], & &1["id"])
      assert ids == Enum.sort(Enum.uniq(ids))
    end

    test "custom file, allowed_paths and item_overrides flow into the items", %{base: base} do
      repo =
        init_repo(base, %{
          "ROADMAP.md" => "- [ ] ship the thing\n"
        })

      profile = %{
        "type" => "todo_file",
        "file" => "ROADMAP.md",
        "allowed_paths" => ["lib/**"],
        "item_overrides" => %{"min_new_tests" => 3}
      }

      {:ok, doc} = Sensing.derive(profile, repo)
      [item] = doc["items"]
      assert item["allowed_paths"] == ["lib/**"]
      assert item["min_new_tests"] == 3
      assert item["min_kill_ratio"] == nil
    end

    test "a missing file and an unsafe path both fail closed", %{base: base} do
      repo = init_repo(base, %{"README.md" => "no tasks\n"})

      assert {:error, {:todo_file_missing, "TODO.md"}} =
               Sensing.derive(%{"type" => "todo_file"}, repo)

      assert {:error, {:profile_path_must_be_relative, "../etc"}} =
               Sensing.derive(%{"type" => "todo_file", "file" => "../etc"}, repo)

      assert {:error, {:profile_path_must_be_relative, "/etc"}} =
               Sensing.derive(%{"type" => "todo_file", "file" => "/etc"}, repo)
    end
  end

  # ----------------------------------------------------------------------
  # jira_dir
  # ----------------------------------------------------------------------

  describe "jira_dir profile" do
    test "senses open tickets, skips closed and status-less ones, reads nested milestones", %{
      base: base
    } do
      repo =
        init_repo(base, %{
          "docs/jira/v1/done-ticket.md" => """
          # Done Ticket

          ## Status

          DONE — landed as abc123.

          ## Scope

          nothing left
          """,
          "docs/jira/v1/blocked-ticket.md" => """
          # Blocked Ticket

          ## Status

          BLOCKED — awaiting operator act.

          """,
          "docs/jira/v2/queued-ticket.md" => """
          # Queued Ticket

          ## Status

          Queued / Not Started (agent work).
          """,
          "docs/jira/v2/no-status-ticket.md" => """
          # No Status Ticket

          Just prose; the older convention has no Status section.
          """,
          "README.md" => "not a ticket dir entry\n"
        })

      {:ok, doc} = Sensing.derive(%{"type" => "jira_dir"}, repo)

      files = Enum.map(doc["items"], & &1["source"]["file"])
      assert length(doc["items"]) == 2
      assert "docs/jira/v1/blocked-ticket.md" in files
      assert "docs/jira/v2/queued-ticket.md" in files
      refute Enum.any?(files, &(&1 =~ "done-ticket"))
      refute Enum.any?(files, &(&1 =~ "no-status"))

      blocked = Enum.find(doc["items"], &(&1["source"]["file"] =~ "blocked"))
      assert blocked["id"] =~ ~r/\Ajira-blocked-ticket-[0-9a-f]{6}\z/
      assert blocked["source"]["text"] =~ "BLOCKED"
      assert blocked["goal"] =~ "docs/jira/v1/blocked-ticket.md"
      assert blocked["goal"] =~ "History"
    end

    test "ids survive History appends (the operator's append-only convention)", %{base: base} do
      repo =
        init_repo(base, %{
          "docs/jira/v1/t.md" => """
          # Ticket

          ## Status

          OPEN — work remains.
          """
        })

      {:ok, before} = Sensing.derive(%{"type" => "jira_dir"}, repo)
      [item] = before["items"]

      # A wave completes; the ticket gets its History append.
      commit_file(repo, "docs/jira/v1/t.md", """
      # Ticket

      ## Status

      OPEN — work remains.

      ## History

      2026-09-19 | ALIVE | feat/x @abc | gates pass | none
      """)

      {:ok, after_append} = Sensing.derive(%{"type" => "jira_dir"}, repo)

      assert Enum.find(after_append["items"], &(&1["source"]["file"] =~ "t.md"))["id"] ==
               item["id"]
    end

    test "include_unknown_status admits status-less tickets; closed list is configurable", %{
      base: base
    } do
      repo = init_repo(base, %{"docs/jira/v1/t.md" => "# T\n\nno status section\n"})

      assert {:ok, doc} = Sensing.derive(%{"type" => "jira_dir"}, repo)
      assert doc["items"] == []

      assert {:ok, doc} =
               Sensing.derive(
                 %{"type" => "jira_dir", "include_unknown_status" => true},
                 repo
               )

      assert length(doc["items"]) == 1

      # A repo that marks completion with MERGED instead of DONE.
      repo2 =
        init_repo(Path.join(base, "two"), %{
          "docs/jira/v1/t.md" => "# T\n\n## Status\n\nMERGED — done.\n"
        })

      assert {:ok, doc} = Sensing.derive(%{"type" => "jira_dir"}, repo2)
      assert doc["items"] == []

      assert {:ok, doc} =
               Sensing.derive(%{"type" => "jira_dir", "closed" => ["DONE"]}, repo2)

      assert length(doc["items"]) == 1
    end

    test "derivation is deterministic and a missing dir fails closed", %{base: base} do
      repo = init_repo(base, %{"README.md" => "x\n"})

      assert {:error, {:jira_dir_missing, "docs/jira"}} =
               Sensing.derive(%{"type" => "jira_dir"}, repo)

      assert {:error, {:profile_path_must_be_relative, ".."}} =
               Sensing.derive(%{"type" => "jira_dir", "dir" => ".."}, repo)
    end
  end

  # ----------------------------------------------------------------------
  # failing_tests
  # ----------------------------------------------------------------------

  describe "failing_tests profile" do
    test "runs a real failing ExUnit suite and derives one item per failing test", %{base: base} do
      repo = init_repo(base, mix_fixture_files())

      profile = %{
        "type" => "failing_tests",
        "command" => ["mix", "test"],
        "parser" => "exunit",
        "timeout_ms" => 240_000
      }

      assert {:ok, d1} = Sensing.derive(profile, repo)
      assert {:ok, d2} = Sensing.derive(profile, repo)

      # ExUnit randomizes test order per run; the document must STILL be
      # byte-identical (id hashing excludes order, finalize/2 sorts by id).
      assert Jason.encode!(d1) == Jason.encode!(d2)

      assert d1["profile"] == "failing_tests"
      assert length(d1["items"]) == 2

      names = Enum.map(d1["items"], & &1["source"]["text"])
      assert Enum.any?(names, &(&1 =~ "flunk_a"))
      assert Enum.any?(names, &(&1 =~ "flunk_b"))
      refute Enum.any?(names, &(&1 =~ "arithmetic passes"))

      for item <- d1["items"] do
        assert item["id"] =~ ~r/\Afail-[a-z0-9-]+-[0-9a-f]{6}\z/
        assert item["source"]["file"] =~ ~r/w5_fixture_test\.exs\z/
        # ExUnit's failure exit status is 2 (observed, not assumed).
        assert item["goal"] =~ "exited with code 2"
        assert item["goal"] =~ "WITHOUT weakening, skipping, or deleting"
      end

      ids = Enum.map(d1["items"], & &1["id"])
      assert ids == Enum.sort(ids)
    end

    test "regex parser: command execution, named captures, and bounding", %{base: base} do
      repo =
        init_repo(base, %{
          "out.txt" => """
          noise before
          FAIL: login-loop in src/auth.ex
          FAIL: signup-crash in src/signup.ex
          noise after
          """
        })

      profile = %{
        "type" => "failing_tests",
        "command" => ["cat", "out.txt"],
        "parser" => "regex",
        "pattern" => ~s/^FAIL: (?<id>.+?) in (?<file>.+)$/
      }

      {:ok, doc} = Sensing.derive(profile, repo)
      assert length(doc["items"]) == 2

      login = Enum.find(doc["items"], &(&1["id"] =~ "login-loop"))
      assert login["source"]["file"] == "src/auth.ex"

      bounded = Map.put(profile, "max_items", 1)
      {:ok, doc} = Sensing.derive(bounded, repo)
      assert length(doc["items"]) == 1
    end

    test "a command that cannot run, a timeout, and a bad pattern all fail closed", %{base: base} do
      repo = init_repo(base, %{"out.txt" => "FAIL: x in f.ex\n"})

      assert {:error, {:command_not_found, "definitely-not-a-real-bin"}} =
               Sensing.derive(
                 %{"type" => "failing_tests", "command" => ["definitely-not-a-real-bin"]},
                 repo
               )

      assert {:error, :command_timeout} =
               Sensing.derive(
                 %{"type" => "failing_tests", "command" => ["sleep", "5"], "timeout_ms" => 300},
                 repo
               )

      assert {:error, :failing_tests_requires_command} =
               Sensing.derive(%{"type" => "failing_tests"}, repo)

      assert {:error, {:bad_pattern, _}} =
               Sensing.derive(
                 %{
                   "type" => "failing_tests",
                   "command" => ["cat", "out.txt"],
                   "parser" => "regex",
                   "pattern" => "(unclosed"
                 },
                 repo
               )

      assert {:error, :regex_parser_requires_pattern} =
               Sensing.derive(
                 %{
                   "type" => "failing_tests",
                   "command" => ["cat", "out.txt"],
                   "parser" => "regex"
                 },
                 repo
               )
    end
  end

  # ----------------------------------------------------------------------
  # Planner contract + registered-alias sensing
  # ----------------------------------------------------------------------

  describe "wave planner contract" do
    test "items carry every key the Autonomic ticket writer consumes", %{base: base} do
      repo = init_repo(base, %{"TODO.md" => "- [ ] fix the login loop\n"})

      {:ok, doc} = Sensing.derive(%{"type" => "todo_file"}, repo)
      [item] = doc["items"]

      # Keys read by Xaas.Ultracode.Autonomic.create_run_and_epoch/5 and the
      # ticket JSON it writes.
      for key <- ~w(id goal allowed_paths min_new_tests min_kill_ratio mutants) do
        assert Map.has_key?(item, key), "item missing #{key}"
      end

      assert item["id"] =~ @id_charset
      assert is_list(item["allowed_paths"]) and item["allowed_paths"] != []

      # The item must survive the exact encode the ticket writer performs.
      assert {:ok, _} = Jason.encode(%{goal: item["goal"], item: item["id"], extra: item})
    end

    test "sense/4 senses a registered alias at an exact base_sha and cleans up", %{base: base} do
      original = %{
        repos: Application.get_env(:xaas, :ultracode_repos),
        root: Application.get_env(:xaas, :ultracode_worktree_root)
      }

      repo = init_repo(base, %{"TODO.md" => "- [ ] task one\n- [ ] task two\n"})
      root = Path.join(base, "runs")
      sha = git!(repo, ["rev-parse", "HEAD"])

      Application.put_env(:xaas, :ultracode_repos, %{"sensingdemo" => repo})
      Application.put_env(:xaas, :ultracode_worktree_root, root)

      on_exit(fn ->
        Application.put_env(:xaas, :ultracode_repos, original.repos)
        Application.put_env(:xaas, :ultracode_worktree_root, original.root)
      end)

      profile = %{"type" => "todo_file"}

      assert {:ok, doc} =
               Sensing.sense("sensingdemo", sha, profile, name: "sense-demo-1")

      assert doc["head"] == sha
      assert length(doc["items"]) == 2

      # The provisioned worktree is always cleaned up, and re-sensing the same
      # sha reproduces the same document (repeatable at an exact pin).
      assert sense_worktrees_left(root) == []

      assert {:ok, doc_again} =
               Sensing.sense("sensingdemo", sha, profile, name: "sense-demo-2")

      assert Jason.encode!(doc_again) == Jason.encode!(doc)

      assert {:error, :base_sha_not_in_repo} =
               Sensing.sense("sensingdemo", String.duplicate("a", 40), profile)
    end

    test "unknown profile types and malformed profiles fail closed" do
      assert {:error, {:unknown_profile_type, "stars"}} =
               Sensing.derive(%{"type" => "stars"}, "/tmp")

      assert {:error, :profile_missing_type} = Sensing.derive(%{"file" => "TODO.md"}, "/tmp")
      assert {:error, :profile_not_a_map} = Sensing.derive("todo_file", "/tmp")
      assert {:error, :path_not_a_string} = Sensing.derive(%{"type" => "todo_file"}, 42)
    end
  end

  # ----------------------------------------------------------------------
  # Registered profile names (the fallback seam the Autonomic stage drives)
  # ----------------------------------------------------------------------

  describe "registered profile names" do
    setup do
      original = Application.get_env(:xaas, :ultracode_sensing_profiles)

      Application.put_env(:xaas, :ultracode_sensing_profiles, %{
        "demo-jira" => %{"type" => "jira_dir", "dir" => "docs/jira"},
        "broken" => %{"type" => "no-such-type"}
      })

      on_exit(fn ->
        if is_nil(original),
          do: Application.delete_env(:xaas, :ultracode_sensing_profiles),
          else: Application.put_env(:xaas, :ultracode_sensing_profiles, original)
      end)

      :ok
    end

    test "a registered name resolves to its explicit profile; registered? agrees" do
      assert {:ok, %{"type" => "jira_dir", "dir" => "docs/jira"}} = Sensing.profile("demo-jira")
      assert Sensing.registered?("demo-jira")
    end

    test "an unknown name is a typed error, never silently ignored" do
      assert {:error, {:unknown_sensing_profile, "nope"}} = Sensing.profile("nope")
      refute Sensing.registered?("nope")
      # A hand-built ctx without a sensing name is the same refusal shape.
      assert {:error, {:unknown_sensing_profile, nil}} = Sensing.profile(nil)
    end

    test "a name mapped to a malformed profile fails closed" do
      assert {:error,
              {:invalid_sensing_profile, "broken", {:unknown_profile_type, "no-such-type"}}} =
               Sensing.profile("broken")

      refute Sensing.registered?("broken")
    end

    test "the registered profile actually derives: name -> derive round trip", %{base: base} do
      repo =
        init_repo(base, %{
          "docs/jira/v1/t.md" => "# T\n\n## Status\n\nOPEN — work remains.\n"
        })

      assert {:ok, profile} = Sensing.profile("demo-jira")
      assert {:ok, doc} = Sensing.derive(profile, repo)
      assert [%{"source" => %{"file" => "docs/jira/v1/t.md"}}] = doc["items"]
    end
  end

  # ----------------------------------------------------------------------
  # Fixtures: real git repos, real child mix run
  # ----------------------------------------------------------------------

  defp init_repo(dir, files) do
    File.mkdir_p!(dir)

    {_, 0} =
      System.cmd("git", ["-C", dir, "init", "--quiet", "-b", "main"], stderr_to_stdout: true)

    git_identity = [
      {"GIT_AUTHOR_NAME", "t"},
      {"GIT_AUTHOR_EMAIL", "t@t"},
      {"GIT_COMMITTER_NAME", "t"},
      {"GIT_COMMITTER_EMAIL", "t@t"}
    ]

    for {path, content} <- files do
      full = Path.join(dir, path)
      File.mkdir_p!(Path.dirname(full))
      File.write!(full, content)
      {_, 0} = System.cmd("git", ["-C", dir, "add", path], stderr_to_stdout: true)
    end

    {_, 0} =
      System.cmd("git", ["-C", dir, "commit", "--quiet", "-m", "init"],
        env: git_identity,
        stderr_to_stdout: true
      )

    dir
  end

  defp commit_file(dir, path, content) do
    full = Path.join(dir, path)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, content)
    {_, 0} = System.cmd("git", ["-C", dir, "add", path], stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", dir, "commit", "--quiet", "-m", "update #{path}"],
        env: [
          {"GIT_AUTHOR_NAME", "t"},
          {"GIT_AUTHOR_EMAIL", "t@t"},
          {"GIT_COMMITTER_NAME", "t"},
          {"GIT_COMMITTER_EMAIL", "t@t"}
        ],
        stderr_to_stdout: true
      )

    :ok
  end

  # A real minimal Mix project whose suite has exactly two deliberate
  # failures. The child `mix` resolves through the SAME asdf pins as this
  # repo (the fixture carries a copy of the repo's .tool-versions, since the
  # temp fixture dir has no ancestor pin of its own).
  defp mix_fixture_files do
    [
      {"mix.exs",
       """
       defmodule W5SensorFixture.MixProject do
         use Mix.Project

         def project do
           [app: :w5_sensor_fixture, version: "0.1.0", deps: []]
         end

         def application do
           [extra_applications: [:logger]]
         end
       end
       """},
      {"test/test_helper.exs", "ExUnit.start()\n"},
      {"test/w5_fixture_test.exs",
       """
       defmodule W5FixtureTest do
         use ExUnit.Case, async: true

         test "arithmetic passes" do
           assert 1 + 1 == 2
         end

         test "flunk_a fails on purpose" do
           flunk("deliberate failure flunk_a")
         end

         test "flunk_b fails on purpose" do
           flunk("deliberate failure flunk_b")
         end
       end
       """}
    ] ++ tool_versions()
  end

  defp tool_versions do
    repo_pin = Path.expand(".tool-versions", File.cwd!())

    pins =
      case File.read(repo_pin) do
        {:ok, text} ->
          text
          |> String.split("\n")
          |> Enum.filter(&(&1 =~ ~r/^(elixir|erlang)\s/))
          |> Enum.join("\n")

        _ ->
          ""
      end

    if pins == "", do: [], else: [{".tool-versions", pins <> "\n"}]
  end

  defp sense_worktrees_left(root) do
    case File.ls(root) do
      {:ok, entries} -> Enum.filter(entries, &String.starts_with?(&1, "sense-"))
      {:error, _} -> []
    end
  end

  defp git!(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    String.trim(out)
  end
end
