defmodule ExNounVerbCli.EscriptTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Escript
  alias ExNounVerbCli.Test.CalcRegistry

  describe "run/2" do
    test "dispatches a single group and encodes the ok envelope as JSON" do
      {status, json} = Escript.run(CalcRegistry, ["calc", "add", "--x", "2", "--y", "3"])

      assert status == :ok
      assert Jason.decode!(json) == %{"status" => "ok", "result" => 5}
    end

    test "dispatches a single group and encodes the error envelope as JSON" do
      {status, json} = Escript.run(CalcRegistry, ["calc", "unknown-verb"])

      assert status == :error
      assert %{"status" => "error", "error" => %{"code" => "unknown_verb"}} = Jason.decode!(json)
    end

    test "chains multiple groups via ++ into a JSON array, ok when all groups succeed" do
      {status, json} =
        Escript.run(CalcRegistry, [
          "calc",
          "add",
          "--x",
          "2",
          "--y",
          "3",
          "++",
          "calc",
          "multiply",
          "--x",
          "4",
          "--y",
          "5"
        ])

      assert status == :ok

      assert Jason.decode!(json) == [
               %{"status" => "ok", "result" => 5},
               %{"status" => "ok", "result" => 20}
             ]
    end

    test "chains multiple groups, overall status is error when any group errors" do
      {status, json} =
        Escript.run(CalcRegistry, [
          "calc",
          "add",
          "--x",
          "2",
          "--y",
          "3",
          "++",
          "calc",
          "unknown-verb"
        ])

      assert status == :error
      assert [%{"status" => "ok"}, %{"status" => "error"}] = Jason.decode!(json)
    end
  end

  describe "the real ExNounVerbCli.Examples.Calc example CLI end-to-end" do
    test "add via the toy calc registry proves the whole core pipeline" do
      {status, json} =
        Escript.run(ExNounVerbCli.Examples.Calc.Registry, [
          "calc",
          "add",
          "--x",
          "2",
          "--y",
          "3"
        ])

      assert status == :ok
      assert Jason.decode!(json) == %{"status" => "ok", "result" => 5}
    end
  end

  describe "--introspect" do
    test "returns the full registry manifest wrapped in the ok envelope" do
      {status, json} = Escript.run(CalcRegistry, ["--introspect"])

      assert status == :ok

      assert %{
               "status" => "ok",
               "result" => %{
                 "nouns" => %{"calc" => ["add", "boom", "echo-profile", "multiply"]},
                 "verbs" => verbs
               }
             } = Jason.decode!(json)

      assert length(verbs) == length(CalcRegistry.list_verbs())
    end

    test "with a noun argument, returns just that noun's verbs" do
      {status, json} = Escript.run(CalcRegistry, ["--introspect", "calc"])

      assert status == :ok
      assert %{"result" => %{"nouns" => %{"calc" => [_ | _]}}} = Jason.decode!(json)
    end
  end

  describe "--help (v26.9.16)" do
    test "renders usage and the full command table for the registry, plain text, exit ok" do
      {status, help} = Escript.run(CalcRegistry, ["--help"])

      assert status == :ok
      assert help =~ "ex_noun_verb_cli <noun> <verb> [options]"
      assert help =~ "--x <integer> (required)"
      assert help =~ "Chaining (++ separates groups):"
      assert help =~ "@{N.path}"
    end

    test "filters to one noun when given" do
      {status, help} = Escript.run(CalcRegistry, ["--help", "calc"])

      assert status == :ok
      assert help =~ "calc:"
    end
  end

  describe "--completions (v26.9.16)" do
    test "emits a bash script naming the command, every noun and verb" do
      {status, script} = Escript.run(CalcRegistry, ["--completions", "bash"])

      assert status == :ok
      assert script =~ "complete -F _ex_noun_verb_cli_completions ex_noun_verb_cli"
      assert script =~ ~s(compgen -W "add boom echo-profile multiply")
      assert script =~ "--profile-id"
    end

    test "a consumer can rename the completed command via config" do
      previous = Application.get_env(:ex_noun_verb_cli, :completion_command)
      Application.put_env(:ex_noun_verb_cli, :completion_command, "greet_cli")
      on_exit(fn -> Application.delete_env(:ex_noun_verb_cli, :completion_command) end)

      {status, script} = Escript.run(CalcRegistry, ["--completions", "fish"])
      assert status == :ok
      assert script =~ "complete -c greet_cli"

      if previous, do: Application.put_env(:ex_noun_verb_cli, :completion_command, previous)
    end

    test "an unported shell returns the typed error envelope, not a script or crash" do
      {status, json} = Escript.run(CalcRegistry, ["--completions", "powershell"])

      assert status == :error

      assert %{
               "status" => "error",
               "error" => %{
                 "code" => "invalid_option",
                 "detail" => %{
                   "invalid" => [%{"flag" => "--completions", "value" => "powershell"}]
                 }
               }
             } = Jason.decode!(json)
    end

    test "an unknown shell is refused the same way" do
      {status, json} = Escript.run(CalcRegistry, ["--completions", "tcsh"])

      assert status == :error

      assert %{"error" => %{"detail" => %{"invalid" => [%{"value" => "tcsh"}]}}} =
               Jason.decode!(json)
    end
  end

  describe "@{N.path} reference threading across chained groups" do
    test "a later group consumes an earlier group's result" do
      {status, json} =
        Escript.run(CalcRegistry, [
          "calc",
          "add",
          "--x",
          "2",
          "--y",
          "3",
          "++",
          "calc",
          "multiply",
          "--x",
          "@{0.result}",
          "--y",
          "5"
        ])

      assert status == :ok
      assert [%{"result" => 5}, %{"result" => 25}] = Jason.decode!(json)
    end

    test "a reference can reach into an earlier group's error envelope" do
      {status, json} =
        Escript.run(CalcRegistry, [
          "calc",
          "boom",
          "++",
          "calc",
          "echo-profile",
          "--profile-id",
          "@{0.error.code}"
        ])

      assert status == :error
      assert [%{"status" => "error"}, %{"result" => "handler_raised"}] = Jason.decode!(json)
    end

    test "a bad reference resolves to empty string and surfaces as the next group's own error envelope" do
      {status, json} =
        Escript.run(CalcRegistry, [
          "calc",
          "add",
          "--x",
          "2",
          "--y",
          "3",
          "++",
          "calc",
          "multiply",
          "--x",
          "@{0.nope}",
          "--y",
          "5"
        ])

      assert status == :error

      assert [
               %{"result" => 5},
               %{
                 "status" => "error",
                 "error" => %{
                   "code" => "invalid_option",
                   "detail" => %{"invalid" => [%{"flag" => "--x", "value" => ""}]}
                 }
               }
             ] = Jason.decode!(json)
    end

    test "an inline reference splices a prior group's result mid-token (v26.9.16)" do
      {status, json} =
        Escript.run(CalcRegistry, [
          "calc",
          "add",
          "--x",
          "2",
          "--y",
          "3",
          "++",
          "calc",
          "echo-profile",
          "--profile-id",
          "run-@{0.result}-final"
        ])

      assert status == :ok
      assert [%{"result" => 5}, %{"result" => "run-5-final"}] = Jason.decode!(json)
    end
  end
end
