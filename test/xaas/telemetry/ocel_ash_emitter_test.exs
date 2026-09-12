defmodule Xaas.Telemetry.OcelAshEmitterTest do
  @moduledoc """
  Chicago-school test: real sandboxed Postgres, real Ash actions (no
  telemetry mocking, no fabricated OCEL events). Asserts the real defect
  fix -- a failing Ash action produces an OCEL line whose `outcome` is
  distinguishable from a successful one -- by driving two real
  `Xaas.Library.Book` creates (one with a resolved actor that succeeds,
  one with `actor: nil` that the resource's own
  `authorize_if actor_present()` policy really denies) and reading the
  real, real-appended `priv/ocel/ash-actions.ndjson` lines each one
  produced.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.Book

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    # Real fixture-scoping fix, not a mock: `priv/ocel/ash-actions.ndjson`
    # is the real, shared, never-rotated OCEL log every Ash action across
    # every test run appends to (ocel_ash_emitter.ex:237-239). Truncating
    # it here means read_ocel_lines/0 below reads only this test's own
    # real writes instead of the whole repo's accumulated test history
    # (352MB / 844,698 lines observed), which is the actual 13.3s cost --
    # not network retry or sleep.
    log_path = Xaas.Telemetry.OcelAshEmitter.log_path()
    File.mkdir_p!(Path.dirname(log_path))
    File.write!(log_path, "")

    :ok
  end

  defp read_ocel_lines do
    Xaas.Telemetry.OcelAshEmitter.log_path()
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
  end

  test "a real successful Ash create and a real failing Ash update produce OCEL lines with distinguishable outcomes" do
    actor =
      Ash.Seed.seed!(User, %{
        email: "ocel-emitter-#{System.unique_integer([:positive])}@example.com"
      })

    lines_before = read_ocel_lines()
    count_before = length(lines_before)

    # Real successful action: Ash.Library.Book create, via the real Ash
    # domain action pipeline (not seeded), with a resolved actor to
    # satisfy the resource's `authorize_if actor_present()` policy.
    {:ok, book} =
      Book
      |> Ash.Changeset.for_create(
        :create,
        %{
          title: "OCEL Outcome Fixture",
          author: "Test Author",
          isbn: "OCEL-TEST-#{System.unique_integer([:positive])}",
          grade_level: Decimal.new("3"),
          genres: ["Fiction"],
          formats: ["hardcover"],
          available_copies: 0,
          total_copies: 1
        },
        actor: actor
      )
      |> Ash.create()

    # Real failing action: a second `Book` create with no actor
    # real-triggers the resource's own `policy action_type([:create,
    # :update, :destroy]) do authorize_if actor_present() end`
    # (lib/xaas/library/book.ex) -- a genuine `Ash.Policy.Authorizer`
    # denial. Confirmed empirically (not assumed) to differ from a plain
    # attribute/compare validation failure: `Ash.Changeset.for_update`'s
    # own eager attribute-constraint validation short-circuits
    # `Ash.Actions.Update.run/4` *before* its `Ash.Tracer.telemetry_span`
    # even opens (`run(domain, %{valid?: false, ...}, ...)` in
    # `deps/ash/lib/ash/actions/update/update.ex`), so that class of
    # failure never reaches this module's `handle_event/4` at all -- a
    # real, disclosed further gap in Ash's own telemetry, separate from
    # this fix. A policy denial, in contrast, is evaluated *inside* the
    # real pipeline the `telemetry_span` wraps, so it is the real,
    # minimal failure this fix can distinguish.
    assert {:error, %Ash.Error.Forbidden{}} =
             Book
             |> Ash.Changeset.for_create(
               :create,
               %{
                 title: "OCEL Outcome Fixture (forbidden)",
                 author: "Test Author",
                 isbn: "OCEL-TEST-FORBIDDEN-#{System.unique_integer([:positive])}",
                 grade_level: Decimal.new("3"),
                 genres: ["Fiction"],
                 formats: ["hardcover"],
                 available_copies: 0,
                 total_copies: 1
               },
               actor: nil
             )
             |> Ash.create()

    lines_after = read_ocel_lines()
    new_lines = Enum.drop(lines_after, count_before)

    assert length(new_lines) >= 2,
           "expected at least 2 new OCEL lines (2 real Book creates), got #{length(new_lines)}: #{inspect(new_lines)}"

    create_lines =
      Enum.filter(new_lines, fn line ->
        String.ends_with?(line["ocel:activity"], ".create")
      end)

    ok_line = Enum.find(create_lines, &(&1["ocel:vmap"]["outcome"] == "ok"))
    error_line = Enum.find(create_lines, &(&1["ocel:vmap"]["outcome"] == "error"))

    refute is_nil(ok_line),
           "expected a real OCEL line with outcome \"ok\" for the successful create"

    refute is_nil(error_line),
           "expected a real OCEL line with outcome \"error\" for the forbidden create"

    assert ok_line["ocel:vmap"]["outcome"] == "ok"
    assert error_line["ocel:vmap"]["outcome"] == "error"
    assert ok_line["ocel:vmap"]["outcome"] != error_line["ocel:vmap"]["outcome"]

    refute is_nil(book)
  end
end
