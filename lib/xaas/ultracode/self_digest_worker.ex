defmodule Xaas.Ultracode.SelfDigestWorker do
  @moduledoc """
  The production caller of the self-digest vertical
  (`Xaas.Ultracode.CapitalCensus.SelfDigest.Run.digest/1`): a daily Oban
  job (crontab in `config :xaas, Oban`) that digests the wave loop's
  telemetry window and ADMITS every recurring, ontology-classified frontier
  cluster as a `CapitalCensus.WorkOrder` whose subject is UltraCode itself
  (`SelfDigest.Run.self_subject/0`) through the generated ExperienceCluster
  -> Gap -> WorkOrder chain. Clusters the law refuses (unknown shape) are
  recorded as receipted candidates only.

  Queue: `:ultracode_wave` -- the queue the repo's hand-written ultracode
  Oban worker (`Xaas.Ultracode.SemanticWaveTrigger.Worker`) uses, so the
  digest never overlaps a wave's promote step.

  Options come from `config :xaas, :ultracode_self_digest` (see
  config/config.exs), overridable per job via string args
  (`"telemetry_path"`, `"out_dir"`, `"window_minutes"`). A missing
  telemetry path is a typed refusal
  `{:error, {:self_digest_unconfigured, :telemetry_path}}`.

  Every successful run writes `self-digest-receipt.json` into `out_dir`.
  """

  use Oban.Worker, queue: :ultracode_wave, max_attempts: 1

  alias Xaas.Ultracode.CapitalCensus.SelfDigest.Run, as: SelfDigest

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    case run(args) do
      {:ok, _summary} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Runs one digest with admission. Returns `{:ok, summary}` (the JSON-safe
  receipt also written to disk) or a typed `{:error, {reason, detail}}`.
  """
  @spec run(map()) :: {:ok, map()} | {:error, term()}
  def run(args \\ %{}) do
    with {:ok, opts} <- options(args),
         {:ok, report} <- SelfDigest.digest(Map.put(opts, :admit?, Map.get(opts, :admit?, true))) do
      summary = SelfDigest.summary(report)
      File.mkdir_p!(opts.out_dir)

      File.write!(
        Path.join(opts.out_dir, "self-digest-receipt.json"),
        Jason.encode!(summary, pretty: true)
      )

      {:ok, summary}
    end
  end

  @doc """
  Resolves digest options: job args win over `:ultracode_self_digest`
  config; the telemetry path falls back to the wave loop's configured
  `:ultracode_wave_loop_telemetry_path`.
  """
  @spec options(map()) :: {:ok, map()} | {:error, {atom(), term()}}
  def options(args) do
    config = Application.get_env(:xaas, :ultracode_self_digest, [])

    telemetry_path =
      args["telemetry_path"] || config[:telemetry_path] ||
        Application.get_env(:xaas, :ultracode_wave_loop_telemetry_path)

    out_dir = args["out_dir"] || config[:out_dir] || "tmp/self-digest"
    window = args["window_minutes"] || config[:window_minutes] || 24 * 60

    admit? =
      case args["admit"] do
        false -> false
        _ -> Keyword.get(config, :admit, true)
      end

    cond do
      not is_binary(telemetry_path) ->
        {:error, {:self_digest_unconfigured, :telemetry_path}}

      not (is_integer(window) and window > 0) ->
        {:error, {:self_digest_invalid_window, window}}

      true ->
        {:ok,
         %{
           telemetry_path: telemetry_path,
           out_dir: out_dir,
           window_minutes: window,
           admit?: admit?
         }}
    end
  end
end
