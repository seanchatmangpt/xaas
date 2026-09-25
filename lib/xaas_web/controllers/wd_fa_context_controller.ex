defmodule XaasWeb.WdFaContextController do
  use XaasWeb, :controller

  alias Xaas.CaseStudies.WdFa.ContextEnvelope

  def show(conn, %{"case_id" => case_id} = params) do
    case_id = String.replace_suffix(case_id, ".json", "")
    viewpoint = Map.get(params, "viewpoint", "fa-engineer")
    learned? = Map.get(params, "learned") in ["1", "true", "yes"]

    case ContextEnvelope.build(case_id, viewpoint, learned?) do
      {:ok, envelope} ->
        json(conn, envelope)

      {:error, reason} ->
        conn
        |> put_status(:not_found)
        |> json(%{standing: "REFUSED", reason: to_string(reason)})
    end
  end
end
