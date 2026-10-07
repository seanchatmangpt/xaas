defmodule Xaas.Witness.CertifiedReceipt do
  @moduledoc """
  An immutable, signature-bearing certified receipt over a subject.

  Payload fields (`subject`, `payload_hash_hex`, `algorithm`,
  `signature_hex`, `verifying_key_hex`) are write-once at create time and
  can never be changed afterward: the resource exposes no general
  `:update`/`:destroy` action and its policies forbid every action except
  `:read`, create `:ingest`, and the narrow `:record_verification` update,
  which itself refuses once `verified` is true (a verification result is
  also write-once).
  """
  use Xaas.Resource,
    domain: Xaas.Witness,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Ash.Changeset

  @algorithms [:es256, :ed25519, :es256k, :ml_dsa65]

  postgres do
    table("witness_certified_receipts")
    repo(Xaas.Repo)
  end

  attributes do
    uuid_primary_key(:id)

    attribute(:subject, :string, allow_nil?: false, public?: true)
    attribute(:payload_hash_hex, :string, allow_nil?: false, public?: true)

    attribute(:algorithm, :atom,
      allow_nil?: false,
      public?: true,
      constraints: [one_of: @algorithms]
    )

    attribute(:signature_hex, :string, allow_nil?: false, public?: true)
    attribute(:verifying_key_hex, :string, allow_nil?: false, public?: true)

    attribute(:verified, :boolean, allow_nil?: false, default: false, public?: true)
    attribute(:verified_at, :utc_datetime_usec, allow_nil?: true, public?: true)

    timestamps()
  end

  identities do
    identity(:unique_subject_payload, [:subject, :payload_hash_hex])
  end

  actions do
    defaults([:read])

    create :ingest do
      primary?(true)
      accept([:subject, :payload_hash_hex, :algorithm, :signature_hex, :verifying_key_hex])
    end

    update :record_verification do
      primary?(true)
      require_atomic?(false)
      accept([])

      change(fn changeset, _context ->
        if changeset.data.verified do
          Changeset.add_error(
            changeset,
            field: :verified,
            message: "receipt is already verified; verification results are write-once"
          )
        else
          now = DateTime.utc_now()

          changeset
          |> Changeset.force_change_attribute(:verified, true)
          |> Changeset.force_change_attribute(:verified_at, now)
        end
      end)
    end
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    bypass action(:ingest) do
      authorize_if(always())
    end

    bypass action(:record_verification) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end
end
