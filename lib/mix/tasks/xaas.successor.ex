defmodule Mix.Tasks.Xaas.Successor do
  @shortdoc "Successor intake (GC23-12): retired with compile_prose -- typed UNSUPPORTED(provider_capability)"

  @moduledoc """
  The GC23-12 successor intake runner (lane V23-H; PRD section 12, ARD
  sections 5.5, 9 and 24 M9; `Xaas.Sjira.Successor`).

      mix xaas.successor --dir DIR --ggen-igniter-dir GI [--out-dir OUT] [--check]
                         [--ggen-build-path PATH] [--verifier-suite NAME]
                         [--alias owner/repo=alias ...]

  RETIRED (v26.9.25 post-tag hardening, X1): ggen_igniter retired
  `mix semantic_jira.compile_prose` in dc2724263b7c955f23cd3e1a7407f3665e2a022e
  (prose is observation-only; a WorkOrder originates only from a pinned
  `origin_authority`). After the no-LLM guard the task now prints
  `UNSUPPORTED(provider_capability)` (reason `compile_prose_retired`, with the
  successor pointer, `Xaas.Sjira.Successor.successor/0`) and exits `69`; it
  runs no graph-side process and writes nothing. The historical contract:

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

  The no-LLM guard runs first and fails closed (`SemanticDrive.no_llm_guard/1`
  over `priv/no_llm/policy.json`): a provider-claimed variable or a provider
  executable on PATH is `REFUSED(llm_credential_present)`, any other variable
  the policy does not admit `REFUSED(unadmitted_environment)` (broken term
  `mu_on_O`).

  ## Exit codes

  Historical (before the retirement): `0` the intake ran (last stdout line:
  the JSON summary), `75` the graph side had no usable build. Now: `2`
  invalid invocation, `3` a
  typed refusal (last stdout line: `{"standing": "REFUSED(...)", ...}`),
  `69` `UNSUPPORTED(provider_capability)`: the retired prose -> WorkOrder
  edge (last stdout line: the typed JSON with the successor pointer).
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
  @spec run([String.t()]) :: no_return()
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

  @spec intake(keyword(), map()) :: no_return()
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
      {:unsupported, typed} -> emit(69, typed)
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

  # Every outcome of the retired intake is non-zero (2, 3 or 69): emit always
  # exits.
  @spec emit(pos_integer(), map()) :: no_return()
  defp emit(code, document) do
    Mix.shell().info(Jason.encode!(document))
    exit({:shutdown, code})
  end
end
