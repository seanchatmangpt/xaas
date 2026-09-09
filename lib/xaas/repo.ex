defmodule Xaas.Repo do
  use AshPostgres.Repo, otp_app: :xaas

  def min_pg_version do
    %Version{major: 14, minor: 19, patch: 0}
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  def prefer_transaction? do
    false
  end

  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    #
    # "vector" (AshPostgres.Extensions.Vector, confirmed supported) is
    # required by Xaas.Library.Book's `vectorize` block -- BLOCKED at
    # runtime: the running dev Postgres has zero rows for 'vector' in
    # pg_available_extensions, so CREATE EXTENSION vector fails until the
    # Postgres image/host ships the pgvector extension binary (e.g.
    # pgvector/pgvector). See Xaas.Library.Book's moduledoc for detail.
    ["ash-functions", "citext", "vector", AshMoney.AshPostgresExtension]
  end
end
