defmodule Xaas.Witness.VerificationKey do
  @moduledoc """
  A registered verifying key on the witness surface (kid + algorithm +
  key material). Registering the same kid twice is refused by identity.
  """
  use Xaas.Resource,
    domain: Xaas.Witness,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  @algorithms [:es256, :ed25519, :es256k, :ml_dsa65]

  postgres do
    table("witness_verification_keys")
    repo(Xaas.Repo)
  end

  attributes do
    uuid_primary_key(:id)
    attribute(:kid, :string, allow_nil?: false, public?: true)

    attribute(:algorithm, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: @algorithms]
    )

    attribute(:key_material_hex, :string, allow_nil?: false, public?: true)
    attribute(:created_at, :utc_datetime_usec, allow_nil?: false, public?: true)
  end

  identities do
    identity(:unique_kid, [:kid])
  end

  actions do
    defaults([:read])

    create :register do
      primary?(true)
      accept([:kid, :algorithm, :key_material_hex])

      change(fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(:created_at, DateTime.utc_now())
      end)
    end
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass action(:register) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end
end
