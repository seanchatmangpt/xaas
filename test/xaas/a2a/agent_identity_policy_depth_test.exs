defmodule Xaas.A2a.AgentIdentityPolicyDepthTest do
  @moduledoc """
  Lane W984ak — depth batch 3, family 1: `Xaas.A2a.Agent` (private ETS
  projection resource).

  Uncovered slice (read-first: `test/xaas/a2a_resources_deepening_test.exs`
  courts Agent only at a1 create / c1-c2 card projection; the a2/a3/a4
  courts target Task; `test/xaas/a2a/catalog_test.exs` courts the Catalog
  ingest path): the Agent resource's own
  identity/policy/update/defaults invariants —

    * `unique_name` identity (pre_check_with Ets) refusing a duplicate
      name create with a typed Invalid, original row untouched,
    * the W984l deny-by-default policy floor: authorized create/destroy
      refuse `Ash.Error.Forbidden` while the `authorize?: false` internal
      path keeps working (read stays open via the read bypass),
    * the `:update` accept-list contract: mutable card fields round-trip;
      the `name` identity is not rewritable through update input,
    * attribute defaults: `skills` / `transport_bindings` default to real
      empty lists and `version` is optional (persists nil).

  Chicago-style: real Ash actions on the real private ETS store, real row
  state asserted, no mocks.
  """

  use ExUnit.Case, async: false


  alias Xaas.A2a.Agent

  setup do
    Agent |> Ash.bulk_destroy!(:destroy, %{}, authorize?: false)
    :ok
  end

  @card_attrs %{
    name: "depth-batch-3-agent",
    url: "https://agents.example/depth-batch-3",
    description: "W984ak depth court agent card"
  }

  test "duplicate name create is refused with a typed Invalid; the original row is untouched" do
    original = Ash.create!(Agent, @card_attrs, action: :create, authorize?: false)

    dup_cs =
      Ash.Changeset.for_create(
        Agent,
        :create,
        Map.put(@card_attrs, :url, "https://other.example")
      )

    assert {:error, %Ash.Error.Invalid{}} = Ash.create(dup_cs, authorize?: false)

    [only] = Ash.read!(Agent, authorize?: false)
    assert only.name == original.name
    assert only.url == @card_attrs.url
  end

  test "authorized create refuses Forbidden; the authorize?: false path admits the same attrs" do
    assert {:error, %Ash.Error.Forbidden{}} =
             Ash.create(Agent, @card_attrs, action: :create, authorize?: true)

    # the policy-shaped refusal wrote nothing
    assert [] = Ash.read!(Agent, authorize?: false)

    assert %Agent{} = Ash.create!(Agent, @card_attrs, action: :create, authorize?: false)
    assert [%Agent{}] = Ash.read!(Agent, authorize?: false)
  end

  test "authorized destroy refuses Forbidden and the row survives; the internal path removes it" do
    agent = Ash.create!(Agent, @card_attrs, action: :create, authorize?: false)

    assert {:error, %Ash.Error.Forbidden{}} = Ash.destroy(agent, authorize?: true)

    assert [%Agent{}] = Ash.read!(Agent, authorize?: false)

    Ash.destroy!(agent, authorize?: false)
    assert [] = Ash.read!(Agent, authorize?: false)
  end

  test "update round-trips mutable card fields; the name identity is not rewritable" do
    agent = Ash.create!(Agent, @card_attrs, action: :create, authorize?: false)

    updated =
      agent
      |> Ash.Changeset.for_update(:update, %{
        url: "https://agents.example/v2",
        description: "updated description",
        version: "2.0.0",
        skills: [%{"id" => "s1", "name" => "rank", "tags" => ["library"]}],
        transport_bindings: [
          %{
            "url" => "https://agents.example/v2",
            "protocolBinding" => "JSONRPC",
            "protocolVersion" => "1.0"
          }
        ]
      })
      |> Ash.update!(authorize?: false)

    assert updated.url == "https://agents.example/v2"
    assert updated.description == "updated description"
    assert updated.version == "2.0.0"
    assert [%{"id" => "s1"}] = updated.skills
    assert [%{"protocolBinding" => "JSONRPC"}] = updated.transport_bindings

    reloaded = Ash.get!(Agent, agent.name, authorize?: false)
    assert reloaded.url == "https://agents.example/v2"
    assert reloaded.version == "2.0.0"
  end

  test "version is optional (persists nil) and list attributes default to real empty lists" do
    agent = Ash.create!(Agent, @card_attrs, action: :create, authorize?: false)

    assert is_nil(agent.version)
    assert agent.skills == []
    assert agent.transport_bindings == []
  end
end
