defmodule Xaas.Operations.ProjectMeasure.Verifiers.ValidateConfiguration do
  @moduledoc """
  Fail-closed admission for the project-measurement Spark DSL.

  The verifier runs after the host Ash domain has compiled, so it validates the
  final extension state without manufacturing runtime authority or mutating the
  DSL. Invalid repository identities, artifact paths, environment-variable
  names, and non-HTTPS sensor endpoints are rejected before the domain can stand.
  """

  use Spark.Dsl.Verifier

  @path [:project_measure, :github_actions]
  @env_name ~r/\A[A-Z_][A-Z0-9_]*\z/

  @impl true
  def verify(dsl_state) do
    with :ok <- validate_repository(option(dsl_state, :repository), dsl_state),
         :ok <- validate_output_path(option(dsl_state, :output_path), dsl_state),
         :ok <- validate_env_name(:token_env, option(dsl_state, :token_env), dsl_state),
         :ok <-
           validate_env_name(
             :subject_sha_env,
             option(dsl_state, :subject_sha_env),
             dsl_state
           ),
         :ok <- validate_api_url(option(dsl_state, :api_url), dsl_state) do
      :ok
    end
  end

  defp option(dsl_state, name) do
    Spark.Dsl.Verifier.get_option(dsl_state, @path, name)
  end

  defp validate_repository(repository, _dsl_state)
       when is_binary(repository) and repository != "" do
    case String.split(repository, "/") do
      [owner, name] ->
        if valid_slug?(owner) and valid_slug?(name) do
          :ok
        else
          :invalid
        end

      _ ->
        :invalid
    end
    |> case do
      :ok -> :ok
      :invalid -> error(:repository, "repository must be exactly owner/name", _dsl_state)
    end
  end

  defp validate_repository(_repository, dsl_state) do
    error(:repository, "repository must be a non-empty owner/name string", dsl_state)
  end

  defp valid_slug?(value) do
    value != "" and not String.match?(value, ~r/[\s\/]/)
  end

  defp validate_output_path(path, dsl_state) when is_binary(path) and path != "" do
    cond do
      Path.type(path) != :relative ->
        error(:output_path, "output_path must be relative to the application root", dsl_state)

      ".." in Path.split(path) ->
        error(:output_path, "output_path may not escape the application root", dsl_state)

      true ->
        :ok
    end
  end

  defp validate_output_path(_path, dsl_state) do
    error(:output_path, "output_path must be a non-empty relative path", dsl_state)
  end

  defp validate_env_name(option_name, value, dsl_state)
       when is_binary(value) and value != "" do
    if Regex.match?(@env_name, value) do
      :ok
    else
      error(option_name, "must be a valid environment-variable name", dsl_state)
    end
  end

  defp validate_env_name(option_name, _value, dsl_state) do
    error(option_name, "must be a non-empty environment-variable name", dsl_state)
  end

  defp validate_api_url(value, dsl_state) when is_binary(value) and value != "" do
    uri = URI.parse(value)

    if uri.scheme == "https" and is_binary(uri.host) and uri.host != "" and is_nil(uri.userinfo) do
      :ok
    else
      error(:api_url, "api_url must be an HTTPS origin without userinfo", dsl_state)
    end
  end

  defp validate_api_url(_value, dsl_state) do
    error(:api_url, "api_url must be a non-empty HTTPS origin", dsl_state)
  end

  defp error(option_name, message, dsl_state) do
    {:error,
     Spark.Error.DslError.exception(
       message: message,
       path: @path ++ [option_name],
       module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
     )}
  end
end
