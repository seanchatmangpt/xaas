defmodule Xaas.Sjira.Atlassian do
  @moduledoc "Pure Jira Cloud request projection; performs no provider IO."
  @required ~w(identity project_key issue_type summary)
  @retryable MapSet.new([408, 409, 425, 429, 500, 502, 503, 504])

  def project(item, opts \\ [])

  def project(item, opts) when is_map(item) do
    with :ok <- require_fields(item) do
      id = str(item, "identity")

      fields =
        %{
          project: %{key: str(item, "project_key")},
          issuetype: %{name: str(item, "issue_type")},
          summary: truncate(str(item, "summary"), Keyword.get(opts, :summary_limit, 255)),
          description: adf(item["description"] || item[:description] || ""),
          labels: labels(item)
        }
        |> custom(item, Keyword.get(opts, :field_map, %{}))

      key = Keyword.get(opts, :issue_key) || item["provider_key"] || item[:provider_key]
      operation = if key, do: {:update, key}, else: :create

      digest =
        digest(%{
          id: id,
          operation:
            case operation do
              :create -> "create"
              {:update, k} -> %{"update" => to_string(k)}
            end,
          fields: fields
        })

      {method, path} =
        case operation do
          :create -> {:post, "/rest/api/3/issue"}
          {:update, k} -> {:put, "/rest/api/3/issue/" <> URI.encode(to_string(k))}
        end

      {:ok,
       %{
         method: method,
         path: path,
         headers: [{"content-type", "application/json"}, {"accept", "application/json"}],
         body: %{fields: fields, properties: properties(item, digest)},
         idempotency_key: digest,
         semantic_id: id
       }}
    end
  end

  def project(other, _), do: {:error, {:invalid_item, other}}

  def classify_response(status, body, env) do
    cond do
      status in 200..299 ->
        %{
          disposition: :accepted,
          retry: false,
          semantic_id: env.semantic_id,
          provider_key: key(body),
          idempotency_key: env.idempotency_key
        }

      status == 400 ->
        refusal(:invalid_provider_payload, body)

      status in [401, 403] ->
        refusal(:provider_authority, body)

      status == 404 ->
        refusal(:provider_subject_missing, body)

      status == 412 ->
        %{
          disposition: :reconcile,
          retry: false,
          class: :provider_precondition,
          detail: errors(body)
        }

      MapSet.member?(@retryable, status) ->
        %{
          disposition: :retry,
          retry: true,
          class: retry_class(status),
          retry_after_ms: retry_after(body),
          idempotency_key: env.idempotency_key
        }

      true ->
        refusal({:provider_status, status}, body)
    end
  end

  def encode(env), do: Jason.encode!(canonical(env.body))

  def digest(term),
    do:
      "sha256:" <>
        Base.encode16(:crypto.hash(:sha256, Jason.encode!(canonical(term))), case: :lower)

  defp require_fields(item) do
    missing = Enum.reject(@required, fn k -> present?(item[k] || item[String.to_atom(k)]) end)
    if missing == [], do: :ok, else: {:error, {:missing_fields, missing}}
  end

  defp properties(item, d),
    do:
      [
        %{key: "semantic-jira.identity", value: str(item, "identity")},
        %{key: "semantic-jira.envelope", value: d}
      ] ++
        if(item["tuple_digest"],
          do: [%{key: "semantic-jira.tuple-digest", value: item["tuple_digest"]}],
          else: []
        )

  defp adf(""), do: %{type: "doc", version: 1, content: []}

  defp adf(text),
    do: %{
      type: "doc",
      version: 1,
      content: [%{type: "paragraph", content: [%{type: "text", text: to_string(text)}]}]
    }

  defp labels(item),
    do:
      (["semantic-jira", "sj-" <> sanitize(str(item, "identity"))] ++
         Enum.map(List.wrap(item["labels"] || item[:labels]), &sanitize/1))
      |> Enum.uniq()
      |> Enum.sort()

  defp sanitize(v),
    do:
      v
      |> to_string()
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9_.-]+/u, "-")
      |> String.trim("-")
      |> truncate(255)

  defp custom(fields, item, map),
    do:
      Enum.reduce(map, fields, fn {src, dst}, acc ->
        case item[to_string(src)] || item[src] do
          nil -> acc
          v -> Map.put(acc, to_string(dst), v)
        end
      end)

  defp str(item, k), do: to_string(item[k] || item[String.to_atom(k)])
  defp present?(v), do: not is_nil(v) and to_string(v) != ""

  defp truncate(v, n),
    do:
      if(String.length(to_string(v)) <= n,
        do: to_string(v),
        else: String.slice(to_string(v), 0, n)
      )

  defp key(%{"key" => k}), do: k
  defp key(%{key: k}), do: k
  defp key(_), do: nil
  defp errors(%{"errors" => e}), do: e
  defp errors(%{"errorMessages" => e}), do: e
  defp errors(e), do: e
  defp refusal(c, b), do: %{disposition: :refused, retry: false, class: c, detail: errors(b)}
  defp retry_class(408), do: :timeout
  defp retry_class(409), do: :provider_conflict
  defp retry_class(425), do: :too_early
  defp retry_class(429), do: :rate_limited
  defp retry_class(s) when s >= 500, do: :provider_unavailable
  defp retry_after(%{"retryAfter" => n}) when is_integer(n), do: n * 1000
  defp retry_after(%{"retry_after_ms" => n}) when is_integer(n), do: n
  defp retry_after(_), do: nil

  defp canonical(%{} = m),
    do:
      m
      |> Enum.map(fn {k, v} -> {to_string(k), canonical(v)} end)
      |> Enum.sort_by(&elem(&1, 0))
      |> Jason.OrderedObject.new()

  defp canonical(l) when is_list(l), do: Enum.map(l, &canonical/1)
  defp canonical(v), do: v
end
