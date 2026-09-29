defmodule XaaS.Trimtab.ExperimentTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.Experiment
  test "experiment binds subject and epoch" do
    e=Experiment.new("s",7)
    assert e.subject=="s" and e.epoch==7
  end
end
