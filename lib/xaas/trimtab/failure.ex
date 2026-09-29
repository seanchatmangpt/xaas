defmodule Xaas.Trimtab.Failure do
  @classes [:transient, :rate_limited, :auth, :refused, :invalid, :crash]
  @enforce_keys [:provider_id, :class, :reason]
  defstruct [:provider_id, :class, :reason]
  def new(p, c, r) when c in @classes, do: {:ok, %__MODULE__{provider_id: p, class: c, reason: r}}
  def new(_, _, _), do: {:error, :invalid_failure_class}
  def retryable?(f), do: f.class in [:transient, :rate_limited, :crash]
end
