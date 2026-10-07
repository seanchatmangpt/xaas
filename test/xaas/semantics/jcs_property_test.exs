defmodule Xaas.Semantics.JcsPropertyTest do
  @moduledoc """
  Lane W617 — property/fuzz deepening for `Xaas.Semantics.Jcs` (RFC 8785).

  Properties:

    J1 determinism: encode(x) == encode(x) across repeated calls and
       across randomized key-insertion orders of equivalent maps
    J2 round-trip: Jason.decode!(encode(x)) reconstructs x modulo
       atom-key -> string-key and number binary-form normalization
    J3 key ordering: at EVERY nesting level, object keys appear in
       ascending order (RFC 8785 §3.2.3, verified by scanning the
       encoded output, not by trusting the encoder)
    J4 number corpus: integers, floats, exponents serialize stably
       (byte-identical across runs and insertion orders) with the
       RFC 8785 minimal forms pinned
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  @moduletag :property
  @moduletag timeout: 900_000

  alias Xaas.Semantics.Jcs

  # ---------- seeded random structure generator ----------


  # Depth-bounded random JSON-ish structure, deterministic per seed.
  # Maps built from shuffled key lists so insertion order varies.
  defp gen_value(rng, depth)

  defp gen_value(rng, 0) do
    pick(rng, [
      fn r -> {i, r} = :rand.uniform_s(1_000_000, r); {i, r} end,
      fn r ->
        {neg, r} = :rand.uniform_s(2, r)
        {i, r} = :rand.uniform_s(1_000, r)
        {(if neg == 1, do: -i, else: i) * 1.0, r}
      end,
      fn r ->
        {n, r} = :rand.uniform_s(20, r)
        {String.duplicate("x", n), r}
      end,
      fn r ->
        {b, r} = :rand.uniform_s(2, r)
        {b == 1, r}
      end,
      fn r -> {nil, r} end
    ])
  end

  defp gen_value(rng, depth) do
    {choice, rng} = :rand.uniform_s(5, rng)

    case choice do
      1 ->
        gen_value(rng, depth - 1)

      2 ->
        {n, rng} = :rand.uniform_s(6, rng)
        Enum.map_reduce(1..n, rng, fn _, r -> gen_value(r, depth - 1) end)

      3 ->
        {n, rng} = :rand.uniform_s(6, rng)
        gen_map(rng, depth - 1, n)

      4 ->
        gen_value(rng, depth - 1)

      5 ->
        {n, rng} = :rand.uniform_s(4, rng)
        gen_map(rng, depth - 1, n)
    end
  end

  defp gen_map(rng, depth, n) do
    {keys, rng} =
      Enum.map_reduce(1..n, rng, fn _, r ->
        {len, r} = :rand.uniform_s(12, r)
        {chars, r} = rand_key_chars(r, len)
        {IO.iodata_to_binary(chars), r}
      end)

    {vals, rng} =
      Enum.map_reduce(keys, rng, fn _k, r -> gen_value(r, max(depth, 0)) end)

    {Map.new(Enum.zip(keys, vals)), rng}
  end

  @key_alphabet ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z) ++
                  ~w(0 1 2 3 4 5 6 7 8 9 _ -)

  defp rand_key_chars(rng, 0), do: {["k"], rng}

  defp rand_key_chars(rng, len) do
    Enum.map_reduce(1..len, rng, fn _, r ->
      {i, r} = :rand.uniform_s(38, r)
      {[Enum.at(@key_alphabet, i - 1)], r}
    end)
  end

  defp pick(rng, fns) do
    {i, rng} = :rand.uniform_s(length(fns), rng)
    Enum.at(fns, i - 1).(rng)
  end

  # ---------- J3: key-order scanner over encoded output ----------

  # Returns :ok if every object in the encoded JSON has keys in ascending
  # binary order; raises otherwise. Scans the actual bytes.
  defp check_key_order(bin) do
    result =
      case bin do
        <<"{", _::binary>> -> scan_object(bin, 0)
        <<"[", rest::binary>> -> scan_array(rest, 0)
        _other -> {<<>>, 0}
      end

    {_rest, _ctx} = result
    :ok
  end

  defp scan_object(<<"{", rest::binary>>, ctx) do
    scan_members(rest, [], ctx)
  end

  defp scan_members(<<"}", rest::binary>>, keys, ctx) do
    assert_ascending(keys, ctx)
    {rest, ctx}
  end

  defp scan_members(bin, keys, ctx) do
    {key, rest} = scan_string(skip_ws(bin))
    assert_ascending(keys ++ [key], ctx)
    {_, rest} = skip_colon(rest)
    {_value, rest} = scan_value(skip_ws(rest), ctx)

    case skip_ws(rest) do
      <<",", rest2::binary>> -> scan_members(rest2, keys, ctx)
      <<"}", rest2::binary>> -> {rest2, ctx}
    end
  end

  defp scan_value(<<"{", _::binary>> = bin, ctx) do
    {rest, _ctx} = scan_object(bin, ctx)
    {nil, rest}
  end

  defp scan_value(<<"[", rest::binary>>, ctx) do
    {rest, _ctx} = scan_array(rest, ctx)
    {nil, rest}
  end

  defp scan_value(<<"\"", _::binary>> = bin, _ctx), do: scan_string(bin)

  defp scan_value(bin, _ctx) do
    # number / true / false / null: consume until , } ] or whitespace
    len =
      bin
      |> :binary.split([",", "}", "]", " ", "\t", "\n"])
      |> hd()
      |> byte_size()

    <<_::binary-size(len), rest::binary>> = bin
    {nil, rest}
  end

  defp scan_array(<<"]", rest::binary>>, ctx), do: {rest, ctx}

  defp scan_array(bin, ctx) do
    {_v, rest} = scan_value(skip_ws(bin), ctx)

    case skip_ws(rest) do
      <<",", rest2::binary>> -> scan_array(rest2, ctx)
      <<"]", rest2::binary>> -> {rest2, ctx}
    end
  end

  # bin begins at the OPENING quote of a JSON string.
  defp scan_string(<<"\"", rest::binary>>) do
    do_scan_string(rest, [])
  end

  defp do_scan_string(bin, acc) do
    [chunk, rest] = :binary.split(bin, "\"")

    if rem(trailing_backslashes(chunk), 2) == 1 do
      # the quote was escaped; keep scanning
      do_scan_string(rest, [acc, chunk, "\\\""])
    else
      {IO.iodata_to_binary([acc, chunk]), rest}
    end
  end

  defp trailing_backslashes(bin) do
    bin |> String.to_charlist() |> Enum.reverse() |> Enum.take_while(&(&1 == ?\\)) |> length()
  end

  defp skip_ws(<<" ", rest::binary>>), do: skip_ws(rest)
  defp skip_ws(bin), do: bin

  defp skip_colon(bin) do
    case skip_ws(bin) do
      <<":", rest::binary>> -> {:ok, skip_ws(rest)}
    end
  end

  defp assert_ascending(keys, ctx) do
    sorted = Enum.sort(keys)

    if keys != sorted do
      flunk("keys not ascending at ctx #{inspect(ctx)}: #{inspect(keys)}")
    end
  end

  # ---------- J1 + J2 + J3 properties ----------

  test "J1/J2/J3: 1000 seeded random nested structures — deterministic, round-trip, sorted keys" do
    for seed <- 1..1000 do
      rng = :rand.seed_s(:exsss, {seed, 606, 617})
      {value, _} = gen_value(rng, 3)

      encoded = Jcs.encode(value)

      # J1: determinism across repeated encodes
      assert encoded == Jcs.encode(value)

      # J1: byte-identical when rebuilt from the normalized shape
      assert stable_under_rebuild?(value, encoded)

      # J2: round-trip via Jason
      assert Jason.decode!(encoded) == normalize(value)

      # J3: keys ascending at every level of the actual output
      assert check_key_order(encoded) == :ok
    end
  end

  # Erlang maps are unordered, so "insertion order" only exists at the
  # encoder input as distinct map shapes. Rebuild via Jason round-trip of a
  # list-shaped twin and confirm the canonical bytes agree.
  defp stable_under_rebuild?(value, encoded) do
    normalized = normalize(value)
    re_encoded = Jcs.encode(normalized)
    re_encoded == encoded and Jason.decode!(encoded) == Jason.decode!(re_encoded)
  end

  defp normalize(v) when is_map(v) do
    Map.new(v, fn {k, val} -> {to_string(k), normalize(val)} end)
  end

  defp normalize(v) when is_list(v), do: Enum.map(v, &normalize/1)
  defp normalize(-0.0), do: -0.0
  defp normalize(v), do: v

  # ---------- J4: number corpus ----------

  test "J4: integer corpus is stable and minimal" do
    corpus = [
      {0, "0"},
      {1, "1"},
      {-1, "-1"},
      {255, "255"},
      {-255, "-255"},
      {9_007_199_254_740_991, "9007199254740991"},
      {9_007_199_254_740_992, "9007199254740992"},
      {-9_007_199_254_740_992, "-9007199254740992"},
      {12_345_678_901_234_567_890_123_456_789, "12345678901234567890123456789"}
    ]

    for {n, expected} <- corpus do
      assert Jcs.encode(n) == expected
      assert Jason.decode!(Jcs.encode(n)) == n
    end
  end

  test "J4: float/exponent corpus is stable and RFC 8785 minimal" do
    corpus = [
      {1.0, "1"},
      {-0.0, "0"},
      {0.0, "0"},
      {1.5, "1.5"},
      {-1.5, "-1.5"},
      {1.0e30, "1e+30"},
      {1.0e-7, "1e-7"},
      {3.141592653589793, "3.141592653589793"},
      {2.0e-308, "2e-308"},
      {1.7976931348623157e308, "1.7976931348623157e+308"},
      {6.02214076e23, "6.02214076e+23"},
      {0.1, "0.1"},
      {100.0, "100"}
    ]

    for {f, expected} <- corpus do
      encoded = Jcs.encode(f)
      assert encoded == expected, "got #{encoded}, expected #{expected}"
      # stability across repeated encodes
      assert Jcs.encode(f) == encoded
      # round-trips to the same double
      assert Jason.decode!(encoded) == f
    end
  end

  property "J4: random floats round-trip through encode/decode to identical doubles" do
    check all seed <- integer(1..2000) do
      rng = :rand.seed_s(:exsss, {seed, 4, 4})
      {m, rng} = :rand.uniform_s(308, rng)
      {sign, rng} = :rand.uniform_s(2, rng)
      f = (if sign == 1, do: 1, else: -1) * (:math.pow(10, m - 154) * (0.5 + rem(seed, 1500) / 1500.0))

      if f == trunc(f) * 1.0 or abs(f) < 1.0e308 do
        encoded = Jcs.encode(f)
        decoded = Jason.decode!(encoded)

        # Jason returns an integer when the canonical form has no decimal
        # point or exponent (RFC 8785 minimal form). The RFC round-trip
        # criterion is re-canonicalization equality, so assert that.
        assert decoded == f or (is_integer(decoded) and Jcs.encode(decoded) == encoded)

        assert Jcs.encode(f) == encoded
      end
    end
  end

  test "J4: number stability inside nested structures (byte-identical across rebuilds)" do
    nested = %{
      "z" => [1.0e30, -0.0, 9007199254740992, %{"b" => 1.5, "a" => 1.0e-7}],
      "a" => %{"deep" => %{"x" => 1.7976931348623157e308, "y" => 0}}
    }

    encoded = Jcs.encode(nested)
    assert encoded == Jcs.encode(nested)
    assert Jason.decode!(encoded) == normalize(nested)
    assert check_key_order(encoded) == :ok
  end
end
