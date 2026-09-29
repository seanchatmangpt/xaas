defmodule Xaas.Ultracode.SuiteHealth do
  @moduledoc """
  The suite health court: drift detection for the verifier itself, with
  automatic quarantine and automatic release. No human unquarantines.

  A verifier suite is only worth trusting while it still (a) passes a tree
  known to be green and (b) FAILS a tree known to be red. A suite that fails
  green has drifted (toolchain, dependency, environment) and would reject good
  work; a suite that passes red is vacuous and would accept anything. This
  court measures both, on demand or on a schedule, and turns the measurement
  into admission state:

      suite declares  health: %{green_ref: ..., red_ref: ... | red_mutation: ...}
        -> `check/2` runs the suite (real `Xaas.Ultracode.Verifier.run/2`, so
           containment, `env -i`, process-group kill and clean-tree law all
           apply) against a scratch clone at the green ref and another at the
           red fixture
        -> a sealed receipt is recorded (`receipt_digest` binds every field)
        -> `status/3` derives admission from the LATEST receipt only

  ## Declaration

      health: %{
        repo: "/abs/clone",            # optional: default = the registered repo whose
                                       # suite/canonical_suite is this suite (Xaas.Ultracode.Repos)
        green_ref: "refs/tags/dod-green",
        red_ref: "refs/tags/dod-red",  # EITHER a known-red ref ...
        red_mutation: %{kind: "replace", file: "answer.txt", pattern: "42", replacement: "41"},
                                       # ... OR a mutation (Xaas.Ultracode.Probes) applied on
                                       # top of the green ref and committed in the scratch clone
        max_age_seconds: 86_400        # optional, default 86_400
      }

  A suite WITHOUT a `health` declaration is `:unmanaged`: never quarantined,
  and listed as such by `mix xaas.ultracode.suite_health` so the gap is
  visible rather than silently trusted.

  ## Quarantine law (`status/3`, `admission/3`)

  A managed suite is quarantined -- Run admission refuses it with
  `suite_unhealthy` (`Xaas.Ultracode.Validations.VerifierSuiteRegistered`) and
  `Verifier.run/2` refuses it with typed `suite_unhealthy` -- unless the latest
  receipt is present, intact (digest recomputes), `verdict == "healthy"`,
  bound to the suite's CURRENT steps/env/declaration digest, and younger than
  `max_age_seconds`. Everything else fails closed:

    * `:never_checked`, `:health_store_unconfigured`, `:receipt_unreadable`,
      `:receipt_digest_mismatch`
    * `:suite_changed_since_check` (the suite or its declaration was edited)
    * `:stale`, `:receipt_from_future`
    * `{:unhealthy, verdict}` -- `green_failed | vacuous | inconclusive | blocked`

  The only exit from quarantine is a new healthy receipt written by `check/2`
  (`sweep/1` re-checks every quarantined or soon-stale suite, and
  `Xaas.Ultracode.Autonomic` sweeps before every wave), so a recovered suite
  releases itself and a drifted one stops the loop by itself.

  ## Store

  `config :xaas, :ultracode_suite_health_dir` -- one `<suite>.json` (the latest
  receipt, written atomically) plus an append-only `history.ndjson`. Unset =
  every managed suite is quarantined (`:health_store_unconfigured`).
  """

  alias Xaas.Ultracode.{Probes, Repos, SemanticReceipt, Verifier}

  @schema "xaas.suite_health_receipt/1"
  @default_max_age 86_400
  @future_skew 300
  @name_re ~r/\A[A-Za-z0-9._-]{1,80}\z/
  @ref_re ~r/\A[A-Za-z0-9][A-Za-z0-9._\/~^@{}-]{0,199}\z/
  @executor "xaas-suite-health-court"

  @type quarantine_reason :: atom() | {:unhealthy, String.t()}
  @type status :: :unmanaged | :healthy | {:quarantined, quarantine_reason()}

  # ------------------------------------------------------------------
  # Declaration
  # ------------------------------------------------------------------

  @doc "True when the suite declares a `health` block."
  @spec managed?(map()) :: boolean()
  def managed?(suite) when is_map(suite), do: Map.has_key?(suite, :health)
  def managed?(_), do: false

  @doc "Registration-time problem strings for `Xaas.Ultracode.TargetSuites.validate/1`."
  @spec declaration_problems(term()) :: [String.t()]
  def declaration_problems(health) when is_map(health) do
    red_ref? = Map.has_key?(health, :red_ref)
    red_mut? = Map.has_key?(health, :red_mutation)

    [
      ref_problem(:green_ref, health),
      if(red_ref? == red_mut?,
        do: ["health needs exactly one of red_ref or red_mutation"],
        else: []
      ),
      if(red_ref?, do: ref_problem(:red_ref, health), else: []),
      if(red_mut?, do: mutation_problems(health[:red_mutation]), else: []),
      case Map.get(health, :repo) do
        nil ->
          []

        repo when is_binary(repo) ->
          if Path.type(repo) == :absolute, do: [], else: ["health repo must be an absolute path"]

        _ ->
          ["health repo must be an absolute path"]
      end,
      case Map.get(health, :max_age_seconds) do
        nil -> []
        n when is_integer(n) and n > 0 -> []
        other -> ["health max_age_seconds must be a positive integer, got #{inspect(other)}"]
      end
    ]
    |> List.flatten()
  end

  def declaration_problems(_), do: ["health must be a map"]

  defp ref_problem(key, health) do
    case Map.get(health, key) do
      ref when is_binary(ref) ->
        if Regex.match?(@ref_re, ref),
          do: [],
          else: ["health #{key} is not a safe ref: #{inspect(ref)}"]

      _ ->
        ["health #{key} is required"]
    end
  end

  defp mutation_problems(mutation) when is_map(mutation) do
    Probes.problems([Map.put_new(mutation, :id, "health-red")])
  end

  defp mutation_problems(_), do: ["health red_mutation must be a probe map"]

  # ------------------------------------------------------------------
  # Admission state
  # ------------------------------------------------------------------

  @doc """
  `:ok` when a Run may name the suite, `{:quarantined, reason}` when the
  court has quarantined it. Unmanaged suites are always `:ok`.
  """
  @spec admission(String.t(), map(), keyword()) :: :ok | {:quarantined, quarantine_reason()}
  def admission(name, suite, opts \\ []) do
    case status(name, suite, opts) do
      {:quarantined, _} = quarantined -> quarantined
      _ -> :ok
    end
  end

  @doc """
  The suite's health status from the LATEST recorded receipt. `opts[:now]`
  (unix seconds) pins the reference time; default is the real clock.
  """
  @spec status(String.t(), map(), keyword()) :: status()
  def status(name, suite, opts \\ []) do
    if managed?(suite) do
      now = Keyword.get(opts, :now) || System.os_time(:second)

      case latest(name) do
        {:ok, receipt} -> judge(receipt, suite, now)
        {:error, reason} -> {:quarantined, reason}
      end
    else
      :unmanaged
    end
  end

  defp judge(receipt, suite, now) do
    max_age = get_in(suite, [:health, :max_age_seconds]) || @default_max_age
    checked_at = receipt["checked_at"]

    cond do
      receipt["binding"] != suite_binding(suite) ->
        {:quarantined, :suite_changed_since_check}

      not is_integer(checked_at) ->
        {:quarantined, :receipt_unreadable}

      checked_at > now + @future_skew ->
        {:quarantined, :receipt_from_future}

      now - checked_at > max_age ->
        {:quarantined, :stale}

      receipt["verdict"] != "healthy" ->
        {:quarantined, {:unhealthy, to_string(receipt["verdict"])}}

      true ->
        :healthy
    end
  end

  @doc """
  Digest binding a receipt to the suite it measured: the step argv/timeouts,
  the env allowlist, the probes and the health declaration. Editing any of
  them invalidates the standing receipt.
  """
  @spec suite_binding(map()) :: String.t()
  def suite_binding(suite) do
    SemanticReceipt.digest(%{
      "steps" => Verifier.suite_digest(suite),
      "env" => Map.get(suite, :env, %{}),
      "health" => Map.get(suite, :health, %{})
    })
  end

  # ------------------------------------------------------------------
  # Store
  # ------------------------------------------------------------------

  @doc "The configured store directory, or nil."
  @spec store_dir() :: String.t() | nil
  def store_dir do
    case Application.get_env(:xaas, :ultracode_suite_health_dir) do
      dir when is_binary(dir) and dir != "" -> dir
      _ -> nil
    end
  end

  @doc "The latest recorded receipt for `name`, integrity-checked."
  @spec latest(String.t()) :: {:ok, map()} | {:error, atom()}
  def latest(name) do
    with {:ok, dir} <- fetch_dir(),
         {:ok, file} <- receipt_file(dir, name),
         {:ok, raw} <- read_receipt(file),
         {:ok, receipt} <- decode(raw),
         :ok <- intact(receipt) do
      {:ok, receipt}
    end
  end

  defp fetch_dir do
    case store_dir() do
      nil -> {:error, :health_store_unconfigured}
      dir -> {:ok, dir}
    end
  end

  defp receipt_file(dir, name) do
    if is_binary(name) and Regex.match?(@name_re, name),
      do: {:ok, Path.join(dir, name <> ".json")},
      else: {:error, :unsafe_suite_name}
  end

  defp read_receipt(file) do
    case File.read(file) do
      {:ok, raw} -> {:ok, raw}
      {:error, :enoent} -> {:error, :never_checked}
      {:error, _} -> {:error, :receipt_unreadable}
    end
  end

  defp decode(raw) do
    case Jason.decode(raw) do
      {:ok, %{} = receipt} -> {:ok, receipt}
      _ -> {:error, :receipt_unreadable}
    end
  end

  defp intact(%{"receipt_digest" => digest} = receipt) when is_binary(digest) do
    if SemanticReceipt.digest(Map.delete(receipt, "receipt_digest")) == digest,
      do: :ok,
      else: {:error, :receipt_digest_mismatch}
  end

  defp intact(_), do: {:error, :receipt_digest_mismatch}

  @doc """
  Records a receipt as the suite's latest (atomic rename) and appends it to
  the history. `{:error, :health_store_unconfigured}` without a store.
  """
  @spec record(map()) :: :ok | {:error, term()}
  def record(%{"suite" => name} = receipt) do
    with {:ok, dir} <- fetch_dir(),
         {:ok, file} <- receipt_file(dir, name),
         :ok <- File.mkdir_p(dir) do
      json = Jason.encode!(receipt)
      tmp = file <> ".tmp-#{System.unique_integer([:positive])}"

      with :ok <- File.write(tmp, json),
           :ok <- File.rename(tmp, file),
           :ok <- File.write(Path.join(dir, "history.ndjson"), json <> "\n", [:append]) do
        :ok
      else
        {:error, _} = error ->
          File.rm(tmp)
          error
      end
    end
  end

  # ------------------------------------------------------------------
  # The court
  # ------------------------------------------------------------------

  @doc """
  Runs the court for one registered, managed suite and records the receipt.
  Always returns the receipt: a court that could not run (no worktree root,
  unresolvable repo/ref, clone failure) yields `verdict: "blocked"` -- a
  recorded, quarantining verdict, never a silent pass.

  Options: `:now` (unix seconds, default real clock), `:record` (default true).
  """
  @spec check(String.t(), keyword()) ::
          {:ok, map()} | {:error, :unknown_suite | :unmanaged | :busy}
  def check(name, opts \\ []) do
    with {:ok, suite} <- fetch_suite(name),
         :ok <- if(managed?(suite), do: :ok, else: {:error, :unmanaged}) do
      :global.trans({{__MODULE__, name}, self()}, fn -> court(name, suite, opts) end, [node()], 0)
      |> case do
        :aborted -> {:error, :busy}
        receipt -> {:ok, receipt}
      end
    end
  end

  defp fetch_suite(name) do
    case Verifier.suite(name) do
      {:ok, suite} -> {:ok, suite}
      :error -> {:error, :unknown_suite}
    end
  end

  defp court(name, suite, opts) do
    now = Keyword.get(opts, :now) || System.os_time(:second)
    health = suite.health

    {green, red, verdict, reason} =
      case run_fixtures(name, health) do
        {:ok, green, red} -> classify(green, red)
        {:blocked, reason, green, red} -> {green, red, "blocked", reason}
      end

    body = %{
      "schema" => @schema,
      "suite" => name,
      "verdict" => verdict,
      "healthy" => verdict == "healthy",
      "reason" => reason,
      "checked_at" => now,
      "checked_at_iso" => now |> DateTime.from_unix!() |> DateTime.to_iso8601(),
      "max_age_seconds" => health[:max_age_seconds] || @default_max_age,
      "binding" => suite_binding(suite),
      "suite_argv_sha256" => Verifier.suite_digest(suite),
      "green" => green,
      "red" => red,
      "verifier_id" => "xaas-ultracode-verifier/#{Application.spec(:xaas, :vsn)}"
    }

    receipt = Map.put(body, "receipt_digest", SemanticReceipt.digest(body))
    if Keyword.get(opts, :record, true), do: record(receipt)
    receipt
  end

  # green must pass and red must fail; every other pairing quarantines, with
  # the more dangerous condition (a suite that passes known-red = vacuous)
  # named first.
  defp classify(green, red) do
    cond do
      red["status"] == "pass" ->
        {green, red, "vacuous", "suite passed the known-red fixture"}

      green["status"] != "pass" ->
        {green, red, "green_failed",
         "suite did not pass the known-green fixture: #{green["status"]}"}

      red["status"] == "fail" ->
        {green, red, "healthy", nil}

      true ->
        {green, red, "inconclusive", "known-red fixture was unverifiable: #{red["status"]}"}
    end
  end

  defp run_fixtures(name, health) do
    with {:ok, root} <- worktree_root(),
         {:ok, repo} <- resolve_repo(name, health),
         {:ok, green_sha} <- resolve_ref(repo, health.green_ref),
         {:ok, red_plan} <- red_plan(repo, health) do
      base = Path.join(root, "health-#{name}-#{System.unique_integer([:positive])}")
      green = fixture(name, repo, green_sha, health.green_ref, base <> "-green", nil)
      red = red_fixture(name, repo, green_sha, red_plan, base <> "-red")
      {:ok, green, red}
    else
      {:error, reason} ->
        {:blocked, inspect(reason), %{"status" => "blocked"}, %{"status" => "blocked"}}
    end
  end

  defp red_plan(repo, %{red_ref: ref}) do
    with {:ok, sha} <- resolve_ref(repo, ref), do: {:ok, {:ref, ref, sha}}
  end

  defp red_plan(_repo, %{red_mutation: mutation}) do
    with {:ok, [probe]} <- Probes.admit([Map.put_new(mutation, :id, "health-red")]),
         do: {:ok, {:mutation, probe}}
  end

  defp red_fixture(name, repo, _green_sha, {:ref, ref, sha}, dest),
    do: fixture(name, repo, sha, ref, dest, nil)

  defp red_fixture(name, repo, green_sha, {:mutation, probe}, dest),
    do: fixture(name, repo, green_sha, "green+" <> probe.id, dest, probe)

  # One fixture run: scratch clone at `sha` (optionally mutated and committed),
  # then the REAL verifier against it. Court runs bypass quarantine and probes.
  defp fixture(name, repo, sha, ref, dest, mutation) do
    record = %{"ref" => ref, "sha" => sha}

    try do
      with {:ok, clone} <- Probes.scratch_clone(repo, sha, dest),
           {:ok, head} <- materialize(clone, sha, mutation) do
        {:ok, result} =
          Verifier.run(name, %{
            worktree: clone,
            head: head,
            run_id: Ecto.UUID.generate(),
            epoch_id: Ecto.UUID.generate(),
            executor: @executor,
            health_check: true
          })

        record
        |> Map.put("sha", head)
        |> Map.put("status", result["status"])
        |> Map.put("reason", result["reason"])
        |> Map.put(
          "steps",
          Enum.map(result["steps"] || [], &Map.take(&1, ["id", "status", "exit"]))
        )
      else
        {:error, reason} ->
          Map.merge(record, %{"status" => "blocked", "reason" => inspect(reason)})
      end
    after
      File.rm_rf(dest)
    end
  end

  defp materialize(clone, _sha, nil), do: head_of(clone)

  defp materialize(clone, _sha, probe) do
    with :ok <- Probes.apply_probe(probe, clone),
         {_, 0} <- git(clone, ["add", "-A"]),
         {_, 0} <-
           git(clone, ["commit", "--quiet", "--no-gpg-sign", "-m", "suite-health red fixture"]) do
      head_of(clone)
    else
      {:error, _} = error ->
        error

      {out, code} ->
        {:error, {:red_commit_failed, code, String.slice(String.trim(out), -200, 200)}}
    end
  end

  defp head_of(clone) do
    case git(clone, ["rev-parse", "HEAD"]) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, code} -> {:error, {:head_unreadable, code, String.trim(out)}}
    end
  end

  defp resolve_ref(repo, ref) do
    with :ok <- if(Regex.match?(@ref_re, ref), do: :ok, else: {:error, :unsafe_ref}) do
      case git(repo, ["rev-parse", "--verify", "--quiet", "--end-of-options", ref <> "^{commit}"]) do
        {out, 0} -> {:ok, String.trim(out)}
        _ -> {:error, {:ref_unresolvable, ref}}
      end
    end
  end

  defp resolve_repo(_name, %{repo: repo}) when is_binary(repo), do: {:ok, repo}

  defp resolve_repo(name, _health) do
    {results, _warnings} = Repos.entries()

    results
    |> Enum.find_value(fn
      {_alias, {:ok, entry}} when entry.suite == name or entry.canonical_suite == name ->
        entry.path

      _ ->
        nil
    end)
    |> case do
      nil -> {:error, :health_repo_unresolved}
      path -> {:ok, path}
    end
  end

  defp worktree_root do
    case Application.get_env(:xaas, :ultracode_worktree_root) do
      root when is_binary(root) and root != "" -> {:ok, root}
      _ -> {:error, :worktree_root_unconfigured}
    end
  end

  defp git(dir, args) do
    System.cmd("git", ["-C", dir | args],
      stderr_to_stdout: true,
      env: [
        {"GIT_TERMINAL_PROMPT", "0"},
        {"GIT_AUTHOR_NAME", "xaas-suite-health"},
        {"GIT_AUTHOR_EMAIL", "health@xaas.local"},
        {"GIT_COMMITTER_NAME", "xaas-suite-health"},
        {"GIT_COMMITTER_EMAIL", "health@xaas.local"}
      ]
    )
  end

  # ------------------------------------------------------------------
  # Sweep (the periodic half)
  # ------------------------------------------------------------------

  @doc """
  Re-checks every managed suite that is quarantined or past half its
  `max_age_seconds` (`force: true` = all managed suites), so a healthy suite
  is refreshed BEFORE it goes stale and a recovered one releases itself.
  Options: `:suites` (names; default every registered suite), `:force`,
  `:now`. Returns one row per suite:

      %{suite: name, action: :checked | :fresh | :unmanaged | :busy | :unknown,
        status: status(), verdict: String.t() | nil}
  """
  @spec sweep(keyword()) :: [map()]
  def sweep(opts \\ []) do
    now = Keyword.get(opts, :now) || System.os_time(:second)
    names = Keyword.get(opts, :suites) || Verifier.suite_names()

    names
    |> Enum.uniq()
    |> Enum.map(fn name ->
      case fetch_suite(name) do
        {:error, _} ->
          %{suite: name, action: :unknown, status: {:quarantined, :unknown_suite}, verdict: nil}

        {:ok, suite} ->
          cond do
            not managed?(suite) ->
              %{suite: name, action: :unmanaged, status: :unmanaged, verdict: nil}

            Keyword.get(opts, :force, false) or due?(name, suite, now) ->
              case check(name, now: now) do
                {:ok, receipt} ->
                  %{
                    suite: name,
                    action: :checked,
                    status: status(name, suite, now: now),
                    verdict: receipt["verdict"]
                  }

                {:error, :busy} ->
                  %{
                    suite: name,
                    action: :busy,
                    status: status(name, suite, now: now),
                    verdict: nil
                  }
              end

            true ->
              %{suite: name, action: :fresh, status: status(name, suite, now: now), verdict: nil}
          end
      end
    end)
  end

  # Due = quarantined for any reason, or a healthy receipt past half its life.
  defp due?(name, suite, now) do
    case status(name, suite, now: now) do
      :healthy ->
        max_age = get_in(suite, [:health, :max_age_seconds]) || @default_max_age

        case latest(name) do
          {:ok, %{"checked_at" => checked_at}} -> now - checked_at >= div(max_age, 2)
          _ -> true
        end

      _ ->
        true
    end
  end
end
