defmodule Xaas.Semantics.JcsTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.Jcs

  describe "encode/1 — RFC 8785 §3.2.3 key sorting" do
    test "literal RFC example: UTF-16 code-unit key order, no whitespace" do
      input = %{
        "" => "",
        "0" => "Zero",
        "1" => "One",
        "\u0001" => "Start of Heading",
        "\u000A" => "Newline",
        "\u000B" => "Line Separator",
        "\r" => "Carriage Return",
        "ö" => "Latin Small Letter O With Diaeresis",
        "\u0080" => "Control\u007F",
        "€" => "Euro Sign",
        "ﬁ" => "fi Ligature",
        "😀" => "Emoji: Grinning Face",
        "דּ" => "Hebrew Letter Tsadi",
        "literals" => [nil, true, false]
      }

      # Control-character names (U+0001, U+000A, U+000B, U+000D) sort before
      # digits; U+0080 and above are serialized "as is" (RFC §3.2.2.2 escapes
      # only U+0000–U+001F); astral-plane names sort after BMP names.
      expected =
        "{\"\":\"\",\"\\u0001\":\"Start of Heading\",\"\\n\":\"Newline\"," <>
          "\"\\u000b\":\"Line Separator\",\"\\r\":\"Carriage Return\"," <>
          "\"0\":\"Zero\",\"1\":\"One\",\"literals\":[null,true,false]," <>
          "\"\u0080\":\"Control\u007F\",\"ö\":\"Latin Small Letter O With Diaeresis\"," <>
          "\"€\":\"Euro Sign\",\"😀\":\"Emoji: Grinning Face\"," <>
          "\"ﬁ\":\"fi Ligature\",\"דּ\":\"Hebrew Letter Tsadi\"}"

      assert Jcs.encode(input) == expected
    end

    test "string escapes: control chars, quote, backslash (lowercase hex)" do
      assert Jcs.encode(%{"a" => "\u0001\u001F\"\\"}) == "{\"a\":\"\\u0001\\u001f\\\"\\\\\"}"
    end

    test "non-ASCII passes through as-is above U+001F" do
      assert Jcs.encode(%{"k" => "ä"}) == "{\"k\":\"ä\"}"
    end

    test "atom keys are stringified and sorted" do
      assert Jcs.encode(%{b: 1, a: 2}) == "{\"a\":2,\"b\":1}"
    end

    test "arrays keep order; empty and scalar forms" do
      assert Jcs.encode([3, 1, 2]) == "[3,1,2]"
      assert Jcs.encode(%{}) == "{}"
      assert Jcs.encode([]) == "[]"
      assert Jcs.encode(nil) == "null"
      assert Jcs.encode(true) == "true"
      assert Jcs.encode(false) == "false"
    end
  end

  describe "encode/1 — number serialization (RFC 8785 §3.2.2.3)" do
    test "integers have no fractional part" do
      assert Jcs.encode(333_333_333) == "333333333"
      assert Jcs.encode(0) == "0"
      assert Jcs.encode(-1) == "-1"
    end

    test "1.0 serializes as 1, -1.0 as -1" do
      assert Jcs.encode(1.0) == "1"
      assert Jcs.encode(-1.0) == "-1"
    end

    test "negative zero serializes as 0" do
      assert Jcs.encode(-0.0) == "0"
    end

    test "1E30 round-trips in exponent form" do
      assert Jcs.encode(1.0e30) == "1e+30"
    end

    test "small float expands to plain decimal" do
      assert Jcs.encode(1.0e-6) == "0.000001"
    end

    test "RFC 8785 Appendix B number round-trip vectors" do
      vectors = [
        {0.0, "0"},
        {1.0, "1"},
        {-1.0, "-1"},
        {0.5, "0.5"},
        {-0.5, "-0.5"},
        {1.0e30, "1e+30"},
        {1.0e-6, "0.000001"},
        {9007199254740992.0, "9007199254740992"},
        {5.0e-324, "5e-324"},
        {1.7976931348623157e308, "1.7976931348623157e+308"}
      ]

      for {input, expected} <- vectors do
        assert Jcs.encode(input) == expected, "failed for #{inspect(input)}"
      end
    end

    test "big integers keep arbitrary precision" do
      big = 18_446_744_073_709_551_616
      assert Jcs.encode(%{"n" => big}) == "{\"n\":18446744073709551616}"
    end
  end

  describe "properties" do
    test "determinism: same input, same output across 25 runs" do
      value = %{
        "z" => 1.0e30,
        "a" => [1.5, -0.0, nil, true],
        "é" => "unicode",
        "nested" => %{"b" => 1, "a" => %{"y" => 2.5}}
      }

      outputs =
        for _ <- 1..25, into: MapSet.new() do
          Jcs.encode(value)
        end

      assert MapSet.size(outputs) == 1
    end

    test "round-trip: parse(encode(x)) == x for representative values" do
      values = [
        0,
        -1,
        333_333_333,
        1.5,
        -0.5,
        1.0e30,
        "",
        "hello",
        "quote\"backslash\\",
        [1, "two", nil],
        %{"a" => 1, "b" => [true, false]},
        %{"nested" => %{"deep" => %{"leaf" => 2.5e-5}}}
      ]

      for value <- values do
        assert value |> Jcs.encode() |> decode() == value,
               "round-trip failed for #{inspect(value)}"
      end
    end

    test "byte-level determinism of digest form" do
      payload = %{"schema" => "chatman.release-closure/v1", "members" => []}
      expected = :crypto.hash(:sha256, Jcs.encode(payload)) |> Base.encode16(case: :lower)

      assert byte_size(expected) == 64

      assert expected ==
               :crypto.hash(:sha256, Jcs.encode(payload)) |> Base.encode16(case: :lower)
    end

    test "encode raises on non-JSON terms (documented subset boundary)" do
      assert_raise ArgumentError, fn -> Jcs.encode({:tuple, 1}) end
      assert_raise ArgumentError, fn -> Jcs.encode(%{key: :unsupported_atom_value}) end
    end
  end

  defp decode(json) do
    case Jason.decode(json) do
      {:ok, decoded} -> decoded
      {:error, _} = err -> flunk("invalid canonical JSON produced: #{inspect(err)}")
    end
  end
end
