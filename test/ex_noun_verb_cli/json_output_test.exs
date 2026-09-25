defmodule ExNounVerbCli.JsonOutputTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.{Error, JsonOutput}

  test "encode(:ok, term) produces a real ok envelope that round-trips through Jason" do
    envelope = JsonOutput.encode(:ok, %{"sum" => 5})
    json = Jason.encode!(envelope)

    assert Jason.decode!(json) == %{"status" => "ok", "result" => %{"sum" => 5}}
  end

  test "encode(:error, error) produces a real error envelope that round-trips through Jason" do
    error = Error.new(:unknown_verb, "no such verb", %{noun: "calc"})
    envelope = JsonOutput.encode(:error, error)
    json = Jason.encode!(envelope)

    assert Jason.decode!(json) == %{
             "status" => "error",
             "error" => %{
               "code" => "unknown_verb",
               "message" => "no such verb",
               "detail" => %{"noun" => "calc"}
             }
           }
  end

  test "encode_string/1 wraps Jason.encode!/1 and round-trips" do
    term = %{"a" => 1}
    json = JsonOutput.encode_string(term)

    assert json == Jason.encode!(term)
    assert Jason.decode!(json) == term
  end

  test "encode(:error, ...) sanitizes non-encodable detail terms -- the envelope must \
        always serialize, even for handler-supplied detail (raw OptionParser tuples \
        crashed Jason.encode!/1 in the escript, 2026-09-15)" do
    error =
      ExNounVerbCli.Error.new(:invalid_option, "unrecognized option(s)", %{
        "invalid" => [{"--x-y", nil}],
        "nested" => [%{"keep" => 1}, {"--x", "7\n"}],
        {1, 2} => "tuple key gets inspected"
      })

    json = JsonOutput.encode_string(JsonOutput.encode(:error, error))

    assert %{
             "error" => %{
               "detail" => %{
                 "invalid" => [["--x-y", nil]],
                 "nested" => [%{"keep" => 1}, ["--x", "7\n"]],
                 "{1, 2}" => "tuple key gets inspected"
               }
             }
           } = Jason.decode!(json)
  end
end
