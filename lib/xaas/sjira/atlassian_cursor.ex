defmodule Xaas.Sjira.AtlassianCursor do
  @moduledoc "Normalizes Jira offset and nextPageToken pagination."
  def initial(opts \\ []),
    do:
      (case Keyword.get(opts, :mode, :offset) do
         :offset -> %{mode: :offset, next: 0, exhausted: false, seen: 0}
         :token -> %{mode: :token, next: nil, exhausted: false, seen: 0}
       end)

  def params(%{mode: :offset, next: n}, limit), do: %{startAt: n || 0, maxResults: limit}
  def params(%{mode: :token, next: nil}, limit), do: %{maxResults: limit}
  def params(%{mode: :token, next: t}, limit), do: %{maxResults: limit, nextPageToken: t}
  def advance(%{exhausted: true}, _), do: {:error, :cursor_exhausted}

  def advance(%{mode: :offset} = s, p) do
    vals = p["issues"] || p["values"] || []
    start = p["startAt"] || s.next || 0
    maxr = p["maxResults"] || max(length(vals), 1)
    total = p["total"]
    next = start + length(vals)

    done =
      cond do
        is_integer(total) -> next >= total
        Map.has_key?(p, "isLast") -> p["isLast"] == true
        true -> length(vals) < maxr
      end

    {:ok,
     %{s | next: if(done, do: nil, else: next), exhausted: done, seen: s.seen + length(vals)},
     vals}
  end

  def advance(%{mode: :token} = s, p) do
    vals = p["issues"] || p["values"] || []
    token = p["nextPageToken"]
    done = p["isLast"] == true or is_nil(token)

    {:ok,
     %{s | next: if(done, do: nil, else: token), exhausted: done, seen: s.seen + length(vals)},
     vals}
  end
end
