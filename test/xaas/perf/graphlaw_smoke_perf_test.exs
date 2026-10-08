defmodule Xaas.Perf.GraphlawSmokeTest do
  @moduledoc """
  Lane W982x — smoke-perf rung of the verify ladder (the gap W946/W972/W977b
  correctness courts leave open; benchmark class is explicitly out of scope).

  Two real smoke tripwires, no synthetic micro-benchmarks:

    1. GraphQL-assess path latency: 200 real `Xaas.Bridges.Graphlaw.assess/2`
       calls — full path: LimitGate Postgres-backed limit reads
       (`Xaas.Graphlaw.Catalog.limits_by_scope/1` over the real sandboxed
       `Xaas.Repo`) + WASM engine N3/SHACL derivation through the real
       test-env pool (`config :ash_graphlaw, start_pool: true`) — with the
       median asserted under a generous ceiling. This is a tripwire, not a
       benchmark claim.
    2. Census-scale sanity: the 3 heaviest typical Ash resource CRUD
       round-trips from the Library domain (Book create + read, Checkout
       `:borrow`, HoldRequest `:place`) over real Postgres, median under a
       generous ceiling over 100 iterations.

  ## Ceiling provenance (honest, measured-then-set)

  Ceilings are measured-median x3, set from the first W982x run on this
  machine (M-series host, local brew postgresql@14, asdf elixir 1.20.2-otp-28)
  and recorded in the W982x receipt
  (`docs/sjira/v26.10.6/plans/w982x-perf-smoke.md`). A 3x headroom tripwire
  fails only when the real path degrades ~3x from the witnessed baseline —
  the smoke rung's job, nothing more.

  Excluded by default (`@moduletag :perf_smoke` + `test_helper.exs` exclude);
  run explicitly with `mix test --include perf_smoke`. No `:eu_ai_act` tag.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Bridges.Graphlaw
  alias Xaas.Library.{Book, Checkout, HoldRequest}

  @moduletag :perf_smoke

  # Ceilings set from measured W982x medians x3, rounded up (see moduledoc +
  # receipt). Measured run 1: assess median 13.383ms -> ceiling 45ms
  # (13.383x3 ~= 40.2, rounded up); heaviest CRUD op checkout_borrow median
  # 17.2265ms -> 55ms (x3 ~= 51.7, rounded up). All other CRUD op medians
  # were below the borrow median, so one ceiling covers them all.
  @assess_median_ceiling_ms 45
  @crud_median_ceiling_ms 55

  @n 200
  @crud_n 100

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    # Real Postgres-backed limit registry rows so the assess path's LimitGate
    # reads actual EngineLimit rows on every call (not the fail-open miss).
    seed_limit!("max_json_depth", 64)
    seed_limit!("max_request_bytes", 16 * 1024 * 1024)
    seed_limit!("n3_max_term_bytes", 64 * 1024)
    seed_limit!("n3_max_total_bytes", 256 * 1024 * 1024)

    :ok
  end

  test "graphlaw assess path: median of 200 real calls under the smoke ceiling" do
    assert match?({:ok, _}, AshGraphLaw.Pool.info()), "live WASM host required for this court"
    claim = %{"amount" => 100, "limit" => 500}

    times =
      for _ <- 1..@n do
        {us, result} = :timer.tc(fn -> Graphlaw.assess(claim) end)
        assert match?({:ok, _}, result), "assess refused during timing: #{inspect(result)}"
        us / 1000.0
      end

    median = median_ms(times)
    IO.puts("[W982x] assess median=#{format(median)}ms over #{@n} calls")
    assert median < @assess_median_ceiling_ms,
           "assess median #{format(median)}ms >= #{@assess_median_ceiling_ms}ms smoke ceiling"
  end

  test "census-scale CRUD sanity: 3 heaviest library round-trips median under ceiling" do
    # A fresh reader per iteration: the domain's real per-student open-checkout
    # cap (3) would otherwise refuse iteration 4+ — the cap is real law, so
    # the court borrows under 100 real fresh patrons instead of bypassing it.
    {borrow_times, place_times, read_times, create_times, _acc} =
      Enum.reduce(1..@crud_n, {[], [], [], [], nil}, fn _i, {bt, pt, rt, ct, _} ->
        user = Xaas.Generator.create_user!()

        # Fresh real rows each iteration (unique titles via Generator sequence).
        {t_create, book} = timed(fn -> Xaas.Generator.create_book!() end)

        {t_read, _read_book} =
          timed(fn -> Ash.get!(Book, book.id, authorize?: false) end)

        {t_borrow, _checkout} =
          timed(fn ->
            Checkout
            |> Ash.Changeset.for_create(:borrow, %{
              book_id: book.id,
              user_id: user.id,
              school_id: "willow-creek"
            })
            |> Ash.create!(authorize?: false)
          end)

        {t_place, _hold} =
          timed(fn ->
            HoldRequest
            |> Ash.Changeset.for_create(:place, %{
              book_id: book.id,
              user_id: user.id,
              school_id: "willow-creek"
            })
            |> Ash.create!(authorize?: false)
          end)

        {bt ++ [t_borrow / 1000.0], pt ++ [t_place / 1000.0], rt ++ [t_read / 1000.0],
         ct ++ [t_create / 1000.0], user}
      end)

    medians = %{
      book_create: median_ms(create_times),
      book_read: median_ms(read_times),
      checkout_borrow: median_ms(borrow_times),
      hold_place: median_ms(place_times)
    }

    IO.puts("[W982x] CRUD medians=#{inspect(medians)} over #{@crud_n} iterations")

    Enum.each(medians, fn {op, ms} ->
      assert ms < @crud_median_ceiling_ms,
             "#{op} median #{format(ms)}ms >= #{@crud_median_ceiling_ms}ms smoke ceiling"
    end)
  end

  defp seed_limit!(name, value) do
    Xaas.Graphlaw.EngineLimit
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      value: value,
      scope: "abi",
      source: "w982x-smoke-court",
      unit: "count"
    })
    |> Ash.create!(authorize?: false, upsert?: true)
  end

  defp timed(fun), do: :timer.tc(fun)

  defp median_ms(samples) do
    sorted = Enum.sort(samples)
    mid = div(length(sorted), 2)

    if rem(length(sorted), 2) == 0,
      do: (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2,
      else: Enum.at(sorted, mid)
  end

  defp format(ms), do: :erlang.float_to_binary(ms * 1.0, decimals: 3)
end
