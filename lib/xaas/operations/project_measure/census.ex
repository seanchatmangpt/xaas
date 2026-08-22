defmodule Xaas.Operations.ProjectMeasure.Census do
  @moduledoc """
  Exact-subject GitHub Actions measurement for an Ash project.

  Successful CI is evidence, not ambient correctness. This module never promotes
  the project to `ALIVE`; it reports the observed CI state and manufactures a
  deterministic replayable receipt.
  """

  alias Xaas.Operations.ProjectMeasure.{GitHubActions, Info, Receipt}

  @schema "xaas.project-measure.github-actions/1"
  @failure_like ~w(action_required cancelled failure startup_failure timed_out)

  def observe!(domain, opts \\ []) do
    config = Info.config(domain)
    until = Keyword.get(opts, :until, DateTime.utc_now() |> DateTime.truncate(:second))
    since = Keyword.get(opts, :since, DateTime.add(until, -7, :day))
    subject_sha = Keyword.get(opts, :subject_sha, System.get_env(config.subject_sha_env))

    client_opts = [
      api_url: config.api_url,
      token: System.get_env(config.token_env)
    ]

    with {:ok, rows} <-
           GitHubActions.list_workflow_runs(
             config.repository,
             since,
             until,
             client_opts
           ),
         {:ok, payload} <- build(config, since, until, rows, subject_sha: subject_sha) do
      write!(config.output_path, payload)
      emit_summary(payload)
      payload
    else
      {:error, reason} -> raise reason
    end
  end

  def replay_file!(path) do
    payload = path |> File.read!() |> Jason.decode!()

    if Receipt.verify(payload) do
      IO.puts(
        "ALIVE:XAAS_PROJECT_MEASURE_REPLAY " <>
          "digest=#{payload["receipt"]["observation_digest"]}"
      )

      :ok
    else
      raise "REFUSED[PROJECT_MEASURE_REPLAY_MISMATCH]"
    end
  end

  def build(config, since, until, rows, opts \\ [])

  def build(config, %DateTime{} = since, %DateTime{} = until, rows, opts)
      when is_map(config) and is_list(rows) and is_list(opts) do
    subject_sha = Keyword.get(opts, :subject_sha)

    with :ok <- validate_config(config),
         :ok <- validate_window(since, until),
         :ok <- validate_subject_sha(subject_sha),
         {:ok, exact_rows, off_subject_count, outside_window_count} <-
           admit_rows(rows, since, until, subject_sha),
         {:ok, runs} <- deduplicate(exact_rows) do
      {:ok,
       observation(
         config,
         since,
         until,
         subject_sha,
         runs,
         off_subject_count,
         outside_window_count
       )
       |> Receipt.attach()}
    end
  end

  def build(_config, _since, _until, _rows, _opts) do
    refusal("PROJECT_MEASURE_INPUT_INVALID")
  end

  defp validate_config(config) do
    required = [:repository, :output_path, :token_env, :subject_sha_env, :api_url]

    if Enum.all?(required, fn key ->
         value = Map.get(config, key)
         is_binary(value) and String.trim(value) != ""
       end) do
      case String.split(config.repository, "/", parts: 2) do
        [owner, name] when owner != "" and name != "" -> :ok
        _ -> refusal("REPOSITORY_IDENTITY_INVALID", "repository=#{config.repository}")
      end
    else
      refusal("PROJECT_MEASURE_CONFIG_INCOMPLETE")
    end
  end

  defp validate_window(since, until) do
    if DateTime.compare(since, until) == :lt do
      :ok
    else
      refusal("PROJECT_MEASURE_WINDOW_INVALID")
    end
  end

  defp validate_subject_sha(sha) when is_binary(sha) do
    if Regex.match?(~r/\A[0-9a-fA-F]{40}\z/, sha) do
      :ok
    else
      refusal("SUBJECT_SHA_INVALID", "sha=#{inspect(sha)}")
    end
  end

  defp validate_subject_sha(_), do: refusal("SUBJECT_SHA_MISSING")

  defp admit_rows(rows, since, until, subject_sha) do
    Enum.reduce_while(rows, {:ok, [], 0, 0}, fn row,
                                               {:ok, admitted, off_subject,
                                                outside_window} ->
      with {:ok, created_at} <- row_time(row),
           {:ok, head_sha} <- row_head_sha(row) do
        cond do
          DateTime.compare(created_at, since) == :lt or
              DateTime.compare(created_at, until) != :lt ->
            {:cont, {:ok, admitted, off_subject, outside_window + 1}}

          head_sha != subject_sha ->
            {:cont, {:ok, admitted, off_subject + 1, outside_window}}

          true ->
            {:cont, {:ok, [row | admitted], off_subject, outside_window}}
        end
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, admitted, off_subject, outside_window} ->
        {:ok, Enum.reverse(admitted), off_subject, outside_window}

      error ->
        error
    end
  end

  defp row_time(%{"created_at" => value}) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      _ -> refusal("CI_RUN_TIMESTAMP_INVALID", "created_at=#{inspect(value)}")
    end
  end

  defp row_time(_), do: refusal("CI_RUN_TIMESTAMP_INVALID")

  defp row_head_sha(%{"head_sha" => sha}) when is_binary(sha) and sha != "", do: {:ok, sha}
  defp row_head_sha(_), do: refusal("CI_RUN_SUBJECT_IDENTITY_MISSING")

  defp deduplicate(rows) do
    Enum.reduce_while(rows, {:ok, %{}}, fn row, {:ok, by_identity} ->
      with {:ok, identity} <- identity(row) do
        case Map.fetch(by_identity, identity) do
          :error ->
            {:cont, {:ok, Map.put(by_identity, identity, row)}}

          {:ok, ^row} ->
            {:cont, {:ok, by_identity}}

          {:ok, _different} ->
            {:halt,
             refusal("CI_RUN_IDENTITY_CONFLICT", "identity=#{identity}")}
        end
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, by_identity} ->
        runs =
          by_identity
          |> Map.values()
          |> Enum.map(&project/1)
          |> Enum.sort_by(& &1["identity"])

        {:ok, runs}

      error ->
        error
    end
  end

  defp identity(%{"id" => id}) when is_integer(id), do: {:ok, "id:#{id}"}

  defp identity(%{"node_id" => node_id}) when is_binary(node_id) and node_id != "" do
    {:ok, "node:#{node_id}"}
  end

  defp identity(_), do: refusal("CI_RUN_IDENTITY_MISSING")

  defp project(row) do
    %{
      "identity" => elem(identity(row), 1),
      "name" => value(row, "name"),
      "event" => value(row, "event"),
      "status" => value(row, "status"),
      "conclusion" => nullable_value(row, "conclusion"),
      "head_sha" => value(row, "head_sha"),
      "created_at" => value(row, "created_at"),
      "updated_at" => nullable_value(row, "updated_at"),
      "html_url" => nullable_value(row, "html_url")
    }
  end

  defp observation(
         config,
         since,
         until,
         subject_sha,
         runs,
         off_subject_count,
         outside_window_count
       ) do
    completed = Enum.filter(runs, &(&1["status"] == "completed"))
    pending = Enum.reject(runs, &(&1["status"] == "completed"))
    failure_like = Enum.filter(completed, &(&1["conclusion"] in @failure_like))
    successful = Enum.filter(completed, &(&1["conclusion"] == "success"))

    %{
      "schema" => @schema,
      "subject" => %{
        "repository" => config.repository,
        "sha" => subject_sha
      },
      "window" => %{
        "since_inclusive" => iso_z(since),
        "until_exclusive" => iso_z(until)
      },
      "sensor" => %{
        "provider" => "github-actions",
        "api_url" => config.api_url,
        "authority" => "OBSERVE_ONLY"
      },
      "summary" => %{
        "subject_run_count" => length(runs),
        "completed_run_count" => length(completed),
        "pending_run_count" => length(pending),
        "successful_run_count" => length(successful),
        "failure_like_run_count" => length(failure_like),
        "off_subject_run_count" => off_subject_count,
        "outside_window_run_count" => outside_window_count,
        "conclusion_counts" =>
          completed
          |> Enum.map(&(&1["conclusion"] || "none"))
          |> Enum.frequencies(),
        "evidence_state" => evidence_state(runs, pending, failure_like)
      },
      "runs" => runs,
      "standing" => standing(runs, failure_like),
      "claim_ceiling" => "OBSERVED_EXACT_SUBJECT_GITHUB_ACTIONS",
      "exclusions" => [
        "successful CI does not prove repository correctness",
        "non-GitHub CI providers",
        "local-only test/build evidence",
        "workflow runs outside the exact subject SHA",
        "workflow runs outside the exact half-open observation window",
        "release, deployment, billing, cloud, or infrastructure actuation"
      ]
    }
  end

  defp evidence_state([], _pending, _failure_like), do: "NO_OBSERVED_CI"
  defp evidence_state(_runs, _pending, [_ | _]), do: "FAILURE_LIKE"
  defp evidence_state(_runs, [_ | _], _failure_like), do: "PENDING"
  defp evidence_state(_runs, _pending, _failure_like), do: "COMPLETED_NO_FAILURE_LIKE"

  defp standing([], _failure_like), do: "UNKNOWN"
  defp standing(_runs, [_ | _]), do: "BUILD_BROKEN"
  defp standing(_runs, _failure_like), do: "PARTIAL_ALIVE"

  defp write!(path, payload) do
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, Jason.encode!(payload, pretty: true) <> "\n")
  end

  defp emit_summary(payload) do
    summary = payload["summary"]

    IO.puts(
      "#{payload["standing"]}:XAAS_PROJECT_MEASURE " <>
        "repository=#{payload["subject"]["repository"]} " <>
        "sha=#{payload["subject"]["sha"]} " <>
        "runs=#{summary["subject_run_count"]} " <>
        "failure_like=#{summary["failure_like_run_count"]} " <>
        "digest=#{payload["receipt"]["observation_digest"]}"
    )
  end

  defp value(row, key) do
    case Map.get(row, key) do
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  defp nullable_value(row, key) do
    case Map.get(row, key) do
      nil -> nil
      value when is_binary(value) -> value
      _ -> nil
    end
  end

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
