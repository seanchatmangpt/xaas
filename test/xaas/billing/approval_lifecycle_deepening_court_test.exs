defmodule Xaas.Billing.ApprovalLifecycleDeepeningCourtTest do
  @moduledoc """
  Lane W982s -- billing approval-surface LIFECYCLE deepening court.
  Real Postgres (`Ecto.Adapters.SQL.Sandbox` + `Xaas.Repo`), no mocks.
  Independent of (and not duplicating) the landed multitenancy court
  (`test/xaas/billing/billing_multitenancy_court_test BillingMultitenancyCourtTest`,
  W970a) and W982p's in-flight multitenancy completion: this court probes
  the approval LIFECYCLE invariants on all 6 billing `Approval*`
  resources (the SPEC-07 "8" includes `Subscription` and
  `RevenueRecognition`, which carry no approval lifecycle -- noted
  report-only in the W982s receipt):

    1. state-machine integrity: re-approving an already-approved record
       (the only transition these resources model -- there is no
       `:status` attribute on any of the 6, `approved_by` nil->set is the
       state machine) must refuse with the real typed error;
    2. approver-self-approval must be refused typed where the
       RequiresApprover validation exists;
    3. double-approve race (Task.async x2, real Postgres WHERE
       semantics): exactly one success where a DB-level guard exists;
    4. tenant isolation post-W970a/W982p using DIFFERENT verbs than the
       multitenancy court (read + update(:approve) here; the :delete
       verb is not exposed on any of the 6 -- introspected in 0b).

  FINDING WITNESS tests (explicitly labeled) pin CURRENT behavior where
  a resource lacks a guard, per the report-only lane instruction: they
  are witnesses of a typed finding, not endorsements. If a later lane
  lands the missing guard, the witness fails and must be flipped with
  the fix.

  Falsifier (per test, stated in place).
  """

  use ExUnit.Case, async: false

  # async: false for the same real, disclosed reason as the sibling
  # approval suites (approval_sla_credit_apply_test.exs /
  # approval_tier_downgrade_test.exs): this file writes real
  # Xaas.Ledger rows (sla_credit approves, tier_downgrade prorate), and
  # AshEvents' single global advisory lock + open sandbox transactions
  # under async: true caused the full-suite Postgres deadlock flake.

  @resources [
    Xaas.Billing.ApprovalPricingOverride,
    Xaas.Billing.ApprovalQuotaOverride,
    Xaas.Billing.ApprovalInvoiceReconciliationApprove,
    Xaas.Billing.ApprovalPatchSlaCreditApply,
    Xaas.Billing.ApprovalSlaCreditApply,
    Xaas.Billing.ApprovalTierDowngrade
  ]

  @requires_approver [
    {Xaas.Billing.ApprovalPricingOverride,
     Xaas.Billing.Validations.ApprovalPricingOverrideRequiresApprover},
    {Xaas.Billing.ApprovalQuotaOverride, Xaas.Billing.Validations.ApprovalQuotaOverrideRequiresApprover},
    {Xaas.Billing.ApprovalInvoiceReconciliationApprove,
     Xaas.Billing.Validations.ApprovalInvoiceReconciliationApproveRequiresApprover},
    {Xaas.Billing.ApprovalPatchSlaCreditApply,
     Xaas.Billing.Validations.ApprovalPatchSlaCreditApplyRequiresApprover},
    {Xaas.Billing.ApprovalSlaCreditApply,
     Xaas.Billing.Validations.ApprovalSlaCreditApplyRequiresApprover},
    {Xaas.Billing.ApprovalTierDowngrade,
     Xaas.Billing.Validations.ApprovalTierDowngradeRequiresApprover}
  ]

  @sla_resources [Xaas.Billing.ApprovalPatchSlaCreditApply, Xaas.Billing.ApprovalSlaCreditApply]

  # Resources whose :approve carries a real DB-level transition guard
  # against re-approval (the `filter(expr(is_nil(approved_by)))`
  # WHERE-clause filter, W746 corrected contract). W984k landed the guard
  # on the 4 W982s finding-1b resources (pricing_override, quota_override,
  # invoice_reconciliation_approve, patch_sla_credit_apply); tier_downgrade
  # remains only incidentally guarded downstream. 1b/3b now assert the
  # guarded contract on the fixed set (flipped from W982s finding pins).
  @db_transition_guarded [
    Xaas.Billing.ApprovalPricingOverride,
    Xaas.Billing.ApprovalQuotaOverride,
    Xaas.Billing.ApprovalInvoiceReconciliationApprove,
    Xaas.Billing.ApprovalPatchSlaCreditApply
  ]

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # ------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------

  defp create_org!(suffix) do
    slug = "w982s-#{suffix}-#{System.unique_integer([:positive])}"

    Xaas.Accounts.Org
    |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
    |> Ash.create!()
  end

  defp fixture(resource, tenant_id, requested_by) do
    extra =
      cond do
        resource in @sla_resources ->
          %{credit_amount_cents: 1000}

        resource == Xaas.Billing.ApprovalTierDowngrade ->
          sub =
            Xaas.Billing.Subscription
            |> Ash.Changeset.for_create(
              :create,
              %{
                org_id: tenant_id,
                tier: :pro,
                stripe_customer_id: "cus_#{System.unique_integer([:positive])}",
                stripe_subscription_id: "sub_#{System.unique_integer([:positive])}"
              },
              authorize?: false
            )
            |> Ash.create!()

          %{subscription_id: sub.id, requested_tier: :standard}

        true ->
          %{}
      end

    resource
    |> Ash.Changeset.for_create(
      :create,
      extra |> Map.put(:requested_by, requested_by) |> Map.put(:org_id, tenant_id),
      tenant: tenant_id,
      authorize?: false
    )
    |> Ash.create!()
  end

  defp approve(record, approver) do
    record
    |> Ash.Changeset.for_update(:approve, %{approved_by: approver})
    |> Ash.update(authorize?: false)
  end

  defp approve!(record, approver) do
    record
    |> Ash.Changeset.for_update(:approve, %{approved_by: approver})
    |> Ash.update!(authorize?: false)
  end

  # Zero-row UPDATE semantics under Ash 3.34: the typed error for a
  # WHERE-clause filter that matches nothing is StaleRecord (Invalid
  # class); older shapes surfaced NotFound. Both are the real typed
  # zero-row refusal, so classify either.
  defp zero_row_error?(errors) do
    Enum.any?(errors, fn e ->
      match?(%Ash.Error.Changes.StaleRecord{}, e) or match?(%Ash.Error.Query.NotFound{}, e)
    end)
  end

  defp classify_errors(errors) do
    if zero_row_error?(errors), do: :invalid_zero_row, else: :invalid_other
  end

  # Two real :approve tasks, serialized onto the sandbox connection via
  # allow/3 + a barrier (same disclosed Sandbox model as
  # approval_sla_credit_apply_test.exs: allowed processes multiplex onto
  # the SAME physical connection/transaction, so true concurrent-race
  # semantics are not reproducible here -- what IS real is the second
  # UPDATE's WHERE-clause semantics against the already-approved row in
  # real Postgres). Each task re-fetches its own record first.
  defp race_two_approves(resource, record, approvers) do
    parent = self()
    tenant = record.org_id

    tasks =
      for approver <- approvers do
        Task.async(fn ->
          receive do
            :go -> :ok
          end

          try do
            fresh = Ash.get!(resource, record.id, tenant: tenant, authorize?: false)
            {:ok, approve!(fresh, approver)}
          rescue
            e in Ash.Error.Invalid -> {:refused, classify_errors(e.errors)}
          end
        end)
      end

    Enum.each(tasks, &Ecto.Adapters.SQL.Sandbox.allow(Xaas.Repo, parent, &1.pid))
    Enum.each(tasks, &send(&1.pid, :go))

    results =
      Enum.map(tasks, fn task ->
        case Task.yield(task, 15_000) do
          {:ok, result} -> result
          other -> {:crashed, other}
        end
      end)

    Enum.zip(approvers, results)
  end

  # ------------------------------------------------------------------
  # 0. Schema court (introspection)
  # ------------------------------------------------------------------

  test "0a. each approval resource has an :approve action carrying its own RequiresApprover validation" do
    for {resource, validation} <- @requires_approver do
      action = Ash.Resource.Info.action(resource, :approve)

      assert action != nil, "#{inspect(resource)} lost its :approve action"

      # Minimal unblock fix (lane W982p, compile-freeze SLA): the original
      # called an undefined `validation_modules/1` and could not compile,
      # freezing the whole test/xaas/billing dir. Action-scoped validations
      # introspect via the action's changes list -- `validate ...` inside an
      # action compiles to an `Ash.Resource.Validation` wrapper in
      # `action.changes`, not a function or a `cs.validations` field.
      validation_modules =
        action.changes
        |> Enum.filter(&(&1.__struct__ == Ash.Resource.Validation))
        |> Enum.map(&elem(&1.validation, 0))

      assert validation in validation_modules,
             "#{inspect(resource)} :approve no longer validates with #{inspect(validation)} " <>
               "(found: #{inspect(validation_modules)})"
    end
  end

  test "0b. no approval resource exposes a :destroy action (delete verb absent -- FINDING witness)" do
    for resource <- @resources do
      assert Ash.Resource.Info.action(resource, :destroy) == nil,
             "#{inspect(resource)} gained a :destroy action -- re-run the delete-verb " <>
               "isolation probe and update the W982s receipt"
    end
  end

  # ------------------------------------------------------------------
  # 1. State-machine integrity (transition guards)
  # ------------------------------------------------------------------

  test "1a. re-approval is refused typed (Invalid + NotFound) where the DB-level guard exists" do
    org = create_org!("trans-guard")
    resource = Xaas.Billing.ApprovalSlaCreditApply

    record = fixture(resource, org.id, "req-trans-guard")

    assert {:ok, first} = approve(record, "approver-a")
    assert first.approved_by == "approver-a"

    # Stale in-memory record, fresh re-approve: the WHERE-clause filter
    # (W746 corrected contract) matches zero rows -> typed NotFound.
    assert {:error, %Ash.Error.Invalid{} = err} = approve(first, "approver-b")

    assert zero_row_error?(err.errors),
           "expected a typed zero-row error in #{inspect(err.errors)}"

    reloaded = Ash.reload!(first, authorize?: false)
    assert reloaded.approved_by == "approver-a"
  end

  # FLIPPED (W984k, was W982s finding-1b witness): the 4 previously
  # unguarded resources now carry the W746 DB-level transition guard, so
  # re-approval with a distinct second approver through a stale in-memory
  # record must be refused typed zero-row, and the first approval must
  # survive un-overwritten.
  test "1b. re-approval is refused typed on every W984k-guarded resource" do
    for resource <- @db_transition_guarded do
      org = create_org!("trans-guarded")
      record = fixture(resource, org.id, "req-trans-guarded")

      assert {:ok, first} = approve(record, "approver-a")
      assert first.approved_by == "approver-a"

      assert {:error, %Ash.Error.Invalid{} = err} = approve(first, "approver-b")

      assert zero_row_error?(err.errors),
             "expected typed zero-row refusal on re-approve for #{inspect(resource)}, " <>
               "got #{inspect(err.errors)}"

      reloaded = Ash.reload!(record, authorize?: false)
      assert reloaded.approved_by == "approver-a",
             "#{inspect(resource)} re-approval overwrote approved_by"
    end
  end

  # ------------------------------------------------------------------
  # 2. Approver-self-approval
  # ------------------------------------------------------------------

  test "2. self-approval is refused typed on every approval resource" do
    for resource <- @resources do
      org = create_org!("self")
      record = fixture(resource, org.id, "req-self")

      assert {:error, %Ash.Error.Invalid{} = err} = approve(record, "req-self")

      assert Enum.any?(err.errors, &match?(%{field: :approved_by}, &1)),
             "expected an :approved_by validation error on #{inspect(resource)}, " <>
               "got #{inspect(err.errors)}"

      reloaded = Ash.reload!(record, authorize?: false)
      assert reloaded.approved_by == nil
    end
  end

  # ------------------------------------------------------------------
  # 3. Double-approve race (real Postgres WHERE semantics under Sandbox)
  # ------------------------------------------------------------------

  test "3a. double-approve race: exactly one success where the DB-level guard exists" do
    org = create_org!("race-guarded")
    resource = Xaas.Billing.ApprovalSlaCreditApply
    record = fixture(resource, org.id, "req-race")

    results = race_two_approves(resource, record, ["race-approver-1", "race-approver-2"])

    oks = Enum.count(results, fn {_a, r} -> match?({:ok, _}, r) end)

    assert oks == 1,
           "expected exactly one race success on #{inspect(resource)}, got #{inspect(results)}"

    assert Enum.any?(results, fn {_a, r} -> r == {:refused, :invalid_zero_row} end),
           "expected the race loser refused typed zero-row error, got #{inspect(results)}"

    # Exactly one real approval persisted, under whichever approver won.
    reloaded = Ash.reload!(record, authorize?: false)
    assert reloaded.approved_by in ["race-approver-1", "race-approver-2"]
  end

  # FLIPPED (W984k, was W982s finding-3b witness): with the W746 guard in
  # the UPDATE's WHERE clause, the double-approve race yields exactly one
  # success; the loser is refused typed zero-row and exactly one approval
  # persists.
  test "3b. double-approve race: exactly one success on every W984k-guarded resource" do
    for resource <- @db_transition_guarded do
      org = create_org!("race-guarded-w984k")
      record = fixture(resource, org.id, "req-race-w984k")

      results = race_two_approves(resource, record, ["race-w984k-1", "race-w984k-2"])

      assert length(results) == 2

      oks = Enum.count(results, fn {_a, r} -> match?({:ok, _}, r) end)

      assert oks == 1,
             "expected exactly one race success on #{inspect(resource)}, got #{inspect(results)}"

      assert Enum.any?(results, fn {_a, r} -> r == {:refused, :invalid_zero_row} end),
             "expected the race loser refused typed zero-row on #{inspect(resource)}, " <>
               "got #{inspect(results)}"

      reloaded = Ash.reload!(record, authorize?: false)
      assert reloaded.approved_by in ["race-w984k-1", "race-w984k-2"]
    end
  end

  # ------------------------------------------------------------------
  # 4. Tenant isolation post-W970a/W982p -- read + update verbs
  # ------------------------------------------------------------------

  test "4a. cross-tenant read and update(:approve) are hard-refused typed, per resource" do
    for resource <- @resources do
      org_a = create_org!("iso-a")
      org_b = create_org!("iso-b")

      record_a = fixture(resource, org_a.id, "req-iso-a")

      # Read verb: cross-tenant Ash.get! refused typed (hard filter).
      assert_raise Ash.Error.Invalid, fn ->
        Ash.get!(resource, record_a.id, tenant: org_b.id, authorize?: false)
      end

      # Update verb (NEW vs the multitenancy court's read-only probe): a
      # cross-tenant :approve must also be refused -- the tenant filter
      # lands in the UPDATE's WHERE clause, zero rows -> typed NotFound.
      assert {:error, %Ash.Error.Invalid{} = err} =
               record_a
               |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-iso-b"},
                 tenant: org_b.id, authorize?: false
               )
               |> Ash.update()

      assert zero_row_error?(err.errors),
             "expected typed zero-row refusal on cross-tenant :approve for #{inspect(resource)}, " <>
               "got #{inspect(err.errors)}"

      # Untouched: no approval persisted, no side effects.
      reloaded = Ash.reload!(record_a, authorize?: false)
      assert reloaded.approved_by == nil

      # The owner can still really approve it afterwards.
      assert {:ok, approved} =
               record_a
               |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-iso-a"},
                 tenant: org_a.id, authorize?: false
               )
               |> Ash.update()

      assert approved.approved_by == "approver-iso-a"
    end
  end

  test "4b. cross-tenant update from a stale foreign-tenant record is refused typed, per resource" do
    for resource <- @resources do
      org_a = create_org!("iso-stale-a")
      org_b = create_org!("iso-stale-b")

      record_a = fixture(resource, org_a.id, "req-iso-stale")

      # The stale caller binds org_b's tenant on an org_a row: the tenant
      # filter must win over the in-memory record identity.
      assert {:error, %Ash.Error.Invalid{}} =
               record_a
               |> Ash.Changeset.for_update(:approve, %{approved_by: "approver-stale"},
                 tenant: org_b.id, authorize?: false
               )
               |> Ash.update()

      reloaded = Ash.reload!(record_a, authorize?: false)
      assert reloaded.approved_by == nil
    end
  end
end
