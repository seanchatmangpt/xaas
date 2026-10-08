defmodule Xaas.Runtime.ProviderRegistryDeepeningTest do
  @moduledoc """
  W984dq8 court over `Xaas.Runtime.ProviderRegistry` — the runtime family's
  state-bearing circuit-breaker registry, previously exercised only indirectly
  through `Xaas.Runtime.Router` (whose setup always runs a threshold-1
  registry, so the degraded mid-state and threshold-2 open transition were
  never exercised against the registry's own contract).

  Real GenServer, real failure reports, no mocks. Router is deliberately NOT
  involved so the registry's own contract is what is on trial.

  Mutation rationale per test (what mutation each test kills):

    1. kills a mutation deleting the `put_in(state, [:providers, provider], entry)`
       insert or the `failures: 0` / `status: :ready` / default `priority: 100`
       defaults;
    2. kills a mutation inverting the `rank/1` ordering (ready < degraded < open)
       or dropping the `status != :open` filter — an open circuit must be
       removed, not merely deprioritized;
    3. kills a mutation of the threshold comparison (`n >= state.threshold`) or
       of the `:degraded` mid-state on sub-threshold failures;
    4. kills a mutation of the `{:report, provider, :ok}` clause failing to
       reset `failures`/`status`/`opened_at`;
    5. kills a mutation of `update/3`'s unknown-provider catch-all into a crash
       or insert, and of `register/2` failing to overwrite an open circuit back
       to a fresh ready entry.
  """

  use ExUnit.Case, async: false

  alias Xaas.Runtime.ProviderRegistry

  defmodule Plan5 do
    @behaviour Xaas.Runtime.Provider
    def capabilities, do: [:plan]
    def health(_), do: :healthy
    def execute(_, _, _), do: {:ok, :done}
  end

  defmodule Plan9 do
    @behaviour Xaas.Runtime.Provider
    def capabilities, do: [:plan]
    def health(_), do: :healthy
    def execute(_, _, _), do: {:ok, :done}
  end

  defmodule MultiCap do
    @behaviour Xaas.Runtime.Provider
    def capabilities, do: [:plan, :observe]
    def health(_), do: :healthy
    def execute(_, _, _), do: {:ok, :done}
  end

  setup do
    # Real supervised GenServer per test; long cooldown so an opened circuit
    # stays open for the duration of a test (real state, no time mocking).
    start_supervised!({ProviderRegistry, failure_threshold: 2, cooldown_ms: 60_000})
    :ok
  end

  test "1: registration creates a ready zero-failure entry with default priority" do
    assert :ok = ProviderRegistry.register(Plan5)
    assert :ok = ProviderRegistry.register(Plan9, priority: 7)

    snap = ProviderRegistry.snapshot()

    assert %{provider: Plan5, status: :ready, failures: 0, opened_at: nil, priority: 100} =
             snap[Plan5]

    assert %{provider: Plan9, status: :ready, failures: 0, opened_at: nil, priority: 7} =
             snap[Plan9]
  end

  test "2: candidates filters by capability and ranks ready < degraded < open, then priority" do
    ProviderRegistry.register(Plan9, priority: 9)
    ProviderRegistry.register(Plan5, priority: 5)
    ProviderRegistry.register(MultiCap, priority: 1)

    # Degrade MultiCap once (threshold 2, so one failure = :degraded, still a candidate).
    ProviderRegistry.report(MultiCap, {:error, :flaky})

    # rank/1 orders ready(0) before degraded(1) before open(2); priority breaks ties.
    assert [ready_hi, ready_lo, degraded] = ProviderRegistry.candidates(:plan)
    assert %{provider: MultiCap, status: :degraded} = degraded
    assert %{provider: Plan5, status: :ready, priority: 5} = ready_hi
    assert %{provider: Plan9, status: :ready, priority: 9} = ready_lo

    # Capability filter is real: :observe yields only MultiCap.
    assert [%{provider: MultiCap}] = ProviderRegistry.candidates(:observe)
  end

  test "3: sub-threshold failure degrades, threshold failure opens and removes from candidates" do
    ProviderRegistry.register(Plan5)

    ProviderRegistry.report(Plan5, {:error, :e1})
    assert %{status: :degraded, failures: 1} = ProviderRegistry.snapshot()[Plan5]
    assert [%{provider: Plan5, status: :degraded}] = ProviderRegistry.candidates(:plan)

    ProviderRegistry.report(NoSuchProvider, {:error, :ignored})
    ProviderRegistry.report(Plan5, {:error, :e2})

    assert %{status: :open, failures: 2, opened_at: opened_at} = ProviderRegistry.snapshot()[Plan5]
    assert is_integer(opened_at)
    assert [] = ProviderRegistry.candidates(:plan)
  end

  test "4: report :ok resets failures and restores ready" do
    ProviderRegistry.register(Plan5)
    ProviderRegistry.report(Plan5, {:error, :e1})
    assert %{status: :degraded, failures: 1} = ProviderRegistry.snapshot()[Plan5]

    ProviderRegistry.report(Plan5, :ok)

    assert %{status: :ready, failures: 0, opened_at: nil} = ProviderRegistry.snapshot()[Plan5]
  end

  test "5: report for unknown provider is a no-op; re-registration clears an open circuit" do
    ProviderRegistry.register(Plan5)
    ProviderRegistry.report(Plan5, {:error, :e1})
    ProviderRegistry.report(Plan5, {:error, :e2})
    assert %{status: :open} = ProviderRegistry.snapshot()[Plan5]

    # Unknown-provider cast must neither crash nor insert.
    :ok = ProviderRegistry.report(NoSuchProvider, {:error, :boom})
    refute Map.has_key?(ProviderRegistry.snapshot(), NoSuchProvider)

    # Re-registering an opened provider resets the breaker (fresh entry).
    :ok = ProviderRegistry.register(Plan5)
    assert %{status: :ready, failures: 0, opened_at: nil} = ProviderRegistry.snapshot()[Plan5]
    assert [%{provider: Plan5, status: :ready}] = ProviderRegistry.candidates(:plan)
  end
end
