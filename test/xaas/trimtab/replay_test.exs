defmodule XaaS.Trimtab.ReplayTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.{Receipt,Replay}
  test "same receipt replays deterministically" do
    r=Receipt.new("s","p","o")
    assert Replay.key(r) == Replay.key(r)
  end
end
