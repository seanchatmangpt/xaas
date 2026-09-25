defmodule ExNounVerbCli.Registry do
  @moduledoc """
  Behaviour for anything that can produce the list of `ExNounVerbCli.Verb.t()`
  a CLI understands. `ExNounVerbCli.Dispatcher.dispatch/2` looks up the
  noun/verb it was given against `list_verbs/0`'s result.

  Two real implementations ship with this library:

    * `ExNounVerbCli.Registry.Generated` -- v1-primary: a `use` macro that
      lets a ggen-emitted (or hand-written) module declare its verbs
      explicitly and satisfy this behaviour with no extra boilerplate.
    * `ExNounVerbCli.Registry.Reflection` -- v2 fallback: scans the current
      application's compiled modules at runtime for a real marker function.

  A consumer may also hand-write its own module implementing this behaviour
  directly -- that is a real, first-class option, not just an internal
  detail of the two implementations above.
  """

  alias ExNounVerbCli.Verb

  @callback list_verbs() :: [Verb.t()]
end
