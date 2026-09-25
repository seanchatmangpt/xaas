defmodule ExNounVerbCli.Error do
  @moduledoc """
  A plain, typed error struct used throughout `ex_noun_verb_cli` instead of
  raw strings or exceptions for expected failure paths (unknown verb,
  missing required option, a handler that raised).

    * `:code` -- an atom naming the error class (e.g. `:unknown_verb`,
      `:missing_required_option`, `:handler_raised`).
    * `:message` -- a human-readable description.
    * `:detail` -- a free-form map of extra context (defaults to `%{}`).
  """

  @enforce_keys [:code, :message]
  defstruct code: nil, message: "", detail: %{}

  @type t :: %__MODULE__{
          code: atom(),
          message: String.t(),
          detail: map()
        }

  @doc "Builds a new `Error.t()`."
  @spec new(atom(), String.t(), map()) :: t()
  def new(code, message, detail \\ %{}) when is_atom(code) and is_binary(message) do
    %__MODULE__{code: code, message: message, detail: detail}
  end
end
