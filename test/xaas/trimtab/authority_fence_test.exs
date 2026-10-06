defmodule Xaas.Trimtab.AuthorityFenceTest do
  use ExUnit.Case, async: true
  alias Xaas.Trimtab.AuthorityFence

  test "model output is never DO authority" do
    assert AuthorityFence.admit(:do) == {:error, :consequential_do_forbidden}
    assert AuthorityFence.admit(:observe) == {:ok, :observe}
    assert AuthorityFence.admit(:construct) == {:ok, :construct}
    assert AuthorityFence.admit(:recommend) == {:ok, :recommend}
    assert AuthorityFence.admit(:bogus) == {:error, :unknown_action}
  end
end
