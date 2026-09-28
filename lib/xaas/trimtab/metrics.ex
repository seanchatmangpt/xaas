defmodule Xaas.Trimtab.Metrics do
  def summarize([]), do: %{count: 0, min: nil, max: nil, mean: nil, p50: nil}

  def summarize(xs) do
    s = Enum.sort(xs)
    n = length(s)

    %{
      count: n,
      min: hd(s),
      max: List.last(s),
      mean: Enum.sum(s) / n,
      p50: Enum.at(s, div(n - 1, 2))
    }
  end
end
