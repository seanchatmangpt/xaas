defmodule Xaas.Sjira.Checkpoint do
  @moduledoc """
  Crash-safe filesystem checkpoints for sJira delivery episodes.

  The store is intentionally tiny and dependency-free. A checkpoint is written
  to a sibling temporary file and then atomically renamed into place. The
  delivery state remains data: callers may inspect, copy, or migrate it without
  starting a process.

  The scope and run key are hashed before they reach the filesystem so semantic
  identifiers never become path traversal input.
  """

  @type state :: map()
  @type option :: {:checkpoint_dir, String.t()}

  @spec load(String.t(), String.t(), [option()]) ::
          {:ok, state() | nil} | {:error, term()}
  def load(scope, run_key, opts \\ []) do
    path = path(scope, run_key, opts)

    case File.read(path) do
      {:ok, bytes} ->
        case Jason.decode(bytes) do
          {:ok, %{} = state} -> {:ok, state}
          {:ok, other} -> {:error, {:invalid_checkpoint_shape, other}}
          {:error, error} -> {:error, {:invalid_checkpoint_json, error}}
        end

      {:error, :enoent} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, {:checkpoint_read_failed, reason}}
    end
  end

  @spec save(String.t(), String.t(), state(), [option()]) ::
          {:ok, String.t()} | {:error, term()}
  def save(scope, run_key, %{} = state, opts \\ []) do
    target = path(scope, run_key, opts)
    parent = Path.dirname(target)
    nonce = System.unique_integer([:positive, :monotonic])
    temp = target <> ".tmp." <> Integer.to_string(nonce)

    with :ok <- File.mkdir_p(parent),
         :ok <- File.write(temp, encode(state), [:binary]),
         :ok <- replace(temp, target) do
      {:ok, target}
    else
      {:error, reason} ->
        _ = File.rm(temp)
        {:error, {:checkpoint_write_failed, reason}}
    end
  end

  @spec clear(String.t(), String.t(), [option()]) :: :ok | {:error, term()}
  def clear(scope, run_key, opts \\ []) do
    case File.rm(path(scope, run_key, opts)) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, {:checkpoint_delete_failed, reason}}
    end
  end

  @spec path(String.t(), String.t(), [option()]) :: String.t()
  def path(scope, run_key, opts \\ []) do
    root = Keyword.get(opts, :checkpoint_dir, default_root())
    digest = digest(scope <> "\0" <> run_key)
    Path.join([root, safe_segment(scope), digest <> ".json"])
  end

  @spec migrate(map(), non_neg_integer()) :: {:ok, map()} | {:error, term()}
  def migrate(%{} = state, target_version \\ 1)

  def migrate(%{"version" => version} = state, version), do: {:ok, state}

  def migrate(%{} = state, 1) do
    {:ok,
     state
     |> Map.put_new("version", 1)
     |> Map.put_new("cursor", 0)
     |> Map.put_new("completed", %{})
     |> Map.put_new("failed", [])
     |> Map.put_new("inflight", nil)}
  end

  def migrate(%{} = state, target_version),
    do: {:error, {:unsupported_checkpoint_version, state["version"], target_version}}

  @spec encode(term()) :: binary()
  def encode(term), do: Jason.encode!(canonical(term), pretty: true) <> "\n"

  defp replace(temp, target) do
    case File.rename(temp, target) do
      :ok ->
        :ok

      {:error, :eexist} ->
        with :ok <- File.rm(target),
             :ok <- File.rename(temp, target) do
          :ok
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp default_root do
    Path.join(System.tmp_dir!(), "xaas-sjira-checkpoints")
  end

  defp digest(value) do
    :crypto.hash(:sha256, value)
    |> Base.url_encode64(padding: false)
  end

  defp safe_segment(value) do
    value
    |> to_string()
    |> String.replace(~r/[^A-Za-z0-9_.-]+/u, "-")
    |> String.trim("-")
    |> case do
      "" -> "default"
      segment -> segment
    end
  end

  defp canonical(%{} = map) when not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical(value)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp canonical(list) when is_list(list), do: Enum.map(list, &canonical/1)
  defp canonical(other), do: other
end
