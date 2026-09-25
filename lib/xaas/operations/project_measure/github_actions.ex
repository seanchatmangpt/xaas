defmodule Xaas.Operations.ProjectMeasure.GitHubActions do
  @moduledoc """
  Read-only GitHub Actions observation boundary.

  Only HTTP GET is reachable from this module. Pagination fails closed when the
  reported population changes while a repository is being observed.
  """

  @per_page 100
  @max_pages 100

  def list_workflow_runs(repository, since, until, opts \\ []) do
    with {:ok, owner, name} <- split_repository(repository) do
      fetch_pages(owner, name, since, until, opts, 1, nil, [])
    end
  end

  defp split_repository(repository) when is_binary(repository) do
    case String.split(repository, "/", parts: 2) do
      [owner, name] when owner != "" and name != "" -> {:ok, owner, name}
      _ -> refusal("REPOSITORY_IDENTITY_INVALID", "repository=#{repository}")
    end
  end

  defp split_repository(repository) do
    refusal("REPOSITORY_IDENTITY_INVALID", "repository=#{inspect(repository)}")
  end

  defp fetch_pages(owner, name, since, until, opts, page, expected_total, rows)
       when page <= @max_pages do
    params = [
      created: "#{iso_z(since)}..#{iso_z(until)}",
      per_page: @per_page,
      page: page
    ]

    path =
      "/repos/#{URI.encode_www_form(owner)}/#{URI.encode_www_form(name)}/actions/runs"

    with {:ok, payload} <- request(path, params, opts),
         {:ok, page_rows, total} <- validate_payload(payload),
         :ok <- validate_total(expected_total, total, owner, name) do
      all_rows = rows ++ page_rows
      pages = max(1, div(total + @per_page - 1, @per_page))

      cond do
        page >= pages and length(all_rows) == total ->
          {:ok, all_rows}

        page >= pages ->
          refusal(
            "CI_RUN_SEARCH_TRUNCATED",
            "repository=#{owner}/#{name} total_count=#{total} retrieved=#{length(all_rows)}"
          )

        true ->
          fetch_pages(owner, name, since, until, opts, page + 1, total, all_rows)
      end
    end
  end

  defp fetch_pages(owner, name, _since, _until, _opts, _page, _expected_total, _rows) do
    refusal("CI_RUN_PAGINATION_UNBOUNDED", "repository=#{owner}/#{name}")
  end

  defp request(path, params, opts) do
    api_url =
      opts
      |> Keyword.get(:api_url, "https://api.github.com")
      |> String.trim_trailing("/")

    token = Keyword.get(opts, :token)
    timeout = Keyword.get(opts, :timeout, 30_000)

    headers = [
      {"accept", "application/vnd.github+json"},
      {"user-agent", "xaas-project-measure/1"},
      {"x-github-api-version", "2022-11-28"}
    ]

    headers =
      if is_binary(token) and token != "" do
        [{"authorization", "Bearer " <> token} | headers]
      else
        headers
      end

    case Req.get(api_url <> path,
           params: params,
           headers: headers,
           receive_timeout: timeout,
           retry: false
         ) do
      {:ok, %Req.Response{status: status, body: body}} when status in 200..299 ->
        decode_body(body)

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, "GitHub HTTP #{status}: #{inspect_body(body)}"}

      {:error, reason} ->
        {:error, "GitHub transport failed: #{inspect(reason)}"}
    end
  end

  defp decode_body(body) when is_map(body), do: {:ok, body}

  defp decode_body(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, payload} when is_map(payload) -> {:ok, payload}
      _ -> refusal("CI_RUN_JSON_INVALID")
    end
  end

  defp decode_body(_), do: refusal("CI_RUN_JSON_INVALID")

  defp validate_payload(%{"workflow_runs" => rows, "total_count" => total})
       when is_list(rows) and is_integer(total) and total >= 0 do
    if Enum.all?(rows, &is_map/1) do
      {:ok, rows, total}
    else
      refusal("CI_RUN_PAYLOAD_INVALID")
    end
  end

  defp validate_payload(_), do: refusal("CI_RUN_PAYLOAD_INVALID")

  defp validate_total(nil, _observed, _owner, _name), do: :ok
  defp validate_total(total, total, _owner, _name), do: :ok

  defp validate_total(expected, observed, owner, name) do
    refusal(
      "CI_RUN_COUNT_DRIFT",
      "repository=#{owner}/#{name} expected=#{expected} observed=#{observed}"
    )
  end

  defp inspect_body(body) when is_binary(body), do: String.slice(body, 0, 400)
  defp inspect_body(body), do: inspect(body, limit: 20, printable_limit: 400)

  defp iso_z(%DateTime{} = value) do
    value
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
    |> String.replace("+00:00", "Z")
  end

  defp refusal(code, detail \\ nil) do
    suffix = if detail, do: " " <> detail, else: ""
    {:error, "REFUSED[#{code}]#{suffix}"}
  end
end
