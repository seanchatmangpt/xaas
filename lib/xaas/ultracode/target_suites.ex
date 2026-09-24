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

  ## The four SJ-program targets (xaas, autofde-lab, gymact, ggen-igniter)

  Each gets a per-item `<alias>-dod` suite (the cheapest sound check, judged at
  `Lease.close/4`) and an `<alias>-canonical` suite (the exhaustive check run
  at the integration head after the serial `--no-ff` promotion). The clones
  live at `~/xaas-worktrees/repos/<alias>` (`git clone --local`; see
  `Xaas.Ultracode.Repos.refresh/1`). Two extra environment laws apply on top
  of the ones above:

    * **Evidence-subject identity.** The Python suites open with a `subject`
      step that imports the package under test and refuses unless it resolved
      INSIDE the worktree. The repos' venvs are editable installs pointing at
      the operator's source checkout, so a green pytest run against the wrong
      tree would be a false ALIVE; the relative `PYTHONPATH=src` makes the
      worktree win and the `subject` step proves it did, every run.
    * **Elixir seeds, per-run DB.** The Elixir suites take `deps/` and
      `_build/` from an operator-owned APFS-clone seed under
      `~/xaas-worktrees/toolchain/seeds/<alias>` (the seed is what makes a
      git dependency resolvable under the verifier's credential-free
      throwaway HOME, and what turns a from-scratch compile into an
      incremental one). A missing seed only costs time: the first run that
      passes publishes it atomically. `mix test` runs against its own
      `MIX_TEST_PARTITION` database derived from the per-run `{tmpdir}` and
      drops it on exit, so concurrent verifier runs never share (or litter)
      a test database.
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

    # spr clone (~/xaas/worktrees/repos/spr): the full pytest suite. The
    # module under test sits at the repo root and tests/test_sprtool.py
    # inserts the repo root on sys.path itself, so no PYTHONPATH is needed
    # and pytest resolves from the Homebrew interpreter on PATH. The tree
    # carries no .gitignore, but the verifier forces PYTHONDONTWRITEBYTECODE
    # on every child and `-p no:cacheprovider` + `--basetemp {tmpdir}` keep
    # every write inside the worktree/per-run tmpdir, so the verifier's
    # after-run tree-clean check holds.
    #
    # BOTH heads share this one judge ("spr-canonical" is the same map, the
    # bitstar pattern), so a durable-registry `spr` entry is
    # admission-ready with its OWN suites instead of the legacy aps courts
    # (the mis-registration the 2026-09-21 V4/V10 finding eliminated).
    # Observed 2026-09-21 (verifier-shaped `env -i` run, clone head
    # 4283aab4): exit 0, "16 passed, 4 subtests passed in 0.25s", tree clean.
    spr = %{
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
      # spr clone (~/xaas/worktrees/repos/spr): the `spr` binding below --
      # ONE judge at BOTH heads (the bitstar pattern), so the durable
      # `spr` registry entry is admission-ready with its OWN suites.
      "spr-dod" => spr,
      "spr-canonical" => spr,
      "bitstar-dod" => bitstar,
      "bitstar-canonical" => bitstar,
      "infinite-agentic-cli-dod" => micli,
      "infinite-agentic-cli-canonical" => micli,
      "xaas-dod" => xaasclone,
      "xaas-canonical" => xaasclone
    }
    |> Map.merge(sj_program_suites())
  end

  # ------------------------------------------------------------------
  # SJ-program targets: xaas, autofde-lab, gymact, ggen-igniter
  # ------------------------------------------------------------------

  @seed_root "~/xaas-worktrees/toolchain/seeds"

  # Seed step (Elixir suites): take `deps/` and `_build/` from the operator
  # seed via APFS clone (`cp -c`) when the worktree has none. Never fails the
  # suite -- a missing/partial seed only costs time (deps.get + a cold
  # compile follow). A half-copied dir is removed so it cannot poison the run.
  @seed_take ~S"""
  [ -d deps ] || { [ -d "$SEED/deps" ] && { cp -cR "$SEED/deps" deps 2>/dev/null || cp -R "$SEED/deps" deps || rm -rf deps; }; }
  [ -d _build ] || { [ -d "$SEED/_build" ] && { cp -cR "$SEED/_build" _build 2>/dev/null || cp -R "$SEED/_build" _build || rm -rf _build; }; }
  exit 0
  """

  # Seed publish step (last step of an Elixir suite, so it only runs after
  # everything passed): publish `deps/` + `_build/` as the seed when none
  # exists. Copy into a private temp dir and `mv` into place, so a concurrent
  # or interrupted publish can never leave a half-written seed visible.
  @seed_publish ~S"""
  [ -d "$SEED/deps" ] && exit 0
  mkdir -p "$(dirname "$SEED")" || exit 0
  tmp="$SEED.tmp.$$"
  rm -rf "$tmp"
  mkdir "$tmp" || exit 0
  { { cp -cR deps "$tmp/deps" 2>/dev/null || cp -R deps "$tmp/deps"; } && { cp -cR _build "$tmp/_build" 2>/dev/null || cp -R _build "$tmp/_build"; }; } || { rm -rf "$tmp"; exit 0; }
  if [ -e "$SEED" ]; then rm -rf "$tmp"; else mv "$tmp" "$SEED" || rm -rf "$tmp"; fi
  exit 0
  """

  # `mix test` against a per-run database. `$1` is the run's `{tmpdir}`: it is
  # unique per verifier run, so the checksum-derived partition (a valid, short
  # Postgres identifier suffix -- `xaas_test<partition>` for xaas) never
  # collides between concurrent runs. The DB is dropped on exit whatever the
  # test verdict was, and the test exit code is the step's exit code.
  @mix_test_partitioned ~S"""
  MIX_TEST_PARTITION="v$(printf %s "$1" | cksum | cut -d' ' -f1)"
  export MIX_TEST_PARTITION
  shift
  mix test "$@"
  rc=$?
  mix ecto.drop --quiet >/dev/null 2>&1
  exit $rc
  """

  # Refuses unless `import <package>` resolved INSIDE the worktree under test
  # (the venvs are editable installs pointing at the operator's source
  # checkout -- see the moduledoc's evidence-subject law).
  @subject_code "import importlib, os, sys; m = importlib.import_module(sys.argv[1]); " <>
                  "p = os.path.realpath(m.__file__); w = os.path.realpath(os.getcwd()) + os.sep; " <>
                  "print('subject', sys.argv[1], p); sys.exit(0 if p.startswith(w) else 3)"

  defp sj_program_suites do
    %{
      # xaas itself: the Elixir/Phoenix + Ash platform. Toolchain pinned to the
      # repo's own .tool-versions (elixir 1.20.2-otp-28 / erlang 28.5.0.2).
      # DoD = strict compile + format gate + the narrow Reactor/actuation
      # falsifier + the ultracode seam the loop itself runs on;
      # canonical = the same gates plus the FULL default `mix test` at the
      # integration head. Postgres at the config/test.exs defaults
      # (postgres@localhost:5432) -- nothing else is passed through.
      "xaas-dod" =>
        elixir_suite("xaas", "1.20.2-otp-28", "28.5.0.2", 1_800_000, [
          "test/xaas/actuation_test.exs",
          "test/xaas/ultracode"
        ]),
      "xaas-canonical" => elixir_suite("xaas", "1.20.2-otp-28", "28.5.0.2", 3_600_000, []),

      # ggen_igniter (Elixir library): toolchain pinned to its .tool-versions
      # (elixir 1.18.4-otp-27 / erlang 27.2.4). Both suites run `mix test`
      # (the repo's own default exclusions apply); DoD additionally gates on
      # strict compile + format.
      "ggen-igniter-dod" =>
        elixir_suite("ggen-igniter", "1.18.4-otp-27", "27.2.4", 1_800_000, [],
          partitioned_db: false
        ),
      "ggen-igniter-canonical" =>
        elixir_suite("ggen-igniter", "1.18.4-otp-27", "27.2.4", 3_600_000, [],
          partitioned_db: false
        ),

      # The Friday reference KNOWN class (GC-FRI-0800 G6/G7): `mix format`
      # drift repair. The court IS the postcondition -- one receipt step,
      # `mix format --check-formatted` (no deps, no compile, no network),
      # judged by its exit status (`result_format: "exit_status"`): a work
      # order's acceptance IRI maps to `%{"test" => "format"}`.
      "ggen-igniter-format" => elixir_format_suite("ggen-igniter", "1.18.4-otp-27", "27.2.4"),

      # autofde-lab (Python): the repo's own venv interpreter is pinned by
      # ABSOLUTE path (children run under a throwaway HOME). DoD = the SA2A +
      # beam-bridge surface the Semantic Jira loop actually drives; the one
      # test that regenerates a tracked benchmark doc is deselected (a test
      # that rewrites tracked source cannot pass the clean-tree law).
      # canonical = the repo's own `just test` recipe.
      "autofde-lab-dod" =>
        python_suite(
          "~/autofde-lab/.venv/bin/python",
          "autofde_lab",
          600_000,
          [
            "tests/sa2a",
            "tests/beam",
            "--ignore=tests/sa2a/test_v26_9_17_concurrency_stress_chicago.py"
          ]
        ),
      "autofde-lab-canonical" =>
        python_suite(
          "~/autofde-lab/.venv/bin/python",
          "autofde_lab",
          3_000_000,
          [
            "tests",
            "-n",
            "4",
            "--ignore=tests/solvers/cpp",
            "--ignore=tests/solvers/python",
            "--ignore=tests/scheduling",
            "--ignore=tests/ecosystem",
            "--ignore=tests/domains",
            "--ignore=tests/flight_planning",
            "--ignore=tests/autofde/test_terraform_guards.py",
            "--ignore=tests/fabric/test_dspy_mcp_planner_loop_chicago.py",
            "--ignore=tests/fabric/test_mcp_ocel_instrumentation_chicago.py",
            "--ignore=tests/powl/test_import_separation.py",
            "--ignore=tests/test_self_play_dspy_advanced_planning_chicago.py",
            "--ignore=tests/test_self_play_dspy_all_domains_chicago.py",
            "--ignore=tests/test_self_play_dspy_turbofieldfare_chicago.py",
            "--ignore=tests/test_chatman_wasm.py",
            "--ignore=tests/test_import_all_submodules.py",
            "--ignore=tests/evidence/test_level4_witness_falsifiers_chicago.py",
            "--ignore=tests/sa2a/test_v26_9_17_concurrency_stress_chicago.py"
          ]
        ),

      # gymact (Python): same venv-pin + subject-identity law. The venv lacks
      # the optional gym extras, so the repo's OWN degrade contract
      # (`GYMACT_ALLOW_DEGRADED_STANDINGS`, an exact-name allowlist that turns
      # a missing collaborator into a NAMED, visible skip) is applied to
      # exactly the standings observed absent -- any other standing still
      # fails loudly.
      "gymact-dod" =>
        python_suite("~/gymact/.venv/bin/python", "gymact", 900_000, gymact_dod_args(),
          env: gymact_env()
        ),
      "gymact-canonical" =>
        python_suite("~/gymact/.venv/bin/python", "gymact", 3_000_000, gymact_canonical_args(),
          env: gymact_env()
        )
    }
  end

  defp gymact_env do
    %{
      "GYMACT_ALLOW_DEGRADED_STANDINGS" =>
        Enum.join(
          [
            "LOCAL_EXTRA:dspy",
            "LOCAL_GYM:browsergym-openended",
            "LOCAL_GYM:inspect-evals",
            "LOCAL_GYM:kubernetes-reconciliation",
            "LOCAL_GYM:swegym",
            "LOCAL_GYM:terraform-plan"
          ],
          ","
        )
    }
  end

  defp gymact_dod_args, do: ["tests"]
  defp gymact_canonical_args, do: ["tests"]

  # An Elixir target suite. `tests` are extra `mix test` paths (empty = the
  # full default suite). `:partitioned_db` (default true) runs `mix test`
  # through the per-run-database wrapper; `false` for a library with no test
  # database.
  defp elixir_suite(alias_name, elixir, erlang, test_timeout_ms, tests, opts \\ []) do
    partitioned? = Keyword.get(opts, :partitioned_db, true)
    env = elixir_env(alias_name, elixir, erlang)

    test_step =
      if partitioned? do
        %{
          id: "test",
          timeout_ms: test_timeout_ms,
          argv: ["/bin/sh", "-c", @mix_test_partitioned, "mix-test", "{tmpdir}"] ++ tests
        }
      else
        %{id: "test", timeout_ms: test_timeout_ms, argv: ["mix", "test"] ++ tests}
      end

    %{
      env: env,
      max_output_bytes: 65_536,
      toolchain: [["mix", "--version"], ["git", "--version"]],
      steps: [
        %{id: "seed", timeout_ms: 600_000, argv: ["/bin/sh", "-c", @seed_take, "seed"]},
        %{id: "deps", timeout_ms: 900_000, argv: ["mix", "deps.get"]},
        %{
          id: "compile",
          timeout_ms: 1_800_000,
          argv: ["mix", "compile", "--warnings-as-errors"]
        },
        %{id: "format", timeout_ms: 300_000, argv: ["mix", "format", "--check-formatted"]},
        test_step,
        %{id: "seed_publish", timeout_ms: 600_000, argv: ["/bin/sh", "-c", @seed_publish, "seed"]}
      ]
    }
  end

  # An Elixir format-court suite: the same pinned env as `elixir_suite/6`,
  # one receipt step whose exit status is the verdict.
  defp elixir_format_suite(alias_name, elixir, erlang) do
    %{
      env: elixir_env(alias_name, elixir, erlang),
      max_output_bytes: 65_536,
      result_format: "exit_status",
      toolchain: [["mix", "--version"], ["git", "--version"]],
      steps: [
        %{
          id: "format",
          timeout_ms: 300_000,
          receipt: true,
          argv: ["mix", "format", "--check-formatted"]
        }
      ]
    }
  end

  defp elixir_env(alias_name, elixir, erlang) do
    seed = Path.expand(Path.join(@seed_root, alias_name))

    %{
      "PATH" =>
        Enum.join(
          [
            asdf_bin("elixir", elixir),
            asdf_bin("erlang", erlang),
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin"
          ],
          ":"
        ),
      "LANG" => "en_US.UTF-8",
      "MIX_ENV" => "test",
      "MIX_ARCHIVES" => Path.expand("~/xaas-worktrees/toolchain/mix-archives"),
      "SEED" => seed
    }
  end

  # A Python target suite: the repo's venv interpreter pinned by absolute
  # path, `PYTHONPATH=src` (relative, resolved against the worktree), a
  # subject-identity step, then pytest over `pytest_args` with the verifier's
  # per-run `{tmpdir}` as basetemp and no cache provider.
  defp python_suite(python, package, test_timeout_ms, pytest_args, opts \\ []) do
    python = Path.expand(python)

    env =
      Map.merge(
        %{
          "PATH" => "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
          "LANG" => "en_US.UTF-8",
          "PYTHONPATH" => "src"
        },
        Keyword.get(opts, :env, %{})
      )

    %{
      env: env,
      max_output_bytes: 65_536,
      toolchain: [
        [python, "--version"],
        [python, "-m", "pytest", "--version"],
        ["git", "--version"]
      ],
      steps: [
        %{
          id: "subject",
          timeout_ms: 120_000,
          argv: [python, "-c", @subject_code, package]
        },
        %{
          id: "test",
          timeout_ms: test_timeout_ms,
          argv:
            [python, "-m", "pytest"] ++
              pytest_args ++
              ["--basetemp", "{tmpdir}", "-p", "no:cacheprovider"]
        }
      ]
    }
  end

  defp asdf_bin(tool, version), do: Path.expand("~/.asdf/installs/#{tool}/#{version}/bin")

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
