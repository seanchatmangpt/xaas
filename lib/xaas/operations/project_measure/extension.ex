defmodule Xaas.Operations.ProjectMeasure.Extension do
  @moduledoc """
  Ash/Spark extension for read-only project measurement.

  The extension configures observation only. It grants no mutation, release,
  deployment, billing, or infrastructure authority. Its verifier rejects
  malformed identity, artifact, environment, and sensor configuration before a
  host Ash domain can acquire standing.
  """

  @github_actions %Spark.Dsl.Section{
    name: :github_actions,
    schema: [
      repository: [type: :string, required: true],
      output_path: [type: :string, required: true],
      token_env: [type: :string, default: "GITHUB_TOKEN"],
      subject_sha_env: [type: :string, default: "GITHUB_SHA"],
      api_url: [type: :string, default: "https://api.github.com"]
    ]
  }

  @project_measure %Spark.Dsl.Section{
    name: :project_measure,
    sections: [@github_actions]
  }

  use Spark.Dsl.Extension,
    sections: [@project_measure],
    verifiers: [Xaas.Operations.ProjectMeasure.Verifiers.ValidateConfiguration]
end
