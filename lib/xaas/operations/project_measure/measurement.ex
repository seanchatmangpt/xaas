defmodule Xaas.Operations.ProjectMeasure.Measurement do
  @moduledoc """
  Stateless Ash resource exposing exact-subject project measurement.

  This resource exists for Ash ecosystem integration, not persistence. It has no
  create/update/destroy actions and no database table. Its `:measure` generic
  action is implemented by `Xaas.Operations.ProjectMeasure.Reactor`, so Ash owns
  input typing, authorization, tracing, JSON:API dispatch, and TypeScript RPC
  while Reactor owns workflow orchestration and the existing census/receipt core
  owns semantic admission.

  The GraphQL query uses the `:measure_json` projection because an unconstrained
  map has no honest static GraphQL object shape. That projection carries the same
  receipt-bearing observation as canonical JSON rather than fabricating a schema.
  """

  use Xaas.Resource,
    otp_app: :kanban,
    domain: Xaas.Operations,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource, AshGraphql.Resource, AshTypescript.Resource]

  alias Xaas.Operations.ProjectMeasure.Types.SubjectSha

  typescript do
    type_name("ProjectMeasurement")
  end

  policies do
    bypass action(:measure) do
      authorize_if(always())
    end

    bypass action(:measure_json) do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end

  json_api do
    type("project_measurement")

    routes do
      base("/project_measurement")
      route(:get, "/measure", :measure)
    end
  end

  graphql do
    queries do
      action(:project_measure_json, :measure_json)
    end
  end

  code_interface do
    define(:measure, args: [:subject_sha, :since, :until])
    define(:measure_json, args: [:subject_sha, :since, :until])
  end

  actions do
    action :measure, :map do
      description("Observe and admit GitHub Actions evidence for one exact project commit.")

      argument :subject_sha, SubjectSha do
        allow_nil?(false)
      end

      argument :since, :utc_datetime do
        allow_nil?(false)
      end

      argument :until, :utc_datetime do
        allow_nil?(false)
      end

      run(Xaas.Operations.ProjectMeasure.Reactor)
    end

    action :measure_json, :string do
      description("GraphQL-safe canonical JSON projection of the exact project measurement.")

      argument :subject_sha, SubjectSha do
        allow_nil?(false)
      end

      argument :since, :utc_datetime do
        allow_nil?(false)
      end

      argument :until, :utc_datetime do
        allow_nil?(false)
      end

      run fn input, _context ->
        case Reactor.run(Xaas.Operations.ProjectMeasure.Reactor, input.arguments) do
          {:ok, payload} -> {:ok, Xaas.Operations.ProjectMeasure.Receipt.canonical_json(payload)}
          {:error, error} -> {:error, error}
        end
      end
    end
  end
end
