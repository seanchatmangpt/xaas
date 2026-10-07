defmodule XaasWeb.MarketplaceCatalogLiveTest do
  @moduledoc """
  Coverage for `XaasWeb.MarketplaceCatalogLive` (/marketplace-catalog).

  The courts mount the LiveView against a real ingested catalog (the real
  generator output of ggen-marketplace's `scripts/marketplace.py catalog`,
  same fixture law as the XL1 catalog courts): the table renders real pack
  names, search narrows via the real `Catalog.search/1`, and a malformed
  source produces the typed ingest refusal in the UI instead of a crash.
  """

  use XaasWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Xaas.Marketplace.Catalog

  @marketplace_root "/Users/sac/ggen-marketplace"

  setup do
    source = Application.get_env(:xaas, :marketplace_catalog_source)
    on_exit(fn -> Application.put_env(:xaas, :marketplace_catalog_source, source) end)

    :ok
  end

  # The catalog is generated fresh per run (unique tmp file) by the real
  # generator; ingest happens inside the LiveView process at mount.
  defp generate_real_catalog! do
    {output, 0} =
      System.cmd("python3", ["scripts/marketplace.py", "catalog"],
        cd: @marketplace_root,
        stderr_to_stdout: true
      )

    file = Path.join(System.tmp_dir(), "xl2-catalog-#{:erlang.unique_integer([:positive])}.json")
    File.write!(file, output)
    file
  end

  defp with_catalog_source(source, fun) do
    Application.put_env(:xaas, :marketplace_catalog_source, source)

    try do
      fun.()
    after
      Application.delete_env(:xaas, :marketplace_catalog_source)
    end
  end

  @tag :real_marketplace_catalog
  test "mount ingests the real catalog and renders pack rows", %{conn: conn} do
    file = generate_real_catalog!()

    names =
      file |> File.read!() |> Jason.decode!() |> Map.fetch!("packs") |> Enum.map(& &1["name"])

    assert names != []

    with_catalog_source(file, fn ->
      {:ok, view, html} = live(conn, "/marketplace-catalog")

      assert html =~ "Marketplace Catalog"

      # Every real pack name from the generated catalog renders a row.
      Enum.each(names, fn name ->
        assert has_element?(view, "#pack-row-#{name}")
      end)
    end)
  end

  test "search narrows the pack table server-side", %{conn: conn} do
    source = %{
      "schema" => Catalog.catalog_schema_url(),
      "packs" => [
        %{
          "name" => "alpha-pack",
          "version" => "1.0.0",
          "digest" => "sha256:" <> String.duplicate("a", 64),
          "download_url" => "https://example.com/alpha.tgz",
          "pack_class" => "KernelPack",
          "readiness" => %{"gates" => true, "verify" => true},
          "description" => "Alpha test pack"
        },
        %{
          "name" => "beta-pack",
          "version" => "2.0.0",
          "digest" => "sha256:" <> String.duplicate("b", 64),
          "download_url" => "https://example.com/beta.tgz",
          "pack_class" => "CapabilityPack",
          "readiness" => "gates",
          "description" => "Beta test pack"
        }
      ]
    }

    with_catalog_source(source, fn ->
      {:ok, view, _html} = live(conn, "/marketplace-catalog")

      assert has_element?(view, "#pack-row-alpha-pack")
      assert has_element?(view, "#pack-row-beta-pack")
      assert has_element?(view, "#pack-table", "KernelPack")
      assert has_element?(view, "#pack-table", "gates+verify")

      # Truncated digest: first 16 chars of the digest + ellipsis.
      alpha_digest = "sha256:" <> String.duplicate("a", 64)
      assert has_element?(view, "#pack-table", String.slice(alpha_digest, 0, 16) <> "…")

      html =
        view
        |> element("#pack-search-form")
        |> render_change(%{"q" => "beta"})

      assert html =~ "beta-pack"
      refute html =~ "alpha-pack"
      assert html =~ "matching “beta”"

      # Clearing the search restores the full table.
      html =
        view
        |> element("#pack-search-form")
        |> render_change(%{"q" => ""})

      assert html =~ "alpha-pack"
    end)
  end

  test "no-match search renders the empty state", %{conn: conn} do
    source = %{
      "schema" => Catalog.catalog_schema_url(),
      "packs" => [
        %{
          "name" => "only-pack",
          "version" => "0.1.0",
          "digest" => "sha256:" <> String.duplicate("c", 64),
          "download_url" => "https://example.com/only.tgz",
          "readiness" => %{"witnesses" => true},
          "description" => "Sole pack"
        }
      ]
    }

    with_catalog_source(source, fn ->
      {:ok, view, _html} = live(conn, "/marketplace-catalog")
      assert has_element?(view, "#pack-row-only-pack")

      html =
        view
        |> element("#pack-search-form")
        |> render_change(%{"q" => "zzz-no-such-pack"})

      assert html =~ "No packs match."
      refute html =~ "only-pack"
    end)
  end

  test "malformed source renders the typed ingest refusal, not a crash", %{conn: conn} do
    with_catalog_source(%{"schema" => "https://wrong.example/schema", "packs" => []}, fn ->
      # mount must not raise
      {:ok, _view, html} = live(conn, "/marketplace-catalog")
      assert html =~ "catalog ingest refused"

      # Structured refusal: machine-readable attributes, not a bare string.
      assert html =~ ~s(data-refusal="catalog_ingest")
      assert html =~ ~s(data-reason="invalid_catalog")
    end)
  end
end
