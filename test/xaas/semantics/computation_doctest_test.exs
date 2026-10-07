defmodule Xaas.Semantics.ComputationDoctestTest do
  @moduledoc """
  Doctest harness for the hash functions flagged by W832
  (docs/sjira/v26.10.6/plans/w832-doctest-verify.md, lines 66/91/186/289).
  """

  use ExUnit.Case, async: true

  doctest Xaas.Semantics.ComputationArtifact
  doctest Xaas.Semantics.ComputationHash
  doctest Xaas.Semantics.ComputationClaim
  doctest Xaas.Semantics.PlanningAdvice
end
