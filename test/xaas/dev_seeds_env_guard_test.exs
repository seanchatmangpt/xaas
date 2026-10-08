defmodule Xaas.DevSeedsEnvGuardTest do
  @moduledoc """
  Permanent guard court for the `Xaas.DevSeeds` environment fence (lane
  W983f, closing W982r's "open guard" residual:
  `docs/sjira/v26.10.6/plans/w982r-nextread-cluster.md`). The leak it
  guards against really happened: a bare `mix run` DevSeeds execution
  committed 10 `library_books` + 2 `library_checkouts` + 1 curation
  straight to `xaas_test` (a bare `mix run` never runs
  `test/test_helper.exs`, so the SQL sandbox stays in :auto ownership
  mode and every write commits). This court re-fires the exact leak shape
  every run: an unsandboxed caller in :test env must be refused with the
  typed `REFUSED(dev_seeds, env=...)` error, and the real `library_books`
  table must be unchanged (real count before/after) — no mocking, real
  Postgres, real ownership manager.
  """
  use ExUnit.Case, async: false

  alias Xaas.Library.Book

  test "run/0 refuses an unsandboxed :test-env caller with a typed error and writes nothing" do
    # Real sandboxed connection for the before/after counts (this test
    # process's writes/reads roll back at teardown).
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    count_before = Ash.count!(Book, authorize?: false)

    # The refusal probe runs in a RAW spawned process (deliberately NOT a
    # Task: Tasks inherit the `$callers` chain, which the ownership
    # manager consults, so a Task under this checked-out test would be
    # treated as sandboxed). A raw spawn has no `$callers`, no checkout,
    # and no allow -- exactly the shape of the bare `mix run` process
    # that polluted xaas_test (W982r).
    parent = self()

    pid =
      spawn(fn ->
        result =
          try do
            Xaas.DevSeeds.run()
            :ran
          rescue
            e -> {:raised, e}
          end

        send(parent, {:w983f_result, result})
      end)

    assert_receive {:w983f_result, {:raised, %Mix.Error{message: msg}}}, 15_000
    refute Process.alive?(pid)

    assert msg =~ "REFUSED(dev_seeds"
    assert msg =~ "env=test"

    # Nothing leaked: the real table is unchanged after the refused call.
    count_after = Ash.count!(Book, authorize?: false)
    assert count_after == count_before
  end

  test "run/0 remains available to a sandboxed :test-env caller (existing courts stay green)" do
    # A real checked-out owner is the one sanctioned non-dev path: the
    # sandbox rollback is the pollution-prevention mechanism itself.
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    assert %{org: %{slug: "acme-dev"}} = Xaas.DevSeeds.run()
  end

  test "run(e2e: true) seeds for real through the committed e2e code path" do
    # Proves the opt-in branch runs the real seed chain end to end (the
    # same call e2e/seed-library.exs makes). The checkout here gives the
    # spawned process a sandbox connection that rolls back at process
    # exit; the truly unsandboxed :auto shape of the real e2e script is
    # not reproducible mid-suite (global ownership mode) and is witnessed
    # instead by the fresh-boot Playwright run (W984bs receipt). The
    # no-opt-in refusal discrimination is covered by the two tests above.
    parent = self()

    spawn(fn ->
      result =
        try do
          :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
          Xaas.DevSeeds.run(e2e: true)
        rescue
          e -> {:raised, e}
        end

      send(parent, {:w984bs_result, result})
    end)

    assert_receive {:w984bs_result, %{org: %{slug: "acme-dev"}, library_books: books}}, 15_000
    assert length(books) == 10
  end

  test "run(e2e: false) is still refused from an unsandboxed :test-env caller" do
    # The opt-in must be spelled `e2e: true` -- anything else (absent,
    # false) keeps the typed refusal, so the guard is not vacuous.
    parent = self()

    pid =
      spawn(fn ->
        result =
          try do
            Xaas.DevSeeds.run(e2e: false)
            :ran
          rescue
            e -> {:raised, e}
          end

        send(parent, {:w984bs_refused, result})
      end)

    assert_receive {:w984bs_refused, {:raised, %Mix.Error{message: msg}}}, 15_000
    refute Process.alive?(pid)
    assert msg =~ "REFUSED(dev_seeds"
    assert msg =~ "env=test"
    assert msg =~ "e2e: true"
  end
end
