defmodule Xaas.Igniter.RefusalCode do
  @moduledoc """
  One entry of the ggen_igniter typed refusal vocabulary
  (`ggen_igniter/priv/schema/refusals.schema.json`, top-level `refusals`
  array; the schema is the source of truth, this is a queryable projection).

  Canonical text form of a code: `REFUSED:<CODE> <detail>`; legacy forms
  `REFUSED(<CODE>) subject: detail` and `REFUSED_<CODE> detail` parse to the
  same code.
  """
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Igniter,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    attribute :code, :string do
      allow_nil?(false)
      public?(true)
      primary_key?(true)
      writable?(true)
    end

    attribute(:family, :string, allow_nil?: false, public?: true)
    attribute(:retryable, :boolean, allow_nil?: false, public?: true, default: false)
    attribute(:broken_term, :string, public?: true)
    attribute(:owner, :string, public?: true)
    attribute(:fix_hint, :string, public?: true)

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_code, [:code])
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([:code, :family, :retryable, :broken_term, :owner, :fix_hint])
    end

    update :update do
      accept([:family, :retryable, :broken_term, :owner, :fix_hint])
      require_atomic?(false)
    end
  end
end
