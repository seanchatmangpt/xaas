defmodule Xaas.Governance.ApprovalBackupRetentionChangeStressTest do
  @moduledoc """
  Real concurrency stress test: 30 real concurrent Elixir Tasks, each doing
  a real `Ash.create!` (submit) followed by a real `Ash.update!` (approve)
  against the real live Postgres, via the Ecto.Adapters.SQL.Sandbox's
  `{:shared, self()}` mode so every spawned Task connection reuses the
  same sandboxed transaction as the test process. No mocking -- real
  Task.async/await, real Ash.create!/Ash.update!, real Ash.read! count
  assertion on real persisted rows.

  `tier: :pro`, `requested_retention_days: 30` is used deliberately: `:pro`
  passes `ApprovalBackupRetentionChangeWithinTierRange`'s real 7-90 day
  range, and 30 equals `ApprovalBackupRetentionChangeChargeOverage`'s real
  `:pro` default (see that module), so `overage_days` is exactly 0 and no
  real `Xaas.Ledger.Transfer` fires -- keeping this stress test scoped to
  the governance resource's own create/approve concurrency, not the
  ledger's.
  """

  use ExUnit.Case, async: false
  @moduletag :stress

  alias Xaas.Governance.ApprovalBackupRetentionChange

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    org =
      Ash.create!(
        Xaas.Accounts.Org,
        %{
          name: "Stress Test Org",
          slug: "stress-test-org-#{System.unique_integer([:positive, :monotonic])}"
        },
        action: :create,
        authorize?: false
      )

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    {:ok, org: org}
  end

  test "30 real concurrent Tasks each create+approve a unique retention change, all rows real-persisted",
       %{org: org} do
    run_tag = System.unique_integer([:positive, :monotonic])

    tasks =
      for i <- 1..30 do
        Task.async(fn ->
          created =
            Ash.create!(
              ApprovalBackupRetentionChange,
              %{
                org_id: org.slug,
                requested_by: "stress-requester-#{run_tag}-#{i}",
                requested_retention_days: 30,
                tier: :pro
              },
              action: :create,
              authorize?: false
            )

          Ash.update!(
            created,
            %{approved_by: "stress-approver-#{run_tag}-#{i}"},
            action: :approve,
            authorize?: false
          )
        end)
      end

    results = Task.await_many(tasks, 30_000)

    assert length(results) == 30
    assert Enum.all?(results, &match?(%ApprovalBackupRetentionChange{}, &1))

    assert Enum.all?(results, fn r ->
             r.approved_by != nil and String.starts_with?(r.approved_by, "stress-approver-#{run_tag}-")
           end)

    expected_requesters =
      MapSet.new(Enum.map(1..30, &"stress-requester-#{run_tag}-#{&1}"))

    persisted =
      ApprovalBackupRetentionChange
      |> Ash.read!(authorize?: false)
      |> Enum.filter(&MapSet.member?(expected_requesters, &1.requested_by))

    assert length(persisted) == 30
    assert Enum.all?(persisted, & &1.approved_by)

    persisted_requesters = MapSet.new(persisted, & &1.requested_by)
    assert persisted_requesters == expected_requesters
  end
end
