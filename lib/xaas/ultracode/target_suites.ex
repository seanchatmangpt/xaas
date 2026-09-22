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
  zero/negative, or above the 1h cap) so a typo cannot reach close time. It
  also gates the court-receipt declarations: a step's `receipt` must be a
  boolean, its `receipt_argv` a well-formed argv list, and the suite's
  `result_format` one of `Xaas.Ultracode.CourtReceipt.result_formats/0`.
  """

  alias Xaas.Ultracode.{CourtReceipt, Verifier}

  @max_timeout_ms 3_600_000

  @doc "Suite declarations merged into the dev verifier registry by config/dev.exs."
  @spec devs() :: map()
  def devs do
    # Shared env for the uv (Python) targets. Two pins, both observed
    # necessary 2026-09-21:
    #   * UV_CACHE_DIR at the operator-owned toolchain dir -- the verifier
    #     gives children a throwaway HOME, so an unpinned uv cache would be
    #     cold (and re-downloaded) on every close.
    #   * UV_PYTHON at an absolute PATH-reachable interpreter -- the
    #     infinite-agentic-cli clone's .venv was bound to a uv-MANAGED
    #     CPython under ~/.local/share/uv, which does not exist under the
    #     throwaway HOME; `uv run` then silently fell back to a non-venv
    #     pytest and the project import failed at collection (observed:
    #     ModuleNotFoundError: infinite_agentic_cli). Pinning the interpreter
    #     keeps every venv on a python that exists inside the child env.
    uv_env = %{
      "PATH" => "/Users/sac/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      "LANG" => "en_US.UTF-8",
      "UV_CACHE_DIR" => Path.expand("~/xaas/worktrees/toolchain/uv-cache"),
      "UV_PYTHON" => "/opt/homebrew/bin/python3.13"
    }

    # Shared env for the Elixir (mix) targets, same pin shape as
    # nounverb-dod below: absolute asdf install dirs (throwaway HOME defeats
    # asdf shim resolution) + the operator-owned MIX_ARCHIVES so hex never
    # prompts.
    xaas_env = %{
      "PATH" =>
        "/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:" <>
          "/Users/sac/.asdf/installs/erlang/28.3/bin:" <>
          "/Users/sac/.cargo/bin:" <>
          "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      "LANG" => "en_US.UTF-8",
      "MIX_ARCHIVES" => Path.expand("~/xaas/worktrees/toolchain/mix-archives"),
      # Mix finds rebar3 ONLY via this env var (or ~/.mix, which a throwaway
      # HOME erases): the Erlang dep :idna needs it. Observed 2026-09-21:
      # "Could not find rebar3" without the pin even though rebar3 is on PATH.
      "MIX_REBAR3" => "/opt/homebrew/bin/rebar3",
      # Rustler NIF build (the :ggen_igniter dependency) needs the rust
      # toolchain AND the real rustup home under a throwaway HOME.
      "RUSTUP_HOME" => "/Users/sac/.rustup",
      "CARGO_HOME" => "/Users/sac/.cargo",
      # The xaas test database is xaas_test#{MIX_TEST_PARTITION}
      # (config/test.exs); the partition keeps the clone's Chicago sandbox
      # OFF the main checkout's xaas_test so a campaign close and a local
      # `mix test` never share one mutable database.
      "MIX_TEST_PARTITION" => "_ultracode"
    }

    # ------------------------------------------------------------------
    # Overnight-run targets (2026-09-21): the durable registry file
    # ~/xaas/worktrees/ultracode-repos.json names SIX targets. Three of
    # them are registered here -- each target names a `-dod` suite (the
    # per-item close judge) AND a `-canonical` suite (the per-repo
    # integration-head judge that Autonomic resolves from the registry
    # entry) -- the same judge at both heads, the nounverb/eds pattern.
    # Every argv below was executed against the real clone under this
    # exact env (verifier-shaped: throwaway HOME/TMPDIR) on 2026-09-21;
    # observed exits live in the wave receipt. The other three targets
    # (autofde-lab, ggen-igniter, gymact) are deliberately NOT registered:
    # see the block below.
    # ------------------------------------------------------------------

    # bitstar clone (~/xaas/worktrees/repos/bitstar): NO pyproject.toml at
    # the root, so `uv run` takes its no-project fallback and resolves
    # `pytest` from PATH (homebrew). test_cli_fixes.py is import-free pure
    # logic; the verifier-forced PYTHONDONTWRITEBYTECODE and the repo's
    # own .gitignore keep the tree clean.
    # Observed 2026-09-21: exit 0, "3 passed in 0.04s".
    bitstar = %{
      env: uv_env,
      max_output_bytes: 65_536,
      toolchain: [["uv", "--version"], ["git", "--version"]],
      steps: [
        %{
          id: "test",
          timeout_ms: 300_000,
          argv: ["uv", "run", "--frozen", "pytest", "test_cli_fixes.py", "-q"]
        }
      ]
    }

    # infinite-agentic-cli clone: the runbook §1.1 verifier command,
    # verbatim. The UV_PYTHON pin in uv_env is REQUIRED here (observed:
    # without it the throwaway HOME cannot see the uv-managed CPython the
    # clone's .venv was bound to, `uv run` falls back to a non-venv pytest,
    # and collection dies on `ModuleNotFoundError: infinite_agentic_cli`).
    # The repo's pytest ini writes reports/pytest.xml -- gitignored.
    # Observed 2026-09-21 (with the pin): exit 0, "11 passed in 0.77s".
    micli = %{
      env: uv_env,
      max_output_bytes: 65_536,
      toolchain: [["uv", "--version"], ["git", "--version"]],
      steps: [
        %{
          id: "test",
          timeout_ms: 300_000,
          argv: ["uv", "run", "--frozen", "pytest", "tests/test_analysis.py", "-q"]
        }
      ]
    }

    # autofde-lab, ggen-igniter, gymact: DELIBERATELY NOT REGISTERED
    # (2026-09-21) -- each suite was executed against its real clone under
    # the verifier-shaped env (throwaway HOME) and is structurally
    # red/dirty there, so a registration would fake readiness while every
    # close failed. Prerequisites live in the TARGET repos, not here:
    #
    #   * autofde-lab (120/1193 failed): machine-coupled collaborators a
    #     fresh clone lacks -- vendored `cmca_rank_cli` Rust binary
    #     (resolve checks $BCINR_CMCA_CLI / ~/bcinr / vendor target),
    #     beam-port + AtomVM + helm-chart + sregym/POWL sibling checkouts
    #     under ~/, and the identity anti-vacuity counts. Its REAL CI
    #     qualification is Linux-only (wheel install + MiniZinc + ray
    #     partitions). Also by design one hot-loop test rewrites the
    #     tracked docs/jira/.../concurrency-stress-findings.md -- an
    #     after-run clean-tree violation on its own.
    #   * ggen-igniter (28/1185 failed, rest green in 1056s): three
    #     test files (ggen_igniter_base_code_module/_pattern_string/
    #     _project_formatter_taskaliases) read the sibling `~/ex4pm`
    #     checkout via a COMPILE-TIME `System.user_home!()` fixture with
    #     no env override, and the verifier sets HOME after merging suite
    #     env. mix test cannot exclude files without blinding new-file
    #     detection. Prerequisite: EX4PM_ROOT-style override in the
    #     fixture. (Env pins needed to even compile: asdf elixir
    #     1.18.4-otp-27 per its own CI -- mix.lock's faker 0.18.0 has a
    #     raw \\u0085 the 1.20 tokenizer rejects; MIX_REBAR3 for :idna;
    #     cargo + RUSTUP_HOME/CARGO_HOME for the Rustler NIF.)
    #   * gymact (exit 2 + tracked-file rewrites): module-level
    #     `import gymnasium` etc. make a bare sync die at collection
    #     (needs `uv sync --all-extras --group dev`); standing-gated real
    #     gyms degrade only with GYMACT_ALLOW_DEGRADED_STANDINGS; but the
    #     suite REWRITES tracked reports/ocel + tests/fixtures files and
    #     drops untracked .inspect_logs/*.eval, several tests fail
    #     hermetically (chatman_state PROVIDER_ERROR:ValueError; local-
    #     repo/github discovery), and filterwarnings=["error"] promotes
    #     benign GC warnings to exit != 0. Also no committed uv.lock (the
    #     repo gitignores it), so every close re-resolves the world.

    # xaas clone: the repo's own fast boundary -- `mix test` (alias:
    # ecto.create + ecto.migrate + test; the :external/:kind/:stress/...
    # heavy tags stay excluded by test_helper.exs). MIX_TEST_PARTITION
    # gives the clone its OWN xaas_test_ultracode database
    # (config/test.exs concatenates it), so a campaign close and a local
    # `mix test` in the main checkout never share one mutable database.
    # cargo MUST be on PATH and rustup/cargo homes pinned: the
    # :ggen_igniter dependency compiles a Rustler NIF
    # (native/ggen_graph_nif) -- observed :enoent without cargo on PATH,
    # then "rustup could not choose a version of cargo" under a throwaway
    # HOME without RUSTUP_HOME/CARGO_HOME. Plain `mix compile` (not
    # --warnings-as-errors): the clone's dep tree carries charlist
    # deprecation warnings. First compile builds the EXLA C++ extension
    # from source (minutes); UV_CACHE_DIR-style warmth does not apply, the
    # per-worktree _build pays it once per epoch.
    # Observed 2026-09-21 (warm _build): compile exit 0; test exit 0,
    # "1351 passed, 72 excluded" in 68.9s.
    xaasclone = %{
      env: xaas_env,
      max_output_bytes: 65_536,
      toolchain: [["mix", "--version"], ["cargo", "--version"], ["git", "--version"]],
      steps: [
        %{id: "deps", timeout_ms: 600_000, argv: ["mix", "deps.get"]},
        %{id: "compile", timeout_ms: 900_000, argv: ["mix", "compile"]},
        %{id: "test", timeout_ms: 1_800_000, argv: ["mix", "test"]}
      ]
    }

    %{
      # ex_noun_verb_cli clone (~/xaas/worktrees/repos/nounverb): mix deps.get
      # against the committed mix.lock, strict compile, full mix test. Hex is
      # resolved from the pinned MIX_ARCHIVES so a throwaway HOME never
      # triggers the interactive `mix local.hex` prompt.
      #
      # Deliberately NOT court-receipt flagged yet (`receipt: true` + a
      # `mix test --trace` receipt_argv + result_format "mix_trace"): the
      # extractor exists and is unit-qualified, but no RED/GREEN witness on
      # the real nounverb worktree has been recorded, and a court flag is
      # declared only where witnessed. Same for spr-dod.
      "nounverb-dod" => %{
        env: %{
          "PATH" =>
            "/Users/sac/.asdf/installs/elixir/1.20.2-otp-28/bin:" <>
              "/Users/sac/.asdf/installs/erlang/28.3/bin:" <>
              "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
          "LANG" => "en_US.UTF-8",
          "MIX_ARCHIVES" => Path.expand("~/xaas/worktrees/toolchain/mix-archives")
        },
        max_output_bytes: 65_536,
        toolchain: [["mix", "--version"], ["git", "--version"]],
        steps: [
          %{id: "deps", timeout_ms: 180_000, argv: ["mix", "deps.get"]},
          %{id: "compile", timeout_ms: 300_000, argv: ["mix", "compile", "--warnings-as-errors"]},
          %{id: "test", timeout_ms: 300_000, argv: ["mix", "test"]}
        ]
      },
      # eds clone (~/xaas/worktrees/repos/eds): the full pytest suite against
      # the worktree's own src/ (relative PYTHONPATH), with the base temp
      # inside the verifier's per-run tmpdir so nothing is written outside
      # the worktree or shared between runs.
      #
      # COURT RECEIPT (Xaas.Ultracode.CourtReceipt): the step is flagged
      # `receipt: true` and declares `receipt_argv` (the same suite with
      # `-v` instead of `-q`, so per-test verdict lines are observed at
      # all -- `-q` output names only failures, and a passing acceptance
      # test would then be unverifiable) plus the suite-level
      # `result_format: "pytest_v"`. When a Run carries a court_map, the
      # fabric runs THIS argv and emits acceptance_results /
      # falsifier_results keyed by the work order's minted IRIs. Plain
      # runs (no court_map) keep the `-q` argv exactly as before.
      "eds-dod" => %{
        result_format: "pytest_v",
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
            receipt: true,
            receipt_argv: [
              "python3",
              "-m",
              "pytest",
              "tests",
              "--basetemp",
              "{tmpdir}",
              "-v",
              "-p",
              "no:cacheprovider"
            ],
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
      },
      # spr clone (~/xaas/worktrees/repos/spr): the full pytest suite. The
      # module under test sits at the repo root and tests/test_sprtool.py
      # inserts the repo root on sys.path itself, so no PYTHONPATH is needed
      # and pytest resolves from the Homebrew interpreter on PATH. The tree
      # carries no .gitignore, but the verifier forces PYTHONDONTWRITEBYTECODE
      # on every child and `-p no:cacheprovider` + `--basetemp {tmpdir}` keep
      # every write inside the worktree/per-run tmpdir, so the verifier's
      # after-run tree-clean check holds.
      "spr-dod" => %{
        env: %{
          "PATH" => "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
          "LANG" => "en_US.UTF-8"
        },
        max_output_bytes: 16_384,
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
      },
      "bitstar-dod" => bitstar,
      "bitstar-canonical" => bitstar,
      "infinite-agentic-cli-dod" => micli,
      "infinite-agentic-cli-canonical" => micli,
      "xaas-dod" => xaasclone,
      "xaas-canonical" => xaasclone
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

        format_problems =
          case Map.get(suite, :result_format) do
            nil ->
              []

            format when is_binary(format) ->
              if format in CourtReceipt.result_formats() do
                []
              else
                [ctx <> "unknown result_format #{inspect(format)}"]
              end

            other ->
              [ctx <> "result_format must be a string, got #{inspect(other)}"]
          end

        env_problems ++ step_problems ++ toolchain_problems ++ format_problems

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

    receipt_problem =
      case Map.get(step, :receipt) do
        nil ->
          []

        flag when is_boolean(flag) ->
          []

        other ->
          [
            "step #{inspect(Map.get(step, :id))}: receipt must be a boolean, got #{inspect(other)}"
          ]
      end

    receipt_argv_problem =
      case Map.get(step, :receipt_argv) do
        nil ->
          []

        argv when is_list(argv) ->
          case argv_problems("receipt_argv", argv) do
            [] -> []
            problems -> ["step #{inspect(Map.get(step, :id))}: receipt_argv: " <> hd(problems)]
          end

        other ->
          [
            "step #{inspect(Map.get(step, :id))}: receipt_argv must be an argv list, got #{inspect(other)}"
          ]
      end

    for problem <-
          id_problem ++
            argv_problems ++
            timeout_problem ++
            infra_problem ++
            receipt_problem ++
            receipt_argv_problem,
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
