defmodule Xaas.Ultracode.RecipeWorkerTest do
  @moduledoc """
  Chicago qualification of the deterministic construction provider
  (`Xaas.Ultracode.RecipeWorker`, GC-FRI-0800 G6 / GC23-5): real sandboxed
  Postgres Run/Epoch/Receipt rows, the real `Lease` protocol, the real
  `Xaas.Ultracode.Engine` fill with the CONFIGURED worker and provider
  allowlist, real git repositories under a real containment root, and the
  REAL registered `"recipe:mix-format"` recipe (config/config.exs) running
  the real `mix format` of the toolchain `RecipeWorker.toolchain/1`
  resolves from the target worktree (asdf layout from `.tool-versions`,
  else the running node's `mix`) through `Verifier.spawn_and_collect/6`.
  The fabric court at close is a real registered verifier suite running
  `mix format --check-formatted` against the committed head.

  Lost-lease falsifiers run a real two-step `sh` recipe whose first step
  blocks on a signal file, so the test makes the REAL lease row stale
  between the steps (expired through the Epoch `:renew_lease` action and
  re-claimed through `Lease.claim_next/3`, or refused through
  `Lease.refuse/3`) and then proves no second step, no staging and no
  commit happened. No mocks.
  """

  use ExUnit.Case, async: false

  require Ash.Query

  import ExUnit.CaptureLog

  @moduletag :ultracode

  alias Xaas.Ultracode.{Engine, Epoch, Lease, Receipt, RecipeWorker, Run, SemanticWork}

  @capability "recipe:mix-format"
  @court "recipe-format-court"
  @probe "recipe:lease-probe"

  # The canonical `capabilityId` value space of the v26.9.23 wave contract
  # (DRIVER.md / B1 context), pinned as a source string.
  @canonical_capability_id "^[a-z0-9][a-z0-9_.-]*:[a-z0-9][a-z0-9_.:-]*$"

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

    # Registered BEFORE anything below can raise: `start_owner!` spawns an
    # UNLINKED owner that holds the shared sandbox mode, so a setup crash
    # with this on_exit not yet registered would leak it and fail every
    # later module's `start_owner!(shared: true)` with `:already_shared`
    # (observed under the court's full revert-mutation: 26 cascade failures
    # masking which tests constrain the change).
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    original = %{
      suites: Application.get_env(:xaas, :ultracode_verifier_suites),
      root: Application.get_env(:xaas, :ultracode_worktree_root),
      recipes: Application.get_env(:xaas, :ultracode_construction_recipes),
      asdf: Application.get_env(:xaas, :ultracode_asdf_data_dir)
    }

    on_exit(fn ->
      restore_env(:ultracode_verifier_suites, original.suites)
      restore_env(:ultracode_worktree_root, original.root)
      restore_env(:ultracode_construction_recipes, original.recipes)
      restore_env(:ultracode_asdf_data_dir, original.asdf)
    end)

    root = canonical(mktmp("root"))
    Application.put_env(:xaas, :ultracode_worktree_root, root)

    # An asdf data dir with no installs: every `.tool-versions`-less subject
    # below resolves to the running node's toolchain on ANY host (the xaas
    # CI runner has setup-beam, not asdf), never to a host-specific path.
    Application.put_env(:xaas, :ultracode_asdf_data_dir, mktmp("asdf-empty"))

    {:ok, recipe} = RecipeWorker.recipe(@capability)
    {:ok, toolchain} = RecipeWorker.toolchain(mktmp("toolchain-probe"))
    assert toolchain["source"] == "node"
    assert File.exists?(toolchain["mix"]), inspect(toolchain)

    # The fabric's independent court for this class: the same resolved
    # toolchain, checking the postcondition (tree is formatted) at the
    # worker's committed head.
    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      @court => %{
        env: %{"PATH" => toolchain["path"], "LANG" => "en_US.UTF-8"},
        steps: [
          %{id: "format-check", argv: ["mix", "format", "--check-formatted"], timeout_ms: 300_000}
        ]
      }
    })

    %{root: root, recipe: recipe, toolchain: toolchain}
  end

  # ------------------------------------------------------------------
  # the reference KNOWN class through the real engine path
  # ------------------------------------------------------------------

  test "a format-drift epoch is committed and closed :alive by recipe-worker through the engine, and a ready zcode epoch is left untouched",
       %{root: root, recipe: recipe, toolchain: toolchain} do
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

    # The resolved toolchain identity is part of the closing evidence: the
    # subject has no `.tool-versions`, so it is the running node's.
    assert receipt.evidence["toolchain"] == toolchain
    assert receipt.evidence["toolchain"]["pin_satisfied"] == nil

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
  # a lost lease halts the recipe before any further step, add or commit
  # ------------------------------------------------------------------

  describe "a lease lost between steps" do
    setup %{root: root} do
      signals = mktmp("signals")

      Application.put_env(:xaas, :ultracode_construction_recipes, %{
        @probe => probe_recipe(signals)
      })

      worktree = git_repo(root, @formatted)
      %{signals: signals, worktree: worktree, base_head: git!(worktree, ["rev-parse", "HEAD"])}
    end

    test "re-claimed by another owner after expiry: typed :lease_lost, no second step, nothing staged or committed, the new owner's lease intact",
         %{signals: signals, worktree: worktree, base_head: base_head} do
      {_run, epoch} = running_epoch("recipe", @probe, worktree)
      task = Task.async(fn -> RecipeWorker.run(epoch, %{provider: "recipe"}) end)

      held = await_first_step(signals, epoch)
      assert held.leased_to == "recipe-worker"

      # The real lease row goes stale between the steps: TTL passed (the
      # Epoch's own :renew_lease action), then another owner re-claims it
      # through the real Lease API.
      expire_lease!(held)

      assert {:ok, _stolen, other_token, _run} =
               Lease.claim_next("recipe", "other-worker", epoch_id: epoch.id)

      release(signals)

      log =
        capture_log(fn ->
          assert {:error, {:lease_lost, {:no_lease, redacted}}} = Task.await(task, 60_000)
          send(self(), {:redacted, redacted})
        end)

      assert_received {:redacted, redacted}
      # The dead token never leaves the worker: only its sha256 fingerprint.
      assert redacted == "lease:sha256:" <> sha256_hex(held.lease_token)
      refute log =~ held.lease_token
      assert log =~ "lease lost before commit"

      assert_no_write_after_loss(signals, worktree, base_head)

      now = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
      assert now.state == :running
      assert now.leased_to == "other-worker"
      assert now.lease_token == other_token
      assert receipts_for(epoch.id) == []
    end

    test "refused by another party through Lease.refuse/3: typed :lease_lost, no commit, only that party's receipt",
         %{signals: signals, worktree: worktree, base_head: base_head} do
      {_run, epoch} = running_epoch("recipe", @probe, worktree)
      task = Task.async(fn -> RecipeWorker.run(epoch, %{provider: "recipe"}) end)

      held = await_first_step(signals, epoch)
      assert {:ok, _epoch, _receipt} = Lease.refuse(held.lease_token, :operator_cancelled, %{})
      release(signals)

      capture_log(fn ->
        assert {:error, {:lease_lost, {:lease_not_live, :failed}}} = Task.await(task, 60_000)
      end)

      assert_no_write_after_loss(signals, worktree, base_head)

      assert [receipt] = receipts_for(epoch.id)
      assert receipt.outcome == :refused
      assert receipt.evidence["refusal_reason"] == "operator_cancelled"
    end

    test "expired mid-recipe under the engine: the worker stops uncommitted and the engine reaps the epoch with a refused receipt",
         %{signals: signals, worktree: worktree, base_head: base_head} do
      {_run, epoch} = running_epoch("recipe", @probe, worktree)

      # Undirected fill: configured worker + allowlist, exactly the cron path.
      task = Task.async(fn -> Engine.fill() end)

      held = await_first_step(signals, epoch)
      expire_lease!(held)
      release(signals)

      capture_log(fn ->
        epoch_id = epoch.id

        assert [%{provider: "recipe", dispatched: [%{epoch_id: ^epoch_id, status: :reaped}]}] =
                 Task.await(task, 60_000)
      end)

      assert_no_write_after_loss(signals, worktree, base_head)

      reaped = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
      assert reaped.state == :failed
      assert [receipt] = receipts_for(epoch.id)
      assert receipt.outcome == :refused
      assert receipt.evidence["reap_reason"] == "worker_ended_without_closing"
    end
  end

  # ------------------------------------------------------------------
  # the recipe toolchain comes from the target, not from this host
  # ------------------------------------------------------------------

  test "the shipped recipe resolves its toolchain from the target and pins no PATH" do
    registered = Application.get_env(:xaas, :ultracode_construction_recipes)[@capability]
    assert registered.elixir_toolchain == :target
    refute Map.has_key?(registered.env, "PATH")
  end

  test "a target .tool-versions resolves through the asdf install layout and the recipe runs that toolchain",
       %{root: root, toolchain: node} do
    # A real asdf layout whose pinned installs are the running node's own
    # elixir and ERTS bin dirs (so the recipe really executes through them).
    asdf = mktmp("asdf")
    elixir_bin = Path.join([asdf, "installs", "elixir", "9.9.9-probe", "bin"])
    erlang_bin = Path.join([asdf, "installs", "erlang", "99.9-probe", "bin"])
    File.mkdir_p!(Path.dirname(elixir_bin))
    File.mkdir_p!(Path.dirname(erlang_bin))
    File.ln_s!(Path.dirname(node["mix"]), elixir_bin)
    File.ln_s!(Path.dirname(node["erl"]), erlang_bin)
    Application.put_env(:xaas, :ultracode_asdf_data_dir, asdf)

    pins = "elixir 9.9.9-probe\nerlang 99.9-probe # comment\n"
    worktree = git_repo(root, @drifted, %{".tool-versions" => pins})
    base_head = git!(worktree, ["rev-parse", "HEAD"])

    assert {:ok, resolved} = RecipeWorker.toolchain(worktree)
    assert resolved["source"] == "asdf"
    assert resolved["elixir"] == "9.9.9-probe"
    assert resolved["erlang"] == "99.9-probe"
    assert resolved["mix"] == Path.join(elixir_bin, "mix")
    assert resolved["erl"] == Path.join(erlang_bin, "erl")
    assert String.starts_with?(resolved["path"], elixir_bin <> ":" <> erlang_bin <> ":")
    assert resolved["pin_satisfied"] == true
    assert resolved["tool_versions"]["sha256"] == "sha256:" <> sha256_hex(pins)

    {_run, epoch} = running_epoch("recipe", @capability, worktree)
    assert :ok = RecipeWorker.run(epoch, %{provider: "recipe"})

    assert File.read!(Path.join(worktree, "drift.ex")) == @formatted
    assert git!(worktree, ["rev-parse", "HEAD~1"]) == base_head
    assert [receipt] = receipts_for(epoch.id)
    assert receipt.outcome == :alive, inspect(receipt.evidence["fabric_verifier"])
    assert receipt.evidence["toolchain"] == resolved
  end

  test "a pin asdf cannot satisfy falls back to the running node and records the unsatisfied pin",
       %{root: root, toolchain: node} do
    worktree = git_repo(root, @formatted, %{".tool-versions" => "elixir 0.0.0-absent\n"})

    assert {:ok, resolved} = RecipeWorker.toolchain(worktree)
    assert resolved["source"] == "node"
    assert resolved["mix"] == node["mix"]
    assert resolved["path"] == node["path"]
    assert resolved["pin_satisfied"] == false
    assert resolved["tool_versions"]["elixir"] == "0.0.0-absent"
  end

  test "a recipe that pins PATH next to elixir_toolchain: :target, or names another source, is refused before any claim" do
    step = %{id: "format", argv: ["mix", "format"], timeout_ms: 1_000}

    Application.put_env(:xaas, :ultracode_construction_recipes, %{
      "recipe:pinned" => %{elixir_toolchain: :target, env: %{"PATH" => "/x/bin"}, steps: [step]},
      "recipe:other" => %{elixir_toolchain: :host, env: %{}, steps: [step]}
    })

    {_run, pinned} = running_epoch("recipe", "recipe:pinned", nil)

    assert {:error, {:invalid_recipe, [problem]}} =
             RecipeWorker.run(pinned, %{provider: "recipe"})

    assert problem =~ "may not pin PATH"
    assert_unclaimed(pinned)

    {_run, other} = running_epoch("recipe", "recipe:other", nil)
    assert {:error, {:invalid_recipe, [problem]}} = RecipeWorker.run(other, %{provider: "recipe"})
    assert problem =~ "elixir_toolchain must be :target"
    assert_unclaimed(other)
  end

  # ------------------------------------------------------------------
  # the descriptor carries the capability to the Run
  # ------------------------------------------------------------------

  test "SemanticWork and Run.capability_id carry the canonical capabilityId pattern source" do
    assert SemanticWork.capability_id_pattern().source == @canonical_capability_id

    assert regex_source(Ash.Resource.Info.attribute(Run, :capability_id).constraints[:match]) ==
             @canonical_capability_id

    # Same accept set on the real admission paths.
    for ok <- ["recipe:mix-format", "a:b", "r0_.-:x.y:z-9"] do
      assert {:ok, %{capability: ^ok}} =
               SemanticWork.admit(Map.put(descriptor(), "capability", ok))

      assert {:ok, %Run{capability_id: ^ok}} = create_run(ok)
    end

    for bad <- ["Recipe:x", "recipe:", ":x", "recipe:Mix", "re cipe:x", "recipe"] do
      assert {:error, {:refused_semantic_work, {:invalid, :capability}}} =
               SemanticWork.admit(Map.put(descriptor(), "capability", bad))

      assert {:error, %Ash.Error.Invalid{}} = create_run(bad)
    end

    # `$` is end-of-string (SHACL/XSD reading), not "before a final newline".
    assert {:error, {:refused_semantic_work, {:invalid, :capability}}} =
             SemanticWork.admit(Map.put(descriptor(), "capability", "recipe:x\n"))
  end

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

  # Two real `sh` steps: the first edits the worktree, signals, and blocks
  # until released; the second only leaves a marker. PATH is POSIX-only.
  defp probe_recipe(signals) do
    %{
      env: %{"PATH" => "/usr/bin:/bin"},
      steps: [
        %{
          id: "edit",
          argv: [
            "sh",
            "-c",
            "echo edited > edited.txt && touch '#{signals}/step1' && " <>
              "while [ ! -f '#{signals}/go' ]; do sleep 0.05; done"
          ],
          timeout_ms: 60_000
        },
        %{id: "second", argv: ["sh", "-c", "touch '#{signals}/step2'"], timeout_ms: 10_000}
      ]
    }
  end

  # Waits for the first step's signal and returns the epoch with the
  # worker's live lease as the database holds it.
  defp await_first_step(signals, epoch, waited \\ 0) do
    cond do
      File.exists?(Path.join(signals, "step1")) ->
        Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)

      waited > 30_000 ->
        flunk("the recipe's first step never signalled")

      true ->
        Process.sleep(20)
        await_first_step(signals, epoch, waited + 20)
    end
  end

  defp release(signals), do: File.write!(Path.join(signals, "go"), "")

  defp expire_lease!(%Epoch{} = epoch) do
    epoch
    |> Ash.Changeset.for_update(
      :renew_lease,
      %{lease_expires_at: DateTime.add(DateTime.utc_now(), -60, :second)},
      authorize?: false
    )
    |> Ash.update!()
  end

  # The step after the loss never ran; the first step's output is in the
  # tree but never staged or committed.
  defp assert_no_write_after_loss(signals, worktree, base_head) do
    refute File.exists?(Path.join(signals, "step2"))
    assert git!(worktree, ["rev-parse", "HEAD"]) == base_head
    assert git!(worktree, ["rev-list", "--count", "HEAD"]) == "1"
    assert git!(worktree, ["diff", "--cached", "--name-only"]) == ""
    assert git!(worktree, ["status", "--porcelain"]) == "?? edited.txt"
  end

  defp create_run(capability) do
    Run
    |> Ash.Changeset.for_create(
      :create,
      %{goal: "capability pattern", provider: "recipe", capability_id: capability},
      authorize?: false
    )
    |> Ash.create()
  end

  defp regex_source({Spark.Regex, :cache, [source | _opts]}), do: source
  defp regex_source(%Regex{source: source}), do: source

  defp sha256_hex(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

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
  defp git_repo(parent, source, extra \\ %{}) do
    dir = Path.join(parent, "wt-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, ".formatter.exs"), ~s([inputs: ["*.ex"]]\n))
    File.write!(Path.join(dir, "drift.ex"), source)
    Enum.each(extra, fn {name, bytes} -> File.write!(Path.join(dir, name), bytes) end)
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
