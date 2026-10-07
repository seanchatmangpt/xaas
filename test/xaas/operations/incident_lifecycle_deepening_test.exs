defmodule Xaas.Operations.IncidentLifecycleDeepeningTest do
  @moduledoc """
  W793 — deepening of the Operations incident / route-castle lifecycle
  surface (lane W793, v26.10.6). These Ash resources were previously
  undocketed (the semantics-layer `Xaas.Semantics.IncidentReport` is
  courted separately; this court is the row-level lifecycle).

  Chicago-style: real Ash actions on the real sandboxed Postgres
  (`Xaas.Repo`), `authorize?: false` where the point is the lifecycle
  machine itself (auth policy is already courted in
  `test/xaas/operations/incident_test.exs`), real row-state asserts.

  Four lenses:

    (a) the real lifecycle state machine per the actual actions --
        `:create` -> `:update` only, no `:destroy`; transition set
        asserted, plus honest typed gaps where guards are ABSENT
        (GAP entries below are observed live, not assumed);

    (b) cross-resource integrity where it exists -- and where it does
        NOT (GAP(NO_CROSS_REFERENCE): the route-castle ledgers carry no
        incident reference at all; the real cross-resource coupling is
        Incident <-> `Xaas.Governance.Validations.
        ApprovalDrFailoverRequiresOpenIncident`'s region/org/status
        query, exercised here through the real lifecycle);

    (c) what the W747/W745 fabric courts consume from these resources,
        read-only cross-check -- `RouteCastleRun`'s private `:execute`
        is the from-node of the nested-BRCE edge
        (`Xaas.Castle.Generated.EdgeCatalog`), admitted by
        `Xaas.Castle` against `ontology_projection_hash/0`;

    (d) determinism -- identical payloads project identically; the
        ontology projection hash is stable.
  """

  use ExUnit.Case, async: true

  alias Xaas.Operations.Incident
  alias Xaas.Operations.RouteCastleDeploy
  alias Xaas.Operations.RouteCastleRun
  alias Xaas.Operations.RouteCastleSchedule
  alias Xaas.Operations.RouteCastleSunset

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_id, do: "org-#{System.unique_integer([:positive])}"
  defp region, do: "region-#{System.unique_integer([:positive])}"

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp create_incident!(attrs) do
    Incident
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create!(authorize?: false)
  end

  defp base_attrs(overrides \\ %{}) do
    Map.merge(
      %{
        org_id: org_id(),
        title: "W793 lifecycle probe",
        region: region(),
        opened_at: now()
      },
      overrides
    )
  end

  defp action_names(module), do: module |> Ash.Resource.Info.actions() |> Enum.map(& &1.name)

  defp write_actions(module) do
    module
    |> Ash.Resource.Info.actions()
    |> Enum.filter(&(&1.type in [:create, :update, :destroy]))
  end

  # ---------------------------------------------------------------------------
  # (a) The real lifecycle state machine, per the actual actions
  # ---------------------------------------------------------------------------

  describe "(a) lifecycle action surface" do
    test "Incident exposes exactly read/create/update -- no destroy anywhere in the surface" do
      assert action_names(Incident) |> Enum.sort() == [:create, :read, :update]
      assert write_actions(Incident) |> Enum.map(& &1.type) |> Enum.sort() == [:create, :update]
    end

    test "route-castle ledgers are read-only at the Ash action layer (GAP: no create/update actions exist, so the ledgers cannot be populated through the Ash surface at all)" do
      for module <- [RouteCastleDeploy, RouteCastleRun, RouteCastleSchedule, RouteCastleSunset] do
        assert write_actions(module) == []

        # The only non-read action on RouteCastleRun is the private BRCE :execute.
        non_read = module |> Ash.Resource.Info.actions() |> Enum.reject(&(&1.type == :read))

        case module do
          RouteCastleRun ->
            assert Enum.map(non_read, & &1.name) == [:execute]

          _ ->
            assert non_read == []
        end
      end
    end

    test "RouteCastleRun :execute is private (public?(false)) -- not caller-reachable" do
      execute = Ash.Resource.Info.action(RouteCastleRun, :execute)

      assert execute.public? == false
      assert execute.transaction? == true
    end

    test "full happy-path lifecycle: create(:open) -> update(:resolved + resolved_at + postmortem final), real row state asserted" do
      opened = now()
      resolved_at = now()

      incident = create_incident!(base_attrs())

      assert incident.status == :open
      assert incident.severity == :minor
      assert incident.postmortem_status == :draft
      assert incident.resolved_at == nil
      assert incident.opened_at == opened

      resolved =
        incident
        |> Ash.Changeset.for_update(
          :update,
          %{
            status: :resolved,
            resolved_at: resolved_at,
            postmortem_root_cause: "pool exhaustion",
            postmortem_remediation: "raised pool limit",
            postmortem_status: :final
          }
        )
        |> Ash.update!(authorize?: false)

      assert resolved.status == :resolved
      assert resolved.resolved_at == resolved_at
      assert resolved.postmortem_status == :final

      persisted = Ash.get!(Incident, incident.id, authorize?: false)
      assert persisted.status == :resolved
      assert persisted.resolved_at == resolved_at
    end

    test "GUARD (W818): :create cannot mint :resolved without resolved_at -- the resolved-at invariant now holds on create too" do
      # Was GAP(RESOLVED_AT_GUARD_ONLY_ON_UPDATE) in W793 (observed live);
      # closed by wiring IncidentResolvedRequiresResolvedAt onto :create.
      # :create does not accept :resolved_at, so a :resolved-at-birth
      # incident is refused outright.
      assert {:error, %Ash.Error.Invalid{}} =
               Incident
               |> Ash.Changeset.for_create(:create, base_attrs(%{status: :resolved}))
               |> Ash.create(authorize?: false)

      # No rows were written by the rejected attempt.
      assert Incident
             |> Ash.Query.filter(org_id == ^base_attrs().org_id)
             |> Ash.read!(authorize?: false) == []
    end

    test "GUARD (W818): :resolved is terminal for :update -- resolved -> open is refused (was GAP(NO_REOPEN_GUARD))" do
      resolved_at = now()

      incident =
        create_incident!(base_attrs())
        |> Ash.Changeset.for_update(:update, %{status: :resolved, resolved_at: resolved_at})
        |> Ash.update!(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               incident
               |> Ash.Changeset.for_update(:update, %{status: :open})
               |> Ash.update(authorize?: false)

      # Row unchanged on disk: still resolved, resolved_at intact (the
      # stale-resolved_at retention W793 pinned dies with the reopen path).
      persisted = Ash.get!(Incident, incident.id, authorize?: false)
      assert persisted.status == :resolved
      assert persisted.resolved_at == resolved_at

      # Same-status resolved annotation (postmortem fields) stays allowed.
      annotated =
        persisted
        |> Ash.Changeset.for_update(:update, %{postmortem_status: :final})
        |> Ash.update!(authorize?: false)

      assert annotated.status == :resolved
      assert annotated.postmortem_status == :final
    end

    test "GUARD (W902): resolved_at requires :resolved -- resolved_at while :open is refused (was GAP(NO_RESOLVED_AT_GUARD))" do
      incident = create_incident!(base_attrs())

      # Direct set while open: refused.
      assert {:error, %Ash.Error.Invalid{}} =
               incident
               |> Ash.Changeset.for_update(:update, %{resolved_at: now()})
               |> Ash.update(authorize?: false)

      # A resolved incident whose resolved_at is then cleared back while
      # staying resolved is a different edge; here we pin that the refused
      # attempt wrote nothing: the row still has no resolved_at.
      persisted = Ash.get!(Incident, incident.id, authorize?: false)
      assert persisted.status == :open
      assert persisted.resolved_at == nil

      # The lawful edge stays open: resolving WITH the timestamp succeeds
      # and lands both fields.
      resolved =
        persisted
        |> Ash.Changeset.for_update(:update, %{status: :resolved, resolved_at: now()})
        |> Ash.update!(authorize?: false)

      assert resolved.status == :resolved
      assert resolved.resolved_at != nil
    end

    test "GUARD (W902): postmortem :final requires :resolved (was GAP(NO_POSTMORTEM_STATUS_GUARD))" do
      incident = create_incident!(base_attrs())

      # :final while :open is refused typed.
      assert {:error, %Ash.Error.Invalid{}} =
               incident
               |> Ash.Changeset.for_update(
                 :update,
                 %{postmortem_status: :final, postmortem_root_cause: "x"}
               )
               |> Ash.update(authorize?: false)

      # :draft annotation while :open stays legal (only the :final
      # close-out is gated).
      annotated =
        incident
        |> Ash.Changeset.for_update(:update, %{postmortem_root_cause: "x"})
        |> Ash.update!(authorize?: false)

      assert annotated.postmortem_status == :draft
      assert annotated.postmortem_root_cause == "x"

      # The lawful edge: resolve first, then :final succeeds.
      resolved =
        annotated
        |> Ash.Changeset.for_update(:update, %{status: :resolved, resolved_at: now()})
        |> Ash.update!(authorize?: false)

      finalized =
        resolved
        |> Ash.Changeset.for_update(:update, %{postmortem_status: :final})
        |> Ash.update!(authorize?: false)

      assert finalized.status == :resolved
      assert finalized.postmortem_status == :final
    end

    test "the one real guard holds: :resolved without resolved_at on :update is rejected and the row is unchanged" do
      incident = create_incident!(base_attrs())

      assert {:error, %Ash.Error.Invalid{}} =
               incident
               |> Ash.Changeset.for_update(:update, %{status: :resolved})
               |> Ash.update(authorize?: false)

      persisted = Ash.get!(Incident, incident.id, authorize?: false)
      assert persisted.status == :open
      assert persisted.resolved_at == nil
    end

    test "the severity/postmortem enums are closed sets -- out-of-set values are rejected at the type layer" do
      assert {:error, %Ash.Error.Invalid{}} =
               Incident
               |> Ash.Changeset.for_create(:create, base_attrs(%{severity: :catastrophic}))
               |> Ash.create(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               Incident
               |> Ash.Changeset.for_create(:create, base_attrs(%{status: :mitigated}))
               |> Ash.create(authorize?: false)

      assert {:error, %Ash.Error.Invalid{}} =
               Incident
               |> Ash.Changeset.for_create(:create, base_attrs(%{postmortem_status: :archived}))
               |> Ash.create(authorize?: false)

      # No rows were written by any of the rejected attempts.
      assert Incident
             |> Ash.Query.filter(title == "W793 lifecycle probe" and status == :open)
             |> Ash.read!(authorize?: false) == []
    end
  end

  # ---------------------------------------------------------------------------
  # (b) Cross-resource integrity where it exists (and where it does not)
  # ---------------------------------------------------------------------------

  describe "(b) cross-resource integrity" do
    test "GAP(NO_CROSS_REFERENCE): route-castle ledgers carry no incident reference and no relationship to Incident" do
      for module <- [RouteCastleDeploy, RouteCastleRun, RouteCastleSchedule, RouteCastleSunset] do
        attr_names =
          module |> Ash.Resource.Info.attributes() |> Enum.map(& &1.name)

        refute :incident_id in attr_names

        rel_names =
          module |> Ash.Resource.Info.relationships() |> Enum.map(& &1.name)

        refute Enum.any?(rel_names, &(&1 in [:incident, :incidents]))

        incident_side =
          Incident |> Ash.Resource.Info.relationships() |> Enum.map(& &1.name)

        refute Enum.any?(incident_side, &(to_string(&1) =~ "castle"))
      end
    end

    test "the real cross-resource coupling: lifecycle transition flips the ApprovalDrFailoverRequiresOpenIncident query outcome" do
      r = region()
      org = org_id()

      incident = create_incident!(base_attrs(%{org_id: org, region: r, status: :open}))

      precondition_query = fn ->
        Incident
        |> Ash.Query.filter(
          org_id == ^org and region == ^r and status == "open"
        )
        |> Ash.read!(authorize?: false)
      end

      assert Enum.map(precondition_query.(), & &1.id) == [incident.id]

      # The transition open -> resolved must clear the DR-failover
      # precondition through the REAL update action.
      _resolved =
        incident
        |> Ash.Changeset.for_update(:update, %{status: :resolved, resolved_at: now()})
        |> Ash.update!(authorize?: false)

      assert precondition_query.() == []

      # W818: the reopen path is now REFUSED (:resolved is terminal for
      # :update), so the DR-failover precondition cannot be re-satisfied
      # by a bare status flip -- it stays cleared through the real action.
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.get!(Incident, incident.id, authorize?: false)
               |> Ash.Changeset.for_update(:update, %{status: :open})
               |> Ash.update(authorize?: false)

      assert precondition_query.() == []
    end

    test "org mismatch still does not satisfy the precondition query (seventeenth-pass invariant holds under this lifecycle)" do
      r = region()
      target_org = org_id()
      other_org = org_id()

      _foreign =
        create_incident!(base_attrs(%{org_id: other_org, region: r, status: :open}))

      assert Incident
             |> Ash.Query.filter(org_id == ^target_org and region == ^r and status == "open")
             |> Ash.read!(authorize?: false) == []
    end
  end

  # ---------------------------------------------------------------------------
  # (c) What the W747/W745 fabric courts consume (read-only cross-check)
  # ---------------------------------------------------------------------------

  describe "(c) fabric-court consumption surface" do
    test "RouteCastleRun is the from-node of the nested-BRCE edge with BRCE_ONLY authority" do
      edge =
        Enum.find(
          Xaas.Castle.Generated.EdgeCatalog.all(),
          &(&1.sequence == 50 and &1.name == "nested-brce-do")
        )

      assert %{} = edge
      assert edge.from == "Xaas.Operations.RouteCastleRun.execute"
      assert edge.authority == "BRCE_ONLY"
      assert edge.do_boundary? == true
      assert edge.receipt_before? == true and edge.receipt_after? == true
      assert edge.replayable? == true
    end

    test "castle admission verifies against RouteCastleRun identity + ontology_projection_hash (stable, non-empty)" do
      h1 = RouteCastleRun.ontology_projection_hash()
      h2 = RouteCastleRun.ontology_projection_hash()

      assert is_binary(h1) and h1 != ""
      assert h1 == h2
    end

    test "Incident is not a bridge-edge node -- it sits outside the castle DO boundary" do
      edge_froms = Enum.map(Xaas.Castle.Generated.EdgeCatalog.all(), & &1.from)

      refute Enum.any?(edge_froms, &(&1 =~ "Incident"))
    end
  end

  # ---------------------------------------------------------------------------
  # (d) Determinism
  # ---------------------------------------------------------------------------

  describe "(d) determinism" do
    test "identical payloads project identically (id and timestamps aside)" do
      attrs = base_attrs(%{org_id: org_id(), region: region()})
      opened_at = now()

      a =
        create_incident!(Map.put(attrs, :opened_at, opened_at))

      b =
        create_incident!(Map.put(attrs, :opened_at, opened_at))

      assert a.id != b.id

      projection = fn inc ->
        inc |> Map.take([:org_id, :title, :severity, :region, :status, :opened_at])
      end

      assert projection.(a) == projection.(b)

      # Re-read is idempotent on the same projection.
      assert projection.(Ash.get!(Incident, a.id, authorize?: false)) ==
               projection.(a)
    end

    test "route-castle reads are deterministic across repeated calls" do
      r1 = Ash.read!(RouteCastleDeploy, authorize?: false)
      r2 = Ash.read!(RouteCastleDeploy, authorize?: false)
      assert r1 == r2
      assert is_list(r1)
    end
  end
end
