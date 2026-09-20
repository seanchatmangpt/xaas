defmodule Xaas.Ultracode.Dispatch do
  @moduledoc """
  The in-family dispatch boundary: launches ONE real worker agent process
  for an `Epoch` and returns what actually happened, typed.

  This finishes the seam `Xaas.Ultracode.Autonomic`'s default worker used to
  cover by shelling out to `scripts/xaas-glm-failover-dispatcher.sh` in its
  directed `--epoch` mode: everything that script did for one dispatch
  (epoch-readiness check, scratch-cwd reap mode, worker-id attribution,
  `XAAS_WORKER=1`/`XAAS_LEASE_CWD` gate env, hard timeout, rate-limit
  classification, full-output log) now happens here, in the same BEAM
  process family that owns `Lease`, `Receipt` and `Autonomic`. The bash
  script remains for its standing `--once`/`--interval` polling modes, which
  this module deliberately does not duplicate (`Autonomic` already owns
  loop, pacing, and reaping).

  What one `dispatch/2` call does:

    1. Re-reads the Epoch (`:read_unscoped`) and refuses -- typed, never a
       crash -- unless it is `:running`, unleased (or lease-expired), and
       of the expected provider. An epoch that is not ready is not
       dispatched into.
    2. Picks the cwd: the epoch's worktree when it exists (`:claim` mode),
       otherwise a fresh scratch dir (`:reap` mode) -- the worker can then
       claim and refuse the epoch through the fabric, unblocking the queue
       head, exactly like the bash script's reap path. The scratch dir is
       removed when the dispatch ends.
    3. Builds the canonical gated worker invocation (byte-identical prompt
       shape to the bash script's): `<node> bin/zcode.js --prompt "/xaas
       Call claim_next with provider_worker_id exactly <worker_id> and
       epoch_id exactly <epoch_id>; do not use any other values." --cwd
       <cwd> --json`, run with cwd = the zcode CLI dir and
       `XAAS_WORKER=1` + `XAAS_LEASE_CWD=<real cwd>` added to the child
       env -- the two variables that arm the xaas-fabric plugin's
       PreToolUse gate (host-enforced admit_tool, worktree-confined
       writes, Bash allowlist). No goal text is ever placed on the command
       line: the worker reads the goal from the lease payload after it
       claims, so untrusted customer content never touches this argv.
       The worker id is constructed here (not left to the model to infer)
       because zcode session memory has been observed resurrecting a stale
       session id and mis-attributing every lease to it.
    4. Runs it under a hard double timeout: the process leads its own
       process group with a SIGALRM backstop, and the BEAM-side deadline
       kills the whole group (same mechanics as `Xaas.Ultracode.Verifier`),
       so no grandchild outlives the deadline. The wrapper supervises the
       turn and records its true exit code, so completion is observed even
       when a leftover pipe-holding child would otherwise stall the port,
       and the group is reaped on every exit path -- not only on timeout.
    5. Classifies the outcome: `:ok` (exit 0), `:rate_limited`
       (failover-class provider error in the output -- the exact patterns
       the bash dispatcher greps for), `:timeout`, or `:failed` (any other
       exit). Full output streams to a log file; a bounded tail is kept in
       the result.
    6. **Failover rule** (learned from the 2026-09-18 GLM failover trials,
       see `docs/ultracode/FAILOVER-RUNBOOK.md` and the trial receipts
       under `docs/ultracode/wave-v26.9.17-receipts/failover-trial-evidence/`):
       a failover-class outcome is retried exactly ONCE inside this
       boundary (`:failover_retries`, default 1, after `:failover_backoff_ms`)
       so one transient provider-rate blip costs the wave cycle a backoff,
       not an attempt. `Autonomic`'s own rate handling (halve + retry
       without spending an attempt) still applies if the retry also comes
       back rate-limited.
    7. Attaches the epoch's sealed `Xaas.Ultracode.Receipt` rows and its
       current state to the result, so the caller gets exit AND receipt in
       one value. Closing remains the worker's own job through the lease
       protocol (`Lease.close/4` via the fabric MCP surface); this module
       never seals on the worker's behalf.

  `plan/2` is the dry-run half: identical construction, zero execution.
  It exists so callers and tests can prove everything about a dispatch
  except the final exec -- the honest shape of a `PARTIAL_ALIVE` dispatch
  claim.

  ## Failure posture (fail-closed)

    * epoch not ready → `{:error, {:epoch_not_ready, epoch_id, detail}}`
    * CLI dir / `bin/zcode.js` missing → `{:error, {:cli_unavailable, path}}`
    * node executable not resolvable → `{:error, {:node_unavailable, "node"}}`
    * log file not writable → `{:error, {:log_unavailable, path}}`
    * spawn failure → `{:error, {:spawn_failed, message}}`
    * timeout → the whole process group is killed and the result status is
      `:timeout`, never a hang

  This is not an OS sandbox. The worker runs with this node's inherited
  environment (the bash dispatcher did the same) and is bounded by the
  plugin's host-side gate plus the server-side `Lease.admit_tool/2` fence,
  not by this module. `:extra_env` adds explicit, caller-supplied
  assignments on top of the inherited environment (used by tests to script
  the CLI and by operators to pin per-dispatch variables).
  """

  require Logger

  alias Xaas.Ultracode.{Epoch, Receipt}

  # Keep below the run default `epoch_timeout_seconds` (900), same bound the
  # bash dispatcher documents: the lease clock is the provider's to spend,
  # but a hung turn must be killed before the fabric itself times out.
  @default_timeout_seconds 840
  @default_failover_retries 1
  @default_failover_backoff_ms 15_000
  @default_max_output_bytes 65_536
  @default_cli_dir "/Users/sac/dev/zcode-cli"
  @grace_ms 2_000
  @kill_confirm_ms 1_000
  @alarm_grace_s 2
  @poll_interval_ms 250

  # Failover-class provider errors. Verbatim from
  # scripts/xaas-glm-failover-dispatcher.sh's classification grep -- the
  # 2026-09-18 5-worker trial's observed Z.AI rate/refusal signatures -- with
  # one hardening: the 1302 branch is whitespace-tolerant, because
  # `{"code":1302}` and `{"code": 1302}` are the same JSON document and a
  # classifier must not depend on the provider's serialization (the 429
  # branch already was, via [": ]+). Caught by the tripwire suite.
  @failover_regex ~r/"code"\s*:\s*"?1302|HTTP 429|status(Code)?[": ]+429|Too Many Requests|High concurrency usage/

  # The wrapper SUPERVISES the worker turn instead of exec'ing into it: after
  # the turn ends it records the true exit code to the code file (argv slot
  # after the alarm seconds) and exits. Why not exec: a worker that exits 0
  # leaving a background child keeps the port's stdout/stderr write ends
  # open, and a port whose pipe is still held never delivers
  # `{:exit_status, _}` -- observed 2026-09-20 as a clean 0-exit turn
  # misclassified :timeout at full deadline. The record lets `collect/7`
  # finish the attempt when the turn actually ends, reap the leftover group,
  # and classify with the real code. The alarm backstop now terminates the
  # wrapper (not the worker directly); a group the BEAM deadline cannot
  # reach is still reaped through it, and an unwritten code file degrades to
  # the historical `exec ... or exit 127` semantics.
  @wrapper """
  setpgrp(0,0);
  alarm(shift @ARGV);
  my $code_file = shift @ARGV;
  my $rc = system(@ARGV);
  my $code = $rc == -1 ? 127 : ($rc & 127) ? 128 + ($rc & 127) : $rc >> 8;
  if (open my $fh, '>', $code_file) { print {$fh} $code; close $fh; }
  exit($code > 255 ? 255 : $code);
  """

  @type status :: :ok | :rate_limited | :timeout | :failed

  @type result :: %{
          required(:status) => status(),
          required(:epoch_id) => String.t(),
          required(:worker_id) => String.t(),
          required(:mode) => :claim | :reap,
          required(:attempts) => pos_integer(),
          required(:exit_code) => non_neg_integer() | nil,
          required(:duration_ms) => non_neg_integer(),
          required(:output_tail) => String.t(),
          required(:log_path) => String.t(),
          required(:prompt) => String.t(),
          required(:epoch_state) => atom(),
          required(:receipts) => [map()]
        }

  @doc """
  Dispatches ONE real worker agent for `epoch_or_id` (an `Epoch` struct or
  an epoch UUID).

  Options:

    * `:timeout_seconds` (default #{@default_timeout_seconds}) -- hard
      deadline for the whole agent turn, killed process-group-wide
    * `:provider` (default `"zcode"`) -- the epoch's Run must be this
      provider's, else `{:error, {:epoch_not_ready, ...}}`
    * `:cli_dir` (config `:xaas, :ultracode_dispatch_cli_dir`) -- the zcode
      CLI checkout holding `bin/zcode.js`
    * `:node_path` (config `:xaas, :ultracode_dispatch_node_path`) -- the
      node executable; defaults to `System.find_executable("node")`
    * `:failover_retries` (default #{@default_failover_retries}) -- extra
      attempts on a failover-class outcome, beyond the first
    * `:failover_backoff_ms` (default #{@default_failover_backoff_ms})
    * `:log_path` -- full-output log file; defaults to a per-dispatch file
      under the OS temp dir
    * `:extra_env` -- map of additional child-env assignments
    * `:dry_run` -- true builds and returns the plan without executing
      (same as `plan/2`)

  Returns `{:ok, result}` (or `{:ok, plan}` when dry) or a typed
  `{:error, term()}`.
  """
  @spec dispatch(Epoch.t() | String.t(), keyword()) :: {:ok, result() | map()} | {:error, term()}
  def dispatch(epoch_or_id, opts \\ []) do
    if Keyword.get(opts, :dry_run, false) do
      plan(epoch_or_id, opts)
    else
      execute(epoch_or_id, opts)
    end
  end

  @doc """
  The dry-run half of `dispatch/2`: identical construction, zero
  execution. Returns `{:ok, plan}` where `plan` carries the exact argv,
  added env, cwd, prompt, worker id, mode, log path, and timeout a real
  dispatch would use.
  """
  @spec plan(Epoch.t() | String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def plan(epoch_or_id, opts \\ []) do
    with {:ok, resolved} <- resolve_opts(opts),
         {:ok, epoch} <- ready_epoch(epoch_or_id, resolved) do
      {:ok, built} = build(epoch, resolved)
      {:ok, Map.merge(built, %{dry_run: true})}
    end
  end

  @doc """
  The `Autonomic` worker contract adapter: `(epoch, ctx) -> :ok |
  :rate_limited | {:error, reason}`. Dispatch options are read from
  `ctx[:dispatch_opts]`. This is the wave cycle's default worker.
  """
  @spec autonomic_worker(Epoch.t(), map()) :: :ok | :rate_limited | {:error, term()}
  def autonomic_worker(%Epoch{} = epoch, ctx) do
    dispatch(epoch, Map.get(ctx, :dispatch_opts, []))
    |> case do
      {:ok, %{status: :ok}} ->
        :ok

      {:ok, %{status: :rate_limited}} ->
        :rate_limited

      {:ok, %{status: :timeout, output_tail: tail}} ->
        {:error, {:dispatch_timeout, tail}}

      {:ok, %{status: :failed, exit_code: code, output_tail: tail}} ->
        {:error, {:dispatch_failed, code, tail}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ------------------------------------------------------------------
  # Execution
  # ------------------------------------------------------------------

  defp execute(epoch_or_id, opts) do
    started = System.monotonic_time(:millisecond)

    with {:ok, resolved} <- resolve_opts(opts),
         {:ok, epoch} <- ready_epoch(epoch_or_id, resolved),
         {:ok, built} <- build(epoch, resolved),
         {:ok, log} <- open_log(built.log_path) do
      built = Map.put(built, :log, log)
      max_retries = resolved.failover_retries

      outcome = attempt_loop(built, resolved, 1, max_retries)
      duration = System.monotonic_time(:millisecond) - started

      File.close(built.log)

      # Reap-mode scratch cwd: best-effort removal, it was ours.
      if built.mode == :reap, do: File.rmdir(built.cwd)

      case outcome do
        {:spawn_error, message} ->
          {:error, {:spawn_failed, message}}

        {status, attempts, exit_code, tail} ->
          result = %{
            status: status,
            epoch_id: epoch.id,
            worker_id: built.worker_id,
            mode: built.mode,
            attempts: attempts,
            exit_code: exit_code,
            duration_ms: duration,
            output_tail: String.replace_invalid(tail, "?"),
            log_path: built.log_path,
            prompt: built.prompt,
            epoch_state: current_epoch_state(epoch.id),
            receipts: sealed_receipts(epoch.id)
          }

          Logger.info(
            "[ultracode] dispatch epoch=#{epoch.id} status=#{status} " <>
              "attempts=#{attempts} exit=#{inspect(exit_code)} duration_ms=#{duration}"
          )

          {:ok, result}
      end
    end
  rescue
    error -> {:error, {:dispatch_crashed, Exception.message(error)}}
  end

  # One real subprocess per attempt; classification decides whether the
  # failover rule earns it another. Terminal values are the classified
  # {status, attempts, exit, tail} tuple or a {:spawn_error, message} that
  # surfaces as a typed refusal (a boundary defect, not a provider
  # transient -- never retried).
  defp attempt_loop(built, resolved, attempt, retries_left) do
    outcome =
      try do
        spawn_and_collect(built, resolved)
      rescue
        error -> {:spawn_error, Exception.message(error)}
      end

    case outcome do
      {:spawn_error, _} = terminal ->
        terminal

      {:exit, 0, out} ->
        cond do
          failover_class?(out) and retries_left > 0 ->
            Logger.warning(
              "[ultracode] dispatch failover-class outcome (attempt #{attempt}); " <>
                "retrying once after #{resolved.failover_backoff_ms}ms"
            )

            Process.sleep(resolved.failover_backoff_ms)
            attempt_loop(built, resolved, attempt + 1, retries_left - 1)

          failover_class?(out) ->
            {:rate_limited, attempt, 0, out}

          true ->
            {:ok, attempt, 0, out}
        end

      {:exit, code, out} ->
        {:failed, attempt, code, out}

      {:timeout, out} ->
        # A hang is not failover-class: never retried, the group is dead.
        {:timeout, attempt, nil, out}
    end
  end

  defp failover_class?(output), do: Regex.match?(@failover_regex, output)

  defp spawn_and_collect(built, resolved) do
    alarm_s = resolved.timeout_seconds + @alarm_grace_s
    code_file = code_file_path()

    # /usr/bin/env takes assignments as plain `K=V` argv strings (a port
    # args list itself must be all strings); the tuple form stays in the
    # plan/dry-run shape for evidence.
    env_args = Enum.map(built.env_added, fn {k, v} -> "#{k}=#{v}" end)

    args =
      env_args ++
        [
          "/usr/bin/perl",
          "-e",
          @wrapper,
          Integer.to_string(alarm_s),
          code_file,
          resolved.node_path
        ] ++
        built.argv_tail

    port =
      Port.open({:spawn_executable, "/usr/bin/env"}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        :hide,
        {:args, args},
        {:cd, built.cli_dir}
      ])

    {:os_pid, os_pid} = Port.info(port, :os_pid)
    deadline = System.monotonic_time(:millisecond) + resolved.timeout_seconds * 1000

    try do
      collect(port, os_pid, deadline, "", resolved.max_output_bytes, built.log, code_file)
    after
      # Universal group reap: runs on the clean-exit path too, so a worker
      # that leaves a background child behind never leaks it. Safe when the
      # group is already gone.
      kill_group(os_pid)
      _ = File.rm(code_file)
    end
  end

  # Completion is observed, not assumed: the port's own `{:exit_status, _}`
  # arrives only when the last holder of the inherited pipe closes it, so a
  # leftover pipe-holding descendant would otherwise stall the attempt to
  # the deadline. `collect/7` therefore also polls (a) the wrapper's exit
  # code record -- the definitive "turn ended" signal -- and (b) the
  # wrapper pid's liveness (spawn/exec failure without a record). Neither
  # signal false-fires while the turn is genuinely running.
  defp collect(port, os_pid, deadline, tail, max_out, log, code_file) do
    if System.monotonic_time(:millisecond) >= deadline do
      close_port(port)
      {:timeout, tail}
    else
      receive do
        {^port, {:data, data}} ->
          _ = io_log(log, data)

          collect(
            port,
            os_pid,
            deadline,
            keep_tail(tail <> data, max_out),
            max_out,
            log,
            code_file
          )

        {^port, {:exit_status, code}} ->
          {:exit, code, tail}
      after
        @poll_interval_ms ->
          cond do
            wrapper_recorded?(code_file) ->
              # The turn ended; a descendant is keeping the port open. Drain
              # what is already buffered, classify with the true code, and
              # let the outer after-clause reap the leftover group.
              tail = drain(port, tail, max_out, log)
              code = read_recorded_code(code_file)
              close_port(port)
              {:exit, code, tail}

            direct_dead?(os_pid) ->
              # Wrapper gone without a record: spawn/exec failure or a
              # backstop kill -- the historical exit-127 contract.
              tail = drain(port, tail, max_out, log)
              close_port(port)
              {:exit, 127, tail}

            true ->
              collect(port, os_pid, deadline, tail, max_out, log, code_file)
          end
      end
    end
  end

  defp wrapper_recorded?(code_file), do: File.regular?(code_file)

  defp read_recorded_code(code_file) do
    case File.read(code_file) do
      {:ok, bin} ->
        case Integer.parse(String.trim(bin)) do
          {code, ""} when code in 0..255 -> code
          _ -> 127
        end

      _ ->
        127
    end
  end

  defp direct_dead?(os_pid) do
    {_, code} =
      System.cmd("/bin/kill", ["-0", Integer.to_string(os_pid)], stderr_to_stdout: true)

    code != 0
  end

  # A short bounded sweep for port data that raced the completion signal;
  # the full stream is in the log file regardless.
  defp drain(port, tail, max_out, log) do
    receive do
      {^port, {:data, data}} ->
        _ = io_log(log, data)
        drain(port, keep_tail(tail <> data, max_out), max_out, log)
    after
      50 ->
        tail
    end
  end

  defp code_file_path do
    Path.join(System.tmp_dir!(), "xaas-dispatch-code-#{System.unique_integer([:positive])}")
  end

  # ------------------------------------------------------------------
  # Construction (shared by plan/2 and dispatch/2)
  # ------------------------------------------------------------------

  defp build(%Epoch{} = epoch, resolved) do
    epoch_id = epoch.id
    worker_id = worker_id(epoch_id)
    {mode, cwd} = pick_cwd(epoch.worktree)
    {:ok, cwd_real} = realpath(cwd)
    prompt = prompt(worker_id, epoch_id)

    log_path = resolved.log_path || default_log_path(epoch_id)

    env_added = [
      {"XAAS_WORKER", "1"},
      {"XAAS_LEASE_CWD", cwd_real}
      | Map.to_list(resolved.extra_env)
    ]

    argv_tail = [
      "bin/zcode.js",
      "--prompt",
      prompt,
      "--cwd",
      cwd_real,
      "--json"
    ]

    {:ok,
     %{
       epoch_id: epoch_id,
       worker_id: worker_id,
       mode: mode,
       cwd: cwd_real,
       prompt: prompt,
       env_added: env_added,
       argv_tail: argv_tail,
       cli_dir: resolved.cli_dir,
       log_path: log_path
     }}
  end

  # The prompt carries exactly two identifiers and nothing else -- the same
  # shape the proven bash dispatcher used. Goal text never enters it.
  defp prompt(worker_id, epoch_id) do
    "/xaas Call claim_next with provider_worker_id exactly \"#{worker_id}\" " <>
      "and epoch_id exactly \"#{epoch_id}\"; do not use any other values."
  end

  defp worker_id(epoch_id) do
    host =
      case :inet.gethostname() do
        {:ok, full} -> full |> List.to_string() |> String.split(".") |> hd()
        _ -> "unknown"
      end

    "zcode-dispatch-#{host}-#{String.slice(epoch_id, 0, 8)}-#{:os.getpid() |> List.to_string()}"
  end

  defp pick_cwd(worktree) when is_binary(worktree) do
    if File.dir?(worktree), do: {:claim, worktree}, else: {:reap, make_reap_dir()}
  end

  defp pick_cwd(_), do: {:reap, make_reap_dir()}

  defp make_reap_dir do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-dispatch-reap-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end

  defp default_log_path(epoch_id) do
    Path.join(
      System.tmp_dir!(),
      "xaas-dispatch-#{String.slice(epoch_id, 0, 8)}-#{System.unique_integer([:positive])}.log"
    )
  end

  # ------------------------------------------------------------------
  # Readiness (the fence: never dispatch into an epoch that is not ours
  # to dispatch)
  # ------------------------------------------------------------------

  # A caller may hand us the struct it already holds (Autonomic does); the
  # readiness fence still re-reads the row fresh so the decision is made
  # against the DB's current state, never a possibly-stale snapshot. Fetch
  # and check are deliberately separate clauses: the fetch re-reads by id,
  # the check runs once against the fetched row (a check that re-entered
  # the fetch would recurse forever -- a real bug this shape guards
  # against).
  defp ready_epoch(epoch_or_id, resolved) when is_binary(epoch_or_id),
    do: fetch_then_check(epoch_or_id, resolved)

  defp ready_epoch(%Epoch{} = epoch, resolved), do: fetch_then_check(epoch.id, resolved)

  defp fetch_then_check(epoch_id, resolved) do
    case Ash.get(Epoch, epoch_id, action: :read_unscoped, authorize?: false, load: [:run]) do
      {:ok, epoch} -> check_ready(epoch, resolved)
      {:error, error} -> {:error, {:epoch_not_found, epoch_id, inspect(error)}}
    end
  end

  defp check_ready(%Epoch{} = epoch, resolved) do
    now = DateTime.utc_now()
    lease_free? = is_nil(epoch.lease_token) or expired?(epoch.lease_expires_at, now)

    cond do
      epoch.state != :running ->
        {:error, {:epoch_not_ready, epoch.id, "state is #{epoch.state}, not :running"}}

      not lease_free? ->
        {:error, {:epoch_not_ready, epoch.id, "lease is still live"}}

      not is_struct(epoch.run, Xaas.Ultracode.Run) ->
        {:error, {:epoch_not_ready, epoch.id, "run record could not be loaded"}}

      epoch.run.provider != resolved.provider ->
        {:error,
         {:epoch_not_ready, epoch.id,
          "run provider is #{epoch.run.provider}, expected #{resolved.provider}"}}

      true ->
        {:ok, epoch}
    end
  end

  defp expired?(nil, _now), do: false
  defp expired?(expires_at, now), do: DateTime.compare(expires_at, now) == :lt

  # ------------------------------------------------------------------
  # Options
  # ------------------------------------------------------------------

  defp resolve_opts(opts) do
    cli_dir =
      Keyword.get(opts, :cli_dir) ||
        Application.get_env(:xaas, :ultracode_dispatch_cli_dir, @default_cli_dir)

    # The documented default (`:node_path` docs above): an unset option AND
    # an unset `:ultracode_dispatch_node_path` fall back to a PATH lookup,
    # NOT to a guaranteed refusal. The hard `check_node(nil)` fail-closed
    # below still fires when node genuinely is not resolvable.
    # PERMANENT GUARD (observed falsifier 2026-09-20, campaign
    # 529f359a wave 1): with no app env set, every worker launch of the
    # live 8-hour campaign returned `{:error, {:node_unavailable, "node"}}`
    # in <1ms -- all 18 wave-1 attempt epochs refused (e.g.
    # 82f2826f-240a-4272-b1ed-90e53e625e88, 75a0e737-d3d0-4a89-9c5f-052fa11a6aa8)
    # and the wave burned all 3 attempts per item producing zero real work,
    # while node was on PATH the whole time. Unset must MEAN "look it up".
    node_path =
      Keyword.get(opts, :node_path) ||
        Application.get_env(:xaas, :ultracode_dispatch_node_path, nil) ||
        System.find_executable("node")

    timeout_seconds = Keyword.get(opts, :timeout_seconds, @default_timeout_seconds)

    with {:ok, checked_cli} <- check_cli_dir(cli_dir),
         {:ok, checked_node} <- check_node(node_path) do
      {:ok,
       %{
         cli_dir: checked_cli,
         node_path: checked_node,
         timeout_seconds: timeout_seconds,
         failover_retries: Keyword.get(opts, :failover_retries, @default_failover_retries),
         failover_backoff_ms:
           Keyword.get(opts, :failover_backoff_ms, @default_failover_backoff_ms),
         max_output_bytes: Keyword.get(opts, :max_output_bytes, @default_max_output_bytes),
         log_path: Keyword.get(opts, :log_path),
         extra_env: Keyword.get(opts, :extra_env, %{}),
         provider: Keyword.get(opts, :provider, "zcode")
       }}
    end
  end

  defp check_cli_dir(cli_dir) when is_binary(cli_dir) do
    script = Path.join(cli_dir, "bin/zcode.js")

    if File.dir?(cli_dir) and File.regular?(script),
      do: {:ok, cli_dir},
      else: {:error, {:cli_unavailable, script}}
  end

  defp check_cli_dir(_), do: {:error, {:cli_unavailable, "unset"}}

  defp check_node(nil), do: {:error, {:node_unavailable, "node"}}

  defp check_node(node_path) when is_binary(node_path) do
    if System.find_executable(node_path) || File.exists?(node_path),
      do: {:ok, node_path},
      else: {:error, {:node_unavailable, node_path}}
  end

  defp check_node(_), do: {:error, {:node_unavailable, "node"}}

  # ------------------------------------------------------------------
  # Evidence: the log (full output) and the receipts (sealed records)
  # ------------------------------------------------------------------

  defp open_log(path) do
    File.mkdir_p!(Path.dirname(path))

    case File.open(path, [:append]) do
      {:ok, log} -> {:ok, log}
      {:error, reason} -> {:error, {:log_unavailable, path, inspect(reason)}}
    end
  end

  defp io_log(log, data) when is_pid(log), do: IO.binwrite(log, data)
  defp io_log(nil, _data), do: :ok

  defp sealed_receipts(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!(authorize?: false)
    |> Enum.map(fn receipt ->
      %{
        "outcome" => Atom.to_string(receipt.outcome),
        "head_verified" => Map.get(receipt.evidence, "head_verified", false),
        "sealed_at" => DateTime.to_iso8601(receipt.sealed_at)
      }
    end)
  end

  defp current_epoch_state(epoch_id) do
    case Ash.get(Epoch, epoch_id, action: :read_unscoped, authorize?: false) do
      {:ok, epoch} -> epoch.state
      {:error, _} -> :unknown
    end
  end

  # ------------------------------------------------------------------
  # Process-group helpers (same mechanics as Xaas.Ultracode.Verifier:
  # group-wide TERM, bounded grace, then KILL; safe when already gone)
  # ------------------------------------------------------------------

  # The kill is verified, not assumed: TERM, then poll the group until it is
  # gone (or the grace budget expires), then KILL, then poll again. The
  # dispatch must not report completion while a group member might still be
  # dying -- observed 2026-09-20: under test load a forked child sat
  # pre-exec for seconds, so a blind grace sleep let a straggler outlive
  # its own dispatch result.
  defp kill_group(os_pid) do
    _ = System.cmd("/bin/kill", ["-TERM", "--", "-#{os_pid}"], stderr_to_stdout: true)
    await_group_gone(os_pid, System.monotonic_time(:millisecond) + @grace_ms)

    unless group_alive?(os_pid) do
      :ok
    else
      _ = System.cmd("/bin/kill", ["-KILL", "--", "-#{os_pid}"], stderr_to_stdout: true)
      await_group_gone(os_pid, System.monotonic_time(:millisecond) + @kill_confirm_ms)

      if group_alive?(os_pid) do
        # A same-uid KILL cannot be ignored; reaching here means the group
        # identity itself is misbehaving. Say so loudly, never silently.
        Logger.warning("[ultracode] dispatch process group -#{os_pid} still alive after KILL")
      end

      :ok
    end
  end

  defp await_group_gone(os_pid, deadline) do
    if group_alive?(os_pid) and System.monotonic_time(:millisecond) < deadline do
      Process.sleep(100)
      await_group_gone(os_pid, deadline)
    end
  end

  defp group_alive?(os_pid) do
    match?({_, 0}, System.cmd("/bin/kill", ["-0", "--", "-#{os_pid}"], stderr_to_stdout: true))
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

  # macOS has no portable `realpath` binary; /bin/pwd -P is the same
  # resolution the bash dispatcher used (`cd "$cwd" && pwd -P`).
  defp realpath(dir) do
    case System.cmd("/bin/pwd", ["-P"], cd: dir, stderr_to_stdout: true) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, code} -> {:error, {:realpath_failed, dir, code, String.trim(out)}}
    end
  end
end
