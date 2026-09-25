defmodule ExNounVerbCli.ChainingTest do
  use ExUnit.Case, async: false

  alias ExNounVerbCli.Chaining

  test "expand/1 returns a single-group list unchanged when there is no ++" do
    assert Chaining.expand(["calc", "add", "--x", "2"]) == [["calc", "add", "--x", "2"]]
  end

  test "expand/1 splits on the literal ++ token into multiple groups" do
    argv = ["calc", "add", "--x", "1", "++", "calc", "multiply", "--x", "2"]

    assert Chaining.expand(argv) == [
             ["calc", "add", "--x", "1"],
             ["calc", "multiply", "--x", "2"]
           ]
  end

  test "expand/1 handles more than one ++ split" do
    argv = ["a", "++", "b", "++", "c"]

    assert Chaining.expand(argv) == [["a"], ["b"], ["c"]]
  end

  test "expand/1 leaves an @{N.path} token unresolved, as documented" do
    assert Chaining.expand(["@{0.result}"]) == [["@{0.result}"]]
  end

  # The following two tests drive Chaining.expand/1 in a real subprocess so
  # that "@-" and "@-::json.path" resolve against a real, genuinely piped
  # stdin stream (via `mix run -e ...` in a shell pipeline) rather than any
  # in-process fake of the :stdio device.

  test "expand/1 resolves @- against real piped stdin in a real subprocess" do
    script = "IO.write(inspect(ExNounVerbCli.Chaining.expand([\"@-\"])))"
    cmd = "printf '%s' 'hello world' | mix run --no-start -e '#{script}'"

    {output, 0} = System.cmd("sh", ["-c", cmd], cd: File.cwd!(), stderr_to_stdout: false)

    assert output =~ ~s([["hello world"]])
  end

  test "expand/1 resolves @-::json.path against real piped JSON stdin in a real subprocess" do
    script = "IO.write(inspect(ExNounVerbCli.Chaining.expand([\"@-::a.b.c\"])))"
    json = ~s({"a":{"b":{"c":42}}})
    cmd = "printf '%s' '#{json}' | mix run --no-start -e '#{script}'"

    {output, 0} = System.cmd("sh", ["-c", cmd], cd: File.cwd!(), stderr_to_stdout: false)

    assert output =~ ~s([["42"]])
  end

  describe "resolve_references/2" do
    # Real envelopes -- the exact maps JsonOutput.encode/2 produces -- not
    # mocks; a state-based check that the token is replaced with the dug,
    # stringified value.
    @ok_envelope %{"result" => 5, "status" => "ok"}
    @error_envelope %{
      "error" => %{"code" => "handler_raised", "detail" => %{"exception" => "RuntimeError"}},
      "status" => "error"
    }

    test "resolves @{N.result} to the prior group's stringified result" do
      group = ["calc", "multiply", "--x", "@{0.result}", "--y", "5"]

      assert Chaining.resolve_references(group, [@ok_envelope]) ==
               ["calc", "multiply", "--x", "5", "--y", "5"]
    end

    test "resolves deep dotted paths into error envelopes" do
      assert Chaining.resolve_references(["--code", "@{1.error.code}"], [
               @ok_envelope,
               @error_envelope
             ]) ==
               ["--code", "handler_raised"]

      assert Chaining.resolve_references(["--e", "@{1.error.detail.exception}"], [
               @ok_envelope,
               @error_envelope
             ]) ==
               ["--e", "RuntimeError"]
    end

    test "an out-of-range index or missing path resolves to empty string, never raises" do
      assert Chaining.resolve_references(["--x", "@{9.result}"], [@ok_envelope]) == ["--x", ""]
      assert Chaining.resolve_references(["--x", "@{0.nope}"], [@ok_envelope]) == ["--x", ""]

      assert Chaining.resolve_references(["--x", "@{0.result.deeper}"], [@ok_envelope]) == [
               "--x",
               ""
             ]
    end

    test "a non-map value stringifies with the same rules as @-::path" do
      envelope = %{"result" => %{"nested" => [1, 2]}, "status" => "ok"}

      assert Chaining.resolve_references(["--x", "@{0.result.nested}"], [envelope]) ==
               ["--x", Jason.encode!([1, 2])]
    end

    test "tokens that merely look like references pass through untouched" do
      assert Chaining.resolve_references(["@{result}", "@{a.b"], []) == ["@{result}", "@{a.b"]
    end

    test "inline references splice inside larger tokens, surrounding bytes kept (v26.9.16)" do
      assert Chaining.resolve_references(
               ["--tag", "run-@{0.result}-final"],
               [%{"result" => 5, "status" => "ok"}]
             ) == ["--tag", "run-5-final"]
    end

    test "multiple inline references in one token resolve left to right" do
      envelopes = [
        %{"result" => 2, "status" => "ok"},
        %{"result" => 3, "status" => "ok"}
      ]

      assert Chaining.resolve_references(["@{0.result}x@{1.result}y@{0.result}"], envelopes) ==
               ["2x3y2"]
    end

    test "an inline bad reference splices empty string, keeping the surrounding bytes" do
      assert Chaining.resolve_references(
               ["--name", "pre-@{9.nope}-post"],
               [%{"result" => 5, "status" => "ok"}]
             ) == ["--name", "pre--post"]
    end

    test "inline non-string values stringify; brace-like non-references stay untouched" do
      assert Chaining.resolve_references(
               ["v@{0.error.code}"],
               [%{"error" => %{"code" => "handler_raised"}, "status" => "error"}]
             ) == ["vhandler_raised"]

      assert Chaining.resolve_references(["a@{not-a-ref}b"], []) == ["a@{not-a-ref}b"]
    end
  end
end
