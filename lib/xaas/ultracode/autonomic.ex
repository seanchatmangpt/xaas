defmodule Xaas.Ultracode.Autonomic do
  @moduledoc """
  Closed-loop autonomic controller over the Ultracode fabric.

  One call (`run/1`, or `mix xaas.autonomic.run`) is the only trigger; there is
  no prompt, approval, or manual step anywhere between it and the terminal
  receipt. The loop is sense -> plan -> act -> verify -> repair -> promote ->
  learn:

    1. **Sense.** `priv/verifiers/aps_backlog.py` derives work items
       deterministically from the repository at an exact `base_sha` (a
       throwaway provisioned worktree, never the operator clone's tree).
    2. **Plan.** Per item: a provisioned worktree, a ticket file (mission,
       allowed paths, mutants, append-only history) OUTSIDE the worktree, and a
       provider-pull `Run` naming the operator-registered verifier suite plus a
       running `Epoch` bound to that worktree.
    3. **Act.** A worker (default: `Xaas.Ultracode.Dispatch.autonomic_worker/2`,
       the in-family dispatch boundary that launches one real gated headless
       zcode/GLM turn for the epoch) claims exactly
       that epoch and constructs. Concurrency is bounded by a top-up semaphore
       that halves on a provider rate refusal (APS swarm pacing law).
    4. **Verify.** The fabric, not the worker, decides done: `Lease.close/4`
       runs the verifier suite (`Xaas.Ultracode.Verifier`) against the exact
       closed head and seals the receipt.
    5. **Repair.** The judge (`judge_receipt/1`) accepts a closed receipt
       WITHOUT re-dispatch iff the FABRIC's court passed the exact head
       (`fabric_verifier.status == "pass"` AND `head_verified == true`) and
       the worker's standing is honest (`alive`/`partial_alive`) -- an
       honest `partial_alive` is the worker correctly declining to
       self-verify, not a failure; the court already ruled on that head.
       Everything else repairs: a court fail/timeout/error, a receipt with
       no court verdict, an unverified head, or a terminal standing
       (`build_broken`/`refused`/`blocked`). A repairing receipt appends
       the court's findings to the ticket history and starts attempt n+1 on
       the SAME worktree (bounded); an exhausted item is reported `blocked`
       with its full history, never dropped. A worker that dies without
       closing is reaped (its lease is refused) and counted as a failed
       attempt.
    6. **Promote.** Alive items merge serially (`--no-ff`) into a fresh
       integration branch in a provisioned integration worktree. This is the
       one shared-state step, so it is the only serialized one. Nothing is ever
       pushed anywhere.
    7. **Learn.** Every action is appended to an ndjson ledger; the final
       receipt records per-item receipts, worker ids, court verdict digests,
       the integration head, and the canonical suite verdict at that head.

  Standing is a pure function of results (`ALIVE` only when every backlog item
  is done AND the canonical suite passes at the integration head); it is never
  upgraded by narrative. `human_inputs` is `0` by construction: no code path
  here reads input.

  A worker is any 2-arity function `(epoch, ctx) -> :ok | :rate_limited |
  {:error, reason}` that drives the lease protocol for that epoch. The default
  launches one real gated worker agent per attempt through
  `Xaas.Ultracode.Dispatch`; tests pass a scripted protocol client that
  really claims, edits, commits and closes through `Xaas.Ultracode.Lease`.

  ## Multi-repo waves (the planning law)

  The `:repo` opt is a SPEC, not necessarily one alias: `"aps"` (one repo,
  the historical default), `"alpha,beta"` (several), or `"all"` (every alias
  registered in `config :xaas, :ultracode_repos`, sorted). `Xaas.Ultracode.WavePlan`
  owns the law:

    * **Selection** resolves the spec against the registry; unknown aliases
      and an empty registry are typed refusals at admission time, never a
      mid-wave surprise.
    * **Rotation** draws the wave's items round-robin over the selected
      repos in sorted alias order, so while a repo has ready items it gets
      at least one per wave (no starvation), and an optional per-repo cap
      (`:repo_caps` opt or `config :xaas, :ultracode_wave_repo_caps`)
      stops one deep backlog from monopolizing the wave.
    * **Tagging**: every plan item carries its `"repo"` alias through the
      whole path -- its worktree is provisioned FROM that repo, its ticket
      and dispatch goal name it, the receipt, per-item ledger lines and the
      integration branch carry it. A single-repo wave emits byte-for-byte
      the historical artifacts (no added keys, no tags): the tagging is
      gated on the wave being genuinely multi-repo.
    * **Promotion** merges each repo's done items into THAT repo's own
      integration worktree and verifies each with the canonical suite; a
      head from one repository can never merge into another's.
  """

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, Run, Verifier, WavePlan, Worktrees}

  @git_env [
    {"GIT_AUTHOR_NAME", "xaas-autonomic"},
    {"GIT_AUTHOR_EMAIL", "autonomic@xaas.local"},
    {"GIT_COMMITTER_NAME", "xaas-autonomic"},
    {"GIT_COMMITTER_EMAIL", "autonomic@xaas.local"}
  ]

  @defaults [
    repo: "aps",
    provider: "zcode",
    suite: "aps-dod",
    canonical_suite: "aps-canonical",
    capacity: 6,
    max_attempts: 3,
    rate_retries: 2,
    rate_backoff_ms: 30_000
  ]

  @doc """
  Runs the loop and returns `{:ok, report}`; the report is also written as JSON
  next to the ledger. Options: `:repo` (a spec: one alias, `a,b,c`, or `all`),
  `:base_sha` (single-repo waves only), `:only` (item ids),
  `:repo_caps` (per-repo wave item caps), `:senser` (`(repo_alias, worktree)
  -> {:ok, [item-maps]}`, default the deterministic APS backlog script),
  `:suite`, `:canonical_suite` (nil to skip), `:provider`, `:capacity`,
  `:max_attempts`, `:worker`, `:ledger`, `:state_dir`, `:project_root`.
  """
  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(opts \\ []) do
    with {:ok, selection} <- select(opts) do
      ctx = build_ctx(Keyword.merge(@defaults, opts), selection)
      File.mkdir_p!(ctx.out_dir)
      ledger(ctx, :start, start_event(ctx))

      with {:ok, items} <- sense_and_plan(ctx) do
        ledger(ctx, :sensed, sensed_event(ctx, items))

        results =
          items
          |> dispatch_bounded(ctx.capacity, fn item, sem_ctx ->
            process_item(item, Map.merge(ctx, sem_ctx))
          end)
          |> Enum.zip(items)
          |> Enum.map(fn
            {{:ok, result}, _item} -> result
            {{:exit, reason}, item} -> errored(item, {:task_exit, reason})
          end)

        finish(ctx, items, results)
      end
    end
  end

  # The planning law's admission gate: resolve the repo spec against the
  # operator registry, validate the per-repo caps, and pin each selected
  # repo's base (its own HEAD unless a single-repo wave pins one sha).
  # Everything types-refuses HERE rather than surprising a wave mid-flight.
  defp select(opts) do
    registry = Application.get_env(:xaas, :ultracode_repos, %{})
    spec = Keyword.get(opts, :repo, "aps")

    with {:ok, repos} <- WavePlan.resolve(spec, registry),
         {:ok, caps} <- WavePlan.validate_caps(repo_caps(opts)),
         {:ok, paths} <- repo_paths(repos),
         {:ok, base_shas} <- base_shas(repos, paths, opts) do
      {:ok, %{repos: repos, paths: paths, base_shas: base_shas, caps: caps}}
    end
  end

  # Generalized registry: an alias maps to a local clone path (plain string
  # shape) or to a map entry (path + per-repo worktree root + integration
  # branch + toolchain env). Typed refusal HERE, at selection; provisioning
  # itself re-refuses fail-closed at use time.
  defp repo_paths(repos) do
    Enum.reduce_while(repos, {:ok, %{}}, fn repo, {:ok, acc} ->
      case Worktrees.registry_entry(repo) do
        {:ok, entry} -> {:cont, {:ok, Map.put(acc, repo, entry.path)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp repo_caps(opts) do
    Keyword.get(opts, :repo_caps) || Application.get_env(:xaas, :ultracode_wave_repo_caps)
  end

  # A wave without an explicit base pins EACH repo at its own HEAD (the
  # historical behavior, per repo). One sha is only meaningful in one
  # repository, so an explicit `:base_sha` on a multi-repo wave is refused.
  defp base_shas(repos, paths, opts) do
    case Keyword.get(opts, :base_sha) do
      nil ->
        {:ok, Map.new(repos, fn repo -> {repo, git!(paths[repo], ["rev-parse", "HEAD"])} end)}

      sha when length(repos) == 1 ->
        {:ok, %{hd(repos) => sha}}

      sha ->
        {:error, {:base_sha_requires_single_repo, sha}}
    end
  end

  @doc """
  The capacity governor: dispatches `fun` over `items` with a hard,
  real-time bound of `capacity` slot-holding workers at any instant.

  This is the ONE in-family enforcement of the standing wave's capacity
  law -- `run/1` calls it with `ctx.capacity` (5 for the scheduled
  `:autonomic_wave` standing wave), so every wave's workers are admitted
  through this exact gate. It is public (test-qualified, not
  doc-hidden) so the invariant "a capacity-5 loop never has more than 5
  workers in flight at any instant" is directly property-tested against
  the production governor rather than a test double
  (`duration_budget_test.exs`).

  `fun` is 2-arity: `fun.(item, sem_ctx)` where `sem_ctx` carries THIS
  governor's semaphore (`sem_ctx.sem`). Callers whose workers re-acquire
  a slot per internal step (run/1's repair loop re-acquires per attempt)
  merge `sem_ctx` into their own context so EVERY acquisition -- first
  dispatch and every retry -- flows through the one semaphore; that is
  what makes the bound real under retries, and it is exactly the shape
  `run/1` had before this function was extracted (the semaphore used to
  live on the loop's ctx directly). The semaphore also halves on provider
  rate refusals (`halve/1`), so the bound only ever TIGHTENS mid-wave.

  Task-level exits surface per-item as `{:exit, reason}`, aligned with
  `items` by order (async_stream preserves input order).
  """
  @spec dispatch_bounded(list(), pos_integer(), (term(), map() -> term())) :: [
          {:ok, term()} | {:exit, term()}
        ]
  def dispatch_bounded(items, capacity, fun)
      when is_list(items) and is_integer(capacity) and capacity >= 1 and is_function(fun, 2) do
    {:ok, sem} = Agent.start_link(fn -> %{limit: capacity, in_flight: 0} end)

    # Materialize BEFORE stopping the semaphore: async_stream is lazy, and
    # workers acquire/release through `sem` during enumeration. Yields
    # {:ok, result} | {:exit, reason} per item, aligned with `items` by
    # order -- exactly this function's contract.
    results =
      items
      |> Task.async_stream(
        fn item -> fun.(item, %{sem: sem}) end,
        max_concurrency: max(capacity, 1),
        timeout: :infinity,
        ordered: true
      )
      |> Enum.to_list()

    Agent.stop(sem)
    results
  end

  # ------------------------------------------------------------------
  # Context
  # ------------------------------------------------------------------

  @doc false
  def new_ctx(opts) do
    case select(opts) do
      {:ok, selection} ->
        build_ctx(Keyword.merge(@defaults, opts), selection)

      {:error, reason} ->
        raise ArgumentError, "cannot build autonomic ctx: #{inspect(reason)}"
    end
  end

  defp build_ctx(opts, selection) do
    %{repos: repos, paths: paths, base_shas: base_shas, caps: caps} = selection
    ticket_dir = Application.fetch_env!(:xaas, :ultracode_ticket_dir)
    nonce = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    out_dir = Path.join(ticket_dir, "autonomic-#{nonce}")

    # Single-repo waves keep the historical flat fields byte-for-byte
    # (`repo`/`repo_path`/`base_sha`); a multi-repo wave names the spec.
    legacy =
      case repos do
        [only] ->
          %{repo: only, repo_path: paths[only], base_sha: base_shas[only]}

        _ ->
          %{repo: Keyword.get(opts, :repo, "aps")}
      end

    opts
    |> Map.new()
    |> Map.merge(legacy)
    |> Map.merge(%{
      repos: repos,
      multi?: length(repos) > 1,
      base_shas: base_shas,
      caps: caps,
      ticket_dir: ticket_dir,
      nonce: nonce,
      out_dir: out_dir,
      ledger: Keyword.get(opts, :ledger, Path.join(out_dir, "ledger.ndjson")),
      state_dir: Keyword.get(opts, :state_dir, Path.join(out_dir, "dispatch")),
      project_root: Keyword.get(opts, :project_root, File.cwd!()),
      worker: Keyword.get(opts, :worker, &dispatch_worker/2),
      senser: Keyword.get(opts, :senser, &aps_backlog/2),
      started_at: DateTime.utc_now()
    })
  end

  # ------------------------------------------------------------------
  # Sense + plan: sense each selected repo at ITS base, then draw the
  # wave through the WavePlan rotation
  # ------------------------------------------------------------------

  defp sense_and_plan(ctx) do
    with {:ok, sensed} <- sense_all(ctx), do: {:ok, WavePlan.rotate(sensed, ctx.caps)}
  end

  defp sense_all(ctx) do
    ctx.repos
    |> Enum.reduce_while({:ok, %{}}, fn repo, {:ok, acc} ->
      case sense_repo(ctx, repo) do
        {:ok, items} -> {:cont, {:ok, Map.put(acc, repo, items)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  @doc false
  def sense_repo(ctx, repo) do
    name = "#{repo}-sense-#{ctx.nonce}"

    with {:ok, path} <- Worktrees.provision(repo, ctx.base_shas[repo], name) do
      try do
        case ctx.senser.(repo, path) do
          {:ok, items} ->
            only = Map.get(ctx, :only)
            {:ok, if(only, do: Enum.filter(items, &(&1["id"] in only)), else: items)}

          {:error, _} = err ->
            err

          other ->
            {:error, {:bad_sense_result, other}}
        end
      after
        Worktrees.cleanup(repo, path)
      end
    end
  end

  # Historical entry point (single-repo ctx: `xaas.autonomic.controls`).
  @doc false
  def sense(ctx) do
    with {:ok, items} <- sense_repo(ctx, ctx.repo), do: {:ok, items}
  end

  # The default senser: the deterministic APS backlog derivation over a
  # throwaway worktree of ONE repo at that repo's base. Generic (non-APS)
  # sensing profiles are their own concern; the plan law treats any
  # `{:ok, [item-maps]}` senser as interchangeable.
  defp aps_backlog(_repo, path) do
    script = Application.app_dir(:xaas, "priv/verifiers/aps_backlog.py")

    case System.cmd("python3", [script, "--repo", path],
           env: [{"PYTHONDONTWRITEBYTECODE", "1"}],
           stderr_to_stdout: false
         ) do
      {out, 0} ->
        %{"items" => items} = Jason.decode!(out)
        {:ok, items}

      {out, code} ->
        {:error, {:backlog_failed, code, String.slice(out, -500, 500)}}
    end
  end

  # Ledger shapes: a single-repo wave emits EXACTLY the historical
  # payloads; a multi-repo wave adds the repo tags.
  defp start_event(ctx) do
    if ctx.multi? do
      %{repo: ctx.repo, repos: ctx.repos, base_shas: ctx.base_shas, capacity: ctx.capacity}
    else
      %{repo: ctx.repo, base_sha: ctx.base_sha, capacity: ctx.capacity}
    end
  end

  defp sensed_event(ctx, items) do
    if ctx.multi? do
      %{items: Enum.map(items, &%{"item" => &1["id"], "repo" => &1["repo"]}), repos: ctx.repos}
    else
      %{items: Enum.map(items, & &1["id"])}
    end
  end

  # ------------------------------------------------------------------
  # Per-item lifecycle
  # ------------------------------------------------------------------

  defp process_item(item, ctx) do
    # The plan tags every item with its repo; the worktree is provisioned
    # FROM that repo at that repo's base. Single-repo waves yield the
    # historical name ("aps-<item>-<nonce>").
    repo = Map.fetch!(item, "repo")
    name = "#{repo}-#{item["id"]}-#{ctx.nonce}"

    with {:ok, worktree} <- Worktrees.provision(repo, ctx.base_shas[repo], name) do
      ledger(ctx, :worktree, worktree_event(ctx, item, worktree))
      attempt(item, worktree, 1, [], 0, ctx)
    else
      {:error, reason} -> errored(item, {:provision_failed, reason})
    end
  rescue
    error -> errored(item, {:crashed, Exception.message(error)})
  end

  defp worktree_event(ctx, item, worktree) do
    if ctx.multi? do
      %{item: item["id"], repo: item["repo"], path: worktree}
    else
      %{item: item["id"], path: worktree}
    end
  end

  # Per-item ledger lines carry the repo tag in a multi-repo wave
  # (attempt_start/item_done/attempt_failed/item_blocked/merged/...);
  # single-repo waves keep the historical line shape byte-for-byte.
  defp item_data(ctx, item, data)
  defp item_data(%{multi?: true}, %{"repo" => repo}, data), do: Map.put(data, :repo, repo)
  defp item_data(%{multi?: true}, %{repo: repo}, data), do: Map.put(data, :repo, repo)
  defp item_data(_ctx, _item, data), do: data

  defp attempt(item, worktree, n, history, _rate_used, ctx) when n > ctx.max_attempts do
    ledger(ctx, :item_blocked, item_data(ctx, item, %{item: item["id"], attempts: n - 1}))

    %{
      item: item["id"],
      repo: item["repo"],
      status: :blocked,
      attempts: n - 1,
      worktree: worktree,
      history: history
    }
  end

  defp attempt(item, worktree, n, history, rate_used, ctx) do
    {run, epoch} = create_run_and_epoch(item, worktree, n, history, ctx)

    ledger(
      ctx,
      :attempt_start,
      item_data(ctx, item, %{
        item: item["id"],
        attempt: n,
        run_id: run.id,
        epoch_id: epoch.id
      })
    )

    result = with_slot(ctx, fn -> ctx.worker.(epoch, ctx) end)

    ledger(
      ctx,
      :worker_returned,
      item_data(ctx, item, %{
        item: item["id"],
        attempt: n,
        epoch_id: epoch.id,
        result: inspect(result)
      })
    )

    case result do
      :rate_limited ->
        halve(ctx)
        _ = settle(epoch, ctx)

        if rate_used < ctx.rate_retries do
          Process.sleep(ctx.rate_backoff_ms)
          attempt(item, worktree, n, history, rate_used + 1, ctx)
        else
          attempt(
            item,
            worktree,
            n + 1,
            history ++ [%{attempt: n, failure: "rate_limited"}],
            0,
            ctx
          )
        end

      _ok_or_error ->
        case settle(epoch, ctx) do
          {:done, receipt, epoch} ->
            ledger(
              ctx,
              :item_done,
              item_data(ctx, item, %{
                item: item["id"],
                attempt: n,
                epoch_id: epoch.id,
                receipt_id: receipt.id,
                # WHICH acceptance rule promoted this item: `alive` (the
                # worker closed alive and the court confirmed) or
                # `partial_alive` (an honest worker's self-assessment,
                # accepted because the court passed the exact head -- the
                # evidence lives in the sealed receipt either way).
                accepted_via: Atom.to_string(receipt.outcome)
              })
            )

            %{
              item: item["id"],
              repo: item["repo"],
              status: :done,
              attempts: n,
              worktree: worktree,
              head: epoch.final_head,
              epoch_id: epoch.id,
              run_id: run.id,
              receipt_id: receipt.id,
              executor: epoch.leased_to,
              fabric_verifier: summarize(receipt.evidence["fabric_verifier"]),
              history: history
            }

          {:failed, failure} ->
            ledger(
              ctx,
              :attempt_failed,
              item_data(ctx, item, %{item: item["id"], attempt: n, failure: failure})
            )

            attempt(item, worktree, n + 1, history ++ [%{attempt: n, failure: failure}], 0, ctx)
        end
    end
  end

  @doc false
  def create_run_and_epoch(item, worktree, n, history, ctx) do
    File.mkdir_p!(ctx.ticket_dir)

    # A multi-repo wave binds the run to its execution repo: the OCEL
    # egress derives the Repo object from it, and Dispatch passes the
    # registry entry's toolchain_env to the worker. Single-repo waves
    # leave it nil -- the historical row and log shape, byte for byte.
    run_attrs =
      %{
        goal: dispatch_goal(item, history, ctx),
        provider: ctx.provider,
        max_cycles: 1,
        verifier_suite: ctx.suite
      }

    run_attrs =
      if ctx.multi?, do: Map.put(run_attrs, :execution_repo_alias, item["repo"]), else: run_attrs

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(:create, run_attrs, authorize?: false)
      |> Ash.create()

    ticket =
      %{
        schemaVersion: "aps-ticket/1",
        item: item["id"],
        attempt: n,
        base_sha: ctx.base_shas[item["repo"]],
        allowed_paths: item["allowed_paths"],
        min_new_tests: item["min_new_tests"],
        min_kill_ratio: item["min_kill_ratio"],
        mutants: item["mutants"],
        history: history
      }

    ticket = if ctx.multi?, do: Map.put(ticket, :repo, item["repo"]), else: ticket

    File.write!(Path.join(ctx.ticket_dir, "#{run.id}.json"), Jason.encode!(ticket))

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "#{item["repo"]}-autonomic:#{item["id"]}##{n}:#{run.id}",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  # The dispatch goal names the repo for a multi-repo wave: the worker
  # reads the goal from the lease payload, and the OCEL egress exports the
  # Run goal -- so the tag reaches both. A single-repo wave keeps the
  # historical goal text byte-for-byte.
  defp dispatch_goal(item, history, ctx) do
    goal = repair_goal(item["goal"], history)

    if ctx.multi? do
      "[repo: #{item["repo"]}] " <> goal
    else
      goal
    end
  end

  defp repair_goal(goal, []), do: goal

  defp repair_goal(goal, history) do
    lines =
      Enum.map_join(history, "\n", fn %{attempt: n, failure: failure} ->
        "  - attempt #{n}: #{failure_text(failure)}"
      end)

    goal <>
      "\n\nPREVIOUS ATTEMPT(S) WERE REJECTED BY THE INDEPENDENT COURT:\n" <>
      lines <>
      "\nYour earlier commit(s) are already in this worktree. Fix exactly the reported " <>
      "failures (edit the same file), commit again, and close with your new head."
  end

  defp failure_text(failure) when is_binary(failure), do: failure
  defp failure_text(failure), do: inspect(failure)

  # Reads the sealed state back from the database and decides. Reaps a worker
  # that never closed.
  defp settle(%Epoch{id: id}, ctx) do
    epoch = Ash.get!(Epoch, id, action: :read_unscoped, authorize?: false)

    receipts =
      Receipt |> Ash.Query.for_read(:for_epoch, %{epoch_id: id}) |> Ash.read!(authorize?: false)

    case epoch.state do
      :completed ->
        closing = Enum.find(receipts, &Map.has_key?(&1.evidence, "head_verified"))
        judge(epoch, closing)

      :failed ->
        {:failed, "worker refused the epoch"}

      :running ->
        reap(epoch, ctx)
    end
  end

  defp judge(epoch, nil),
    do: {:failed, "epoch completed without a closing receipt (epoch #{epoch.id})"}

  defp judge(epoch, receipt) do
    case judge_receipt(receipt) do
      :accept -> {:done, receipt, epoch}
      {:repair, reason} -> {:failed, reason}
    end
  end

  @doc """
  The judge: the wave loop's repair predicate for one closed epoch's sealed
  receipt (`settle/2` finds the closing receipt; this decides).

  ## Precedence law

  The promotion decision is grounded in the FABRIC's verification -- the
  court verdict `Lease.close/4` sealed into `receipt.evidence["fabric_verifier"]`
  (`Xaas.Ultracode.Verifier` executed the operator's suite against the exact
  confirmed head) -- NEVER in the worker's own standing claim. A leased
  worker cannot run its own verification (`Lease.admit_tool/2` refuses
  Bash), so an honest worker's `:partial_alive` is a *self-assessment*, not
  evidence; the court is the evidence. The court outranks the worker in
  BOTH directions:

    * a fabricated `:alive` never promotes: `Lease.close/4` falsifies it to
      `:build_broken` on a court fail, a worker-supplied `fabric_verifier`
      key is dropped (never merged), and this predicate accepts only the
      fabric's own `"pass"` verdict;
    * an honest `:partial_alive` on a court-pass head no longer burns a
      worker session: before 2026-09-19 this loop demanded `outcome ==
      :alive` even when the court had passed the exact head, so every
      honestly-closed item was re-dispatched for one extra full worker
      session purely to manufacture the word `alive` (observed live,
      campaign 9b9efe2c: attempt 1 court-pass + honest `partial_alive` ->
      attempt 2 a full re-dispatch of the same item).

  ## Acceptance rule

  A receipt is accepted WITHOUT re-dispatch iff ALL of:

    * `court == "pass"` -- `fabric_verifier.status == "pass"`;
    * `head_verified == true` -- the court passed against the exact head
      git confirmed (no confirmed head = no confirmed subject);
    * the standing is honest -- `outcome` in `[:alive, :partial_alive]`.

  Everything else repairs with a reason for the ticket history: a court
  fail (falsified evidence), a court timeout/error (unverifiable), a
  receipt with no court verdict at all (standing alone never promotes),
  `head_verified: false`, or a terminal standing
  (`:build_broken`/`:refused`/`:blocked`/`:unsupported`).

  Seam: `config :xaas, :ultracode_judge_accept_court_verified_partial`
  (default true). `false` restores the strict alive-only predicate; the
  court's authority is untouched either way -- this seam can only ever
  *keep* a court-pass head, never accept around a non-pass verdict.
  """
  @spec judge_receipt(Receipt.t()) :: :accept | {:repair, String.t()}
  def judge_receipt(%Receipt{} = receipt) do
    fv = receipt.evidence["fabric_verifier"]

    cond do
      accepted?(receipt, fv) -> :accept
      is_map(fv) -> {:repair, court_failure_text(receipt.outcome, fv)}
      true -> {:repair, "closed #{receipt.outcome} with no fabric verifier verdict"}
    end
  end

  # The acceptance rule, one clause per law above. `receipt.outcome` is the
  # FABRIC-adjusted standing (`Lease.close/4` may falsify or downgrade the
  # worker's claim before sealing), so honesty here means "the sealed
  # standing is in the alive family", and the court-pass conjunct is what
  # makes that family promotable.
  defp accepted?(%Receipt{} = receipt, fv) do
    court_pass? = is_map(fv) and fv["status"] == "pass"
    head_verified? = receipt.evidence["head_verified"] == true
    honest_standing? = receipt.outcome in [:alive, :partial_alive]

    court_pass? and head_verified? and honest_standing? and
      (receipt.outcome == :alive or accept_court_verified_partial?())
  end

  defp accept_court_verified_partial? do
    Application.get_env(:xaas, :ultracode_judge_accept_court_verified_partial, true)
  end

  defp reap(epoch, ctx) do
    ledger(ctx, :reap, %{epoch_id: epoch.id, leased: not is_nil(epoch.lease_token)})

    if epoch.lease_token do
      _ = Lease.refuse(epoch.lease_token, :worker_no_close, %{"reaped_by" => "xaas-autonomic"})
    else
      # No live lease to refuse through -- same terminal disposition, and
      # the SAME receipt invariant (`terminal epoch => receipt`): before
      # this seal, a worker that died un-claimed left a `:failed` epoch
      # with no receipt at all.
      case epoch
           |> Ash.Changeset.for_update(:mark_failed, %{}, authorize?: false)
           |> Ash.update() do
        {:ok, failed} ->
          Receipt
          |> Ash.Changeset.for_create(
            :seal,
            %{
              epoch_id: failed.id,
              subject: failed.exact_subject,
              outcome: :refused,
              evidence: %{"reaped_by" => "xaas-autonomic", "refusal_reason" => "worker_no_close"},
              sealed_at: DateTime.utc_now()
            },
            authorize?: false
          )
          |> Ash.create()

        {:error, _} ->
          {:error, :reap_failed}
      end
    end

    {:failed, "worker ended without closing the lease"}
  end

  defp court_failure_text(outcome, fv) do
    findings =
      case fv["court_receipt"] do
        %{"observation" => %{"gates" => gates}} when is_list(gates) ->
          gates
          |> Enum.reject(&(&1["pass"] == true))
          |> Enum.map_join("; ", fn g ->
            detail = g["detail"] || inspect(Map.drop(g, ~w(id pass kind ms)))
            "#{g["id"]}: #{String.slice(to_string(detail), 0, 400)}"
          end)

        _ ->
          steps = fv["steps"] || []
          tail = steps |> List.last() |> then(&((&1 || %{})["output_tail"] || ""))
          "#{fv["reason"] || fv["status"]} #{String.slice(tail, -600, 600)}"
      end

    "court verdict #{fv["status"]} (receipt outcome #{outcome}): #{findings}"
  end

  defp summarize(nil), do: nil

  defp summarize(fv) do
    receipt = fv["court_receipt"] || %{}

    %{
      "status" => fv["status"],
      "suite" => fv["suite"],
      "argv_sha256" => fv["argv_sha256"],
      "standing" => receipt["standing"],
      "result_digest" => receipt["resultDigest"],
      "receipt_id" => receipt["receiptId"]
    }
  end

  defp errored(item, reason) do
    %{
      item: item["id"],
      repo: item["repo"],
      status: :errored,
      reason: inspect(reason),
      attempts: 0,
      history: []
    }
  end

  # ------------------------------------------------------------------
  # Pacing (top-up semaphore, halves on rate refusal)
  # ------------------------------------------------------------------

  defp with_slot(ctx, fun) do
    acquire(ctx.sem)

    try do
      fun.()
    after
      Agent.update(ctx.sem, &%{&1 | in_flight: &1.in_flight - 1})
    end
  end

  defp acquire(sem) do
    case Agent.get_and_update(sem, fn s ->
           if s.in_flight < s.limit,
             do: {:ok, %{s | in_flight: s.in_flight + 1}},
             else: {:wait, s}
         end) do
      :ok ->
        :ok

      :wait ->
        Process.sleep(150)
        acquire(sem)
    end
  end

  defp halve(ctx), do: Agent.update(ctx.sem, &%{&1 | limit: max(1, div(&1.limit, 2))})

  # ------------------------------------------------------------------
  # Default worker: the in-family dispatch boundary -- one real gated
  # headless zcode/GLM turn per attempt (see Xaas.Ultracode.Dispatch,
  # which owns command construction, timeout/kill, failover-class
  # retry-once, output log, and receipt attachment). The legacy path
  # (the bash dispatcher's directed --epoch mode) stays reachable via
  # `worker: &Autonomic.script_dispatch_worker/2`.
  # ------------------------------------------------------------------

  defp dispatch_worker(epoch, ctx) do
    Xaas.Ultracode.Dispatch.autonomic_worker(epoch, ctx)
  end

  @doc false
  @spec script_dispatch_worker(Epoch.t(), map()) :: :ok | :rate_limited | {:error, term()}
  def script_dispatch_worker(epoch, ctx) do
    script = Path.join(ctx.project_root, "scripts/xaas-glm-failover-dispatcher.sh")
    File.mkdir_p!(ctx.state_dir)

    case System.cmd("bash", [script, "--epoch", epoch.id],
           env: [{"STATE_DIR", ctx.state_dir}],
           stderr_to_stdout: true
         ) do
      {_out, 0} -> :ok
      {_out, 75} -> :rate_limited
      {out, code} -> {:error, {:dispatcher_exit, code, String.slice(out, -300, 300)}}
    end
  end

  # ------------------------------------------------------------------
  # Promote, verify integration, receipt
  # ------------------------------------------------------------------

  defp finish(ctx, items, results) do
    done =
      results
      |> Enum.filter(&(&1.status == :done))
      |> Enum.sort_by(sort_key(ctx))

    {integration, merged, conflicted} = promote(done, ctx)
    canonical = canonical(integration, ctx)

    standing = standing(items, merged, canonical, ctx)

    report =
      if ctx.multi? do
        multi_report(ctx, items, results, standing, integration, merged, conflicted, canonical)
      else
        single_report(ctx, items, results, standing, integration, merged, conflicted, canonical)
      end

    path = Path.join(ctx.out_dir, "receipt.json")
    File.write!(path, Jason.encode!(report, pretty: true))
    ledger(ctx, :final, %{standing: standing, receipt: path})
    {:ok, Map.put(report, "receipt_path", path)}
  end

  defp sort_key(%{multi?: true}), do: &{&1.repo, &1.item}
  defp sort_key(_ctx), do: & &1.item

  # Item entries: the historical take-list for a single-repo wave
  # (byte-for-byte); a multi-repo wave adds each item's "repo".
  defp item_entries(ctx, results) do
    keys = [
      :item,
      :status,
      :attempts,
      :head,
      :epoch_id,
      :run_id,
      :receipt_id,
      :executor,
      :fabric_verifier,
      :reason
    ]

    Enum.map(results, fn r ->
      entry =
        r
        |> Map.take(keys)
        |> Map.put(:history, Enum.map(r.history, &stringify/1))
        |> Map.new(fn {k, v} -> {to_string(k), v} end)
        |> Map.update!("status", &to_string/1)

      if ctx.multi?, do: Map.put(entry, "repo", r.repo), else: entry
    end)
  end

  # The historical report, unchanged for single-repo waves.
  defp single_report(ctx, items, results, standing, integration, merged, conflicted, canonical) do
    %{
      "schema" => "xaas.autonomic-loop-receipt/1",
      "standing" => standing,
      "repo" => ctx.repo,
      "base_sha" => ctx.base_sha,
      "started_at" => DateTime.to_iso8601(ctx.started_at),
      "finished_at" => DateTime.to_iso8601(DateTime.utc_now()),
      "human_inputs" => 0,
      "backlog" => Enum.map(items, & &1["id"]),
      "items" => item_entries(ctx, results),
      "integration" =>
        integration &&
          Map.take(integration, [:branch, :head, :worktree])
          |> Map.new(fn {k, v} -> {to_string(k), v} end),
      "merged" => merged,
      "merge_conflicts" => conflicted,
      "canonical" => canonical,
      "non_claims" => [
        "Not a proof of open-ended or long-horizon autonomy.",
        "One repository, one model, one bounded backlog family.",
        "Nothing was pushed; the integration branch is local."
      ]
    }
  end

  # The multi-repo report: every section carries its repo. There is no
  # single "integration" (each repo integrates into its own worktree), so
  # "integration" is nil and "integrations" is the per-repo map.
  defp multi_report(ctx, items, results, standing, integrations, merged, conflicted, canonical) do
    %{
      "schema" => "xaas.autonomic-loop-receipt/1",
      "standing" => standing,
      "repo" => ctx.repo,
      "repos" => ctx.repos,
      "base_shas" => ctx.base_shas,
      "started_at" => DateTime.to_iso8601(ctx.started_at),
      "finished_at" => DateTime.to_iso8601(DateTime.utc_now()),
      "human_inputs" => 0,
      "backlog" => Enum.map(items, &%{"item" => &1["id"], "repo" => &1["repo"]}),
      "items" => item_entries(ctx, results),
      "integration" => nil,
      "integrations" =>
        Map.new(integrations, fn {repo, integ} ->
          {repo,
           integ
           |> Map.take([:branch, :head, :worktree])
           |> Map.new(fn {k, v} -> {to_string(k), v} end)}
        end),
      "merged" => merged,
      "merge_conflicts" => conflicted,
      "canonical" => canonical,
      "non_claims" => [
        "Not a proof of open-ended or long-horizon autonomy.",
        "One model, bounded backlog families across #{length(ctx.repos)} registered repositories.",
        "Nothing was pushed; the integration branches are local."
      ]
    }
  end

  defp stringify(%{} = m), do: Map.new(m, fn {k, v} -> {to_string(k), v} end)

  defp promote([], ctx) do
    if ctx.multi?, do: {%{}, [], []}, else: {nil, [], []}
  end

  defp promote(done, ctx) do
    if ctx.multi? do
      promote_per_repo(done, ctx)
    else
      promote_one_repo(done, ctx.repo, ctx)
    end
  end

  # Historical single-repo promotion: ONE integration worktree, ONE branch,
  # item-id lists. Byte-for-byte the pre-multi-repo behavior ("aps" keeps
  # the aps-integration/aps-autonomic names).
  defp promote_one_repo(done, repo, ctx) do
    name = "#{repo}-integration-#{ctx.nonce}"
    branch = "#{repo}-autonomic-#{ctx.nonce}"

    with {:ok, wt} <- Worktrees.provision(repo, ctx.base_shas[repo], name),
         {_, 0} <-
           System.cmd("git", ["-C", wt, "checkout", "-q", "-b", branch], stderr_to_stdout: true) do
      {merged, conflicted} =
        Enum.reduce(done, {[], []}, fn r, {ok, bad} ->
          case System.cmd(
                 "git",
                 [
                   "-C",
                   wt,
                   "merge",
                   "--no-ff",
                   "-m",
                   "merge: #{r.item} (receipt #{r.receipt_id})",
                   r.head
                 ],
                 env: @git_env,
                 stderr_to_stdout: true
               ) do
            {_, 0} ->
              ledger(ctx, :merged, item_data(ctx, r, %{item: r.item, head: r.head}))
              {ok ++ [r.item], bad}

            {out, _} ->
              System.cmd("git", ["-C", wt, "merge", "--abort"], stderr_to_stdout: true)

              ledger(
                ctx,
                :merge_conflict,
                item_data(ctx, r, %{item: r.item, output: String.slice(out, -300, 300)})
              )

              {ok, bad ++ [r.item]}
          end
        end)

      {%{branch: branch, worktree: wt, head: git!(wt, ["rev-parse", "HEAD"])}, merged, conflicted}
    else
      other ->
        ledger(ctx, :promotion_failed, %{reason: inspect(other)})
        {nil, [], Enum.map(done, & &1.item)}
    end
  end

  # Multi-repo promotion: each repo's done items merge into THAT repo's own
  # integration worktree (a head from one repository can never merge into
  # another's). Still the one serialized shared-state step; serial per repo
  # within it. Merged/conflicted entries are tagged {"repo", "item"}.
  defp promote_per_repo(done, ctx) do
    done
    |> Enum.group_by(& &1.repo)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {repo, repo_done} -> {repo, promote_one_repo(repo_done, repo, ctx)} end)
    |> Enum.reduce({%{}, [], []}, fn
      {repo, {integ, merged_ids, conflicted_ids}}, {ints, merged, conflicted} when integ != nil ->
        {Map.put(ints, repo, integ),
         merged ++ Enum.map(merged_ids, &%{"repo" => repo, "item" => &1}),
         conflicted ++ Enum.map(conflicted_ids, &%{"repo" => repo, "item" => &1})}

      {repo, {nil, _merged_ids, ids}}, {ints, merged, conflicted} ->
        {ints, merged, conflicted ++ Enum.map(ids, &%{"repo" => repo, "item" => &1})}
    end)
  end

  defp canonical(integrations, ctx) do
    if ctx.multi? do
      Map.new(integrations, fn {repo, integ} -> {repo, canonical_one(integ, ctx)} end)
    else
      canonical_one(integrations, ctx)
    end
  end

  defp canonical_one(nil, _ctx), do: %{"status" => "skipped", "reason" => "no integration branch"}

  defp canonical_one(%{worktree: wt, head: head}, ctx) do
    case Map.get(ctx, :canonical_suite) do
      nil ->
        %{"status" => "skipped", "reason" => "no canonical suite configured"}

      suite ->
        {:ok, result} =
          Verifier.run(suite, %{
            worktree: wt,
            head: head,
            run_id: Ecto.UUID.generate(),
            epoch_id: Ecto.UUID.generate(),
            executor: "xaas-autonomic-controller"
          })

        ledger(ctx, :canonical, %{suite: suite, status: result["status"]})
        result
    end
  end

  defp standing(items, merged, canonical, ctx) do
    if ctx.multi? do
      all_pass = canonical |> Map.values() |> Enum.all?(&(&1["status"] == "pass"))

      cond do
        items != [] and length(merged) == length(items) and all_pass -> "ALIVE"
        merged != [] and all_pass -> "PARTIAL_ALIVE"
        true -> "BLOCKED"
      end
    else
      cond do
        items != [] and length(merged) == length(items) and canonical["status"] == "pass" ->
          "ALIVE"

        merged != [] and canonical["status"] == "pass" ->
          "PARTIAL_ALIVE"

        true ->
          "BLOCKED"
      end
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp ledger(ctx, event, data) do
    line =
      Jason.encode!(%{ts: DateTime.to_iso8601(DateTime.utc_now()), event: event, data: data}) <>
        "\n"

    File.mkdir_p!(Path.dirname(ctx.ledger))
    File.write!(ctx.ledger, line, [:append])
  end

  defp git!(repo, args) do
    {out, 0} = System.cmd("git", ["-C", repo | args], stderr_to_stdout: true)
    String.trim(out)
  end
end
