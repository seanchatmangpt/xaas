defmodule Xaas.Ultracode.Verifier do
  @moduledoc """
  Fabric-executed definition of done: an operator-registered verifier suite,
  run by XaaS itself (never by the leased worker) at close time.

  A leased worker cannot run tests -- `Bash` is refused by `Lease.admit_tool/2`
  and the plugin gate only carves out `git`. This module is the independent
  half: after a worker closes with a head the fabric has already confirmed,
  the suite named on the `Run` is executed against that exact head in the
  epoch worktree and its result is folded into the sealed receipt.

  ## Threat model (this is remote-code-execution-equivalent by design)

  A suite executes code that lives in the worktree (a test runner imports the
  candidate's tests). Every rule below exists because of that:

    * **Name-only lookup.** A caller can only supply a suite NAME. Argv lists
      live in `config :xaas, :ultracode_verifier_suites`, which is empty by
      default (fail closed). Nothing from a request is ever interpolated into
      an argv element, a path, or an atom.
    * **Containment root.** A suite runs only when the epoch worktree resolves
      (symlinks followed) to a git top-level under
      `config :xaas, :ultracode_worktree_root`. Unset root = refuse. Without
      this an API caller could aim a suite at any repository on the host.
    * **No shell.** Steps are argv lists spawned through `/usr/bin/env -i` with
      an explicit env allowlist (`suite.env`); the BEAM environment
      (`DATABASE_URL`, `SECRET_KEY_BASE`, tokens) never reaches the child.
      `HOME` and `TMPDIR` point at a per-run temp dir that is removed after.
    * **Process-group kill.** Each step leads its own process group
      (`setpgrp`), carries a `SIGALRM` backstop, and the Elixir-side deadline
      kills the whole group, so grandchildren do not outlive a timeout.
    * **Bounded output.** Only the last `max_output_bytes` of a step are kept.
    * **Head + tree discipline.** The tree must be clean before (else the
      worker left uncommitted work the head does not represent: `:fail`) and
      after (else the suite dirtied it: `:error`), and `HEAD` must be
      unchanged after.
    * **One run per epoch.** `:global.trans/4` with zero retries; a concurrent
      close on the same epoch gets `:error` `verification_in_progress`.

  This is not an OS sandbox. It bounds blast radius; it does not isolate.

  ## Suite shape

      %{"aps-dod" => %{
          env: %{"PATH" => "/opt/homebrew/bin:/usr/bin:/bin", "LANG" => "en_US.UTF-8"},
          max_output_bytes: 65_536,
          toolchain: [["python3", "--version"]],
          steps: [
            %{id: "court", timeout_ms: 600_000, infra_exit_codes: [2], receipt: true,
              argv: ["python3", "priv:verifiers/aps_dod_court.py",
                     "--worktree", "{worktree}", "--head", "{head}"]}
          ]}}

  An argv element is one of: a literal; `priv:<relpath>` (resolved under this
  app's `priv/`, `..` refused); or exactly one placeholder -- `{worktree}`,
  `{head}`, `{run_id}`, `{epoch_id}`, `{executor}`, `{ticket}`, `{verifier_id}`,
  `{tmpdir}`. A placeholder is only ever a WHOLE element.

  ## Court receipt mode (IRI-keyed verdicts)

  When the run ctx carries a `:court_map` (the work order's minted
  acceptance/falsifier/court IRIs mapped to predicates -- threaded by
  `Lease.close/4` from the fabric-owned Run row, never from the worker),
  the suite's `receipt: true` step becomes a COURT step and the run
  produces an IRI-keyed court receipt (see
  `Xaas.Ultracode.CourtReceipt` for the consumer contract and the
  fail-closed law):

    * the step runs with its `receipt_argv` (a per-step declaration, so a
      generic pytest/mix suite can opt into per-test verbose output for
      the receipt run without changing its plain run);
    * the suite declares `result_format` (`"pytest_v"` for
      `pytest -v` output, `"mix_trace"` for `mix test --trace`);
    * `result["court_receipt"]` carries `acceptance_results` /
      `falsifier_results` keyed by the work order's IRIs, `court_results`
      keyed by the required court IRIs, and a `binding` (suite, step id,
      exact head, argv digest);
    * ANY production refusal (undeclared receipt step, unknown result
      format, a mapped test with no observed verdict) makes the whole run
      `"error"` with reason `{:court_receipt_refused, _}` -- a defaulted
      or skipped verdict row would be a fabricated one.

  ## Falsifier probes (a DoD must be able to fail)

  A green suite proves nothing if it is also green on a broken tree (an
  `exit 0` DoD passes everything). So a suite may declare `probes:` (and a
  run may add more through `ctx[:probes]` or, for Semantic Jira orders, the
  `probes` key of its `{ticket}` file -- see `Xaas.Ultracode.OrderProbes`).
  Each probe (`Xaas.Ultracode.Probes`: a named mutation given as data) is
  applied to a SCRATCH CLONE of the exact head under test, and the suite's
  own steps are rerun there. The probe REQUIRES that rerun to FAIL:

    * every probe fails the rerun -> the verdict stands (`pass`);
    * a probe's rerun still PASSES -> the DoD is VACUOUS: status `"error"`,
      `result["refusal"] == "vacuous_dod"`, reason `{:vacuous_dod, [ids]}`.
      `Lease.close/4` maps error to `:partial_alive`, so a vacuous DoD can
      never seal `:alive` (`AliveRequiresCourt` needs `status == "pass"`);
    * a probe that cannot be applied, or whose rerun times out / errors,
      proves nothing: status `"error"`, `result["refusal"] == "probes_refused"`;
    * `require_probes: true` on a suite with no probes at all is refused the
      same way (`:probes_required`).

  Probes only run once the real steps passed (a failing suite is already
  falsified) and never touch the real worktree (the clone and its temp dirs
  are removed; the head/tree-clean checks still bracket the whole run). The
  per-probe record is in `result["probes"]`.

  ## Quarantine (suite health court)

  A suite that declares `health:` is measured by `Xaas.Ultracode.SuiteHealth`
  against a known-green and a known-red fixture; when its latest receipt is
  stale, red, or bound to a different suite definition, `run/2` refuses it:
  status `"error"`, `result["refusal"] == "suite_unhealthy"` (Run admission
  refuses the name too, see `Validations.VerifierSuiteRegistered`). The court
  itself runs the suite with `ctx[:health_check] == true`, which bypasses
  quarantine and probes.

  ## Result

  `run/2` always returns `{:ok, result}`; `result["status"]` is one of
  `"pass" | "fail" | "timeout" | "error"`. `Lease.close/4` maps pass to the
  claimed outcome, fail to `:build_broken`, timeout/error to `:partial_alive`.
  `result["refusal"]` (when present) types an `"error"`: `"vacuous_dod"`,
  `"probes_refused"` or `"suite_unhealthy"`.
  """

  require Logger

  alias Xaas.Ultracode.{CourtReceipt, Probes, SuiteHealth}

  @grace_ms 2_000
  @default_max_output 65_536
  @placeholders ~w({worktree} {head} {run_id} {epoch_id} {executor} {ticket} {verifier_id} {tmpdir})
  # Keys only `CourtReceipt.produce/6` may write into a court receipt.
  @fabric_only_receipt_keys ~w(binding)

  @type ctx :: %{
          required(:worktree) => String.t(),
          required(:head) => String.t(),
          required(:run_id) => String.t(),
          required(:epoch_id) => String.t(),
          optional(:executor) => String.t() | nil,
          optional(:court_map) => map() | nil,
          optional(:probes) => [map()],
          optional(:health_check) => boolean(),
          optional(:base_sha) => String.t() | nil
        }

  @doc "True when `name` is a registered suite. Never raises on non-binaries."
  @spec registered?(term()) :: boolean()
  def registered?(name) when is_binary(name), do: Map.has_key?(suites(), name)
  def registered?(_), do: false

  @doc "Placeholder argv elements a suite may reference (as WHOLE elements only)."
  @spec placeholders() :: [String.t()]
  def placeholders, do: @placeholders

  @doc "Registered suite names (for typed error messages and docs)."
  @spec suite_names() :: [String.t()]
  def suite_names, do: suites() |> Map.keys() |> Enum.sort()

  @doc "The registered suite declaration for `name`, or `:error`."
  @spec suite(term()) :: {:ok, map()} | :error
  def suite(name) when is_binary(name), do: Map.fetch(suites(), name)
  def suite(_), do: :error

  @doc "Stable digest of a suite's steps (id, argv, timeout, receipt_argv)."
  @spec suite_digest(map()) :: String.t()
  def suite_digest(suite), do: argv_digest(suite)

  @doc """
  Health admission for a registered suite name: `:ok` or
  `{:quarantined, reason}` (see `Xaas.Ultracode.SuiteHealth`). An unknown name
  is `:ok` here -- refusing unknown names is `registered?/1`'s job.
  """
  @spec admission(term()) :: :ok | {:quarantined, term()}
  def admission(name) do
    case suite(name) do
      {:ok, suite} -> SuiteHealth.admission(name, suite)
      :error -> :ok
    end
  end

  @doc """
  Runs the named suite against `ctx.worktree` at `ctx.head`. Always returns
  `{:ok, result}` with a JSON-safe string-keyed map.
  """
  @spec run(String.t(), ctx()) :: {:ok, map()}
  def run(suite_name, ctx) when is_binary(suite_name) and is_map(ctx) do
    base = %{"suite" => suite_name, "head" => ctx.head}

    result =
      case Map.fetch(suites(), suite_name) do
        :error ->
          finish(base, :error, "unknown_suite")

        {:ok, suite} ->
          case quarantine(suite_name, suite, ctx) do
            :ok ->
              :global.trans(
                {{__MODULE__, ctx.epoch_id}, self()},
                fn -> guarded(suite, ctx, base) end,
                [node()],
                0
              )
              |> case do
                :aborted -> finish(base, :error, "verification_in_progress")
                other -> other
              end

            {:quarantined, reason} ->
              refuse(base, "suite_unhealthy", {:suite_unhealthy, reason})
          end
      end

    {:ok, result}
  rescue
    error ->
      Logger.error("[ultracode] verifier crashed: #{Exception.message(error)}")

      {:ok,
       finish(%{"suite" => suite_name, "head" => Map.get(ctx, :head)}, :error, "verifier_crashed")}
  end

  # ------------------------------------------------------------------

  defp guarded(suite, ctx, base) do
    base = Map.put(base, "argv_sha256", argv_digest(suite))

    with {:ok, worktree} <- contained_worktree(ctx.worktree),
         :ok <- head_is(worktree, ctx.head, :before),
         :ok <- tree_clean(worktree, :before),
         {:ok, probes} <- declared_probes(suite, ctx) do
      tmp = make_tmp(ctx.epoch_id)

      try do
        court = court_contract(suite, ctx)

        case verdict_sources_pinned(court, suite, ctx, worktree) do
          :ok -> verify(suite, ctx, worktree, tmp, base, court, probes)
          {:error, reason} -> finish(base, :error, {:court_receipt_refused, reason})
        end
      after
        File.rm_rf(tmp)
      end
    else
      {:error, {:worker_left_uncommitted_changes, _} = reason} ->
        finish(base, :fail, reason)

      {:error, {:probes_refused, _} = reason} ->
        refuse(base, "probes_refused", reason)

      {:error, reason} ->
        finish(base, :error, reason)
    end
  end

  # ------------------------------------------------------------------
  # Quarantine and falsifier probes
  # ------------------------------------------------------------------

  # The suite health court runs the suite itself with `health_check: true`
  # (it must measure a suite that is currently quarantined).
  defp quarantine(_name, _suite, %{health_check: true}), do: :ok
  defp quarantine(name, suite, _ctx), do: SuiteHealth.admission(name, suite)

  # Probes in force for this run: the suite's own, the ctx's, and the ones a
  # Semantic Jira order carried into the controller-written `{ticket}` file.
  # A malformed declaration refuses the run before any step executes.
  defp declared_probes(_suite, %{health_check: true}), do: {:ok, []}

  defp declared_probes(suite, ctx) do
    with {:ok, from_ticket} <- ticket_probes(ctx),
         {:ok, probes} <-
           Probes.admit(Map.get(suite, :probes, []) ++ (ctx[:probes] || []) ++ from_ticket),
         :ok <- probes_required(suite, probes) do
      {:ok, probes}
    else
      {:error, reason} -> {:error, {:probes_refused, reason}}
    end
  end

  defp probes_required(suite, []) do
    if Map.get(suite, :require_probes, false), do: {:error, :probes_required}, else: :ok
  end

  defp probes_required(_suite, _probes), do: :ok

  defp ticket_probes(ctx) do
    dir = Application.get_env(:xaas, :ultracode_ticket_dir)

    with true <- is_binary(dir) and dir != "",
         true <- Regex.match?(~r/\A[A-Za-z0-9._:-]+\z/, to_string(ctx.run_id)),
         {:ok, raw} <- File.read(Path.join(dir, "#{ctx.run_id}.json")),
         {:ok, %{} = ticket} <- Jason.decode(raw) do
      case ticket do
        %{"probes_error" => error} when is_binary(error) ->
          {:error, {:order_probes_invalid, error}}

        %{"probes" => list} when is_list(list) ->
          {:ok, list}

        _ ->
          {:ok, []}
      end
    else
      _ -> {:ok, []}
    end
  end

  defp probe_phase(base, suite, ctx, worktree, probes) do
    records = Enum.map(probes, &run_probe(&1, suite, ctx, worktree))
    survived = for %{"verdict" => "survived", "id" => id} <- records, do: id

    unproven =
      for %{"verdict" => verdict, "id" => id} = record <- records,
          verdict in ["unapplicable", "inconclusive"],
          do: [id, verdict, record["reason"]]

    refusal =
      cond do
        survived != [] -> {"vacuous_dod", {:vacuous_dod, survived}}
        unproven != [] -> {"probes_refused", {:probes_refused, unproven}}
        true -> nil
      end

    base =
      base
      |> Map.put("probes", records)
      |> Map.put("probe_summary", %{
        "declared" => length(records),
        "killed" => Enum.count(records, &(&1["verdict"] == "killed")),
        "survived" => length(survived)
      })

    {base, refusal}
  end

  # One probe: exact head cloned into its own scratch dir, mutated, and the
  # suite's plain steps rerun there. The clone and the step tmp dir are
  # SEPARATE directories (a `--basetemp {tmpdir}` pytest run clears its
  # tmpdir, which must never be the clone's parent). Everything is removed.
  defp run_probe(probe, suite, ctx, worktree) do
    scratch = make_tmp("#{ctx.epoch_id}-probe")
    step_tmp = make_tmp("#{ctx.epoch_id}-probe-run")

    try do
      with {:ok, clone} <- Probes.scratch_clone(worktree, ctx.head, Path.join(scratch, "clone")),
           :ok <- Probes.apply_probe(probe, clone) do
        steps = run_steps(suite, ctx, clone, step_tmp, false)

        case steps |> Enum.map(& &1["status"]) |> worst_status() do
          :fail -> probe_record(probe, "killed", nil, steps)
          :pass -> probe_record(probe, "survived", nil, steps)
          other -> probe_record(probe, "inconclusive", "rerun_#{other}", steps)
        end
      else
        {:error, reason} -> probe_record(probe, "unapplicable", reason_string(reason), [])
      end
    after
      File.rm_rf(scratch)
      File.rm_rf(step_tmp)
    end
  end

  defp probe_record(probe, verdict, reason, steps) do
    %{"id" => probe.id, "kind" => probe.kind, "verdict" => verdict}
    |> then(fn r -> if reason, do: Map.put(r, "reason", reason), else: r end)
    |> then(fn r ->
      Enum.reduce([:falsifier, :acceptance], r, fn key, acc ->
        case Map.fetch(probe, key) do
          {:ok, value} -> Map.put(acc, Atom.to_string(key), value)
          :error -> acc
        end
      end)
    end)
    |> Map.put("steps", Enum.map(steps, &Map.take(&1, ["id", "status", "exit"])))
  end

  # A typed refusal: an `"error"` verdict (never alive) whose `"refusal"`
  # names WHY, for machine consumers.
  defp refuse(base, type, reason) do
    base |> finish(:error, reason) |> Map.put("refusal", type)
  end

  defp verify(suite, ctx, worktree, tmp, base, court, probes) do
    steps = run_steps(suite, ctx, worktree, tmp, court != nil)
    status = steps |> Enum.map(& &1["status"]) |> worst_status()

    base =
      base |> Map.put("steps", steps) |> Map.put("toolchain", toolchain(suite, worktree, tmp))

    {base, court_error} = court_receipt(base, suite, steps, court)

    # Falsifier probes only matter for a verdict that would otherwise
    # stand: a court refusal or a failing suite is already not-alive.
    {base, probe_refusal} =
      if court_error == nil and status == :pass and probes != [] do
        probe_phase(base, suite, ctx, worktree, probes)
      else
        {base, nil}
      end

    case {court_error, probe_refusal, status, head_is(worktree, ctx.head, :after),
          tree_clean(worktree, :after)} do
      {{:refused, reason}, _, _, _, _} ->
        finish(base, :error, {:court_receipt_refused, reason})

      {nil, {type, reason}, :pass, _, _} ->
        refuse(base, type, reason)

      {nil, nil, :pass, :ok, :ok} ->
        finish(base, :pass, nil)

      {nil, nil, :pass, {:error, reason}, _} ->
        finish(base, :error, reason)

      {nil, nil, :pass, _, {:error, reason}} ->
        finish(base, :error, reason)

      {nil, _, status, _, _} ->
        finish(base, status, first_failure(steps))
    end
  end

  # The court receipt contract in force for this run, if any: the ctx's
  # court_map (validated -- a malformed map is a typed refusal, never a
  # silent "no court") plus the suite's receipt-flagged step. A court_map
  # with NO receipt step in the suite is a misdeclared contract and is
  # refused -- silently skipping would close alive-family with the
  # IRI-keyed evidence missing.
  defp court_contract(suite, ctx) do
    case Map.get(ctx, :court_map) do
      nil ->
        nil

      raw ->
        case CourtReceipt.admit(raw) do
          {:ok, nil} -> nil
          {:ok, court_map} -> receipt_step(suite, court_map)
          {:error, reason} -> {:refused, reason}
        end
    end
  end

  defp receipt_step(suite, court_map) do
    case Enum.find(suite.steps, &Map.get(&1, :receipt, false)) do
      nil -> {:refused, :receipt_step_undeclared}
      step -> {step, court_map}
    end
  end

  defp finish(base, status, reason) do
    base
    |> Map.put("status", Atom.to_string(status))
    |> then(fn m -> if reason, do: Map.put(m, "reason", reason_string(reason)), else: m end)
  end

  defp reason_string(reason) when is_binary(reason), do: reason
  defp reason_string(reason), do: inspect(reason)

  defp worst_status(statuses) do
    cond do
      "error" in statuses -> :error
      "timeout" in statuses -> :timeout
      "fail" in statuses -> :fail
      true -> :pass
    end
  end

  defp first_failure(steps) do
    case Enum.find(steps, &(&1["status"] != "pass")) do
      nil -> nil
      step -> "step #{step["id"]}: #{step["status"]}"
    end
  end

  # Legacy path (no court_map): the receipt step's last output line, when it is a
  # JSON object, is the suite script's OWN receipt (the APS court script's shape).
  # It is script output, so it is never fabric evidence: a `"binding"` key is
  # what marks a receipt PRODUCED by `CourtReceipt.produce/6` (the marker
  # `Lease.publish_court_receipt/2` and `SemanticReceipt` key on), so a line that
  # carries one is a forged fabric receipt and is dropped, not recorded. The drop
  # is visible in the result (`"legacy_court_receipt_refused"`).
  defp maybe_put_receipt(base, suite, steps) do
    with %{id: id} <- Enum.find(suite.steps, &Map.get(&1, :receipt, false)),
         %{"output_tail" => tail} <- Enum.find(steps, &(&1["id"] == to_string(id))),
         line when is_binary(line) <- last_line(tail),
         {:ok, %{} = receipt} <- Jason.decode(line),
         true <- byte_size(line) <= 32_768 do
      if Enum.any?(@fabric_only_receipt_keys, &Map.has_key?(receipt, &1)) do
        Map.put(base, "legacy_court_receipt_refused", "fabric_only_key")
      else
        Map.put(base, "court_receipt", receipt)
      end
    else
      _ -> base
    end
  end

  # Court receipt mode: the verdicts are read from what the receipt step PRINTS,
  # and the step runs repo-resident code (`sh check.sh`, a pytest file) the worker
  # can rewrite. So the files that DECIDE a verdict must be the ones the work
  # order was minted against: every file a mapped test id names (pytest ids are
  # `path::test`) and every regular-file operand of the receipt step's argv must
  # be byte-identical between the base SHA and the judged head, else the court
  # refuses (`{:verdict_source_modified, path}`) and the run is "error" -- the
  # work may be fine, but the court cannot witness it. A caller that supplies no
  # `:base_sha` (every Run materialized by `SemanticWork` carries one) has nothing
  # to compare against and is not pinned. Only the id paths of `pytest_v` ids are
  # known; a `mix_trace` id is a test description, so a mix suite pins its argv
  # file operands only.
  defp verdict_sources_pinned({step, court_map}, suite, %{base_sha: base_sha} = ctx, worktree)
       when is_binary(base_sha) do
    paths = pinned_paths(step, court_map, Map.get(suite, :result_format), worktree, base_sha)

    Enum.reduce_while(paths, :ok, fn path, :ok ->
      case path_changed(worktree, base_sha, ctx.head, path) do
        :same -> {:cont, :ok}
        :changed -> {:halt, {:error, {:verdict_source_modified, path}}}
        :unknown -> {:halt, {:error, {:verdict_source_unverifiable, path}}}
      end
    end)
  end

  defp verdict_sources_pinned(_no_pinned_court, _suite, _ctx, _worktree), do: :ok

  defp pinned_paths(step, court_map, result_format, worktree, base_sha) do
    id_paths =
      if result_format == "pytest_v" do
        for group <- ~w(acceptance falsifiers),
            {_iri, %{"test" => id}} <- Map.get(court_map, group, %{}) do
          id |> String.split("::", parts: 2) |> hd()
        end
      else
        []
      end

    argv_paths =
      for operand <- CourtReceipt.step_argv(step, true) || [],
          repo_file_operand?(operand, worktree, base_sha),
          do: operand

    (id_paths ++ argv_paths) |> Enum.filter(&safe_relative?/1) |> Enum.uniq() |> Enum.sort()
  end

  defp safe_relative?(path) do
    path != "" and Path.type(path) == :relative and ".." not in Path.split(path)
  end

  defp repo_file_operand?(operand, worktree, base_sha) do
    is_binary(operand) and safe_relative?(operand) and not String.starts_with?(operand, "-") and
      not String.starts_with?(operand, "priv:") and operand not in @placeholders and
      (File.regular?(Path.join(worktree, operand)) or blob_at?(worktree, base_sha, operand))
  end

  defp blob_at?(worktree, rev, path) do
    case git(worktree, ["cat-file", "-t", rev <> ":" <> path]) do
      {"blob\n", 0} -> true
      _ -> false
    end
  end

  defp path_changed(worktree, base_sha, head, path) do
    case git(worktree, [
           "diff",
           "--quiet",
           "--no-renames",
           "--no-ext-diff",
           base_sha,
           head,
           "--",
           path
         ]) do
      {_, 0} -> :same
      {_, 1} -> :changed
      _ -> :unknown
    end
  end

  # `refs/replace` lives in the worker-writable repository: read objects as they
  # are, never as a replace ref says they are. (`path_changed/4` also passes
  # `--no-renames --no-ext-diff`, without which `git diff --quiet` reports a
  # replaced blob as unchanged; each defence alone is enough, both are kept, and
  # `VerifierVerdictSourceTest` kills the mutant that removes both.)
  defp git(worktree, args) do
    System.cmd("git", ["-C", worktree | args],
      stderr_to_stdout: true,
      env: [{"GIT_NO_REPLACE_OBJECTS", "1"}]
    )
  end

  # Court receipt mode: produce the IRI-keyed receipt from the receipt
  # step's output (replacing the legacy JSON-line path entirely -- when a
  # court_map is in force it owns the receipt contract). Any production
  # refusal surfaces as a court_error that makes the whole run "error".
  defp court_receipt(base, _suite, _steps, {:refused, reason}) do
    {base, {:refused, reason}}
  end

  defp court_receipt(base, suite, steps, {step, court_map}) do
    step_result = Enum.find(steps, &(&1["id"] == to_string(step.id)))

    CourtReceipt.produce(
      court_map,
      base["suite"],
      suite,
      step_result || %{"id" => to_string(step.id)},
      base["head"],
      base["argv_sha256"]
    )
    |> case do
      {:ok, receipt} -> {Map.put(base, "court_receipt", receipt), nil}
      {:error, reason} -> {base, {:refused, reason}}
    end
  end

  defp court_receipt(base, suite, steps, nil), do: {maybe_put_receipt(base, suite, steps), nil}

  defp last_line(tail) do
    tail |> String.split("\n", trim: true) |> List.last()
  end

  # ------------------------------------------------------------------
  # Containment and repository state
  # ------------------------------------------------------------------

  @doc """
  The containment law: `{:ok, realpath}` only when `worktree` resolves
  (symlinks followed) to a git top-level strictly under
  `config :xaas, :ultracode_worktree_root`; `{:error, reason}` otherwise
  (unset root refuses). Public so a mutating construction worker
  (`Xaas.Ultracode.RecipeWorker`) is fenced by the same root as the verifier.
  """
  @spec contained_worktree(String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def contained_worktree(nil), do: {:error, "no_worktree"}

  def contained_worktree(worktree) do
    case Application.get_env(:xaas, :ultracode_worktree_root) do
      root when is_binary(root) and root != "" ->
        with {:ok, real_root} <- realpath(root),
             {:ok, real_wt} <- realpath(worktree),
             {:ok, top} <- git_toplevel(real_wt),
             :ok <-
               if(top == real_wt, do: :ok, else: {:error, "worktree_is_not_a_repository_root"}),
             :ok <-
               if(String.starts_with?(real_wt, real_root <> "/"),
                 do: :ok,
                 else: {:error, "worktree_outside_root"}
               ) do
          {:ok, real_wt}
        end

      _ ->
        {:error, "worktree_root_unconfigured"}
    end
  end

  # Symlink-resolving realpath in pure Elixir (there is no portable realpath
  # binary: /usr/bin/realpath is absent on current macOS). Bounded depth.
  defp realpath(path) do
    if File.exists?(path),
      do: resolve_links(Path.split(Path.expand(path)), "/", 0),
      else: {:error, "worktree_not_found"}
  end

  defp resolve_links(_parts, _acc, depth) when depth > 40, do: {:error, "symlink_loop"}
  defp resolve_links([], acc, _depth), do: {:ok, acc}
  defp resolve_links(["/" | rest], _acc, depth), do: resolve_links(rest, "/", depth)

  defp resolve_links([component | rest], acc, depth) do
    candidate = Path.join(acc, component)

    case File.read_link(candidate) do
      {:ok, target} ->
        resolve_links(Path.split(Path.expand(target, acc)) ++ rest, "/", depth + 1)

      {:error, _} ->
        resolve_links(rest, candidate, depth)
    end
  end

  defp git_toplevel(dir) do
    case System.cmd("git", ["-C", dir, "rev-parse", "--show-toplevel"], stderr_to_stdout: true) do
      {out, 0} -> realpath(String.trim(out))
      {_, _} -> {:error, "worktree_not_a_git_repo"}
    end
  end

  defp head_is(worktree, head, phase) do
    case System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"], stderr_to_stdout: true) do
      {out, 0} ->
        if String.trim(out) == head, do: :ok, else: {:error, "head_changed_#{phase}_suite"}

      {_, _} ->
        {:error, "head_unreadable_#{phase}_suite"}
    end
  end

  defp tree_clean(worktree, phase) do
    case System.cmd("git", ["-C", worktree, "status", "--porcelain"], stderr_to_stdout: true) do
      {"", 0} ->
        :ok

      {out, 0} when phase == :before ->
        {:error,
         {:worker_left_uncommitted_changes,
          out |> String.split("\n", trim: true) |> Enum.take(20)}}

      {_out, 0} ->
        {:error, "suite_dirtied_worktree"}

      {_, _} ->
        {:error, "git_status_failed_#{phase}_suite"}
    end
  end

  # ------------------------------------------------------------------
  # Steps
  # ------------------------------------------------------------------

  defp run_steps(suite, ctx, worktree, tmp, court_mode) do
    subst = substitutions(ctx, worktree, tmp)

    Enum.reduce_while(suite.steps, [], fn step, acc ->
      result =
        step
        |> maybe_receipt_argv(court_mode)
        |> run_step(suite, subst, worktree, tmp)

      acc = acc ++ [result]
      if result["status"] == "pass", do: {:cont, acc}, else: {:halt, acc}
    end)
  end

  # In court receipt mode a receipt-flagged step runs its declared
  # `receipt_argv` (per-test verbose output) instead of its plain argv.
  defp maybe_receipt_argv(%{receipt: true} = step, true),
    do: Map.put(step, :argv, CourtReceipt.step_argv(step, true))

  defp maybe_receipt_argv(step, _court_mode), do: step

  defp substitutions(ctx, worktree, tmp) do
    ticket_dir = Application.get_env(:xaas, :ultracode_ticket_dir, "")

    %{
      "{worktree}" => worktree,
      "{head}" => ctx.head,
      "{run_id}" => ctx.run_id,
      "{epoch_id}" => ctx.epoch_id,
      "{executor}" => ctx[:executor] || "",
      "{ticket}" => Path.join(to_string(ticket_dir), "#{ctx.run_id}.json"),
      "{verifier_id}" => "xaas-ultracode-verifier/#{Application.spec(:xaas, :vsn)}",
      "{tmpdir}" => tmp
    }
  end

  defp resolve_argv(argv, subst) do
    Enum.reduce_while(argv, {:ok, []}, fn element, {:ok, acc} ->
      case resolve_element(element, subst) do
        {:ok, resolved} -> {:cont, {:ok, acc ++ [resolved]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp resolve_element("priv:" <> rel, _subst) do
    if ".." in Path.split(rel) or String.starts_with?(rel, "/") do
      {:error, "bad_priv_path"}
    else
      path = Application.app_dir(:xaas, Path.join("priv", rel))
      if File.regular?(path), do: {:ok, path}, else: {:error, "priv_file_missing"}
    end
  end

  defp resolve_element(element, subst) when element in @placeholders,
    do: {:ok, Map.fetch!(subst, element)}

  defp resolve_element(element, _subst) when is_binary(element) do
    if Enum.any?(@placeholders, &String.contains?(element, &1)),
      do: {:error, "embedded_placeholder_refused"},
      else: {:ok, element}
  end

  defp run_step(step, suite, subst, worktree, tmp) do
    id = to_string(step.id)
    timeout_ms = Map.get(step, :timeout_ms, 300_000)
    started = System.monotonic_time(:millisecond)

    case resolve_argv(step.argv, subst) do
      {:error, reason} ->
        step_result(id, nil, "error", 0, "", reason)

      {:ok, argv} ->
        max_out = Map.get(suite, :max_output_bytes, @default_max_output)
        outcome = spawn_and_collect(argv, suite, worktree, tmp, timeout_ms, max_out)
        duration = System.monotonic_time(:millisecond) - started

        case outcome do
          {:exit, 0, out} ->
            step_result(id, 0, "pass", duration, out, nil)

          {:exit, code, out} ->
            status = if code in Map.get(step, :infra_exit_codes, []), do: "error", else: "fail"
            step_result(id, code, status, duration, out, nil)

          {:timeout, out} ->
            step_result(id, nil, "timeout", duration, out, "step_timeout_#{timeout_ms}ms")

          {:spawn_error, reason} ->
            step_result(id, nil, "error", duration, "", reason)
        end
    end
  end

  defp step_result(id, exit_code, status, duration_ms, tail, reason) do
    base = %{
      "id" => id,
      "exit" => exit_code,
      "status" => status,
      "duration_ms" => duration_ms,
      "output_tail" => String.replace_invalid(tail, "?")
    }

    if reason, do: Map.put(base, "reason", reason_string(reason)), else: base
  end

  @doc """
  The fabric's one guarded process runner: spawns `argv` (already resolved,
  no placeholders) in `worktree` through `/usr/bin/env -i` with only
  `suite.env` plus `HOME`/`TMPDIR` pointed at `tmp`, as its own process
  group with a `SIGALRM` backstop, and kills the whole group at
  `timeout_ms`. Keeps only the last `max_out` bytes of combined output.

  Public so a deterministic construction worker
  (`Xaas.Ultracode.RecipeWorker`) runs its argv through the SAME runner the
  independent verifier uses -- one containment implementation, never a copy.

  Returns `{:exit, code, output_tail}`, `{:timeout, output_tail}`, or
  `{:spawn_error, reason}`.
  """
  @spec spawn_and_collect(
          [String.t()],
          map(),
          String.t(),
          String.t(),
          pos_integer(),
          pos_integer()
        ) ::
          {:exit, non_neg_integer(), binary()}
          | {:timeout, binary()}
          | {:spawn_error, String.t()}
  def spawn_and_collect(argv, suite, worktree, tmp, timeout_ms, max_out) do
    env =
      suite
      |> Map.get(:env, %{})
      |> Map.merge(%{"HOME" => tmp, "TMPDIR" => tmp, "PYTHONDONTWRITEBYTECODE" => "1"})
      |> Enum.map(fn {k, v} -> "#{k}=#{v}" end)

    alarm_s = div(timeout_ms, 1000) + 2
    wrapper = "setpgrp(0,0); alarm(shift @ARGV); exec @ARGV or exit 127;"
    args = ["-i"] ++ env ++ ["/usr/bin/perl", "-e", wrapper, Integer.to_string(alarm_s)] ++ argv

    port =
      Port.open({:spawn_executable, "/usr/bin/env"}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        :hide,
        {:args, args},
        {:cd, worktree}
      ])

    os_pid = port_os_pid(port)
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    try do
      collect(port, os_pid, deadline, "", max_out)
    after
      kill_group(os_pid)
    end
  rescue
    error -> {:spawn_error, "spawn_failed: #{Exception.message(error)}"}
  end

  defp collect(port, os_pid, deadline, tail, max_out) do
    remaining = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {^port, {:data, data}} ->
        collect(port, os_pid, deadline, keep_tail(tail <> data, max_out), max_out)

      {^port, {:exit_status, code}} ->
        {:exit, code, tail}
    after
      remaining ->
        kill_group(os_pid)
        close_port(port)
        {:timeout, tail}
    end
  end

  # A step that exits before the caller is scheduled again (loaded scheduler,
  # fast `true`) has already closed its port: `Port.info/2` is then `nil`. The
  # data and exit_status messages are already in the mailbox, so the result is
  # still collectable; only the process-group kill has nothing to address.
  @doc false
  @spec port_os_pid(port()) :: non_neg_integer() | nil
  def port_os_pid(port) do
    case Port.info(port, :os_pid) do
      {:os_pid, os_pid} -> os_pid
      nil -> nil
    end
  end

  # Killing the group usually closes the port first; closing a closed port
  # raises, and that must not turn a timeout into a spawn error.
  defp close_port(port) do
    Port.close(port)
  rescue
    ArgumentError -> :ok
  end

  defp keep_tail(bin, max) when byte_size(bin) <= max, do: bin
  defp keep_tail(bin, max), do: binary_part(bin, byte_size(bin) - max, max)

  # Group-wide TERM, brief grace, then KILL. Safe to call when the group is
  # already gone.
  defp kill_group(nil), do: :ok

  defp kill_group(os_pid) do
    _ = System.cmd("/bin/kill", ["-TERM", "--", "-#{os_pid}"], stderr_to_stdout: true)

    if group_alive?(os_pid) do
      Process.sleep(@grace_ms)
      _ = System.cmd("/bin/kill", ["-KILL", "--", "-#{os_pid}"], stderr_to_stdout: true)
    end

    :ok
  end

  defp group_alive?(os_pid) do
    match?({_, 0}, System.cmd("/bin/kill", ["-0", "--", "-#{os_pid}"], stderr_to_stdout: true))
  end

  # ------------------------------------------------------------------
  # Provenance
  # ------------------------------------------------------------------

  defp toolchain(suite, worktree, tmp) do
    suite
    |> Map.get(:toolchain, [])
    |> Enum.map(fn argv ->
      case spawn_and_collect(argv, suite, worktree, tmp, 10_000, 512) do
        {:exit, 0, out} -> {Enum.join(argv, " "), String.trim(out)}
        _ -> {Enum.join(argv, " "), "unavailable"}
      end
    end)
    |> Map.new()
  end

  @doc """
  The `argv_sha256` a verification (and its court receipt binding) records
  for `suite`: lowercase hex sha256 over the JSON of each step's `:id`,
  `:argv`, `:timeout_ms` and `:receipt_argv`. Environment, toolchain probes
  and output limits are not part of it. Public so a court can check that a
  receipt's replay command is the command the declaration that produced its
  evidence runs (`Xaas.Receipt.RProjection.consistency/2`).
  """
  @spec argv_digest(map()) :: String.t()
  def argv_digest(suite) do
    suite.steps
    |> Enum.map(&Map.take(&1, [:id, :argv, :timeout_ms, :receipt_argv]))
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp make_tmp(epoch_id) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-verifier-#{epoch_id}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end

  # The registry is environment config plus, when the environment opts in via
  # `:ultracode_target_suites`, the code-declared suites for non-APS targets
  # (see `Xaas.Ultracode.TargetSuites`). The config value is the module itself
  # -- a bare atom at config-evaluation time -- so it is resolved HERE, at
  # runtime, never while loading config. Unresolvable module = registry stays
  # as configured (fail closed, no invented suites).
  defp suites do
    # `|| %{}` is the permanent tripwire for the env-restore poison class:
    # restoring this key with `Application.put_env/2` and a nil value SETS
    # a literal nil, and get_env/3 then returns nil instead of this default
    # -- which used to crash the maps.merge/2 below (the seed-dependent
    # TargetSuitesTest flake). An unset OR nil'd registry means "no suites
    # configured", never a crash.
    base = Application.get_env(:xaas, :ultracode_verifier_suites, %{}) || %{}

    case Application.get_env(:xaas, :ultracode_target_suites, nil) do
      module when is_atom(module) and not is_nil(module) ->
        case Code.ensure_loaded(module) do
          {:module, _} -> Map.merge(base, module.devs())
          {:error, _} -> base
        end

      _ ->
        base
    end
  end
end
