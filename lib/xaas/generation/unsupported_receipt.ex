defmodule Xaas.Generation.UnsupportedReceipt do
  @moduledoc """
  Generator-unsupported receipt — the required component a caller emits
  when it hits a real generator capability gap instead of quietly
  patching around it by hand. Per the ticket's last falsifier, a
  capability gap "worked around with a handwritten patch instead of
  producing a generator-unsupported receipt" is a violation — this
  struct is the typed alternative to that silent workaround.

  Real, no mocking: this is a plain struct with a real, current
  `DateTime`. It does not itself decide when it's needed — every caller
  in this slice (`Xaas.Generation.RegenerationVerifier`,
  `Xaas.Generation.DependencyGraph`, `Xaas.Generation.Manifest`) that
  documents a bounded UNSUPPORTED scope in its own moduledoc is the thing
  that should build one of these when it actually hits that boundary.
  """

  @enforce_keys [:generator_id, :reason, :detail, :occurred_at]
  defstruct [:generator_id, :reason, :detail, :occurred_at]

  @type t :: %__MODULE__{
          generator_id: String.t(),
          reason: atom(),
          detail: String.t(),
          occurred_at: DateTime.t()
        }

  @spec build(String.t(), atom(), String.t()) :: t()
  def build(generator_id, reason, detail) when is_binary(generator_id) and is_atom(reason) do
    %__MODULE__{
      generator_id: generator_id,
      reason: reason,
      detail: detail,
      occurred_at: DateTime.utc_now()
    }
  end
end
