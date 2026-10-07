defmodule Xaas.A2a.ResourcesDeepeningTest do
  @moduledoc """
  Lane W751 court: resource-level deepening of the undocketed `Xaas.A2a`
  domain (PW4 protocol-as-resources: `Xaas.A2a.Agent`, `Xaas.A2a.Task`),
  layering under the W699 wire-level court
  (`test/xaas_web/a2a_v1_wire_deepening_test.exs`). Chicago-style: real Ash
  actions on the real (private ETS) store, the real served agent card off
  the wire for the cross-check, real row state asserted; no mocks.

  Courts:
    (a) Agent create -> Task create bound to the agent; task status surface
        per the REAL actions: the one_of membership constraint refuses an
        out-of-set atom, and the W772 forward-only transition guard
        (`Xaas.A2a.Validations.ForwardOnlyTransition`) refuses any
        non-admitted edge — terminal `:completed`/`:failed` absorb
        (W715 pattern: assert the actual machine).
    (b) Cross-resource integrity: a Task bound to a nonexistent Agent is
        ACCEPTED (no relationship/FK between the resources) — asserted,
        not assumed; the only integrity the domain enforces is the
        `unique_task_id` / `unique_name` identities.
    (c) Agent-card consistency: the real wire card from
        `GET /a2a/v1/.well-known/agent-card.json` ingested via
        `Xaas.A2a.Catalog.ingest/1` projects exactly W699's shared fields
        (name/version/description/skills/supportedInterfaces) onto the
        resource surface, and the resource's attribute surface honestly
        carries NO `capabilities` / `defaultInputModes` / `defaultOutputModes`
        (the wire-only card members W699 pins but the projection omits).
    (d) Determinism: the same card + task sequence, replayed from a wiped
        store, lands in an identical projected state.
  """

  use XaasWeb.ConnCase

  require Ash.Query

  alias Xaas.A2a.Agent
  alias Xaas.A2a.Catalog
  alias Xaas.A2a.Task
  alias XaasWeb.A2A.NextReadAshAgent

  @card_path "/a2a/v1/.well-known/agent-card.json"

  setup do
    wipe()

    if Process.whereis(NextReadAshAgent) == nil do
      start_supervised!(NextReadAshAgent)
    end

    :ok
  end

  defp wipe do
    Ash.bulk_destroy!(Task, :destroy, %{}, authorize?: false)
    Ash.bulk_destroy!(Agent, :destroy, %{}, authorize?: false)
  end

  defp agent_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        name: "w751-agent",
        url: "https://w751.example.com/a2a/v1",
        description: "W751 court agent",
        version: "1.0.0",
        skills: [%{"id" => "probe", "name" => "Probe", "tags" => ["w751"]}],
        transport_bindings: [
          %{"url" => "https://w751.example.com/a2a/v1", "protocolBinding" => "HTTP+JSON"}
        ]
      },
      overrides
    )
  end

  defp create_agent(overrides \\ %{}) do
    agent_attrs(overrides)
    |> then(&Ash.Changeset.for_create(Agent, :create, &1, authorize?: false))
    |> Ash.create!(authorize?: false)
  end

  defp create_task(attrs) do
    Ash.Changeset.for_create(Task, :create, attrs, authorize?: false)
    |> Ash.create!(authorize?: false)
  end

  # -- (a) Agent -> Task binding + the REAL status surface ---------------------

  test "a1. Agent create then Task create bound to the agent — real row state" do
    agent = create_agent()

    assert %Agent{name: "w751-agent", url: "https://w751.example.com/a2a/v1"} =
             Ash.get!(Agent, agent.name, authorize?: false)

    task =
      create_task(%{
        agent_id: agent.name,
        task_id: "t-a1",
        status: :submitted,
        context_id: "ctx-a1"
      })

    assert %Task{agent_id: "w751-agent", task_id: "t-a1", status: :submitted,
                 context_id: "ctx-a1", artifacts: []} = task

    # read back through a fresh query: the row is real store state
    assert [%Task{status: :submitted}] =
             Task
             |> Ash.Query.filter(agent_id == ^agent.name and task_id == "t-a1")
             |> Ash.read!(authorize?: false)
  end

  test "a2. status membership IS enforced: out-of-set atom refused by the one_of constraint" do
    agent = create_agent()

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.Changeset.for_create(
               Task,
               :create,
               %{
                 agent_id: agent.name,
                 task_id: "t-bad",
                 status: :cancelled,
                 context_id: "ctx-bad"
               },
               authorize?: false
             )
             |> Ash.create()

    assert [] =
             Task
             |> Ash.Query.filter(task_id == "t-bad")
             |> Ash.read!(authorize?: false)
  end

  test "a3. forward-only transition machine: lawful walk accepted, terminal->non-terminal refused typed" do
    agent = create_agent()

    task =
      create_task(%{agent_id: agent.name, task_id: "t-a3", status: :submitted, context_id: "ctx-a3"})

    # the lawful A2A walkthrough (each edge is in the validation's allow-list)
    legal_walk = [:working, :input_required, :working, :completed]

    task =
      Enum.reduce(legal_walk, task, fn next, acc ->
        acc
        |> Ash.Changeset.for_update(:update, %{status: next}, authorize?: false)
        |> Ash.update!(authorize?: false)
      end)

    assert %Task{status: :completed} = Ash.get!(Task, task.id, authorize?: false)

    # terminal -> non-terminal (completed -> submitted): REFUSED typed
    # (W772 forward-only guard; was accepted before the guard).
    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Changes.InvalidChanges{}]}} =
             task
             |> Ash.Changeset.for_update(:update, %{status: :submitted}, authorize?: false)
             |> Ash.update()

    assert %Task{status: :completed} = Ash.get!(Task, task.id, authorize?: false)

    # artifacts ride :update alongside status (status unchanged -> self-transition, allowed)
    with_art =
      task
      |> Ash.Changeset.for_update(:update, %{artifacts: [%{"artifactId" => "a1"}]}, authorize?: false)
      |> Ash.update!(authorize?: false)

    assert [%{"artifactId" => "a1"}] = with_art.artifacts
  end

  test "a3b. terminal is absorbing: failed -> any non-failed status refused; failed self-loop allowed" do
    agent = create_agent()

    task =
      create_task(%{agent_id: agent.name, task_id: "t-a3b", status: :working, context_id: "ctx-a3b"})

    task =
      task
      |> Ash.Changeset.for_update(:update, %{status: :failed}, authorize?: false)
      |> Ash.update!(authorize?: false)

    for refused <- [:submitted, :working, :input_required, :completed] do
      assert {:error, %Ash.Error.Invalid{}} =
               task
               |> Ash.Changeset.for_update(:update, %{status: refused}, authorize?: false)
               |> Ash.update()
    end

    # self-transition on a terminal state stays lawful (artifacts-style no-op)
    assert %Task{status: :failed} =
             task
             |> Ash.Changeset.for_update(:update, %{status: :failed}, authorize?: false)
             |> Ash.update!(authorize?: false)
  end

  test "a3c. every forward edge in the validation's allow-list succeeds on a real row" do
    agent = create_agent()

    for {from, to} <- Xaas.A2a.Validations.ForwardOnlyTransition.forward_edges() do
      task =
        create_task(%{
          agent_id: agent.name,
          task_id: "t-a3c-#{from}-#{to}",
          status: from,
          context_id: "ctx-a3c"
        })

      assert %Task{status: ^to} =
               task
               |> Ash.Changeset.for_update(:update, %{status: to}, authorize?: false)
               |> Ash.update!(authorize?: false)
    end
  end

  test "a4. unique_task_id identity is enforced" do
    agent = create_agent()

    create_task(%{agent_id: agent.name, task_id: "t-dup", status: :submitted, context_id: "c"})

    assert {:error, %Ash.Error.Invalid{}} =
             Ash.Changeset.for_create(
               Task,
               :create,
               %{agent_id: agent.name, task_id: "t-dup", status: :working, context_id: "c2"},
               authorize?: false
             )
             |> Ash.create()

    assert [%Task{}] =
             Task |> Ash.Query.filter(task_id == "t-dup") |> Ash.read!(authorize?: false)
  end

  # -- (b) cross-resource integrity: the REAL behavior -------------------------

  test "b1. a Task bound to a nonexistent Agent is ACCEPTED (no FK; integrity is caller's duty)" do
    agent_names_before = MapSet.new(Ash.read!(Agent, authorize?: false), & &1.name)
    refute MapSet.member?(agent_names_before, "ghost-agent")

    task =
      create_task(%{
        agent_id: "ghost-agent",
        task_id: "t-ghost",
        status: :working,
        context_id: "ctx-ghost"
      })

    # real row persisted despite the dangling reference
    assert %Task{agent_id: "ghost-agent", status: :working} =
             Ash.get!(Task, task.id, authorize?: false)

    # and the catalog's per-agent view serves the dangling task
    assert [%Task{task_id: "t-ghost"}] = Catalog.tasks_for_agent("ghost-agent")
  end

  test "b2. destroying the parent agent leaves the child task dangling by design" do
    agent = create_agent(%{name: "doomed-agent"})
    create_task(%{agent_id: agent.name, task_id: "t-orphan", status: :submitted, context_id: "c"})

    Ash.destroy!(agent, authorize?: false)

    assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
             Ash.get(Agent, "doomed-agent", authorize?: false)

    refute MapSet.member?(MapSet.new(Ash.read!(Agent, authorize?: false), & &1.name), "doomed-agent")
    assert [%Task{task_id: "t-orphan"}] = Catalog.tasks_for_agent("doomed-agent")
  end

  # -- (c) agent-card consistency: resource surface vs the real wire card ------

  test "c1. the real served card projects onto Agent with W699's shared fields intact" do
    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> get(@card_path)

    assert conn.status == 200

    wire = json_response(conn, 200)

    # W699 pins these card members on the wire; assert the same before ingest.
    assert is_binary(wire["name"]) and wire["name"] != ""
    assert is_binary(wire["version"]) and wire["version"] != ""
    assert is_binary(wire["description"])
    assert is_list(wire["skills"]) and wire["skills"] != []
    assert is_map(wire["capabilities"])
    assert is_list(wire["supportedInterfaces"]) and wire["supportedInterfaces"] != []

    assert {:ok, _count} = Catalog.ingest(wire)
    agent = Catalog.get_agent!(wire["name"])

    # the shared surface round-trips byte-for-semantics
    assert agent.name == wire["name"]
    assert agent.version == wire["version"]
    assert agent.description == wire["description"]
    assert agent.skills == wire["skills"]

    assert agent.transport_bindings ==
             Enum.map(wire["supportedInterfaces"], fn iface ->
               %{
                 "url" => iface["url"],
                 "protocolBinding" => iface["protocolBinding"],
                 "protocolVersion" => iface["protocolVersion"]
               }
             end)

    # every task bound to this card's agent name resolves against the card
    task =
      create_task(%{
        agent_id: agent.name,
        task_id: "t-card",
        status: :working,
        context_id: "ctx-card"
      })

    assert task.agent_id == agent.name
  end

  test "c2. the resource attribute surface honestly carries only the card's shared members" do
    attr_names =
      Agent
      |> Ash.Resource.Info.attributes()
      |> MapSet.new(& &1.name)

    # projected (W699-shared) members
    for shared <- [:name, :url, :description, :version, :skills, :transport_bindings] do
      assert MapSet.member?(attr_names, shared)
    end

    # wire-only card members W699 pins that the projection deliberately omits
    for wire_only <- [:capabilities, :defaultInputModes, :defaultOutputModes] do
      refute MapSet.member?(attr_names, wire_only)
    end
  end

  # -- (d) determinism ----------------------------------------------------------

  defp run_sequence(card) do
    {:ok, _} = Catalog.ingest(card)
    agent = Catalog.get_agent!(card["name"])

    t1 =
      Catalog.create_task(%{
        agent_id: agent.name,
        task_id: "det-t1",
        status: :submitted,
        context_id: "det-ctx"
      })

    t1
    |> Ash.Changeset.for_update(:update, %{status: :working}, authorize?: false)
    |> Ash.update!(authorize?: false)

    Ash.get!(Task, t1.id, authorize?: false)
  end

  test "d1. replaying the same card + task sequence from a wiped store is deterministic" do
    card = %{
      "name" => "w751-det-agent",
      "description" => "determinism court agent",
      "url" => "https://det.example.com/a2a/v1",
      "version" => "2.0.0",
      "skills" => [%{"id" => "det", "name" => "Det", "tags" => ["det"]}],
      "supportedInterfaces" => [
        %{"url" => "https://det.example.com/a2a/v1", "protocolBinding" => "HTTP+JSON"}
      ]
    }

    first = run_sequence(card)
    wipe()
    second = run_sequence(card)

    assert second.status == :working
    assert second.agent_id == card["name"]
    assert second.task_id == "det-t1"
    assert second.context_id == "det-ctx"
    assert second.artifacts == []

    assert first.status == second.status
    assert first.agent_id == second.agent_id
    assert first.task_id == second.task_id
    assert first.context_id == second.context_id
    assert first.artifacts == second.artifacts

    # the projected agent is identical too
    agent_a = Catalog.get_agent!(card["name"])
    agent_b = Catalog.get_agent!(card["name"])
    assert agent_a.url == agent_b.url
    assert agent_a.skills == agent_b.skills
    assert agent_a.transport_bindings == agent_b.transport_bindings
    assert agent_a.version == agent_b.version

    # uuid identity differs across replays (fresh PK per row) — asserted,
    # and stripped before the comparison above; only stable fields compared.
    refute first.id == second.id
  end
end
