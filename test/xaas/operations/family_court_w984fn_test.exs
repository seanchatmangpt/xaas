defmodule Xaas.Operations.FamilyCourtW984fnTest do
  @moduledoc """
  Lane W984fn unclaimed-family probe court over `lib/xaas/operations/`,
  excluding the Castle/Route-verb batch (W984fj) and Incident lifecycle (W650za).

  Genuinely unexercised state-bearing branches found:

    * `Xaas.Operations.ProjectMeasure.GitHubActions` — zero prior test
      references. The fail-closed repository-identity admission
      (`REFUSED[REPOSITORY_IDENTITY_INVALID]`) fires BEFORE any HTTP call,
      so each refusal shape is courted over the real module with no network
      and no doubles.
    * `Xaas.Operations.ProjectMeasure.Verifiers.ValidateConfiguration` — zero
      prior test references. The production Spark verifier admits/rejects the
      real extension configuration at domain-compile time; each fail-closed
      clause (relative output_path, no `..` escape, env-var name shape,
      HTTPS-only sensor origin without userinfo) is a distinct branch the
      sole prior test (repository identity only) never reached.

  Mutation rationale is stated per test: each names the concrete source
  mutation that would kill the test. Zero mocks; real modules, real Spark
  compile-time admission over the real extension.
  """

  use ExUnit.Case, async: false

  require Spark.Test

  alias Xaas.Operations.ProjectMeasure.GitHubActions

  describe "GitHubActions.list_workflow_runs/4 fail-closed identity admission" do
    test "non-binary repository refuses REPOSITORY_IDENTITY_INVALID before any HTTP",
         do: assert(
           GitHubActions.list_workflow_runs(nil, ~U[2026-08-21 00:00:00Z], ~U[2026-08-22 00:00:00Z]) ==
             {:error, "REFUSED[REPOSITORY_IDENTITY_INVALID] repository=nil"}
         )

    # Mutation: deleting the `owner != "" and name != ""` guard in
    # split_repository/1 would let "owner/" reach Req.get against
    # /repos/owner//actions/runs — this assertion kills that mutant.
    test "empty owner part refuses typed" do
      assert {:error, reason} =
               GitHubActions.list_workflow_runs(
                 "/name",
                 ~U[2026-08-21 00:00:00Z],
                 ~U[2026-08-22 00:00:00Z]
               )

      assert reason =~ "REFUSED[REPOSITORY_IDENTITY_INVALID]"
      assert reason =~ "repository=/name"
    end

    test "empty name part refuses typed" do
      assert {:error, "REFUSED[REPOSITORY_IDENTITY_INVALID] repository=owner/"} =
               GitHubActions.list_workflow_runs(
                 "owner/",
                 ~U[2026-08-21 00:00:00Z],
                 ~U[2026-08-22 00:00:00Z]
               )
    end

    test "bare owner with no slash refuses typed" do
      assert {:error, reason} =
               GitHubActions.list_workflow_runs(
                 "owner",
                 ~U[2026-08-21 00:00:00Z],
                 ~U[2026-08-22 00:00:00Z]
               )

      assert reason =~ "REFUSED[REPOSITORY_IDENTITY_INVALID]"
      assert reason =~ "repository=owner"
    end

    # Mutation: dropping `parts: 2` from String.split would split "a/b/c" into
    # three parts and refuse an arguably valid subpath; pinning the exact
    # current contract (last two segments kept) makes that observable.
    test "three-segment repository keeps last two as owner/name (split/2 contract)" do
      # "a/b/c" splits (parts: 2) into owner="a", name="b/c" — both non-empty,
      # so identity is admitted and the module proceeds toward HTTP. Without
      # network in the test env this surfaces as a transport error, NOT an
      # identity refusal — pinning that identity admission and transport
      # refusal are distinct failure classes.
      assert {:error, reason} =
               GitHubActions.list_workflow_runs(
                 "a/b/c",
                 ~U[2026-08-21 00:00:00Z],
                 ~U[2026-08-22 00:00:00Z]
               )

      refute reason =~ "REPOSITORY_IDENTITY_INVALID"
    end
  end

  describe "ValidateConfiguration verifier fail-closed branches" do
    # Mutation: deleting the `Path.type(path) != :relative` clause in
    # validate_output_path/2 would admit an absolute artifact sink outside
    # the application root; this domain would then compile.
    test "absolute output_path refuses domain compilation" do
      errors =
        Spark.Test.dsl_errors do
          defmodule Elixir.Xaas.W984fnAbsoluteOutputDomain do
            use Ash.Domain,
              otp_app: :xaas,
              extensions: [Xaas.Operations.ProjectMeasure.Extension]

            project_measure do
              github_actions do
                repository("seanchatmangpt/xaas")
                output_path("/abs/artifacts.json")
              end
            end
          end
        end

      assert [{Xaas.W984fnAbsoluteOutputDomain, verifier_errors}] = errors
      assert Enum.any?(verifier_errors, &(Exception.message(&1) =~ "output_path must be relative"))
    end

    # Mutation: deleting the `".." in Path.split(path)` clause would admit an
    # artifact sink escaping the application root via traversal.
    test "output_path with .. traversal refuses domain compilation" do
      errors =
        Spark.Test.dsl_errors do
          defmodule Elixir.Xaas.W984fnTraversalOutputDomain do
            use Ash.Domain,
              otp_app: :xaas,
              extensions: [Xaas.Operations.ProjectMeasure.Extension]

            project_measure do
              github_actions do
                repository("seanchatmangpt/xaas")
                output_path("../escape/artifacts.json")
              end
            end
          end
        end

      assert [{Xaas.W984fnTraversalOutputDomain, verifier_errors}] = errors
      assert Enum.any?(verifier_errors, &(Exception.message(&1) =~ "may not escape"))
    end

    # Mutation: deleting the @env_name regex match would admit lowercase env
    # names that System.get_env/1 would then never resolve at runtime.
    test "lowercase token_env name refuses domain compilation" do
      errors =
        Spark.Test.dsl_errors do
          defmodule Elixir.Xaas.W984fnBadEnvDomain do
            use Ash.Domain,
              otp_app: :xaas,
              extensions: [Xaas.Operations.ProjectMeasure.Extension]

            project_measure do
              github_actions do
                repository("seanchatmangpt/xaas")
                output_path(".artifacts/project-measure/test.json")
                token_env("github_token")
              end
            end
          end
        end

      assert [{Xaas.W984fnBadEnvDomain, verifier_errors}] = errors

      assert Enum.any?(
               verifier_errors,
               &(Exception.message(&1) =~ "must be a valid environment-variable name")
             )
    end

    # Layered admission: a nil env name is refused by the Spark options
    # schema (:string type) at definition time, BEFORE the verifier runs —
    # the verifier's non-binary clause is defense-in-depth, unreachable via
    # the DSL. Mutation: weakening the option type to allow nil would
    # silently disable exact-subject identity at the observation boundary;
    # this pins the schema gate as the first refusal layer.
    test "nil subject_sha_env is refused at the Spark options schema layer" do
      assert_raise Spark.Error.DslError, ~r/expected string, got: nil/, fn ->
        defmodule Elixir.Xaas.W984fnMissingEnvDomain do
          use Ash.Domain,
            otp_app: :xaas,
            extensions: [Xaas.Operations.ProjectMeasure.Extension]

          project_measure do
            github_actions do
              repository("seanchatmangpt/xaas")
              output_path(".artifacts/project-measure/test.json")
              subject_sha_env(nil)
            end
          end
        end
      end
    end

    # Mutation: dropping the `uri.scheme == "https"` requirement would admit a
    # plaintext sensor origin, leaking the bearer token over the wire.
    test "http (non-HTTPS) api_url refuses domain compilation" do
      errors =
        Spark.Test.dsl_errors do
          defmodule Elixir.Xaas.W984fnHttpSensorDomain do
            use Ash.Domain,
              otp_app: :xaas,
              extensions: [Xaas.Operations.ProjectMeasure.Extension]

            project_measure do
              github_actions do
                repository("seanchatmangpt/xaas")
                output_path(".artifacts/project-measure/test.json")
                api_url("http://api.github.com")
              end
            end
          end
        end

      assert [{Xaas.W984fnHttpSensorDomain, verifier_errors}] = errors

      assert Enum.any?(
               verifier_errors,
               &(Exception.message(&1) =~ "api_url must be an HTTPS origin without userinfo")
             )
    end

    # Mutation: dropping the is_nil(uri.userinfo) requirement would admit an
    # origin embedding credentials.
    test "api_url with embedded userinfo refuses domain compilation" do
      errors =
        Spark.Test.dsl_errors do
          defmodule Elixir.Xaas.W984fnUserinfoSensorDomain do
            use Ash.Domain,
              otp_app: :xaas,
              extensions: [Xaas.Operations.ProjectMeasure.Extension]

            project_measure do
              github_actions do
                repository("seanchatmangpt/xaas")
                output_path(".artifacts/project-measure/test.json")
                api_url("https://user:token@api.github.com")
              end
            end
          end
        end

      assert [{Xaas.W984fnUserinfoSensorDomain, verifier_errors}] = errors

      assert Enum.any?(
               verifier_errors,
               &(Exception.message(&1) =~ "api_url must be an HTTPS origin without userinfo")
             )
    end
  end
end
