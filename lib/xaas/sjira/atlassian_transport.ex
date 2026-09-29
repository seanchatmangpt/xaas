defmodule Xaas.Sjira.AtlassianTransport do
  @moduledoc """
  Consequential Jira transport for typed sJira successor items.

  This module consumes successor items whose route is KNOWN and turns them into
  stable Jira Cloud request envelopes. The network edge is injected through
  request_fun/4. That keeps planning, serialization, checkpointing, retry
  scheduling, and disposition mapping reusable across Finch, Req, Hackney, or
  an external worker.

  Delivery is resumable. Before each consequential request, the exact request
  envelope is persisted as inflight. If the process dies in the crash window,
  the next call replays that same envelope with the same stable delivery id.
  After a terminal response the checkpoint advances and clears inflight.

  Nothing here grants authority. The module expects already-classified semantic
  work and records transport outcomes only.
  """

  alias Xaas.Sjira.Checkpoint
  alias Xaas.Sjira.RateLimit

  @scope "sjira-atlassian-delivery"
  @default_batch_size 50
  @default_max_attempts 5

  @typedoc "Normalized request envelope passed to the injected transport."
  @type envelope :: %{
          required(String.t()) => term()
        }

  @typedoc "Normalized response expected from request_fun."
  @type response :: %{
          required(:status) => integer(),
          optional(:headers) => map() | list(),
          optional(:body) => binary() | map() | nil
        }

  @typedoc """
  request_fun receives method, absolute URL, headers, encoded JSON body and
  returns {:ok, response} or {:error, reason}.
  """
  @type request_fun ::
          (atom(), String.t(), [{String.t(), String.t()}], binary() ->
             {:ok, response()} | {:error, term()})

  @spec deliver(String.t(), [map()], keyword()) :: {:ok, map()} | {:error, term()}
  def deliver(run_key, items, opts) when is_binary(run_key) and is_list(items) do
    with {:ok, config} <- config(opts),
         {:ok, state} <- load_or_initialize(run_key, items, config) do
      continue(run_key, state, config)
    end
  end

  @spec resume(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def resume(run_key, opts) when is_binary(run_key) do
    with {:ok, config} <- config(opts),
         {:ok, state} <- load_existing(run_key, config) do
      continue(run_key, state, config)
    end
  end

  @spec plan([map()], keyword()) :: {:ok, [envelope()]} | {:error, term()}
  def plan(items, opts) when is_list(items) do
    with {:ok, config} <- config(opts) do
      items
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, []}, fn {item, index}, {:ok, acc} ->
        case envelope(item, index, config) do
          {:ok, request} -> {:cont, {:ok, [request | acc]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:ok, envelopes} -> {:ok, Enum.reverse(envelopes)}
        error -> error
      end
    end
  end

  @spec envelope(map(), non_neg_integer(), keyword() | map()) ::
          {:ok, envelope()} | {:error, term()}
  def envelope(item, index, opts_or_config)

  def envelope(%{} = item, index, %{} = config) when index >= 0 do
    with :ok <- require_known_route(item),
         {:ok, identity} <- required_string(item, "order"),
         {:ok, capability} <- required_string(item, "capability"),
         {:ok, tuple_digest} <- required_string(item, "tuple_digest") do
      jira_key = optional_string(item, "jira_key")
      method = if jira_key, do: :put, else: :post

      path =
        if jira_key do
          "/rest/api/3/issue/" <> URI.encode(jira_key)
        else
          "/rest/api/3/issue"
        end

      delivery_id = stable_delivery_id(identity, tuple_digest, config.project_key)
      body = jira_body(item, capability, identity, tuple_digest, config)

      {:ok,
       %{
         "index" => index,
         "delivery_id" => delivery_id,
         "semantic_identity" => identity,
         "tuple_digest" => tuple_digest,
         "method" => Atom.to_string(method),
         "path" => path,
         "url" => config.base_url <> path,
         "headers" =>
           merge_headers(config.headers, [
             {"content-type", "application/json"},
             {"accept", "application/json"},
             {"x-xaas-delivery-id", delivery_id}
           ]),
         "body" => body,
         "encoded_body" => Jason.encode!(body)
       }}
    end
  end

  def envelope(%{} = item, index, opts) when is_list(opts) do
    with {:ok, config} <- config(opts) do
      envelope(item, index, config)
    end
  end

  def envelope(other, _index, _opts), do: {:error, {:invalid_successor_item, other}}

  @spec disposition(response() | {:error, term()}, envelope()) :: map()
  def disposition({:error, reason}, request) do
    %{
      "delivery_id" => request["delivery_id"],
      "semantic_identity" => request["semantic_identity"],
      "outcome" => "RETRYABLE_TRANSPORT_ERROR",
      "terminal" => false,
      "retryable" => true,
      "reason" => inspect(reason)
    }
  end

  def disposition(%{status: status} = response, request) when status in 200..299 do
    body = decode_body(Map.get(response, :body))

    %{
      "delivery_id" => request["delivery_id"],
      "semantic_identity" => request["semantic_identity"],
      "outcome" => "DELIVERED",
      "terminal" => true,
      "retryable" => false,
      "status" => status,
      "jira_key" => body["key"],
      "jira_id" => body["id"]
    }
  end

  def disposition(%{status: 429} = response, request) do
    %{
      "delivery_id" => request["delivery_id"],
      "semantic_identity" => request["semantic_identity"],
      "outcome" => "RATE_LIMITED",
      "terminal" => false,
      "retryable" => true,
      "status" => 429,
      "provider_error" => provider_error(response)
    }
  end

  def disposition(%{status: status} = response, request) when status in 500..599 do
    %{
      "delivery_id" => request["delivery_id"],
      "semantic_identity" => request["semantic_identity"],
      "outcome" => "RETRYABLE_PROVIDER_ERROR",
      "terminal" => false,
      "retryable" => true,
      "status" => status,
      "provider_error" => provider_error(response)
    }
  end

  def disposition(%{status: status} = response, request) when status in [408, 409, 423, 425] do
    %{
      "delivery_id" => request["delivery_id"],
      "semantic_identity" => request["semantic_identity"],
      "outcome" => "RETRYABLE_PROVIDER_CONFLICT",
      "terminal" => false,
      "retryable" => true,
      "status" => status,
      "provider_error" => provider_error(response)
    }
  end

  def disposition(%{status: status} = response, request) do
    %{
      "delivery_id" => request["delivery_id"],
      "semantic_identity" => request["semantic_identity"],
      "outcome" => "REFUSED_BY_PROVIDER",
      "terminal" => true,
      "retryable" => false,
      "status" => status,
      "provider_error" => provider_error(response)
    }
  end

  @spec batches([term()], pos_integer()) :: [[term()]]
  def batches(items, size) when is_list(items) and size > 0 do
    Enum.chunk_every(items, size)
  end

  @spec deduplicate([map()]) :: [map()]
  def deduplicate(items) do
    {_, reversed} =
      Enum.reduce(items, {MapSet.new(), []}, fn item, {seen, acc} ->
        key = {item["order"], item["tuple_digest"]}

        if MapSet.member?(seen, key) do
          {seen, acc}
        else
          {MapSet.put(seen, key), [item | acc]}
        end
      end)

    Enum.reverse(reversed)
  end

  defp continue(run_key, %{"inflight" => %{} = inflight} = state, config) do
    dispatch(run_key, state, inflight, config)
  end

  defp continue(run_key, %{"cursor" => cursor, "requests" => requests} = state, config)
       when cursor < length(requests) do
    request = Enum.at(requests, cursor)

    state =
      state
      |> Map.put("inflight", request)
      |> Map.put("updated_at", iso8601(config.now_fun.()))

    with {:ok, _path} <- persist(run_key, state, config) do
      dispatch(run_key, state, request, config)
    end
  end

  defp continue(run_key, state, config) do
    final =
      state
      |> Map.put("status", "complete")
      |> Map.put("inflight", nil)
      |> Map.put("updated_at", iso8601(config.now_fun.()))

    with {:ok, checkpoint_path} <- persist(run_key, final, config) do
      {:ok, summarize(final, checkpoint_path)}
    end
  end

  defp dispatch(run_key, state, request, config) do
    attempt = Map.get(state, "attempt", 1)
    method = request["method"] |> String.to_existing_atom()
    headers = request["headers"]
    body = request["encoded_body"]

    result =
      try do
        config.request_fun.(method, request["url"], headers, body)
      rescue
        exception -> {:error, {:request_exception, exception, __STACKTRACE__}}
      catch
        kind, reason -> {:error, {:request_throw, kind, reason}}
      end

    response_for_disposition =
      case result do
        {:ok, %{status: _} = response} ->
          response

        {:ok, %{"status" => status} = response} ->
          %{
            status: status,
            headers: response["headers"] || [],
            body: response["body"]
          }

        {:ok, other} ->
          {:error, {:invalid_response_shape, other}}

        {:error, reason} ->
          {:error, reason}

        other ->
          {:error, {:invalid_request_result, other}}
      end

    disp = disposition(response_for_disposition, request)

    cond do
      disp["terminal"] ->
        finish_request(run_key, state, request, disp, config)

      attempt >= config.max_attempts ->
        exhausted =
          disp
          |> Map.put("outcome", "RETRY_EXHAUSTED")
          |> Map.put("terminal", true)
          |> Map.put("retryable", false)
          |> Map.put("attempts", attempt)

        finish_request(run_key, state, request, exhausted, config)

      true ->
        headers =
          case response_for_disposition do
            %{headers: response_headers} -> response_headers
            _ -> []
          end

        delay =
          RateLimit.delay_ms(headers, attempt,
            now_ms: config.now_ms_fun.(),
            base_backoff_ms: config.base_backoff_ms,
            max_backoff_ms: config.max_backoff_ms
          )

        retry_state =
          state
          |> Map.put("attempt", attempt + 1)
          |> Map.put("last_disposition", Map.put(disp, "delay_ms", delay))
          |> Map.put("updated_at", iso8601(config.now_fun.()))

        with {:ok, _path} <- persist(run_key, retry_state, config) do
          config.sleep_fun.(delay)
          dispatch(run_key, retry_state, request, config)
        end
    end
  end

  defp finish_request(run_key, state, request, disp, config) do
    cursor = state["cursor"]
    delivery_id = request["delivery_id"]

    {completed, failed} =
      if disp["outcome"] == "DELIVERED" do
        {Map.put(state["completed"], delivery_id, disp), state["failed"]}
      else
        {state["completed"], state["failed"] ++ [disp]}
      end

    next_state =
      state
      |> Map.put("cursor", cursor + 1)
      |> Map.put("attempt", 1)
      |> Map.put("completed", completed)
      |> Map.put("failed", failed)
      |> Map.put("inflight", nil)
      |> Map.put("last_disposition", disp)
      |> Map.put("updated_at", iso8601(config.now_fun.()))

    with {:ok, _path} <- persist(run_key, next_state, config) do
      continue(run_key, next_state, config)
    end
  end

  defp load_or_initialize(run_key, items, config) do
    case config.checkpoint_module.load(@scope, run_key, config.checkpoint_opts) do
      {:ok, nil} ->
        initialize(run_key, items, config)

      {:ok, %{} = state} ->
        with {:ok, migrated} <- config.checkpoint_module.migrate(state, 1) do
          {:ok, migrated}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_existing(run_key, config) do
    case config.checkpoint_module.load(@scope, run_key, config.checkpoint_opts) do
      {:ok, nil} -> {:error, :checkpoint_not_found}
      {:ok, %{} = state} -> config.checkpoint_module.migrate(state, 1)
      {:error, reason} -> {:error, reason}
    end
  end

  defp initialize(run_key, items, config) do
    with {:ok, requests} <- plan(deduplicate(items), Map.to_list(config)) do
      now = iso8601(config.now_fun.())

      state = %{
        "version" => 1,
        "scope" => @scope,
        "run_key" => run_key,
        "status" => "running",
        "cursor" => 0,
        "attempt" => 1,
        "requests" => requests,
        "completed" => %{},
        "failed" => [],
        "inflight" => nil,
        "created_at" => now,
        "updated_at" => now
      }

      with {:ok, _path} <- persist(run_key, state, config) do
        {:ok, state}
      end
    end
  end

  defp persist(run_key, state, config) do
    config.checkpoint_module.save(@scope, run_key, state, config.checkpoint_opts)
  end

  defp summarize(state, checkpoint_path) do
    %{
      "run_key" => state["run_key"],
      "status" => state["status"],
      "request_count" => length(state["requests"]),
      "delivered_count" => map_size(state["completed"]),
      "failed_count" => length(state["failed"]),
      "completed" => state["completed"],
      "failed" => state["failed"],
      "checkpoint_path" => checkpoint_path
    }
  end

  defp config(opts) when is_list(opts) do
    with {:ok, base_url} <- keyword_string(opts, :base_url),
         {:ok, project_key} <- keyword_string(opts, :project_key),
         {:ok, request_fun} <- request_fun(opts) do
      {:ok,
       %{
         base_url: String.trim_trailing(base_url, "/"),
         project_key: project_key,
         request_fun: request_fun,
         checkpoint_module: Keyword.get(opts, :checkpoint_module, Checkpoint),
         checkpoint_opts: Keyword.get(opts, :checkpoint_opts, []),
         batch_size: Keyword.get(opts, :batch_size, @default_batch_size),
         max_attempts: Keyword.get(opts, :max_attempts, @default_max_attempts),
         base_backoff_ms: Keyword.get(opts, :base_backoff_ms, 500),
         max_backoff_ms: Keyword.get(opts, :max_backoff_ms, 30_000),
         headers: normalize_headers(Keyword.get(opts, :headers, [])),
         now_fun: Keyword.get(opts, :now_fun, fn -> DateTime.utc_now() end),
         now_ms_fun: Keyword.get(opts, :now_ms_fun, fn -> System.system_time(:millisecond) end),
         sleep_fun: Keyword.get(opts, :sleep_fun, &Process.sleep/1)
       }}
    end
  end

  defp config(%{} = config), do: {:ok, config}

  defp request_fun(opts) do
    case Keyword.get(opts, :request_fun) do
      fun when is_function(fun, 4) -> {:ok, fun}
      nil -> {:error, {:missing_option, :request_fun}}
      other -> {:error, {:invalid_option, :request_fun, other}}
    end
  end

  defp keyword_string(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and byte_size(value) > 0 -> {:ok, value}
      nil -> {:error, {:missing_option, key}}
      other -> {:error, {:invalid_option, key, other}}
    end
  end

  defp require_known_route(%{"route" => "KNOWN"}), do: :ok

  defp require_known_route(item) do
    {:error, {:successor_not_routable, item["order"], item["route"], item["standing"]}}
  end

  defp required_string(map, key) do
    case map[key] do
      value when is_binary(value) and byte_size(value) > 0 -> {:ok, value}
      other -> {:error, {:missing_or_invalid_field, key, other}}
    end
  end

  defp optional_string(map, key) do
    case map[key] do
      value when is_binary(value) and byte_size(value) > 0 -> value
      _ -> nil
    end
  end

  defp jira_body(item, capability, identity, tuple_digest, config) do
    summary =
      item["summary"] ||
        item["title"] ||
        "#{capability}: #{identity}"

    description =
      item["description"] ||
        "Semantic work item #{identity} routed through #{capability}."

    fields =
      %{
        "project" => %{"key" => config.project_key},
        "summary" => truncate(summary, 255),
        "description" => adf(description),
        "labels" => labels(item, capability)
      }
      |> maybe_put("issuetype", issue_type(item))

    %{
      "fields" => fields,
      "properties" => [
        %{
          "key" => "xaas.semantic.identity",
          "value" => %{
            "order" => identity,
            "tuple_digest" => tuple_digest,
            "capability" => capability,
            "checkpoint_of" => item["checkpoint_of"]
          }
        }
      ]
    }
  end

  defp issue_type(item) do
    case item["issue_type"] do
      value when is_binary(value) and byte_size(value) > 0 -> %{"name" => value}
      _ -> nil
    end
  end

  defp labels(item, capability) do
    item_labels =
      case item["labels"] do
        list when is_list(list) -> Enum.map(list, &to_string/1)
        _ -> []
      end

    (["xaas-sjira", "capability-" <> slug(capability)] ++ item_labels)
    |> Enum.map(&truncate(&1, 255))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp adf(text) do
    %{
      "type" => "doc",
      "version" => 1,
      "content" => [
        %{
          "type" => "paragraph",
          "content" => [%{"type" => "text", "text" => to_string(text)}]
        }
      ]
    }
  end

  defp provider_error(response) do
    response
    |> Map.get(:body)
    |> decode_body()
    |> case do
      %{} = body ->
        %{
          "errorMessages" => body["errorMessages"] || [],
          "errors" => body["errors"] || %{}
        }

      other ->
        %{"body" => other}
    end
  end

  defp decode_body(nil), do: %{}
  defp decode_body(%{} = body), do: body

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end

  defp decode_body(other), do: other

  defp merge_headers(left, right) do
    (normalize_headers(left) ++ normalize_headers(right))
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, String.downcase(key), {key, value})
    end)
    |> Map.values()
    |> Enum.sort_by(fn {key, _value} -> String.downcase(key) end)
  end

  defp normalize_headers(headers) when is_map(headers) do
    Enum.map(headers, fn {key, value} -> {to_string(key), to_string(value)} end)
  end

  defp normalize_headers(headers) when is_list(headers) do
    Enum.flat_map(headers, fn
      {key, value} -> [{to_string(key), to_string(value)}]
      _ -> []
    end)
  end

  defp normalize_headers(_), do: []

  defp stable_delivery_id(identity, tuple_digest, project_key) do
    :crypto.hash(:sha256, Enum.join([identity, tuple_digest, project_key], "\0"))
    |> Base.url_encode64(padding: false)
  end

  defp iso8601(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp iso8601(value), do: to_string(value)

  defp slug(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  defp truncate(value, max_bytes) do
    value = to_string(value)

    if byte_size(value) <= max_bytes do
      value
    else
      binary_part(value, 0, max_bytes)
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
