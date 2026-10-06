defmodule Xaas.Trimtab.ExperimentTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.Experiment

  test "experiment binds subject and epoch" do
    e = Experiment.new("digest", :control, :candidate)
    assert e.subject_digest == "digest"
    assert e.control == :control and e.candidate == :candidate
    assert e.metrics == %{}
    assert Experiment.record(e, :yield, 0.5).metrics == %{yield: 0.5}
  end
end
