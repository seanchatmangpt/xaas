defmodule XaasWeb.SensitiveResourceRouteAbsenceTest do
  @moduledoc """
  Route-absence guard for the deliberately unexposed sensitive resources
  (see CLAUDE.md "Sensitive resources"). Introspects the real compiled
  resource/domain DSL: no JSON:API route, no GraphQL query/mutation, and no
  AshAi tool may target them. Adding any of those makes this test red.
  """
  use ExUnit.Case, async: true

  @sensitive [
    {Xaas.Ledger.Account, Xaas.Ledger},
    {Xaas.Ledger.Balance, Xaas.Ledger},
    {Xaas.Ledger.Transfer, Xaas.Ledger},
    {Xaas.Accounts.User, Xaas.Accounts},
    {Xaas.Accounts.Token, Xaas.Accounts},
    {Xaas.Accounts.Token.RevokeNonce, Xaas.Accounts}
  ]

  test "every sensitive resource module exists and is registered in its domain" do
    for {resource, domain} <- @sensitive do
      assert Code.ensure_loaded?(resource), "#{inspect(resource)} not loadable"
      assert resource in Ash.Domain.Info.resources(domain)
    end
  end

  test "sensitive resources have zero AshJsonApi routes" do
    for {resource, domain} <- @sensitive do
      assert AshJsonApi.Resource.Info.routes(resource, domain) == [],
             "#{inspect(resource)} gained an AshJsonApi route"
    end
  end

  test "sensitive resources are absent from the Xaas.Library AshAi tool list" do
    tools = AshAi.Info.tools(Xaas.Library)
    assert tools != []
    tool_resources = tools |> Enum.map(& &1.resource) |> MapSet.new()

    for {resource, _domain} <- @sensitive do
      refute MapSet.member?(tool_resources, resource),
             "#{inspect(resource)} exposed as an AshAi tool"
    end
  end
end
