import Config

# Default registry for the escript/Igniter adapters' `main/1`/`igniter/1`
# entry points -- points at the toy `calc` example CLI (Milestone 1 of the
# design spec) so `mix escript.build`/`mix ex_noun_verb_cli` work out of the
# box in this repo. A real consumer app would set its own registry module
# here instead.
config :ex_noun_verb_cli, registry: ExNounVerbCli.Examples.Calc.Registry
