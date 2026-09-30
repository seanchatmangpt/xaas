defmodule XaaS.Trimtab.FalsifierTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.Falsifier

  test "subject drift falsifies admission" do
    assert Falsifier.check(%{subject: "a"}, %{subject: "b"}) == {:falsified, :subject_drift}
  end
end
