defmodule Xaas.Trimtab.FalsifierTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.{Evidence, Falsifier, Subject}

  test "subject drift falsifies admission" do
    {:ok, s} = Subject.new("repo", "sha-a")

    ev = Evidence.new(s, :admitted, :drifted, fn w -> w == :drifted end)
    assert Falsifier.evaluate(ev) == :falsified
    assert Falsifier.evaluate(Evidence.new(s, :admitted, :ok, fn w -> w == :drifted end)) == :not_falsified
    assert Falsifier.evaluate(Evidence.new(s, :admitted, :ok)) == :not_falsified
  end
end
