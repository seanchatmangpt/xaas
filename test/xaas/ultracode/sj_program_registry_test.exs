defmodule Xaas.Ultracode.SjProgramRegistryTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Qualifies the committed baseline that registers the four Semantic Jira
  program targets (xaas, autofde-lab, gymact, ggen-igniter) so the autonomic
  loop owns their merge + canonical verification:

    * `config/dev.exs` -- read for real through `Config.Reader`, exactly as a
      fresh checkout would load it -- names all four targets, each opted in to
      `refresh`, each with a per-item and a canonical suite that
      `Xaas.Ultracode.TargetSuites.devs/0` actually declares, and a sensing
      name that resolves to a declared profile;
    * the suite declarations pass the registration-time gate (`validate/1`)
      and obey the environment law (pinned absolute toolchain, allowlisted
      env keys, per-run test database from `{tmpdir}`, Python subject-identity
      step, bounded timeouts);
    * the `xaas-sjira` profile senses the REAL orders in this checkout's
      `docs/sjira` -- the not-yet-ALIVE ones, decided by each order's own
      `## Status` first word -- and the Python `subject` guard really refuses
      a package that resolved outside the worktree (the false-ALIVE class).

  Real files, real Config.Reader, real python3. Nothing mocked.
  """

  alias Xaas.Ultracode.{Sensing, TargetSuites}

  @aliases ~w(xaas autofde-lab gymact ggen-igniter)
  @closed ~w(DONE MERGED LANDED CLOSED RESOLVED ALIVE)
  @env_allowlist ~w(PATH LANG MIX_ENV MIX_ARCHIVES SEED PYTHONPATH GYMACT_ALLOW_DEGRADED_STANDINGS)

  @python System.find_executable("python3")

  defp dev_config do
    Config.Reader.read!(Path.expand("config/dev.exs"), env: :dev)[:xaas]
  end

  # ------------------------------------------------------------------
  # The committed baseline
  # ------------------------------------------------------------------

  test "config/dev.exs registers all four targets with refresh, suites and profiles" do
    cfg = dev_config()
    repos = cfg[:ultracode_repos]
    profiles = cfg[:ultracode_sensing_profiles]
    suites = TargetSuites.devs()

    for alias_name <- @aliases do
      assert %{path: path, sensing: sensing, suite: suite, canonical_suite: canonical} =
               entry = Map.fetch!(repos, alias_name)

      assert path == Path.expand("~/xaas-worktrees/repos/#{alias_name}")
      assert entry.refresh == true
      assert suite == "#{alias_name}-dod"
      assert canonical == "#{alias_name}-canonical"
      assert Map.has_key?(suites, suite), "#{suite} is not declared in TargetSuites.devs/0"
      assert Map.has_key?(suites, canonical), "#{canonical} is not declared"
      assert Map.has_key?(profiles, sensing), "sensing profile #{sensing} is not declared"
    end
  end

  test "every declared sensing profile is a known, well-formed jira_dir profile" do
    for {name, profile} <- dev_config()[:ultracode_sensing_profiles] do
      assert profile["type"] == "jira_dir", "#{name}"
      assert is_binary(profile["dir"]) and profile["dir"] != ""
      refute Path.type(profile["dir"]) == :absolute
      refute ".." in Path.split(profile["dir"])
    end
  end

  # ------------------------------------------------------------------
  # Suite declarations: the registration gate + the environment law
  # ------------------------------------------------------------------

  test "the whole suite registry (including the eight new suites) passes validate/1" do
    assert :ok = TargetSuites.validate(TargetSuites.devs())

    for alias_name <- @aliases, kind <- ~w(dod canonical) do
      assert Map.has_key?(TargetSuites.devs(), "#{alias_name}-#{kind}")
    end
  end

  test "validate/1 refuses a broken variant of a new suite" do
    good = TargetSuites.devs()["xaas-dod"]

    bad_placeholder =
      update_in(good, [:steps], fn [first | rest] ->
        [%{first | argv: ["echo", "prefix-{worktree}"]} | rest]
      end)

    assert {:error, problems} = TargetSuites.validate(%{"xaas-dod" => bad_placeholder})
    assert Enum.any?(problems, &(&1 =~ "embedded placeholder"))

    bad_timeout =
      update_in(good, [:steps], fn [first | rest] -> [%{first | timeout_ms: 0} | rest] end)

    assert {:error, problems} = TargetSuites.validate(%{"xaas-dod" => bad_timeout})
    assert Enum.any?(problems, &(&1 =~ "bad timeout_ms"))
  end

  test "every new suite runs under an allowlisted env with an absolute pinned toolchain" do
    for alias_name <- @aliases, kind <- ~w(dod canonical) do
      name = "#{alias_name}-#{kind}"
      suite = Map.fetch!(TargetSuites.devs(), name)

      # No ambient secrets or connection strings can be smuggled in.
      assert Map.keys(suite.env) -- @env_allowlist == [], "#{name}: env key outside allowlist"

      path_entries = String.split(suite.env["PATH"], ":")
      assert Enum.all?(path_entries, &String.starts_with?(&1, "/")), "#{name}: PATH not absolute"
      assert suite.env["LANG"] == "en_US.UTF-8"

      # Every step is bounded (validate/1 also enforces this, asserted here so
      # a relaxed gate would still be caught).
      for step <- suite.steps do
        assert is_integer(step.timeout_ms) and step.timeout_ms in 1..3_600_000
      end
    end
  end

  test "Elixir suites pin the repo's own toolchain and give mix test a per-run database" do
    for name <- ~w(xaas-dod xaas-canonical) do
      suite = TargetSuites.devs()[name]

      assert suite.env["MIX_ENV"] == "test"
      assert suite.env["PATH"] =~ ".asdf/installs/elixir/1.20.2-otp-28/bin"
      assert suite.env["PATH"] =~ ".asdf/installs/erlang/28.5.0.2/bin"
      assert Path.type(suite.env["MIX_ARCHIVES"]) == :absolute

      ids = Enum.map(suite.steps, & &1.id)
      assert ids == ~w(seed deps compile format test seed_publish)

      compile = Enum.find(suite.steps, &(&1.id == "compile"))
      assert compile.argv == ["mix", "compile", "--warnings-as-errors"]

      test_step = Enum.find(suite.steps, &(&1.id == "test"))
      # The run's `{tmpdir}` (unique per verifier run) seeds MIX_TEST_PARTITION.
      assert "{tmpdir}" in test_step.argv
      assert Enum.any?(test_step.argv, &(&1 =~ "MIX_TEST_PARTITION"))
      assert Enum.any?(test_step.argv, &(&1 =~ "mix ecto.drop"))
    end

    dod = TargetSuites.devs()["xaas-dod"]
    canonical = TargetSuites.devs()["xaas-canonical"]
    dod_test = Enum.find(dod.steps, &(&1.id == "test"))
    canonical_test = Enum.find(canonical.steps, &(&1.id == "test"))

    # DoD is the targeted gate; canonical is the FULL default suite.
    assert "test/xaas/actuation_test.exs" in dod_test.argv
    refute "test/xaas/actuation_test.exs" in canonical_test.argv
  end

  test "ggen-igniter suites pin elixir 1.18.4 / OTP 27 and run mix test" do
    for name <- ~w(ggen-igniter-dod ggen-igniter-canonical) do
      suite = TargetSuites.devs()[name]

      assert suite.env["PATH"] =~ ".asdf/installs/elixir/1.18.4-otp-27/bin"
      assert suite.env["PATH"] =~ ".asdf/installs/erlang/27.2.4/bin"
      test_step = Enum.find(suite.steps, &(&1.id == "test"))
      assert Enum.take(test_step.argv, 2) == ["mix", "test"]
    end
  end

  test "Python suites pin the venv interpreter absolutely and open with the subject guard" do
    for alias_name <- ~w(autofde-lab gymact), kind <- ~w(dod canonical) do
      name = "#{alias_name}-#{kind}"
      suite = TargetSuites.devs()[name]

      # Relative on purpose: resolved against the worktree the verifier cds into.
      assert suite.env["PYTHONPATH"] == "src"

      [subject, test_step] = suite.steps
      assert subject.id == "subject"
      assert test_step.id == "test"

      [python | _] = subject.argv
      assert Path.type(python) == :absolute
      assert python =~ ".venv/bin/python"
      assert hd(test_step.argv) == python
      assert "--basetemp" in test_step.argv and "{tmpdir}" in test_step.argv
      assert "no:cacheprovider" in test_step.argv
    end
  end

  test "tests that rewrite tracked files are excluded from the suites that would dirty the tree" do
    afde_dod = TargetSuites.devs()["autofde-lab-dod"]
    afde_test = Enum.find(afde_dod.steps, &(&1.id == "test"))

    assert "--ignore=tests/sa2a/test_v26_9_17_concurrency_stress_chicago.py" in afde_test.argv
  end

  # ------------------------------------------------------------------
  # The Python subject-identity guard, run for real
  # ------------------------------------------------------------------

  @tag skip: if(@python, do: false, else: "python3 not on PATH")
  test "the subject step passes inside the worktree and REFUSES a package resolved outside it" do
    [subject | _] = TargetSuites.devs()["gymact-dod"].steps
    [_python, "-c", code, _package] = subject.argv

    root = Path.join(System.tmp_dir!(), "subject-guard-#{System.unique_integer([:positive])}")
    worktree = Path.join(root, "worktree")
    outside = Path.join(root, "outside")

    for dir <- [Path.join(worktree, "src/fixpkg"), Path.join(outside, "fixpkg")] do
      File.mkdir_p!(dir)
      File.write!(Path.join(dir, "__init__.py"), "")
    end

    on_exit(fn -> File.rm_rf!(root) end)

    # Package resolves inside the worktree (relative PYTHONPATH=src): accepted.
    {out, inside_code} =
      System.cmd(@python, ["-c", code, "fixpkg"],
        cd: worktree,
        env: [{"PYTHONPATH", "src"}, {"PYTHONDONTWRITEBYTECODE", "1"}],
        stderr_to_stdout: true
      )

    assert inside_code == 0
    assert out =~ "subject fixpkg"

    # Same code, but the package the interpreter finds lives OUTSIDE the
    # worktree (the editable-install-of-the-source-checkout failure): refused.
    {_out, outside_code} =
      System.cmd(@python, ["-c", code, "fixpkg"],
        cd: worktree,
        env: [{"PYTHONPATH", outside}, {"PYTHONDONTWRITEBYTECODE", "1"}],
        stderr_to_stdout: true
      )

    assert outside_code == 3
  end

  # ------------------------------------------------------------------
  # Sensing the REAL Semantic Jira orders of this checkout
  # ------------------------------------------------------------------

  test "xaas-sjira senses exactly the not-yet-ALIVE orders in this checkout's docs/sjira" do
    # The COMMITTED baseline profile (test env declares none of its own).
    profile = dev_config()[:ultracode_sensing_profiles]["xaas-sjira"]

    root = File.cwd!()
    assert File.dir?(Path.join(root, "docs/sjira")), "expected docs/sjira in #{root}"

    assert {:ok, %{"profile" => "jira_dir", "items" => items, "head" => head}} =
             Sensing.derive(profile, root)

    assert head =~ ~r/^[0-9a-f]{40}$/

    # Independent oracle: read each order's `## Status` first word straight
    # off the file (no Sensing code involved) and compute the open set.
    expected_open =
      root
      |> Path.join("docs/sjira/**/*.md")
      |> Path.wildcard()
      |> Enum.map(&Path.relative_to(&1, root))
      |> Enum.filter(fn rel ->
        case status_first_word(File.read!(Path.join(root, rel))) do
          nil -> false
          word -> word not in @closed
        end
      end)
      |> Enum.sort()

    sensed = items |> Enum.map(& &1["source"]["file"]) |> Enum.sort()

    # `max_items` (default 20) bounds the document; the oracle must fit it.
    assert length(expected_open) <= 20
    assert sensed == expected_open

    for item <- items do
      assert String.starts_with?(item["source"]["file"], "docs/sjira/")
      assert item["id"] =~ ~r/^jira-[a-z0-9-]+-[0-9a-f]{6}$/
    end
  end

  defp status_first_word(text) do
    case Regex.run(~r/^##\s+Status\s*$\s*(\S.*)$/m, text, capture: :all_but_first) do
      [line] ->
        line |> String.split(~r/[\s—:,-]/, parts: 2) |> hd() |> String.trim() |> String.upcase()

      _ ->
        nil
    end
  end
end
