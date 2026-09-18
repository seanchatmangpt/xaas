defmodule Mix.Tasks.Xaas.InternalApiToken do
  @moduledoc """
  Real operator entry point for minting/listing/revoking
  `Xaas.Governance.InternalApiToken` rows -- the rotation-capable
  replacement for hand-editing the single, flat `INTERNAL_API_TOKEN` env
  var and redeploying. See that resource's moduledoc for the full,
  disclosed rationale (why it exists, why it has no HTTP routes, how the
  plug's fallback keeps dev mode working).

  Usage:

      mix xaas.internal_api_token issue <created_by> [--expires-in-days N] [--org <slug-or-id>]
      mix xaas.internal_api_token list
      mix xaas.internal_api_token revoke <token_id>

  `issue` prints the raw bearer token exactly once -- it is never stored
  and can never be recovered again after this command returns. Copy it
  into wherever the caller (a CI secret, a provider worker's env, an
  operator's own shell) needs it immediately.

  `--org` (real, optional, added this pass): mints a real per-org token --
  e.g. `mix xaas.internal_api_token issue "customer-acme" --org acme-corp`
  resolves `acme-corp` against a real `Xaas.Accounts.Org` (by `slug`, or by
  `id`) and stores it as this token's `org_id`. Omitted, `issue` mints the
  original internal/admin-tier token (`org_id: nil`), unchanged from
  before this pass -- see `Xaas.Governance.InternalApiToken`'s moduledoc
  for the full disclosure.
  """
  use Mix.Task

  alias Xaas.Governance.InternalApiToken
  alias Xaas.Governance.InternalApiTokenAuth

  @shortdoc "Mint, list, or revoke a rotatable /internal-api bearer token"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, rest, _invalid} =
      OptionParser.parse(args, strict: [expires_in_days: :integer, org: :string])

    case rest do
      ["issue", created_by | _] -> issue(created_by, opts[:expires_in_days], opts[:org])
      ["list"] -> list()
      ["revoke", token_id | _] -> revoke(token_id)
      _ -> usage!()
    end
  end

  defp issue(created_by, expires_in_days, org) do
    expires_at =
      case expires_in_days do
        nil -> nil
        days when is_integer(days) and days > 0 -> DateTime.add(DateTime.utc_now(), days, :day)
      end

    case InternalApiTokenAuth.issue(created_by, expires_at, org) do
      {:ok, raw_token, token} ->
        Mix.shell().info("""
        Minted a new InternalApiToken:

          id:          #{token.id}
          created_by:  #{token.created_by}
          org_id:      #{inspect(token.org_id)}
          expires_at:  #{inspect(token.expires_at)}
          prefix:      #{token.token_prefix}

        Raw bearer token (shown exactly once, never stored -- copy it now):

          #{raw_token}
        """)

      {:error, {:org_not_found, org}} ->
        Mix.shell().error("Could not mint token: no Org found matching #{inspect(org)}")

      {:error, error} ->
        Mix.shell().error("Could not mint token: #{inspect(error)}")
    end
  end

  defp list do
    case Ash.read(InternalApiToken, authorize?: false) do
      {:ok, []} ->
        Mix.shell().info("No InternalApiToken rows exist yet.")

      {:ok, tokens} ->
        Mix.shell().info("#{length(tokens)} InternalApiToken row(s):\n")

        Enum.each(tokens, fn token ->
          status =
            cond do
              token.revoked_at ->
                "revoked at #{token.revoked_at}"

              token.expires_at && DateTime.compare(token.expires_at, DateTime.utc_now()) != :gt ->
                "expired at #{token.expires_at}"

              true ->
                "active"
            end

          Mix.shell().info("""
          id:          #{token.id}
          created_by:  #{token.created_by}
          org_id:      #{inspect(token.org_id)}
          prefix:      #{token.token_prefix}
          expires_at:  #{inspect(token.expires_at)}
          status:      #{status}
          """)
        end)

      {:error, error} ->
        Mix.shell().error("Could not list tokens: #{inspect(error)}")
    end
  end

  defp revoke(token_id) do
    with {:ok, token} <- Ash.get(InternalApiToken, token_id, authorize?: false),
         {:ok, revoked} <- InternalApiTokenAuth.revoke(token) do
      Mix.shell().info(
        "Revoked InternalApiToken #{revoked.id} (created_by: #{revoked.created_by}) at #{revoked.revoked_at}."
      )
    else
      {:error, error} -> Mix.shell().error("Could not revoke #{token_id}: #{inspect(error)}")
    end
  end

  defp usage! do
    Mix.raise("""
    usage:
      mix xaas.internal_api_token issue <created_by> [--expires-in-days N] [--org <slug-or-id>]
      mix xaas.internal_api_token list
      mix xaas.internal_api_token revoke <token_id>
    """)
  end
end
