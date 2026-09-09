defmodule Xaas.Telemetry.OcelAshEmitterTest do
  @moduledoc """
  Chicago-school test: real sandboxed Postgres, real Ash actions (no
  telemetry mocking, no fabricated OCEL events). Asserts the real defect
  fix -- a failing Ash action produces an OCEL line whose `outcome` is
  distinguishable from a successful one -- by driving two real actions
  (a successful `Xaas.Library.Book` create, then a `borrow_copy` update
  that Ash's own `validate compare(:available_copies, greater_than: 0)`
  rejects) and reading the real, real-appended
  `priv/ocel/ash-actions.ndjson` lines each one produced.
  """
  use Xaas.DataCase, async: false

  alias Xaas.Accounts.User
  alias Xaas.Library.Book

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
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
      Ash.Seed.seed!(User, %{email: "ocel-emitter-#{System.unique_integer([:positive])}@example.com"})

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

    # Real failing action: `borrow_copy` on a book with zero available
    # copies real-triggers `validate compare(:available_copies,
    # greater_than: 0)` (lib/xaas/library/book.ex) -- a genuine Ash
    # validation error, evaluated inside the real action pipeline
    # (confirmed empirically: it surfaces from `Ash.update/1`, not from
    # `Ash.Changeset.for_update/4`'s own eager build), so it real-flows
    # through the same `Ash.Tracer.set_handled_error/2` call this fix
    # depends on.
    assert {:error, %Ash.Error.Invalid{}} =
             book
             |> Ash.Changeset.for_update(:borrow_copy, %{}, actor: actor)
             |> Ash.update()

    lines_after = read_ocel_lines()
    new_lines = Enum.drop(lines_after, count_before)

    assert length(new_lines) >= 2,
           "expected at least 2 new OCEL lines (create + borrow_copy), got #{length(new_lines)}: #{inspect(new_lines)}"

    create_line =
      Enum.find(new_lines, fn line ->
        String.ends_with?(line["ocel:activity"], ".create")
      end)

    borrow_line =
      Enum.find(new_lines, fn line ->
        String.ends_with?(line["ocel:activity"], ".borrow_copy")
      end)

    refute is_nil(create_line), "expected a real OCEL line for the Book create action"
    refute is_nil(borrow_line), "expected a real OCEL line for the Book borrow_copy action"

    assert create_line["ocel:vmap"]["outcome"] == "ok"
    assert borrow_line["ocel:vmap"]["outcome"] == "error"
    assert create_line["ocel:vmap"]["outcome"] != borrow_line["ocel:vmap"]["outcome"]

    refute is_nil(book)
  end
end
