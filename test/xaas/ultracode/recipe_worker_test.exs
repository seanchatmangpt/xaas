defmodule Xaas.Ultracode.RecipeWorkerTest do
  @moduledoc """
  Chicago qualification of the deterministic construction provider
  (`Xaas.Ultracode.RecipeWorker`, GC-FRI-0800 G6): real sandboxed Postgres
  Run/Epoch/Receipt rows, the real `Lease` protocol, the real
  `Xaas.Ultracode.Engine` fill with the CONFIGURED worker and provider
  allowlist, real git repositories under a real containment root, and the
  REAL registered `"recipe:mix-format"` recipe (config/config.exs) running
  the real pinned `mix format` through `Verifier.spawn_and_collect/6`. The
  fabric court at close is a real registered verifier suite running
  `mix format --check-formatted` against the committed head. No mocks.
  """

  use ExUnit.Case, async: false

  require Ash.Query

  @moduletag :ultracode

  alias Xaas.Ultracode.{Engine, Epoch, Receipt, RecipeWorker, Run, SemanticWork}

  @capability "recipe:mix-format"
  @court "recipe-format-court"

  @drifted """
  defmodule Drift do
    def add(  a,b ),do:   a+b
  end
  """

  @formatted """
  defmodule Drift do
    def add(a, b), do: a + b
  end
  """

  setup do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)

    original = %{
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      recipes: Application.get_env(:xaas, :ultracode_construction_recipes)
    }

    root = canonical(mktmp("root"))
    Application.put_env(:xaas, :ultracode_worktree_root, root)

    # The fabric's independent court for this class: the SAME pinned
    # toolchain env the registered recipe declares, checking the
    # postcondition (tree is formatted) at the worker's committed head.
    {:ok, recipe} = RecipeWorker.recipe(@capability)
    mix = recipe.env["PATH"] |> String.split(":") |> hd() |> Path.join("mix")
    assert File.exists?(mix), "pinned recipe toolchain missing on this host: #{mix}"

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      @court => %{
        env: recipe.env,
        steps: [
          %{id: "format-check", argv: ["mix", "format", "--check-formatted"], timeout_ms: 300_000}
        ]
      }
    })

    on_exit(fn ->
      restore_env(:ultracode_verifier_suites, original.suites)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_construction_recipes, original.recipes)
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end)

    %{root: root, recipe: recipe}
  end

  # ------------------------------------------------------------------
  # the reference KNOWN class through the real engine path
  # ------------------------------------------------------------------

  test "a format-drift epoch is committed and closed :alive by recipe-worker through the engine, and a ready zcode epoch is left untouched",
       %{root: root, recipe: recipe} do
    worktree = git_repo(root, @drifted)
    base_head = git!(worktree, ["rev-parse", "HEAD"])

    {_run, epoch} = running_epoch("recipe", @capability, worktree)
    {_zrun, zepoch} = running_epoch("zcode", nil, nil)

    # Undirected fill: the configured worker ({RecipeWorker, :run}) and the
    # configured allowlist (["recipe"]) decide everything.
    reports = Engine.fill()

    assert [%{provider: "recipe", dispatched: [%{epoch_id: epoch_id, status: :done} = slot]}] =
             reports

    assert epoch_id == epoch.id

    closed = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert closed.state == :completed
    assert closed.leased_to == "recipe-worker"
    assert closed.final_head == slot.final_head

    # The delta is a real commit on top of the base, authored by the worker,
    # and the postcondition holds in the tree.
    head = git!(worktree, ["rev-parse", "HEAD"])
    assert head == closed.final_head
    assert head != base_head
    assert git!(worktree, ["rev-parse", "HEAD~1"]) == base_head
    assert git!(worktree, ["log", "-1", "--format=%an"]) == "recipe-worker"
    assert git!(worktree, ["status", "--porcelain"]) == ""
    assert File.read!(Path.join(worktree, "drift.ex")) == @formatted

    message = git!(worktree, ["log", "-1", "--format=%B"])
    assert message =~ "recipe(#{@capability}): deterministic construction"
    assert message =~ "argv_sha256: #{RecipeWorker.argv_digest(recipe)}"

    receipt = Ash.get!(Receipt, slot.receipt_id, authorize?: false)
    assert receipt.outcome == :alive, inspect(receipt.evidence["fabric_verifier"])
    assert receipt.evidence["executor"] == "recipe-worker"
    assert receipt.evidence["recipe"] == @capability
    assert receipt.evidence["argv_sha256"] == RecipeWorker.argv_digest(recipe)
    assert receipt.evidence["argv_sha256"] =~ ~r/^[0-9a-f]{64}$/
    assert receipt.evidence["base_head"] == base_head
    assert receipt.evidence["head_verified"] == true
    assert [%{"id" => "format", "exit" => 0, "status" => "pass"}] = receipt.evidence["steps"]

    assert %{"status" => "pass", "suite" => @court, "head" => ^head} =
             receipt.evidence["fabric_verifier"]

    # The zcode epoch was never discovered, claimed, reaped, or receipted.
    untouched = Ash.get!(Epoch, zepoch.id, action: :read_unscoped, authorize?: false)
    assert untouched.state == :running
    assert is_nil(untouched.lease_token)
    assert is_nil(untouched.leased_to)
    assert receipts_for(zepoch.id) == []
  end

  test "a directed fill of a non-allowlisted provider without an explicit worker dispatches nothing" do
    {_zrun, zepoch} = running_epoch("zcode", nil, nil)

    assert [%{provider: "zcode", dispatched: [], outcome: :provider_not_allowlisted}] =
             Engine.fill(providers: ["zcode"])

    untouched = Ash.get!(Epoch, zepoch.id, action: :read_unscoped, authorize?: false)
    assert untouched.state == :running
    assert is_nil(untouched.lease_token)
    assert receipts_for(zepoch.id) == []
  end

  # ------------------------------------------------------------------
  # refusals
  # ------------------------------------------------------------------

  test "an already-formatted subject is refused :no_delta with no commit", %{root: root} do
    worktree = git_repo(root, @formatted)
    base_head = git!(worktree, ["rev-parse", "HEAD"])
    {_run, epoch} = running_epoch("recipe", @capability, worktree)

    assert :ok = RecipeWorker.run(epoch, %{provider: "recipe"})

    failed = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert failed.state == :failed
    assert failed.leased_to == "recipe-worker"
    assert git!(worktree, ["rev-parse", "HEAD"]) == base_head
    assert git!(worktree, ["status", "--porcelain"]) == ""

    assert [receipt] = receipts_for(epoch.id)
    assert receipt.outcome == :refused
    assert receipt.evidence["refusal_reason"] == "no_delta"
    assert receipt.evidence["executor"] == "recipe-worker"
    assert receipt.evidence["recipe"] == @capability
    assert [%{"id" => "format", "status" => "pass"}] = receipt.evidence["steps"]
  end

  test "an unregistered capability is refused before any claim: no lease bound, no receipt" do
    {_run, epoch} = running_epoch("recipe", "recipe:not-registered", nil)

    assert {:error, :unregistered_recipe} = RecipeWorker.run(epoch, %{provider: "recipe"})
    assert_unclaimed(epoch)

    {_run, bare} = running_epoch("recipe", nil, nil)
    assert {:error, :unregistered_recipe} = RecipeWorker.run(bare, %{provider: "recipe"})
    assert_unclaimed(bare)
  end

  test "an inadmissible recipe (placeholder argv) is refused before any claim", %{recipe: recipe} do
    Application.put_env(:xaas, :ultracode_construction_recipes, %{
      "recipe:bad" => %{
        env: recipe.env,
        steps: [%{id: "x", argv: ["mix", "format", "{worktree}"], timeout_ms: 1_000}]
      }
    })

    {_run, epoch} = running_epoch("recipe", "recipe:bad", nil)

    assert {:error, {:invalid_recipe, [problem]}} =
             RecipeWorker.run(epoch, %{provider: "recipe"})

    assert problem =~ "non-literal argv element"
    assert_unclaimed(epoch)
  end

  test "a worktree outside the containment root is refused after claim, never mutated" do
    outside = canonical(mktmp("outside"))
    worktree = git_repo(outside, @drifted)
    base_head = git!(worktree, ["rev-parse", "HEAD"])
    {_run, epoch} = running_epoch("recipe", @capability, worktree)

    assert :ok = RecipeWorker.run(epoch, %{provider: "recipe"})

    assert [receipt] = receipts_for(epoch.id)
    assert receipt.outcome == :refused
    assert receipt.evidence["refusal_reason"] == "worktree_not_contained"
    assert receipt.evidence["containment"] == "worktree_outside_root"
    assert git!(worktree, ["rev-parse", "HEAD"]) == base_head
    assert File.read!(Path.join(worktree, "drift.ex")) == @drifted
  end

  # ------------------------------------------------------------------
  # the descriptor carries the capability to the Run
  # ------------------------------------------------------------------

  test "SemanticWork admits an sj:capabilityId-shaped capability and refuses a malformed one" do
    assert {:ok, admitted} = SemanticWork.admit(Map.put(descriptor(), "capability", @capability))
    assert admitted.capability == @capability

    assert {:ok, without} = SemanticWork.admit(descriptor())
    refute Map.has_key?(without, :capability)

    for bad <- ["Recipe Mix", "mix-format", "", 42] do
      assert {:error, {:refused_semantic_work, {:invalid, :capability}}} =
               SemanticWork.admit(Map.put(descriptor(), "capability", bad))
    end
  end

  # ------------------------------------------------------------------
  # fixtures
  # ------------------------------------------------------------------

  defp running_epoch(provider, capability, worktree) do
    attrs =
      %{goal: "recipe qualification", provider: provider, capability_id: capability}
      |> then(fn a ->
        if provider == "recipe", do: Map.put(a, :verifier_suite, @court), else: a
      end)

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "recipe qualification subject",
          state: :running,
          expected_at: DateTime.utc_now(),
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  defp assert_unclaimed(epoch) do
    fresh = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
    assert fresh.state == :running
    assert is_nil(fresh.lease_token)
    assert is_nil(fresh.leased_to)
    assert is_nil(fresh.claimed_at)
    assert receipts_for(epoch.id) == []
  end

  defp receipts_for(epoch_id) do
    Receipt
    |> Ash.Query.filter(epoch_id == ^epoch_id)
    |> Ash.read!(authorize?: false)
  end

  defp descriptor do
    %{
      "work_order_iri" => "urn:sj:wo:fri-t2-format",
      "checkpoint_iri" => "urn:sj:checkpoint:GC-FRI-0800",
      "graph_digest" => "sha256:" <> String.duplicate("a", 64),
      "repository_identity" => "seanchatmangpt/ggen_igniter",
      "execution_repo_alias" => "ggen_igniter",
      "base_sha" => String.duplicate("b", 40),
      "goal" => "mix format drift repair",
      "provider" => "recipe",
      "verifier_suite" => @court,
      "execution_policy" => "continuous_epoch_run",
      "dependencies" => []
    }
  end

  # A real git repository (its own top level) with a formatter config and
  # one tracked source file, committed.
  defp git_repo(parent, source) do
    dir = Path.join(parent, "wt-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, ".formatter.exs"), ~s([inputs: ["*.ex"]]\n))
    File.write!(Path.join(dir, "drift.ex"), source)
    git!(dir, ["init", "--quiet"])
    git!(dir, ["add", "-A"])
    git!(dir, ["commit", "--quiet", "-m", "subject"])
    canonical(dir)
  end

  defp git!(dir, args) do
    {out, 0} =
      System.cmd("git", ["-C", dir | args],
        stderr_to_stdout: true,
        env: [
          {"GIT_AUTHOR_NAME", "t"},
          {"GIT_AUTHOR_EMAIL", "t@t"},
          {"GIT_COMMITTER_NAME", "t"},
          {"GIT_COMMITTER_EMAIL", "t@t"}
        ]
      )

    String.trim(out)
  end

  defp restore_env(key, nil), do: Application.delete_env(:xaas, key)
  defp restore_env(key, value), do: Application.put_env(:xaas, key, value)

  defp mktmp(label) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-recipe-test-#{label}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf(dir) end)
    dir
  end

  defp canonical(path) do
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", path])
    String.trim(out)
  end
end
