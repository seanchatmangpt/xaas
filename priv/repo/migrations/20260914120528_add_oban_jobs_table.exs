defmodule Xaas.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  @moduledoc """
  ULTRACODE-50 milestone (2026-09-14): real finding — `config :xaas, Oban`
  existed and 4 resources declare AshOban `scheduled_actions`/`triggers`,
  but `Oban.Migrations.up/0`/`down/0` had never been invoked anywhere in
  this repo's migration history. Confirmed via `Oban.start_link/1` itself
  refusing to boot: "Oban migrations have not been run. The oban_jobs
  table does not exist." Without this migration, `{Oban, ...}` (just
  added to `lib/xaas/application.ex`) cannot start in ANY environment,
  making the whole "add Oban to the supervision tree" fix inert.
  """

  def up, do: Oban.Migrations.up()

  # Intentionally do not provide a default down function, as up/1 always
  # migrates to the latest version.
  def down, do: Oban.Migrations.down(version: 1)
end
