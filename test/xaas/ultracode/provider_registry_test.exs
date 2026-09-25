defmodule Xaas.Ultracode.ProviderRegistryTest do
  @moduledoc """
  Qualification of `Xaas.Ultracode.ProviderRegistry` (selection closing
  UNSUPPORTED(provider-selection:policy)) and of `Lease.claim_next_among/3`
  (the candidate-provider-list claim routing).

  Fail-closed law under court: an empty registry, an unknown provider, a
  disabled provider, a missing capability, and an unknown/absent authority
  ceiling are each a TYPED refusal -- never a silent default. The anti-vacuity
  shape (`lease_test.exs`'s fence-cannot-be-defeated pattern): every "selects
  X" claim is paired with the mutation that must flip it ("disables X ->
  selection refuses").
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.{Epoch, Lease, ProviderRegistry, Run}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  defp with_registry(reg, fun) do
    previous = Application.get_env(:xaas, :ultracode_providers)
    Application.put_env(:xaas, :ultracode_providers, reg)

    try do
      fun.()
    after
      if previous do
        Application.put_env(:xaas, :ultracode_providers, previous)
      else
        Application.delete_env(:xaas, :ultracode_providers)
      end
    end
  end

  defp provider_run_and_epoch(provider) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "registry selection qualification.", provider: provider},
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
          exact_subject: "provider-registry-test:#{System.unique_integer([:positive])}",
          state: :running
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  # ------------------------------------------------------------------
  # Registry access
  # ------------------------------------------------------------------

  describe "registry/0 + lookup/1" do
    test "unset config is the EMPTY registry (fail-closed, no default provider invented)" do
      previous = Application.get_env(:xaas, :ultracode_providers)
      Application.delete_env(:xaas, :ultracode_providers)

      try do
        assert %{} = ProviderRegistry.registry()
        assert {:error, {:unknown_provider, "zcode"}} = ProviderRegistry.lookup("zcode")
      after
        if previous do
          Application.put_env(:xaas, :ultracode_providers, previous)
        else
          Application.delete_env(:xaas, :ultracode_providers)
        end
      end
    end

    test "lookup returns the configured entry, typed for unknown ids" do
      entry = %{capabilities: ["construction"], enabled: true}

      with_registry(%{"alpha" => entry}, fn ->
        assert {:ok, ^entry} = ProviderRegistry.lookup("alpha")
        assert {:error, {:unknown_provider, "beta"}} = ProviderRegistry.lookup("beta")
      end)
    end
  end

  # ------------------------------------------------------------------
  # Selection (the admission court)
  # ------------------------------------------------------------------

  describe "select/2" do
    test "empty registry: typed refusal, never a silent default" do
      with_registry(%{}, fn ->
        assert {:error, {:no_qualifying_provider, []}} =
                 ProviderRegistry.select(%{capabilities: ["construction"]})
      end)
    end

    test "selects the enabled, capable provider whose ceiling covers the requirement" do
      with_registry(
        %{
          "a" => %{capabilities: ["construction"], authority_ceiling: :construction, enabled: true},
          "b" => %{capabilities: ["gall_work"], authority_ceiling: :construction, enabled: true}
        },
        fn ->
          assert {:ok, "a", %{capabilities: ["construction"]}} =
                   ProviderRegistry.select(%{capabilities: ["construction"]})
        end
      )
    end

    test "a DISABLED provider is invisible to selection (kill-switch falsifier)" do
      with_registry(
        %{
          "a" => %{capabilities: ["construction"], authority_ceiling: :construction, enabled: false}
        },
        fn ->
          assert {:error, {:no_qualifying_provider, [%{provider: "a", verdict: :disabled}]}} =
                   ProviderRegistry.select(%{capabilities: ["construction"]})
        end
      )
    end

    test "a provider missing a required capability is refused with the exact gap named" do
      with_registry(
        %{
          "a" => %{capabilities: ["construction"], authority_ceiling: :construction, enabled: true}
        },
        fn ->
          assert {:error,
                  {:no_qualifying_provider,
                   [%{provider: "a", verdict: {:missing_capabilities, ["gall_work"]}}]}} =
                   ProviderRegistry.select(%{capabilities: ["gall_work"]})
        end
      )
    end

    test "an authority ceiling below the requirement is refused; an equal one passes" do
      with_registry(
        %{
          "low" => %{capabilities: ["construction"], authority_ceiling: :none, enabled: true},
          "ok" => %{capabilities: ["construction"], authority_ceiling: :construction, enabled: true}
        },
        fn ->
          assert {:ok, "ok", _} =
                   ProviderRegistry.select(%{capabilities: ["construction"], authority: :construction})

          assert {:error,
                  {:no_qualifying_provider,
                   [
                     %{provider: "low", verdict: {:authority_ceiling_too_low, :none}},
                     %{provider: "ok", verdict: {:authority_ceiling_too_low, :construction}}
                   ]}} =
                   ProviderRegistry.select(%{capabilities: ["construction"], authority: :actuation})
        end
      )
    end

    test "an entry with NO ceiling and an unknown REQUIRED authority term are typed refusals" do
      with_registry(
        %{
          "no-ceiling" => %{capabilities: ["construction"], enabled: true},
          "bad-ceiling" => %{capabilities: ["construction"], authority_ceiling: :omnipotent, enabled: true}
        },
        fn ->
          # Rejection details list EVERY candidate in deterministic (sorted)
          # order, each with its own typed verdict.
          assert {:error,
                  {:no_qualifying_provider,
                   [
                     %{provider: "bad-ceiling", verdict: :unknown_authority_term},
                     %{provider: "no-ceiling", verdict: :unknown_authority_term}
                   ]}} =
                   ProviderRegistry.select(%{capabilities: ["construction"]})

          assert {:error, {:no_qualifying_provider, _}} =
                   ProviderRegistry.select(%{capabilities: ["construction"], authority: :unknown_term})
        end
      )
    end

    test "policy :cost orders ascending with deterministic id tie-break; :capability by coverage" do
      with_registry(
        %{
          "cheap-b" => %{capabilities: ["construction"], authority_ceiling: :construction, enabled: true, cost: 1},
          "cheap-a" => %{capabilities: ["construction"], authority_ceiling: :construction, enabled: true, cost: 1},
          "rich" => %{
            capabilities: ["construction", "gall_work"],
            authority_ceiling: :construction,
            enabled: true,
            cost: 9
          }
        },
        fn ->
          # :cost default: cost 1 tie between cheap-a/cheap-b broken by id.
          assert {:ok, "cheap-a", _} = ProviderRegistry.select(%{capabilities: ["construction"]})

          # :capability: the wider provider wins regardless of cost.
          assert {:ok, "rich", _} =
                   ProviderRegistry.select(%{capabilities: ["construction"]}, policy: :capability)

          # :name: deterministic.
          assert {:ok, "cheap-a", _} =
                   ProviderRegistry.select(%{capabilities: ["construction"]}, policy: :name)
        end
      )
    end

    test "disable/1 is the live kill switch and enable/1 re-arms it" do
      entry = %{capabilities: ["construction"], authority_ceiling: :construction, enabled: true}

      with_registry(%{"a" => entry}, fn ->
        assert ProviderRegistry.disable("a") == true
        assert {:error, {:no_qualifying_provider, _}} = ProviderRegistry.select(%{capabilities: ["construction"]})

        # The entry survived the disable (config loss would be a second harm).
        assert {:ok, %{enabled: false}} = ProviderRegistry.lookup("a")

        assert ProviderRegistry.enable("a") == false
        assert {:ok, "a", _} = ProviderRegistry.select(%{capabilities: ["construction"]})
      end)
    end

    test "disable of an unknown provider is typed" do
      with_registry(%{}, fn ->
        assert {:error, {:unknown_provider, "ghost"}} = ProviderRegistry.disable("ghost")
      end)
    end
  end

  # ------------------------------------------------------------------
  # Capability-id law (CONTRACT: provider identity ONLY as left segment)
  # ------------------------------------------------------------------

  describe "capability_left_segment/1" do
    test "left segment is the provider identity; segment-free ids are provider-neutral" do
      assert ProviderRegistry.capability_left_segment("zcode:fix-build") == "zcode"
      assert ProviderRegistry.capability_left_segment("recipe:mix-format") == "recipe"
      assert ProviderRegistry.capability_left_segment("construction") == "construction"
    end
  end

  # ------------------------------------------------------------------
  # claim_next_among/3 -- the candidate-provider-list claim
  # ------------------------------------------------------------------

  describe "claim_next_among/3" do
    test "routes to the first provider with ready work, skipping empty queues" do
      provider_run_and_epoch("among-b")

      assert {:ok, epoch, token, run} =
               Lease.claim_next_among(["among-a-empty", "among-b"], "worker-1")

      assert run.provider == "among-b"
      assert is_binary(token) and epoch.state == :running
    end

    test "deduplicates the candidate list (no double-bind from repeated entries)" do
      provider_run_and_epoch("among-dedup")

      assert {:ok, epoch, _token, run} =
               Lease.claim_next_among(["among-dedup", "among-dedup", "among-dedup"], "worker-1")

      assert run.provider == "among-dedup"
      assert epoch.lease_token
    end

    test "a provider at pool capacity is skipped (recorded), work re-routes" do
      # Capacity 1 on the blocked provider, unbounded on the fallback. The
      # per-call :pool_capacity opt rides through claim_next_among so the
      # fence (not merely an empty queue) is what routes this test.
      provider_run_and_epoch("among-cap-full")
      {:ok, _epoch, _token, _run} = Lease.claim_next("among-cap-full", "holder", pool_capacity: 1)

      provider_run_and_epoch("among-cap-free")

      assert {:ok, _epoch, _token, run} =
               Lease.claim_next_among(["among-cap-full", "among-cap-free"], "worker-2",
                 pool_capacity: 1
               )

      assert run.provider == "among-cap-free"
    end

    test "every candidate dry: typed no_ready_work_among naming tried and capacity-blocked providers" do
      assert {:error, {:no_ready_work_among, [], []}} = Lease.claim_next_among([], "worker-1")

      provider_run_and_epoch("among-cap-only")
      {:ok, _e, _t, _r} = Lease.claim_next("among-cap-only", "holder", pool_capacity: 1)

      assert {:error, {:no_ready_work_among, ["among-cap-only", "among-dry"], ["among-cap-only"]}} =
               Lease.claim_next_among(["among-cap-only", "among-dry"], "worker-1",
                 pool_capacity: 1
               )
    end

    test "never double-binds under concurrency across the candidate list" do
      provider_run_and_epoch("among-race")

      results =
        1..10
        |> Task.async_stream(
          fn i -> Lease.claim_next_among(["among-race", "among-race"], "worker-#{i}") end,
          max_concurrency: 10,
          timeout: 15_000
        )
        |> Enum.map(fn {:ok, result} -> result end)

      wins = Enum.filter(results, &match?({:ok, _, _, _}, &1))

      assert length(wins) == 1,
             "expected exactly one winner across the whole candidate list, got #{length(wins)}"
    end
  end

  # ------------------------------------------------------------------
  # Default-provider dehardcode
  # ------------------------------------------------------------------

  describe "default_provider/0" do
    test "the historical default is named in exactly one place" do
      assert ProviderRegistry.default_provider() == "zcode"
    end
  end
end
