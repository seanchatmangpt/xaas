defmodule Xaas.Platform.RouteProjects do
  use Xaas.Resource,
    otp_app: :xaas,
    domain: Xaas.Platform,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  policies do
    # ash-migration Phase 5 (deny-by-default floor): real, confirmed gap --
    # this resource had zero policy blocks before this commit, meaning
    # implicit allow-all authorization on a repo with real deployed infra.
    # Replace with real per-action rules as domain owners define them; never
    # relax this to allow-all without an explicit rule.
    bypass action_type(:read) do
      authorize_if(always())
    end

    # W792: real maker-checker approve surface -- internal_api
    # system-authority gate (matching the flags/secrets mutation gate),
    # plus the RouteProjectsRequiresApprover validation on the action
    # itself (approved_by present and distinct from requested_by).
    # W969c / SPEC-21: rows can now be minted through the resource's own
    # real `:create` (previously create-less: rows could only exist via
    # storage-layer insert_all).
    bypass action(:approve) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    bypass action(:create) do
      authorize_if({Xaas.Checks.SystemActor, []})
    end

    policy always() do
      forbid_if(always())
    end
  end

  json_api do
    type("route_projects")

    routes do
      base("/route_projects")
      get(:read)
      index(:read)
      patch(:approve)
    end
  end

  postgres do
    table("route_projects")
    repo(Xaas.Repo)
  end

  actions do
    defaults([:read])

    # W969c / SPEC-21 (W770-GAP-3): the create half of the maker-checker
    # pair. Before this action the columns existed but could never be
    # produced through the resource (`approved_by` metadata dead-ended at
    # the W792 :approve operating only on storage-inserted rows). Policy
    # gate matches the flags/secrets mutation gate (SystemActor).
    create :create do
      accept([:requested_by])
    end

    # W792: real maker-checker approve action -- a second, distinct actor
    # (named by `approved_by`, refused when equal to `requested_by` by the
    # validation) signs the project row. Previously the *RequiresApprover
    # validation / *Approve change shims were wired to no action anywhere
    # and the resource was write-dead. W969c / SPEC-21 adds the `:create`
    # half so `requested_by` can now be lawfully produced too.
    update :approve do
      accept([:approved_by])
      require_atomic?(false)
      validate(Xaas.Platform.Validations.RouteProjectsRequiresApprover)
      change(Xaas.Platform.Changes.RouteProjectsApprove)
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :requested_by, :string do
      allow_nil?(false)
    end

    attribute(:approved_by, :string)
  end
end
