defmodule Xaas.ResearchRuntime.ClosureWaveTest do
  @moduledoc false
  def case(before_subject, after_subject) when before_subject == after_subject, do: {:ok, :exact_subject_preserved}
  def case(before_subject, after_subject), do: {:refused, :boundary_violation}
end
