defmodule Xaas.Sjira.W984dp3AtlassianCursorCourtTest do
  @moduledoc """
  W984dp3 depth court for `Xaas.Sjira.AtlassianCursor`.

  Lane W984dp3. Complements (does not duplicate) the alias-level coverage in
  atlassian_test.exs lines 69-95 and W984di's delivery_batch_depth_court_test.exs.

  Mutation rationale per test — each asserts a real invariant such that a mutant
  of the module (flipped termination predicate, dropped accumulation, removed
  refusal clause) fails the suite.
  """

  use ExUnit.Case, async: true

  alias Xaas.Sjira.AtlassianCursor

  test "exhausted cursor refuses further advance with typed error (clause 1 of advance/2)" do
    # Mutation rationale: deleting the `advance(%{exhausted: true}, _)` clause or
    # changing :cursor_exhausted to any other atom fails this assertion.
    o = AtlassianCursor.initial(mode: :offset)

    {:ok, o, _} =
      AtlassianCursor.advance(o, %{"issues" => [1], "startAt" => 0, "maxResults" => 5, "total" => 1})

    assert o.exhausted
    assert {:error, :cursor_exhausted} = AtlassianCursor.advance(o, %{"issues" => [2]})
  end

  test "offset termination precedence: total wins over isLast and short-page heuristic" do
    # The cond in advance/2 is ordered total -> isLast -> short-page. A mutant
    # reordering branches or dropping the is_integer(total) guard changes
    # exhaustion here: total=2 but page is not short (len == maxResults) and
    # isLast absent — only the total branch can end the stream.
    o = AtlassianCursor.initial(mode: :offset)

    assert {:ok, o, [:a, :b]} =
             AtlassianCursor.advance(o, %{
               "issues" => [:a, :b],
               "startAt" => 0,
               "maxResults" => 2,
               "total" => 2
             })

    assert o.exhausted
    assert is_nil(o.next)

    # And conversely: total larger than consumed keeps the cursor alive even
    # when isLast=true is present (total must win, isLast must lose).
    o2 = AtlassianCursor.initial(mode: :offset)

    assert {:ok, o2, _} =
             AtlassianCursor.advance(o2, %{
               "issues" => [:a],
               "startAt" => 0,
               "maxResults" => 5,
               "total" => 3,
               "isLast" => true
             })

    refute o2.exhausted
    assert o2.next == 1
  end

  test "short-page fallback terminates when neither total nor isLast present" do
    # Mutation rationale: the fallback branch `length(vals) < maxr` is only
    # reachable when total is absent and isLast is absent. Deleting it makes a
    # short final page look non-exhausted and the cursor never terminates.
    o = AtlassianCursor.initial(mode: :offset)

    assert {:ok, o, [1]} =
             AtlassianCursor.advance(o, %{"issues" => [1], "startAt" => 0, "maxResults" => 10})

    assert o.exhausted
  end

  test "seen accumulates across advances and params/2 roundtrips cursor state" do
    # Mutation rationale: dropping `s.seen + length(vals)` or the
    # if(done, do: nil, else: next) nil-out breaks both halves of this assertion.
    o = AtlassianCursor.initial(mode: :offset)

    {:ok, o, _} =
      AtlassianCursor.advance(o, %{"issues" => [1, 2], "startAt" => 0, "maxResults" => 2, "total" => 5})

    {:ok, o, _} =
      AtlassianCursor.advance(o, %{"issues" => [3], "startAt" => 2, "maxResults" => 2, "total" => 5})

    assert o.seen == 3

    # Cursor state must project into the next request's query params (roundtrip):
    # offset mode -> startAt = accumulated next offset.
    assert AtlassianCursor.params(o, 25) == %{startAt: 3, maxResults: 25}
  end

  test "token mode: initial params omit nextPageToken, present token roundtrips, absent token exhausts" do
    # Mutation rationale: swapping the next: nil vs next: t clauses of params/2
    # (or making initial(mode: :token) emit a token) fails all three assertions.
    t = AtlassianCursor.initial(mode: :token)
    assert AtlassianCursor.params(t, 50) == %{maxResults: 50}

    {:ok, t, _} = AtlassianCursor.advance(t, %{"values" => [:a], "nextPageToken" => "p2"})
    assert AtlassianCursor.params(t, 50) == %{maxResults: 50, nextPageToken: "p2"}

    # A page with no nextPageToken is terminal: nil token => done => exhausted,
    # and a subsequent advance refuses rather than looping forever.
    {:ok, t2, _} = AtlassianCursor.advance(t, %{"values" => [:b]})
    assert t2.exhausted
    assert {:error, :cursor_exhausted} = AtlassianCursor.advance(t2, %{"values" => [:c]})
  end
end
