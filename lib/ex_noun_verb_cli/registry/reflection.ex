defmodule ExNounVerbCli.Registry.Reflection do
  @moduledoc """
  v2 fallback registry: discovers verbs by scanning the BEAM modules of the
  running application for a real marker function, `__noun_verb_marker__/0`,
  rather than requiring an explicit generated list.

  This is a real, lower-priority convenience for hand-authored verb
  modules (per the design spec's non-goals: "Reflection-based registry as
  anything but an opt-in convenience"). A module opts in simply by
  exporting:

      def __noun_verb_marker__, do: [
        [noun: "calc", verb: "add", module: __MODULE__, function: :add]
      ]

  Each element returned by a marker function is anything
  `ExNounVerbCli.Verb.new/1` accepts.

  `list_verbs/0` walks `Application.get_application/1` for the calling
  module to find *its own* application (defaulting to `:ex_noun_verb_cli`
  when that lookup fails, e.g. when called from a script with no owning
  OTP application), then `:application.get_key/2` for that application's
  compiled `:modules` list, calling the marker function on every module
  that exports it and concatenating the results.
  """

  @behaviour ExNounVerbCli.Registry

  alias ExNounVerbCli.Verb

  @impl ExNounVerbCli.Registry
  def list_verbs do
    app = Application.get_application(__MODULE__) || :ex_noun_verb_cli

    modules =
      case :application.get_key(app, :modules) do
        {:ok, mods} -> mods
        _ -> []
      end

    modules
    |> Enum.filter(&exports_marker?/1)
    |> Enum.flat_map(fn mod ->
      mod.__noun_verb_marker__()
      |> List.wrap()
      |> Enum.map(&Verb.new/1)
    end)
  end

  defp exports_marker?(mod) do
    Code.ensure_loaded?(mod) and function_exported?(mod, :__noun_verb_marker__, 0)
  end
end
