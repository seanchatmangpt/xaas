defmodule Xaas.SystemAuthorityFollowupChicagoTest do
  @moduledoc """
  Chicago-school proof closing XAAS-2602 (docs/jira/v26.9.15): the same
  review falsifier XAAS-2601 proved for the Ultracode/WebhookDelivery/
  HoldRequest cluster, extended to every SERVICE-BOUNDARY and INTERNAL-ONLY
  mutation this pass converted from `authorize_if(always())` to the real
  system-authority predicate `Xaas.Checks.SystemActor`.

  Invoke each converted action as an ordinary non-system actor through real
  Ash authorization -- it must be REFUSED, where the previous bare
  `bypass ... authorize_if(always())` authorized any caller at all. The
  real system authority actor (`Xaas.SystemAuthority.new(:internal_api)` --
  exactly what `XaasWeb.Plugs.SetInternalApiSystemActor` supplies after the
  RequireInternalApiToken Bearer check) is admitted.

  Everything real: real Postgres via `Ecto.Adapters.SQL.Sandbox` over
  `Xaas.Repo`, real Ash resources, the real `Ash.Policy.Authorizer`
  calculus, and a real fabricated ORDINARY actor
  (`%{id: ..., org_id: ..., role: ...}` -- the map shape every other
  actor-check in this repo consumes). No mocks.

  The converted resources are represented per domain (Platform, Governance,
  Billing, Operations) plus the two INTERNAL-ONLY clusters (the autofde
  planner `request_*` creates, the AshOban `:check_regressions` schedule);
  the remaining ~20 sibling Governance maker-checker resources share the
  exact same converted policy shape (verified by the mechanical conversion
  and the existing controller-test suite, which exercises every one of
  their real HTTP routes through the new plug).
  """

  use ExUnit.Case, async: true

  alias Xaas.Billing.ApprovalPricingOverride
  alias Xaas.Billing.ApprovalQuotaOverride
  alias Xaas.Governance.ApprovalOrgDelete
  alias Xaas.Governance.FreezeWindow
  alias Xaas.Operations.ApprovalK8sFaultRemediateSuggest
  alias Xaas.Operations.AutofdePlannerMatch
  alias Xaas.Operations.CapabilityLivenessReceipt
  alias Xaas.Platform.RouteFeatureFlags
  alias Xaas.Platform.RouteSecrets

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # An ORDINARY actor: a plausible, well-formed caller identity carrying
  # exactly the fields this repo's real actor checks read -- and none of
  # them is a system authority. Same falsifier actor as XAAS-2601's suite.
  @ordinary_actor %{id: "user_12345", org_id: "org_normal", role: :member}
  @internal_api Xaas.SystemAuthority.new(:internal_api)

  defp seed_secret!(namespace) do
    RouteSecrets
    |> Ash.Changeset.for_create(
      :create,
      %{namespace: namespace, name: "db-credentials", requested_by: "seeder"},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp seed_flag!(flag_key) do
    RouteFeatureFlags
    |> Ash.Changeset.for_create(
      :create,
      %{flag_key: flag_key, enabled: false, requested_by: "seeder"},
      authorize?: false
    )
    |> Ash.create!()
  end

  defp seed_window!(org_id) do
    FreezeWindow
    |> Ash.Changeset.for_create(
      :create,
      %{
        org_id: org_id,
        starts_at: DateTime.utc_now(),
        ends_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        reason: "falsifier window",
        created_by: "seeder"
      },
      authorize?: false
    )
    |> Ash.create!()
  end

  defp seed_pending_approval!(resource, attrs) do
    resource
    |> Ash.Changeset.for_create(:create, attrs, authorize?: false)
    |> Ash.create!()
  end

  describe "the review falsifier: ordinary actors are refused on converted SERVICE-BOUNDARY mutations" do
    test "RouteSecrets :create refuses an ordinary non-system actor (and persists nothing)" do
      assert {:error, %Ash.Error.Forbidden{}} =
               RouteSecrets
               |> Ash.Changeset.for_create(:create, %{
                 namespace: "falsifier-ns",
                 name: "creds",
                 requested_by: "attacker"
               })
               |> Ash.create(actor: @ordinary_actor)

      assert RouteSecrets
             |> Ash.read!(authorize?: false)
             |> Enum.filter(&(&1.namespace == "falsifier-ns")) == []
    end

    test "RouteSecrets :create refuses a nil actor (any anonymous caller)" do
      assert {:error, %Ash.Error.Forbidden{}} =
               RouteSecrets
               |> Ash.Changeset.for_create(:create, %{
                 namespace: "falsifier-ns-nil",
                 name: "creds",
                 requested_by: "anonymous"
               })
               |> Ash.create()
    end

    test "RouteSecrets :destroy refuses an ordinary actor" do
      secret = seed_secret!("falsifier-ns-destroy")

      assert {:error, %Ash.Error.Forbidden{}} =
               secret
               |> Ash.Changeset.for_destroy(:destroy, %{})
               |> Ash.destroy(actor: @ordinary_actor)

      assert Ash.get!(RouteSecrets, secret.id, authorize?: false).namespace ==
               "falsifier-ns-destroy"
    end

    test "RouteFeatureFlags :update refuses an ordinary actor" do
      flag = seed_flag!("falsifier-flag")

      assert {:error, %Ash.Error.Forbidden{}} =
               flag
               |> Ash.Changeset.for_update(:update, %{enabled: true})
               |> Ash.update(actor: @ordinary_actor)

      refute Ash.get!(RouteFeatureFlags, flag.id, authorize?: false).enabled
    end

    test "FreezeWindow :create and :destroy refuse an ordinary actor" do
      assert {:error, %Ash.Error.Forbidden{}} =
               FreezeWindow
               |> Ash.Changeset.for_create(:create, %{
                 org_id: "org-falsifier",
                 starts_at: DateTime.utc_now(),
                 ends_at: DateTime.add(DateTime.utc_now(), 3600, :second),
                 reason: "must be refused",
                 created_by: "attacker"
               })
               |> Ash.create(actor: @ordinary_actor)

      window = seed_window!("org-falsifier-2")

      assert {:error, %Ash.Error.Forbidden{}} =
               window
               |> Ash.Changeset.for_destroy(:destroy, %{})
               |> Ash.destroy(actor: @ordinary_actor)

      assert Ash.get!(FreezeWindow, window.id, authorize?: false).org_id == "org-falsifier-2"
    end

    test "ApprovalOrgDelete :create and :approve refuse an ordinary actor" do
      assert {:error, %Ash.Error.Forbidden{}} =
               ApprovalOrgDelete
               |> Ash.Changeset.for_create(:create, %{
                 org_id: "org-falsifier",
                 requested_by: "attacker"
               })
               |> Ash.create(actor: @ordinary_actor)

      pending =
        seed_pending_approval!(ApprovalOrgDelete, %{org_id: "org-x", requested_by: "req-1"})

      assert {:error, %Ash.Error.Forbidden{}} =
               pending
               |> Ash.Changeset.for_update(:approve, %{approved_by: "appr-1"})
               |> Ash.update(actor: @ordinary_actor)
    end

    test "Billing approvals refuse an ordinary actor (:create and :approve shapes)" do
      assert {:error, %Ash.Error.Forbidden{}} =
               ApprovalQuotaOverride
               |> Ash.Changeset.for_create(:create, %{requested_by: "attacker"})
               |> Ash.create(actor: @ordinary_actor)

      pending = seed_pending_approval!(ApprovalPricingOverride, %{requested_by: "req-1"})

      assert {:error, %Ash.Error.Forbidden{}} =
               pending
               |> Ash.Changeset.for_update(:approve, %{approved_by: "appr-1"})
               |> Ash.update(actor: @ordinary_actor)
    end

    test "Operations approvals refuse an ordinary actor (:create and :approve shapes)" do
      assert {:error, %Ash.Error.Forbidden{}} =
               ApprovalK8sFaultRemediateSuggest
               |> Ash.Changeset.for_create(:create, %{requested_by: "attacker"})
               |> Ash.create(actor: @ordinary_actor)

      pending = seed_pending_approval!(ApprovalK8sFaultRemediateSuggest, %{requested_by: "req-1"})

      assert {:error, %Ash.Error.Forbidden{}} =
               pending
               |> Ash.Changeset.for_update(:approve, %{approved_by: "appr-1"})
               |> Ash.update(actor: @ordinary_actor)
    end
  end

  describe "the review falsifier: ordinary actors are refused on converted INTERNAL-ONLY mutations" do
    test "AutofdePlannerMatch :request_match refuses an ordinary actor in the real policy calculus" do
      # Real, disclosed mechanics (verified live this session): this
      # action's own `change` block performs the outbound Req.post to
      # cnv-deploy DURING changeset assembly, and with the sibling service
      # not running the changeset is invalid before Ash.create's internal
      # authorize step -- so the honest, network-independent falsifier is
      # the REAL policy calculus itself, evaluated exactly the way
      # Ash.create evaluates it (Ash.can?/2 runs the real
      # Ash.Policy.Authorizer against the real action + input).
      changeset =
        AutofdePlannerMatch
        |> Ash.Changeset.for_create(:request_match, %{query: "Maze"})

      refute Ash.can?(changeset, @ordinary_actor)
      refute Ash.can?(changeset, nil)
      assert Ash.can?(changeset, Xaas.SystemAuthority.new(:autofde_coverage_monitor))

      # And the ordinary-actor create attempt persists nothing.
      assert {:error, _} =
               AutofdePlannerMatch
               |> Ash.Changeset.for_create(:request_match, %{query: "Maze"})
               |> Ash.create(actor: @ordinary_actor)

      assert AutofdePlannerMatch
             |> Ash.read!(authorize?: false)
             |> Enum.filter(&(&1.query == "Maze")) ==
               []
    end

    test "CapabilityLivenessReceipt :check_regressions refuses an ordinary actor" do
      assert {:error, %Ash.Error.Forbidden{}} =
               CapabilityLivenessReceipt
               |> Ash.ActionInput.for_action(:check_regressions, %{})
               |> Ash.run_action(actor: @ordinary_actor)
    end
  end

  describe "the real system authority actor is admitted" do
    test "RouteSecrets :create admits the internal_api system actor and persists the real row" do
      created =
        RouteSecrets
        |> Ash.Changeset.for_create(:create, %{
          namespace: "admission-ns",
          name: "creds",
          requested_by: "internal-service"
        })
        |> Ash.create!(actor: @internal_api)

      persisted = Ash.get!(RouteSecrets, created.id, authorize?: false)
      assert persisted.namespace == "admission-ns"
    end

    test "FreezeWindow :create admits the internal_api system actor" do
      window =
        FreezeWindow
        |> Ash.Changeset.for_create(:create, %{
          org_id: "org-admission",
          starts_at: DateTime.utc_now(),
          ends_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          reason: "admission proof",
          created_by: "internal-service"
        })
        |> Ash.create!(actor: @internal_api)

      # FreezeWindow carries the AshIam extension, which redacts
      # policy-gated fields on records returned to a non-IAM actor (the
      # system authority is not an IAM principal) -- assert on the real
      # persisted row, exactly like the freeze_window controller test.
      persisted = Ash.get!(FreezeWindow, window.id, authorize?: false)
      assert persisted.org_id == "org-admission"
      assert persisted.reason == "admission proof"
    end

    test "ApprovalK8sFaultRemediateSuggest :create and :approve admit the internal_api system actor" do
      pending =
        ApprovalK8sFaultRemediateSuggest
        |> Ash.Changeset.for_create(:create, %{requested_by: "internal-service"})
        |> Ash.create!(actor: @internal_api)

      approved =
        pending
        |> Ash.Changeset.for_update(:approve, %{approved_by: "internal-approver"})
        |> Ash.update!(actor: @internal_api)

      assert approved.approved_by == "internal-approver"
    end

    test "CapabilityLivenessReceipt :check_regressions admits the oban_scheduler system actor" do
      # The exact actor the AshOban schedule's default_actor now supplies.
      assert {:ok, %{regressions: regressions}} =
               CapabilityLivenessReceipt
               |> Ash.ActionInput.for_action(:check_regressions, %{})
               |> Ash.run_action(actor: Xaas.SystemAuthority.new(:oban_scheduler))

      # This test's sandbox transaction ingested nothing: no regressions.
      assert regressions == []
    end

    test "AutofdePlannerMatch :request_match admits the system actor in the real policy calculus" do
      # Same disclosed mechanics as the falsifier test above: with
      # cnv-deploy not running, the action's outbound-HTTP change errors
      # during changeset assembly, so the real admission proof is the
      # policy calculus itself (Ash.can?/2 with the real system actor --
      # the exact actor the updated close_coverage_gap Mix task passes).
      changeset =
        AutofdePlannerMatch
        |> Ash.Changeset.for_create(:request_match, %{query: "Maze"})

      assert Ash.can?(changeset, Xaas.SystemAuthority.new(:autofde_coverage_monitor))
    end
  end

  describe "fabricated lookalike actors are still refused" do
    test "a plain map carrying the same :service field is NOT a system authority" do
      lookalike = %{service: :internal_api, id: "fake", org_id: "org_fabricated"}

      assert {:error, %Ash.Error.Forbidden{}} =
               RouteSecrets
               |> Ash.Changeset.for_create(:create, %{
                 namespace: "lookalike-ns",
                 name: "creds",
                 requested_by: "fabricator"
               })
               |> Ash.create(actor: lookalike)
    end
  end
end
