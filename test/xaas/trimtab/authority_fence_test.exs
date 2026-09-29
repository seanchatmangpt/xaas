defmodule XaaS.Trimtab.AuthorityFenceTest do
  use ExUnit.Case, async: true
  alias XaaS.Trimtab.AuthorityFence
  test "model output is never DO authority" do
    assert {:refused, :model_has_no_do_authority} = AuthorityFence.admit(:model, :do)
  end
end
