defmodule Xaas.Trimtab.ReplayTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.{Receipt, Replay, Subject}

  test "same receipt replays deterministically" do
    {:ok, s} = Subject.new("repo", "sha")
    r = Receipt.seal(s, :provider, %{}, %{x: 1})
    assert Replay.verify(r, s, %{}, %{x: 1}) == :ok
    assert Replay.verify(r, s, %{}, %{x: 2}) == {:error, :output_drift}
    {:ok, other} = Subject.new("repo", "sha2")
    assert Replay.verify(r, other, %{}, %{x: 1}) == {:error, :subject_mismatch}
  end
end
