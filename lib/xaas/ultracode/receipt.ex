defmodule Xaas.Ultracode.Receipt do
  @moduledoc """
  Evidences one `Epoch`'s outcome.

  Reuse decision (per task instruction to check recon before duplicating):
  `Xaas.Operations.ActuationReceipt` already exists as a general receipt
  resource, but it is structurally bound to `Xaas.Operations.ActuationIntent`
  (a `belongs_to :intent`, non-nullable) and is the sole receipt for the
  admitted Reactor DO kernel specifically (`docs/claude/diataxis/reference/
  actuation-and-semantics.md`). It cannot be pointed at an `Epoch` without
  either making `intent_id` nullable (weakening its own existing invariant)
  or repurposing a kernel-scoped resource for a different subject. This
  module is therefore a new resource, scoped to `Epoch`, following the same
  `outcome`-vocabulary convention this repo's CLAUDE.md doctrine already
  uses (ALIVE/PARTIAL_ALIVE/BLOCKED/UNSUPPORTED/REFUSED) rather than
  `ActuationReceipt`'s narrower `:prepared/:succeeded/:failed/:refused`.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ultracode,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ultracode_receipts")
    repo(Xaas.Repo)
  end

  policies do
    policy always() do
      forbid_if(always())
    end
  end

  actions do
    read :read do
      primary?(true)
      public?(false)
    end

    create :seal do
      public?(false)
      accept([:epoch_id, :subject, :outcome, :evidence, :sealed_at])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :subject, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :outcome, :atom do
      allow_nil?(false)

      constraints(
        one_of: [:alive, :partial_alive, :blocked, :build_broken, :unsupported, :refused]
      )

      public?(true)
    end

    attribute :evidence, :map do
      allow_nil?(false)
      default(%{})
      public?(true)
    end

    attribute :sealed_at, :utc_datetime_usec do
      allow_nil?(false)
      default(&DateTime.utc_now/0)
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :epoch, Xaas.Ultracode.Epoch do
      allow_nil?(false)
      attribute_writable?(true)
    end
  end
end
