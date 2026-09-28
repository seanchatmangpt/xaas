defmodule Xaas.ResearchRuntime.IdentityWaveTest do
  use ExUnit.Case, async: true
  alias Xaas.ResearchRuntime.ExactSubject
  test "refuses missing identity and admits bounded value" do
    assert {:error, :missing_subject_sha} = ExactSubject.new([])
    assert {:ok, value} = ExactSubject.new(subject_sha: "exact")
    assert {:error, :refused} = ExactSubject.admit(value, fn _ -> false end)
    assert {:ok, admitted} = ExactSubject.admit(value, fn _ -> true end)
    assert admitted.status == :admitted
  end
end
