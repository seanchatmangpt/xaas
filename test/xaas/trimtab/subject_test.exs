defmodule Xaas.Trimtab.SubjectTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.Subject

  test "identity is exact and deterministic" do
    {:ok, a} = Subject.new("repo", "abc123")
    {:ok, b} = Subject.new("repo", "abc123")
    assert Subject.same?(a, b)
    refute Subject.same?(a, elem(Subject.new("repo", "def456"), 1))
  end

  test "invalid subject is refused" do
    assert Subject.new("", "abc123") == {:error, :invalid_subject}
  end
end
