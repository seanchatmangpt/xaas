defmodule Xaas.Workbench.GgenClient do
  @moduledoc """
  HTTP client and admission fence for the private Fly-hosted GGen workbench.

  The public/control-plane caller never receives shell authority. It submits only
  an argv vector for the `ggen` executable plus a bounded ephemeral file bundle.
  The worker repeats these limits independently and executes the exact
  digest-pinned ggen-ecosystem capsule without `sh -c`.

  This surface is CONSTRUCT-only: it manufactures files in a fresh ephemeral
  workspace and returns them with a deterministic construction receipt. Git,
  GitHub, cloud, and deployment actuation are intentionally outside this API and
  remain behind their own BRCE paths.
  """

  @max_args 64
  @max_arg_bytes 512
  @max_files 256
  @max_file_bytes 1024 * 1024
  @max_input_bytes 5 * 1024 * 1024
  @max_timeout_ms 300_000
  @default_timeout_ms 120_000

  @type refusal :: {:refused, String.t(), String.t()}

  @spec run(map()) :: {:ok, map()} | {:error, term()}
  def run(payload) do
    with {:ok, normalized} <- validate_payload(payload),
         {:ok, base_url} <- configured_url(),
         {:ok, token} <- configured_token(),
         {:ok, response} <-
           Req.post(base_url <> "/v1/ggen/run",
             json: normalized,
             headers: [{"authorization", "Bearer " <> token}],
             receive_timeout: normalized["timeout_ms"] + 5_000,
             retry: false
           ) do
      normalize_response(response)
    end
  rescue
    error -> {:error, {:transport_exception, Exception.message(error)}}
  end

  @spec health() :: {:ok, map()} | {:error, term()}
  def health do
    with {:ok, base_url} <- configured_url(),
         {:ok, response} <- Req.get(base_url <> "/healthz", receive_timeout: 15_000, retry: false) do
      normalize_response(response)
    end
  rescue
    error -> {:error, {:transport_exception, Exception.message(error)}}
  end

  @doc """
  Applies the same reversible request fence used by the remote worker.

  This is deliberately public for executable falsifier tests and for future
  non-HTTP adapters. Passing admission here does not grant execution authority;
  the worker independently re-admits the request.
  """
  @spec validate_payload(map()) :: {:ok, map()} | {:error, refusal()}
  def validate_payload(payload) when is_map(payload) do
    args = value(payload, "args", :args, ["--version"])
    files = value(payload, "files", :files, %{})
    timeout_ms = value(payload, "timeout_ms", :timeout_ms, @default_timeout_ms)

    with :ok <- validate_args(args),
         :ok <- validate_files(files),
         :ok <- validate_timeout(timeout_ms) do
      {:ok,
       %{
         "args" => args,
         "files" => stringify_file_keys(files),
         "timeout_ms" => timeout_ms
       }}
    end
  end

  def validate_payload(_),
    do: refuse("INVALID_REQUEST", "request body must be a JSON object")

  defp validate_args(args) when is_list(args) and args != [] do
    cond do
      length(args) > @max_args ->
        refuse("ARGS_LIMIT", "at most #{@max_args} ggen arguments are allowed")

      Enum.any?(args, &(not valid_arg?(&1))) ->
        refuse(
          "INVALID_ARG",
          "each ggen argument must be 1..#{@max_arg_bytes} UTF-8 bytes and contain no NUL"
        )

      true ->
        :ok
    end
  end

  defp validate_args(_),
    do: refuse("INVALID_ARGS", "args must be a non-empty JSON array")

  defp valid_arg?(arg) when is_binary(arg) do
    byte_size(arg) in 1..@max_arg_bytes and not String.contains?(arg, <<0>>)
  end

  defp valid_arg?(_), do: false

  defp validate_files(files) when is_map(files) do
    cond do
      map_size(files) > @max_files ->
        refuse("FILES_LIMIT", "at most #{@max_files} input files are allowed")

      true ->
        Enum.reduce_while(files, {:ok, 0}, fn {path, value}, {:ok, total} ->
          with {:ok, path} <- normalize_path(path),
               {:ok, size} <- file_size(value),
               :ok <- file_size_within_limit(path, size),
               next_total <- total + size,
               :ok <- aggregate_size_within_limit(next_total) do
            {:cont, {:ok, next_total}}
          else
            {:error, _} = error -> {:halt, error}
          end
        end)
        |> case do
          {:ok, _total} -> :ok
          {:error, _} = error -> error
        end
    end
  end

  defp validate_files(_),
    do: refuse("INVALID_FILES", "files must be a JSON object keyed by relative path")

  defp normalize_path(path) when is_atom(path), do: normalize_path(Atom.to_string(path))

  defp normalize_path(path) when is_binary(path) and path != "" do
    parts = Path.split(path)

    cond do
      Path.type(path) != :relative ->
        refuse("UNSAFE_PATH", "file path must be relative: #{path}")

      ".." in parts ->
        refuse("UNSAFE_PATH", "file path escapes the ephemeral workspace: #{path}")

      path == "." ->
        refuse("INVALID_PATH", "file path cannot be '.'")

      true ->
        {:ok, path}
    end
  end

  defp normalize_path(_),
    do: refuse("INVALID_PATH", "file paths must be non-empty strings")

  defp file_size(value) when is_binary(value), do: {:ok, byte_size(value)}

  defp file_size(%{"content_base64" => content}) when is_binary(content),
    do: decoded_base64_size(content)

  defp file_size(%{content_base64: content}) when is_binary(content),
    do: decoded_base64_size(content)

  defp file_size(_),
    do:
      refuse(
        "INVALID_FILE_CONTENT",
        "each file must be a UTF-8 string or {content_base64: <base64>}"
      )

  defp decoded_base64_size(content) do
    case Base.decode64(content) do
      {:ok, decoded} -> {:ok, byte_size(decoded)}
      :error -> refuse("INVALID_BASE64", "content_base64 is not valid base64")
    end
  end

  defp file_size_within_limit(_path, size) when size <= @max_file_bytes, do: :ok

  defp file_size_within_limit(path, _size),
    do: refuse("FILE_LIMIT", "#{path} exceeds the #{@max_file_bytes}-byte per-file input limit")

  defp aggregate_size_within_limit(total) when total <= @max_input_bytes, do: :ok

  defp aggregate_size_within_limit(_),
    do: refuse("INPUT_LIMIT", "input bundle exceeds the #{@max_input_bytes}-byte aggregate limit")

  defp validate_timeout(timeout_ms)
       when is_integer(timeout_ms) and timeout_ms >= 1 and timeout_ms <= @max_timeout_ms,
       do: :ok

  defp validate_timeout(_),
    do:
      refuse(
        "INVALID_TIMEOUT",
        "timeout_ms must be an integer from 1 through #{@max_timeout_ms}"
      )

  defp stringify_file_keys(files) do
    Map.new(files, fn {path, value} ->
      {if(is_atom(path), do: Atom.to_string(path), else: path), stringify_file_value(value)}
    end)
  end

  defp stringify_file_value(%{content_base64: content}),
    do: %{"content_base64" => content}

  defp stringify_file_value(value), do: value

  defp configured_url do
    case System.get_env("GGEN_WORKBENCH_URL") do
      nil ->
        refuse(
          "WORKBENCH_NOT_CONFIGURED",
          "GGEN_WORKBENCH_URL is not configured on the xaas control plane"
        )

      url ->
        {:ok, String.trim_trailing(url, "/")}
    end
  end

  defp configured_token do
    case System.get_env("GGEN_WORKBENCH_TOKEN") do
      nil ->
        refuse(
          "WORKBENCH_TOKEN_MISSING",
          "GGEN_WORKBENCH_TOKEN is not configured on the xaas control plane"
        )

      token when byte_size(token) > 0 ->
        {:ok, token}

      _ ->
        refuse("WORKBENCH_TOKEN_MISSING", "GGEN_WORKBENCH_TOKEN cannot be empty")
    end
  end

  defp normalize_response(%Req.Response{status: status, body: body}) when status in 200..299,
    do: {:ok, body}

  defp normalize_response(%Req.Response{status: status, body: body}),
    do: {:error, {:upstream, status, body}}

  defp value(map, string_key, atom_key, default) do
    cond do
      Map.has_key?(map, string_key) -> Map.get(map, string_key)
      Map.has_key?(map, atom_key) -> Map.get(map, atom_key)
      true -> default
    end
  end

  defp refuse(code, detail), do: {:error, {:refused, code, detail}}
end
