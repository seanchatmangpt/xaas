defmodule XaasWeb.ApprovalCausalAnatomyControllerTest do
  @moduledoc """
  Chicago court for WP-1 (OS-15, EU AI Act Art. 14(4)(b)): the operator
  authorization surface carries the causal anatomy of the decision being
  approved.

  Two real registers, no mocking:

    1. HTTP: real Phoenix `PATCH /api/approval_sla_credit_apply/:id`
       requests through the real router, real Ash `:approve` action against
       the real sandboxed Postgres, asserting on the real decoded response
       document — specifically the new top-level `meta.causal_anatomy`
       member (W505 exact Shapley attribution + W506 counterfactual trace +
       W984p briefing, composed by `Xaas.Operations.ApprovalCausalAnatomy`).
    2. Module: the anatomy computation over a real REFUSED decision
       (self-approval) — real nonzero Shapley blame, real refusal anatomy,
       real counterfactual replay naming the flipping check — and the typed
       degrade contract for missing-anatomy input.
  """

  use XaasWeb.ConnCase

  alias Xaas.Billing.ApprovalSlaCreditApply
  alias Xaas.Operations.ApprovalCausalAnatomy

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_org_headers(conn, org_id) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("x-org-id", org_id)
  end

  defp real_org_slug! do
    Xaas.Generator.create_org!().slug
  end

  defp create_pending!(requested_by, org_id) do
    Xaas.Generator.pending_approval!(ApprovalSlaCreditApply, :create, %{
      requested_by: requested_by,
      org_id: org_id,
      credit_amount_cents: 1000
    })
  end

  test "PATCH :approve response carries the causal anatomy block for the approved decision", %{
    conn: conn
  } do
    org_id = real_org_slug!()
    requester = "requester-#{System.unique_integer([:positive])}"
    approver = "approver-#{System.unique_integer([:positive])}"
    pending = create_pending!(requester, org_id)

    body = %{
      "data" => %{
        "type" => "approval_sla_credit_apply",
        "attributes" => %{"approved_by" => approver}
      }
    }

    conn =
      conn
      |> with_org_headers(org_id)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> patch("/api/approval_sla_credit_apply/#{pending.id}", body)

    assert conn.status == 200

    response = json_response(conn, 200)
    assert response["data"]["attributes"]["approved_by"] == approver

    anatomy = response["meta"]["causal_anatomy"]
    assert anatomy, "expected meta.causal_anatomy in the approve response document"
    assert anatomy["available"] == true

    briefing = anatomy["briefing"]
    assert briefing["verdict"] == "admit"
    assert length(briefing["per_check_causes"]) == 5

    # Real attribution values: every check name is present with a numeric
    # exact-Shapley value (all pass => v(N)=1=v(∅) => all phi zero, the
    # real admitted-anatomy shape).
    names = Enum.map(briefing["per_check_causes"], & &1["name"])
    assert "approver_present" in names
    assert "approver_differs" in names
    assert "not_already_approved" in names
    assert "credit_amount_positive" in names
    assert "org_bound" in names

    Enum.each(briefing["per_check_causes"], fn cause ->
      assert is_number(cause["shapley"])
      assert cause["verdict"] == "pass"
    end)

    assert briefing["refusal_anatomy"] == []
    assert briefing["counterfactual_available"] == true
    assert briefing["interpretability"] =~ "Shapley"

    # Full admit => nothing to repair => no counterfactual replay.
    assert anatomy["counterfactual"] == nil
  end

  test "module anatomy over a real REFUSED decision: nonzero Shapley blame, refusal anatomy, counterfactual flip", %{
    conn: _conn
  } do
    org_id = real_org_slug!()
    requester = "requester-#{System.unique_integer([:positive])}"

    intent = %{
      requested_by: requester,
      approved_by: requester,
      already_approved?: false,
      credit_amount_cents: 1000,
      org_id: org_id
    }

    assert {:ok, %{briefing: briefing, counterfactual: cf}} = ApprovalCausalAnatomy.anatomy(intent)

    assert briefing.verdict == :refuse

    # Exact Shapley blame: the refusing check carries real nonzero blame.
    by_name = Map.new(briefing.per_check_causes, fn c -> {c.name, c} end)
    self = Map.fetch!(by_name, :approver_differs)
    assert self.verdict == :fail
    assert self.refusal == :self_approval
    assert self.shapley < 0

    assert briefing.refusal_anatomy == [%{name: :approver_differs, refusal: :self_approval}]
    assert briefing.counterfactual_available == true

    # Art. 86 trace: repairing the approver flips exactly the failing check.
    assert cf.outcome == :admitted
    assert cf.changed? == true
    assert cf.explanation =~ "approver_differs"
  end

  test "module anatomy over an already-approved decision: counterfactual honestly stays refused", %{
    conn: _conn
  } do
    org_id = real_org_slug!()
    requester = "requester-#{System.unique_integer([:positive])}"

    intent = %{
      requested_by: requester,
      approved_by: "approver-#{System.unique_integer([:positive])}",
      already_approved?: true,
      credit_amount_cents: 1000,
      org_id: org_id
    }

    assert {:ok, %{briefing: briefing, counterfactual: cf}} = ApprovalCausalAnatomy.anatomy(intent)
    assert briefing.verdict == :refuse

    by_name = Map.new(briefing.per_check_causes, fn c -> {c.name, c} end)
    assert Map.fetch!(by_name, :not_already_approved).refusal == :already_approved

    # No single-approver repair flips an already-made decision.
    assert cf.outcome == {:refused, :already_approved}
    assert cf.changed? == false
  end

  test "missing-anatomy input refuses typed; HTTP metadata adapter degrades with the typed reason", %{
    conn: _conn
  } do
    incomplete = %{requested_by: "r", approved_by: "a", already_approved?: false}

    assert {:error, {:missing_intent, missing}} = ApprovalCausalAnatomy.anatomy(incomplete)
    assert missing == [:credit_amount_cents, :org_id]

    # Non-map input also refuses typed.
    assert {:error, {:missing_intent, [:not_a_map]}} = ApprovalCausalAnatomy.anatomy("nope")

    # The metadata adapter always builds the full 5-key intent (it is the
    # resource adapter, the keys come from the record), so the missing-intent
    # typed refusal lives at the module boundary. Its real visible effect on
    # the surface is a degraded-but-typed anatomy: a record with a nil
    # amount yields a real REFUSED briefing (amount_not_positive), never a
    # crash or an unexplained admit.
    record = %{
      requested_by: "r",
      approved_by: "a",
      credit_amount_cents: nil,
      org_id: "some-org"
    }

    meta = ApprovalCausalAnatomy.metadata(record)
    # Direct call (not JSON round-tripped): the adapter envelope is
    # string-keyed (the wire shape); the briefing payload keeps the module's
    # atom keys. The HTTP test above proves the serialized string-keyed shape.
    assert %{"causal_anatomy" => %{"available" => true, "briefing" => briefing}} = meta
    assert briefing.verdict == :refuse

    refusal =
      Enum.find(briefing.refusal_anatomy, fn a -> a.refusal == :amount_not_positive end)

    assert refusal.name == :credit_amount_positive
  end
end
