defmodule ExNounVerbCli.Registry.Generated do
  @moduledoc """
  v1-primary registry mechanism: `use ExNounVerbCli.Registry.Generated,
  verbs: [...]` turns the using module into a real, zero-boilerplate
  implementation of `ExNounVerbCli.Registry`.

  This is the shape a ggen template targets: it already knows every verb it
  emits at generation time, so it can emit one plain module listing them
  explicitly -- no runtime reflection needed for the generator path.

  Each entry in `:verbs` is anything `ExNounVerbCli.Verb.new/1` accepts
  (a keyword list or map with `:noun`, `:verb`, `:module`, `:function`, and
  optionally `:info`/`:doc`) -- validation happens once, at compile time,
  via `Verb.new/1`'s own `ArgumentError` on a missing required field.

  ## Example

      defmodule MyApp.Cli.Registry do
        use ExNounVerbCli.Registry.Generated,
          verbs: [
            [noun: "calc", verb: "add", module: MyApp.Calc, function: :add],
            [noun: "calc", verb: "multiply", module: MyApp.Calc, function: :multiply]
          ]
      end

      MyApp.Cli.Registry.list_verbs()
      #=> [%ExNounVerbCli.Verb{noun: "calc", verb: "add", ...}, ...]
  """

  alias ExNounVerbCli.Verb

  defmacro __using__(opts) do
    verbs = Keyword.get(opts, :verbs, [])

    quote bind_quoted: [verbs: verbs] do
      @behaviour ExNounVerbCli.Registry

      @__ex_noun_verb_cli_verbs__ Enum.map(verbs, &Verb.new/1)

      @impl ExNounVerbCli.Registry
      def list_verbs, do: @__ex_noun_verb_cli_verbs__
    end
  end
end
