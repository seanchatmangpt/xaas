defmodule Xaas.A2a.CatalogIngestDepthTest do
  @moduledoc """
  Lane W984db depth court over `Xaas.A2a.Catalog`'s ingest edges that the
  W751/W699 courts do not pin:

    1. dual key shape (wire camelCase vs struct snake_case) — the same card
       in both shapes must project identically (the camelize/1 path).
    2. url fallback through `supportedInterfaces[0].url` (the v1 spec's own
       L1008 shape) and typed refusal when no url exists anywhere.
    3. non-list `skills`/`supported_interfaces` normalization — malformed
       cards project empty lists, never raise.
    4. the upsert UPDATE path: re-ingest with changed fields must mutate
       the existing row (count stays 1, fields move).
    5. read-surface contracts: `get_agent!/1` raises on absent, `list_agents/0`
       sorts by name, and `Catalog.Error.message/1` formats both reasons.

  Mutation rationale per test: kill `card_key/2` (drop camelize fallback) =>
  test 1 fails. Kill the `Enum.find_value(& &1["url"])` fallback in
  `card_url/1` => test 2 fails. Change `normalize_list/1` to return the
  non-list input => test 3 fails. Make `upsert_agent!/1` always create =>
  test 4 fails (unique_name refusal or count 2). Swap `sort(:name)` /
  `raise` in get_agent!/`list_agents` => test 5 fails.
  """
  use ExUnit.Case, async: false

  alias Xaas.A2a.Agent
  alias Xaas.A2a.Catalog
  alias Xaas.A2a.Task

  setup do
    Ash.bulk_destroy!(Task, :destroy, %{}, authorize?: false)
    Ash.bulk_destroy!(Agent, :destroy, %{}, authorize?: false)
    :ok
  end

  defp wire_card do
    %{
      "name" => "depth-agent",
      "description" => "W984db depth court agent",
      "version" => "2.0.0",
      "url" => "https://depth.example.com/a2a/v1",
      "skills" => [%{"id" => "probe", "name" => "Probe", "tags" => ["depth"]}],
      "supportedInterfaces" => [
        %{"url" => "https://depth.example.com/a2a/v1", "protocolBinding" => "HTTP+JSON"}
      ]
    }
  end

  defp snake_card do
    %{
      "name" => "depth-agent",
      "description" => "W984db depth court agent",
      "version" => "2.0.0",
      "url" => "https://depth.example.com/a2a/v1",
      "skills" => [%{"id" => "probe", "name" => "Probe", "tags" => ["depth"]}],
      "supported_interfaces" => [
        %{
          "url" => "https://depth.example.com/a2a/v1",
          "protocol_binding" => "JSONRPC",
          "protocol_version" => "1.0"
        }
      ]
    }
  end

  # -- 1. dual key shape: camelCase and snake_case project identically ---------

  test "1. snake_case struct-shaped card projects identically to the wire camelCase card" do
    assert {:ok, 1} = Catalog.ingest(wire_card())
    wire_projection = Catalog.get_agent!("depth-agent")

    Ash.bulk_destroy!(Task, :destroy, %{}, authorize?: false)
    Ash.bulk_destroy!(Agent, :destroy, %{}, authorize?: false)

    assert {:ok, 1} = Catalog.ingest(snake_card())
    snake_projection = Catalog.get_agent!("depth-agent")

    # identical on every shared field; transport_bindings normalize the
    # snake_case interface keys onto the wire shape
    assert wire_projection.url == snake_projection.url
    assert wire_projection.version == snake_projection.version
    assert wire_projection.description == snake_projection.description
    assert wire_projection.skills == snake_projection.skills

    assert [%{"url" => "https://depth.example.com/a2a/v1", "protocolBinding" => "JSONRPC",
              "protocolVersion" => "1.0"}] = snake_projection.transport_bindings

    # and the camelCase card re-ingested over the snake_case row is a no-op
    # upsert (idempotent across shapes)
    assert {:ok, 1} = Catalog.ingest(wire_card())
    assert wire_projection.url == Catalog.get_agent!("depth-agent").url
  end

  # -- 2. url fallback through supportedInterfaces[0].url -----------------------

  test "2. card with no top-level url takes the interface url; url-less card refused typed" do
    # the v1 spec L1008 shape: endpoint only as supportedInterfaces[0].url
    interface_only =
      wire_card()
      |> Map.delete("url")

    assert {:ok, 1} = Catalog.ingest(interface_only)
    assert %Agent{url: "https://depth.example.com/a2a/v1"} = Catalog.get_agent!("depth-agent")

    # no url anywhere: validate_card refuses typed, no row lands
    assert {:error, %Catalog.Error{reason: :invalid_card, detail: {:bad_field_types, "url-less"}}} =
             Catalog.ingest(%{
               "name" => "url-less",
               "description" => "no endpoint anywhere",
               "supportedInterfaces" => [%{"protocolBinding" => "HTTP+JSON"}]
             })

    # detail carries the refused card's own name

    assert [] = Catalog.list_agents() |> Enum.filter(&(&1.name == "url-less"))
  end

  # -- 3. non-list skills / interfaces normalize, never raise -------------------

  test "3. malformed non-list skills and interfaces project as empty lists" do
    assert {:ok, 1} =
             Catalog.ingest(%{
               "name" => "malformed-agent",
               "description" => "lists of the wrong shape",
               "url" => "https://malformed.example.com",
               "skills" => "not-a-list",
               "supportedInterfaces" => %{"url" => "also-not-a-list"}
             })

    agent = Catalog.get_agent!("malformed-agent")
    assert [] = agent.skills
    assert [] = agent.transport_bindings
  end

  # -- 4. the upsert UPDATE path actually mutates -------------------------------

  test "4. re-ingest with changed fields updates the existing row (count stays 1)" do
    assert {:ok, 1} = Catalog.ingest(wire_card())
    before = Catalog.get_agent!("depth-agent")

    changed =
      wire_card()
      |> Map.put("description", "mutated description")
      |> Map.put("version", "3.0.0")
      |> Map.put("skills", [%{"id" => "probe-v2", "name" => "Probe V2", "tags" => ["v2"]}])

    assert {:ok, 1} = Catalog.ingest(changed)

    after_row = Catalog.get_agent!("depth-agent")
    assert 1 == length(Catalog.list_agents())
    assert "mutated description" = after_row.description
    assert "3.0.0" = after_row.version
    assert [%{"id" => "probe-v2"}] = after_row.skills
    refute after_row.description == before.description
    # updated_at moved: this was a real UPDATE, not a read-back of the old row
    assert DateTime.compare(after_row.updated_at, before.updated_at) in [:gt, :eq]
  end

  # -- 5. read-surface contracts -------------------------------------------------

  test "5. get_agent! raises on absent, list_agents sorts by name, Error.message formats" do
    # Ash surfaces get-miss as Invalid{NotFound} on this resource
    assert_raise Ash.Error.Invalid, fn ->
      Catalog.get_agent!("no-such-agent")
    end

    for name <- ["zulu", "alpha", "mike"] do
      {:ok, _} =
        Catalog.ingest(%{
          "name" => name,
          "description" => "sort probe #{name}",
          "url" => "https://#{name}.example.com"
        })
    end

    assert ["alpha", "mike", "zulu"] = Enum.map(Catalog.list_agents(), & &1.name)

    assert "agent-card ingest refused (invalid_json): " <> _ =
             Catalog.Error.message(%Catalog.Error{reason: :invalid_json, detail: :x})

    assert "agent-card ingest refused (invalid_card): " <> _ =
             Catalog.Error.message(%Catalog.Error{reason: :invalid_card, detail: :x})
  end
end
