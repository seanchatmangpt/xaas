defmodule XaaS.Trimtab.SubjectTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.Subject
  test "identity is exact and deterministic" do
    a=Subject.new("repo","abc123")
    b=Subject.new("repo","abc123")
    assert a == b
    refute a == Subject.new("repo","def456")
  end
end
