defmodule Xaas.Trimtab.ModelRoleTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.ModelRole

  test "role is contextual steering" do
    assert {:ok, role} = ModelRole.new("openai", "gpt")
    assert ModelRole.authority?(role) == false
    assert role.authority == :none
    assert ModelRole.new(1, "gpt") == {:error, :invalid_model}
  end
end
