defmodule ExNounVerbCli.ErrorTest do
  use ExUnit.Case, async: true

  alias ExNounVerbCli.Error

  test "new/3 builds a real struct with a default empty detail map" do
    error = Error.new(:unknown_verb, "no such verb")

    assert %Error{code: :unknown_verb, message: "no such verb", detail: %{}} = error
  end

  test "new/3 accepts an explicit detail map" do
    error = Error.new(:missing_required_option, "missing x", %{missing: [:x]})

    assert error.detail == %{missing: [:x]}
  end
end
