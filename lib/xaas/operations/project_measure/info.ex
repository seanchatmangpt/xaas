defmodule Xaas.Operations.ProjectMeasure.Info do
  @moduledoc false

  @path [:project_measure, :github_actions]

  def config(domain) do
    %{
      repository: opt(domain, :repository),
      output_path: opt(domain, :output_path),
      token_env: opt(domain, :token_env, "GITHUB_TOKEN"),
      subject_sha_env: opt(domain, :subject_sha_env, "GITHUB_SHA"),
      api_url: opt(domain, :api_url, "https://api.github.com")
    }
  end

  defp opt(domain, key, default \\ nil) do
    Spark.Dsl.Extension.get_opt(domain, @path, key, default)
  end
end
