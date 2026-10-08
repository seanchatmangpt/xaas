defmodule Xaas.Ultracode.ProviderMesh.RemainderCourtW984dzTest do
  @moduledoc """
  W984dz court for the uncovered provider_mesh remainder: Supervisor, Reconciler,
  Router, plus thin-transport dispositions (Telemetry, DispatchAdapter,
  ProviderAdapter, Exclusion).

  Chicago discipline: real GenServers (Registry/HealthStore under a real
  :rest_for_one Supervisor), real anonymous provider modules with real
  invoke/3 and health/0, real :telemetry handlers. Zero mocks.
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.ProviderMesh.{
    Candidate,
    Capability,
    DispatchAdapter,
    Exclusion,
    Failure,
    HealthSnapshot,
    HealthStore,
    Outcome,
    ProviderAdapter,
    Reconciler,
    Registry,
    Router,
    Supervisor,
    Telemetry
  }

  describe "Supervisor (state-bearing: spawns Registry + HealthStore, rest_for_one)" do
    test "starts both children under caller-owned names; stores hold real state" do
      # Mutation rationale: if Supervisor dropped a child or used wrong strategy,
      # the named GenServers would be absent and put/get/register would fail.
      reg = :"w984dz_reg_#{System.unique_integer([:positive])}"
      hs = :"w984dz_hs_#{System.unique_integer([:positive])}"

      assert {:ok, sup} =
               Supervisor.start_link(registry: reg, health_store: hs)

      assert Process.whereis(reg) |> is_pid()
      assert Process.whereis(hs) |> is_pid()

      # real state through the real children
      c = Candidate.new("p1", W984dzOkProvider)
      assert :ok = Registry.register(reg, c)
      assert [%Candidate{id: "p1"}] = Registry.candidates(reg)

      assert :ok = HealthStore.put(hs, HealthSnapshot.healthy("p1", %{rtt: 3}))
      assert %{status: :healthy, detail: %{rtt: 3}} = HealthStore.get(hs, "p1")

      ref = Process.monitor(sup)
      :ok = Elixir.Supervisor.stop(sup)
      assert_receive {:DOWN, ^ref, :process, ^sup, _}

      # children die with the supervisor (supervision, not orphaned state)
      refute Process.whereis(reg)
      refute Process.whereis(hs)
    end

    test "default options bind the module-named singletons" do
      # Mutation rationale: swapping the Keyword.get default would leave the
      # default Registry/HealthStore names unsupervised.
      # (Non-async singleton: exercises the default-name path exactly once.)
      sup = start_supervised!(Supervisor)
      assert Process.whereis(Xaas.Ultracode.ProviderMesh.Registry) |> is_pid()
      assert Process.whereis(Xaas.Ultracode.ProviderMesh.HealthStore) |> is_pid()
      assert Elixir.Supervisor.which_children(sup)
             |> Enum.map(&elem(&1, 0)) |> Enum.sort() ==
               [Xaas.Ultracode.ProviderMesh.HealthStore, Xaas.Ultracode.ProviderMesh.Registry]
    end
  end

  describe "Reconciler (state-bearing via real health/0 collaborator calls)" do
    test "maps real module health/0 results to healthy snapshots" do
      # Mutation rationale: inverting the healthy/unhealthy branches, or dropping
      # the function_exported? guard, flips these assertions.
      cs = [Candidate.new("okp", W984dzHealthyProvider)]

      assert [%HealthSnapshot{provider_id: "okp", status: :healthy, detail: %{probe: 1}}] =
               Reconciler.observe(cs)
    end

    test "maps {:error, r} to unhealthy preserving reason; non-tuple to invalid_health" do
      cs = [
        Candidate.new("bad", W984dzErrorProvider),
        Candidate.new("odd", W984dzOddProvider)
      ]

      snaps = Reconciler.observe(cs) |> Enum.into(%{}, &{&1.provider_id, &1})

      assert %{status: :unhealthy, detail: {:down, "db"}} = snaps["bad"]
      assert %{status: :unhealthy, detail: {:invalid_health, :weird}} = snaps["odd"]
    end

    test "provider without health/0 yields {:error, :health_unavailable} -> unhealthy" do
      # Mutation rationale: removing the function_exported? fallback would raise
      # UndefinedFunctionError instead of producing an unhealthy snapshot.
      cs = [Candidate.new("noh", W984dzOkProvider)]

      [snap] = Reconciler.observe(cs)
      assert %{provider_id: "noh", status: :unhealthy} = snap
      assert match?(detail when detail in [:health_unavailable, {:error, :health_unavailable}],
                    snap.detail),
             "unexpected detail: #{inspect(snap.detail)}"
    end
  end

  describe "Router (real Selector/Outcome/Failure collaborators)" do
    test "routes to the highest-priority capable provider and returns value + provider id" do
      # Mutation rationale: dropping the priority ordering in Selector, or
      # mis-tagging the winner's id, breaks the %{provider: "hi"} assertion.
      cs = [
        Candidate.new("lo", W984dzOkProvider, priority: 200),
        Candidate.new("hi", W984dzOkProvider, priority: 10)
      ]

      assert {:ok, %{provider: "hi", value: {:echoed, :x}, excluded: []}} =
               Router.route(cs, :echo, :x)
    end

    test "filters by real Capability.supported?/2 — incapable providers are never invoked" do
      # Mutation rationale: replacing Enum.filter with a pass-through would
      # invoke the incapable provider and produce a non-:unsupported failure
      # path (or wrong exhaustion list).
      cs = [Candidate.new("only_echo", W984dzOkProvider)]

      assert {:error, {:providers_exhausted, :translate, []}} =
               Router.route(cs, :translate, "bonjour")
    end

    test "failed invoke is Failure.classed and tried on the next candidate; excluded trail returned" do
      # Mutation rationale: breaking Failure.class (terminal vs transient) or
      # the accumulation order of `ex` corrupts the excluded trail asserted here.
      cs = [
        Candidate.new("flaky", W984dzFailingProvider, priority: 10),
        Candidate.new("solid", W984dzOkProvider, priority: 20)
      ]

      assert {:ok, %{provider: "solid", excluded: [{"flaky", :terminal, {:boom, "no"}}]}} =
               Router.route(cs, :echo, :y)
    end

    test "invalid provider outcome (non-tuple) is normalized to an error and skipped" do
      # Mutation rationale: Outcome.normalize passing raw values through would
      # make Router return {:ok, :weird} instead of exhausting.
      cs = [Candidate.new("odd", W984dzOddProvider)]

      assert {:error, {:providers_exhausted, :echo,
                     [{"odd", :terminal, {:invalid_provider_outcome, :weird}}]}} =
               Router.route(cs, :echo, :z)
    end
  end

  describe "thin-transport dispositions" do
    test "Telemetry.event/2 executes a real :telemetry event with count=1 measurements" do
      # Mutation rationale: changing the event prefix or measurements map is
      # observed directly by the attached handler.
      test_pid = self()
      handler_id = :"w984dz_#{System.unique_integer([:positive])}"

      on_exit(fn -> :telemetry.detach(handler_id) end)

      :ok =
        :telemetry.attach(handler_id, [:xaas, :ultracode, :provider_mesh, :probe], fn _n, m, _md, _ ->
        send(test_pid, {:telemetry_fired, m})
      end, nil)

      assert :ok = Telemetry.event(:probe, %{lane: "w984dz"})
      assert_receive {:telemetry_fired, %{count: 1}}
    end

    test "DispatchAdapter.invoke/3 maps dispatch statuses to ok/error" do
      # Mutation rationale: the %{status: :ok} vs other-status clauses are the
      # whole module; swapping them inverts these assertions.
      ok = DispatchAdapter.invoke(W984dzDispatchOk, :evt)
      assert {:ok, %{status: :ok}} = ok

      assert {:error, {:degraded, %{status: :degraded}}} =
               DispatchAdapter.invoke(W984dzDispatchDegraded, :evt)

      assert {:error, :hard_down} = DispatchAdapter.invoke(W984dzDispatchError, :evt)
    end

    test "ProviderAdapter.invoke/4 honours invoke/3 when exported, else :unsupported_provider" do
      # Mutation rationale: dropping the function_exported? guard raises instead
      # of returning the typed :unsupported_provider error.
      assert {:ok, {:echoed, 1}} = ProviderAdapter.invoke(W984dzOkProvider, :echo, 1)
      assert {:error, :unsupported_provider} = ProviderAdapter.invoke(NotAModule984dz, :echo, 1)
    end

    test "Exclusion.new/2 stamps provider_id, reason, and a real monotonic timestamp" do
      # Mutation rationale: dropping the `at` stamp (or using wall clock) is
      # caught by the monotonic-range assertion.
      before = System.monotonic_time(:millisecond)
      e = Exclusion.new("p9", :rate_limited)
      after_t = System.monotonic_time(:millisecond)

      assert %Exclusion{provider_id: "p9", reason: :rate_limited, at: at} = e
      assert at >= before and at <= after_t
    end
  end
end

# -- real collaborators (hand-written real behaviours, not mocks) --

defmodule W984dzOkProvider do
  def capabilities, do: [:echo]
  def invoke(:echo, p, _o), do: {:ok, {:echoed, p}}
end

defmodule W984dzFailingProvider do
  def capabilities, do: [:echo]
  def invoke(:echo, _p, _o), do: {:error, {:boom, "no"}}
end

defmodule W984dzHealthyProvider do
  def capabilities, do: [:echo]
  def invoke(:echo, p, _o), do: {:ok, p}
  def health, do: {:ok, %{probe: 1}}
end

defmodule W984dzErrorProvider do
  def capabilities, do: [:echo]
  def health, do: {:error, {:down, "db"}}
end

defmodule W984dzOddProvider do
  def capabilities, do: [:echo]
  def invoke(:echo, _p, _o), do: :weird
  def health, do: :weird
end

defmodule W984dzDispatchOk do
  def dispatch(_e, _o), do: {:ok, %{status: :ok, id: 1}}
end

defmodule W984dzDispatchDegraded do
  def dispatch(_e, _o), do: {:ok, %{status: :degraded}}
end

defmodule W984dzDispatchError do
  def dispatch(_e, _o), do: {:error, :hard_down}
end
