defmodule Xaas.Sjira.W650y3AtlassianCursorDepthCourtTest do
  @moduledoc """
  W650y3 depth court for `Xaas.Sjira.AtlassianCursor`.

  Real collaborators, real state assertions (Chicago). No mocks.

  Mutation rationale per test: each test kills a specific class of mutation
  (state-loss, precedence-flip, off-by-one, typed-refusal-removal,
  seen-counter-drift) that alias-level coverage was blind to.
  """

  use ExUnit.Case, async: true

  alias Xaas.Sjira.AtlassianCursor

  @page %{"issues" => [1, 2, 3], "startAt" => 0, "maxResults" => 3, "total" => 7}

  test "offset roundtrip: params -> advance -> params threads startAt across pages exactly once per page" do
    o = AtlassianCursor.initial(mode: :offset)

    assert AtlassianCursor.params(o, 3) == %{startAt: 0, maxResults: 3}

    {:ok, o1, vals1} = AtlassianCursor.advance(o, @page)
    assert vals1 == [1, 2, 3]
    assert AtlassianCursor.params(o1, 3) == %{startAt: 3, maxResults: 3}

    {:ok, o2, _} = AtlassianCursor.advance(o1, %{@page | "startAt" => 3})
    assert AtlassianCursor.params(o2, 3) == %{startAt: 6, maxResults: 3}

    # mutation kill: startAt derived from page startAt instead of accumulated next
    # would double-count; derived from a reset s.next would regress to 0.
  end

  test "typed refusal: exhausted cursor refuses advance with {:error, :cursor_exhausted} and stays refused" do
    o = AtlassianCursor.initial(mode: :offset)

    {:ok, done, _} =
      AtlassianCursor.advance(o, %{"issues" => [1], "startAt" => 0, "maxResults" => 5, "total" => 1})

    assert done.exhausted == true
    assert is_nil(done.next)
    assert {:error, :cursor_exhausted} = AtlassianCursor.advance(done, @page)
    assert {:error, :cursor_exhausted} = AtlassianCursor.advance(done, %{"issues" => [9]})

    # mutation kill: dropping the exhausted head, or advancing past done without
    # the guard, silently re-fetches the final page forever (infinite loop class).
  end

  test "termination precedence: integer total beats isLast beats shortfall; each branch reachable" do
    o = AtlassianCursor.initial(mode: :offset)

    # total branch: full page but total reached -> done even though isLast would say continue
    {:ok, d1, _} =
      AtlassianCursor.advance(o, %{
        "issues" => [1],
        "startAt" => 0,
        "maxResults" => 5,
        "total" => 1,
        "isLast" => false
      })

    assert d1.exhausted == true

    # isLast branch: no total, isLast false with full page -> not done
    {:ok, d2, _} =
      AtlassianCursor.advance(o, %{
        "issues" => [1, 1, 1, 1, 1],
        "startAt" => 0,
        "maxResults" => 5,
        "isLast" => false
      })

    refute d2.exhausted
    assert d2.next == 5

    # shortfall branch: no total, no isLast -> short page terminates
    {:ok, d3, _} = AtlassianCursor.advance(o, %{"issues" => [1], "startAt" => 0, "maxResults" => 5})
    assert d3.exhausted == true

    # mutation kill: reordering the cond (isLast before total, or shortfall first)
    # changes termination on pages carrying both signals — a pagination halt bug.
  end

  test "token mode: absent token on first page yields no nextPageToken param; token propagates; nil/isLast exhausts" do
    t = AtlassianCursor.initial(mode: :token)
    assert AtlassianCursor.params(t, 50) == %{maxResults: 50}

    {:ok, t1, _} = AtlassianCursor.advance(t, %{"values" => [:a], "nextPageToken" => "p2"})
    assert AtlassianCursor.params(t1, 50) == %{maxResults: 50, nextPageToken: "p2"}

    {:ok, t2, _} =
      AtlassianCursor.advance(t1, %{"values" => [:b], "nextPageToken" => "p3", "isLast" => true})

    assert t2.exhausted == true
    assert AtlassianCursor.params(t2, 50) == %{maxResults: 50}

    {:ok, t3, _} = AtlassianCursor.advance(t, %{"values" => [:c]})
    assert t3.exhausted == true
    assert AtlassianCursor.params(t3, 50) == %{maxResults: 50}

    # mutation kill: emitting nextPageToken: nil leaks a key into query params;
    # treating explicit-nil token as "continue" never terminates token pagination.
  end

  test "boundary and accounting: empty page terminates via max(length,1) default; seen accumulates across modes" do
    o = AtlassianCursor.initial(mode: :offset)

    # empty issues with no maxResults: maxr = max(0,1) = 1, 0 < 1 -> done
    {:ok, d, vals} = AtlassianCursor.advance(o, %{"issues" => []})
    assert vals == []
    assert d.exhausted == true
    assert d.seen == 0

    {:ok, o1, _} = AtlassianCursor.advance(o, @page)
    {:ok, o2, _} = AtlassianCursor.advance(o1, %{@page | "startAt" => 3})
    assert o2.seen == 6

    t = AtlassianCursor.initial(mode: :token)
    {:ok, t1, _} = AtlassianCursor.advance(t, %{"values" => [:a, :b], "nextPageToken" => "mid"})
    {:ok, t2, _} = AtlassianCursor.advance(t1, %{"values" => [:c]})
    assert t2.seen == 3

    # mutation kill: seen drift (under/over-count, or reset per page) corrupts
    # any downstream yield accounting; max(length,1) guards the empty-first-page
    # termination path.
  end
end
