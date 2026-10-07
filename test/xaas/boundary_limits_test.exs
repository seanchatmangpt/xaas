defmodule Xaas.BoundaryLimitsTest do
  use ExUnit.Case, async: true

  @moduledoc """
  True boundary tests for the two caps flagged by V5's receipt
  (docs/sjira/v26.10.6/plans/vector5-limits-lints.md, caps section):

    * `Xaas.Sjira.AtlassianTransport` `truncate/2` 255-byte cap — driven
      through the public, pure `envelope/3` seam (real production function,
      real assertion on returned body bytes).
    * `keep_tail/2` max vs max+1 in `Xaas.Ultracode.Dispatch` and
      `Xaas.Ultracode.Verifier` — both are `defp` with no public seam, so the
      exact production clauses are extracted from the real source files and
      compiled at test time. The code under test is the real shipped bytes,
      not a retyped copy (same extract-and-run-real-source style as
      `DispatcherPreflightOutputTest`).

  Each case asserts post-operation bytes/length, not just no-raise.
  """

  @dispatch_source "lib/xaas/ultracode/dispatch.ex"
  @verifier_source "lib/xaas/ultracode/verifier.ex"

  describe "atlassian_transport truncate/2 255-byte cap (via public envelope/3)" do
    defp envelope_for_summary(summary, capability \\ "boundary-probe", labels \\ []) do
      item = %{
        "route" => "KNOWN",
        "order" => "W54-BOUNDARY",
        "capability" => capability,
        "tuple_digest" => "deadbeef",
        "summary" => summary,
        "labels" => labels
      }

      {:ok, env} =
        Xaas.Sjira.AtlassianTransport.envelope(item, 0,
          base_url: "https://jira.example.test",
          project_key: "XAA",
          request_fun: fn _m, _u, _h, _b -> {:ok, %{status: 200, body: %{"key" => "XAA-1"}}} end
        )

      env
    end

    test "summary at exactly 255 bytes is passed through unchanged" do
      summary = String.duplicate("a", 255)
      env = envelope_for_summary(summary)

      assert byte_size(summary) == 255
      assert env["body"]["fields"]["summary"] == summary
      assert byte_size(env["body"]["fields"]["summary"]) == 255
      assert env["encoded_body"] =~ summary
    end

    test "summary at 256 bytes is truncated to exactly the first 255 bytes" do
      summary = String.duplicate("a", 255) <> "Z"
      env = envelope_for_summary(summary)

      truncated = env["body"]["fields"]["summary"]
      assert byte_size(truncated) == 255
      assert truncated == String.duplicate("a", 255)
      refute truncated =~ "Z"
    end

    test "summary at 256 bytes loses exactly one byte, not more" do
      summary = String.duplicate("x", 200) <> String.duplicate("y", 56)
      env = envelope_for_summary(summary)

      truncated = env["body"]["fields"]["summary"]
      assert byte_size(truncated) == 255
      assert truncated == String.duplicate("x", 200) <> String.duplicate("y", 55)
    end

    test "labels are capped at 255 bytes by the same truncate/2" do
      long_label = String.duplicate("l", 300)
      env = envelope_for_summary("ok", "boundary-probe", [long_label])

      labels = env["body"]["fields"]["labels"]
      assert is_list(labels)

      Enum.each(labels, fn label ->
        assert byte_size(label) <= 255
      end)

      assert byte_size(String.replace(List.first(labels), "xaas-sjira", "")) <= 255
      assert long_label not in labels
      assert String.duplicate("l", 255) in labels
    end
  end

  describe "keep_tail/2 boundary (extracted real production clauses)" do
    @keep_tail_regex ~r/defp keep_tail\(bin, max\) when byte_size\(bin\) <= max, do: bin\n\s*defp keep_tail\(bin, max\), do: binary_part\(bin, byte_size\(bin\) - max, max\)/

    defp compile_keep_tail(source_path, module_name) do
      source = File.read!(Path.expand("../../" <> source_path, __DIR__))

      case Regex.run(@keep_tail_regex, source) do
        [clauses] ->
          body = String.replace(clauses, "defp", "def")

          Code.compile_string("defmodule #{module_name} do\n" <> body <> "\nend")

          module_name

        _ ->
          raise "keep_tail clauses not found verbatim in #{source_path} — " <>
                  "production source drifted; this test must be updated, not silenced"
      end
    end

    test "at exactly max bytes: returned unchanged" do
      mod = compile_keep_tail(@dispatch_source, KeepTailDispatchUnderTest)
      bin = :crypto.strong_rand_bytes(1024)

      assert mod.keep_tail(bin, 1024) == bin
      assert byte_size(mod.keep_tail(bin, 1024)) == 1024
    end

    test "at max+1 bytes: keeps exactly the last max bytes" do
      mod = compile_keep_tail(@dispatch_source, KeepTailDispatchUnderTest)
      bin = :crypto.strong_rand_bytes(1025)

      kept = mod.keep_tail(bin, 1024)
      assert byte_size(kept) == 1024
      assert kept == binary_part(bin, 1, 1024)
    end

    test "boundary distinguishes max vs max+1 (dispatch source)" do
      mod = compile_keep_tail(@dispatch_source, KeepTailDispatchUnderTest)

      at_max = :crypto.strong_rand_bytes(64)
      assert mod.keep_tail(at_max, 64) == at_max

      over = "HEAD" <> at_max
      kept = mod.keep_tail(over, 64)
      assert byte_size(kept) == 64
      assert kept == at_max
      refute kept == over
    end

    test "verifier source clauses behave identically at the boundary" do
      mod = compile_keep_tail(@verifier_source, KeepTailVerifierUnderTest)

      at_max = String.duplicate("v", 255)
      assert mod.keep_tail(at_max, 255) == at_max
      assert mod.keep_tail("Q" <> at_max, 255) == at_max
      assert byte_size(mod.keep_tail("Q" <> at_max, 255)) == 255
    end

    test "empty tail stays empty (min edge)" do
      mod = compile_keep_tail(@dispatch_source, KeepTailDispatchUnderTest)
      assert mod.keep_tail("", 1024) == ""
    end
  end
end
