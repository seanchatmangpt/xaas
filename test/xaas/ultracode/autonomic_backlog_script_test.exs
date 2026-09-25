defmodule Xaas.Ultracode.AutonomicBacklogScriptTest do
  use ExUnit.Case, async: false

  @moduledoc """
  Qualifies the per-repo sense-script seam (`Xaas.Ultracode.Autonomic.backlog_script/1`)
  and the real SPR sense execution behind it: `priv/verifiers/spr_backlog.py`
  run through the real `Autonomic.sense/1` (real provisioned worktree, real
  python3, deterministic backlog) against a real local clone of the operator's
  SparsePrimingRepresentations repository.

  The default law is asserted too: an alias with no registered script falls
  back to `aps_backlog.py`, so APS behavior is unchanged by the seam.

  Tagged `:subprocess` (each test shells out to git/python3) and skipped by
  name when the operator SPR clone or python3 is missing.
  """

  alias Xaas.Ultracode.Autonomic

  @moduletag :subprocess

  @source Path.expand("~/xaas-worktrees/repos/spr")

  @moduletag skip:
               (cond do
                  not File.dir?(Path.join(@source, ".git")) ->
                    "operator SPR clone missing at #{@source}"

                  is_nil(System.find_executable("python3")) ->
                    "python3 not on PATH"

                  true ->
                    false
                end)

  setup do
    _ = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    original =
      for key <- [
            :ultracode_backlog_scripts,
            :ultracode_worktree_root,
            :ultracode_ticket_dir,
            :ultracode_repos
          ],
          into: %{},
          do: {key, Application.get_env(:xaas, key)}

    base =
      Path.join(
        System.tmp_dir!(),
        "spr-sense-#{:crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)}"
      )

    File.mkdir_p!(base)
    repo = Path.join(base, "spr")
    {_, 0} = System.cmd("git", ["clone", "-q", @source, repo], stderr_to_stdout: true)

    Application.put_env(:xaas, :ultracode_backlog_scripts, %{"spr" => "spr_backlog.py"})
    Application.put_env(:xaas, :ultracode_worktree_root, Path.join(base, "runs"))
    Application.put_env(:xaas, :ultracode_ticket_dir, Path.join(base, "tickets"))
    Application.put_env(:xaas, :ultracode_repos, %{"spr" => repo})

    on_exit(fn ->
      for {key, value} <- original, do: Application.put_env(:xaas, key, value)
      File.rm_rf!(base)
    end)

    %{base: base, repo: repo}
  end

  test "unregistered alias falls back to the default aps_backlog.py script" do
    script = Autonomic.backlog_script(%{repo: "some-other-repo"})
    assert Path.basename(script) == "aps_backlog.py"
    assert script == Application.app_dir(:xaas, "priv/verifiers/aps_backlog.py")
  end

  test "a registered alias resolves its own script from the app priv dir" do
    script = Autonomic.backlog_script(%{repo: "spr"})
    assert Path.basename(script) == "spr_backlog.py"
    assert File.regular?(script)
  end

  test "sense/1 runs the real SPR backlog script against a real provisioned worktree" do
    ctx = Autonomic.new_ctx(repo: "spr")

    assert {:ok, items} = Autonomic.sense(ctx)

    # The live SPR tree always leaves at least one public function with thin
    # negative coverage (the suite only has so many negative fixtures), but the
    # exact set is head-dependent (the loop promotes commits into the clone), so
    # the contract here is the ITEM SHAPE and the script's own boundedness.
    assert is_list(items) and items != []

    for item <- items do
      assert item["id"] =~ ~r/^spr-neg-[a-z_]+$/
      assert is_binary(item["goal"]) and item["goal"] != ""
      assert item["allowed_paths"] == ["tests/test_sprtool.py"]
      assert is_integer(item["min_new_tests"]) and item["min_new_tests"] >= 1
      assert Map.has_key?(item, "mutants")
    end

    assert items == Enum.sort_by(items, & &1["id"])
    assert length(items) <= 8

    # The sense worktree was cleaned up: nothing leaked into the run root.
    leftovers =
      Path.join(Application.fetch_env!(:xaas, :ultracode_worktree_root), "aps-sense-#{ctx.nonce}")

    refute File.exists?(leftovers)
  end
end
