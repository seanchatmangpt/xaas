defmodule Xaas.Chicago.Subject do
  @moduledoc """
  The exact Chicago demo subject literal.

  Every projection, case, piece of evidence and receipt in the Chicago surface
  binds to this single literal (`dcterms:identifier` of `chi:purchase-001` in
  `docs/sjira/v26.10.1/chicago.ttl`). Anything bound to a different string is
  stale by law and is refused rather than generalized.

  This is a semantic/demo entity. It is NOT evidence that a real financial
  transaction occurred, and carrying this literal never grants authority.
  """

  @literal "urn:chicago:agentic-payment:purchase-001"

  @spec literal :: String.t()
  def literal, do: @literal

  @spec matches?(term) :: boolean
  def matches?(value), do: is_binary(value) and value == @literal
end
