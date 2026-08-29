defmodule Mix.Tasks.Xaas.Install.AshAdminTest do
  @moduledoc """
  Chicago-style: runs the real Igniter task (`Mix.Tasks.Xaas.Install.AshAdmin.igniter/1`)
  against a real `Igniter.Test.test_project/1` in-memory project and asserts on the real
  resulting source patch / notice content -- no mocked Igniter collaborator. Modeled on
  ash_r2rml's `test/mix/tasks/ash_r2rml_install_test.exs`.
  """
  use ExUnit.Case, async: true

  import Igniter.Test

  test "without --target, leaves a manual-instructions notice" do
    igniter =
      test_project()
      |> Igniter.compose_task("xaas.install.ash_admin", [])

    assert Enum.any?(igniter.notices, &(&1 =~ "requires --target"))
    assert Enum.any?(igniter.notices, &(&1 =~ "--target MyApp.SomeDomain"))
  end

  test "with --target, patches the target domain with AshAdmin.Domain and a real admin do show? true end block" do
    igniter =
      test_project(
        files: %{
          "lib/my_app/billing.ex" => """
          defmodule MyApp.Billing do
            use Ash.Domain,
              otp_app: :my_app
          end
          """
        }
      )
      |> Igniter.compose_task("xaas.install.ash_admin", ["--target", "MyApp.Billing"])

    source = Rewrite.source!(igniter.rewrite, "lib/my_app/billing.ex")
    content = Rewrite.Source.get(source, :content)

    assert content =~ "AshAdmin.Domain"
    assert content =~ "admin do"
    assert content =~ "show?(true)"
  end

  test "with --target, re-running against an already-patched domain does not duplicate the admin block" do
    igniter =
      test_project(
        files: %{
          "lib/my_app/billing.ex" => """
          defmodule MyApp.Billing do
            use Ash.Domain,
              otp_app: :my_app,
              extensions: [AshAdmin.Domain]

            admin do
              show? true
            end
          end
          """
        }
      )
      |> Igniter.compose_task("xaas.install.ash_admin", ["--target", "MyApp.Billing"])

    source = Rewrite.source!(igniter.rewrite, "lib/my_app/billing.ex")
    content = Rewrite.Source.get(source, :content)

    assert length(String.split(content, "admin do")) == 2
  end
end
