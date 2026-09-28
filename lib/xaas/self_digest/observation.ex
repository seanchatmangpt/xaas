defmodule Xaas.SelfDigest.Observation do
  @enforce_keys [:subject, :kind, :payload]
  defstruct [:subject, :kind, :payload, :provenance]
  def new(subject, kind, payload, provenance \\ %{}) when is_binary(subject) and is_atom(kind),
    do: %__MODULE__{subject: subject, kind: kind, payload: payload, provenance: provenance}
  def exact_subject?(%__MODULE__{subject: subject}, expected), do: subject == expected
end
