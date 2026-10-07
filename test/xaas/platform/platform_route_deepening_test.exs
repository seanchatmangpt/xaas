defmodule Xaas.Platform.PlatformRouteDeepeningTest do
  @moduledoc """
  Lane W770 deepening coverage for the `Xaas.Platform` route/approval
  resources BEYOND the webhook pair (which W725's
  `Xaas.Platform.WebhookDeepeningTest` already courts): RouteFeatureFlags,
  RouteSecrets, RouteOrgsCustomDomain, RouteProjectsBackups, RouteProjects.

  Chicago-style: real Ash actions against real sandboxed Postgres
  (`Ecto.Adapters.SQL.Sandbox`), real policy evaluation with
  `authorize?: true`, real row state asserted after every transition. No
  mocks, no fakes of owned code.

  Contracts are read from the source (not assumed):

  - RouteFeatureFlags / RouteSecrets mutations are gated by
    `Xaas.Checks.SystemActor` exact-subject mapping to `:internal_api`
    (XAAS-2602) -- a wrong-service system authority is refused, not just a
    non-system actor.
  - RouteOrgsCustomDomain / RouteProjectsBackups mutations are gated by
    `Xaas.Platform.Checks.ActorOrgMatches` (actor's `org_id` must equal the
    record's own `org_id`); RouteOrgsCustomDomain additionally enforces the
    RFC 1123 hostname shape rule on `:create` and the
    active-requires-certificate-secret rule on `:update`.
  - RouteProjects gained a real `:create` in W969c / SPEC-21 (W770-GAP-3),
    so `requested_by` rows are now mintable through the resource (W792
    added the real `:approve` half of the maker-checker pair).

  Approval wiring corrected in W792 (asserted, not assumed):

  - RouteFeatureFlags / RouteSecrets / RouteProjects now have a real
    `:approve` update action wired to the paired
    `Xaas.Platform.Validations.*RequiresApprover` (enforces: approved_by
    present, non-blank, and distinct from requested_by) and
    `Xaas.Platform.Changes.*Approve` change, gated by
    `Xaas.Checks.SystemActor` (:internal_api) -- replacing W770's disclosed
    vacuous shims.
  - the RouteProjectsBackups and RouteOrgsCustomDomain
    `*RequiresApprover`/`*Approve` pairs are DELETED with typed rationale:
    their resources/tables carry no approver metadata columns at all
    (backups: org/backup lifecycle fields only; domain: org/hostname/cert
    fields only), so there is no action surface the approval half could
    truthfully wire to, and a migration is out of lane scope.
  - RouteProjectsBackups still has no `:update`/`:destroy` action: a backup row's
    `status` starts `:pending` and nothing in this domain can ever
    transition it (the moduledoc's own disclosed non-ported reconciliation
    loop), and there is no pruning/retention sweep.
  """
  use ExUnit.Case, async: true

  import Plug.Conn, only: [put_req_header: 3]

  require Ash.Query

  alias Xaas.Platform.RouteFeatureFlags
  alias Xaas.Platform.RouteOrgsCustomDomain
  alias Xaas.Platform.RouteProjects
  alias Xaas.Platform.RouteProjectsBackups
  alias Xaas.Platform.RouteSecrets

  @internal_api Xaas.SystemAuthority.new(:internal_api)
  @oban_scheduler Xaas.SystemAuthority.new(:oban_scheduler)

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_actor(slug), do: %{org_id: slug}

  defp uniq(suffix), do: "w770-#{suffix}-#{System.unique_integer([:positive])}"

  defp authorized_create!(resource, action, attrs, actor) do
    resource
    |> Ash.Changeset.for_create(action, attrs, actor: actor, authorize?: true)
    |> Ash.create!()
  end

  # ------------------------------------------------------------------
  # (1) RouteFeatureFlags -- :internal_api-gated lifecycle
  # ------------------------------------------------------------------

  test "(1a) create as internal_api persists a real row with the documented defaults" do
    flag =
      authorized_create!(RouteFeatureFlags, :create, %{
        flag_key: uniq("flag"),
        enabled: true,
        requested_by: "w770-operator"
      }, @internal_api)

    assert %RouteFeatureFlags{} = flag
    assert flag.enabled == true
    assert flag.requested_by == "w770-operator"
    assert flag.required_tier == "starter"
    assert is_nil(flag.approved_by)

    # real persisted row, re-read from Postgres
    assert %RouteFeatureFlags{} = Ash.get!(RouteFeatureFlags, flag.id, authorize?: false)
  end

  test "(1b) non-system actor and wrong-service system actor are both refused on :create and :update (typed refusals)" do
    key = uniq("gate")

    assert_raise Ash.Error.Forbidden, fn ->
      authorized_create!(RouteFeatureFlags, :create, %{flag_key: key, requested_by: "x"},
        org_actor("some-org"))
    end

    assert_raise Ash.Error.Forbidden, fn ->
      authorized_create!(RouteFeatureFlags, :create, %{flag_key: key, requested_by: "x"},
        @oban_scheduler)
    end

    flag =
      authorized_create!(RouteFeatureFlags, :create, %{flag_key: key, requested_by: "w770"},
        @internal_api)

    assert_raise Ash.Error.Forbidden, fn ->
      flag
      |> Ash.Changeset.for_update(:update, %{enabled: false},
        actor: @oban_scheduler,
        authorize?: true
      )
      |> Ash.update!()
    end

    updated =
      flag
      |> Ash.Changeset.for_update(:update, %{enabled: false},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()

    assert updated.enabled == false

    # real row state on disk moved
    reloaded = Ash.get!(RouteFeatureFlags, flag.id, authorize?: false)
    assert reloaded.enabled == false
  end

  test "(1c) determinism: identical create input yields independent rows with identical field state" do
    attrs = %{flag_key: uniq("det"), enabled: false, requested_by: "w770-det"}

    a = authorized_create!(RouteFeatureFlags, :create, attrs, @internal_api)
    b = authorized_create!(RouteFeatureFlags, :create, attrs, @internal_api)

    assert a.id != b.id
    assert a.flag_key == b.flag_key
    assert a.enabled == b.enabled
    assert a.required_tier == b.required_tier
    assert a.approved_by == b.approved_by
  end

  # ------------------------------------------------------------------
  # (2) RouteSecrets -- :internal_api-gated create + destroy lifecycle
  # ------------------------------------------------------------------

  test "(2a) full create -> destroy lifecycle as internal_api; row really gone after destroy" do
    secret =
      authorized_create!(RouteSecrets, :create, %{
        namespace: "w770-ns",
        name: uniq("secret"),
        requested_by: "w770-operator"
      }, @internal_api)

    assert %RouteSecrets{} = secret
    assert is_nil(secret.approved_by)

    assert %RouteSecrets{} = Ash.get!(RouteSecrets, secret.id, authorize?: false)

    :ok = secret |> Ash.Changeset.for_destroy(:destroy, %{}, actor: @internal_api, authorize?: true) |> Ash.destroy!()

    assert nil ==
             RouteSecrets
             |> Ash.Query.filter(id: secret.id)
             |> Ash.read_one!(authorize?: false)
  end

  test "(2b) refusals: non-system actor on :create, wrong-service actor on :destroy" do
    assert_raise Ash.Error.Forbidden, fn ->
      authorized_create!(RouteSecrets, :create, %{
        namespace: "ns",
        name: uniq("nope"),
        requested_by: "x"
      }, org_actor("some-org"))
    end

    secret =
      authorized_create!(RouteSecrets, :create, %{
        namespace: "ns",
        name: uniq("del"),
        requested_by: "w770"
      }, @internal_api)

    assert_raise Ash.Error.Forbidden, fn ->
      secret
      |> Ash.Changeset.for_destroy(:destroy, %{}, actor: org_actor("some-org"), authorize?: true)
      |> Ash.destroy!()
    end

    # row still there after both refusals
    assert %RouteSecrets{} = Ash.get!(RouteSecrets, secret.id, authorize?: false)
  end

  # ------------------------------------------------------------------
  # (3) RouteOrgsCustomDomain -- org-matched lifecycle + validations
  # ------------------------------------------------------------------

  test "(3a) create as matching-org actor persists a 'pending' binding; invalid hostname is a typed refusal" do
    slug = "w770-dom-#{System.unique_integer([:positive])}"
    attrs = %{org_id: slug, hostname: "console.#{slug}.com"}

    row =
      attrs
      |> then(&authorized_create!(RouteOrgsCustomDomain, :create, &1, org_actor(slug)))

    assert row.status == "pending"
    assert row.hostname == "console.#{slug}.com"
    assert is_nil(row.certificate_secret_name)

    # real row state
    assert %RouteOrgsCustomDomain{} = Ash.get!(RouteOrgsCustomDomain, row.id, authorize?: false)

    # hostname shape: single label is refused
    assert_raise Ash.Error.Invalid, fn ->
      authorized_create!(RouteOrgsCustomDomain, :create, %{org_id: slug, hostname: "barehost"},
        org_actor(slug))
    end

    # underscore label is refused
    assert_raise Ash.Error.Invalid, fn ->
      authorized_create!(RouteOrgsCustomDomain, :create,
        %{org_id: slug, hostname: "my_host.example.com"}, org_actor(slug))
    end

    # underscore-bearing binding was NOT persisted
    count =
      RouteOrgsCustomDomain
      |> Ash.Query.filter(org_id == ^slug)
      |> Ash.count!(authorize?: false)

    assert count == 1
  end

  test "(3b) cross-org create is refused by ActorOrgMatches (typed refusal, no row)" do
    slug = "w770-victim-#{System.unique_integer([:positive])}"

    assert_raise Ash.Error.Forbidden, fn ->
      authorized_create!(RouteOrgsCustomDomain, :create,
        %{org_id: slug, hostname: "console.#{slug}.com"},
        org_actor("attacker-org-#{System.unique_integer([:positive])}"))
    end

    assert 0 ==
             RouteOrgsCustomDomain
             |> Ash.Query.filter(org_id == ^slug)
             |> Ash.count!(authorize?: false)
  end

  test "(3c) update: 'active' without certificate_secret_name is refused and leaves the row unchanged; with the secret name it transitions for the matching org" do
    slug = "w770-act-#{System.unique_integer([:positive])}"

    row =
      authorized_create!(RouteOrgsCustomDomain, :create,
        %{org_id: slug, hostname: "console.#{slug}.com"},
        org_actor(slug))

    # typed refusal: active-without-secret
    assert_raise Ash.Error.Invalid, fn ->
      row
      |> Ash.Changeset.for_update(:update, %{status: "active"},
        actor: org_actor(slug),
        authorize?: true
      )
      |> Ash.update!()
    end

    reloaded = Ash.get!(RouteOrgsCustomDomain, row.id, authorize?: false)
    assert reloaded.status == "pending"

    # valid transition for the matching org
    activated =
      row
      |> Ash.Changeset.for_update(:update,
        %{status: "active", certificate_secret_name: "cert-#{slug}"},
        actor: org_actor(slug),
        authorize?: true
      )
      |> Ash.update!()

    assert activated.status == "active"
    assert activated.certificate_secret_name == "cert-#{slug}"

    # cross-org update of the SAME record: refused, state unchanged
    assert_raise Ash.Error.Forbidden, fn ->
      reloaded
      |> Ash.Changeset.for_update(:update, %{status: "failed"},
        actor: org_actor("other-org-#{System.unique_integer([:positive])}"),
        authorize?: true
      )
      |> Ash.update!()
    end

    assert %RouteOrgsCustomDomain{status: "active"} =
             Ash.get!(RouteOrgsCustomDomain, row.id, authorize?: false)
  end

  # ------------------------------------------------------------------
  # (4) RouteProjectsBackups -- org-matched create; no transition exists
  # ------------------------------------------------------------------

  test "(4a) create as matching-org actor persists a :pending backup row; blank project_name is a typed refusal" do
    slug = "w770-bak-#{System.unique_integer([:positive])}"
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    row =
      authorized_create!(RouteProjectsBackups, :create, %{
        org_id: slug,
        namespace: "ns-#{slug}",
        project_name: "proj-#{slug}",
        job_name: "job-#{slug}",
        taken_at: now,
        size_bytes: 0,
        retain_until: DateTime.add(now, 7 * 24 * 3600, :second)
      }, org_actor(slug))

    assert %RouteProjectsBackups{} = row
    assert row.status == :pending
    assert row.size_bytes == 0

    # blank project_name: real 400-shape refusal
    assert_raise Ash.Error.Invalid, fn ->
      authorized_create!(RouteProjectsBackups, :create,
        %{
          org_id: slug,
          namespace: "ns",
          project_name: "   ",
          job_name: "job",
          taken_at: now,
          size_bytes: 0,
          retain_until: now
        },
        org_actor(slug))
    end

    # cross-org create refused, no row
    assert_raise Ash.Error.Forbidden, fn ->
      authorized_create!(RouteProjectsBackups, :create,
        %{
          org_id: slug,
          namespace: "ns",
          project_name: "hijack",
          job_name: "job",
          taken_at: now,
          size_bytes: 0,
          retain_until: now
        },
        org_actor("attacker-#{System.unique_integer([:positive])}"))
    end

    assert 1 ==
             RouteProjectsBackups
             |> Ash.Query.filter(org_id == ^slug)
             |> Ash.count!(authorize?: false)
  end

  test "(4b) typed gap: no :update/:destroy action exists, so a :pending backup can never be transitioned or pruned through this resource" do
    slug = "w770-stuck-#{System.unique_integer([:positive])}"
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    row =
      authorized_create!(RouteProjectsBackups, :create, %{
        org_id: slug,
        namespace: "ns",
        project_name: "p",
        job_name: "j",
        taken_at: now,
        size_bytes: 0,
        retain_until: now
      }, org_actor(slug))

    action_names = Enum.map(Ash.Resource.Info.actions(RouteProjectsBackups), & &1.name)

    refute :update in action_names
    refute :destroy in action_names

    # and a real update attempt through the API surface is a typed refusal
    assert_raise ArgumentError, fn ->
      row
      |> Ash.Changeset.for_update(:update, %{}, actor: org_actor(slug), authorize?: true)
      |> Ash.update!()
    end

    # real row state: still :pending after the refused transition
    assert %RouteProjectsBackups{status: :pending} =
             Ash.get!(RouteProjectsBackups, row.id, authorize?: false)
  end

  test "(4c) W970b/W770 retention sweep: purge_expired refuses before retain_until, purges after it (row really gone), cross-org refused" do
    slug = "w970b-purge-#{System.unique_integer([:positive])}"
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    row =
      authorized_create!(RouteProjectsBackups, :create, %{
        org_id: slug,
        namespace: "ns",
        project_name: "p",
        job_name: "j",
        taken_at: now,
        size_bytes: 0,
        retain_until: now
      }, org_actor(slug))

    # (i) a row whose retain_until is in the future: typed refusal, row
    # survives on disk
    future_row =
      authorized_create!(RouteProjectsBackups, :create, %{
        org_id: slug,
        namespace: "ns",
        project_name: "p2",
        job_name: "j2",
        taken_at: now,
        size_bytes: 0,
        retain_until: DateTime.add(now, 7 * 24 * 3600, :second)
      }, org_actor(slug))

    assert_raise Ash.Error.Invalid, fn ->
      future_row
      |> Ash.Changeset.for_destroy(:purge_expired, %{},
        actor: org_actor(slug),
        authorize?: true
      )
      |> Ash.destroy!()
    end

    assert %RouteProjectsBackups{} = Ash.get!(RouteProjectsBackups, future_row.id,
             authorize?: false
           )

    # (ii) cross-org purge refused by ActorOrgMatches (typed Forbidden)
    assert_raise Ash.Error.Forbidden, fn ->
      row
      |> Ash.Changeset.for_destroy(:purge_expired, %{},
        actor: org_actor("attacker-#{System.unique_integer([:positive])}"),
        authorize?: true
      )
      |> Ash.destroy!()
    end

    assert %RouteProjectsBackups{} = Ash.get!(RouteProjectsBackups, row.id, authorize?: false)

    # (iii) after retain_until passes: the real prune succeeds and the row
    # is really gone from disk
    assert :ok =
             row
             |> Ash.Changeset.for_destroy(:purge_expired, %{},
               actor: org_actor(slug),
               authorize?: true
             )
             |> Ash.destroy()

    assert nil == Ash.get(RouteProjectsBackups, row.id, authorize?: false)
  end

  # ------------------------------------------------------------------
  # (5) RouteProjects -- read-only by construction
  # ------------------------------------------------------------------

  test "(5) RouteProjects :create exists (W969c / SPEC-21) alongside :approve" do
    action_names = Enum.map(Ash.Resource.Info.actions(RouteProjects), & &1.name)
    assert action_names -- [:read, :approve, :create] == []
    assert :read in action_names
    assert :approve in action_names
    assert :create in action_names

    # The old pin (create attempt raises ArgumentError) flips here: the
    # create half of the maker-checker pair is real, so a real create
    # through the resource must persist a row.
    row =
      RouteProjects
      |> Ash.Changeset.for_create(:create, %{requested_by: "w969c"},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.create!()

    assert %RouteProjects{requested_by: "w969c", approved_by: nil} =
             Ash.get!(RouteProjects, row.id, authorize?: false)
  end

  # ------------------------------------------------------------------
  # (6) Approve half is executably wired (W792): maker-checker enforced,
  # SystemActor-gated, real row state moved
  # ------------------------------------------------------------------

  test "(6a) RouteFeatureFlags :approve enforces maker-checker (typed refusals; distinct approver persists)" do
    key = uniq("approve")

    flag =
      authorized_create!(RouteFeatureFlags, :create, %{flag_key: key, requested_by: "maker-1"},
        @internal_api)

    # missing approved_by: typed refusal
    assert_raise Ash.Error.Invalid, fn ->
      flag
      |> Ash.Changeset.for_update(:approve, %{}, actor: @internal_api, authorize?: true)
      |> Ash.update!()
    end

    # blank approved_by: typed refusal
    assert_raise Ash.Error.Invalid, fn ->
      flag
      |> Ash.Changeset.for_update(:approve, %{approved_by: "   "},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()
    end

    # self-approval refused
    assert_raise Ash.Error.Invalid, fn ->
      flag
      |> Ash.Changeset.for_update(:approve, %{approved_by: "maker-1"},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()
    end

    # wrong-service system actor refused on :approve (policy gate)
    assert_raise Ash.Error.Forbidden, fn ->
      flag
      |> Ash.Changeset.for_update(:approve, %{approved_by: "checker-1"},
        actor: @oban_scheduler,
        authorize?: true
      )
      |> Ash.update!()
    end

    # valid: distinct approver, real row state on disk
    approved =
      flag
      |> Ash.Changeset.for_update(:approve, %{approved_by: "checker-1"},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()

    assert approved.approved_by == "checker-1"

    assert %RouteFeatureFlags{approved_by: "checker-1"} =
             Ash.get!(RouteFeatureFlags, flag.id, authorize?: false)
  end

  test "(6b) RouteSecrets :approve enforces maker-checker (typed refusals; distinct approver persists)" do
    name = uniq("approve")

    secret =
      authorized_create!(RouteSecrets, :create, %{
        namespace: "w792-ns",
        name: name,
        requested_by: "maker-2"
      }, @internal_api)

    assert_raise Ash.Error.Invalid, fn ->
      secret
      |> Ash.Changeset.for_update(:approve, %{}, actor: @internal_api, authorize?: true)
      |> Ash.update!()
    end

    assert_raise Ash.Error.Invalid, fn ->
      secret
      |> Ash.Changeset.for_update(:approve, %{approved_by: "maker-2"},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()
    end

    approved =
      secret
      |> Ash.Changeset.for_update(:approve, %{approved_by: "checker-2"},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()

    assert approved.approved_by == "checker-2"

    assert %RouteSecrets{approved_by: "checker-2"} =
             Ash.get!(RouteSecrets, secret.id, authorize?: false)
  end

  test "(6c) RouteProjects :approve on an existing row enforces maker-checker; non-system actor refused" do
    # row still inserted at the storage layer here to keep the original
    # W792 block's real-row construction unchanged (W969c / SPEC-21 added
    # a real `:create`; that half is courted in test (5) and
    # route_projects_create_court_test.exs). Raw insert with RETURNING
    # because the table's uuid has a DB-side default and Postgrex needs
    # the binary form.
    import Ecto.Query

    {1, _} =
      Xaas.Repo.insert_all("route_projects", [
        %{requested_by: "w792-maker-3", approved_by: nil}
      ])

    %{id: id} =
      Xaas.Repo.one!(
        from(p in "route_projects",
          where: p.requested_by == ^"w792-maker-3",
          select: %{id: p.id}
        )
      )

    row = Ash.get!(RouteProjects, id, authorize?: false)
    assert row.approved_by == nil

    assert_raise Ash.Error.Invalid, fn ->
      row
      |> Ash.Changeset.for_update(:approve, %{approved_by: "w792-maker-3"},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()
    end

    assert_raise Ash.Error.Forbidden, fn ->
      row
      |> Ash.Changeset.for_update(:approve, %{approved_by: "checker-3"},
        actor: org_actor("some-org"),
        authorize?: true
      )
      |> Ash.update!()
    end

    approved =
      row
      |> Ash.Changeset.for_update(:approve, %{approved_by: "checker-3"},
        actor: @internal_api,
        authorize?: true
      )
      |> Ash.update!()

    assert approved.approved_by == "checker-3"

    assert %RouteProjects{approved_by: "checker-3"} =
             Ash.get!(RouteProjects, id, authorize?: false)
  end

  test "(6d) typed deletion: the backups/domain approval pairs are gone; no :approve action exists on their resources" do
    refute Code.ensure_loaded?(Xaas.Platform.Validations.RouteProjectsBackupsRequiresApprover)
    refute Code.ensure_loaded?(Xaas.Platform.Changes.RouteProjectsBackupsApprove)
    refute Code.ensure_loaded?(Xaas.Platform.Validations.RouteOrgsCustomDomainRequiresApprover)
    refute Code.ensure_loaded?(Xaas.Platform.Changes.RouteOrgsCustomDomainApprove)

    for resource <- [RouteProjectsBackups, RouteOrgsCustomDomain] do
      action_names = Enum.map(Ash.Resource.Info.actions(resource), & &1.name)
      refute :approve in action_names
    end
  end

  # ------------------------------------------------------------------
  # (7) Reads are universally open (bypass action_type(:read))
  # ------------------------------------------------------------------

  test "(7) reads are open to any actor, including no actor, across all five route resources" do
    slug = "w770-read-#{System.unique_integer([:positive])}"
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    authorized_create!(RouteProjectsBackups, :create, %{
      org_id: slug,
      namespace: "ns",
      project_name: "p",
      job_name: "j",
      taken_at: now,
      size_bytes: 0,
      retain_until: now
    }, org_actor(slug))

    authorized_create!(RouteOrgsCustomDomain, :create, %{org_id: slug, hostname: "a.#{slug}.com"},
      org_actor(slug))

    authorized_create!(RouteFeatureFlags, :create, %{flag_key: uniq("r"), requested_by: "x"},
      @internal_api)

    for resource <- [RouteFeatureFlags, RouteSecrets, RouteOrgsCustomDomain, RouteProjectsBackups, RouteProjects] do
      rows = Ash.read!(resource, actor: nil, authorize?: true)
      assert is_list(rows)
    end
  end

  test "(8) secret-adjacent determinism: two identical backup creates under one org produce independent identical-shape rows" do
    slug = "w770-det2-#{System.unique_integer([:positive])}"
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    attrs = %{
      org_id: slug,
      namespace: "ns",
      project_name: "p",
      job_name: "j",
      taken_at: now,
      size_bytes: 0,
      retain_until: now
    }

    a = authorized_create!(RouteProjectsBackups, :create, attrs, org_actor(slug))
    b = authorized_create!(RouteProjectsBackups, :create, attrs, org_actor(slug))

    assert a.id != b.id
    assert {a.status, b.status} == {:pending, :pending}
    assert {a.size_bytes, b.size_bytes} == {0, 0}
    assert {a.taken_at, b.taken_at} == {now, now}
  end

  # ------------------------------------------------------------------
  # (9) W808: :approve has a real, non-colliding HTTP surface
  # ------------------------------------------------------------------

  # The route registration itself is load-bearing: this is the exact
  # assertion that fails if the `patch(:approve, route: ":id/approve")`
  # line is removed from lib/xaas/platform/route_feature_flags.ex again
  # (mutation target).
  test "(9a) the :approve route is registered as a distinct json-api patch route" do
    routes = AshJsonApi.Resource.Info.routes(RouteFeatureFlags)

    approve_routes =
      Enum.filter(routes, fn r -> r.action == :approve and r.method == :patch end)

    assert [_] = approve_routes
    assert hd(approve_routes).route == "/route_feature_flags/:id/approve"

    # and it does not collide with the default :update patch route path
    update_routes = Enum.filter(routes, fn r -> r.action == :update end)
    assert [_] = update_routes
    assert hd(update_routes).route == "/route_feature_flags/:id"
  end

  test "(9b) approve over the real HTTP surface: SystemActor-gated request moves real row state" do
    # Raw conn pipeline (no ConnCase here: this suite is `use ExUnit.Case`);
    # real endpoint dispatch is exercised in
    # test/xaas_web/controllers/route_feature_flags_controller_test.exs --
    # this court adds the route-level guard here so the deepening suite
    # alone catches a route removal.
    key = uniq("http-approve")

    flag =
      authorized_create!(RouteFeatureFlags, :create, %{flag_key: key, requested_by: "maker-9"},
        @internal_api)

    # document-shape sanity: the approve route accepts the same
    # vnd.api+json patch document the controller test uses, dispatched
    # through the real Phoenix endpoint.
    body = %{
      "data" => %{
        "type" => "route_feature_flags",
        "id" => flag.id,
        "attributes" => %{"approved_by" => "checker-9"}
      }
    }

    conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> Phoenix.ConnTest.dispatch(XaasWeb.Endpoint, :patch,
           "/api/route_feature_flags/#{flag.id}/approve",
           body
         )

    assert %Plug.Conn{status: 200, resp_body: resp_body} = conn

    assert %{"data" => %{"attributes" => %{"approved_by" => "checker-9"}}} =
             Jason.decode!(resp_body)

    # real row state on disk moved
    assert %RouteFeatureFlags{approved_by: "checker-9"} =
             Ash.get!(RouteFeatureFlags, flag.id, authorize?: false)

    # HTTP gate is real: without the internal token the request is refused
    # before any Ash policy runs
    refused_conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> Phoenix.ConnTest.dispatch(XaasWeb.Endpoint, :patch,
           "/api/route_feature_flags/#{flag.id}/approve",
           body
         )

    assert refused_conn.status == 401

    assert %RouteFeatureFlags{approved_by: "checker-9"} =
             Ash.get!(RouteFeatureFlags, flag.id, authorize?: false)
  end
end
