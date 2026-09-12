defmodule Xaas.Library.PersonaGrantRegressionTest do
  @moduledoc """
  Narrow, real Chicago-style regression check on `Xaas.Library.PersonaGrant`
  itself (not routed through the A2A agent), added alongside the
  vision-2030 ex4pm-staleness/audit-plug batch to prove that batch did not
  break the existing grant/resolve path. Real Ash `:grant` create action,
  real Postgres row via the sandbox, real `resolve_actor/2`-equivalent
  read -- no mocking.

  Broader end-to-end coverage of this same path through the real A2A
  agent already exists in
  `test/xaas_web/a2a/next_read_user_agent_test.exs`
  ("resolve_actor/2 persona grant enforcement"); this file is the
  resource-level companion, not a replacement.
  """
  use Xaas.DataCase, async: true

  alias Xaas.Library.PersonaGrant

  @internal_api_caller_id "internal_api_token"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
  end

  defp create_user! do
    Xaas.Generator.create_user!()
  end

  test "grant!/4 creates a real, readable PersonaGrant row for a real user" do
    user = create_user!()

    grant =
      PersonaGrant.grant!(@internal_api_caller_id, user.id, "regression_test", authorize?: false)

    assert grant.user_id == user.id
    assert grant.caller_id == @internal_api_caller_id

    # Real Ash idiom: PersonaGrant.active_for/2 is the resource's own
    # code_interface (lib/xaas/library/persona_grant.ex:84, action:
    # :list_active) for exactly this query -- use it instead of hand-
    # rolling the same Ash.Query.filter/Ash.read_one! it already
    # encodes, so this test exercises the same public surface a real
    # caller (e.g. next_read_user_agent.ex's resolve_actor/2) uses.
    assert {:ok, [reloaded]} =
             PersonaGrant.active_for(@internal_api_caller_id, user.id, authorize?: false)

    assert reloaded.id == grant.id
  end

  test "an ungranted user has no matching PersonaGrant row" do
    user = create_user!()

    assert {:ok, []} =
             PersonaGrant.active_for(@internal_api_caller_id, user.id, authorize?: false)
  end
end
