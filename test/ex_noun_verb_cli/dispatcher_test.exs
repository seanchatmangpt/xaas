defmodule ExNounVerbCli.DispatcherTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Dispatcher
  alias ExNounVerbCli.Test.CalcRegistry

  test "dispatch/2 returns {:error, unknown_verb} for a noun/verb not in the registry" do
    assert {:error, error} = Dispatcher.dispatch(CalcRegistry, ["calc", "subtract"])
    assert error.code == :unknown_verb
    assert error.message =~ "calc"
    assert error.message =~ "subtract"
  end

  test "dispatch/2 returns {:error, missing_required_option} when a required opt is absent" do
    assert {:error, error} = Dispatcher.dispatch(CalcRegistry, ["calc", "add", "--x", "2"])
    assert error.code == :missing_required_option
    assert error.detail.missing == [:y]
  end

  test "dispatch/2 returns {:error, invalid_option} for an option not in the schema" do
    assert {:error, error} =
             Dispatcher.dispatch(CalcRegistry, [
               "calc",
               "add",
               "--x",
               "2",
               "--y",
               "3",
               "--z",
               "4"
             ])

    assert error.code == :invalid_option
  end

  test "dispatch/2's invalid_option detail is Jason-encodable -- the error envelope must \
        always serialize instead of crashing the adapter (raw OptionParser tuples in \
        detail crashed Jason.encode!/1 in the escript, 2026-09-15)" do
    assert {:error, error} =
             Dispatcher.dispatch(CalcRegistry, [
               "calc",
               "add",
               "--x",
               "2",
               "--y",
               "3",
               "--z",
               "4"
             ])

    assert %{invalid: [%{"flag" => "--z", "value" => nil}]} = error.detail

    assert {:ok, _json} = Jason.encode(ExNounVerbCli.JsonOutput.encode(:error, error))
  end

  test "dispatch/2's invalid_option path also covers OptionParser's malformed-value tuples \
        (e.g. --x @- stdin text that fails an :integer cast) without crashing the envelope" do
    assert {:error, error} =
             Dispatcher.dispatch(CalcRegistry, ["calc", "add", "--x", "7\n", "--y", "3"])

    assert error.code == :invalid_option
    assert [%{"flag" => "--x", "value" => "7\n"}] = error.detail.invalid
    assert {:ok, _json} = Jason.encode(ExNounVerbCli.JsonOutput.encode(:error, error))
  end

  test "dispatch/2 accepts the canonical kebab-case long flag" do
    assert {:ok, "acme"} =
             Dispatcher.dispatch(CalcRegistry, ["calc", "echo-profile", "--profile-id", "acme"])
  end

  test "dispatch/2 also accepts the verbatim snake_case flag as a backward-compatible alias, \
        mirroring the real Rust --profile-id/--profile_id dual acceptance" do
    assert {:ok, "acme"} =
             Dispatcher.dispatch(CalcRegistry, ["calc", "echo-profile", "--profile_id", "acme"])
  end

  test "dispatch/2 accepts the snake_case flag in --flag=value form too" do
    assert {:ok, "acme"} =
             Dispatcher.dispatch(CalcRegistry, ["calc", "echo-profile", "--profile_id=acme"])
  end

  test "dispatch/2 performs a real successful dispatch against a real fixture handler" do
    assert {:ok, 5} =
             Dispatcher.dispatch(CalcRegistry, ["calc", "add", "--x", "2", "--y", "3"])

    assert {:ok, 6} =
             Dispatcher.dispatch(CalcRegistry, [
               "calc",
               "multiply",
               "--x",
               "2",
               "--y",
               "3"
             ])
  end

  test "dispatch/2 catches a real raised exception and returns {:error, handler_raised}" do
    assert {:error, error} = Dispatcher.dispatch(CalcRegistry, ["calc", "boom"])
    assert error.code == :handler_raised
    assert error.message =~ "handler exploded"
  end
end
