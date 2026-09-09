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

  alias Xaas.Accounts.User
  alias Xaas.Library.PersonaGrant
  require Ash.Query

  @internal_api_caller_id "internal_api_token"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
  end

  defp create_user! do
    Ash.Seed.seed!(User, %{email: Faker.Internet.email()})
  end

  test "grant!/4 creates a real, readable PersonaGrant row for a real user" do
    user = create_user!()

    grant =
      PersonaGrant.grant!(@internal_api_caller_id, user.id, "regression_test", authorize?: false)

    assert grant.user_id == user.id
    assert grant.caller_id == @internal_api_caller_id

    caller_id = @internal_api_caller_id

    reloaded =
      PersonaGrant
      |> Ash.Query.filter(user_id == ^user.id and caller_id == ^caller_id)
      |> Ash.read_one!(authorize?: false)

    assert reloaded != nil
    assert reloaded.id == grant.id
  end

  test "an ungranted user has no matching PersonaGrant row" do
    user = create_user!()

    caller_id = @internal_api_caller_id

    result =
      PersonaGrant
      |> Ash.Query.filter(user_id == ^user.id and caller_id == ^caller_id)
      |> Ash.read_one!(authorize?: false)

    assert result == nil
  end
end
