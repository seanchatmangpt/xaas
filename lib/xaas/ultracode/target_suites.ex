defmodule Xaas.Ultracode.TargetSuites do
  @moduledoc """
  Operator-registered fabric verifier suites for non-APS targets, so
  `Lease.close/4` can judge work on those repos too. Declared here as code
  (compile-checked, admission-gated by `validate/1`); an environment opts in
  by setting `config :xaas, :ultracode_target_suites` to THIS MODULE (an atom
  value in dev.exs), which `Xaas.Ultracode.Verifier` merges into the registry
  at runtime. The corresponding clones are registered under
  `config :xaas, :ultracode_repos`.

  A suite for a target repo is the CHEAPEST SOUND CHECK that work on that repo
  compiles and its tests pass -- no receipts, no ticket semantics (those stay
  APS-specific in `priv/verifiers/aps_dod_court.py`). Exit semantics are the
  `Xaas.Ultracode.Verifier` ones: step exit 0 = pass, any other non-zero exit
  (outside `infra_exit_codes`) = fail (worker claimed alive, tree is broken),
  timeout = unverifiable.

  Environment law (copied from the `aps-dod` / `aps-canonical` pattern):

    * The verifier spawns children through `/usr/bin/env -i` with a throwaway
      `HOME`/`TMPDIR`, so NOTHING that depends on `$HOME` resolution is
      available. Toolchains are pinned with absolute paths: the Elixir suite
      points `PATH` at exact asdf install dirs (the repos carry no
      `.tool-versions`, so asdf shim global-version resolution would fail
      under a throwaway HOME anyway), and Hex is pinned via `MIX_ARCHIVES` in
      the operator-owned toolchain dir (same shape as the APS `PYTHONUSERBASE`
      pin). The Python suite pins the Homebrew interpreter first on `PATH` and
      points `PYTHONUSERBASE` at the real user site, exactly like aps-dod.
    * Hermetic: no network beyond dependency fetch (`mix deps.get` against the
      committed `mix.lock`); no writes outside the worktree except the
      per-run temp dir the verifier hands over (`{tmpdir}`, used as the pytest
      base temp) and the operator-owned `MIX_ARCHIVES`/user-site reads. Both
      targets' `.gitignore` covers `_build/`, `deps/`, `__pycache__/` and
      `.pytest_cache/`, so the verifier's after-the-run tree-clean check
      holds; pytest runs with `-p no:cacheprovider` regardless.
    * `PYTHONPATH=src` is RELATIVE on purpose: Python resolves it against the
      child's working directory, which the verifier sets to the epoch
      worktree -- so `import eds` resolves inside the tree under test, never
      in an installed copy (exactness of the evidence subject).

  Runtime admission stays NAME-ONLY (`Xaas.Ultracode.Validations.
  VerifierSuiteRegistered`); `validate/1` is the registration-time gate over
  the declarations themselves -- it refuses bad commands (empty/non-binary or
  placeholder-embedded argv elements) and bad timeouts (missing, non-integer,
  zero/negative, or above the 1h cap) so a typo cannot reach close time.
  """

  alias Xaas.Ultracode.Verifier

  @max_timeout_ms 3_600_000

  @doc "Suite declarations merged into the dev verifier registry by config/dev.exs."
  @spec devs() :: map()
  def devs do
    %{
      # ex_noun_verb_cli clone (~/xaas-worktrees/repos/nounverb): mix deps.get
      # against the committed mix.lock, strict compile, full mix test. Hex is
      # resolved from the pinned MIX_ARCHIVES so a throwaway HOME never
      # triggers the interactive `mix local.hex` prompt.
      "nounverb-dod" => %{
        env: %{
          "PATH" =>
            "/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:" <>
              "/Users/sac/.asdf/installs/erlang/28.3/bin:" <>
              "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
          "LANG" => "en_US.UTF-8",
          "MIX_ARCHIVES" => Path.expand("~/xaas-worktrees/toolchain/mix-archives")
        },
        max_output_bytes: 65_536,
        toolchain: [["mix", "--version"], ["git", "--version"]],
        steps: [
          %{id: "deps", timeout_ms: 180_000, argv: ["mix", "deps.get"]},
          %{id: "compile", timeout_ms: 300_000, argv: ["mix", "compile", "--warnings-as-errors"]},
          %{id: "test", timeout_ms: 300_000, argv: ["mix", "test"]}
        ]
      },
      # eds clone (~/xaas-worktrees/repos/eds): the full pytest suite against
      # the worktree's own src/ (relative PYTHONPATH), with the base temp
      # inside the verifier's per-run tmpdir so nothing is written outside
      # the worktree or shared between runs.
      "eds-dod" => %{
        env: %{
          "PATH" => "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
          "LANG" => "en_US.UTF-8",
          # jsonschema/pytest live in the user site; the verifier gives
          # children a throwaway HOME, so point Python at it explicitly
          # (same pin as aps-dod).
          "PYTHONUSERBASE" => Path.expand("~/Library/Python/3.14"),
          "PYTHONPATH" => "src"
        },
        max_output_bytes: 65_536,
        toolchain: [
          ["python3", "--version"],
          ["python3", "-m", "pytest", "--version"],
          ["git", "--version"]
        ],
        steps: [
          %{
            id: "test",
            timeout_ms: 300_000,
            argv: [
              "python3",
              "-m",
              "pytest",
              "tests",
              "--basetemp",
              "{tmpdir}",
              "-q",
              "-p",
              "no:cacheprovider"
            ]
          }
        ]
      }
    }
  end

  @doc """
  Registration-time admission gate for suite declarations. `:ok` when every
  suite is executable-shaped; `{:error, problems}` otherwise. This is a
  config gate, not a runtime change: `Verifier.run/2` still does name-only
  lookup and fails closed per step.
  """
  @spec validate(term()) :: :ok | {:error, [String.t()]}
  def validate(suites)

  def validate(suites) when is_map(suites) and suites != %{} do
    problems = Enum.flat_map(suites, fn {name, suite} -> suite_problems(name, suite) end)

    case problems do
      [] -> :ok
      problems -> {:error, Enum.reverse(problems)}
    end
  end

  def validate(_), do: {:error, ["suites must be a non-empty map"]}

  defp suite_problems(name, suite) do
    ctx = "suite #{inspect(name)}: "

    case suite do
      suite when is_map(suite) ->
        env_problems = env_problems(ctx, suite[:env])

        step_problems =
          case Map.get(suite, :steps) do
            steps when is_list(steps) and steps != [] ->
              Enum.flat_map(steps, &step_problems(ctx, &1))

            _ ->
              [ctx <> "steps must be a non-empty list"]
          end

        toolchain_problems = toolchain_problems(ctx, Map.get(suite, :toolchain, []))

        env_problems ++ step_problems ++ toolchain_problems

      _ ->
        [ctx <> "suite must be a map"]
    end
  end

  defp env_problems(_ctx, nil), do: []

  defp env_problems(_ctx, env) when is_map(env) do
    if Enum.all?(env, fn {k, v} -> is_binary(k) and is_binary(v) end) do
      []
    else
      ["suite env must map binary keys to binary values"]
    end
  end

  defp env_problems(ctx, _), do: [ctx <> "env must be a map"]

  defp toolchain_problems(_ctx, nil), do: []

  defp toolchain_problems(ctx, argvs) when is_list(argvs) do
    Enum.flat_map(argvs, fn argv ->
      case argv_problems("toolchain", argv) do
        [] -> []
        problems -> [ctx <> hd(problems)]
      end
    end)
  end

  defp toolchain_problems(ctx, _), do: [ctx <> "toolchain must be a list of argv lists"]

  defp step_problems(ctx, step) when is_map(step) do
    id_problem =
      case step[:id] do
        id when is_binary(id) and id != "" -> []
        id when is_atom(id) and not is_boolean(id) and not is_nil(id) -> []
        _ -> ["step needs a non-empty id"]
      end

    argv_problems =
      case Map.fetch(step, :argv) do
        {:ok, argv} -> argv_problems(Map.get(step, :id, "?"), argv)
        :error -> ["step #{inspect(Map.get(step, :id))}: argv is required"]
      end

    timeout_problem =
      case Map.fetch(step, :timeout_ms) do
        {:ok, ms} when is_integer(ms) and ms > 0 and ms <= @max_timeout_ms -> []
        {:ok, ms} -> ["step #{inspect(Map.get(step, :id))}: bad timeout_ms #{inspect(ms)}"]
        :error -> ["step #{inspect(Map.get(step, :id))}: timeout_ms is required"]
      end

    infra_problem =
      case Map.get(step, :infra_exit_codes) do
        nil ->
          []

        codes when is_list(codes) ->
          if Enum.all?(codes, &is_integer/1) do
            []
          else
            ["step #{inspect(Map.get(step, :id))}: infra_exit_codes must be integers"]
          end

        _ ->
          ["step #{inspect(Map.get(step, :id))}: infra_exit_codes must be integers"]
      end

    for problem <- id_problem ++ argv_problems ++ timeout_problem ++ infra_problem,
        do: ctx <> problem
  end

  defp step_problems(ctx, _), do: [ctx <> "step must be a map"]

  # An argv element is executable-shaped when it is a binary that is either a
  # whole `{placeholder}` (as Verifier.placeholders/0 defines them) or a
  # literal containing no placeholder at all -- exactly what
  # `Verifier.resolve_element/2` accepts, minus `priv:` existence which is
  # only resolvable against a compiled app.
  defp argv_problems(_label, argv) when is_list(argv) and argv != [] do
    placeholders = Verifier.placeholders()

    Enum.flat_map(argv, fn element ->
      cond do
        not is_binary(element) ->
          ["argv elements must be binaries"]

        element in placeholders ->
          []

        Enum.any?(placeholders, &String.contains?(element, &1)) ->
          ["embedded placeholder refused in #{inspect(element)}"]

        true ->
          []
      end
    end)
  end

  defp argv_problems(label, _), do: ["#{label}: argv must be a non-empty list of elements"]
end
