defmodule XaasWeb.Plugs.SyntheticMarkingPlug do
  @moduledoc """
  W533: EU AI Act Art. 50(2) — machine-detectable marking of synthetic
  content. The `/a2a` and `/mcp` surfaces emit AI-generated text, so every
  response from those surfaces is marked at the dispatch chokepoint:
  a response header `x-ai-generated: true` plus, where the response body
  is a JSON object, a top-level `"ai_generated": true` field.

  ## Seam choice (why minimal)

  Mirrors the W521 `XaasWeb.Plugs.EuAiActAdmissionPlug` idiom exactly: an
  endpoint plug keyed on `%{method: "POST", path_info: ["a2a" | _]}` /
  `["mcp" | _]`, placed in `XaasWeb.Endpoint` immediately BEFORE
  `EuAiActAdmissionPlug` (a W521 refusal halts there; Plug.Builder skips
  remaining plugs once halted, and the marking's `register_before_send`
  must already be registered so refusal envelopes are marked too). No
  router, scope, or forward change; GETs (agent
  card), SSE, and every non-AI surface (`/`, `/internal-api`, `/api`) pass
  through untouched. Marking is applied AFTER the handler via
  `register_before_send` — so refusals (including the W521 admission
  refusal envelope, which halts in an earlier plug) are marked too, since
  `before_send` callbacks run for halted conns as well.

  Zero-config: unconditional on the AI surfaces, no operator knobs.
  """

  @behaviour Plug

  @header "x-ai-generated"
  @field "ai_generated"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "POST", path_info: ["a2a" | _]} = conn, _opts) do
    mark(conn)
  end

  def call(%{method: "POST", path_info: ["mcp" | _]} = conns_or_conn, _opts) do
    mark(conns_or_conn)
  end

  def call(conn, _opts), do: conn

  defp mark(conn) do
    Plug.Conn.register_before_send(conn, fn conn ->
      conn
      |> Plug.Conn.put_resp_header(@header, "true")
      |> mark_json_body()
    end)
  end

  # Inject the field into a JSON object body, idempotently. Accepts both
  # binary and iodata bodies (Phoenix's json/2 encodes to iodata).
  # Non-JSON bodies (SSE chunks, empty bodies, arrays) get the header only.
  defp mark_json_body(%Plug.Conn{resp_body: body} = conn) when body != "" and body != nil do
    bin = IO.iodata_to_binary(body)

    case Jason.decode(bin) do
      {:ok, %{} = object} ->
        %{conn | resp_body: Jason.encode!(Map.put(object, @field, true))}

      _ ->
        conn
    end
  end

  defp mark_json_body(conn), do: conn
end
