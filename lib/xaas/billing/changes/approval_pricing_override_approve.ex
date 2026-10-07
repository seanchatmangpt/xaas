defmodule Xaas.Billing.Changes.ApprovalPricingOverrideApprove do
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def change(changeset, _opts, _context) do
    changeset
  end

  @impl true
  # SPEC-08 / W729-GAP-4 (lane W984cc): no-op stub -- trivially
  # atomic-compatible so :approve can run atomically after
  # require_atomic?(false) was dropped.
  def atomic(changeset, _opts, _context) do
    {:ok, changeset}
  end
end
