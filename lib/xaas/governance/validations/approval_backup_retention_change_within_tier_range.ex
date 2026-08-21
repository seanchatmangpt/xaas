defmodule Xaas.Governance.Validations.ApprovalBackupRetentionChangeWithinTierRange do
  @moduledoc """
  Real per-tier retention-range validation, ported verbatim from
  platform-console's `RETENTION_RANGE` (`app/lib/backup-retention.ts`):

      starter:    1-7 days
      pro:        7-90 days
      enterprise: 30-2555 days (2555 = 7 years, SEC 17a-4 / SOX)

  platform-console's own `setBackupPolicy`/`isRetentionDaysAllowed` hard-
  rejects an out-of-range value rather than billing for it -- this
  validation does the same: a real 400-shaped rejection, not a fee.
  """
  use Ash.Resource.Validation

  @retention_range %{
    starter: {1, 7},
    pro: {7, 90},
    enterprise: {30, 2555}
  }

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    tier = Ash.Changeset.get_attribute(changeset, :tier)
    days = Ash.Changeset.get_attribute(changeset, :requested_retention_days)

    case Map.fetch(@retention_range, tier) do
      {:ok, {min_days, max_days}} ->
        if is_integer(days) and days >= min_days and days <= max_days do
          :ok
        else
          {:error,
           field: :requested_retention_days,
           message:
             "must be an integer between #{min_days} and #{max_days} for tier '#{tier}'"}
        end

      :error ->
        {:error, field: :tier, message: "is required to validate a retention range"}
    end
  end
end
