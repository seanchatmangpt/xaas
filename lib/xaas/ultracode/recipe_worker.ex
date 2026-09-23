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
       `Lease.refuse(token, :no_delta)`. Otherwise the delta is staged into
       a PRIVATE index (`GIT_INDEX_FILE` under the epoch's tmp dir; the
       worktree's own index is not written), turned into a commit object
       with `git commit-tree` (message via file, recipe-worker identity, no
       target hook runs), and published by the FENCED ref update below.
       The lease is then closed `:alive` at the new head with evidence
       `recipe`, `argv_sha256`, `executor: "recipe-worker"`.
       `Lease.close/4` applies the fabric's own court: head verification
       plus the Run's registered verifier suite -- the worker's `:alive` is
       a claim, never standing.

  ## The lease is the only write authority

  Between steps (and after the last one, before any staging) the worker
  renews its lease. A renew error means the lease is lost -- expired,
  closed or refused by someone else, or re-claimed by another owner -- and
  the recipe HALTS there: no further step, no staging, no commit.

  The one history write -- moving `HEAD` to the recipe's commit -- is
  fenced by the lease row itself: `git update-ref HEAD <commit> <base_head>`
  (a compare-and-swap on the base head) runs inside a `Xaas.Repo`
  transaction that holds the epoch row `FOR UPDATE` and only while that
  row still binds this token, is `:running` and is not past
  `lease_expires_at`. Every competing lease write (claim, renew, close,
  refuse) is a row-level `UPDATE` on the same row, so it waits for the
  fence; a lease lost at any moment before the fence -- including after
  the last renew, while the delta is being staged -- leaves `HEAD`, the
  branch and the worktree's index untouched (the unreferenced commit
  object is only named as `unreferenced_commit`).

  On a loss the worker returns `{:error, {:lease_lost, reason}}`, refuses
  the lease when the token is still bound to it (so the slot and a
  `:refused` receipt are sealed), and otherwise leaves the epoch to the
  engine's reaper or to its new owner. The step output stays uncommitted in
  the worktree; it is only read (`git status`) and named in the log.

  The lease token never leaves this worker: every `{:error, reason}` it
  returns and every log line it writes carries the token only as its
  sha256 fingerprint (`"lease:sha256:<hex>"`), including the `Lease` errors
  that embed the raw token (`{:lease_expired, token}`, `{:no_lease, token}`,
  `{:lease_stale, token}`) on the refuse and close paths.

  ## The toolchain is resolved from the target, never pinned to a host

  A recipe declaring `elixir_toolchain: :target` (the registered
  `"recipe:mix-format"`) gets its `PATH` at execution time from
  `toolchain/1`: the TARGET worktree's `.tool-versions` through the asdf
  install layout (`$ASDF_DATA_DIR`, or `config :xaas,
  :ultracode_asdf_data_dir`, default `~/.asdf`) when the pinned installs
  are present, else the running node's `System.find_executable("mix")`
  plus the node's own ERTS `bin`. Such a recipe may not pin `PATH` in its
  env (admission refuses it). The resolved identity is recorded as
  `toolchain` in the closing (or refusing) lease evidence; an unresolvable
  toolchain refuses the lease `:toolchain_unresolved`. Only an ABSENT
  `.tool-versions` (no directory entry at all) means "no pin": a pin file
  that exists but cannot be read (`eacces`, `eisdir`, a dangling symlink,
  ...) is logged and refused `:toolchain_unresolved`, never silently
  replaced by the running node's toolchain.

  No LLM, no network, no credential is on this path: the only executables
  are the recipe argv lists an operator registered in config.
  """

  require Logger

  import Ecto.Query, only: [from: 2]

  alias Xaas.Ultracode.{DurationBudget, Epoch, Lease, Run, TargetSuites, Verifier}

  @executor "recipe-worker"
  @default_provider "recipe"
  @default_max_output 16_384
  # Appended to every resolved toolchain PATH: POSIX locations only (the
  # recipe's own `sh`/`env` users), never a host-specific install dir.
  @system_path ["/usr/bin", "/bin"]
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

  @doc """
  The Elixir toolchain a recipe with `elixir_toolchain: :target` runs under,
  resolved from the TARGET `worktree`:

    1. `<worktree>/.tool-versions` pins `elixir` (and optionally `erlang`)
       and the asdf installs `<asdf>/installs/elixir/<v>/bin/mix` (and
       `<asdf>/installs/erlang/<v>/bin/erl`) exist -> `"source" => "asdf"`;
       an unpinned erlang comes from the running node's ERTS `bin`;
    2. otherwise the running node: `System.find_executable("mix")` plus
       `:code.root_dir()/bin` -> `"source" => "node"` (a pin that asdf
       could not satisfy is recorded as `"pin_satisfied" => false`).

  `<asdf>` = `config :xaas, :ultracode_asdf_data_dir`, else
  `$ASDF_DATA_DIR`, else `~/.asdf`. Returns the JSON-safe identity map
  (`source`, `elixir`, `erlang`, `mix`, `erl`, `path`, `tool_versions`,
  `pin_satisfied`) whose `"path"` becomes the recipe's `PATH`, or
  `{:error, {:toolchain_unresolved, why}}` -- also when
  `<worktree>/.tool-versions` exists but cannot be read (logged; only an
  absent file falls through to step 2).
  """
  @spec toolchain(String.t()) :: {:ok, map()} | {:error, {:toolchain_unresolved, String.t()}}
  def toolchain(worktree) when is_binary(worktree) do
    with {:ok, pins, digest} <- tool_versions(worktree) do
      case asdf_toolchain(pins) do
        {:ok, identity} -> {:ok, Map.merge(identity, pin_identity(pins, digest, true))}
        :unavailable -> node_toolchain(pins, digest)
      end
    end
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
         :ok <- literal_argv(recipe),
         :ok <- toolchain_declaration(recipe) do
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

  # `elixir_toolchain: :target` is the only toolchain declaration: its PATH
  # is resolved per epoch from the target, so the recipe may not pin one.
  defp toolchain_declaration(recipe) do
    case Map.fetch(recipe, :elixir_toolchain) do
      :error ->
        :ok

      {:ok, :target} ->
        if Map.has_key?(Map.get(recipe, :env) || %{}, "PATH"),
          do:
            {:error,
             [
               "elixir_toolchain: :target resolves PATH from the target worktree; env may not pin PATH"
             ]},
          else: :ok

      {:ok, other} ->
        {:error, ["elixir_toolchain must be :target, got #{inspect(other)}"]}
    end
  end

  defp execute(%Epoch{} = leased, token, capability, recipe) do
    base = %{
      "recipe" => capability,
      "argv_sha256" => argv_digest(recipe),
      "executor" => @executor
    }

    result =
      with {:ok, worktree} <- contained(leased.worktree),
           {:ok, base_head} <- git_head(worktree),
           :ok <- clean_before(worktree),
           {:ok, recipe, toolchain} <- bind_toolchain(recipe, worktree) do
        base = base |> Map.put("base_head", base_head) |> Map.put("toolchain", toolchain)
        tmp = make_tmp(leased.id)

        try do
          run_and_settle(token, worktree, tmp, recipe, base)
        after
          File.rm_rf(tmp)
        end
      else
        {:refuse, reason, evidence} -> refuse(token, reason, Map.merge(base, evidence))
      end

    # The single exit for everything after the claim: no error carries the
    # raw token (see the moduledoc).
    case result do
      {:error, error} -> {:error, redact(error, token)}
      other -> other
    end
  end

  defp run_and_settle(token, worktree, tmp, recipe, base) do
    case run_steps(token, worktree, tmp, recipe) do
      {:lease_lost, reason, steps} ->
        lease_lost(token, worktree, reason, Map.put(base, "steps", steps))

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
        # The lease is re-proven after EVERY passing step -- including the
        # last, i.e. before `git status`/`git add`/commit. A lost lease halts
        # here: no further step and no write to the worktree's history.
        case Lease.renew(token) do
          :ok -> {:cont, {:ok, acc}}
          {:error, reason} -> {:halt, {:lease_lost, redact(reason, token), acc}}
        end
      else
        {:halt, {:failed, acc}}
      end
    end)
  end

  # The lease is lost (see the moduledoc): record what is observable without
  # writing -- the uncommitted paths -- try to seal a refusal with the token
  # (succeeds only while the token is still bound), and return the typed loss.
  defp lease_lost(token, worktree, reason, evidence) do
    uncommitted =
      case git(worktree, ["status", "--porcelain"]) do
        {out, 0} -> String.split(out, "\n", trim: true)
        {out, code} -> "git status failed #{code}: #{out}"
      end

    evidence =
      evidence
      |> Map.put("lease_lost", inspect(reason))
      |> Map.put("uncommitted", uncommitted)

    refusal =
      case Lease.refuse(token, :lease_lost, evidence) do
        {:ok, _epoch, _receipt} -> "refused"
        {:error, error} -> inspect(redact(error, token))
      end

    Logger.error(
      "[recipe-worker] lease lost before commit: recipe=#{evidence["recipe"]} " <>
        "lease=#{fingerprint(token)} reason=#{inspect(reason)} refuse=#{refusal} " <>
        "uncommitted=#{inspect(uncommitted)} " <>
        "unreferenced_commit=#{evidence["unreferenced_commit"] || "none"}"
    )

    {:error, {:lease_lost, reason}}
  end

  # The lease token is the only capability: it never leaves this worker in a
  # return value or a log line, only its sha256 fingerprint does. Applied to
  # every error `execute/4` returns and to every logged Lease error, at any
  # depth: tuples, lists, maps and structs (Ash errors), and binaries that
  # merely contain the token.
  defp redact(binary, token) when is_binary(binary) do
    if String.contains?(binary, token),
      do: String.replace(binary, token, "lease:sha256:" <> fingerprint(token)),
      else: binary
  end

  defp redact(tuple, token) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&redact(&1, token)) |> List.to_tuple()

  # Cons-cell recursion: also safe on an improper list's tail.
  defp redact([head | tail], token), do: [redact(head, token) | redact(tail, token)]

  defp redact(map, token) when is_map(map), do: :maps.map(fn _k, v -> redact(v, token) end, map)

  defp redact(other, _token), do: other

  defp fingerprint(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

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

  # Stage + commit object off to the side, publish under the lease fence,
  # then close (see the moduledoc, "The lease is the only write authority").
  defp commit_and_close(token, worktree, tmp, evidence) do
    message_file = Path.join(tmp, "COMMIT_MSG")
    File.write!(message_file, commit_message(evidence))
    base_head = evidence["base_head"]

    with {:ok, commit} <- candidate_commit(worktree, tmp, message_file, base_head),
         :ok <- fenced_ref_update(token, worktree, commit, base_head),
         {:ok, head} <- git_head(worktree) do
      evidence = sync_index(worktree, evidence)

      case Lease.close(token, head, :alive, evidence) do
        {:ok, _epoch, _receipt} ->
          :ok

        {:error, error} ->
          # The commit was published under a live, locked lease; the close
          # itself lost (e.g. the lease expired after the fence). Typed and
          # logged -- the engine's reaper settles the epoch.
          error = redact(error, token)

          Logger.error(
            "[recipe-worker] close after fenced commit failed: recipe=#{evidence["recipe"]} " <>
              "lease=#{fingerprint(token)} head=#{head} error=#{inspect(error)}"
          )

          {:error, error}
      end
    else
      {:lease_lost, reason, commit} ->
        lease_lost(token, worktree, reason, Map.put(evidence, "unreferenced_commit", commit))

      {:refuse, reason, extra} ->
        refuse(token, reason, Map.merge(evidence, extra))
    end
  end

  # The delta as a commit object whose parent is `base_head`, built through a
  # private index so nothing the worktree's own index or refs see changes
  # until the fence publishes it. `commit-tree` runs no hook of the target.
  defp candidate_commit(worktree, tmp, message_file, base_head) do
    index = [{"GIT_INDEX_FILE", Path.join(tmp, "index")}]

    with {_, 0} <- git(worktree, ["read-tree", base_head], index),
         {_, 0} <- git(worktree, ["add", "-A"], index),
         {tree, 0} <- git(worktree, ["write-tree"], index),
         {:ok, tree} <- object_id(tree),
         {commit, 0} <-
           git(worktree, ["commit-tree", tree, "-p", base_head, "-F", message_file]),
         {:ok, commit} <- object_id(commit) do
      {:ok, commit}
    else
      {out, code} when is_integer(code) ->
        {:refuse, :commit_failed, %{"git" => "#{code}: #{out}"}}

      {:error, {:not_an_object_id, out}} ->
        {:refuse, :commit_failed, %{"git" => "unexpected git output: #{out}"}}
    end
  end

  defp object_id(out) do
    id = String.trim(out)

    if Regex.match?(~r/\A[0-9a-f]{40}(?:[0-9a-f]{24})?\z/, id),
      do: {:ok, id},
      else: {:error, {:not_an_object_id, out}}
  end

  # THE FENCE: `HEAD` moves (compare-and-swap on `base_head`) only inside a
  # transaction holding the epoch row `FOR UPDATE` while that row still
  # binds `token`, is `:running` and is not past `lease_expires_at` -- the
  # same liveness `Lease.renew/1` proves, on the same clock
  # (`DurationBudget.now/0`), but held across the write instead of checked
  # before it.
  defp fenced_ref_update(token, worktree, commit, base_head) do
    fenced =
      Xaas.Repo.transaction(fn ->
        row = Xaas.Repo.one(from(e in Epoch, where: e.lease_token == ^token, lock: "FOR UPDATE"))

        with :ok <- live_row(row, token),
             {_, 0} <-
               git(worktree, [
                 "update-ref",
                 "-m",
                 "recipe-worker: fenced commit",
                 "HEAD",
                 commit,
                 base_head
               ]) do
          :ok
        else
          {:lost, reason} -> Xaas.Repo.rollback({:lost, reason})
          {out, code} -> Xaas.Repo.rollback({:ref_update_failed, "#{code}: #{out}"})
        end
      end)

    case fenced do
      {:ok, :ok} ->
        :ok

      {:error, {:lost, reason}} ->
        {:lease_lost, redact(reason, token), commit}

      {:error, {:ref_update_failed, git_out}} ->
        {:refuse, :ref_update_failed, %{"git" => git_out, "unreferenced_commit" => commit}}

      {:error, other} ->
        {:refuse, :fence_failed,
         %{"fence" => inspect(redact(other, token)), "unreferenced_commit" => commit}}
    end
  end

  defp live_row(nil, token), do: {:lost, {:no_lease, token}}

  defp live_row(%Epoch{state: :running, lease_expires_at: %DateTime{} = expires_at}, token) do
    if DateTime.compare(expires_at, DurationBudget.now()) == :lt,
      do: {:lost, {:lease_expired, token}},
      else: :ok
  end

  defp live_row(%Epoch{state: :running}, token), do: {:lost, {:lease_expired, token}}
  defp live_row(%Epoch{state: state}, _token), do: {:lost, {:lease_not_live, state}}

  # After the fenced publish the worktree's own index still holds the base
  # tree; `read-tree HEAD` makes it the published tree (index only, the
  # working tree is not touched) and `update-index --refresh` restores the
  # stat cache. (`read-tree -m HEAD` refuses here: the changed paths are not
  # up to date with the old index.) A failure is recorded, not hidden: the
  # history write already happened under the lease.
  defp sync_index(worktree, evidence) do
    with {_, 0} <- git(worktree, ["read-tree", "HEAD"]),
         {_, 0} <- git(worktree, ["update-index", "-q", "--refresh"]) do
      evidence
    else
      {out, code} -> Map.put(evidence, "index_sync", "#{code}: #{out}")
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

  # A refusal that cannot be sealed (the lease was lost meanwhile) is typed
  # and logged, with the token redacted: `Lease.refuse/3` embeds it in
  # `{:lease_expired, token}` / `{:no_lease, token}`.
  defp refuse(token, reason, evidence) do
    case Lease.refuse(token, reason, evidence) do
      {:ok, _epoch, _receipt} ->
        :ok

      {:error, error} ->
        error = redact(error, token)

        Logger.error(
          "[recipe-worker] refusal #{reason} not sealed: recipe=#{evidence["recipe"]} " <>
            "lease=#{fingerprint(token)} error=#{inspect(error)}"
        )

        {:error, error}
    end
  end

  defp bind_toolchain(%{elixir_toolchain: :target} = recipe, worktree) do
    case toolchain(worktree) do
      {:ok, identity} ->
        env = Map.put(Map.get(recipe, :env) || %{}, "PATH", identity["path"])
        {:ok, Map.put(recipe, :env, env), identity}

      {:error, {:toolchain_unresolved, why}} ->
        {:refuse, :toolchain_unresolved, %{"toolchain" => %{"error" => why}}}
    end
  end

  defp bind_toolchain(recipe, _worktree) do
    env = Map.get(recipe, :env) || %{}
    {:ok, recipe, %{"source" => "recipe_env", "path" => Map.get(env, "PATH")}}
  end

  # ------------------------------------------------------------------
  # Toolchain resolution (`toolchain/1`)
  # ------------------------------------------------------------------

  # `{:ok, pins, digest}`; `{:ok, %{}, nil}` ONLY when the target has no
  # `.tool-versions` entry at all. An entry that exists but cannot be read
  # (eacces, eisdir, eloop, a dangling symlink's enoent, ...) is a typed
  # `{:error, {:toolchain_unresolved, why}}`, logged -- never read as "no
  # pin", which would silently substitute the running node's toolchain.
  defp tool_versions(worktree) do
    path = Path.join(worktree, ".tool-versions")

    case File.read(path) do
      {:ok, bytes} ->
        pins =
          bytes
          |> String.split("\n")
          |> Enum.map(&(&1 |> String.split("#", parts: 2) |> hd() |> String.split()))
          |> Enum.reduce(%{}, fn
            [tool, version | _], acc when tool in ["elixir", "erlang"] ->
              Map.put_new(acc, tool, version)

            _line, acc ->
              acc
          end)

        {:ok, pins, "sha256:" <> (:crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower))}

      {:error, :enoent} ->
        case File.lstat(path) do
          {:error, :enoent} -> {:ok, %{}, nil}
          _entry_exists -> unreadable_pins(path, :enoent)
        end

      {:error, reason} ->
        unreadable_pins(path, reason)
    end
  end

  defp unreadable_pins(path, reason) do
    why = "target .tool-versions exists but is unreadable (#{inspect(reason)}): #{path}"

    Logger.error(
      "[recipe-worker] #{why}; refusing instead of substituting the running node's toolchain"
    )

    {:error, {:toolchain_unresolved, why}}
  end

  defp asdf_toolchain(%{"elixir" => elixir} = pins) do
    root = asdf_data_dir()
    elixir_bin = Path.join([root, "installs", "elixir", elixir, "bin"])
    mix = Path.join(elixir_bin, "mix")

    with true <- executable?(mix),
         {:ok, erlang, erl} <- asdf_erlang(root, pins) do
      {:ok,
       %{
         "source" => "asdf",
         "asdf_data_dir" => root,
         "elixir" => elixir,
         "erlang" => erlang,
         "mix" => mix,
         "erl" => erl,
         "path" => path_string([elixir_bin, Path.dirname(erl)])
       }}
    else
      _ -> :unavailable
    end
  end

  defp asdf_toolchain(_no_elixir_pin), do: :unavailable

  defp asdf_erlang(root, %{"erlang" => erlang}) do
    erl = Path.join([root, "installs", "erlang", erlang, "bin", "erl"])
    if executable?(erl), do: {:ok, erlang, erl}, else: :unavailable
  end

  defp asdf_erlang(_root, _no_erlang_pin), do: {:ok, node_otp_version(), node_erl()}

  defp node_toolchain(pins, digest) do
    case System.find_executable("mix") do
      nil ->
        {:error,
         {:toolchain_unresolved,
          "no asdf install satisfies the target pins #{inspect(pins)} and no mix is on the running node's PATH"}}

      mix ->
        if Map.has_key?(pins, "elixir") do
          Logger.warning(
            "[recipe-worker] target pins #{inspect(pins)} not installed under #{asdf_data_dir()}; " <>
              "falling back to the running node's toolchain (#{mix})"
          )
        end

        real = follow_links(mix)

        {:ok,
         Map.merge(
           %{
             "source" => "node",
             "elixir" => version_file(real),
             "node_elixir" => System.version(),
             "erlang" => node_otp_version(),
             "mix" => real,
             "erl" => node_erl(),
             # The REAL elixir bin dir (only elixir/elixirc/iex/mix), so a
             # package-manager bin dir cannot shadow the node's own `erl`.
             "path" => path_string([Path.dirname(real), Path.dirname(node_erl())])
           },
           pin_identity(pins, digest, false)
         )}
    end
  end

  defp pin_identity(pins, digest, satisfied?) do
    %{
      "tool_versions" =>
        if(digest,
          do: %{"sha256" => digest, "elixir" => pins["elixir"], "erlang" => pins["erlang"]}
        ),
      "pin_satisfied" => if(Map.has_key?(pins, "elixir"), do: satisfied?)
    }
  end

  defp asdf_data_dir do
    Application.get_env(:xaas, :ultracode_asdf_data_dir) || System.get_env("ASDF_DATA_DIR") ||
      Path.expand("~/.asdf")
  end

  defp node_erl, do: Path.join([to_string(:code.root_dir()), "bin", "erl"])

  defp node_otp_version do
    release = to_string(:erlang.system_info(:otp_release))
    file = Path.join([to_string(:code.root_dir()), "releases", release, "OTP_VERSION"])

    case File.read(file) do
      {:ok, version} -> String.trim(version)
      {:error, _} -> release
    end
  end

  # `<elixir root>/VERSION` next to `bin/mix` (asdf and release installs
  # carry it; a package-manager install may not -> nil, and `node_elixir`
  # still names the running node's version).
  defp version_file(mix) do
    case File.read(Path.join([mix |> Path.dirname() |> Path.dirname(), "VERSION"])) do
      {:ok, version} -> String.trim(version)
      {:error, _} -> nil
    end
  end

  defp follow_links(path, depth \\ 16)

  defp follow_links(path, 0), do: path

  defp follow_links(path, depth) do
    case File.read_link(path) do
      {:ok, target} -> follow_links(Path.expand(target, Path.dirname(path)), depth - 1)
      {:error, _not_a_link} -> path
    end
  end

  defp executable?(path) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular, mode: mode}} -> Bitwise.band(mode, 0o111) != 0
      _ -> false
    end
  end

  defp path_string(dirs), do: (dirs ++ @system_path) |> Enum.uniq() |> Enum.join(":")

  # ------------------------------------------------------------------

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

  defp git(worktree, args, env \\ []) do
    System.cmd("git", ["-C", worktree | args], env: @git_identity ++ env, stderr_to_stdout: true)
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
