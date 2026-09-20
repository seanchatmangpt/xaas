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

  ## Result

  `run/2` always returns `{:ok, result}`; `result["status"]` is one of
  `"pass" | "fail" | "timeout" | "error"`. `Lease.close/4` maps pass to the
  claimed outcome, fail to `:build_broken`, timeout/error to `:partial_alive`.
  """

  require Logger

  @grace_ms 2_000
  @default_max_output 65_536
  @placeholders ~w({worktree} {head} {run_id} {epoch_id} {executor} {ticket} {verifier_id} {tmpdir})

  @type ctx :: %{
          required(:worktree) => String.t(),
          required(:head) => String.t(),
          required(:run_id) => String.t(),
          required(:epoch_id) => String.t(),
          optional(:executor) => String.t() | nil
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
         :ok <- tree_clean(worktree, :before) do
      tmp = make_tmp(ctx.epoch_id)

      try do
        steps = run_steps(suite, ctx, worktree, tmp)
        status = steps |> Enum.map(& &1["status"]) |> worst_status()

        base =
          base |> Map.put("steps", steps) |> Map.put("toolchain", toolchain(suite, worktree, tmp))

        base = maybe_put_receipt(base, suite, steps)

        case {status, head_is(worktree, ctx.head, :after), tree_clean(worktree, :after)} do
          {:pass, :ok, :ok} -> finish(base, :pass, nil)
          {:pass, {:error, reason}, _} -> finish(base, :error, reason)
          {:pass, _, {:error, reason}} -> finish(base, :error, reason)
          {status, _, _} -> finish(base, status, first_failure(steps))
        end
      after
        File.rm_rf(tmp)
      end
    else
      {:error, {:worker_left_uncommitted_changes, _} = reason} -> finish(base, :fail, reason)
      {:error, reason} -> finish(base, :error, reason)
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

  defp maybe_put_receipt(base, suite, steps) do
    with %{id: id} <- Enum.find(suite.steps, &Map.get(&1, :receipt, false)),
         %{"output_tail" => tail} <- Enum.find(steps, &(&1["id"] == to_string(id))),
         line when is_binary(line) <- last_line(tail),
         {:ok, %{} = receipt} <- Jason.decode(line),
         true <- byte_size(line) <= 32_768 do
      Map.put(base, "court_receipt", receipt)
    else
      _ -> base
    end
  end

  defp last_line(tail) do
    tail |> String.split("\n", trim: true) |> List.last()
  end

  # ------------------------------------------------------------------
  # Containment and repository state
  # ------------------------------------------------------------------

  defp contained_worktree(nil), do: {:error, "no_worktree"}

  defp contained_worktree(worktree) do
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

  defp run_steps(suite, ctx, worktree, tmp) do
    subst = substitutions(ctx, worktree, tmp)

    Enum.reduce_while(suite.steps, [], fn step, acc ->
      result = run_step(step, suite, subst, worktree, tmp)
      acc = acc ++ [result]
      if result["status"] == "pass", do: {:cont, acc}, else: {:halt, acc}
    end)
  end

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

  defp spawn_and_collect(argv, suite, worktree, tmp, timeout_ms, max_out) do
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

    {:os_pid, os_pid} = Port.info(port, :os_pid)
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

  defp argv_digest(suite) do
    suite.steps
    |> Enum.map(&Map.take(&1, [:id, :argv, :timeout_ms]))
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
