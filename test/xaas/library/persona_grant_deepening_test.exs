defmodule Xaas.Library.PersonaGrantDeepeningTest do
  @moduledoc """
  Policy-floor deepening courts on `Xaas.Library.PersonaGrant`
  (security-floor surface, lane W718). Companion to
  `persona_grant_regression_test.exs` (which covers the happy grant/active
  path with `authorize?: false`); this file exercises the authorization
  layer itself with `authorize?:` left at its real default:

  (a) deny-by-default: every mutation without a resolved actor refuses via
      the real `Ash.Error.Forbidden` policy path (the catch-all
      `policy always() do forbid_if always() end`);
  (b) a granted caller identity can act-as a user (visible via the same
      `active_for/2` read the A2A resolver uses), a second caller without
      a grant cannot;
  (c) duplicate active grants for the same (caller_id, user_id) hit the
      real partial unique index `active_caller_user`
      (`revoked_at IS NULL`) -- identity refusal;
  (d) `:revoke` is observable on the next active check, and the partial
      index permits a fresh grant after revocation.

  Real Postgres via the sandbox, real Ash actions, no mocks. No
  @moduletag :eu_ai_act -- this is caller-credential authorization, not
  Art. 5 bias/protection adjacent.
  """

  use Xaas.DataCase, async: true

  alias Xaas.Library.PersonaGrant

  @internal_api_caller_id "internal_api_token"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
  end

  defp create_user!, do: Xaas.Generator.create_user!()

  # (a) deny-by-default -------------------------------------------------

  test "grant without an actor refuses via the Forbidden policy path" do
    user = create_user!()

    # Non-bang code interface returns the error instead of raising.
    assert {:error, %Ash.Error.Forbidden{} = error} =
             PersonaGrant.grant(@internal_api_caller_id, user.id, "w718")

    assert [%Ash.Error.Forbidden.Policy{} | _] = error.errors

    # Real state: nothing was written.
    assert {:ok, []} =
             PersonaGrant.active_for(@internal_api_caller_id, user.id, authorize?: false)
  end

  test "revoke without an actor refuses via the Forbidden policy path" do
    user = create_user!()

    grant =
      PersonaGrant.grant!(@internal_api_caller_id, user.id, "w718", authorize?: false)

    assert {:error, %Ash.Error.Forbidden{} = error} = PersonaGrant.revoke(grant)

    assert [%Ash.Error.Forbidden.Policy{} | _] = error.errors

    # Real state: the grant is still active.
    assert {:ok, [active]} =
             PersonaGrant.active_for(@internal_api_caller_id, user.id, authorize?: false)

    assert active.id == grant.id
    assert is_nil(active.revoked_at)
  end

  # (b) grant -> act-as; ungranted caller cannot ------------------------

  test "a granted caller resolves as active; a second caller without a grant does not" do
    granted_caller = "internal_api_token"
    ungranted_caller = "other_credential_without_grant"
    user = create_user!()

    grant =
      PersonaGrant.grant!(granted_caller, user.id, "w718", authorize?: false)

    assert {:ok, [found]} =
             PersonaGrant.active_for(granted_caller, user.id, authorize?: false)

    assert found.id == grant.id

    # The ungranted credential has no active binding: cannot act-as.
    assert {:ok, []} =
             PersonaGrant.active_for(ungranted_caller, user.id, authorize?: false)
  end

  # (c) duplicate grant semantics ---------------------------------------

  test "duplicate active grant for same caller+user hits the partial unique identity" do
    user = create_user!()

    PersonaGrant.grant!(@internal_api_caller_id, user.id, "w718", authorize?: false)

    error =
      assert_raise Ash.Error.Invalid, fn ->
        PersonaGrant.grant!(@internal_api_caller_id, user.id, "w718-dup",
          authorize?: false
        )
      end

    assert [%Ash.Error.Changes.InvalidAttribute{field: :caller_id} | _] =
             error.errors

    # Exactly one active row remains.
    assert {:ok, [only]} =
             PersonaGrant.active_for(@internal_api_caller_id, user.id, authorize?: false)

    assert only.granted_by == "w718"
  end

  # (d) revocation observable, re-grant permitted ------------------------

  test "revoke makes the binding inactive on the next check and permits a fresh grant" do
    user = create_user!()

    grant =
      PersonaGrant.grant!(@internal_api_caller_id, user.id, "w718", authorize?: false)

    revoked =
      PersonaGrant.revoke!(grant, authorize?: false)

    assert %DateTime{} = revoked.revoked_at

    assert {:ok, []} =
             PersonaGrant.active_for(@internal_api_caller_id, user.id, authorize?: false)

    # Partial unique index is scoped to revoked_at IS NULL: re-grant works.
    regrant =
      PersonaGrant.grant!(@internal_api_caller_id, user.id, "w718-regrant",
        authorize?: false
      )

    assert {:ok, [active]} =
             PersonaGrant.active_for(@internal_api_caller_id, user.id, authorize?: false)

    assert active.id == regrant.id
    assert active.id != grant.id

    # The revoked row is still really there, non-active.
    assert %PersonaGrant{revoked_at: %DateTime{}} = Ash.get!(PersonaGrant, grant.id)
  end
end
