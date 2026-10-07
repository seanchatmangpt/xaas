defmodule XaasWeb.Plugs.EuAiActAdmissionPlug do
  @moduledoc """
  W521: runs `Xaas.Semantics.EuAiActAdmission.admit/1` over the JSON-RPC
  `params` of POSTs on the `/a2a` intake surface BEFORE agent dispatch.

  ## Seam choice (why minimal)

  Mirrors the W150 `XaasWeb.Plugs.A2AParseFloor` idiom exactly: an endpoint
  plug keyed on `%{method: "POST", path_info: ["a2a" | _]}`, placed in
  `XaasWeb.Endpoint` immediately after `Plug.Parsers` (the parse floor has
  already fetched+decoded the body for /a2a POSTs, so `body_params` is a
  plain decoded map here). No router, scope, or forward change; GETs
  (agent card), SSE, and every non-/a2a path pass through untouched, so
  `:require_internal_api_token` stays the single auth floor and this gate
  grants no authority — it only refuses, with the same JSON-RPC 2.0 error
  envelope shape the surface already uses (HTTP 200, request id, code
  -32600) plus a machine-detectable typed refusal atom in `error.data`.

  ## Structure, not content

  JSON transport hands us string keys/values; the admission schema is
  atom-keyed. Normalization converts ONLY the nine declared schema-field
  keys and their values via `String.to_existing_atom/1` — the entire
  prohibited-practice vocabulary (`:manipulate_behavior`, `:social_behavior`,
  `:realtime`, ...) is already compiled into the admission module's beam
  file, so no new atom is ever minted. Unknown keys and free text (message
  parts, prompts, user data) are never atomized and never inspected: the
  same fixture with different text yields the same verdict.
  """

  @behaviour Plug

  alias Xaas.Semantics.EuAiActAdmission

  # The admission schema's structural fields (mirrors EuAiActAdmission's
  # @type candidate). Only these keys are normalized/inspected.
  @schema_fields [
    :techniques,
    :purpose,
    :data_domains,
    :provenance,
    :context_joins,
    :setting,
    :latency_goal,
    :inferences,
    :match_token_type
  ]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "POST", path_info: ["a2a" | _]} = conn, _opts) do
    with decoded when is_map(decoded) <- conn.body_params,
         params when is_map(params) <- Map.get(decoded, "params") do
      case EuAiActAdmission.admit(normalize(params)) do
        {:ok, :admitted} ->
          conn

        {:error, refusal} ->
          refuse(conn, refusal)
      end
    else
      _ -> conn
    end
  end

  def call(conn, _opts), do: conn

  # -- normalization (structure only) ------------------------------------------

  defp normalize(params) when is_map(params) do
    Map.new(params, fn
      {k, v} when is_binary(k) ->
        key = atomize_key(k)

        value =
          if key in @schema_fields do
            atomize_value(v)
          else
            v
          end

        {key, value}

      {k, v} ->
        {k, v}
    end)
  end

  # The nine schema keys and the full prohibited-practice vocabulary,
  # as an explicit compiled string->atom map. Deterministic: no
  # String.to_existing_atom — the runtime atom table cannot make this
  # gate admit or refuse differently between runs.
  @vocab %{
    "techniques" => :techniques,
    "purpose" => :purpose,
    "data_domains" => :data_domains,
    "provenance" => :provenance,
    "context_joins" => :context_joins,
    "setting" => :setting,
    "latency_goal" => :latency_goal,
    "inferences" => :inferences,
    "match_token_type" => :match_token_type,
    "manipulate_behavior" => :manipulate_behavior,
    "deceptive" => :deceptive,
    "subliminal" => :subliminal,
    "exploit_vulnerability" => :exploit_vulnerability,
    "target_vulnerable_audience" => :target_vulnerable_audience,
    "social_behavior" => :social_behavior,
    "unrelated_context_join" => :unrelated_context_join,
    "predict_offending" => :predict_offending,
    "individualized_profile_join" => :individualized_profile_join,
    "consented" => :consented,
    "facial_images" => :facial_images,
    "affective" => :affective,
    "workplace" => :workplace,
    "education" => :education,
    "public_space" => :public_space,
    "biometric_identification" => :biometric_identification,
    "biometric" => :biometric,
    "boolean" => :boolean,
    "realtime" => :realtime
  }

  # Every schema key/value atom comes from the compiled @vocab map;
  # anything unknown stays a string and is never inspected by the gate.
  defp atomize_key(k) do
    Map.get(@vocab, k, k)
  end

  defp atomize_value(v) when is_binary(v) do
    Map.get(@vocab, v, v)
  end

  defp atomize_value(v) when is_list(v), do: Enum.map(v, &atomize_value/1)

  defp atomize_value(other), do: other

  # -- typed refusal envelope ----------------------------------------------------

  defp refuse(conn, refusal) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(
      200,
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: request_id(conn),
        error: %{
          code: -32_600,
          message: "EU AI Act Art. 5 admission refused",
          data: %{
            refusal: Atom.to_string(refusal),
            article: EuAiActAdmission.describe(refusal)
          }
        }
      })
    )
    |> Plug.Conn.halt()
  end

  defp request_id(conn) do
    case conn.body_params do
      %{"id" => id} -> id
      %{id: id} -> id
      _ -> nil
    end
  end
end
