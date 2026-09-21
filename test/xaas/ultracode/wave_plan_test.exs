defmodule Xaas.Ultracode.WavePlanTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Qualification of the multi-repo wave plan law (`Xaas.Ultracode.WavePlan`):
  spec shape admission, registry membership resolution, per-repo cap
  validation, and the round-robin rotation (the no-starvation law). Pure
  functions -- the only I/O is the registry read, which these tests pin via
  the application env.
  """

  alias Xaas.Ultracode.WavePlan

  describe "parse_spec/1 spec-shape admission" do
    test "one alias is the historical single-repo spec" do
      assert {:ok, ["aps"]} = WavePlan.parse_spec("aps")
    end

    test "a comma list preserves order and collapses duplicates" do
      assert {:ok, ["aps", "eds", "nounverb"]} = WavePlan.parse_spec("aps,eds,nounverb")
      assert {:ok, ["aps", "eds"]} = WavePlan.parse_spec("aps,eds,aps")
    end

    test "whitespace around aliases is tolerated" do
      assert {:ok, ["aps", "eds"]} = WavePlan.parse_spec(" aps , eds ")
    end

    test "all is the wildcard spec" do
      assert {:ok, :all} = WavePlan.parse_spec("all")
    end

    test "an empty segment is a typed refusal, never a silent alias" do
      assert {:error, {:bad_repo_spec, "aps,,"}} = WavePlan.parse_spec("aps,,")
      assert {:error, {:bad_repo_spec, "aps,"}} = WavePlan.parse_spec("aps,")
      assert {:error, {:bad_repo_spec, ""}} = WavePlan.parse_spec("")
    end

    test "a malformed alias is a typed refusal naming the alias" do
      assert {:error, {:bad_repo_spec, "Big Repo"}} = WavePlan.parse_spec("aps,Big Repo")
      assert {:error, {:bad_repo_spec, "1ups"}} = WavePlan.parse_spec("1ups")
    end

    test "non-string specs are typed refusals" do
      assert {:error, {:bad_repo_spec, nil}} = WavePlan.parse_spec(nil)
      assert {:error, {:bad_repo_spec, [:aps]}} = WavePlan.parse_spec([:aps])
    end
  end

  describe "resolve/1 registry membership" do
    setup do
      original = Application.get_env(:xaas, :ultracode_repos)

      base = mktmp()

      repos = %{
        "bbrepo" => git_repo(Path.join(base, "bbrepo")),
        "aarepo" => git_repo(Path.join(base, "aarepo"))
      }

      Application.put_env(:xaas, :ultracode_repos, repos)

      on_exit(fn ->
        if is_nil(original),
          do: Application.delete_env(:xaas, :ultracode_repos),
          else: Application.put_env(:xaas, :ultracode_repos, original)
      end)

      %{aliases: MapSet.new(Map.keys(repos))}
    end

    test "a list spec resolves sorted and refuses unknown aliases", %{aliases: aliases} do
      assert {:ok, ["aarepo", "bbrepo"]} = WavePlan.resolve(["bbrepo", "aarepo"])
      assert {:error, {:unknown_repo_alias, "nope"}} = WavePlan.resolve(["aarepo", "nope"])

      # every listed alias must be registered
      for alias <- aliases do
        assert {:ok, _} = WavePlan.resolve([alias])
      end
    end

    test "all resolves every registered alias (sorted, superset of the env entries)" do
      assert {:ok, resolved} = WavePlan.resolve(:all)
      assert resolved == Enum.sort(resolved)

      # The durable registry file may register MORE targets on this machine;
      # the env baseline must always be a subset of the membership.
      assert MapSet.subset?(MapSet.new(["aarepo", "bbrepo"]), MapSet.new(resolved))
    end
  end

  describe "validate_caps/2 admission" do
    test "caps inside the resolved spec are admitted" do
      assert :ok = WavePlan.validate_caps(%{"aps" => 3, "eds" => 0}, ["aps", "eds"])
      assert :ok = WavePlan.validate_caps(%{}, ["aps"])
    end

    test "a cap naming an alias outside the spec is dead config -- refused" do
      assert {:error, {:unknown_repo_alias, "spr"}} =
               WavePlan.validate_caps(%{"spr" => 1}, ["aps", "eds"])
    end

    test "a malformed cap value is a typed refusal" do
      assert {:error, {:bad_repo_cap, {"aps", -1}}} =
               WavePlan.validate_caps(%{"aps" => -1}, ["aps"])

      assert {:error, {:bad_repo_cap, {"aps", "many"}}} =
               WavePlan.validate_caps(%{"aps" => "many"}, ["aps"])
    end

    test "a malformed cap key is a typed refusal" do
      assert {:error, {:bad_repo_spec, "Not An Alias"}} =
               WavePlan.validate_caps(%{"Not An Alias" => 1}, ["Not An Alias"])

      assert {:error, :bad_repo_caps} = WavePlan.validate_caps("nope", ["aps"])
    end
  end

  describe "rotate/2 the no-starvation law" do
    test "round-robin over sorted aliases: first n items cover the first n repos exactly once" do
      items_by_repo = %{
        "nounverb" => [%{"id" => "nv-1"}, %{"id" => "nv-2"}],
        "aps" => [%{"id" => "aps-1"}, %{"id" => "aps-2"}, %{"id" => "aps-3"}],
        "eds" => [%{"id" => "eds-1"}]
      }

      plan = WavePlan.rotate(items_by_repo)

      assert Enum.map(plan, & &1["id"]) == [
               "aps-1",
               "eds-1",
               "nv-1",
               "aps-2",
               "nv-2",
               "aps-3"
             ]
    end

    test "a deep backlog can never starve a shallow one (one item per repo per round)" do
      items_by_repo = %{
        "deep" => Enum.map(1..7, &%{"id" => "deep-#{&1}"}),
        "shallow" => [%{"id" => "shallow-1"}]
      }

      plan = WavePlan.rotate(items_by_repo)
      ids = Enum.map(plan, & &1["id"])

      # The single shallow item lands in the FIRST round, ahead of deep's tail.
      assert Enum.take(ids, 2) == ["deep-1", "shallow-1"]
      assert Enum.count(ids, &(&1 in ["deep-1", "deep-2", "shallow-1"])) == 3
    end

    test "per-repo caps keep items in the backlog for a later wave" do
      items_by_repo = %{
        "aps" => Enum.map(1..5, &%{"id" => "aps-#{&1}"}),
        "eds" => Enum.map(1..5, &%{"id" => "eds-#{&1}"})
      }

      plan = WavePlan.rotate(items_by_repo, %{"aps" => 2})

      assert Enum.count(plan, &(&1["id"] =~ "aps-")) == 2
      assert Enum.count(plan, &(&1["id"] =~ "eds-")) == 5
    end

    test "empty and missing queues contribute nothing" do
      items_by_repo = %{"aps" => [%{"id" => "aps-1"}], "eds" => []}
      assert [%{"id" => "aps-1"}] = WavePlan.rotate(items_by_repo)
      assert [] = WavePlan.rotate(%{})
    end
  end

  # ------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------

  defp mktmp do
    dir = Path.join(System.tmp_dir!(), "wave-plan-test-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    dir
  end

  defp git_repo(path) do
    File.mkdir_p!(path)

    {_, 0} = System.cmd("git", ["-C", path, "init", "-q"])
    {_, 0} = System.cmd("git", ["-C", path, "config", "user.email", "t@t"])
    {_, 0} = System.cmd("git", ["-C", path, "config", "user.name", "t"])
    File.write!(Path.join(path, "README.md"), "test fixture\n")
    {_, 0} = System.cmd("git", ["-C", path, "add", "README.md"])
    {_, 0} = System.cmd("git", ["-C", path, "commit", "-q", "-m", "init"])

    path
  end
end
