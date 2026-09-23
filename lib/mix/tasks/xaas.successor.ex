defmodule Mix.Tasks.Xaas.Successor do
  @shortdoc "Successor intake: compiled successor orders -> frontier -> descriptor -> Route.resolve (GC23-12)"

  @moduledoc """
  The GC23-12 successor intake runner (lane V23-H; PRD section 12, ARD
  sections 5.5, 9 and 24 M9; `Xaas.Sjira.Successor`).

      mix xaas.successor --dir DIR --ggen-igniter-dir GI [--out-dir OUT] [--check]
                         [--ggen-build-path PATH] [--verifier-suite NAME]
                         [--alias owner/repo=alias ...]

  `DIR` holds the successor goal graph (`goal.ttl`) and the first-mile
  compiler's output (`compiled/orders.ttl`). The intake projects the compiled
  orders into the work graph, runs `mix semantic_jira.frontier` and
  `mix semantic_jira.descriptor --provider recipe` in the ggen_igniter
  checkout `GI`, and resolves the first eligible order's capability with
  `Xaas.Sa2a.Route.resolve/1`; an unregistered capability is a typed
  `UNSUPPORTED(provider_capability)` successor item, not an error. It writes
  `work.json`, `frontier.json`, `descriptor.json` and `resolution.json` to
  `OUT` (default `DIR/intake`). `--check` recomputes into a private
  directory and compares byte for byte with `OUT` instead of writing.

  The no-LLM guard runs first: a model credential variable or a
  `claude`/`zcode` executable on PATH is `REFUSED(llm_credential_present)`
  (broken term `mu_on_O`).

  ## Exit codes

  `0` the intake ran (last stdout line: the JSON summary; its `standing` is
  the first eligible order's item standing), `2` invalid invocation, `3` a
  typed refusal (last stdout line: `{"standing": "REFUSED(...)", ...}`),
  `75` the graph side has no usable build (`BUILD_BROKEN`; a court reads it
  as UNKNOWN).
  """

  use Mix.Task

  alias Xaas.Sjira.Successor

  @requirements ["app.config"]

  @switches [
    dir: :string,
    ggen_igniter_dir: :string,
    out_dir: :string,
    ggen_build_path: :string,
    verifier_suite: :string,
    alias: :keep,
    check: :boolean
  ]

  @impl Mix.Task
  def run(args) do
    {opts, rest, invalid} = OptionParser.parse(args, strict: @switches)

    cond do
      invalid != [] or rest != [] ->
        emit(2, %{
          "standing" => "REFUSED(usage)",
          "reason" => "usage",
          "detail" => inspect(invalid ++ rest)
        })

      is_nil(opts[:dir]) or is_nil(opts[:ggen_igniter_dir]) ->
        emit(2, %{
          "standing" => "REFUSED(usage)",
          "reason" => "usage",
          "detail" => "--dir and --ggen-igniter-dir are required"
        })

      true ->
        case aliases(Keyword.get_values(opts, :alias)) do
          {:ok, aliases} ->
            intake(opts, aliases)

          {:error, bad} ->
            emit(2, %{
              "standing" => "REFUSED(usage)",
              "reason" => "usage",
              "detail" => "bad --alias #{bad}"
            })
        end
    end
  end

  defp intake(opts, aliases) do
    intake_opts =
      [
        dir: opts[:dir],
        ggen_igniter_dir: opts[:ggen_igniter_dir],
        out_dir: opts[:out_dir],
        ggen_build_path: opts[:ggen_build_path],
        verifier_suite: opts[:verifier_suite],
        aliases: aliases
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    result =
      if opts[:check], do: Successor.check(intake_opts), else: Successor.intake(intake_opts)

    case result do
      {:ok, summary} -> emit(0, summary)
      {:refused, %{"standing" => "BUILD_BROKEN"} = typed} -> emit(75, typed)
      {:refused, typed} -> emit(3, typed)
    end
  end

  defp aliases(values) do
    Enum.reduce_while(values, {:ok, %{}}, fn value, {:ok, acc} ->
      case String.split(value, "=", parts: 2) do
        [repo, name] when repo != "" and name != "" -> {:cont, {:ok, Map.put(acc, repo, name)}}
        _ -> {:halt, {:error, value}}
      end
    end)
  end

  defp emit(code, document) do
    Mix.shell().info(Jason.encode!(document))
    if code != 0, do: exit({:shutdown, code})
  end
end
