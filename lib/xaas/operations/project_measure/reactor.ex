defmodule Xaas.Operations.ProjectMeasure.AdmissionReactor do
  @moduledoc """
  Pure Reactor court for already-observed GitHub Actions rows.

  This reactor is intentionally transport-free. It exists so the same
  exact-subject admission and receipt construction used by the live workflow can
  be executed deterministically against captured observations without granting
  network authority.
  """

  use Reactor

  alias Xaas.Operations.ProjectMeasure.Census

  input :config
  input :subject_sha
  input :since
  input :until
  input :rows

  step :admit do
    argument :config, input(:config)
    argument :subject_sha, input(:subject_sha)
    argument :since, input(:since)
    argument :until, input(:until)
    argument :rows, input(:rows)

    run fn arguments, _context ->
      Census.build(
        arguments.config,
        arguments.since,
        arguments.until,
        arguments.rows,
        subject_sha: arguments.subject_sha
      )
    end
  end

  return :admit
end

defmodule Xaas.Operations.ProjectMeasure.Reactor do
  @moduledoc """
  Live, OBSERVE-only Reactor workflow for exact-subject project measurement.

  The workflow separates configuration, transport observation, semantic
  admission, and telemetry. Its only external transport is the GET-only GitHub
  Actions sensor. The returned value is the deterministic receipt-bearing
  observation map; artifact persistence remains an explicit `Census.observe!/2`
  concern and is not performed by this Ash action workflow.
  """

  use Reactor

  alias Xaas.Operations.ProjectMeasure.{Census, GitHubActions, Info}

  input :subject_sha
  input :since
  input :until

  step :configuration do
    run fn _arguments, _context ->
      {:ok, Info.config(Xaas.Operations)}
    end
  end

  step :observe_runs do
    argument :config, result(:configuration)
    argument :since, input(:since)
    argument :until, input(:until)

    run fn arguments, _context ->
      GitHubActions.list_workflow_runs(
        arguments.config.repository,
        arguments.since,
        arguments.until,
        api_url: arguments.config.api_url,
        token: System.get_env(arguments.config.token_env)
      )
    end
  end

  step :admit do
    argument :config, result(:configuration)
    argument :rows, result(:observe_runs)
    argument :subject_sha, input(:subject_sha)
    argument :since, input(:since)
    argument :until, input(:until)

    run fn arguments, _context ->
      Census.build(
        arguments.config,
        arguments.since,
        arguments.until,
        arguments.rows,
        subject_sha: arguments.subject_sha
      )
    end
  end

  step :emit_telemetry do
    argument :payload, result(:admit)

    run fn %{payload: payload}, _context ->
      summary = payload["summary"]

      :telemetry.execute(
        [:xaas, :operations, :project_measure, :observed],
        %{
          subject_run_count: summary["subject_run_count"],
          failure_like_run_count: summary["failure_like_run_count"]
        },
        %{
          repository: payload["subject"]["repository"],
          subject_sha: payload["subject"]["sha"],
          standing: payload["standing"],
          observation_digest: payload["receipt"]["observation_digest"]
        }
      )

      {:ok, payload}
    end
  end

  return :emit_telemetry
end
