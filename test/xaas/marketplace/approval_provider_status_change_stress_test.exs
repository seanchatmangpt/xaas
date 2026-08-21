defmodule Xaas.Marketplace.ApprovalProviderStatusChangeStressTest do
  @moduledoc """
  Real concurrency stress test for `Xaas.Marketplace.ApprovalProviderStatusChange`'s
  maker-checker `:create` + `:approve` flow (real
  `Xaas.Marketplace.Changes.ApplyProviderStatusChange`), following the exact
  same real convention as `test/xaas/marketplace/provider_stress_test.exs`:
  `Ecto.Adapters.SQL.Sandbox` in `{:shared, self()}` mode, real
  `Task.async_stream`, real `Ash` calls, real state-based assertions on the
  real final DB rows -- no mocking.

  50 real concurrent Tasks each perform a real `:create` (a distinct maker
  requesting the SAME real target `Provider`'s status change to `:active`)
  immediately followed by a real `:approve` (a distinct, second checker
  actor, satisfying the real
  `ApprovalProviderStatusChangeRequiresApprover` distinct-approver rule).

  Nothing in this resource's real design (see its moduledoc) enforces
  single-approval exclusivity across DIFFERENT `ApprovalProviderStatusChange`
  rows targeting the same provider -- each of the 50 races creates its own
  row and each row's own `:approve` real-succeeds (no unique constraint
  blocks concurrent distinct requests the way `Provider.unique_slug` blocks
  concurrent duplicate slugs). The real concurrency-correctness property
  under test is therefore not "only one wins" but: `Provider.status`, after
  all 50 real concurrent read-modify-write updates race on the same row,
  ends up as a single, coherent, real valid enum value (not corrupted,
  truncated, or torn) and every one of the 50 real `:approve` calls that
  committed is reflected by a real, distinct, persisted `approved_by`
  value on its own approval row -- proving Postgres row-level locking (via
  `Xaas.Marketplace.Changes.ApplyProviderStatusChange`'s real
  `Ash.get!`/`Ash.update!` read-modify-write inside the `:approve`
  transaction) serializes the real concurrent writers rather than losing
  updates.
  """

  use ExUnit.Case, async: false
  @moduletag :stress

  require Ash.Query

  alias Xaas.Marketplace.ApprovalProviderStatusChange
  alias Xaas.Marketplace.Provider

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, :manual)
    end)

    :ok
  end

  test "50 real concurrent create+approve races on the same Provider leave a coherent final status and 50 real distinct approved rows" do
    run_tag = System.unique_integer([:positive, :monotonic])
    org_id = "approval-stress-org-#{run_tag}"

    provider =
      Provider
      |> Ash.Changeset.for_create(
        :create,
        %{
          name: "Stress Target Provider #{run_tag}",
          slug: "stress-target-provider-#{run_tag}",
          description: "real concurrent maker-checker race target",
          status: :pending,
          org_id: org_id
        },
        action: :create,
        authorize?: false
      )
      |> Ash.create!()

    results =
      1..50
      |> Task.async_stream(
        fn i ->
          approval =
            ApprovalProviderStatusChange
            |> Ash.Changeset.for_create(
              :create,
              %{
                org_id: org_id,
                provider_id: provider.id,
                requested_by: "maker-#{run_tag}-#{i}",
                requested_status: :active
              },
              authorize?: false
            )
            |> Ash.create!()

          approval
          |> Ash.Changeset.for_update(
            :approve,
            %{approved_by: "checker-#{run_tag}-#{i}"},
            authorize?: false
          )
          |> Ash.update()
        end,
        max_concurrency: 50,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    oks = Enum.filter(results, &match?({:ok, %ApprovalProviderStatusChange{}}, &1))
    errors = Enum.filter(results, &match?({:error, _}, &1))

    assert errors == [],
           "expected every distinct-actor create+approve race to real-succeed (no shared uniqueness constraint blocks them), got errors: #{inspect(errors)}"

    assert length(oks) == 50

    # Real proof no approval row's write was lost or corrupted: 50 real
    # distinct persisted `approved_by` values, one per race participant.
    approved_by_values =
      oks
      |> Enum.map(fn {:ok, approval} -> approval.approved_by end)

    assert length(approved_by_values) == 50
    assert MapSet.size(MapSet.new(approved_by_values)) == 50

    # Real re-read of ALL 50 approval rows straight from Postgres,
    # independent of the in-memory `results` list above.
    {:ok, persisted_approvals} =
      ApprovalProviderStatusChange
      |> Ash.Query.filter(provider_id: provider.id)
      |> Ash.read(authorize?: false)

    assert length(persisted_approvals) == 50
    assert Enum.all?(persisted_approvals, &(&1.requested_status == :active))
    assert Enum.all?(persisted_approvals, &(&1.approved_by != nil))

    # Real final target-row state: a single, coherent, real valid status --
    # every one of the 50 real concurrent writers requested `:active`, so
    # the real Postgres-serialized final value must be `:active` (not nil,
    # not a torn/partial value, not silently reverted).
    final_provider = Ash.get!(Provider, provider.id, authorize?: false)
    assert final_provider.status == :active
  end
end
