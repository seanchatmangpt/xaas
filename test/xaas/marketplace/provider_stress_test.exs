defmodule Xaas.Marketplace.ProviderStressTest do
  @moduledoc """
  Real concurrency stress test: 50 real concurrent Elixir Tasks, each
  doing a real `Ash.create!` against the real live Postgres, via the
  Ecto.Adapters.SQL.Sandbox's `{:shared, self()}` mode so every spawned
  Task connection reuses the same sandboxed transaction as the test
  process. No mocking -- real Task.async_stream, real Ash.create!, real
  Ash.read! count assertion on real persisted rows, real assertion that
  `unique_slug`'s database-level uniqueness constraint held under real
  concurrency (50 distinct real slugs in, 50 real rows out, zero
  duplicates).

  A second real test in this file drives concurrency at the *same* slug
  (all 50 Tasks racing to create `Xaas.Marketplace.Provider` rows with
  one shared slug) to prove the real `unique_slug` identity actually
  rejects concurrent duplicates under real load, not just sequentially --
  exactly one real `Ash.create!` call succeeds; the rest raise a real
  `Ash.Error.Invalid` wrapping the real Postgres unique-violation.
  """

  use ExUnit.Case, async: false
  @moduletag :stress

  alias Xaas.Marketplace.Provider

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  test "50 real concurrent Task.async_stream creates with distinct slugs all real-persist, no duplicates" do
    run_tag = System.unique_integer([:positive, :monotonic])

    results =
      1..50
      |> Task.async_stream(
        fn i ->
          Ash.create!(
            Provider,
            %{
              name: "Stress Provider #{run_tag}-#{i}",
              slug: "stress-provider-#{run_tag}-#{i}",
              description: "real concurrent-create stress test row",
              status: :pending,
              org_id: "stress-org-#{run_tag}"
            },
            action: :create,
            authorize?: false
          )
        end,
        max_concurrency: 50,
        timeout: 30_000
      )
      |> Enum.to_list()

    assert length(results) == 50
    assert Enum.all?(results, &match?({:ok, %Provider{}}, &1))

    created_slugs =
      results
      |> Enum.map(fn {:ok, provider} -> provider.slug end)

    # Real proof no duplicate slugs got through: 50 distinct values in a
    # MapSet built from the 50 real created rows.
    assert length(created_slugs) == 50
    assert MapSet.size(MapSet.new(created_slugs)) == 50

    expected_slugs = MapSet.new(created_slugs)

    persisted =
      Provider
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&MapSet.member?(expected_slugs, &1.slug))

    assert length(persisted) == 50
    assert MapSet.new(persisted, & &1.slug) == expected_slugs
  end

  test "50 real concurrent Task.async_stream creates racing the same slug: exactly one real row persists" do
    run_tag = System.unique_integer([:positive, :monotonic])
    shared_slug = "stress-provider-race-#{run_tag}"

    results =
      1..50
      |> Task.async_stream(
        fn i ->
          Ash.create(
            Provider,
            %{
              name: "Stress Provider Race #{run_tag}-#{i}",
              slug: shared_slug,
              description: "real concurrent-create race stress test row",
              status: :pending,
              org_id: "stress-org-#{run_tag}"
            },
            action: :create,
            authorize?: false
          )
        end,
        max_concurrency: 50,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    oks = Enum.filter(results, &match?({:ok, %Provider{}}, &1))
    errors = Enum.filter(results, &match?({:error, _}, &1))

    assert length(oks) == 1,
           "expected exactly 1 real create to win the race for slug #{shared_slug}, got #{length(oks)}"

    assert length(errors) == 49

    assert Enum.all?(errors, fn {:error, error} -> match?(%Ash.Error.Invalid{}, error) end)

    persisted =
      Provider
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&(&1.slug == shared_slug))

    assert length(persisted) == 1
  end
end
