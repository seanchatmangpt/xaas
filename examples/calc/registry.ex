defmodule ExNounVerbCli.Examples.Calc.Registry do
  @moduledoc """
  The `ExNounVerbCli.Registry` implementation for the toy `calc` example
  CLI: registers noun `"calc"`, verbs `"add"`/`"multiply"`, both backed by
  `ExNounVerbCli.Examples.Calc`. Built via `ExNounVerbCli.Registry.Generated`
  -- the same v1-primary, ggen-template-shaped mechanism a real generated
  registry would use, proving that mechanism end-to-end for this
  proof-of-concept rather than hand-rolling a one-off `Registry`
  implementation just for the example.
  """

  use ExNounVerbCli.Registry.Generated,
    verbs: [
      [
        noun: "calc",
        verb: "add",
        module: ExNounVerbCli.Examples.Calc,
        function: :add,
        info: %{schema: [x: :integer, y: :integer], required: [:x, :y]},
        doc: "Adds --x and --y."
      ],
      [
        noun: "calc",
        verb: "multiply",
        module: ExNounVerbCli.Examples.Calc,
        function: :multiply,
        info: %{schema: [x: :integer, y: :integer], required: [:x, :y]},
        doc: "Multiplies --x and --y."
      ]
    ]
end
