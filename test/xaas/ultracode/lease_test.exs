defmodule Xaas.Ultracode.LeaseTest do
  @moduledoc """
  Chicago-style qualification for the ActuationLease edge on the existing
  Ultracode seam (Run/Epoch/Receipt — no new resources).

  Proves: race-safe claim over a provider-pull run, lease-keyed admission
  court (construction allowed, consequence refused under the no-ceiling
  fence, unknown tool fenced), head-verified closure sealing the existing
  Receipt vocabulary, typed refusal, and that legacy provider-less runs
  keep complete-next-cycle reactor semantics.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.{Epoch, Lease, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp provider_run_and_epoch(provider \\ "zcode-test", worktree \\ nil) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Qualify the lease edge.", provider: provider},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "Xaas.Ultracode.Lease qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  describe "claim_next/3" do
    test "binds a lease to the oldest running epoch of a provider run" do
      {run, epoch} = provider_run_and_epoch()

      assert {:ok, leased, token, run_ctx} = Lease.claim_next("zcode-test", "worker-1")
      assert leased.id == epoch.id
      assert leased.lease_token == token
      assert leased.leased_to == "worker-1"
      assert DateTime.compare(leased.lease_expires_at, DateTime.utc_now()) == :gt
      assert run_ctx.id == run.id
      assert run_ctx.goal == run.goal
    end

    test "no ready work without a provider-pull run" do
      provider_run_and_epoch(nil)

      assert {:error, :no_ready_work} = Lease.claim_next("zcode-test", "worker-1")
    end

    test "already-leased epoch is not double-claimable" do
      provider_run_and_epoch()

      {:ok, _epoch, _token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:error, :no_ready_work} = Lease.claim_next("zcode-test", "worker-2")
    end
  end

  describe "admit_tool/2" do
    test "allows construction tools under a live lease" do
      provider_run_and_epoch()
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")
    end

    test "refuses consequence tools under the no-ceiling fence" do
      provider_run_and_epoch()
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:error, {:refused_no_authority, "git_push"}} = Lease.admit_tool(token, "git_push")
      assert {:error, {:refused_no_authority, "Bash"}} = Lease.admit_tool(token, "Bash")
    end

    test "unknown tool classes are fenced" do
      provider_run_and_epoch()
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:error, {:unknown_tool_class, "TimeMachine"}} =
               Lease.admit_tool(token, "TimeMachine")
    end

    test "no lease, no admission" do
      assert {:error, _} = Lease.admit_tool("no-such-lease", "Edit")
    end

    # Real falsifier for the provider-scoping fix: before this, admit_tool
    # applied one single global `@construction_tools` vocabulary to every
    # provider's lease, regardless of which provider actually issued it.
    # Proves the fix with a real, differently-scoped provider entry
    # (ordinary Application env, not a mock of Lease itself) and two real
    # leases from two real, different provider Runs.
    test "a tool admitted for one provider's lease is refused for a different provider's lease" do
      previous = Application.get_env(:xaas, :ultracode_provider_tools)

      strict_provider = "provider-strict-#{System.unique_integer([:positive])}"
      broad_provider = "provider-broad-#{System.unique_integer([:positive])}"

      Application.put_env(:xaas, :ultracode_provider_tools, %{
        strict_provider => ~w(Edit Read),
        broad_provider => ~w(Edit Read WebFetch)
      })

      on_exit(fn ->
        if previous do
          Application.put_env(:xaas, :ultracode_provider_tools, previous)
        else
          Application.delete_env(:xaas, :ultracode_provider_tools)
        end
      end)

      provider_run_and_epoch(strict_provider)
      {:ok, _epoch, strict_token, _run} = Lease.claim_next(strict_provider, "worker-strict")

      provider_run_and_epoch(broad_provider)
      {:ok, _epoch, broad_token, _run} = Lease.claim_next(broad_provider, "worker-broad")

      # "WebFetch" is legitimately admitted for the broad provider's lease...
      assert {:ok, %{decision: :allow}} = Lease.admit_tool(broad_token, "WebFetch")

      # ...but the SAME tool name is refused when the request actually
      # comes from a different provider's lease -- never silently allowed
      # just because some other provider's lease would have allowed it.
      assert {:error, {:unknown_tool_class, "WebFetch"}} =
               Lease.admit_tool(strict_token, "WebFetch")

      # A tool both providers share is still allowed for both.
      assert {:ok, %{decision: :allow}} = Lease.admit_tool(strict_token, "Edit")
      assert {:ok, %{decision: :allow}} = Lease.admit_tool(broad_token, "Edit")
    end

    test "a provider with no explicit registry entry keeps the unchanged default vocabulary" do
      provider = "provider-unlisted-#{System.unique_integer([:positive])}"
      provider_run_and_epoch(provider)
      {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1")

      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")
      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "WebFetch")
    end

    # Falsifier for the fence-order gap the adversarial review found: the
    # refused-consequence-tools check must win even when a misconfigured
    # per-provider list happens to also name a refused tool -- the fence is
    # this domain's one non-configurable floor, never overridable by config.
    test "a misconfigured provider entry naming a refused tool still cannot defeat the fence" do
      previous = Application.get_env(:xaas, :ultracode_provider_tools)
      provider = "provider-misconfigured-#{System.unique_integer([:positive])}"

      Application.put_env(:xaas, :ultracode_provider_tools, %{
        provider => ~w(Edit Bash git_push publish)
      })

      on_exit(fn ->
        if previous do
          Application.put_env(:xaas, :ultracode_provider_tools, previous)
        else
          Application.delete_env(:xaas, :ultracode_provider_tools)
        end
      end)

      provider_run_and_epoch(provider)
      {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1")

      assert {:ok, %{decision: :allow}} = Lease.admit_tool(token, "Edit")
      assert {:error, {:refused_no_authority, "Bash"}} = Lease.admit_tool(token, "Bash")
      assert {:error, {:refused_no_authority, "git_push"}} = Lease.admit_tool(token, "git_push")
      assert {:error, {:refused_no_authority, "publish"}} = Lease.admit_tool(token, "publish")
    end
  end

  describe "actuate/2" do
    defp with_actuation_registry(registry, fun) do
      previous = Application.get_env(:xaas, :ultracode_actuation_registry)
      Application.put_env(:xaas, :ultracode_actuation_registry, registry)

      try do
        fun.()
      after
        if previous do
          Application.put_env(:xaas, :ultracode_actuation_registry, previous)
        else
          Application.delete_env(:xaas, :ultracode_actuation_registry)
        end
      end
    end

    test "a registered pair reaches the real Xaas.Actuation.run/4 DO kernel, with lease-provenanced authority" do
      provider = "zcode-actuate-#{System.unique_integer([:positive])}"
      marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-actuate"})

      with_actuation_registry(
        %{
          provider => %{
            {"Xaas.Marketplace.Provider", "actuate_status"} =>
              {Xaas.Marketplace.Provider, :actuate_status, marketplace_provider.id}
          }
        },
        fn ->
          provider_run_and_epoch(provider)
          {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1")

          key = "lease-actuate-#{System.unique_integer([:positive])}"

          assert {:ok, envelope} =
                   Lease.actuate(token, %{
                     "resource" => "Xaas.Marketplace.Provider",
                     "action" => "actuate_status",
                     "input" => %{"status" => "active"},
                     "idempotency_key" => key
                   })

          assert envelope.status == :succeeded
          refute envelope.replay?

          # The real mutation actually landed through the real Reactor DO path,
          # against exactly the registry-bound subject.
          assert Xaas.Marketplace.Provider
                 |> Ash.get!(marketplace_provider.id, authorize?: false)
                 |> Map.fetch!(:status) == :active

          # Authority evidence is real, non-empty, and bound to this exact
          # lease -- never an empty/delegated authority map.
          intent =
            Ash.get!(Xaas.Operations.ActuationIntent, envelope.intent.id, authorize?: false)

          assert intent.authority["kind"] == "ultracode_lease_actuation"
          assert intent.authority["provider"] == provider
          assert intent.authority["lease_fingerprint"]
          # Never the raw bearer token itself.
          refute intent.authority["lease_fingerprint"] == token

          # actuate/2 grants no admit_tool/2 allowance -- the two surfaces
          # stay independent on the very same lease.
          assert {:error, {:refused_no_authority, "Bash"}} = Lease.admit_tool(token, "Bash")
        end
      )
    end

    # Falsifier for the broken-object-level-authorization gap the adversarial
    # review found: subject_id used to be raw wire input, so ANY live lease
    # of the registered provider could name an arbitrary row of the
    # registered resource. The fix removed the wire field entirely -- the
    # registry binds the exact subject. Proves the fix by attempting exactly
    # the attack the review demonstrated: a second, unrelated Provider row
    # that the registry entry never names must be unreachable.
    test "a caller cannot redirect a registered actuation onto an unrelated row" do
      provider = "zcode-actuate-idor-#{System.unique_integer([:positive])}"
      bound_provider = Xaas.Generator.create_provider!(%{org_id: "org-actuate-bound"})
      other_provider = Xaas.Generator.create_provider!(%{org_id: "org-actuate-other"})

      with_actuation_registry(
        %{
          provider => %{
            {"Xaas.Marketplace.Provider", "actuate_status"} =>
              {Xaas.Marketplace.Provider, :actuate_status, bound_provider.id}
          }
        },
        fn ->
          provider_run_and_epoch(provider)
          {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1")

          # An attacker-style request tries to smuggle a different subject_id
          # in the wire map -- the contract has no such field, so it is
          # simply ignored; the registry-bound subject is always used.
          assert {:ok, envelope} =
                   Lease.actuate(token, %{
                     "resource" => "Xaas.Marketplace.Provider",
                     "action" => "actuate_status",
                     "subject_id" => other_provider.id,
                     "input" => %{"status" => "active"},
                     "idempotency_key" =>
                       "lease-actuate-idor-#{System.unique_integer([:positive])}"
                   })

          assert envelope.status == :succeeded

          # The registry-bound provider changed...
          assert Xaas.Marketplace.Provider
                 |> Ash.get!(bound_provider.id, authorize?: false)
                 |> Map.fetch!(:status) == :active

          # ...the unrelated one the wire tried to name never did.
          assert Xaas.Marketplace.Provider
                 |> Ash.get!(other_provider.id, authorize?: false)
                 |> Map.fetch!(:status) != :active
        end
      )
    end

    test "an unregistered {resource, action} pair is refused, never silently reaching Path A" do
      provider = "zcode-actuate-unregistered-#{System.unique_integer([:positive])}"
      provider_run_and_epoch(provider)
      {:ok, _epoch, token, _run} = Lease.claim_next(provider, "worker-1")

      assert {:error, {:unregistered_actuation, {"Xaas.Marketplace.Provider", "actuate_status"}}} =
               Lease.actuate(token, %{
                 "resource" => "Xaas.Marketplace.Provider",
                 "action" => "actuate_status",
                 "idempotency_key" => "lease-actuate-unregistered"
               })
    end

    test "no lease, no actuation" do
      assert {:error, _} =
               Lease.actuate("no-such-lease", %{
                 "resource" => "Xaas.Marketplace.Provider",
                 "action" => "actuate_status",
                 "idempotency_key" => "lease-actuate-no-lease"
               })
    end

    test "a pair registered for a different provider's lease is still refused" do
      strict_provider = "zcode-actuate-strict-#{System.unique_integer([:positive])}"
      other_provider = "zcode-actuate-other-#{System.unique_integer([:positive])}"

      with_actuation_registry(
        %{
          other_provider => %{
            {"Xaas.Marketplace.Provider", "actuate_status"} =>
              {Xaas.Marketplace.Provider, :actuate_status, "00000000-0000-0000-0000-000000000000"}
          }
        },
        fn ->
          provider_run_and_epoch(strict_provider)
          {:ok, _epoch, token, _run} = Lease.claim_next(strict_provider, "worker-1")

          assert {:error, {:unregistered_actuation, {_, _}}} =
                   Lease.actuate(token, %{
                     "resource" => "Xaas.Marketplace.Provider",
                     "action" => "actuate_status",
                     "idempotency_key" => "lease-actuate-cross-provider"
                   })
        end
      )
    end
  end

  describe "close/4" do
    test "an :alive claim on a Run with NO verifier suite downgrades to :partial_alive -- alive is court-manufactured only" do
      worktree = make_git_worktree()
      provider_run_and_epoch("zcode-test", worktree)
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, epoch, receipt} =
               Lease.close(token, git_head(worktree), :alive, %{"verifier" => "mix test"})

      assert epoch.state == :completed
      assert epoch.final_head == git_head(worktree)

      # Receipt vocabulary law: the head was verified, but no registered
      # court ran, so `:alive` may not be sealed (`Lease.close/4` performs
      # the honest downgrade itself; `Validations.AliveRequiresCourt`
      # refuses at the boundary should any path ever try).
      assert receipt.outcome == :partial_alive
      assert receipt.evidence["head_verified"] == true
      assert receipt.evidence["verifier_suite_absent"] == true
    end

    test "a claimed :partial_alive with no verifier suite still seals :partial_alive" do
      worktree = make_git_worktree()
      provider_run_and_epoch("zcode-test", worktree)
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, _epoch, receipt} = Lease.close(token, git_head(worktree), :partial_alive)

      assert receipt.outcome == :partial_alive
      assert receipt.evidence["head_verified"] == true
    end

    test "downgrades to build_broken on head mismatch" do
      worktree = make_git_worktree()
      provider_run_and_epoch("zcode-test", worktree)
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      real = git_head(worktree)

      # PERMANENT TRIPWIRE (observed falsifier 2026-09-19, wave-8 flake hunt):
      # a sha is hex, so the real head already starts with "0" for ~1 in 16
      # commits -- and then `"0" <> rest` is a NO-OP: the "fake" head IS the
      # real head, close/4 honestly verifies the match (head_verified: true),
      # finds no verifier court, and downgrades to :partial_alive -- the
      # production law working correctly against a buggy fixture (this exact
      # failure was captured live: evidence %{"head_verified" => true}). Flip
      # the leading char to a value the real head provably does not have.
      fake =
        if(String.starts_with?(real, "0"), do: "1", else: "0") <>
          String.slice(real, 1..-1//1)

      assert {:ok, _epoch, receipt} = Lease.close(token, fake, :alive)
      assert receipt.outcome == :build_broken
      assert receipt.evidence["head_verified"] == false
    end

    test "downgrades to partial_alive when no worktree is verifiable" do
      provider_run_and_epoch("zcode-test", nil)
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, _epoch, receipt} = Lease.close(token, "abc123", :alive)
      assert receipt.outcome == :partial_alive
      assert receipt.evidence["verifier_unavailable"]
    end
  end

  describe "refuse/3" do
    test "lands the epoch failed with a refused receipt" do
      provider_run_and_epoch()
      {:ok, _epoch, token, _run} = Lease.claim_next("zcode-test", "worker-1")

      assert {:ok, epoch, receipt} = Lease.refuse(token, :refused_no_authority)
      assert epoch.state == :failed
      assert receipt.outcome == :refused
      assert receipt.evidence["refusal_reason"] == "refused_no_authority"
    end
  end

  describe "worktree safety (Xaas.Ultracode.Validations.WorktreeIsSafe)" do
    # Real fs-safety hardening pass (2026-09): before this validation,
    # every shape below passed `Epoch.create` unchanged and was handed
    # straight back to a claiming worker via `claim_next`'s `worktree`
    # field -- confirmed via a real repro against the dev DB, not
    # guessed. These are the same real Ash `Epoch.create` call the
    # customer-facing controller's `create_running_epoch/3` makes.

    defp epoch_create(worktree) do
      {:ok, run} =
        Run
        |> Ash.Changeset.for_create(
          :create,
          %{goal: "worktree safety qualification", provider: "zcode-worktree-safety"},
          authorize?: false
        )
        |> Ash.create()

      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "worktree safety qualification",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()
    end

    test "a real git worktree is admitted" do
      worktree = make_git_worktree()
      assert {:ok, epoch} = epoch_create(worktree)
      assert epoch.worktree == worktree
    end

    test "nil worktree is unchanged/legal (no destination to validate)" do
      assert {:ok, epoch} = epoch_create(nil)
      assert epoch.worktree == nil
    end

    test "a relative path is refused as worktree_not_absolute" do
      assert {:error, error} = epoch_create("relative/path")

      assert %Ash.Error.Invalid{errors: [%{field: :worktree, message: "worktree_not_absolute"}]} =
               error
    end

    test "root is refused (not a real git repository) as worktree_not_a_git_repo" do
      assert {:error, error} = epoch_create("/")

      assert %Ash.Error.Invalid{
               errors: [%{field: :worktree, message: "worktree_not_a_git_repo"}]
             } = error
    end

    test "/etc is refused as worktree_not_a_git_repo" do
      assert {:error, error} = epoch_create("/etc")

      assert %Ash.Error.Invalid{
               errors: [%{field: :worktree, message: "worktree_not_a_git_repo"}]
             } = error
    end

    test "a traversal shape is refused as worktree_traversal even though the raw string starts with /" do
      worktree = make_git_worktree()
      traversal = worktree <> "/../../etc"

      assert {:error, error} = epoch_create(traversal)

      assert %Ash.Error.Invalid{errors: [%{field: :worktree, message: "worktree_traversal"}]} =
               error
    end

    test "a nonexistent path is refused as worktree_not_found" do
      missing = Path.join(System.tmp_dir(), "xaas-worktree-safety-missing-#{run_uid()}")

      assert {:error, error} = epoch_create(missing)

      assert %Ash.Error.Invalid{errors: [%{field: :worktree, message: "worktree_not_found"}]} =
               error
    end

    test "a real, existing directory that is NOT a git repo is refused as worktree_not_a_git_repo" do
      plain_dir =
        Path.join(System.tmp_dir(), "xaas-worktree-safety-plain-#{run_uid()}")

      File.mkdir_p!(plain_dir)

      assert {:error, error} = epoch_create(plain_dir)

      assert %Ash.Error.Invalid{
               errors: [%{field: :worktree, message: "worktree_not_a_git_repo"}]
             } = error
    end
  end

  describe "claim_next/3 directed claims (epoch_id)" do
    test "a directed claim binds exactly the named epoch, not the oldest ready one" do
      provider = "zcode-directed-#{System.unique_integer([:positive])}"
      {_run_old, older} = provider_run_and_epoch(provider)
      {_run_new, younger} = provider_run_and_epoch(provider)

      assert {:ok, claimed, _token, _run} =
               Lease.claim_next(provider, "worker-d", epoch_id: younger.id)

      assert claimed.id == younger.id
      assert claimed.leased_to == "worker-d"

      untouched = Ash.get!(Epoch, older.id, action: :read_unscoped, authorize?: false)
      assert is_nil(untouched.lease_token)

      assert {:ok, next, _token, _run} = Lease.claim_next(provider, "worker-e")
      assert next.id == older.id
    end

    test "a directed claim of an already-leased epoch is no_ready_work, never another epoch" do
      provider = "zcode-directed-#{System.unique_integer([:positive])}"
      {_run_a, a} = provider_run_and_epoch(provider)
      {_run_b, b} = provider_run_and_epoch(provider)

      assert {:ok, %{id: id}, _token, _run} = Lease.claim_next(provider, "w1", epoch_id: a.id)
      assert id == a.id

      assert {:error, :no_ready_work} = Lease.claim_next(provider, "w2", epoch_id: a.id)

      still_free = Ash.get!(Epoch, b.id, action: :read_unscoped, authorize?: false)
      assert is_nil(still_free.lease_token)
    end

    test "a directed claim cannot reach another provider's epoch or a nonexistent id" do
      {_run, other} = provider_run_and_epoch("zcode-directed-other")

      assert {:error, :no_ready_work} =
               Lease.claim_next("zcode-directed-mine", "w", epoch_id: other.id)

      assert {:error, :no_ready_work} =
               Lease.claim_next("zcode-directed-other", "w", epoch_id: Ecto.UUID.generate())
    end
  end

  describe "EpochReactor provider-pull semantics" do
    test "provider-pull running epoch awaits provider instead of auto-completing" do
      {_run, epoch} = provider_run_and_epoch()

      assert {:ok, result} = Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: epoch.id})

      assert result.action_taken == :await_provider

      # The await_provider turn is a TICK HEARTBEAT, not standing: its
      # receipt is the typed non-standing `:heartbeat` class -- never
      # `:alive` (that manufactured the standing pollution this class law
      # ends; only a qualifying terminal court manufactures `:alive`).
      assert result.outcome == :heartbeat

      reloaded = Ash.get!(Epoch, epoch.id, action: :read_unscoped)
      assert reloaded.state == :running

      receipt = Ash.get!(Xaas.Ultracode.Receipt, result.receipt_id, authorize?: false)
      assert receipt.outcome == :heartbeat
      assert receipt.evidence["action_taken"] == "await_provider"
      refute Map.has_key?(receipt.evidence, "head_verified")
    end

    test "legacy provider-less run keeps complete-next-cycle semantics" do
      {_run, epoch} = provider_run_and_epoch(nil)

      assert {:ok, result} = Reactor.run(Xaas.Ultracode.EpochReactor, %{epoch_id: epoch.id})

      assert result.action_taken == :complete
      assert Ash.get!(Epoch, epoch.id, action: :read_unscoped).state == :completed
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp make_git_worktree do
    # Temp paths must not collide ACROSS mix test runs: System.unique_integer
    # restarts per BEAM while $TMPDIR is shared by every concurrently running
    # `mix test` VM, so two VMs can pick the SAME worktree dir -- observed
    # 2026-09-19 (full-suite run): a colliding VM's `git init`/cleanup made
    # `rev-parse HEAD` exit 128 inside `Lease.close/4`'s head verification,
    # downgrading the receipt to :partial_alive where :build_broken was
    # asserted. Wall-clock-qualify every per-run artifact path (the
    # dispatch_test `run_uid` convention).
    dir = Path.join(System.tmp_dir(), "xaas-lease-test-#{run_uid()}")
    File.mkdir_p!(dir)

    System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    System.cmd(
      "git",
      ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
      stderr_to_stdout: true,
      env: [
        {"GIT_AUTHOR_NAME", "test"},
        {"GIT_AUTHOR_EMAIL", "test@test"},
        {"GIT_COMMITTER_NAME", "test"},
        {"GIT_COMMITTER_EMAIL", "test@test"}
      ]
    )

    dir
  end

  defp git_head(worktree) do
    {out, 0} = System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"])
    String.trim(out)
  end

  # Temp paths must not collide ACROSS mix test runs (see make_git_worktree
  # above): System.unique_integer restarts per BEAM, $TMPDIR is machine-wide.
  defp run_uid, do: System.system_time(:millisecond)
end
