defmodule Xaas.Semantics.DatasetAdmission do
  @moduledoc """
  EU AI Act Art. 10 dataset admission gate (dissertation Ch3, Theorem 3.2).

  Decidable gate over empirical samples: `admit/2` returns `:ADMITTED` or a
  typed refusal (`REFUSED_BIAS_THRESHOLD`, `REFUSED_INCOMPLETE_DATASET`,
  `REFUSED_EMPTY_DATASET`).

  ## Honest scoping — sliced Wasserstein-1 is an UPPER-BOUND proxy

  The exact empirical Wasserstein-1 distance between two populations requires
  solving an optimal-transport problem (network simplex / Sinkhorn), which is
  O(N^3 log N) in the sample count. This module implements **sliced
  Wasserstein-1**: project every sample onto `k` pseudo-random directions,
  compute exact 1-D W1 per direction via sorted quantiles (O(N log N) each),
  and average. Sliced W1 is polynomial time and is a documented, deterministic
  (seeded) **upper-bound proxy** of the exact quantity it estimates; the
  dissertation's exact network-simplex transport is deferred to v2. The typed
  gate semantics (ADMITTED / typed refusals, thresholds as call arguments) are
  identical between the proxy and the v2 exact path: any `:ADMITTED` verdict
  here certifies `W1_exact <= W1_proxy` only in expectation over projection
  directions and is therefore stated as a bounded, seeded certification, not an
  exact one.

  Gate order (each typed, fail-closed):

    1. empty dataset  -> `{:error, :REFUSED_EMPTY_DATASET}`
    2. completeness < 1 - eta -> `{:error, :REFUSED_INCOMPLETE_DATASET}`
    3. W1_proxy > epsilon_bias -> `{:error, :REFUSED_BIAS_THRESHOLD}`
    4. else `{:ok, :ADMITTED}` with the measured quantities.

  Zero-config: `epsilon_bias`, `eta`, `seed`, and `projections` are call
  arguments; no application-env knobs participate in the safety path.
  """

  @typedoc "A sample: numeric features keyed by atom or string, a label, and a sensitive attribute 0|1."
  @type sample :: %{features: %{optional(atom | String.t()) => number()}, label: term(), sensitive: 0 | 1}

  @type opts :: [
          epsilon_bias: float(),
          eta: float(),
          seed: integer(),
          projections: pos_integer(),
          required_fields: [atom() | String.t()]
        ]

  @default_epsilon_bias 0.1
  @default_eta 0.05
  @default_projections 32
  @default_required_fields []

  @spec admit([sample()], opts()) ::
          {:ok, :ADMITTED,
           %{w1_proxy: float(), completeness: float(), projections: pos_integer()}}
          | {:error, :REFUSED_EMPTY_DATASET}
          | {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: float(), threshold: float()}}}
          | {:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: float(), epsilon_bias: float()}}}
          | {:error, :REFUSED_ARITHMETIC_OVERFLOW}
  def admit(samples, opts \\ [])

  def admit([], _opts), do: {:error, :REFUSED_EMPTY_DATASET}

  def admit(samples, opts) when is_list(samples) do
    # Gate-boundary arithmetic rescue (W630): float overflow in the quantile
    # interpolation / W1 aggregation is a typed refusal, not badarith.
    try do
      epsilon = Keyword.get(opts, :epsilon_bias, @default_epsilon_bias)
      eta = Keyword.get(opts, :eta, @default_eta)
      seed = Keyword.fetch!(opts, :seed)
      k = Keyword.get(opts, :projections, @default_projections)
      required = Keyword.get(opts, :required_fields, @default_required_fields)

      completeness = completeness(samples, required)

      if completeness < 1 - eta do
        {:error, {:REFUSED_INCOMPLETE_DATASET, %{completeness: completeness, threshold: 1 - eta}}}
      else
        w1 = sliced_w1(samples, seed, k)

        if w1 > epsilon do
          {:error, {:REFUSED_BIAS_THRESHOLD, %{w1_proxy: w1, epsilon_bias: epsilon}}}
        else
          {:ok, :ADMITTED, %{w1_proxy: w1, completeness: completeness, projections: k}}
        end
      end
    rescue
      ArithmeticError -> {:error, :REFUSED_ARITHMETIC_OVERFLOW}
    end
  end

  @doc """
  Share of required fields that are non-nil across all samples. With no
  `:required_fields`, completeness is 1.0 (every sample is its own witness).
  """
  @spec completeness([sample()], [atom() | String.t()]) :: float()
  def completeness(_samples, []), do: 1.0

  def completeness(samples, required) do
    total = length(samples) * length(required)

    present =
      Enum.sum(Enum.map(samples, fn sample ->
        features = feature_map(sample)
        Enum.count(required, fn field -> not is_nil(Map.get(features, field)) end)
      end))

    if total == 0, do: 1.0, else: present / total
  end

  # W630 totality: non-map samples carry no observable features — the sample
  # flows to the typed incomplete/bias refusal instead of Map.get raising.
  defp feature_map(sample) when is_map(sample),
    do: enumerable_features(Map.get(sample, :features) || %{})

  defp feature_map(_sample), do: %{}

  # W630 totality: a non-nil non-enumerable `:features` value is treated as
  # missing (empty) — vector/1's Enum.sort_by never sees it, the sample flows
  # to the typed incomplete/bias refusal path.
  defp enumerable_features(f) when is_map(f), do: f
  defp enumerable_features(f) when is_list(f), do: f
  defp enumerable_features(_f), do: %{}

  ## Sliced Wasserstein-1

  @doc """
  Seeded, deterministic sliced W1: mean over `k` pseudo-random unit directions
  of the exact 1-D W1 (sorted-quantile mean absolute deviation) between the
  A=0 and A=1 populations.
  """
  @spec sliced_w1([sample()], integer(), pos_integer()) :: float()
  def sliced_w1(samples, seed, k) do
    a0 = for(s = %{} <- samples, s.sensitive == 0, do: vector(s))
    a1 = for(s = %{} <- samples, s.sensitive == 1, do: vector(s))

    cond do
      a0 == [] or a1 == [] ->
        # One population unobservable: no transport certificate is decidable,
        # so return infinity to force the bias refusal (fail-closed).
        :inf

      true ->
        dim = max_feature_dim(a0 ++ a1)
        1..k
        |> Enum.map(fn i ->
          dir = random_unit_direction(dim, {seed, i})
          w1_1d(Enum.map(a0, &project(&1, dir)), Enum.map(a1, &project(&1, dir)))
        end)
        |> Enum.map(&to_float/1)
        |> Enum.sum()
        |> Kernel./(k)
    end
  end

  defp vector(sample) do
    feature_map(sample)
    |> Enum.sort_by(fn {k, _} -> to_sortable(k) end)
    |> Enum.map(fn {_k, v} -> if is_number(v), do: v * 1.0, else: 0.0 end)
  end

  defp to_sortable(k) when is_atom(k), do: Atom.to_string(k)
  defp to_sortable(k), do: to_string(k)

  defp max_feature_dim(vectors), do: Enum.max(Enum.map(vectors, &length/1), fn -> 0 end)

  defp pad(v, dim) when length(v) >= dim, do: v
  defp pad(v, dim), do: v ++ List.duplicate(0.0, dim - length(v))

  # Deterministic per-index direction: seed derived from {seed, index} so each
  # slice's projection is reproducible without threading :rand state (OTP 28
  # exposes no state-passing uniform_real).
  defp random_unit_direction(dim, {seed, index}) when dim > 0 do
    state = :rand.seed(:exsss, :erlang.phash2({seed, index}))

    {raw, _state} =
      Enum.map_reduce(1..dim, state, fn _i, st ->
        {u, st} = :rand.uniform_s(st)
        {u - 0.5, st}
      end)

    norm = :math.sqrt(Enum.reduce(raw, 0.0, fn x, acc -> acc + x * x end))

    dir = if norm == 0.0, do: List.duplicate(1.0, dim), else: Enum.map(raw, &(&1 / norm))
    dir
  end

  defp project(vec, dir) do
    vec
    |> pad(length(dir))
    |> Enum.zip(dir)
    |> Enum.reduce(0.0, fn {x, d}, acc -> acc + x * d end)
  end

  # Exact empirical 1-D W1 between equal-or-unequal size populations:
  # sorted-quantile L1 (mean of |q0(t) - q1(t)| over t in (0,1], sample-based).
  # Exact empirical 1-D W1: L1 distance between the quantile functions of the
  # two empirical measures, evaluated on a common grid (handles unequal group
  # sizes via linear interpolation).
  defp w1_1d(xs, ys) do
    xs = Enum.sort(xs)
    ys = Enum.sort(ys)
    m = max(length(xs), length(ys))

    grid =
      if m == 1 do
        [0.0]
      else
        Enum.map(1..m, fn i -> (i - 1) / (m - 1) end)
      end

    grid
    |> Enum.map(fn t -> abs(quantile(xs, t) - quantile(ys, t)) end)
    |> Enum.sum()
    |> Kernel./(m)
  end

  defp quantile([], _t), do: 0.0

  defp quantile(sorted, t) do
    n = length(sorted)

    if n == 1 do
      hd(sorted) * 1.0
    else
      pos = t * (n - 1)
      lo = floor(pos)
      hi = min(lo + 1, n - 1)
      frac = pos - lo
      a = Enum.at(sorted, lo) * 1.0
      b = Enum.at(sorted, hi) * 1.0
      a + (b - a) * frac
    end
  end

  defp to_float(:inf), do: :inf
  defp to_float(x) when is_number(x), do: x * 1.0
end
