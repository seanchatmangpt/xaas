defmodule ExNounVerbCli.Test.CalcFixture do
  @moduledoc """
  A real, simple handler module used as a fixture in `Dispatcher`,
  `Registry.Generated`, and `Registry.Reflection` tests -- not a mock, a
  genuine implementation with real (if trivial) behavior.
  """

  def add(x, y), do: x + y
  def multiply(x, y), do: x * y
  def boom, do: raise(RuntimeError, "handler exploded")
  def echo_profile(profile_id), do: profile_id

  # Real marker function for ExNounVerbCli.Registry.Reflection to discover.
  def __noun_verb_marker__ do
    [
      [
        noun: "calc",
        verb: "add",
        module: __MODULE__,
        function: :add,
        info: %{schema: [x: :integer, y: :integer], required: [:x, :y]}
      ]
    ]
  end
end

defmodule ExNounVerbCli.Test.CalcRegistry do
  @moduledoc """
  A real, hand-written `ExNounVerbCli.Registry` implementation used as a
  fixture across dispatcher tests.
  """

  use ExNounVerbCli.Registry.Generated,
    verbs: [
      [
        noun: "calc",
        verb: "add",
        module: ExNounVerbCli.Test.CalcFixture,
        function: :add,
        info: %{schema: [x: :integer, y: :integer], required: [:x, :y]}
      ],
      [
        noun: "calc",
        verb: "multiply",
        module: ExNounVerbCli.Test.CalcFixture,
        function: :multiply,
        info: %{schema: [x: :integer, y: :integer], required: [:x, :y]}
      ],
      [
        noun: "calc",
        verb: "boom",
        module: ExNounVerbCli.Test.CalcFixture,
        function: :boom
      ],
      [
        noun: "calc",
        verb: "echo-profile",
        module: ExNounVerbCli.Test.CalcFixture,
        function: :echo_profile,
        info: %{schema: [profile_id: :string], required: [:profile_id]}
      ]
    ]
end
