defmodule Mix.Tasks.Xaas.Sjira.Yield do
  @shortdoc "Mine per-(class, repo, stage) yields + machinery hop share from an OCEL log"

  @moduledoc """
  Prints the `Xaas.Sjira.Yield` mining of an OCEL 2.0 JSON log as one JSON
  document on stdout (work order XAAS-26922-21, compositions C02 + C10).

  Usage:

      mix xaas.sjira.yield OCEL.json [--classes order-classes.json]
                                     [--orders orders.json [--repo KEY]]
                                     [--stage Construct] [--role build]

  `--classes` keys outcome events linked to a classified work order by order
  class (else by agent role). `--orders` adds `"ranking"`: the orders as SA2A
  candidates, `historical_yield` from the mined log, ordered by the allocator's
  salience. Starts no application: a pure fold over the files named. Runs in
  the :test env by default (`preferred_envs` in mix.exs) so it reuses the build
  `mix test` produced and stdout carries only the JSON document.
  Exit 0 on output; a missing or malformed file raises (non-zero).
  """

  use Mix.Task

  alias Xaas.Sjira.Yield

  @switches [classes: :string, orders: :string, repo: :string, stage: :string, role: :string]

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: @switches)

    ocel =
      case {rest, invalid} do
        {[path], []} ->
          path

        _ ->
          Mix.raise(
            "usage: mix xaas.sjira.yield OCEL.json [--classes F] [--orders F [--repo K]] [--stage S] [--role R]"
          )
      end

    classes = if opts[:classes], do: Yield.load_classes!(opts[:classes]), else: %{}
    mined = Yield.mine_file!(ocel, classes: classes, classes_source: opts[:classes])

    out =
      case opts[:orders] do
        nil ->
          mined

        orders_path ->
          orders = Yield.orders_from_file!(orders_path, repo: opts[:repo])
          cand_opts = [classes: classes] ++ Keyword.take(opts, [:stage, :role])
          Map.put(mined, "ranking", mined |> Yield.candidates(orders, cand_opts) |> Yield.rank())
      end

    IO.puts(Jason.encode!(out, pretty: true))
  end
end
