defmodule Xaas.Ultracode.RecipeWorker do
  @moduledoc """
  The deterministic construction provider: a KNOWN work class executed by an
  operator-registered argv recipe, never by a model.

  It is an engine worker (`Xaas.Ultracode.Engine`'s 2-arity contract,
  `(epoch, ctx) -> :ok | :rate_limited | {:error, reason}`) and drives the
  lease protocol itself:

    1. RESOLVE -- the epoch's Run names a capability (`Run.capability_id`,
       the work order's `sj:capabilityId`, e.g. `"recipe:mix-format"`). The
       recipe is looked up by that NAME in
       `config :xaas, :ultracode_construction_recipes`
       (`capability_id => %{env:, steps: [%{id:, argv:, timeout_ms:}]}`) and
       admitted by `Xaas.Ultracode.TargetSuites.validate/1` plus a
       literal-argv check (no placeholders, no `priv:`). An absent capability
       or an unregistered recipe returns `{:error, :unregistered_recipe}`
       and an inadmissible one `{:error, {:invalid_recipe, problems}}` --
       both WITHOUT claiming, so no lease row is ever bound for work this
       worker cannot do.
    2. CLAIM -- `Lease.claim_next(provider, "recipe-worker", epoch_id: ...)`
       (a directed claim; the engine never claims on a worker's behalf).
    3. RUN -- each step's argv in the epoch's worktree (which must pass the
       verifier's containment law, `Verifier.contained_worktree/1`, and be
       clean) through the fabric's one guarded runner,
       `Xaas.Ultracode.Verifier.spawn_and_collect/6` (`env -i`, recipe env
       allowlist, throwaway HOME/TMPDIR, process-group kill at timeout).
       A non-zero exit, timeout, or spawn error refuses the lease
       (`:recipe_step_failed`) with the step evidence.
    4. DELTA -- `git status --porcelain` empty: the recipe changed nothing,
       `Lease.refuse(token, :no_delta)`. Otherwise the delta is committed
       (message via file, recipe-worker identity) and the lease is closed
       `:alive` at the new head with evidence `recipe`, `argv_sha256`,
       `executor: "recipe-worker"`. `Lease.close/4` then applies the
       fabric's own court: head verification plus the Run's registered
       verifier suite -- the worker's `:alive` is a claim, never standing.

  No LLM, no network, no credential is on this path: the only executables
  are the recipe argv lists an operator registered in config.
  """

  alias Xaas.Ultracode.{Epoch, Lease, Run, TargetSuites, Verifier}

  @executor "recipe-worker"
  @default_provider "recipe"
  @default_max_output 16_384
  @git_identity [
    {"GIT_AUTHOR_NAME", "recipe-worker"},
    {"GIT_AUTHOR_EMAIL", "recipe-worker@xaas.invalid"},
    {"GIT_COMMITTER_NAME", "recipe-worker"},
    {"GIT_COMMITTER_EMAIL", "recipe-worker@xaas.invalid"}
  ]

  @doc "The executor identity recorded on every lease and receipt this worker touches."
  @spec executor() :: String.t()
  def executor, do: @executor

  @doc """
  Engine worker entry point (`config :xaas, :ultracode_engine_worker,
  {Xaas.Ultracode.RecipeWorker, :run}`). `ctx.provider` is the pool the
  engine is filling (default `"recipe"`).
  """
  @spec run(Epoch.t(), map()) :: :ok | {:error, term()}
  def run(%Epoch{} = epoch, ctx) when is_map(ctx) do
    provider = Map.get(ctx, :provider) || @default_provider

    with {:ok, run} <- load_run(epoch),
         {:ok, capability, recipe} <- resolve(run) do
      case Lease.claim_next(provider, @executor, epoch_id: epoch.id) do
        {:ok, leased, token, _run} -> execute(leased, token, capability, recipe)
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  The admitted recipe for `capability_id`, or a typed refusal:
  `{:error, :unregistered_recipe}` / `{:error, {:invalid_recipe, problems}}`.
  """
  @spec recipe(String.t() | nil) ::
          {:ok, map()} | {:error, :unregistered_recipe | {:invalid_recipe, [String.t()]}}
  def recipe(capability_id) when is_binary(capability_id) do
    registry = Application.get_env(:xaas, :ultracode_construction_recipes, %{}) || %{}

    case registry do
      %{^capability_id => recipe} -> admit(capability_id, recipe)
      _ -> {:error, :unregistered_recipe}
    end
  end

  def recipe(_none), do: {:error, :unregistered_recipe}

  @doc """
  Stable sha256 over the recipe's executable surface (each step's id, argv
  and timeout), recorded as `argv_sha256` in the closing evidence.
  """
  @spec argv_digest(map()) :: String.t()
  def argv_digest(%{steps: steps}) do
    steps
    |> Enum.map(fn step ->
      %{"id" => to_string(step.id), "argv" => step.argv, "timeout_ms" => step.timeout_ms}
    end)
    |> Jason.encode!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  # ------------------------------------------------------------------

  defp load_run(%Epoch{run: %Run{} = run}), do: {:ok, run}

  defp load_run(%Epoch{run_id: run_id}) do
    case Ash.get(Run, run_id, action: :read_unscoped, authorize?: false) do
      {:ok, %Run{} = run} -> {:ok, run}
      {:error, reason} -> {:error, {:run_unreadable, reason}}
    end
  end

  defp resolve(%Run{capability_id: capability}) do
    with {:ok, recipe} <- recipe(capability), do: {:ok, capability, recipe}
  end

  defp admit(capability_id, recipe) when is_map(recipe) do
    with :ok <- TargetSuites.validate(%{capability_id => recipe}),
         :ok <- literal_argv(recipe) do
      {:ok, recipe}
    else
      {:error, problems} -> {:error, {:invalid_recipe, problems}}
    end
  end

  defp admit(_capability_id, _recipe), do: {:error, {:invalid_recipe, ["recipe must be a map"]}}

  # The recipe runner resolves no placeholders and no `priv:` paths: every
  # argv element is executed exactly as registered.
  defp literal_argv(%{steps: steps}) do
    placeholders = Verifier.placeholders()

    problems =
      for step <- steps,
          element <- step.argv,
          element in placeholders or String.starts_with?(element, "priv:"),
          do: "step #{inspect(step.id)}: non-literal argv element #{inspect(element)}"

    if problems == [], do: :ok, else: {:error, problems}
  end

  defp execute(%Epoch{} = leased, token, capability, recipe) do
    base = %{
      "recipe" => capability,
      "argv_sha256" => argv_digest(recipe),
      "executor" => @executor
    }

    with {:ok, worktree} <- contained(leased.worktree),
         {:ok, base_head} <- git_head(worktree),
         :ok <- clean_before(worktree) do
      base = Map.put(base, "base_head", base_head)
      tmp = make_tmp(leased.id)

      try do
        run_and_settle(token, worktree, tmp, recipe, base)
      after
        File.rm_rf(tmp)
      end
    else
      {:refuse, reason, evidence} -> refuse(token, reason, Map.merge(base, evidence))
    end
  end

  defp run_and_settle(token, worktree, tmp, recipe, base) do
    case run_steps(token, worktree, tmp, recipe) do
      {:ok, steps} ->
        evidence = Map.put(base, "steps", steps)

        case git(worktree, ["status", "--porcelain"]) do
          {"", 0} ->
            refuse(token, :no_delta, evidence)

          {_changes, 0} ->
            commit_and_close(token, worktree, tmp, evidence)

          {out, code} ->
            refuse(token, :git_status_failed, Map.put(evidence, "git", "#{code}: #{out}"))
        end

      {:failed, steps} ->
        refuse(token, :recipe_step_failed, Map.put(base, "steps", steps))
    end
  end

  defp run_steps(token, worktree, tmp, recipe) do
    max_out = Map.get(recipe, :max_output_bytes, @default_max_output)

    Enum.reduce_while(recipe.steps, {:ok, []}, fn step, {:ok, acc} ->
      started = System.monotonic_time(:millisecond)

      outcome =
        Verifier.spawn_and_collect(step.argv, recipe, worktree, tmp, step.timeout_ms, max_out)

      result = step_result(step, outcome, System.monotonic_time(:millisecond) - started)
      acc = acc ++ [result]

      if result["status"] == "pass" do
        # A multi-step recipe must not outlive its lease between steps.
        _ = Lease.renew(token)
        {:cont, {:ok, acc}}
      else
        {:halt, {:failed, acc}}
      end
    end)
  end

  defp step_result(step, outcome, duration_ms) do
    {exit_code, status, tail} =
      case outcome do
        {:exit, 0, out} -> {0, "pass", out}
        {:exit, code, out} -> {code, "fail", out}
        {:timeout, out} -> {nil, "timeout", out}
        {:spawn_error, reason} -> {nil, "error", reason}
      end

    %{
      "id" => to_string(step.id),
      "exit" => exit_code,
      "status" => status,
      "duration_ms" => duration_ms,
      "output_tail" => String.replace_invalid(tail, "?")
    }
  end

  defp commit_and_close(token, worktree, tmp, evidence) do
    message_file = Path.join(tmp, "COMMIT_MSG")
    File.write!(message_file, commit_message(evidence))

    with {_, 0} <- git(worktree, ["add", "-A"]),
         {_, 0} <- git(worktree, ["commit", "-q", "-F", message_file]),
         {:ok, head} <- git_head(worktree) do
      case Lease.close(token, head, :alive, evidence) do
        {:ok, _epoch, _receipt} -> :ok
        {:error, reason} -> {:error, reason}
      end
    else
      {out, code} when is_integer(code) ->
        refuse(token, :commit_failed, Map.put(evidence, "git", "#{code}: #{out}"))

      {:refuse, reason, extra} ->
        refuse(token, reason, Map.merge(evidence, extra))
    end
  end

  defp commit_message(evidence) do
    """
    recipe(#{evidence["recipe"]}): deterministic construction

    executor: #{@executor}
    argv_sha256: #{evidence["argv_sha256"]}
    base_head: #{evidence["base_head"]}
    """
  end

  defp refuse(token, reason, evidence) do
    case Lease.refuse(token, reason, evidence) do
      {:ok, _epoch, _receipt} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp contained(worktree) do
    case Verifier.contained_worktree(worktree) do
      {:ok, real} -> {:ok, real}
      {:error, reason} -> {:refuse, :worktree_not_contained, %{"containment" => reason}}
    end
  end

  defp clean_before(worktree) do
    case git(worktree, ["status", "--porcelain"]) do
      {"", 0} -> :ok
      {out, 0} -> {:refuse, :dirty_worktree, %{"dirty" => String.split(out, "\n", trim: true)}}
      {out, code} -> {:refuse, :git_status_failed, %{"git" => "#{code}: #{out}"}}
    end
  end

  defp git_head(worktree) do
    case git(worktree, ["rev-parse", "HEAD"]) do
      {out, 0} -> {:ok, String.trim(out)}
      {out, code} -> {:refuse, :head_unreadable, %{"git" => "#{code}: #{out}"}}
    end
  end

  defp git(worktree, args) do
    System.cmd("git", ["-C", worktree | args], env: @git_identity, stderr_to_stdout: true)
  end

  defp make_tmp(epoch_id) do
    dir =
      Path.join(
        System.tmp_dir!(),
        "xaas-recipe-#{epoch_id}-#{System.system_time(:millisecond)}-#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    dir
  end
end
