defmodule Xaas.Governance.MultitenantApprovalDeepeningTest do
  @moduledoc """
  Real Chicago-style composed court for the 4 non-global-multitenancy
  Governance `Approval*` resources (`ApprovalDrFailover`,
  `ApprovalLegalHoldRelease`, `ApprovalDeploymentQuarantine`,
  `ApprovalBackupRetentionChange`) -- the ones whose `X-Org-Id`-resolved
  tenant/actor comes from `XaasWeb.Plugs.ResolveOrgActor`.

  Four lenses, all real actions on the real sandboxed Postgres
  (`Xaas.Repo`), no mocks:

    (a) tenant isolation -- org A cannot read or approve org B's rows
        (Ash attribute-strategy multitenancy, `global? false`);
    (b) the maker-checker invariant -- the same `requested_by` cannot
        also be the `approved_by` on any of the 4 resources;
    (c) state machine -- approving a nonexistent id, approving with no
        `approved_by`, and double-approving an already-approved row;
    (d) the `ResolveOrgActor` plug path -- a missing `X-Org-Id` header
        on any of the 4 resources' tenant-scoped routes is a real
        halted `400 missing_org_id`, never a silent passthrough.
  """
  use XaasWeb.ConnCase, async: false

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalBackupRetentionChange
  alias Xaas.Governance.ApprovalDeploymentQuarantine
  alias Xaas.Governance.ApprovalDrFailover
  alias Xaas.Governance.ApprovalLegalHoldRelease
  alias Xaas.Governance.InternalApiTokenAuth
  alias Xaas.Operations.Incident

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # ---------- fixtures ----------

  defp real_org!(slug_prefix) do
    unique = System.unique_integer([:positive])

    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "#{slug_prefix} #{unique}",
      slug: "#{slug_prefix}-#{unique}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp open_incident!(org_slug, region) do
    Incident
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_slug,
      title: "incident for #{region}",
      region: region,
      opened_at: DateTime.utc_now()
    })
    |> Ash.create!(authorize?: false)
  end

  @spec create_pending!(module, String.t(), String.t()) :: struct
  defp create_pending!(resource, org_slug, requested_by) do
    attrs =
      case resource do
        ApprovalDrFailover ->
          %{
            org_id: org_slug,
            requested_by: requested_by,
            from_region: "us-east-1",
            to_region: "us-west-2",
            reason: "deepening court"
          }

        ApprovalLegalHoldRelease ->
          %{
            org_id: org_slug,
            requested_by: requested_by,
            hold_id: "hold-#{System.unique_integer([:positive])}",
            release_reason: "deepening court"
          }

        ApprovalDeploymentQuarantine ->
          %{
            org_id: org_slug,
            requested_by: requested_by,
            deployment_name: "deploy-#{System.unique_integer([:positive])}",
            environment: :prod,
            reason: :security_finding
          }

        ApprovalBackupRetentionChange ->
          %{
            org_id: org_slug,
            requested_by: requested_by,
            requested_retention_days: 90,
            tier: :pro
          }
      end

    resource
    |> Ash.Changeset.for_create(:create, attrs, tenant: org_slug)
    |> Ash.create!(authorize?: false)
  end

  defp approve_changeset(record, approved_by) do
    Ash.Changeset.for_update(record, :approve, %{approved_by: approved_by},
      tenant: record.org_id,
      actor: %{org_id: record.org_id}
    )
  end

  # ---------- (a) tenant isolation ----------

  describe "tenant isolation (a)" do
    test "org A cannot read org B's pending row: tenant-scoped read is empty and Ash.get is NotFound" do
      org_a = real_org!("iso-org-a")
      org_b = real_org!("iso-org-b")
      row = create_pending!(ApprovalDeploymentQuarantine, org_b.slug, "requester-b")

      # Real tenant-scoped index read under org A's tenant never sees org B's row.
      read_under_a =
        ApprovalDeploymentQuarantine
        |> Ash.Query.filter(org_id: org_b.slug)
        |> Ash.read!(tenant: org_a.slug, authorize?: false)

      assert read_under_a == []

      # Real Ash.get under org A's tenant is a typed NotFound (Ash wraps the
      # NotFound in a top-level Ash.Error.Invalid; class is :invalid).
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(ApprovalDeploymentQuarantine, row.id,
                 tenant: org_a.slug,
                 authorize?: false
               )
    end

    test "org B's actor cannot approve org A's row via an authorized :approve (org B sees no such row)" do
      org_a = real_org!("iso-org-a2")
      org_b = real_org!("iso-org-b2")
      open_incident!(org_a.slug, "us-east-1")
      row = create_pending!(ApprovalDrFailover, org_a.slug, "requester-a")

      # Authorized as org B with tenant org B: Ash's action-filter check
      # (ActorOrgMatches, access_type :filter) turns the attempt into a real
      # Ash.Error.Forbidden -- the row is never reachable, no silent success
      # and no leak of org A's row content.
      assert {:error, %Ash.Error.Forbidden{errors: [%Ash.Error.Forbidden.Policy{} = refusal]}} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-b"},
                 tenant: org_b.slug,
                 actor: %{org_id: org_b.slug},
                 authorize?: true
               )
               |> Ash.update(authorize?: true)

      # The real named check that refused it, from the policy breakdown.
      assert Enum.any?(refusal.facts, fn
               {{Xaas.Governance.Checks.ActorOrgMatches, _}, false} -> true
               _ -> false
             end)

      # Real row state: still pending under org A, untouched.
      persisted = Ash.get!(ApprovalDrFailover, row.id, tenant: org_a.slug, authorize?: false)
      assert persisted.approved_by == nil
    end

    test "authorized same-org approve succeeds (control), proving the refusals above are isolation, not breakage" do
      org = real_org!("iso-org-ctrl")
      open_incident!(org.slug, "us-east-1")
      row = create_pending!(ApprovalDrFailover, org.slug, "requester-ctrl")

      assert {:ok, approved} =
               row
               |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-ctrl"},
                 tenant: org.slug,
                 actor: %{org_id: org.slug},
                 authorize?: true
               )
               |> Ash.update(authorize?: true)

      assert approved.approved_by == "approver-ctrl"
    end
  end

  # ---------- (b) maker-checker invariant ----------

  describe "maker-checker invariant (b)" do
    test "the requester cannot be their own approver on any of the 4 resources" do
      for resource <- [
            ApprovalDrFailover,
            ApprovalLegalHoldRelease,
            ApprovalDeploymentQuarantine,
            ApprovalBackupRetentionChange
          ] do
        org = real_org!("mc-org-#{System.unique_integer([:positive])}")

        if resource == ApprovalDrFailover do
          open_incident!(org.slug, "us-east-1")
        end

        row = create_pending!(resource, org.slug, "same-actor")

        assert {:error, error} =
                 row
                 |> approve_changeset("same-actor")
                 |> Ash.update(authorize?: false)

        # The real, typed refusal of every *RequiresApprover validation.
        assert %Ash.Error.Invalid{} = error
        messages = Exception.message(error)
        assert messages =~ "distinct"
        assert messages =~ "approved_by"

        # Real row state: still pending.
        persisted = Ash.get!(resource, row.id, tenant: org.slug, authorize?: false)
        assert persisted.approved_by == nil
      end
    end
  end

  # ---------- (c) state machine ----------

  describe "state machine (c)" do
    test "approving a nonexistent id is impossible: the only lawful path to a record is a tenant-scoped get, which is a typed NotFound" do
      org = real_org!("sm-org-a")
      missing_id = Ash.UUID.generate()

      # The record-lookup half of :approve is tenant-scoped: an id that was
      # never created cannot be loaded, so it can never be approved.
      assert {:error, %Ash.Error.Invalid{errors: [%Ash.Error.Query.NotFound{}]}} =
               Ash.get(ApprovalDrFailover, missing_id,
                 tenant: org.slug,
                 authorize?: false
               )
    end

    test "approve with no approved_by is a typed invalid on each of the 4 resources" do
      for resource <- [
            ApprovalDrFailover,
            ApprovalLegalHoldRelease,
            ApprovalDeploymentQuarantine,
            ApprovalBackupRetentionChange
          ] do
        org = real_org!("sm-org-#{System.unique_integer([:positive])}")

        if resource == ApprovalDrFailover do
          open_incident!(org.slug, "us-east-1")
        end

        row = create_pending!(resource, org.slug, "requester")

        # approved_by is required but absent (nil) -> the *RequiresApprover
        # validation refuses before any state transition.
        assert {:error, %Ash.Error.Invalid{}} =
                 Ash.update(
                   Ash.Changeset.for_update(row, :approve, %{}, tenant: org.slug),
                   authorize?: false
                 )

        persisted = Ash.get!(resource, row.id, tenant: org.slug, authorize?: false)
        assert persisted.approved_by == nil
      end
    end

    test "double-approve is a typed refusal on each of the 4 resources and the original approved_by is preserved" do
      # W740 fix for the W722 gap-1 defect: every one of the 4 resources now
      # carries Xaas.Governance.Validations.ApprovalNotAlreadyApproved on its
      # :approve action. A second :approve against an already-approved row is
      # a real typed Ash.Error.Invalid refusal on approved_by, and the real
      # persisted row keeps the FIRST approver (no silent overwrite).
      #
      # Mutation rationale: drop
      # `validate(ApprovalNotAlreadyApproved)` from any of the 4 :approve
      # actions and `assert {:error, %Ash.Error.Invalid{}} =` fails here (the
      # second approve succeeds and `persisted.approved_by` flips to
      # "approver-2"), exactly the W722 defect. Drop only one resource's line
      # and that resource alone fails the loop.
      for resource <- [
            ApprovalDrFailover,
            ApprovalLegalHoldRelease,
            ApprovalDeploymentQuarantine,
            ApprovalBackupRetentionChange
          ] do
        org = real_org!("da-org-#{System.unique_integer([:positive])}")

        if resource == ApprovalDrFailover do
          open_incident!(org.slug, "us-east-1")
        end

        row = create_pending!(resource, org.slug, "requester")

        {:ok, first} =
          row
          |> approve_changeset("approver-1")
          |> Ash.update(authorize?: false)

        assert first.approved_by == "approver-1"

        assert {:error, %Ash.Error.Invalid{} = error} =
                 first
                 |> approve_changeset("approver-2")
                 |> Ash.update(authorize?: false)

        # The real, typed refusal is on approved_by, naming the state guard.
        messages = Exception.message(error)
        assert messages =~ "approved_by"
        assert messages =~ "already been approved"

        persisted = Ash.get!(resource, row.id, tenant: org.slug, authorize?: false)

        # Maker-checker integrity: the FIRST approver survives untouched.
        assert persisted.approved_by == "approver-1"
      end
    end

    test "ApprovalBackupRetentionChange's ledger-charge path stays green under the double-approve guard" do
      # The separately-guarded ChargeOverage change must still charge exactly
      # once on a real first approve, and the second approve is now refused
      # outright by the state guard before the charge change ever runs.
      org = real_org!("da-charge-org-#{System.unique_integer([:positive])}")

      row = create_pending!(ApprovalBackupRetentionChange, org.slug, "requester")

      {:ok, first} =
        row
        |> approve_changeset("approver-1")
        |> Ash.update(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               first
               |> approve_changeset("approver-2")
               |> Ash.update(authorize?: false)

      # Exactly one real ledger movement for this org: the first approve's
      # overage charge (90 requested on pro = 60 overage days at 10 cents/day
      # = -$6.00). The second approve never reaches the charge change.
      account =
        Xaas.Ledger.Account
        |> Ash.Query.filter(identifier: org.slug)
        |> Ash.read_one!(authorize?: false)

      balance =
        Xaas.Ledger.Balance
        |> Ash.Query.filter(account_id: account.id)
        |> Ash.read!(authorize?: false)
        |> Enum.max_by(& &1.transfer_id, fn -> nil end)

      assert balance != nil
      assert Money.equal?(balance.balance, Money.new(:USD, "-6.00"))
    end
  end

  # ---------- (d) ResolveOrgActor plug path ----------

  describe "ResolveOrgActor plug path (d)" do
    defp token_conn(conn) do
      put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    end

    defp json_conn(conn, org_id) do
      conn
      |> token_conn()
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> put_req_header("x-org-id", org_id)
    end

    @path_for %{
      ApprovalDrFailover => "approval_dr_failover",
      ApprovalLegalHoldRelease => "approval_legal_hold_release",
      ApprovalDeploymentQuarantine => "approval_deployment_quarantine",
      ApprovalBackupRetentionChange => "approval_backup_retention_change"
    }

    test "missing X-Org-Id on each of the 4 resources' routes is a real halted 400 missing_org_id" do
      for {resource, path_segment} <- @path_for do
        org = real_org!("plug-org-#{System.unique_integer([:positive])}")
        row = create_pending!(resource, org.slug, "requester")

        # GET of a real row id with no X-Org-Id header at all.
        resp =
          token_conn(build_conn())
          |> put_req_header("accept", "application/vnd.api+json")
          |> get("/api/#{path_segment}/#{row.id}")

        assert resp.status == 400, "expected 400 for #{inspect(resource)} GET"
        assert json_response(resp, 400)["error"] == "missing_org_id"
        assert json_response(resp, 400)["detail"] =~ "X-Org-Id"

        # PATCH (the :approve route) with no X-Org-Id header: same refusal.
        resp_patch =
          token_conn(build_conn())
          |> put_req_header("content-type", "application/vnd.api+json")
          |> put_req_header("accept", "application/vnd.api+json")
          |> patch("/api/#{path_segment}/#{row.id}", %{"data" => %{"attributes" => %{}}})

        assert resp_patch.status == 400, "expected 400 for #{inspect(resource)} PATCH"
        assert json_response(resp_patch, 400)["error"] == "missing_org_id"
      end
    end

    test "X-Org-Id that resolves to no real Org is a real 404 org_not_found (one representative + one smoke sibling)" do
      for {resource, path_segment} <-
            Map.take(@path_for, [ApprovalDrFailover, ApprovalBackupRetentionChange]) do
        org = real_org!("plug404-org-#{System.unique_integer([:positive])}")
        row = create_pending!(resource, org.slug, "requester")

        resp =
          json_conn(build_conn(), "no-such-org-#{System.unique_integer([:positive])}")
          |> get("/api/#{path_segment}/#{row.id}")

        assert resp.status == 404
        assert json_response(resp, 404)["error"] == "org_not_found"
      end
    end
  end

  # SPEC-04 (W722-GAP-2; lane W969b design-wave 2): authenticated org
  # binding. A request authenticated via an org-carrying InternalApiToken
  # (XaasWeb.Plugs.AuthenticateOrg binds conn.assigns[:authenticated_org])
  # must REFUSE a forged X-Org-Id naming a different org, must bind the
  # authenticated org with NO header at all, and must leave the legacy
  # shared-token tier's caller-asserted behavior untouched.
  describe "authenticated org binding (e)" do
    defp org_token_conn(conn, raw_token, header_org_id) do
      conn
      |> put_req_header("authorization", "Bearer " <> raw_token)
      |> put_req_header("accept", "application/vnd.api+json")
      |> then(fn c ->
        if header_org_id, do: put_req_header(c, "x-org-id", header_org_id), else: c
      end)
    end

    test "forged X-Org-Id under an authenticated different org is a real 403 org_mismatch" do
      org_a = real_org!("auth-org-a")
      org_b = real_org!("auth-org-b")
      row = create_pending!(ApprovalDrFailover, org_a.slug, "requester")
      {:ok, raw_token, _token} = InternalApiTokenAuth.issue("w969b", nil, org_a)

      resp =
        org_token_conn(build_conn(), raw_token, org_b.slug)
        |> get("/api/approval_dr_failover/#{row.id}")

      assert resp.status == 403
      body = json_response(resp, 403)
      assert body["error"] == "org_mismatch"
      assert body["detail"] =~ org_b.slug
    end

    test "authenticated org binds with NO X-Org-Id header (derive-from-authenticated-identity)" do
      org_a = real_org!("auth-org-c")
      row = create_pending!(ApprovalDrFailover, org_a.slug, "requester")
      {:ok, raw_token, _token} = InternalApiTokenAuth.issue("w969b", nil, org_a)

      resp =
        org_token_conn(build_conn(), raw_token, nil)
        |> get("/api/approval_dr_failover/#{row.id}")

      assert resp.status == 200
      assert json_response(resp, 200)["data"]["id"] == row.id
    end

    test "matching X-Org-Id under the authenticated org passes through (control)" do
      org_a = real_org!("auth-org-d")
      row = create_pending!(ApprovalDrFailover, org_a.slug, "requester")
      {:ok, raw_token, _token} = InternalApiTokenAuth.issue("w969b", nil, org_a)

      resp =
        org_token_conn(build_conn(), raw_token, org_a.slug)
        |> get("/api/approval_dr_failover/#{row.id}")

      assert resp.status == 200
    end

    test "401/403 matrix: no bearer is 401; legacy shared token keeps caller-asserted resolution" do
      org = real_org!("auth-org-e")
      row = create_pending!(ApprovalDrFailover, org.slug, "requester")

      # 401: no bearer at all.
      resp =
        build_conn()
        |> put_req_header("accept", "application/vnd.api+json")
        |> get("/api/approval_dr_failover/#{row.id}")

      assert resp.status == 401

      # Legacy tier: shared INTERNAL_API_TOKEN + forged header for a real
      # other org still resolves as before (caller-asserted), because no
      # authenticated org exists to contradict it. The forged header here
      # names a REAL other org, so the legacy path 200s it — the exact
      # limitation SPEC-04 closes for the org-token tier.
      other = real_org!("auth-org-f")

      resp_legacy =
        build_conn()
        |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
        |> put_req_header("accept", "application/vnd.api+json")
        |> put_req_header("x-org-id", other.slug)
        |> get("/api/approval_dr_failover/#{row.id}")

      assert resp_legacy.status == 404
    end
  end
end
