defmodule Xaas.Ultracode.CapabilityResolver.Source.Sa2a do
  @moduledoc """
  The SA2A / cross-fleet HTTP capability source of the resolution court:
  asks a configured SA2A fleet endpoint what capabilities the WIDER fleet
  already holds for one sensed item.

  Driven entirely by config -- `config :xaas,
  :ultracode_sa2a_capability_endpoint` (a URL string). Unset (the
  default) => `{:skipped, :not_configured}`: the court fail-closes to
  `:unresolved` under the default full-closure mode rather than mint a
  `:frontier` verdict over a closure it could not fully see.

  Protocol (one POST per item, `Req` + the repo's existing Finch pool):

      POST <endpoint>
      {"item_id": "...", "requirements": ["recipe:mix-format"]}

      200 {"capabilities": [{"capability_id": "recipe:mix-format",
                             "satisfies": ["recipe:mix-format"]}]}

  The response body's capability list is returned raw; the COURT re-admits
  every candidate (`CapabilityResolver.admit_candidates/2`), so this
  source adds only transport-shape refusals:

    * non-200 => `{:error, {:sa2a_status, status}}`
    * malformed body (not an object, no object `capabilities` list) =>
      `{:error, :sa2a_body_malformed}`

  A transport exception (timeout, conn refused, DNS) => `{:error, term}`.
  Every error path is the court's fail-closed path: the wider fleet was
  known to be configured but could not be witnessed, so no verdict that
  presumes its absence is lawful.
  """

  @behaviour Xaas.Ultracode.CapabilityResolver.Source

  @timeout_ms 5_000

  @impl true
  def candidates(item, _ctx) do
    case Application.get_env(:xaas, :ultracode_sa2a_capability_endpoint) do
      nil ->
        {:skipped, :not_configured}

      endpoint when is_binary(endpoint) ->
        request(endpoint, item)

      other ->
        {:error, {:invalid_endpoint_config, other}}
    end
  end

  defp request(endpoint, item) do
    body = %{
      "item_id" => item["id"],
      "requirements" => Xaas.Ultracode.CapabilityResolver.requirements(item)
    }

    case Req.post(endpoint, json: body, receive_timeout: @timeout_ms, retry: false) do
      {:ok, %Req.Response{status: 200, body: body}} -> parse(body)
      {:ok, %Req.Response{status: status}} -> {:error, {:sa2a_status, status}}
      {:error, exception} -> {:error, {:sa2a_transport, exception}}
    end
  rescue
    error -> {:error, {:sa2a_transport, Exception.message(error)}}
  end

  defp parse(%{"capabilities" => capabilities}) when is_list(capabilities),
    do: {:ok, capabilities}

  defp parse(_other), do: {:error, :sa2a_body_malformed}
end
