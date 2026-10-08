defmodule Xaas.A2a.CatalogAgentCourtW984jtTest do
  @moduledoc """
  Lane W984jt — unclaimed-family probe court over the residual branches of
  `Xaas.A2a.Catalog` / `Xaas.A2a.Agent` / `Xaas.A2a.Task` that the existing
  family courts (catalog_test W699, catalog_ingest_depth W984db,
  agent_identity_policy_depth W984ak, a2a_resources_deepening W751/W772,
  tofu_test) do not pin:

    1. `search_by_skill/1` nil-field and non-binary-tag branches inside the
       per-skill field scan (`tag_matches?/2` non-binary clause, nil skill
       fields) and the `is_binary(term)` guard.
    2. `Catalog.ingest/1` non-map/non-binary catch-all (typed refusal, no
       exception crossing the boundary).
    3. the Agent read bypass admits under full authorization (`authorize?:
       true` read) — the policy floor's open half, unpinned by W984ak which
       only courts the refusing half.
    4. Task `allow_nil?` floors: nil `agent_id`/`task_id`/`context_id`
       refused typed, no row lands.
    5. Agent `allow_nil?` floor: nil `url`/`description` refused typed.

  Mutation rationale per test (in @tags): kill `nil -> false` in
  search_by_skill => test 1a fails (String.downcase(nil) raises). Kill the
  non-binary tag clause => test 1a fails. Drop the is_binary guard =>
  test 1b fails (downcase of non-binary instead of FunctionClauseError —
  either way the guard contract is pinned). Remove the ingest catch-all =>
  test 2 fails (FunctionClauseError, not typed error). Remove the read
  bypass => test 3 fails Forbidden. Drop allow_nil? false on Task/Agent
  attrs => tests 4/5 fail (nil rows land).
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

  defp base_card(name) do
    %{
      "name" => name,
      "description" => "W984jt court agent",
      "url" => "https://w984jt.example.com/a2a/v1"
    }
  end

  # -- 1. search_by_skill edge branches -----------------------------------------

  test "1a. skill rows with nil fields and non-binary tags never crash the scan" do
    {:ok, _} =
      Catalog.ingest(%{
        "name" => "ragged-agent",
        "description" => "ragged skill shapes",
        "url" => "https://ragged.example.com",
        "skills" => [
          # every matchable field nil or non-matching; tags carry non-binaries
          %{"tags" => [42, :atom, "needle"]},
          %{"id" => nil, "name" => nil, "description" => nil, "tags" => nil}
        ]
      })

    # the non-binary tag clause returns false for 42/:atom; the binary tag
    # "needle" still matches (tag_matches? binary clause)
    assert [%Agent{name: "ragged-agent"}] = Catalog.search_by_skill("needle")
    # and nothing else matches, without raising
    assert [] = Catalog.search_by_skill("wumpus")
  end

  test "1b. search_by_skill guard: a non-binary term is a FunctionClauseError" do
    assert_raise FunctionClauseError, fn -> Catalog.search_by_skill(42) end
  end

  # -- 2. ingest catch-all -------------------------------------------------------

  test "2. ingest of a non-map non-binary input is a typed invalid_card refusal" do
    assert {:error, %Catalog.Error{reason: :invalid_card, detail: 42}} = Catalog.ingest(42)
    assert {:error, %Catalog.Error{reason: :invalid_card, detail: [:list]}} = Catalog.ingest([:list])
  end

  # -- 3. the Agent read bypass's open half --------------------------------------

  test "3. fully authorized reads are admitted through the read bypass" do
    {:ok, _} = Catalog.ingest(base_card("readable-agent"))

    assert [%Agent{name: "readable-agent"}] = Ash.read!(Agent, authorize?: true)

    {:ok, agent} = Ash.get(Agent, "readable-agent", authorize?: true)
    assert %Agent{name: "readable-agent"} = agent
  end

  # -- 4/5. allow_nil? floors ----------------------------------------------------

  test "4. Task nil/absent required attrs refused typed" do
    # explicitly-nil required attrs: refused typed
    for {bad, label} <- [
          {%{agent_id: nil, task_id: "t-nil-a", status: :submitted, context_id: "c"}, "agent_id"},
          {%{agent_id: "a", task_id: nil, status: :submitted, context_id: "c"}, "task_id"},
          {%{agent_id: "a", task_id: "t-nil-c", status: :submitted, context_id: nil}, "context_id"}
        ] do
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.Changeset.for_create(Task, :create, bad, authorize?: false)
               |> Ash.create(),
             label
    end

    # ABSENT required attrs on the accept-list: refused typed too (no row)
    assert {:error, %Ash.Error.Invalid{}} =
             Ash.Changeset.for_create(Task, :create, %{task_id: "t-absent", status: :submitted, context_id: "c"},
               authorize?: false
             )
             |> Ash.create()

    assert [] = Ash.read!(Task, authorize?: false)
  end

  test "5. Agent nil url / nil description refused typed at create" do
    assert {:error, %Ash.Error.Invalid{}} =
             Ash.create(Agent, %{name: "nil-url"}, action: :create, authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.create(
               Agent,
               %{name: "nil-desc", url: "https://x.example", description: nil},
               action: :create,
               authorize?: false
             )

    assert [] = Ash.read!(Agent, authorize?: false)
  end
end
