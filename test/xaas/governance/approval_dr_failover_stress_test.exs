defmodule Xaas.Governance.ApprovalDrFailoverStressTest do
  @moduledoc """
  Real concurrency stress test: real concurrent Elixir Tasks, each doing a
  real `Ash.create!` (file a DR failover request) followed by a real
  `Ash.update!` (`:approve`) against the real live Postgres (via
  Ecto.Adapters.SQL.Sandbox's `{:shared, self()}` mode, so every spawned
  Task connection reuses the same sandboxed transaction as the test
  process). No mocking -- real Task.async/await, real Ash.create!/update!,
  real Ash.read! count assertion on real persisted rows. Matches the style
  of `Xaas.Operations.CapabilityLivenessReceiptStressTest`, the only other
  real stress test in this repo.

  Each concurrent task first opens a real, distinct
  `Xaas.Operations.Incident` in its own `from_region` (satisfying
  `ApprovalDrFailoverRequiresOpenIncident`), then creates and approves its
  own `ApprovalDrFailover` row with a distinct `approved_by` (satisfying
  `ApprovalDrFailoverRequiresApprover`'s "second, distinct owner" rule).
  """

  use ExUnit.Case, async: false
  @moduletag :stress

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDrFailover
  alias Xaas.Operations.Incident

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  test "50 real concurrent Tasks each open an incident, create, and approve a DR failover" do
    run_tag = System.unique_integer([:positive, :monotonic])

    # Real, required since ApprovalDrFailover's real Ash-core multitenancy
    # wiring: org_id is now a real FK to orgs.slug, so a real Org row must
    # exist before any concurrent task creates a failover referencing it.
    org_slug =
      Org
      |> Ash.Changeset.for_create(:create, %{name: "Stress Org", slug: "stress-org-#{run_tag}"})
      |> Ash.create!(authorize?: false)
      |> Map.fetch!(:slug)

    tasks =
      for i <- 1..50 do
        Task.async(fn ->
          region = "stress-region-#{run_tag}-#{i}"

          Ash.create!(
            Incident,
            %{
              org_id: org_slug,
              title: "stress incident ##{i}",
              description: "concurrent stress DR precondition ##{i}",
              region: region,
              status: :open,
              opened_at: DateTime.utc_now()
            },
            action: :create,
            authorize?: false
          )

          failover =
            Ash.create!(
              ApprovalDrFailover,
              %{
                org_id: org_slug,
                requested_by: "stress-requester-#{i}",
                from_region: region,
                to_region: "stress-target-#{run_tag}-#{i}",
                reason: "concurrent stress failover ##{i}"
              },
              action: :create,
              authorize?: false,
              tenant: org_slug
            )

          Ash.update!(
            failover,
            %{approved_by: "stress-approver-#{i}"},
            action: :approve,
            authorize?: false
          )
        end)
      end

    results = Task.await_many(tasks, 30_000)

    assert length(results) == 50
    assert Enum.all?(results, &match?(%ApprovalDrFailover{}, &1))
    assert Enum.all?(results, & &1.approved_by)

    expected_reasons_list = Enum.map(1..50, &"concurrent stress failover ##{&1}")
    expected_set = MapSet.new(expected_reasons_list)

    persisted =
      ApprovalDrFailover
      |> Ash.read!(authorize?: false, tenant: org_slug)
      |> Enum.filter(&MapSet.member?(expected_set, &1.reason))

    assert length(persisted) == 50
    assert Enum.all?(persisted, & &1.approved_by)

    persisted_reasons = MapSet.new(persisted, & &1.reason)
    assert persisted_reasons == expected_set
  end
end
