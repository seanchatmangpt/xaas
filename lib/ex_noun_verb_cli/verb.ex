defmodule ExNounVerbCli.Verb do
  @moduledoc """
  A single noun/verb command binding: the noun+verb pair users type, the
  module/function pair that handles it, an `info` map describing its
  arguments, and a short doc string.

  `info` deliberately mirrors the *shape* of `Igniter.Mix.Task.Info`'s own
  fields (`schema`, `aliases`, `positional`, `required`) as plain data --
  this module has zero compile-time or runtime dependency on the `:igniter`
  library. That dependency is dev/test-only in this repo (used only to test
  the separate Igniter adapter), so the core library must not reference the
  real `Igniter.Mix.Task.Info` struct directly. `info` is just a plain map
  (or keyword list) with these keys:

    * `:schema` -- keyword list of `option_name: type` (e.g. `x: :integer`),
      the same shape `OptionParser.parse/2`'s `:strict`/`:switches` option
      expects.
    * `:aliases` -- keyword list of `alias: :option_name`.
    * `:positional` -- list of atoms naming positional arguments, in order.
    * `:required` -- list of atoms naming required option keys.

  Any of these keys may be omitted; `ExNounVerbCli.Dispatcher` treats a
  missing key as an empty list.
  """

  @enforce_keys [:noun, :verb, :module, :function]
  defstruct noun: nil,
            verb: nil,
            module: nil,
            function: nil,
            info: %{},
            doc: ""

  @type info :: %{
          optional(:schema) => keyword(),
          optional(:aliases) => keyword(),
          optional(:positional) => [atom()],
          optional(:required) => [atom()]
        }

  @type t :: %__MODULE__{
          noun: String.t(),
          verb: String.t(),
          module: module(),
          function: atom(),
          info: info(),
          doc: String.t()
        }

  @doc """
  Builds a new `Verb.t()`, validating that `:noun`, `:verb`, `:module`, and
  `:function` are all present and non-nil. Raises `ArgumentError` with a
  clear message naming the missing field(s) otherwise.

  ## Examples

      iex> ExNounVerbCli.Verb.new(noun: "calc", verb: "add", module: Calc, function: :add)
      %ExNounVerbCli.Verb{noun: "calc", verb: "add", module: Calc, function: :add, info: %{}, doc: ""}
  """
  @spec new(keyword() | map()) :: t()
  def new(fields) when is_list(fields) or is_map(fields) do
    fields = Map.new(fields)

    required = [:noun, :verb, :module, :function]

    missing =
      Enum.filter(required, fn key -> is_nil(Map.get(fields, key)) end)

    if missing != [] do
      raise ArgumentError,
            "ExNounVerbCli.Verb.new/1 is missing required field(s): #{inspect(missing)}"
    end

    struct!(__MODULE__, fields)
  end
end
