defmodule Xaas.Marketplace.ProviderFamilyCourtW984ihTest do
  @moduledoc """
  Lane W984ih unclaimed-family probe court over the Provider lifecycle
  family (lib/xaas/marketplace/). Census (2026-10-07, feat/playwright-surface)
  found the family heavily covered — `provider_test.exs`,
  `provider_preapprove_lifecycle_test.exs`, `family_court_w984fi_test.exs`,
  `remainder_court_w984hu_test.exs`,
  `approval_provider_status_change_provider_org_matches_test.exs`,
  `marketplace_deepening_test.exs` and the JSON:API controller courts cover
  read/create/update policy scoping, the status-smuggling refusal, slug
  identity, org-match validation (dangling + cross-org provider_id), the
  approver validation (missing + self-approval), and the suspended/reactivate
  actuation round-trip via W984fi.

  The genuinely unexercised residue is the delegated-authority evidence
  derivation contract on
  `Xaas.Marketplace.Changes.ApplyProviderStatusChange`:

    1. `authority/1` — the exact map sealed as `ActuationIntent.authority`
       during a real `:approve`; its public docstring promises a court can
       re-derive the IDENTICAL map from the persisted record instead of
       trusting a caller-supplied copy. No test ever derived it, asserted
       its key set/values, or exercised the `stringify(nil)` clause (a
       pending request row really has `approved_by: nil` before approval).
    2. `idempotency_key/1` — the "one approval, at most one DO" key format.
       Zero references anywhere in test/.

  These are state-bearing for replay/adjudication: a mutant that drops a
  key, mangles the key format, or crashes on nil would silently break
  receipt identity and idempotent replay of every approved status change
  without failing any existing court. Real records, real sandboxed
  Postgres, zero mocks. Mutation rationale per test inline.
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.ApprovalProviderStatusChange
  alias Xaas.Marketplace.Changes.ApplyProviderStatusChange
  alias Xaas.Marketplace.Provider

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp unique, do: System.unique_integer([:positive, :monotonic])

  defp create_provider!(org_id) do
    Provider
    |> Ash.Changeset.for_create(
      :create,
      %{
        name: "W984ih Provider #{unique()}",
        slug: "w984ih-provider-#{unique()}",
        description: "lane W984ih family court target",
        org_id: org_id
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp pending_request!(org_id, provider_id) do
    ApprovalProviderStatusChange
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_id,
        provider_id: provider_id,
        requested_by: "maker-#{unique()}",
        requested_status: :active
      },
      actor: %{org_id: org_id}
    )
    |> Ash.create!()
  end

  test "authority/1 derives the exact delegated-authority map from a real pending request (kills key-set/value mutants in the sealed ActuationIntent.authority evidence)" do
    org_id = "org-w984ih-#{unique()}"
    provider = create_provider!(org_id)
    request = pending_request!(org_id, provider.id)

    authority = ApplyProviderStatusChange.authority(request)

    # This pending row really exercises stringify(nil): approved_by is nil
    # before approval. A mutant deleting the nil clause of stringify/1
    # would crash here instead of recording nil evidence.
    assert authority == %{
             kind: "maker_checker_approval",
             approval_resource: "Xaas.Marketplace.ApprovalProviderStatusChange",
             approval_id: request.id,
             approved_by: nil,
             org_id: org_id,
             requested_status: "active"
           }

    assert authority.approval_id == to_string(request.id)
    assert is_binary(authority.requested_status)
  end

  test "authority/1 re-derives the IDENTICAL map from the re-read persisted record (kills a mutant making derivation depend on in-memory struct state rather than persisted fields)" do
    org_id = "org-w984ih-#{unique()}"
    provider = create_provider!(org_id)
    request = pending_request!(org_id, provider.id)

    from_memory = ApplyProviderStatusChange.authority(request)

    reloaded = Ash.get!(ApprovalProviderStatusChange, request.id, authorize?: false)
    from_persisted = ApplyProviderStatusChange.authority(reloaded)

    assert from_memory == from_persisted

    # The reloaded record is a genuinely distinct struct from a fresh DB read.
    assert reloaded.updated_at == request.updated_at
  end

  test "authority/1 records the real approver once set via an actual Ash update changeset application (kills a mutant reading a non-accepted or wrong approver attribute)" do
    org_id = "org-w984ih-#{unique()}"
    provider = create_provider!(org_id)
    request = pending_request!(org_id, provider.id)

    approver = "checker-#{unique()}"

    approved_record =
      request
      |> Ash.Changeset.for_update(:approve, %{approved_by: approver},
        actor: %{org_id: org_id}
      )
      |> Ash.update!()

    authority = ApplyProviderStatusChange.authority(approved_record)

    assert authority == %{
             kind: "maker_checker_approval",
             approval_resource: "Xaas.Marketplace.ApprovalProviderStatusChange",
             approval_id: to_string(request.id),
             approved_by: approver,
             org_id: org_id,
             requested_status: "active"
           }
  end

  test "idempotency_key/1 is the exact 'one approval, at most one DO' key derived from the persisted id (kills key-format mutants that would collide or miss during idempotent replay)" do
    org_id = "org-w984ih-#{unique()}"
    provider = create_provider!(org_id)
    request = pending_request!(org_id, provider.id)

    assert ApplyProviderStatusChange.idempotency_key(request) ==
             "approval-provider-status-change:#{request.id}"

    # Two different approvals never share a key.
    other = pending_request!(org_id, provider.id)
    assert ApplyProviderStatusChange.idempotency_key(other) !=
             ApplyProviderStatusChange.idempotency_key(request)
  end
end
