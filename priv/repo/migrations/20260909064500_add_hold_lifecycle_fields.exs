defmodule Xaas.Repo.Migrations.AddHoldLifecycleFields do
  @moduledoc """
  Adds the expires_at/fulfilled_at/cancelled_at timestamps needed for the
  Xaas.Library.HoldRequest place/fulfill/cancel/expire lifecycle, and widens
  the status constraint to include :expired.
  """
  use Ecto.Migration

  def up do
    alter table(:library_holds) do
      add :expires_at, :utc_datetime_usec
      add :fulfilled_at, :utc_datetime_usec
      add :cancelled_at, :utc_datetime_usec
    end
  end

  def down do
    alter table(:library_holds) do
      remove :expires_at
      remove :fulfilled_at
      remove :cancelled_at
    end
  end
end
