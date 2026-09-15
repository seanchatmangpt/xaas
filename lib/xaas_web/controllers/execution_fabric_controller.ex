defmodule XaasWeb.ExecutionFabricController do
  @moduledoc """
  HTTP surface of the execution fabric, under `/internal-api` and its
  Bearer-token gate (`RequireInternalApiToken`, fail-closed).

  Two shapes share this controller:

    * `POST /internal-api/execution/hooks/:event` — plain JSON consumed by
      the generated ZCode plugin's hook scripts (session_start,
      user_prompt_submit, pre_tool_use, post_tool_use,
      post_tool_use_failure, stop). A `pre_tool_use` refusal is HTTP 403
      with a typed reason; the hook script converts any non-allow into the
      provider's blocking exit code, and converts *its own* transport
      failure to an explicit deny (BRCE_UNAVAILABLE) — outage never widens
      into allow.

    * `POST /internal-api/execution/mcp` — a stateless MCP JSON-RPC 2.0
      endpoint exposing the fabric tools (advertise, claim_next,
      heartbeat, admit_tool, record_provider_event, close_candidate,
      refuse) to the provider's MCP client. No sessions are kept; every
      call is authenticated by the same Bearer gate and authorized by
      lease token.
  """

  use XaasWeb, :controller

  require Ash.Query
  require Logger

  alias Xaas.Execution
  alias Xaas.Operations.ExecutionWorker

  @mcp_tools [
    %{
      name: "advertise",
      description: "Register/refresh a provider worker and its capabilities.",
      inputSchema: %{
        type: "object",
        properties: %{
          provider: %{type: "string"},
          provider_worker_id: %{type: "string"},
          provider_session_id: %{type: "string"},
          repository: %{type: "string"},
          worktree: %{type: "string"},
          model_class: %{type: "string"},
          quota_lane: %{
            type: "string",
            enum: ["free_idle", "scarce_flash", "scarce_frontier"]
          },
          capabilities: %{type: "object"}
        },
        required: ["provider", "provider_worker_id"]
      }
    },
    %{
      name: "claim_next",
      description: "Claim the oldest pending work contract for this worker.",
      inputSchema: %{
        type: "object",
        properties: %{
          provider: %{type: "string"},
          provider_worker_id: %{type: "string"},
          quota_lane: %{type: "string"}
        },
        required: ["provider", "provider_worker_id"]
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
        properties: %{
          lease_token: %{type: "string"},
          tool: %{type: "string"},
          input: %{type: "object"}
        },
        required: ["lease_token", "tool"]
      }
    },
    %{
      name: "record_provider_event",
      description:
        "Record a provider-observed event. Observation, never subject success.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}, event: %{type: "object"}},
        required: ["lease_token", "event"]
      }
    },
    %{
      name: "close_candidate",
      description:
        "Close the leased contract with head verification. Provider stop never implies closure.",
      inputSchema: %{
        type: "object",
        properties: %{
          lease_token: %{type: "string"},
          final_head: %{type: "string"},
          standing: %{type: "string"},
          evidence: %{type: "object"}
        },
        required: ["lease_token", "final_head", "standing"]
      }
    },
    %{
      name: "refuse",
      description: "Refuse the leased work with a typed standing reason.",
      inputSchema: %{
        type: "object",
        properties: %{lease_token: %{type: "string"}, reason: %{type: "string"}},
        required: ["lease_token", "reason"]
      }
    }
  ]

  # ------------------------------------------------------------------
  # Hook surface (plain JSON)
  # ------------------------------------------------------------------

  def hook(%{method: "POST"} = conn, %{"event" => event}) do
    with {:ok, body, conn} <- read_json(conn) do
      handle_hook(conn, event, body)
    end
  end

  defp handle_hook(conn, "session_start", body) do
    attrs = %{
      provider: body["provider"] || "zcode",
      provider_worker_id: worker_id!(body),
      provider_session_id: body["session_id"],
      repository: body["repository"],
      worktree: body["worktree"] || body["cwd"],
      quota_lane: lane(body["quota_lane"]),
      capabilities: body["capabilities"] || %{}
    }

    case Execution.register_worker(attrs) do
      {:ok, worker} -> json(conn, %{status: "advertised", worker_id: worker.id})
      {:error, reason} -> refused(conn, 422, {:register_failed, reason})
    end
  end

  defp handle_hook(conn, "pre_tool_use", body) do
    lease_token = body["lease_token"]

    case Execution.admit_tool(lease_token, body["tool"] || "", body["input"] || %{}) do
      {:ok, %{decision: :allow} = allow} ->
        json(conn, Map.new(allow, fn {k, v} -> {to_string(k), v} end))

      {:error, reason} when is_binary(lease_token) ->
        refused(conn, 403, reason)

      {:error, reason} ->
        # No lease token at all is the strictest refusal.
        refused(conn, 403, reason)
    end
  end

  defp handle_hook(conn, event, body) when event in ~w(user_prompt_submit post_tool_use post_tool_use_failure stop_attempted) do
    lease_token = body["lease_token"]

    case Execution.record_provider_event(lease_token, %{
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

  defp handle_hook(conn, "stop", body) do
    lease_token = body["lease_token"]

    case Execution.close_candidate(
           lease_token,
           body["final_head"] || "",
           body["standing"] || "UNKNOWN",
           body["evidence"] || %{}
         ) do
      {:ok, contract} ->
        json(conn, %{status: "closed", work_id: contract.work_id, standing: contract.standing})

      {:error, reason} ->
        # Stop without a closeable lease is recorded, not fatal: the provider
        # may stop mid-work; the lease will expire on its own.
        Logger.warning("XAAS_STOP_WITHOUT_CLOSE reason=#{inspect(reason)}")
        json(conn, %{status: "not_closeable", reason: inspect(reason)})
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
         serverInfo: %{name: "xaas-execution", version: "1.0.0"}
       }
     }}
  end

  defp rpc(%{"id" => id, "method" => "tools/list"}) do
    {:ok, %{jsonrpc: "2.0", id: id, result: %{tools: @mcp_tools}}}
  end

  defp rpc(%{"id" => id, "method" => "tools/call", "params" => %{"name" => name} = params}) do
    case dispatch_tool(name, Map.get(params, "arguments", %{})) do
      {:ok, result} ->
        {:ok, %{jsonrpc: "2.0", id: id, result: %{content: [%{type: "text", text: Jason.encode!(result)}]}}}

      {:error, reason} ->
        # Tool-level refusal is a normal JSON-RPC tool error, not a transport
        # error: the caller must see the typed reason.
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
     %{
       jsonrpc: "2.0",
       id: id,
       error: %{code: -32_601, message: "method not found: #{method}"}
     }}
  end

  defp rpc(%{"method" => "notifications/" <> _}), do: {:ok, :notification}

  defp rpc(_), do: {:error, :invalid_request}

  defp dispatch_tool("advertise", args) do
    Execution.register_worker(%{
      provider: args["provider"] || "zcode",
      provider_worker_id: worker_id!(args),
      provider_session_id: args["provider_session_id"],
      repository: args["repository"],
      worktree: args["worktree"],
      model_class: args["model_class"],
      quota_lane: lane(args["quota_lane"]),
      capabilities: args["capabilities"] || %{}
    })
  end

  defp dispatch_tool("claim_next", args) do
    with {:ok, worker} <- find_worker(args) do
      Execution.claim_next(worker, quota_lane: lane(args["quota_lane"]))
    end
  end

  defp dispatch_tool("heartbeat", %{"lease_token" => token}) do
    with :ok <- Execution.heartbeat(token), do: {:ok, %{status: "renewed"}}
  end

  defp dispatch_tool("heartbeat", _), do: {:error, :lease_token_required}

  defp dispatch_tool("admit_tool", %{"lease_token" => token, "tool" => tool} = args) do
    Execution.admit_tool(token, tool, args["input"] || %{})
  end

  defp dispatch_tool("admit_tool", _), do: {:error, :lease_token_and_tool_required}

  defp dispatch_tool("record_provider_event", %{"lease_token" => token, "event" => event}) do
    with :ok <- Execution.record_provider_event(token, event), do: {:ok, %{status: "recorded"}}
  end

  defp dispatch_tool("record_provider_event", _), do: {:error, :lease_token_and_event_required}

  defp dispatch_tool(
         "close_candidate",
         %{"lease_token" => token, "final_head" => head, "standing" => standing} = args
       ) do
    Execution.close_candidate(token, head, standing, args["evidence"] || %{})
  end

  defp dispatch_tool("close_candidate", _),
    do: {:error, :lease_token_head_and_standing_required}

  defp dispatch_tool("refuse", %{"lease_token" => token, "reason" => reason}) do
    Execution.refuse(token, reason)
  end

  defp dispatch_tool("refuse", _), do: {:error, :lease_token_and_reason_required}

  defp dispatch_tool(other, _), do: {:error, {:unknown_tool, other}}

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp read_json(conn) do
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

  defp find_worker(%{"provider" => provider, "provider_worker_id" => worker_id}) do
    query =
      ExecutionWorker
      |> Ash.Query.for_read(:read)
      |> Ash.Query.filter(provider == ^provider and provider_worker_id == ^worker_id)

    case Ash.read_one(query, authorize?: false) do
      {:ok, nil} -> {:error, {:worker_not_registered, provider, worker_id}}
      {:ok, worker} -> {:ok, worker}
      {:error, reason} -> {:error, reason}
    end
  end

  defp find_worker(_), do: {:error, :provider_and_worker_id_required}

  defp worker_id!(body) do
    body["provider_worker_id"] || body["worker_id"] ||
      body["session_id"] ||
      raise ArgumentError, "provider_worker_id is required"
  end

  defp lane(nil), do: nil
  defp lane(lane) when lane in ~w(free_idle scarce_flash scarce_frontier), do: String.to_atom(lane)
  defp lane(_), do: nil

  defp refused(conn, status, reason) do
    conn
    |> put_status(status)
    |> json(%{decision: "deny", reason: format_reason(reason)})
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason({tag, detail}) when is_atom(tag), do: "#{tag}:#{inspect(detail)}"
  defp format_reason(reason), do: inspect(reason)
end
