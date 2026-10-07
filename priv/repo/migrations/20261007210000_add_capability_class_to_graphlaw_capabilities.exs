defmodule Xaas.Repo.Migrations.AddCapabilityClassToGraphlawCapabilities do
  @moduledoc """
  SPEC-09 (W731-GAP-1, W905 backlog; lane W912): adds the
  `capability_class` column to `graphlaw_capabilities`, nullable at the SQL
  layer with a backfill to `observe` (the Ash-side default), matching the
  resource attribute's `one_of [:observe, :select, :construct, :do]`
  constraint.
  """

  use Ecto.Migration

  def up do
    # Replay-safe (W971b): tolerate objects created by direct DDL.
    # Replay-safe (W971b): tolerate objects created by direct DDL.
    if column_exists?("graphlaw_capabilities", "capability_class") do
      :ok
    else
      alter table(:graphlaw_capabilities) do
        add :capability_class, :text
      end
    end

    execute("UPDATE graphlaw_capabilities SET capability_class = 'observe'")
  end

  def down do
    if column_exists?("graphlaw_capabilities", "capability_class") do
      alter table(:graphlaw_capabilities) do
        remove :capability_class
      end
    end
  end

  defp column_exists?(table, column) do
    repo().query!(
      "SELECT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = $1 AND column_name = $2)",
      [table, column]
    ).rows |> List.flatten() |> hd()
  end
end
