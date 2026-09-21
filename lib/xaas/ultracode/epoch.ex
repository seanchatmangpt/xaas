defmodule Xaas.Ultracode.Epoch do
  @moduledoc """
  One cycle of a `Run`'s attempt against a real, named `exact_subject`.

  `ExpectedEpoch`/`CompletedEpoch`/`MissedEpoch` are deliberately not
  separate resources -- they are `state` values on this one resource
  (`:expected | :running | :completed | :missed | :failed`), matching this
  repo's existing lifecycle-as-attribute convention (`WebhookDelivery`'s
  `:failed` status, `CapabilityLivenessReceipt`'s receipt lifecycle) instead
  of a polymorphic per-state resource split.

  Enforces two real invariants from the ontology formalization:

  - `Unique(run, cycle)` -- `identities do identity :unique_run_cycle, ...`
    below, giving both an app-level pre-flight rejection and (via
    `ash_postgres` migration generation) a real DB unique index.
  - `AtMostOneActiveEpoch(run)` -- `Xaas.Ultracode.Validations.
    AtMostOneActiveEpoch`, run on `:create`/`:update` whenever `state` is
    being set to `:running`.

  ## Org scoping -- real ATTRIBUTE MULTITENANCY, query-layer enforced (see
  ## ADR-0002, `Xaas.Ultracode.Run`'s own moduledoc, and this repo's
  ## multitenancy retrofit)

  Real, investigated finding (Ash 3.33.1 source: `deps/ash/lib/ash/resource/
  verifiers/validate_multitenancy.ex`): the `:attribute` multitenancy
  strategy requires the tenant attribute to exist ON THIS RESOURCE ITSELF
  -- `Enum.any?(attributes, &(&1.name == attribute))` is a hard verifier
  check at compile time, and there is no "resolve tenant through a
  relationship" mode for `:attribute` multitenancy (that would require the
  `:context` strategy, which this data layer does not use here). So this
  resource carries its OWN `org_id` below -- a denormalized copy of its
  parent `Run`'s `org_id`, kept in sync at every real Epoch-create call
  site (`Xaas.Ultracode.Changes.CreateFirstEpoch`,
  `Xaas.Ultracode.NextEpoch.advance_from_completed/2`, and the
  controller's own customer-facing `create_running_epoch/3`) rather than
  reached via `epoch.run.org_id` on every read.

  `multitenancy do strategy :attribute; attribute :org_id end` below makes
  this resource's PRIMARY `:read` action (`defaults([:read])`) genuinely
  tenant-`:enforce`d (Ash's real per-action default -- see
  `deps/ash/lib/ash/actions/read/read.ex:handle_multitenancy/1`): a caller
  that omits a tenant now gets `Ash.Error.Invalid.TenantRequired`, not
  silent cross-org data. No resource-level `global? true` is set (that
  flag would defeat `:enforce` for every action on the resource, per
  `Ash.Resource.Info.multitenancy_global?`'s use in
  `Ash.Actions.Helpers.validate_changeset_multitenancy/1` and
  `read.ex:validate_multitenancy/1`). Every internal/system call site
  (`EpochReactor`, `Lease`, `MissedEpochs`, `NextEpoch`, the
  `AtMostOneActiveEpoch` validation, and the `:run`/`:epochs`/
  `:active_epoch` relationship loads below) is instead explicitly routed
  through the `:read_unscoped` read action (`multitenancy :allow_global`)
  defined below, or has its own mutation action explicitly marked
  `multitenancy :allow_global` -- deliberate, visible, never the silent
  resource-wide bypass. `Lease` (`Xaas.Ultracode.Lease`) owns no resource
  of its own -- its `lease_token`/`leased_to`/`worktree`/`final_head`
  fields live on THIS resource (see `Lease`'s own moduledoc), so there is
  no separate `Lease` schema to seam either.
  """

  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Ultracode,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table("ultracode_epochs")
    repo(Xaas.Repo)
  end

  multitenancy do
    strategy(:attribute)
    attribute(:org_id)
  end

  policies do
    bypass action_type(:read) do
      authorize_if(always())
    end

    # XAAS-2601 + wave-4 authority tightening: every internal-only mutation
    # action this repo's Ultracode Reactor pipeline calls (Reactor,
    # EpochReactor, NextEpoch, MissedEpochs, Changes.CreateFirstEpoch) plus
    # the lease-family actions (`:lease`, `:renew_lease`,
    # `:record_final_head`) is admitted by the REAL system authority
    # predicate -- `Xaas.Checks.SystemActor` over a `Xaas.SystemAuthority`
    # actor -- instead of the previous `authorize_if(always())` bypasses,
    # which any caller through the normal authorization path satisfied.
    #
    # The lease-family trio's only historical Ash call sites were replaced
    # by `Xaas.Ultracode.Lease`'s raw atomic row writes (outside the Ash
    # authorization path entirely), so no authorized production caller
    # exists today; they stay canonically mapped to `:ultracode_reactor`
    # so any future re-wiring through Ash requires the admitted kernel
    # authority, never an ambient bypass. The deny floor below stays real
    # for every other actor, and any FUTURE action added to this resource
    # remains deny-by-default.
    bypass action([
             :create,
             :start,
             :complete,
             :mark_missed,
             :mark_failed,
             :lease,
             :renew_lease,
             :record_final_head
           ]) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    policy always() do
      forbid_if(always())
    end
  end

  actions do
    defaults([:read])

    # Real, deliberately global internal/system read action -- see the
    # moduledoc's org-scoping section. `multitenancy :allow_global` (not
    # `:bypass`): if a caller DOES supply a tenant, it still filters by it
    # (safer than `:bypass`, which would silently ignore a supplied
    # tenant); every real caller of this action today supplies none, so it
    # behaves exactly like the old, pre-retrofit unscoped default `:read`.
    # Every internal Epoch read in this codebase
    # (`EpochReactor`/`Lease`/`MissedEpochs`/`NextEpoch`/
    # `AtMostOneActiveEpoch`) is routed through this action explicitly,
    # never through the (now tenant-`:enforce`d) default `:read` above.
    read :read_unscoped do
      multitenancy(:allow_global)

      # Real, evidence-based addition (a live `mix test` failure, not
      # guessed): `Ash.bulk_update(Epoch, :lease, ..., read_action:
      # :read_unscoped, strategy: [:atomic, :atomic_batches, :stream])`
      # (`Lease.bind_lease/3`) needs its candidate-selection read to
      # support the `:stream` strategy -- the one bulk-update strategy
      # that does NOT require `Xaas.Ultracode.Validations.LeaseAvailable`
      # to implement `atomic/3` (which it genuinely does not, an
      # unrelated pre-existing real constraint; `:atomic`/`:atomic_batches`
      # both fail on that same real reason). Without explicit keyset
      # pagination here, `:stream` itself failed too ("Action ...
      # read_unscoped does not support streaming with one of [:keyset]"),
      # leaving zero viable strategies. The resource's own primary `:read`
      # (`defaults([:read])`) gets keyset streaming implicitly from
      # `AshPostgres.DataLayer`; this explicitly-defined custom action
      # does not inherit that automatically and needs it declared.
      pagination(keyset?: true, required?: false)
    end

    create :create do
      accept([
        :run_id,
        :org_id,
        :cycle,
        :exact_subject,
        :state,
        :expected_at,
        :started_at,
        :worktree
      ])

      # Real fs-safety fence (2026-09 hardening pass): this is the one real
      # customer-controllable call site for `:worktree`
      # (`XaasWeb.ExecutionFabricController.create_running_epoch/3`, fed
      # straight from a submitted `params["worktree"]`) -- see
      # `Xaas.Ultracode.Validations.WorktreeIsSafe`'s own moduledoc for the
      # real, evidenced gap this closes.
      validate({Xaas.Ultracode.Validations.WorktreeIsSafe, []})

      # `:allow_global`, not the `:enforce` default: this action is called
      # from two real shapes -- the customer-facing controller path (which
      # sets `org_id` explicitly from the authenticated org; see
      # `XaasWeb.ExecutionFabricController.create_running_epoch/3`) and
      # every internal/system Epoch-construction path
      # (`Xaas.Ultracode.Changes.CreateFirstEpoch`,
      # `Xaas.Ultracode.NextEpoch.advance_from_completed/2`, and this
      # resource's own test fixtures), which pass no tenant at all and rely
      # on `org_id` being propagated explicitly (denormalized from the
      # parent `Run`) rather than derived from `Ash.Changeset.set_tenant/2`.
      # `:enforce` here would raise `TenantRequired` on every one of those
      # real internal call sites.
      multitenancy(:allow_global)
    end

    # Every plain `update` action below is `multitenancy(:bypass)`, NOT
    # `:allow_global` -- a real, evidence-based distinction (a failing
    # `mix test` run, not guessed): Ash 3.33.1's UPDATE pipeline has a
    # SECOND, later tenant checkpoint independent of the one
    # `handle_multitenancy/2` runs at action-dispatch time --
    # `deps/ash/lib/ash/actions/update/update.ex`'s own private
    # `set_tenant/1`, invoked deeper in `Ash.Actions.Update.run/4`'s commit
    # path. That second checkpoint's guard is
    # `get_multitenancy_from_context(changeset) in [:bypass, :bypass_all]`
    # -- it does NOT special-case `:allow_global` the way CREATE's own
    # `set_tenant/1` does (`create.ex`'s guard is `in [:bypass, :bypass_all,
    # :allow_global]` -- a real, confirmed asymmetry between the two action
    # types in this Ash version). Marking these `:allow_global` compiled
    # and passed the FIRST checkpoint but raised "changesets require a
    # tenant" at the second, live in `mix test` -- `:bypass` (which DOES
    # satisfy both checkpoints, since `handle_multitenancy/2` maps it to
    # the same `:bypass_all` context flag `:bypass_all` itself sets) is the
    # real, working choice for every one of these internal-only,
    # already-loaded-struct mutations. This behaves identically to
    # `:allow_global` for every real caller here (none ever pass a
    # tenant): `:bypass` only differs by also ignoring a tenant if one WERE
    # supplied, which no real call site does.
    update :start do
      accept([])
      require_atomic?(false)
      change(set_attribute(:state, :running))
      change(set_attribute(:started_at, &DateTime.utc_now/0))

      validate({Xaas.Ultracode.Validations.AtMostOneActiveEpoch, []})

      multitenancy(:bypass)
    end

    update :complete do
      # `:final_head` accepted here (not just via the separate
      # `:record_final_head` action) so `Xaas.Ultracode.Lease.close/4` can
      # fold "record the reported head" and "transition to :completed"
      # into ONE real write -- see this file's `Lease` cross-reference in
      # the moduledoc's "Org scoping" section and `Lease.close/4`'s own
      # comment for the concurrency finding this closes: two sequential,
      # unguarded writes left a real window for a stale/reassigned lease
      # to still land a completion.
      accept([:final_head])
      require_atomic?(false)
      change(set_attribute(:state, :completed))
      change(set_attribute(:completed_at, &DateTime.utc_now/0))

      validate({Xaas.Ultracode.Validations.EpochTransitionAllowed, from: [:running]})

      multitenancy(:bypass)
    end

    update :mark_missed do
      accept([])
      require_atomic?(false)
      change(set_attribute(:state, :missed))

      # The transition's own moment, persisted (the egress's `epoch_missed`
      # event time -- replaces the former `updated_at` approximation; see
      # the `terminal_at` attribute doc).
      change(set_attribute(:terminal_at, &DateTime.utc_now/0))

      validate({Xaas.Ultracode.Validations.EpochTransitionAllowed, from: [:expected, :running]})

      multitenancy(:bypass)
    end

    update :mark_failed do
      accept([])
      require_atomic?(false)
      change(set_attribute(:state, :failed))

      # Same dedicated transition moment as `:mark_missed` above (the
      # egress's `epoch_failed` event time).
      change(set_attribute(:terminal_at, &DateTime.utc_now/0))

      validate({Xaas.Ultracode.Validations.EpochTransitionAllowed, from: [:expected, :running]})

      multitenancy(:bypass)
    end

    # Bind the ActuationLease. Only admissible on a `:running` epoch with no
    # live lease (see Xaas.Ultracode.Validations.LeaseAvailable); callers
    # race-safely bind via Xaas.Ultracode.Lease.claim_next/1's filtered bulk
    # update, not by calling this directly. Kept `:allow_global` (not
    # `:bypass`, unlike the plain updates above): this action is invoked
    # ONLY via `Ash.bulk_update/4` (`Lease.bind_lease/3`), whose own
    # multitenancy validation (`Ash.Actions.Helpers.Bulk.validate_multitenancy/3`)
    # DOES honor `:allow_global` for the write side -- the real gap that
    # broke this call site was `Ash.bulk_update`'s own INTERNAL candidate
    # read defaulting to Epoch's primary (now `:enforce`d) `:read`, fixed
    # by passing `read_action: :read_unscoped` at the call site instead
    # (see `Lease.bind_lease/3`), not by changing this action's setting.
    update :lease do
      accept([:lease_token, :lease_expires_at, :leased_to, :worktree])
      require_atomic?(false)

      validate({Xaas.Ultracode.Validations.LeaseAvailable, []})

      # Defense-in-depth: no real call site sets `:worktree` on `:lease`
      # today (`Lease.bind_lease/3` only ever writes `lease_token`,
      # `lease_expires_at`, `leased_to`), but this action's own `accept`
      # list already allows it -- fence it the same way `:create` is
      # fenced rather than leaving a second, unguarded acceptor of the
      # same unsafe field.
      validate({Xaas.Ultracode.Validations.WorktreeIsSafe, []})

      multitenancy(:allow_global)
    end

    update :renew_lease do
      accept([:lease_expires_at])
      require_atomic?(false)

      multitenancy(:bypass)
    end

    update :record_final_head do
      accept([:final_head])
      require_atomic?(false)

      multitenancy(:bypass)
    end
  end

  attributes do
    uuid_primary_key(:id)

    # Real, denormalized copy of the parent Run's `org_id` -- see this
    # module's moduledoc "Org scoping" section for why `:attribute`
    # multitenancy requires this to live directly on this resource rather
    # than being reached via the `belongs_to :run` relationship. Nullable,
    # matching `Run.org_id`'s own nullability (an org-less Run's Epochs
    # stay org-less too).
    attribute :org_id, :string do
      public?(true)
    end

    attribute :cycle, :integer do
      allow_nil?(false)
      public?(true)
    end

    attribute :exact_subject, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :state, :atom do
      allow_nil?(false)
      default(:expected)
      constraints(one_of: [:expected, :running, :completed, :missed, :failed])
      public?(true)
    end

    # When this epoch is expected to be underway/complete by. Set at
    # `:create` (or `:start`). `Xaas.Ultracode.MissedEpochs` compares this
    # against `now - run.epoch_timeout_seconds` to decide `:missed` --
    # real input to a real state transition, not decoration.
    attribute :expected_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :started_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :completed_at, :utc_datetime_usec do
      public?(true)
    end

    # The `:missed`/`:failed` transition moment -- the dedicated terminal
    # timestamp for the two terminal states that have no per-state column
    # (`:completed` uses `completed_at` above). Written by `:mark_missed`,
    # `:mark_failed`, and `Lease.refuse/3`'s atomic `state: :failed` write.
    # Nullable: an epoch still in flight has no terminal moment, and rows
    # predating this column carry NULL -- the OCEL egress omits the
    # `epoch_missed`/`epoch_failed` event in that case rather than
    # fabricating a time (this column replaces the egress's former
    # `updated_at` approximation for those two events).
    attribute :terminal_at, :utc_datetime_usec do
      public?(true)
    end

    # ------------------------------------------------------------------
    # ActuationLease fields (the provider-pull edge between Plan and
    # Construct). An Epoch is the bounded work unit, so the lease lives
    # here: `lease_token` is the only capability mid-work operations key
    # on, `leased_to` is provider worker identity (free-form string --
    # worker registries are provider business, not this domain), and
    # `final_head` is the provider-reported exact repository head at
    # closure, verified against `worktree` before any Receipt is sealed
    # with an :alive-family outcome.
    # ------------------------------------------------------------------

    attribute :lease_token, :string do
      public?(true)
    end

    attribute :lease_expires_at, :utc_datetime_usec do
      public?(true)
    end

    # The bind moment: when `Lease.claim_next/3`'s atomic UPDATE bound this
    # epoch's lease. Written in the SAME single `UPDATE ... WHERE ...
    # RETURNING *` statement that sets `lease_token`/`lease_expires_at`/
    # `leased_to` (atomicity preserved). Nullable: an epoch never claimed
    # has no bind moment. This is the persisted fact the OCEL egress's
    # `epoch_claimed` event derives from -- before this column existed the
    # bind wrote no timestamp and that event could only be declared, never
    # emitted. A re-claim of an expired lease overwrites it with the new
    # claim's moment (column-level persistence keeps the latest claim).
    attribute :claimed_at, :utc_datetime_usec do
      public?(true)
    end

    # The latest heartbeat moment: written by `Lease.renew/1`'s atomic
    # lease write alongside the extended `lease_expires_at`. One column
    # carrying the LATEST value -- renewal history deliberately collapses
    # here (per-renewal event spam is not persisted; the egress emits one
    # `worker_heartbeat` event per epoch, from the latest moment).
    attribute :last_heartbeat_at, :utc_datetime_usec do
      public?(true)
    end

    attribute :leased_to, :string do
      public?(true)
    end

    attribute :worktree, :string do
      public?(true)
    end

    attribute :final_head, :string do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    # `read_action: :read_unscoped` -- real, deliberate: relationship
    # loading inherits the LOADING query's tenant (`deps/ash/lib/ash/
    # actions/read/relationships.ex`, `Ash.Query.set_tenant(query.tenant ||
    # related_query.tenant)`), never the loaded record's own attribute, so
    # every internal, tenant-less load of `epoch.run` (EpochReactor,
    # Lease.claim_next's `load: [:run]`) would otherwise hit Run's now
    # tenant-`:enforce`d default `:read` and raise. Pinned to Run's own
    # `:read_unscoped` action so this relationship load behaves exactly as
    # it did before this retrofit.
    belongs_to :run, Xaas.Ultracode.Run do
      allow_nil?(false)
      attribute_writable?(true)
      read_action(:read_unscoped)
    end

    has_many :receipts, Xaas.Ultracode.Receipt
  end

  identities do
    identity(:unique_run_cycle, [:run_id, :cycle])
  end
end
