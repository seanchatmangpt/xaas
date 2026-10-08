defmodule Xaas.Library.ILSRepoFixtureAdapterDeepeningTest do
  @moduledoc """
  Chicago courts for `Xaas.Library.ILSRepo.FixtureAdapter` (W984du residue #1,
  4 previously-uncovered pubs). The FixtureAdapter is the repo's disclosed
  hand-written real interface implementation -- legitimate court subject
  matter. Real-state assertions against the real fixture data, zero mocks.
  """

  use ExUnit.Case, async: true

  alias Xaas.Library.ILSRepo
  alias Xaas.Library.ILSRepo.FixtureAdapter

  describe "get_catalog/1" do
    test "returns the three-book fixture catalog for any school id" do
      assert {:ok, catalog} = FixtureAdapter.get_catalog("any-school")
      assert length(catalog) == 3

      item_ids = Enum.map(catalog, & &1.item_id)
      assert item_ids == ["BK-1001", "BK-1002", "BK-1003"]

      assert Enum.all?(catalog, fn item ->
               match?(
                 %{title: t, author: a, grade_level: g, available: av}
                 when is_binary(t) and is_binary(a) and is_integer(g) and is_boolean(av),
                 item
               )
             end)
    end

    test "catalog availability flags match the live-demo script (slide 18)" do
      assert {:ok, catalog} = FixtureAdapter.get_catalog("any-school")

      by_id = Map.new(catalog, &{&1.item_id, &1})
      assert by_id["BK-1001"].available == true
      assert by_id["BK-1002"].available == true
      assert by_id["BK-1003"].available == false
    end

    test "grade levels: two grade-6 books and one grade-5 book" do
      assert {:ok, catalog} = FixtureAdapter.get_catalog("any-school")

      assert Enum.frequencies_by(catalog, & &1.grade_level) == %{5 => 1, 6 => 2}
    end

    test "facade dispatches through the configured default adapter" do
      assert {:ok, catalog} = ILSRepo.get_catalog("any-school")
      assert catalog == elem(FixtureAdapter.get_catalog("any-school"), 1)
    end
  end

  describe "get_circulation_history/1" do
    test "known patron returns dated checkout entries" do
      assert {:ok, history} = FixtureAdapter.get_circulation_history("MAYA-R-001")
      assert length(history) == 2

      assert [%{item_id: "BK-1001", checked_out_at: %Date{} = d1}, %{item_id: "BK-1002"}] =
               history

      assert Date.compare(d1, ~D[2026-08-20]) == :eq
      assert Enum.all?(history, &is_binary(&1.title))
    end

    test "unknown student id returns {:ok, []} -- empty, not an error" do
      assert {:ok, []} = FixtureAdapter.get_circulation_history("NO-SUCH-STUDENT")
    end

    test "facade dispatch: unknown student via ILSRepo returns {:ok, []}" do
      assert {:ok, []} = ILSRepo.get_circulation_history("NO-SUCH-STUDENT")
    end
  end

  describe "patron_status/1" do
    test "known patron returns the full status map" do
      assert {:ok, patron} = FixtureAdapter.patron_status("MAYA-R-001")
      assert patron.name == "Maya R."
      assert patron.grade_level == 6
      assert patron.status == "active"
      assert patron.fines == 0.0
      assert patron.checked_out_count == 2
    end

    test "unknown patron returns {:error, :patron_not_found}" do
      assert {:error, :patron_not_found} = FixtureAdapter.patron_status("GHOST-001")
    end

    test "facade dispatch: unknown patron surfaces the same typed error" do
      assert {:error, :patron_not_found} = ILSRepo.patron_status("GHOST-001")
    end
  end

  describe "item_information/1" do
    test "known item returns the catalog entry" do
      assert {:ok, item} = FixtureAdapter.item_information("BK-1002")
      assert item.title == "Bloom of the Deep"
      assert item.author == "S. Ferris"
      assert item.grade_level == 6
      assert item.available == true
    end

    test "unknown item returns {:error, :item_not_found}" do
      assert {:error, :item_not_found} = FixtureAdapter.item_information("BK-9999")
    end

    test "item_information/1 and get_catalog/1 agree on the same item map" do
      {:ok, catalog} = FixtureAdapter.get_catalog("any-school")
      {:ok, item} = FixtureAdapter.item_information("BK-1001")
      assert item in catalog
    end
  end
end
