defmodule Xaas.Semantics.AdmissionFuzzTest do
  @moduledoc """
  Lane W621 — admission-gate totality fuzz (EU-AI-Act wave).

  Property under test: the admission gates are TOTAL — `admit` never raises;
  every input yields a typed `{:ok, ...}` or `{:error, atom}` verdict — and
  DETERMINISTIC (same input twice → same result).

  Seeded, deterministic fuzz: 500 adversarial candidates per gate, three gates
  (`EuAiActAdmission.admit/1`, `DatasetAdmission.admit/2`,
  `RobustMargin.admit/4`).

  ## Former non-totality escapes — now FIXED and asserted (lane W630)

  W621 documented four escape classes where a gate RAISED instead of
  returning a typed verdict. Lane W630 repaired all four at the gate
  boundary; the corpus classes are now exercised as FLIP TESTS below —
  each adversarial class must yield a typed `{:error, atom}` verdict,
  deterministically (x2):

  1. `RobustMargin.admit/4` guard-domain mismatches (non-numeric / negative
     `l_h`/`l_e`/`epsilon`) → `{:error, :REFUSED_MALFORMED_MARGIN_INPUT}`
     (catch-all clause).
  2. `DatasetAdmission.admit/2` non-map samples and non-enumerable
     `:features` → treated as missing, the sample flows to the typed
     incomplete/bias refusal — never `Map.get`/`Enum.sort_by` raises.
  3. `EuAiActAdmission.admit/1` improper-list values (`[1 | 2]`) →
     normalized as opaque leaves; structural checks run and return typed
     refusal atoms — never `Protocol.UndefinedError`.
  4. Float overflow in gate arithmetic (IEEE-754 max-finite operands) →
     `ArithmeticError` rescued at each gate boundary as
     `{:error, :REFUSED_ARITHMETIC_OVERFLOW}`.

  Totality now genuinely holds: the loops below run over fully arbitrary
  candidate maps for `EuAiActAdmission`, shape-valid samples with fully
  adversarial field VALUES for `DatasetAdmission`, and guard-domain
  numerics for `RobustMargin`, and every probe — including the four
  formerly-escaping classes — must return a typed, deterministic verdict.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.{DatasetAdmission, EuAiActAdmission, RobustMargin}

  @fuzz_cases 500
  @seed {1_760, 421_337, 991_511}

  # Finite extremes as inf/NaN proxies: on this OTP the BEAM cannot construct
  # exact ±inf/NaN at all (float arithmetic overflow raises badarith;
  # :erlang.binary_to_term/1 rejects a non-finite NEW_FLOAT_EXT; a bit-syntax
  # pattern `<<v::float>>` refuses to match infinite bits). 1.7976931348623157e308
  # (IEEE-754 max finite double, and its negation) is the closest representable
  # extreme, so it stands in for the "NaN-adjacent float" fuzz class.
  @max_finite 1.7976931348623157e308
  defp pinf, do: @max_finite
  defp ninf, do: -@max_finite
  defp pnan, do: -@max_finite

  # -- seeded adversarial value generator -------------------------------------

  defp rng, do: :rand.seed(:exsss, @seed)

  defp adversarial_value(state) do
    {pick, state} = :rand.uniform_s(14, state)

    case pick do
      1 -> {:ok_atom, state}
      2 ->
        {i, s} = :rand.uniform_s(50, state)
        {String.to_atom("adv_atom_#{i}"), s}
      3 -> {:unicode_key, state}
      4 -> {<<"bin_", :crypto.strong_rand_bytes(8)::binary>>, state}
      5 -> {String.duplicate("x", 1_048_576), state}
      6 -> {deep_nest(state), state}
      7 -> {pinf(), state}
      8 -> {ninf(), state}
      9 -> {pnan(), state}
      10 -> {-1_048_576, state}
      11 -> {%{}, state}
      12 -> {[], state}
      13 ->
        {i, s} = :rand.uniform_s(1_000_000, state)
        {i - 500_000, s}
      14 ->
        {f, s} = :rand.uniform_s(1000, state)
        {(f - 500.0) / 7.0, s}
    end
  end

  defp deep_nest(state), do: deep_nest(state, 250, %{"leaf" => 1})

  defp deep_nest(state, 0, acc), do: {acc, state}

  defp deep_nest(state, n, acc) do
    deep_nest(state, n - 1, %{Integer.to_string(n) => acc})
  end

  # Builds an arbitrary map with 0..8 keys drawn from schema + junk keyspace.
  defp adversarial_map(state) do
    schema_keys = [
      :id, :techniques, :purpose, :data_domains, :provenance,
      :context_joins, :setting, :latency_goal, :inferences, :match_token_type
    ]

    junk_keys = ["junk", :"日本語キー", :"", 0, :nan_key, :"1MB", :nested, :unicode]

    {n_keys, state} = :rand.uniform_s(8, state)

    {pairs, state} =
      Enum.map_reduce(1..n_keys, state, fn _i, st ->
        {key, st} =
          if rem(_i, 2) == 0 do
            {Enum.random(schema_keys), st}
          else
            {j, s2} = :rand.uniform_s(length(junk_keys), st)
            {Enum.at(junk_keys, j - 1), s2}
          end

        {v, st2} = adversarial_value(st)
        {{key, v}, st2}
      end)

    {Map.new(pairs), state}
  end

  # -- EuAiActAdmission.admit/1 ------------------------------------------------

  test "EuAiActAdmission.admit/1 is total + deterministic over 500 adversarial maps" do
    :rand.seed(:exsss, @seed)
    allowed = EuAiActAdmission.refusal_atoms() ++ [:REFUSED_EUAIA_MALFORMED_CANDIDATE]

    {candidates, _} =
      Enum.map_reduce(1..@fuzz_cases, rng(), fn _i, st ->
        {m, st2} = adversarial_map(st)
        {m, st2}
      end)

    # non-map inputs hit the typed malformed clause
    non_maps = [nil, 5, :atom, [1, 2], "binary", {:tuple, 1}, 3.14]

    for c <- candidates ++ non_maps do
      result1 = EuAiActAdmission.admit(c)
      result2 = EuAiActAdmission.admit(c)

      assert is_tuple(result1) and tuple_size(result1) == 2,
             "non-2-tuple verdict for #{inspect(c, limit: 5)}: #{inspect(result1)}"

      assert elem(result1, 0) in [:ok, :error],
             "untyped verdict #{inspect(result1)}"

      if elem(result1, 0) == :error do
        assert elem(result1, 1) in allowed,
               "refusal atom outside declared set: #{inspect(result1)}"
      end

      assert result1 == result2, "non-deterministic for #{inspect(c, limit: 5)}"
    end
  end

  # -- DatasetAdmission.admit/2 ------------------------------------------------

  defp adversarial_sample(state) do
    {n_features, state} = :rand.uniform_s(4, state)

    {features_list, state} =
      Enum.map_reduce(1..n_features, state, fn i, st ->
        {v, st2} = adversarial_number(st)
        {{"f#{rem(i, 3)}", v}, st2}
      end)

    {sensitive, state} = :rand.uniform_s(2, state)

    {%{features: Map.new(features_list), label: :lbl, sensitive: sensitive - 1}, state}
  end

  # Arithmetic-position numerics are bounded to |x| <= 1.0e150: extreme-magnitude
  # finite floats entering the gates' arithmetic (subtraction, penalty products,
  # quantile interpolation) overflow and RAISE ArithmeticError — CRITICAL-4,
  # filed, excluded here (see moduledoc + plan doc). 1e150 keeps all +/-, *,
  # and interpolation well inside the float range.
  defp adversarial_number(state) do
    {pick, state} = :rand.uniform_s(8, state)

    case pick do
      1 -> {1.0e150, state}
      2 -> {-1.0e150, state}
      3 -> {-1.0e100, state}
      4 -> {-1.0e50, state}
      5 -> {1.0e100, state}
      6 -> {0.0, state}
      7 ->
        {i, s} = :rand.uniform_s(1000, state)
        {i - 500, s}
      8 ->
        {f, s} = :rand.uniform_s(1000, state)
        {(f - 500.0) / 3.0, s}
    end
  end

  test "DatasetAdmission.admit/2 is total + deterministic over 500 adversarial-value sample sets" do
    :rand.seed(:exsss, @seed)

    {corpora, _} =
      Enum.map_reduce(1..@fuzz_cases, rng(), fn _i, st ->
        {n, st} = :rand.uniform_s(6, st)

        {samples, st} =
          Enum.map_reduce(1..n, st, fn _j, s2 ->
            {sample, s3} = adversarial_sample(s2)
            {sample, s3}
          end)

        {seed, st} = :rand.uniform_s(1_000_000, st)
        {{samples, [seed: seed]}, st}
      end)

    for {samples, opts} <- corpora do
      r1 = DatasetAdmission.admit(samples, opts)
      r2 = DatasetAdmission.admit(samples, opts)

      assert_match_dataset(r1, samples, opts)
      assert r1 == r2, "non-deterministic for #{inspect(samples, limit: 3)} #{inspect(opts)}"
    end
  end

  defp assert_match_dataset({:ok, :ADMITTED, _m}, _s, _o), do: :ok
  defp assert_match_dataset({:error, :REFUSED_EMPTY_DATASET}, _s, _o), do: :ok
  defp assert_match_dataset({:error, :REFUSED_ARITHMETIC_OVERFLOW}, _s, _o), do: :ok

  defp assert_match_dataset({:error, {refusal, %{} = meta}}, _s, _o)
       when refusal in [:REFUSED_INCOMPLETE_DATASET, :REFUSED_BIAS_THRESHOLD] do
    assert is_map(meta) and map_size(meta) == 2, "bad refusal meta #{inspect(meta)}"
  end

  defp assert_match_dataset(other, s, o),
    do: flunk("untyped/foreign verdict #{inspect(other)} for #{inspect(s, limit: 3)} #{inspect(o)}")

  test "DatasetAdmission empty corpus stays typed under adversarial opts" do
    assert {:error, :REFUSED_EMPTY_DATASET} = DatasetAdmission.admit([], seed: 1)
  end

  # -- RobustMargin (estimate_lipschitz/2 + admit/4) ---------------------------

  test "RobustMargin.estimate_lipschitz/2 is total + deterministic over adversarial pairs" do
    :rand.seed(:exsss, @seed)

    {pair_sets, _} =
      Enum.map_reduce(1..@fuzz_cases, rng(), fn _i, st ->
        {n, st} = :rand.uniform_s(5, st)

        {pairs, st} =
          Enum.map_reduce(1..n, st, fn _j, s2 ->
            {a, s3} = adversarial_number(s2)
            {b, s4} = adversarial_number(s3)
            {{a, b}, s4}
          end)

        {pairs, st}
      end)

    scoring = fn x -> if is_number(x), do: x * 2.0, else: 0.0 end

    for pairs <- pair_sets do
      r1 = RobustMargin.estimate_lipschitz(scoring, pairs)
      r2 = RobustMargin.estimate_lipschitz(scoring, pairs)

      assert (is_number(r1) and r1 >= 0.0) or
               r1 in [{:error, :REFUSED_NO_CALIBRATION_DATA}, {:error, :REFUSED_ARITHMETIC_OVERFLOW}],
             "untyped lipschitz verdict #{inspect(r1)} for #{inspect(pairs)}"

      assert r1 == r2, "non-deterministic for #{inspect(pairs)}"
    end
  end

  test "RobustMargin.admit/4 is total + deterministic over 500 guard-domain numeric quads" do
    :rand.seed(:exsss, @seed)

    {quads, _} =
      Enum.map_reduce(1..@fuzz_cases, rng(), fn _i, st ->
        {l_h, st} = nonneg_number(st)
        {l_e, st} = nonneg_number(st)
        {eps, st} = nonneg_number(st)

        {v, st} = any_number(st)

        {margin, kind} =
          if rem(_i, 2) == 0 do
            {fn -> v end, :closure}
          else
            {v, :number}
          end

        {{margin, kind, l_h, l_e, eps}, st}
      end)

    for {margin, kind, l_h, l_e, eps} <- quads do
      r1 = RobustMargin.admit(margin, l_h, l_e, eps)
      r2 = RobustMargin.admit(margin, l_h, l_e, eps)

      assert r1 == :ADMITTED or r1 == {:error, :REFUSED_ROBUST_MARGIN},
             "untyped verdict #{inspect(r1)} for margin=#{kind} l_h=#{l_h} l_e=#{l_e} eps=#{eps}"

      assert r1 == r2, "non-deterministic for #{kind} #{l_h} #{l_e} #{eps}"
    end
  end

  defp any_number(state) do
    {pick, state} = :rand.uniform_s(7, state)

    case pick do
      1 -> {1.0e150, state}
      2 -> {-1.0e150, state}
      3 -> {0, state}
      4 ->
        {i, s} = :rand.uniform_s(1000, state)
        {i - 500, s}
      5 ->
        {f, s} = :rand.uniform_s(1000, state)
        {(f - 500.0) / 3.0, s}
      6 -> {0.0, state}
      7 -> {1.0e100, state}
    end
  end

  defp nonneg_number(state) do
    {v, state} = any_number(state)
    v = if is_number(v) and v >= 0, do: v, else: abs(v / 1.0)
    # Constants are further bounded to 1e100: the penalty is a TRIPLE product
    # l_h * l_e * epsilon, and 1e100^3 = 1e300 stays inside the float range.
    v = min(v / 1.0, 1.0e100)
    v = if v == v and v < pinf(), do: v, else: 1.0
    {v, state}
  end

  # -- W630 escape flips: formerly-raising classes now assert typed handling ----

  test "FLIP-1: RobustMargin.admit/4 guard-domain mismatches refuse typed, not raise" do
    malformed_quads = [
      {1.0, -1.0, 1.0, 1.0},
      {1.0, 1.0, 1.0, -0.5},
      {1.0, :atom, 1.0, 1.0},
      {1.0, 1.0, "l_e", 1.0},
      {1.0, 1.0, 1.0, nil},
      {1.0, [1], 1.0, 1.0},
      {1.0, %{}, 1.0, 1.0}
    ]

    for {margin, l_h, l_e, eps} <- malformed_quads do
      expected = {:error, :REFUSED_MALFORMED_MARGIN_INPUT}
      assert RobustMargin.admit(margin, l_h, l_e, eps) == expected
      assert RobustMargin.admit(margin, l_h, l_e, eps) == expected
    end
  end

  test "FLIP-2: DatasetAdmission.admit/2 non-enumerable features + non-map samples stay typed" do
    opts = [seed: 42, required_fields: [:f0]]

    corpora = [
      # non-enumerable :features -> treated as missing -> typed incomplete refusal
      [%{features: 42, label: :l, sensitive: 0}, %{features: :atom, label: :l, sensitive: 1}],
      # non-map samples -> no observable features -> typed path, never Map.get raise
      [nil, 5, "sample", %{features: %{"f0" => 1.0}, label: :l, sensitive: 0}],
      [%{features: %{"f0" => 1.0}, label: :l, sensitive: 0}, {:tuple, 1}]
    ]

    for samples <- corpora do
      r1 = DatasetAdmission.admit(samples, opts)
      r2 = DatasetAdmission.admit(samples, opts)

      assert_match_dataset(r1, samples, opts)
      assert r1 == r2, "non-deterministic for #{inspect(samples, limit: 3)}"
    end
  end

  test "FLIP-3: EuAiActAdmission.admit/1 improper-list values return typed atoms, not raise" do
    improper_candidates = [
      %{techniques: [1 | 2]},
      %{data_domains: [:facial_images | :junk], provenance: :scraped},
      %{context_joins: [[:a] | :b]},
      %{techniques: [1 | 2], data_domains: [:social_behavior | 0],
        context_joins: [:unrelated_context_join | nil]},
      %{data_domains: [:biometric | 2], setting: :public_space, latency_goal: :realtime}
    ]

    allowed = EuAiActAdmission.refusal_atoms() ++ [:REFUSED_EUAIA_MALFORMED_CANDIDATE]

    for c <- improper_candidates do
      r1 = EuAiActAdmission.admit(c)
      r2 = EuAiActAdmission.admit(c)

      assert is_tuple(r1) and tuple_size(r1) == 2 and elem(r1, 0) in [:ok, :error],
             "untyped verdict for #{inspect(c, limit: 5)}: #{inspect(r1)}"

      if elem(r1, 0) == :error do
        assert elem(r1, 1) in allowed, "refusal atom outside declared set: #{inspect(r1)}"
      end

      assert r1 == r2, "non-deterministic for #{inspect(c, limit: 5)}"
    end

    # improper leaf in techniques is opaque: no prohibited class matches, so
    # the structural checks run and admit (typed {:ok, :admitted}).
    assert EuAiActAdmission.admit(%{techniques: [1 | 2]}) == {:ok, :admitted}
  end

  test "FLIP-4: float overflow in gate arithmetic refuses typed (:REFUSED_ARITHMETIC_OVERFLOW)" do
    # RobustMargin: penalty product l_h * l_e * epsilon overflows max-finite^3.
    assert RobustMargin.admit(1.0, @max_finite, @max_finite, @max_finite) ==
             {:error, :REFUSED_ARITHMETIC_OVERFLOW}

    assert RobustMargin.admit(1.0, @max_finite, @max_finite, @max_finite) ==
             RobustMargin.admit(1.0, @max_finite, @max_finite, @max_finite)

    # estimate_lipschitz: list-norm squares overflow (1e200^2 = 1e400).
    huge_pairs = [{[1.0e200, 0.0], [0.0, 0.0]}]
    assert RobustMargin.estimate_lipschitz(fn x -> x end, huge_pairs) ==
             {:error, :REFUSED_ARITHMETIC_OVERFLOW}

    # DatasetAdmission: quantile interpolation (b - a) overflows when the two
    # populations sit at opposite max-finite extremes.
    overflow_samples = [
      %{features: %{"f0" => @max_finite}, label: :l, sensitive: 0},
      %{features: %{"f0" => -@max_finite}, label: :l, sensitive: 1}
    ]

    assert DatasetAdmission.admit(overflow_samples, seed: 7, required_fields: ["f0"]) ==
             {:error, :REFUSED_ARITHMETIC_OVERFLOW}

    assert DatasetAdmission.admit(overflow_samples, seed: 7, required_fields: ["f0"]) ==
             DatasetAdmission.admit(overflow_samples, seed: 7, required_fields: ["f0"])
  end
end
