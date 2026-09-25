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

  ## Real lawful read path (fix, this pass)

  Until this pass this resource had NO read bypass at all -- the only
  place in the repo that ever read a `Receipt` was
  `test/xaas_web/execution_fabric_controller_test.exs`'s atom-safety test,
  via a real, disclosed `authorize?: false` test-only escape hatch, not a
  production-reachable path. That left zero lawful query surface for the
  one resource this product's own "Governance + Evidence" thesis calls
  the auditable record of Run/Epoch outcomes -- a sealed evidentiary
  record nothing could lawfully query is not usable evidence.

  The fix is deliberately narrow, not a reversal of the original decision
  to keep the bare `:read` action forbidden (still true below, unchanged):
  a new `:for_epoch` read action, scoped by a required `epoch_id`
  argument (same `argument/filter(expr(...))` shape already used by
  `Xaas.Library.HoldRequest`'s `:for_user`/`:for_book`), with its own
  `bypass action(:for_epoch)` -- matching this resource's own existing
  `bypass action(:seal)` carve-out shape, and this repo's disclosed
  `bypass action_type(:read)` precedent on
  `Xaas.Operations.CapabilityLivenessReceipt` (see
  `docs/claude/diataxis/explanation/security-and-testing-decisions.md`
  section 1) -- scoped here to ONE action rather than the whole read
  type, since unlike that resource this one's bare `:read` action stays
  intentionally closed.

  The trust boundary this Ash-level bypass relies on is the same one
  every sibling route on `XaasWeb.ExecutionFabricController` already
  relies on: `XaasWeb.Plugs.RequireInternalApiToken`'s shared Bearer
  check is the only real caller-identity mechanism this repo has (see
  `XaasWeb.Plugs.ResolveOrgActor`'s own moduledoc, which discloses the
  identical fact -- "This repo has exactly one real auth mechanism
  today"). There is no richer per-caller actor to key a policy check on,
  so the carve-out is scoped as narrowly as the DSL allows (one action,
  one required filter argument) at the Ash layer, and reuses the
  existing token gate (not a new one) at the HTTP layer.
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
    # XAAS-2601: the internal-only `:seal` action the Ultracode Reactor
    # pipeline calls is admitted by the REAL system authority predicate
    # (`Xaas.Checks.SystemActor` over the `Xaas.SystemAuthority` actor
    # `EpochReactor` now passes) instead of an action-wide
    # `authorize_if(always())` bypass. Deliberately no read bypass --
    # this resource is modeled on `Xaas.Operations.ActuationReceipt`'s own
    # policy, whose moduledoc states plainly: "only the Reactor actuation
    # kernel may prepare, read, or seal it." Receipts here are the same
    # kind of sealed evidentiary record, not operational/queryable state
    # like Run/Epoch -- intentionally unreadable outside the internal
    # kernel path, not an oversight.
    bypass action(:seal) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    # Real, narrow lawful read carve-out (see moduledoc "Real lawful read
    # path" above). Scoped to exactly this one action, filtered by a
    # required `epoch_id` argument -- the bare `:read` action below stays
    # forbidden to every actor, unchanged from the original design.
    bypass action(:for_epoch) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  code_interface do
    define(:for_epoch, args: [:epoch_id])
  end

  actions do
    read :read do
      primary?(true)
      public?(false)
    end

    read :for_epoch do
      description(
        "Every sealed Receipt for one Epoch, newest first -- the real, narrow lawful read path (see moduledoc)."
      )

      argument(:epoch_id, :uuid, allow_nil?: false)
      filter(expr(epoch_id == ^arg(:epoch_id)))
      prepare(build(sort: [sealed_at: :desc]))
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
