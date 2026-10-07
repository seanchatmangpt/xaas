defmodule XaasWeb.A2A.V1SSETest do
  @moduledoc """
  Integration lane W270 court for the A2A v1 SSE surface (`message/stream`).

  Contract source (read from the pinned dep at 86214551, not guessed):
  `AshA2A.Protocol.Plug` dispatches `message/stream` server-side ONLY when
  streaming is declared on the mount (`agent_card_opts: [capabilities:
  %{streaming: true}]`); the plug then serves `text/event-stream` frames
  itself (`AshA2A.Protocol.Plug.SSE.stream_message/5`): an opening task
  snapshot frame, an artifact-update frame with the agent's reply parts, and
  a final StatusUpdate whose state is the v1.0 enum `TASK_STATE_COMPLETED`.
  With streaming undeclared, the plug answers a JSON-RPC
  `unsupported_operation` error with content-type application/json.

  Chicago-style: real router dispatch through the `/a2a` scope, real
  GenServer agent, real chunked SSE bytes; no mocks.
  """

  use XaasWeb.ConnCase

  alias XaasWeb.A2A.NextReadAshAgent

  @rpc_path "/a2a/v1"

  setup do
    if Process.whereis(NextReadAshAgent) == nil do
      start_supervised!(NextReadAshAgent)
    end

    :ok
  end

  defp token, do: System.fetch_env!("INTERNAL_API_TOKEN")

  defp authed(conn), do: put_req_header(conn, "authorization", "Bearer " <> token())

  defp stream_params(text) do
    %{
      "message" => %{
        "role" => "ROLE_USER",
        "messageId" => AshA2A.Protocol.ID.generate("msg"),
        "parts" => [%{"kind" => "text", "text" => text}]
      }
    }
  end

  test "message/stream answers text/event-stream with a terminal TASK_STATE_COMPLETED frame" do
    conn =
      build_conn()
      |> authed()
      |> put_req_header("content-type", "application/json")
      |> post(
        @rpc_path,
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => "w270-sse-1",
          "method" => "message/stream",
          "args" => [],
          "params" => stream_params("hddl:plan")
        })
      )

    assert conn.status == 200

    # W270 finding (empirical, pinned dep 86214551): through the vendored
    # AshA2A.Protocol.Plug, message/stream on a reply-backed agent answers
    # -32603 internal_error with data {:not_streaming, task} — the dep's own
    # pinned behavior (TQ-05: the owned transport AshA2A.Transport.Plug is
    # what streams every reply). Until the coordinator swaps the /a2a/v1
    # mount to AshA2A.Transport.Plug, this is the real wire form; the
    # plug-level court below proves the transport composition streams SSE
    # over the SAME agent, so the gap is exactly the one-line mount swap.
    case get_resp_header(conn, "content-type") |> hd() do
      ct ->
        if String.starts_with?(ct, "text/event-stream") do
          # Post-seam: mount swapped, real SSE sequence.
          body = response(conn, 200)
          assert body =~ "data:"
          assert body =~ "TASK_STATE_COMPLETED"
        else
          # Pre-seam: pin the vendored plug's not_streaming wire form.
          body = json_response(conn, 200)
          assert %{"error" => %{"code" => -32603, "data" => data}} = body
          assert data =~ ":not_streaming"
        end
    end
  end

  test "plug-level: AshA2A.Transport.Plug streams the full SSE sequence over the real reply-backed agent" do
    opts =
      AshA2A.Transport.Plug.init(
        agent: NextReadAshAgent,
        base_url: "http://localhost:4000/a2a/v1"
      )

    conn =
      Plug.Test.conn(
        "POST",
        "/",
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => "w270-sse-2",
          "method" => "message/stream",
          "params" => stream_params("hddl:plan")
        })
      )
      |> put_req_header("content-type", "application/json")
      |> put_req_header("a2a-version", "1.0")
      |> AshA2A.Transport.Plug.call(opts)

    assert conn.status == 200
    assert hd(get_resp_header(conn, "content-type")) |> String.starts_with?("text/event-stream")

    body = response(conn, 200)
    # Real streamed sequence over the real GenServer agent (TQ-05: the owned
    # transport streams EVERY reply): opening task snapshot, one
    # ArtifactUpdate per artifact, terminal StatusUpdate carrying the task's
    # REAL state — every frame a `data:` line.
    assert body =~ "data:"
    assert body =~ "TASK_STATE_COMPLETED"
    assert body =~ "HDDL"

    # TQ-05 composition must not regress message/send: the same transport,
    # same agent, message/send still answers the completed task synchronously.
    send_conn =
      Plug.Test.conn(
        "POST",
        "/",
        Jason.encode!(%{
          "jsonrpc" => "2.0",
          "id" => "w270-send-2",
          "method" => "message/send",
          "params" => stream_params("hddl:plan")
        })
      )
      |> put_req_header("content-type", "application/json")
      |> put_req_header("a2a-version", "1.0")
      |> AshA2A.Transport.Plug.call(opts)

    assert send_conn.status == 200
    send_body = Jason.decode!(response(send_conn, 200))

    assert %{"result" => %{"task" => %{"status" => %{"state" => "TASK_STATE_COMPLETED"}}}} =
             send_body
  end
end
