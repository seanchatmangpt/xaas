defmodule Xaas.Governance.Validations.FreezeWindowEndsAfterStarts do
  @moduledoc """
  Real business rule for `Xaas.Governance.FreezeWindow`'s `:create`
  action, matching platform-console's real
  `validateFreezeWindowInput` (`lib/freeze-windows.ts`): `endsAt` must be
  strictly after `startsAt`.
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, _context) do
    starts_at = Ash.Changeset.get_attribute(changeset, :starts_at)
    ends_at = Ash.Changeset.get_attribute(changeset, :ends_at)

    cond do
      is_nil(starts_at) or is_nil(ends_at) ->
        :ok

      DateTime.compare(ends_at, starts_at) != :gt ->
        {:error, field: :ends_at, message: "must be after starts_at"}

      true ->
        :ok
    end
  end
end
