defmodule XaasWeb.EuAiActExportController do
  @moduledoc """
  OS-14 runtime export surface for the EU AI Act conformance evidence pack
  (closes GAP(NO_RUNTIME_EXPORT_API) from the v26.10.6 coverage map).

  Serves `GET /internal-api/eu-ai-act/pack` — the SAME pack the W513 CLI
  (`mix xaas.eu_ai_act_pack`) assembles, via that task's public `build/1`
  (fail-closed on any missing cited evidence path, missing coverage map, or
  empty typed-gaps extraction — the pack never claims a gap closed; the
  typed-gaps section is carried verbatim from the map). Token-gated by the
  existing internal-api floor (`RequireInternalApiToken`) — no new auth
  surface. The map's remaining gap narrows to retention/persistence
  (artifacts are generated on request, not persisted).
  """

  use XaasWeb, :controller

  @refusal_status 503

  def index(conn, _params) do
    case Mix.Tasks.Xaas.EuAiActPack.build() do
      {:ok, pack} ->
        json(conn, pack)

      {:refused, reason} ->
        conn
        |> put_status(@refusal_status)
        |> json(%{
          schema: "xaas.eu_ai_act_pack_refusal/v1",
          refused: inspect(reason)
        })
    end
  end
end
