defmodule Xaas.Semantics.JcsDocTest do
  @moduledoc """
  Lane W851 — doctest harness for `Xaas.Semantics.Jcs.encode/1`.

  Runs the `iex>` examples in the `@doc` of `Xaas.Semantics.Jcs.encode/1`
  as real assertions: the expected canonical-JSON outputs were derived by
  actually running the function (not guessed), and this suite re-runs them
  on every test pass so the docs cannot drift from the encoder.
  """

  use ExUnit.Case, async: true

  doctest Xaas.Semantics.Jcs
end
