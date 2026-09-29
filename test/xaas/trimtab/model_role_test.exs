defmodule XaaS.Trimtab.ModelRoleTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.ModelRole
  test "role is contextual steering" do
    assert ModelRole.authority() == :none
  end
end
