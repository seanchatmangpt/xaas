defmodule Xaas.Ultracode.CapitalCensus.SelfDigestChicagoTest do
  @moduledoc """
  Chicago qualification for the manufactured self-digest vertical
  (GC-26927-SELFDIGEST): REAL generated Ash resources on REAL Postgres —
  no mocks of owned collaborators, no assertions over hardcoded constants.

  Falsifier corpus (qualification/QUALIFICATION.md):

    1. 3 same-topology episodes MUST cluster and admit a WorkOrder
       (provenance present) — the Experience → Gap → Work_self edge.
    2. differing topology MUST NOT cluster (the {2 same, 1 different} negative).
    3. 2 episodes MUST NOT recur at the ontology threshold (3).
    4. a shape the ontology does not classify MUST refuse (unknown never guesses).
    5. missing falsifier/receipt MUST refuse WorkOrder admission (provenance law).
    6. an unclassified class name MUST be refused by the generated enum type.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.CapitalCensus.{Episode, ExperienceCluster, Facts, Gap, WorkOrder}
  alias Xaas.Ultracode.CapitalCensus.SelfDigest.Law

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)
    :ok
  end

  @topology %{
    required_closure: "semantic_crown_replay",
    residual_shape: "toolchain_pin_missing",
    context: "cold_replay_work_dir"
  }

  defp record_episode!(attrs) do
    Episode
    |> Ash.Changeset.for_create(:create, %{
      subject: Map.get(attrs, :subject, "worker-test"),
      outcome: Map.get(attrs, :outcome, :worker_unclosed),
      required_closure: Map.get(attrs, :required_closure, @topology.required_closure),
      residual_shape: Map.get(attrs, :residual_shape, @topology.residual_shape),
      context: Map.get(attrs, :context, @topology.context)
    })
    |> Ash.create!(authorize?: false)
  end

  defp episode_keys do
    Ash.read!(Episode, authorize?: false)
    |> Enum.map(&Map.take(&1, [:required_closure, :residual_shape, :context]))
  end

  test "ontology exposes the G-table, threshold and classified shapes as data" do
    assert Facts.recurrence_threshold() == 3

    assert {:hypothesis, :runtime, :otp_ash_reactor} =
             Law.classify(%{residual_shape: "toolchain_pin_missing"})

    assert {:unknown, nil, nil} = Law.classify(%{residual_shape: "never_seen_in_ontology"})

    assert %{class: :runtime, primitive: :otp_ash_reactor} in Facts.g_table()
  end

  test "3 same-topology episodes cluster, classify and admit a real WorkOrder" do
    for i <- 1..3, do: record_episode!(%{subject: "worker-#{i}"})

    cluster = Law.cluster(episode_keys()) |> Enum.find(& &1.recurring?)

    {:ok, attrs} =
      Law.self_work_order(
        cluster
        |> Map.put(:falsifier, "replay the 3 episodes: mix test self_digest_chicago_test")
        |> Map.put(:derived_from_receipt, "receipt-abc123")
      )

    # the real chain: episodes -> cluster row -> Gap (hypothesis) -> WorkOrder
    cluster_row =
      ExperienceCluster
      |> Ash.Changeset.for_create(:create, %{
        required_closure: elem(cluster.topology, 0),
        residual_shape: elem(cluster.topology, 1),
        context: elem(cluster.topology, 2),
        episode_count: cluster.count
      })
      |> Ash.create!(authorize?: false)

    gap_row =
      Gap
      |> Ash.Changeset.for_create(:create, %{
        experience_cluster_id: cluster_row.id,
        required_closure: elem(cluster.topology, 0),
        residual_shape: elem(cluster.topology, 1),
        context: elem(cluster.topology, 2),
        recurrence_class: :runtime,
        primitive_target: :otp_ash_reactor,
        episode_count: cluster.count,
        falsifier: "replay",
        status: :hypothesis
      })
      |> Ash.create!(authorize?: false)

    order =
      WorkOrder
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :gap_id, gap_row.id))
      |> Ash.create!(authorize?: false)

    assert order.status == :open
    assert order.classification == :runtime
    assert String.starts_with?(order.ticket_id, "GC-")
    assert length(Ash.read!(WorkOrder, authorize?: false)) == 1
  end

  test "differing topology MUST NOT cluster ({2 same, 1 different} negative)" do
    record_episode!(%{subject: "a"})
    record_episode!(%{subject: "b"})
    record_episode!(%{subject: "c", context: "different_context"})

    same = Enum.find(Law.cluster(episode_keys()), &(&1.topology == Law.topology_key(@topology)))

    assert same.count == 2
    refute same.recurring?
    assert {:refused, :below_threshold} = Law.self_work_order(same)
  end

  test "2 episodes MUST NOT create recurrence at the ontology threshold" do
    record_episode!(%{subject: "a"})
    record_episode!(%{subject: "b"})

    refute Enum.any?(Law.cluster(episode_keys()), & &1.recurring?)
  end

  test "missing falsifier or provenance receipt refuses self-work orders" do
    base = %{
      count: 3,
      topology: Law.topology_key(@topology),
      episodes: []
    }

    assert {:refused, :missing_provenance} = Law.self_work_order(base)
    assert {:refused, :missing_provenance} = Law.self_work_order(Map.put(base, :falsifier, "replay"))

    assert {:refused, :missing_provenance} =
             Law.self_work_order(Map.merge(base, %{falsifier: "replay", derived_from_receipt: ""}))

    assert {:refused, :below_threshold} = %{base | count: 2} |> Law.self_work_order()
  end
  test "unclassified class names are refused by the generated enum type" do
    assert_raise Ash.Error.Invalid, ~r/quantum_gravity/i, fn ->
      Gap
      |> Ash.Changeset.for_create(:create, %{
        experience_cluster_id: Ash.UUID.generate(),
        required_closure: "x",
        residual_shape: "toolchain_pin_missing",
        context: "y",
        recurrence_class: :quantum_gravity,
        primitive_target: :ontology,
        episode_count: 3,
        falsifier: "replay",
        status: :hypothesis
      })
      |> Ash.create!(authorize?: false)
    end
  end

  test "frontier ratio arithmetic and improvement direction" do
    assert Law.frontier_ratio(3, 12) == 0.25
    assert Law.frontier_ratio(5, 0) == 0.0
    assert Law.improving?(0.5, 0.25)
    refute Law.improving?(0.25, 0.5)
    refute Law.improving?(:undefined, 0.5)
  end
end
