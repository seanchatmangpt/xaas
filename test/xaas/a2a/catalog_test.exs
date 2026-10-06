defmodule Xaas.A2a.CatalogTest do
  @moduledoc """
  Real Chicago-style courts over `Xaas.A2a.Catalog`: the courts ingest the
  REAL agent card carried in ash_a2a's v1 spec corpus
  (`priv/a2a_v1_spec_corpus/v1_spec_examples.json`, the served
  `agent-card.json` surface), then assert on real resource state. No mocks,
  no fixture silhouettes — the real ash_a2a artifact is the fixture.
  """
  use ExUnit.Case, async: false

  require Ash.Query

  alias Xaas.A2a.Agent
  alias Xaas.A2a.Catalog
  alias Xaas.A2a.Task

  @ash_a2a_corpus "/Users/sac/ash_a2a/priv/a2a_v1_spec_corpus/v1_spec_examples.json"

  setup do
    wipe()
    :ok
  end

  defp wipe do
    Ash.bulk_destroy!(Task, :destroy, %{}, authorize?: false)
    Ash.bulk_destroy!(Agent, :destroy, %{}, authorize?: false)
  end

  defp real_card do
    corpus = Jason.decode!(File.read!(@ash_a2a_corpus))

    card =
      corpus["examples"]
      |> Enum.find(fn ex -> ex["id"] == "agent-card-research-assistant" end)
      |> Map.fetch!("wire")

    assert is_binary(card["name"])
    card
  end

  test "ingests the real ash_a2a served card and creates a queryable Agent" do
    card = real_card()

    assert {:ok, 1} = Catalog.ingest(card)
    agent = Catalog.get_agent!(card["name"])

    assert agent.url == "https://research-agent.example.com/a2a/v1"
    assert agent.description == card["description"]

    assert [%{"id" => "academic-research", "tags" => ["research", "citations", "academic"]}] =
             agent.skills

    assert [%{"protocolBinding" => "HTTP+JSON"}] = agent.transport_bindings
  end

  test "ingest accepts a raw JSON binary and a file path of the same card" do
    card = real_card()
    body = Jason.encode!(card)
    path = Path.join(System.tmp_dir(), "pw4-card-#{:erlang.unique_integer([:positive])}.json")
    File.write!(path, body)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, 1} = Catalog.ingest(body)
    assert {:ok, 1} = Catalog.ingest(path)
    assert [_] = Catalog.list_agents()
  end

  test "ingest is idempotent on re-ingest (upsert keyed on name)" do
    card = real_card()
    assert {:ok, 1} = Catalog.ingest(card)
    assert {:ok, 1} = Catalog.ingest(Jason.encode!(card))

    assert [%Agent{}] = Catalog.list_agents()
  end

  test "malformed input produces typed errors, never an exception" do
    assert {:error, %Catalog.Error{reason: :invalid_json}} = Catalog.ingest("{not json")
    assert {:error, %Catalog.Error{reason: :invalid_card}} = Catalog.ingest(%{"nope" => true})
  end

  test "search by skill matches id, tags, and description" do
    card = real_card()
    {:ok, 1} = Catalog.ingest(card)

    assert [%Agent{name: name}] = Catalog.search_by_skill("academic-research")
    assert name == card["name"]
    assert [%Agent{}] = Catalog.search_by_skill("CITATIONS")
    refute Catalog.search_by_skill("source verification") == []
    assert [] = Catalog.search_by_skill("cryptocurrency-trading")
  end

  test "tasks cross-reference agents by agent_id" do
    card = real_card()
    {:ok, 1} = Catalog.ingest(card)
    agent = Catalog.get_agent!(card["name"])

    task =
      Catalog.create_task(%{
        agent_id: agent.name,
        task_id: "task-1",
        status: :working,
        context_id: "ctx-1",
        artifacts: [%{"artifactId" => "a1", "parts" => [%{"kind" => "text", "text" => "hi"}]}]
      })

    assert task.status == :working
    assert [%Task{task_id: "task-1"}] = Catalog.tasks_for_agent(agent.name)
    assert [] = Catalog.tasks_for_agent("no-such-agent")

    # every task resolves to a real ingested agent
    agent_names = MapSet.new(Catalog.list_agents(), & &1.name)

    for t <- Catalog.tasks_for_agent(agent.name) do
      assert MapSet.member?(agent_names, t.agent_id)
    end
  end
end
