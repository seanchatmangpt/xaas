defmodule XaasWeb.ExecutionFabricController do
  @moduledoc """
  HTTP surface of the provider-pull execution fabric, under `/internal-api`
  and its Bearer-token gate (`RequireInternalApiToken`, fail-closed).

  This controller owns no state and no resources: it is a thin transport
  projection onto the existing Ultracode seam — `Xaas.Ultracode.Lease`
  (claim/admit/close/refuse over `Run`/`Epoch`/`Receipt`). Two shapes:

    * `POST /internal-api/execution/hooks/:event` — plain JSON consumed by
      the generated provider plugin's hook scripts. A `pre_tool_use`
      refusal is HTTP 403 with a typed reason; the hook script converts
      any non-allow into the provider's blocking exit code, and converts
      its own transport failure to an explicit deny (BRCE_UNAVAILABLE).

    * `POST /internal-api/execution/mcp` — a stateless MCP JSON-RPC 2.0
      endpoint exposing claim_next / heartbeat / admit_tool /
      record_provider_event / close_candidate / refuse to the provider's
      MCP client.
  """

  use XaasWeb, :controller

  require Logger

  alias Xaas.Ultracode.Lease

  @mcp_tools [
    %{
      name: "claim_next",
      description:
        "Claim the oldest lease-free running epoch of a provider-pull run. " <>
          "Returns the work payload (run goal + exact subject) and the lease token.",
      inputSchema: %{
        type: "object",
        properties: %{
          provider: %{type: "string"},
          provider_worker_id: %{type: "string"}
        },
        required: ["provider"]
      }
    },
    %{
      name: "heartbeat",
      description: "Renew the lease held by this lease_token.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}},
        required: ["lease_token"]
      }
    },
    %{
      name: "admit_tool",
      description:
        "Per-consequence admission court for one proposed tool invocation. Refusal is a fence.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}, tool: %{type: "string"}},
        required: ["lease_token", "tool"]
      }
    },
    %{
      name: "record_provider_event",
      description: "Record a provider-observed event. Observation, never subject success.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}, event: %{type: "object"}},
        required: ["lease_token", "event"]
      }
    },
    %{
      name: "close_candidate",
      description:
        "Close the leased epoch with head-verified evidence and seal the Receipt. " <>
          "Provider stop never implies closure.",
      inputSchema: %{
        type: "object",
        properties: %{
          lease_token: %{type: "string"},
          final_head: %{type: "string"},
          outcome: %{type: "string"},
          evidence: %{type: "object"}
        },
        required: ["lease_token", "final_head", "outcome"]
      }
    },
    %{
      name: "refuse",
      description: "Refuse the leased work with a typed reason.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}, reason: %{type: "string"}},
        required: ["lease_token", "reason"]
      }
    }
  ]

  @valid_outcomes ~w(alive partial_alive blocked build_broken unsupported refused)

  # ------------------------------------------------------------------
  # Hook surface (plain JSON)
  # ------------------------------------------------------------------

  def hook(%{method: "POST"} = conn, %{"event" => event}) do
    with {:ok, body, conn} <- read_json(conn) do
      handle_hook(conn, event, body)
    end
  end

  defp handle_hook(conn, "session_start", body) do
    # No worker registry exists by design: worker identity is free-form and
    # travels with the claim. Session start is acknowledged for hook-protocol
    # symmetry and observed via telemetry only.
    :telemetry.execute(
      [:xaas, :ultracode, :provider_session],
      %{},
      %{provider: body["provider"] || "zcode", session_id: body["session_id"], cwd: body["cwd"]}
    )

    json(conn, %{status: "acknowledged"})
  end

  defp handle_hook(conn, "pre_tool_use", body) do
    case lease_token(body) do
      nil ->
        refused(conn, 403, :no_lease)

      token ->
        case Lease.admit_tool(token, body["tool"] || "") do
          {:ok, %{decision: :allow} = allow} ->
            json(conn, Map.new(allow, fn {k, v} -> {to_string(k), v} end))

          {:error, reason} ->
            refused(conn, 403, reason)
        end
    end
  end

  defp handle_hook(conn, event, body)
       when event in ~w(user_prompt_submit post_tool_use post_tool_use_failure) do
    case lease_token(body) do
      nil ->
        refused(conn, 422, :no_lease)

      token ->
        case Lease.record_provider_event(token, %{
               hook: event,
               tool: body["tool"],
               tool_use_id: body["tool_use_id"],
               cwd: body["cwd"],
               session_id: body["session_id"]
             }) do
          :ok -> json(conn, %{status: "recorded"})
          {:error, reason} -> refused(conn, 422, reason)
        end
    end
  end

  defp handle_hook(conn, "stop", body) do
    case lease_token(body) do
      nil ->
        json(conn, %{status: "not_closeable", reason: "no_lease"})

      token ->
        case Lease.close(
               token,
               body["final_head"] || "",
               outcome(body["standing"]),
               body["evidence"] || %{}
             ) do
          {:ok, epoch, receipt} ->
            json(conn, %{
              status: "closed",
              epoch_id: epoch.id,
              outcome: receipt.outcome
            })

          {:error, reason} ->
            # Stop without a closeable lease is observed, not fatal: the
            # lease expires on its own; the provider must not treat this
            # as closure.
            Logger.warning("XAAS_STOP_WITHOUT_CLOSE reason=#{inspect(reason)}")
            json(conn, %{status: "not_closeable", reason: inspect(reason)})
        end
    end
  end

  defp handle_hook(conn, unknown_event, _body) do
    refused(conn, 404, {:unknown_hook_event, unknown_event})
  end

  # ------------------------------------------------------------------
  # MCP surface (stateless JSON-RPC 2.0)
  # ------------------------------------------------------------------

  def mcp(%{method: "POST"} = conn, _params) do
    with {:ok, body, conn} <- read_json(conn),
         {:ok, response} <- rpc(body) do
      json(conn, response)
    else
      {:error, %{} = rpc_error} ->
        json(conn, rpc_error)

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: "bad_request", detail: inspect(reason)})
    end
  end

  defp rpc(%{"id" => id, "method" => "initialize"}) do
    {:ok,
     %{
       jsonrpc: "2.0",
       id: id,
       result: %{
         protocolVersion: "2025-03-26",
         capabilities: %{tools: %{}},
         serverInfo: %{name: "xaas-ultracode-lease", version: "1.0.0"}
       }
     }}
  end

  defp rpc(%{"id" => id, "method" => "tools/list"}) do
    {:ok, %{jsonrpc: "2.0", id: id, result: %{tools: @mcp_tools}}}
  end

  defp rpc(%{"id" => id, "method" => "tools/call", "params" => %{"name" => name} = params}) do
    case dispatch_tool(name, Map.get(params, "arguments", %{})) do
      {:ok, result} ->
        {:ok,
         %{jsonrpc: "2.0", id: id, result: %{content: [%{type: "text", text: Jason.encode!(result)}]}}}

      {:error, reason} ->
        # Tool-level refusal is a JSON-RPC tool error carrying the typed
        # reason — never a silent success.
        {:ok,
         %{
           jsonrpc: "2.0",
           id: id,
           result: %{
             isError: true,
             content: [%{type: "text", text: Jason.encode!(%{error: format_reason(reason)})}]
           }
         }}
    end
  end

  defp rpc(%{"id" => id, "method" => method}) do
    {:error,
     %{jsonrpc: "2.0", id: id, error: %{code: -32_601, message: "method not found: #{method}"}}}
  end

  defp rpc(%{"method" => "notifications/" <> _}), do: {:ok, :notification}

  defp rpc(_), do: {:error, :invalid_request}

  defp dispatch_tool("claim_next", args) do
    case Lease.claim_next(args["provider"] || "zcode", args["provider_worker_id"]) do
      {:ok, epoch, token, run} ->
        {:ok,
         %{
           lease_token: token,
           lease_expires_at: epoch.lease_expires_at,
           epoch_id: epoch.id,
           cycle: epoch.cycle,
           exact_subject: epoch.exact_subject,
           goal: run.goal,
           worktree: epoch.worktree
         }}

      error ->
        error
    end
  end

  defp dispatch_tool("heartbeat", %{"lease_token" => token}) do
    with :ok <- Lease.renew(token), do: {:ok, %{status: "renewed"}}
  end

  defp dispatch_tool("heartbeat", _), do: {:error, :lease_token_required}

  defp dispatch_tool("admit_tool", %{"lease_token" => token, "tool" => tool}) do
    Lease.admit_tool(token, tool)
  end

  defp dispatch_tool("admit_tool", _), do: {:error, :lease_token_and_tool_required}

  defp dispatch_tool("record_provider_event", %{"lease_token" => token, "event" => event}) do
    with :ok <- Lease.record_provider_event(token, event), do: {:ok, %{status: "recorded"}}
  end

  defp dispatch_tool("record_provider_event", _), do: {:error, :lease_token_and_event_required}

  defp dispatch_tool("close_candidate", %{"lease_token" => token, "final_head" => head} = args) do
    case Lease.close(token, head, outcome(args["outcome"]), args["evidence"] || %{}) do
      {:ok, epoch, receipt} ->
        {:ok, %{status: "closed", epoch_id: epoch.id, outcome: receipt.outcome}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp dispatch_tool("close_candidate", _), do: {:error, :lease_token_and_head_required}

  defp dispatch_tool("refuse", %{"lease_token" => token, "reason" => reason}) do
    case Lease.refuse(token, reason_atom(reason)) do
      {:ok, epoch, receipt} ->
        {:ok, %{status: "refused", epoch_id: epoch.id, outcome: receipt.outcome}}

      {:error, err} ->
        {:error, err}
    end
  end

  defp dispatch_tool("refuse", _), do: {:error, :lease_token_and_reason_required}

  defp dispatch_tool(other, _), do: {:error, {:unknown_tool, other}}

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  # Plug.Parsers at the endpoint has already read and decoded JSON bodies
  # by the time the controller runs — read_body would see an empty stream.
  # Prefer the parsed body_params; fall back to a raw read only when the
  # parser did not fetch them.
  defp read_json(%{body_params: %Plug.Conn.Unfetched{}} = conn), do: read_json_raw(conn)

  defp read_json(%{body_params: params} = conn) when is_map(params), do: {:ok, params, conn}

  defp read_json(conn), do: read_json_raw(conn)

  defp read_json_raw(conn) do
    case Plug.Conn.read_body(conn, length: 1_000_000) do
      {:ok, raw, conn} ->
        case Jason.decode(raw) do
          {:ok, body} when is_map(body) -> {:ok, body, conn}
          _ -> {:error, :invalid_json}
        end

      {:more, _, _} -> {:error, :body_too_large}
      {:error, reason} -> {:error, reason}
    end
  end

  # The hook payload's lease key varies across provider builds; the
  # transport normalizes it and NEVER invents a token.
  defp lease_token(body) do
    case body["lease_token"] do
      token when is_binary(token) and token != "" -> token
      _ -> nil
    end
  end

  # Case-insensitive on purpose: providers report standing in the documented
  # vocabulary's natural casing ("ALIVE"); normalize before matching so an
  # honest ALIVE is never silently downgraded to partial_alive.
  defp outcome(outcome) when is_binary(outcome) do
    case String.downcase(outcome) do
      o when o in @valid_outcomes -> String.to_atom(o)
      _ -> :partial_alive
    end
  end

  defp reason_atom(reason) do
    case reason do
      nil -> :unknown
      binary when is_binary(binary) -> String.to_atom(binary)
      other -> other
    end
  end

  defp refused(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{decision: "deny", reason: format_reason(reason)})
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason({tag, detail}) when is_atom(tag), do: "#{tag}:#{inspect(detail)}"
  defp format_reason(reason), do: inspect(reason)
end
