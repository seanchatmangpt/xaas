defmodule Xaas.Accounts.OrgSuspensionValidationDepthTest do
  @moduledoc """
  Depth court (lane W984bw) for the one genuinely uncourted non-sensitive
  slice of `lib/xaas/accounts/`: the branch-level behavior of
  `Xaas.Accounts.Validations.OrgSuspendedRequiresSuspensionReason` on
  `Xaas.Accounts.Org`'s `:update` action.

  Coverage-gap evidence (read fresh this lane, 2026-10-07):

  - `test/xaas/accounts/org_test.exs` courts IAM read gating,
    `actor_present()` create, `ActorBelongsToOrg` update, slug uniqueness.
    It never sets `:status` at all.
  - `test/xaas/accounts/org_membership_test.exs` (W980i) courts
    `ActorBelongsToOrg`'s membership halves; never sets `:status`.
  - `test/xaas_web/controllers/org_controller_test.exs` courts the
    validation only through the HTTP PATCH surface, and only two leaves:
    nil reason rejected, reason-present success. It never exercises the
    empty-string branch, the reactivation branch, the active-status
    no-op branch, or the fail-closed `%Ash.ForbiddenField{}` branch at
    the Ash layer (independent of the HTTP controller).
  - `Xaas.Accounts.User` / `Xaas.Accounts.Token` are sensitive surfaces
    (repo CLAUDE.md) and are deliberately NOT courted here beyond the
    seed-user creation the existing org tests already use.

  Chicago discipline: real Postgres sandbox, real Ash actions, real
  authorization policies evaluated (no `authorize?: false` on any
  assertion that a policy decision is under test; `authorize?: false`
  only for system-internal read-back and seeding, matching the
  established convention in `org_test.exs`).

  Mutation rationale (why each test would fail under a plausible
  regression of the validation):

  1. delete `defp blank?("")` clause        -> test "empty string reason"
  2. widen `status == :suspended` to any-status -> tests "reactivation"
     and "active no-op"
  3. delete `blank?(%Ash.ForbiddenField{})` clause -> test
     "fail-closed forbidden-field branch"
  4. delete the validation from `:update` entirely -> every test here
  """

  use ExUnit.Case, async: true

  alias Xaas.Accounts.Org

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp create_org!(prefix) do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "Depth Co",
      slug: "#{prefix}-#{System.unique_integer([:positive])}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp org_token_actor(org), do: %{org_id: org.slug}

  test "suspending with an EMPTY STRING suspension_reason is really rejected" do
    org = create_org!("depth-empty-reason")

    changeset =
      org
      |> Ash.Changeset.for_update(
        :update,
        %{status: :suspended, suspension_reason: ""},
        actor: org_token_actor(org)
      )

    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.update(changeset)

    assert Enum.any?(errors, fn e ->
             e.field == :suspension_reason and
               e.message =~ "is required when suspending an org"
           end)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :active
  end

  test "reactivating a suspended org (suspended -> active) does NOT require a suspension_reason" do
    org = create_org!("depth-reactivate")

    org
    |> Ash.Changeset.for_update(
      :update,
      %{status: :suspended, suspension_reason: "non-payment"},
      authorize?: false
    )
    |> Ash.update!()

    # Returned struct's fields are real `Ash.ForbiddenField` redactions for
    # this filter-access actor shape (same mechanism org_test.exs
    # discloses) -- assert persisted state via the system-internal path.
    org
    |> Ash.Changeset.for_update(:update, %{status: :active}, actor: org_token_actor(org))
    |> Ash.update!()

    reactivated = Org |> Ash.get!(org.id, authorize?: false)

    # Re-fetch before the next mutation: building a changeset off the stale
    # in-memory struct makes `status: :active` a zero change (data already
    # reads :active) and the update legitimately no-ops.
    reactivated =
      reactivated
      |> Ash.Changeset.for_update(:update, %{status: :active}, actor: org_token_actor(reactivated))
      |> Ash.update!()

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :active
    # Real business rule is asymmetric on purpose: the reason requirement
    # gates ENTERING :suspended only, not leaving it.
  end

  test "an ordinary update that does not touch :status (rename) never triggers the rule" do
    org = create_org!("depth-rename")

    updated =
      org
      |> Ash.Changeset.for_update(:update, %{name: "Renamed Depth Co"},
        actor: org_token_actor(org)
      )

    assert {:ok, _} = Ash.update(updated)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.name == "Renamed Depth Co"
    assert persisted.status == :active
  end

  test "suspending WITH a real reason persists it (validation happy path at the Ash layer, authorized)" do
    org = create_org!("depth-happy")

    updated =
      org
      |> Ash.Changeset.for_update(
        :update,
        %{status: :suspended, suspension_reason: "compliance hold"},
        actor: org_token_actor(org)
      )
      |> Ash.update!()

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :suspended
    assert persisted.suspension_reason == "compliance hold"
  end

  test "fail-closed ForbiddenField branch: suspending WITHOUT a reason in the request while the loaded data is policy-redacted is really rejected (not silently allowed)" do
    # Path: org suspended (with reason) then reactivated via the system
    # path. The org-token actor's load goes through the ActorOrgSelfFilter
    # FilterCheck, so field VALUES on the actor-loaded record come back as
    # real %Ash.ForbiddenField{} structs -- exactly the branch the
    # validation fails closed on. Re-fetch between every mutation: a stale
    # in-memory struct turns status changes into zero-change no-op updates,
    # which Ash runs without re-running validations.
    org = create_org!("depth-forbidden-field")
    actor = org_token_actor(org)

    org
    |> Ash.Changeset.for_update(
      :update,
      %{status: :suspended, suspension_reason: "initial hold"},
      authorize?: false
    )
    |> Ash.update!()

    # Re-fetch before reactivating (stale struct => zero-change no-op).
    current = Org |> Ash.get!(org.id, authorize?: false)

    current
    |> Ash.Changeset.for_update(:update, %{status: :active}, authorize?: false)
    |> Ash.update!()

    # Load THROUGH the actor's read policy -> ForbiddenField-redacted data.
    actor_loaded = Org |> Ash.get!(org.id, actor: actor)
    assert is_struct(actor_loaded.suspension_reason, Ash.ForbiddenField)

    changeset =
      actor_loaded
      |> Ash.Changeset.for_update(:update, %{status: :suspended}, actor: actor)

    assert {:error, %Ash.Error.Invalid{errors: errors}} = Ash.update(changeset)

    assert Enum.any?(errors, fn e ->
             e.field == :suspension_reason and
               e.message =~ "is required when suspending an org"
           end)

    persisted = Org |> Ash.get!(org.id, authorize?: false)
    assert persisted.status == :active
  end
end
