defmodule Xaas.Ultracode.CapitalCensus.FamilyCourtW984ijTest do
  @moduledoc """
  W984ij unclaimed-family probe court for the CapitalCensus domain
  (`lib/xaas/ultracode/capital_census/`). The pre-existing corpus
  (self_digest_chicago/worker, experience, receipt, route tests) covers
  creation through the clustering law but never exercises:

    * `Resolution` — the only CapitalCensus resource with zero test refs;
    * any `update` action on Episode/ExperienceCluster/Gap/WorkOrder
      (status transitions hypothesis->admitted/refuted, open->resolved);
    * relationship loads (`gaps`, `work_orders`, `resolutions`);
    * typed enum refusals outside the one Gap `:quantum_gravity` case.

  Real sandboxed Postgres, real Ash actions, zero mocks. Mutation
  rationale: each test pins a branch that a mutation (dropping an enum
  value, defaulting status, or severing a relationship) would flip.
  """

  use Xaas.DataCase, async: false

  alias Xaas.Ultracode.CapitalCensus.{
    Episode,
    ExperienceCluster,
    Gap,
    Resolution,
    WorkOrder
  }

  setup do
    owner = Ecto.Adapters.SQL.Sandbox.start_owner!(Xaas.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(owner) end)
    :ok
  end

  defp cluster!(overrides \\ %{}) do
    ExperienceCluster
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          required_closure: "probe_closure",
          residual_shape: "probe_shape",
          context: "probe_context",
          episode_count: 3
        },
        overrides
      )
    )
    |> Ash.create!(authorize?: false)
  end

  defp gap!(cluster, overrides \\ %{}) do
    Gap
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          experience_cluster_id: cluster.id,
          required_closure: "probe_closure",
          residual_shape: "probe_shape",
          context: "probe_context",
          recurrence_class: :runtime,
          primitive_target: :otp_ash_reactor,
          episode_count: 3,
          falsifier: "replay: mix test family_court_w984ij",
          status: :hypothesis
        },
        overrides
      )
    )
    |> Ash.create!(authorize?: false)
  end

  defp order!(gap, overrides \\ %{}) do
    WorkOrder
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          ticket_id: "GC-PROBE-1",
          subject: "self",
          observed: "state not exercised",
          expected: "branch exercised",
          residual: "probe",
          classification: :runtime,
          candidate_repair: "write the court",
          falsifier: "replay: mix test family_court_w984ij",
          success_criteria: "exit 0",
          derived_from_receipt: "sha256:" <> String.duplicate("a", 64),
          status: :open,
          gap_id: gap.id
        },
        overrides
      )
    )
    |> Ash.create!(authorize?: false)
  end

  describe "Resolution — the unclaimed resource" do
    test "create + read round-trips the ResolutionOutcome cast and receipt_ref" do
      # Mutation rationale: defaulting outcome or dropping :refuted from the
      # enum flips this assert.
      gap = gap!(cluster!())
      order = order!(gap)

      resolution =
        Resolution
        |> Ash.Changeset.for_create(:create, %{
          outcome: :resolved,
          receipt_ref: "sha256:" <> String.duplicate("b", 64),
          work_order_id: order.id
        })
        |> Ash.create!(authorize?: false)

      assert resolution.outcome == :resolved
      assert resolution.work_order_id == order.id

      [read_back] = Ash.read!(Resolution, authorize?: false)
      assert read_back.outcome == :resolved
    end

    test "update re-outcomes a resolution (resolved -> refuted)" do
      # Mutation rationale: removing :update from the defaults list or the
      # :refuted enum value breaks this transition.
      gap = gap!(cluster!())
      order = order!(gap)

      resolution =
        Resolution
        |> Ash.Changeset.for_create(:create, %{
          outcome: :resolved,
          receipt_ref: "r-1",
          work_order_id: order.id
        })
        |> Ash.create!(authorize?: false)
        |> then(&Ash.Changeset.for_update(&1, :update, %{outcome: :refuted}))
        |> Ash.update!(authorize?: false)

      assert resolution.outcome == :refuted
    end

    test "invalid outcome atom is refused by the generated enum type" do
      # Mutation rationale: enum vacuity — a permissive type would admit.
      gap = gap!(cluster!())
      order = order!(gap)

      assert_raise Ash.Error.Invalid, ~r/ascended/i, fn ->
        Resolution
        |> Ash.Changeset.for_create(:create, %{
          outcome: :ascended,
          receipt_ref: "r-2",
          work_order_id: order.id
        })
        |> Ash.create!(authorize?: false)
      end
    end

    test "WorkOrder load :resolutions returns the chained resolutions" do
      # Mutation rationale: severing the has_many relationship flips this.
      gap = gap!(cluster!())
      order = order!(gap)

      Resolution
      |> Ash.Changeset.for_create(:create, %{
        outcome: :blocked,
        receipt_ref: "r-3",
        work_order_id: order.id
      })
      |> Ash.create!(authorize?: false)

      loaded = Ash.load!(order, :resolutions, authorize?: false)
      assert [%{outcome: :blocked}] = loaded.resolutions
    end
  end

  describe "status transitions via update — never exercised pre-probe" do
    test "Gap hypothesis -> admitted -> refuted through real update actions" do
      # Mutation rationale: defaulting status or dropping :admitted/:refuted
      # from GapStatus flips these asserts.
      gap = gap!(cluster!())

      assert gap.status == :hypothesis

      admitted =
        gap
        |> then(&Ash.Changeset.for_update(&1, :update, %{status: :admitted}))
        |> Ash.update!(authorize?: false)

      assert admitted.status == :admitted

      refuted =
        admitted
        |> then(&Ash.Changeset.for_update(&1, :update, %{status: :refuted}))
        |> Ash.update!(authorize?: false)

      assert refuted.status == :refuted
    end

    test "WorkOrder open -> resolved through update" do
      # Mutation rationale: dropping :resolved from WorkOrderStatus breaks it.
      order = order!(gap!(cluster!()))

      resolved =
        order
        |> then(&Ash.Changeset.for_update(&1, :update, %{status: :resolved}))
        |> Ash.update!(authorize?: false)

      assert resolved.status == :resolved
    end

    test "Episode update re-outcomes a frontier episode (error -> handed_off)" do
      # Mutation rationale: dropping :handed_off from FrontierOutcome flips it.
      episode =
        Episode
        |> Ash.Changeset.for_create(:create, %{
          subject: "probe-episode",
          outcome: :error,
          required_closure: "c",
          residual_shape: "s",
          context: "x"
        })
        |> Ash.create!(authorize?: false)

      updated =
        episode
        |> then(&Ash.Changeset.for_update(&1, :update, %{outcome: :handed_off}))
        |> Ash.update!(authorize?: false)

      assert updated.outcome == :handed_off
    end

    test "Episode invalid frontier outcome is refused at create" do
      # Mutation rationale: a permissive FrontierOutcome would admit.
      assert_raise Ash.Error.Invalid, ~r/transcended/i, fn ->
        Episode
        |> Ash.Changeset.for_create(:create, %{
          subject: "probe-episode",
          outcome: :transcended,
          required_closure: "c",
          residual_shape: "s",
          context: "x"
        })
        |> Ash.create!(authorize?: false)
      end
    end

    test "ExperienceCluster update rewrites episode_count" do
      # Mutation rationale: dropping :episode_count from the update action
      # (accepted fields) leaves the count stale.
      cluster = cluster!(%{episode_count: 1})

      updated =
        cluster
        |> then(&Ash.Changeset.for_update(&1, :update, %{episode_count: 7}))
        |> Ash.update!(authorize?: false)

      assert updated.episode_count == 7
    end
  end

  describe "relationship loads across the whole chain" do
    test "ExperienceCluster load :gaps and Gap load :work_orders traverse" do
      # Mutation rationale: severing either has_many flips this.
      cluster = cluster!()
      gap = gap!(cluster)
      order!(gap)

      loaded_cluster = Ash.load!(cluster, :gaps, authorize?: false)
      assert [%Gap{}] = loaded_cluster.gaps

      [loaded_gap] = loaded_cluster.gaps
      loaded_gap = Ash.load!(loaded_gap, :work_orders, authorize?: false)
      assert [%WorkOrder{}] = loaded_gap.work_orders
    end
  end

  describe "typed refusals on the remaining enums" do
    test "Gap invalid primitive_target refused" do
      # Mutation rationale: permissive PrimitiveTarget enum admits garbage.
      assert_raise Ash.Error.Invalid, ~r/quantum_fond/i, fn ->
        gap!(cluster!(), %{primitive_target: :quantum_fond})
      end
    end

    test "WorkOrder invalid classification refused" do
      # Mutation rationale: permissive RecurrenceClass enum admits garbage.
      assert_raise Ash.Error.Invalid, ~r/metaphysical/i, fn ->
        order!(gap!(cluster!()), %{classification: :metaphysical})
      end
    end

    test "WorkOrder invalid status refused" do
      # Mutation rationale: permissive WorkOrderStatus enum admits garbage.
      assert_raise Ash.Error.Invalid, ~r/vibes/i, fn ->
        order!(gap!(cluster!()), %{status: :vibes})
      end
    end
  end
end
