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
    # required by Xaas.Library.Book's `vectorize` block. Real fix landed:
    # compose.yaml's db service now runs pgvector/pgvector:pg15 (was plain
    # postgres:15.2, which had no vector extension binary at all -- CREATE
    # EXTENSION vector failed with "extension \"vector\" is not available").
    # Also required: lib/xaas/postgrex_types.ex (a real Postgrex.Types.define/3
    # module) + `types: Xaas.PostgrexTypes` in config/{dev,test}.exs's
    # `config :xaas, Xaas.Repo` -- without that, Postgrex.DefaultTypes still
    # can't encode/decode the `vector` wire type even once the Postgres
    # extension itself is installed.
    ["ash-functions", "citext", "vector", AshMoney.AshPostgresExtension]
  end
end
