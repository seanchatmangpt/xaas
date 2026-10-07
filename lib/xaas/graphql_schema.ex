defmodule Xaas.GraphqlSchema do
  use Absinthe.Schema

  use AshGraphql,
    domains: [
      Xaas.Operations,
      Xaas.Library,
      Xaas.Marketplace,
      # SPEC-31 (W819/W802-GAP-2; lane W973c design-wave 8): wire the
      # remaining domains. Each addition passed a real compile gate
      # (MIX_BUILD_ROOT=_build-laneW973c); domains that failed the gate are
      # disclosed UNSUPPORTED(graphql-domain-N) in
      # docs/sjira/v26.10.6/plans/w973c-design-wave8.md, not forced.
      Xaas.Accounts,
      Xaas.A2a,
      Xaas.Billing,
      Xaas.Coupling,
      Xaas.Conference,
      Xaas.Governance,
      Xaas.Graphlaw,
      Xaas.Generation,
      Xaas.Igniter,
      Xaas.Ledger,
      Xaas.Ocel,
      Xaas.Platform,
      Xaas.Security,
      Xaas.TemporalMemory,
      Xaas.Ultracode,
      Xaas.Witness
    ]

  import_types(Absinthe.Plug.Types)

  query do
    # Custom Absinthe queries can be placed here
    @desc """
    Hello! This is a sample query to verify that AshGraphql has been set up correctly.
    Remove me once you have a query of your own!
    """
    field :say_hello, :string do
      resolve(fn _, _, _ ->
        {:ok, "Hello from AshGraphql!"}
      end)
    end
  end

  mutation do
    # Custom Absinthe mutations can be placed here
  end

  subscription do
    # Custom Absinthe subscriptions can be placed here
  end
end
