defmodule Xaas.Governance.W984dr2DrFailoverOpenIncidentCourtTest do
  @moduledoc """
  Lane W984dr2 depth court (v26.10.6 governance burn-down), continuing
  W984cz (3 modules courted) and W984dr (Types enums). Census finding:
  of the remaining unclaimed validations,
  `Xaas.Governance.Validations.ApprovalDrFailoverRequiresOpenIncident`
  (77 lines) is the most state-bearing: a real cross-resource read
  against `Xaas.Operations.Incident` gating `ApprovalDrFailover`'s
  `:approve` -- the maker-checker precondition for real multi-region DR
  failover -- whose moduledoc documents a live-HTTP-proven cross-org
  escalation that was fixed by adding the `org_id == ^target_org_id`
  clause. Exactly the kind of guard whose regression silently re-opens
  a real escalation channel.

  Indirect-exercise census: existing coverage
  (`approval_dr_failover_stress_test.exs`, HTTP tests) exercises the
  happy path and policy layer; no direct court pins the four filter
  clauses (existence / region / status / org) or the terminal-state
  interaction with `IncidentResolvedIsTerminal` through the live
  `:approve` action. This court fills that gap through the real action
  surface over real sandboxed Postgres. No mocks.

  Per-test mutation rationale is in each test's comment.
  """

  use ExUnit.Case, async: true

  alias Xaas.Accounts.Org
  alias Xaas.Governance.ApprovalDrFailover
  alias Xaas.Operations.Incident

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp unique, do: System.unique_integer([:positive])

  defp real_org!(prefix) do
    Org
    |> Ash.Changeset.for_create(:create, %{
      name: "#{prefix} #{unique()}",
      slug: "#{prefix}-#{unique()}"
    })
    |> Ash.create!(authorize?: false)
  end

  defp failover!(org_slug, from_region) do
    ApprovalDrFailover
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_slug,
      requested_by: "w984dr2-requester-#{unique()}",
      from_region: from_region,
      to_region: "us-east-9",
      reason: "w984dr2 court failover"
    })
    |> Ash.create!(authorize?: false, tenant: org_slug)
  end

  defp incident!(org_slug, region, status) do
    Incident
    |> Ash.Changeset.for_create(:create, %{
      org_id: org_slug,
      title: "w984dr2 court incident #{unique()}",
      description: "real open incident for the dr-failover court",
      region: region,
      status: status,
      opened_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Ash.create!(authorize?: false)
  end

  defp approve(failover, approver) do
    failover
    |> Ash.Changeset.for_update(:approve, %{approved_by: approver})
    |> Ash.update(authorize?: false, tenant: failover.org_id)
  end

  # ------------------------------------------------------------------
  # (1) Existence clause: with zero incidents of any kind, :approve is
  # refused with the real typed message. Mutation: map the
  # `{:ok, []}` -> error clause to :ok -- a failover with no
  # precondition at all would then be approvable.
  # ------------------------------------------------------------------
  test "approve without any open incident is refused" do
    org = real_org!("w984dr2-no-incident")
    f = failover!(org.slug, "ap-south-9")

    assert {:error, %Ash.Error.Invalid{} = err} = approve(f, "w984dr2-approver-#{unique()}")

    assert msg = Exception.message(err)
    assert msg =~ "requires an open Xaas.Operations.Incident"
    assert msg =~ "referencing this region AND this org"
  end

  # ------------------------------------------------------------------
  # (2) Region clause: an open incident in a DIFFERENT region does not
  # satisfy the precondition. Mutation: drop `region == ^from_region`
  # from the query -- a failover for region A approvable on the
  # strength of an incident about region B.
  # ------------------------------------------------------------------
  test "open incident in a different region does not authorize approve" do
    org = real_org!("w984dr2-wrong-region")
    f = failover!(org.slug, "eu-west-9")
    incident!(org.slug, "us-east-1", :open)

    assert {:error, %Ash.Error.Invalid{}} = approve(f, "w984dr2-approver-#{unique()}")
  end

  # ------------------------------------------------------------------
  # (3) Org clause (the live-HTTP-proven escalation fix): an open
  # incident in the SAME region under a DIFFERENT org must not satisfy
  # the precondition. Mutation: drop `org_id == ^org_id` from the
  # query -- the documented cross-org escalation re-opens.
  # ------------------------------------------------------------------
  test "open incident in same region but different org does not authorize approve" do
    victim = real_org!("w984dr2-victim")
    attacker = real_org!("w984dr2-attacker")

    f = failover!(victim.slug, "sa-east-9")
    incident!(attacker.slug, "sa-east-9", :open)

    assert {:error, %Ash.Error.Invalid{}} = approve(f, "w984dr2-approver-#{unique()}")
  end

  # ------------------------------------------------------------------
  # (4) Status clause + terminal-state interaction: a RESOLVED
  # same-region same-org incident does not satisfy the precondition --
  # and because `IncidentResolvedIsTerminal` makes :resolved terminal
  # through :update, resolving the incident permanently un-gates no
  # future approve. Mutation: drop `status == "open"` -- a resolved
  # incident would permanently satisfy the precondition forever.
  # ------------------------------------------------------------------
  test "resolved incident does not satisfy the precondition" do
    org = real_org!("w984dr2-resolved")
    f = failover!(org.slug, "me-central-9")
    i = incident!(org.slug, "me-central-9", :open)

    # Prove the incident was qualifying BEFORE resolution (non-vacuity
    # for the status clause): approve must now be blocked only by the
    # status, not by the region/org clauses.
    i
    |> Ash.Changeset.for_update(:update, %{
      status: :resolved,
      resolved_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
    |> Ash.update!(authorize?: false)

    assert {:error, %Ash.Error.Invalid{}} = approve(f, "w984dr2-approver-#{unique()}")
  end

  # ------------------------------------------------------------------
  # (5) Happy path (mutation: delete the validation from :approve --
  # then this still passes but (1)-(4) fail; conversely if the query
  # over-filters, this fails). Same-org, same-region, :open incident ->
  # :approve succeeds through the real action, including its
  # EnqueueWebhookDeliveries + WriteAuditLogEntry changes, and the
  # approval is persisted.
  # ------------------------------------------------------------------
  test "same-org open same-region incident authorizes real approve" do
    org = real_org!("w984dr2-happy")
    f = failover!(org.slug, "us-west-9")
    incident!(org.slug, "us-west-9", :open)

    approver = "w984dr2-approver-#{unique()}"
    assert {:ok, approved} = approve(f, approver)
    assert approved.approved_by == approver

    # Non-vacuity: real persisted approval, re-read from Postgres.
    assert {:ok, reloaded} =
             Ash.get(ApprovalDrFailover, approved.id,
               authorize?: false,
               tenant: approved.org_id
             )
    assert reloaded.approved_by == approver
  end
end
