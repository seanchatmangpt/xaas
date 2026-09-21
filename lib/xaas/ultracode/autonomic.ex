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
    3. **Act.** A worker (default: the hardened dispatcher in directed
       `--epoch` mode, i.e. a gated headless zcode/GLM session) claims exactly
       that epoch and constructs. Concurrency is bounded by a top-up semaphore
       that halves on a provider rate refusal (APS swarm pacing law).
    4. **Verify.** The fabric, not the worker, decides done: `Lease.close/4`
       runs the verifier suite (`Xaas.Ultracode.Verifier`) against the exact
       closed head and seals the receipt.
    5. **Repair.** A non-alive receipt appends the court's findings to the
       ticket history and starts attempt n+1 on the SAME worktree (bounded);
       an exhausted item is reported `blocked` with its full history, never
       dropped. A worker that dies without closing is reaped (its lease is
       refused) and counted as a failed attempt.
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
  launches the real dispatcher; tests pass a scripted protocol client that
  really claims, edits, commits and closes through `Xaas.Ultracode.Lease`.
  """

  alias Xaas.Ultracode.{Epoch, Lease, Receipt, Run, Verifier, Worktrees}

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
  next to the ledger. Options: `:repo`, `:base_sha`, `:only` (item ids),
  `:suite`, `:canonical_suite` (nil to skip), `:provider`, `:capacity`,
  `:max_attempts`, `:worker`, `:ledger`, `:state_dir`, `:project_root`.
  """
  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(opts \\ []) do
    ctx = build_ctx(Keyword.merge(@defaults, opts))
    File.mkdir_p!(ctx.out_dir)
    ledger(ctx, :start, %{repo: ctx.repo, base_sha: ctx.base_sha, capacity: ctx.capacity})

    with {:ok, items} <- sense(ctx) do
      ledger(ctx, :sensed, %{items: Enum.map(items, & &1["id"])})
      {:ok, sem} = Agent.start_link(fn -> %{limit: ctx.capacity, in_flight: 0} end)
      ctx = Map.put(ctx, :sem, sem)

      results =
        items
        |> Task.async_stream(&process_item(&1, ctx),
          max_concurrency: max(length(items), 1),
          timeout: :infinity,
          ordered: true
        )
        |> Enum.zip(items)
        |> Enum.map(fn
          {{:ok, result}, _item} -> result
          {{:exit, reason}, item} -> errored(item, {:task_exit, reason})
        end)

      Agent.stop(sem)
      finish(ctx, items, results)
    end
  end

  # ------------------------------------------------------------------
  # Context
  # ------------------------------------------------------------------

  @doc false
  def new_ctx(opts), do: build_ctx(Keyword.merge(@defaults, opts))

  defp build_ctx(opts) do
    repo = Keyword.fetch!(opts, :repo)
    repo_path = :xaas |> Application.get_env(:ultracode_repos, %{}) |> Map.fetch!(repo)
    ticket_dir = Application.fetch_env!(:xaas, :ultracode_ticket_dir)
    base_sha = Keyword.get(opts, :base_sha) || git!(repo_path, ["rev-parse", "HEAD"])
    nonce = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    out_dir = Path.join(ticket_dir, "autonomic-#{nonce}")

    opts
    |> Map.new()
    |> Map.merge(%{
      repo_path: repo_path,
      ticket_dir: ticket_dir,
      base_sha: base_sha,
      nonce: nonce,
      out_dir: out_dir,
      ledger: Keyword.get(opts, :ledger, Path.join(out_dir, "ledger.ndjson")),
      state_dir: Keyword.get(opts, :state_dir, Path.join(out_dir, "dispatch")),
      project_root: Keyword.get(opts, :project_root, File.cwd!()),
      worker: Keyword.get(opts, :worker, &dispatch_worker/2),
      started_at: DateTime.utc_now()
    })
  end

  # ------------------------------------------------------------------
  # Sense
  # ------------------------------------------------------------------

  @doc false
  def sense(ctx) do
    name = "aps-sense-#{ctx.nonce}"

    with {:ok, path} <- Worktrees.provision(ctx.repo, ctx.base_sha, name) do
      try do
        script = Application.app_dir(:xaas, "priv/verifiers/aps_backlog.py")

        case System.cmd("python3", [script, "--repo", path],
               env: [{"PYTHONDONTWRITEBYTECODE", "1"}],
               stderr_to_stdout: false
             ) do
          {out, 0} ->
            %{"items" => items} = Jason.decode!(out)
            only = Map.get(ctx, :only)
            {:ok, if(only, do: Enum.filter(items, &(&1["id"] in only)), else: items)}

          {out, code} ->
            {:error, {:backlog_failed, code, String.slice(out, -500, 500)}}
        end
      after
        Worktrees.cleanup(ctx.repo, path)
      end
    end
  end

  # ------------------------------------------------------------------
  # Per-item lifecycle
  # ------------------------------------------------------------------

  defp process_item(item, ctx) do
    name = "aps-#{item["id"]}-#{ctx.nonce}"

    with {:ok, worktree} <- Worktrees.provision(ctx.repo, ctx.base_sha, name) do
      ledger(ctx, :worktree, %{item: item["id"], path: worktree})
      attempt(item, worktree, 1, [], 0, ctx)
    else
      {:error, reason} -> errored(item, {:provision_failed, reason})
    end
  rescue
    error -> errored(item, {:crashed, Exception.message(error)})
  end

  defp attempt(item, worktree, n, history, _rate_used, ctx) when n > ctx.max_attempts do
    ledger(ctx, :item_blocked, %{item: item["id"], attempts: n - 1})
    %{item: item["id"], status: :blocked, attempts: n - 1, worktree: worktree, history: history}
  end

  defp attempt(item, worktree, n, history, rate_used, ctx) do
    {run, epoch} = create_run_and_epoch(item, worktree, n, history, ctx)

    ledger(ctx, :attempt_start, %{
      item: item["id"],
      attempt: n,
      run_id: run.id,
      epoch_id: epoch.id
    })

    result = with_slot(ctx, fn -> ctx.worker.(epoch, ctx) end)

    ledger(ctx, :worker_returned, %{
      item: item["id"],
      attempt: n,
      epoch_id: epoch.id,
      result: inspect(result)
    })

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
            ledger(ctx, :item_done, %{
              item: item["id"],
              attempt: n,
              epoch_id: epoch.id,
              receipt_id: receipt.id
            })

            %{
              item: item["id"],
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
            ledger(ctx, :attempt_failed, %{item: item["id"], attempt: n, failure: failure})
            attempt(item, worktree, n + 1, history ++ [%{attempt: n, failure: failure}], 0, ctx)
        end
    end
  end

  @doc false
  def create_run_and_epoch(item, worktree, n, history, ctx) do
    File.mkdir_p!(ctx.ticket_dir)

    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{
          goal: repair_goal(item["goal"], history),
          provider: ctx.provider,
          max_cycles: 1,
          verifier_suite: ctx.suite
        },
        authorize?: false
      )
      |> Ash.create()

    File.write!(
      Path.join(ctx.ticket_dir, "#{run.id}.json"),
      Jason.encode!(%{
        schemaVersion: "aps-ticket/1",
        item: item["id"],
        attempt: n,
        base_sha: ctx.base_sha,
        allowed_paths: item["allowed_paths"],
        min_new_tests: item["min_new_tests"],
        min_kill_ratio: item["min_kill_ratio"],
        mutants: item["mutants"],
        history: history
      })
    )

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "aps-autonomic:#{item["id"]}##{n}:#{run.id}",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
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
  @doc false
  def settle(%Epoch{id: id}, ctx) do
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
    fv = receipt.evidence["fabric_verifier"]

    cond do
      receipt.outcome == :alive and is_map(fv) and fv["status"] == "pass" ->
        {:done, receipt, epoch}

      is_map(fv) ->
        {:failed, court_failure_text(receipt.outcome, fv)}

      true ->
        {:failed, "closed #{receipt.outcome} with no fabric verifier verdict"}
    end
  end

  defp reap(epoch, ctx) do
    ledger(ctx, :reap, %{epoch_id: epoch.id, leased: not is_nil(epoch.lease_token)})

    if epoch.lease_token do
      _ = Lease.refuse(epoch.lease_token, :worker_no_close, %{"reaped_by" => "xaas-autonomic"})
    else
      epoch |> Ash.Changeset.for_update(:mark_failed, %{}, authorize?: false) |> Ash.update()
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
    %{item: item["id"], status: :errored, reason: inspect(reason), attempts: 0, history: []}
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
  # Default worker: the hardened dispatcher in directed --epoch mode
  # ------------------------------------------------------------------

  defp dispatch_worker(epoch, ctx) do
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
    done = results |> Enum.filter(&(&1.status == :done)) |> Enum.sort_by(& &1.item)

    {integration, merged, conflicted} = promote(done, ctx)
    canonical = canonical(integration, ctx)

    standing = standing(items, merged, canonical)

    report = %{
      "schema" => "xaas.autonomic-loop-receipt/1",
      "standing" => standing,
      "repo" => ctx.repo,
      "base_sha" => ctx.base_sha,
      "started_at" => DateTime.to_iso8601(ctx.started_at),
      "finished_at" => DateTime.to_iso8601(DateTime.utc_now()),
      "human_inputs" => 0,
      "backlog" => Enum.map(items, & &1["id"]),
      "items" =>
        Enum.map(results, fn r ->
          r
          |> Map.take([
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
          ])
          |> Map.put(:history, Enum.map(r.history, &stringify/1))
          |> Map.new(fn {k, v} -> {to_string(k), v} end)
          |> Map.update!("status", &to_string/1)
        end),
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

    path = Path.join(ctx.out_dir, "receipt.json")
    File.write!(path, Jason.encode!(report, pretty: true))
    ledger(ctx, :final, %{standing: standing, receipt: path})
    {:ok, Map.put(report, "receipt_path", path)}
  end

  defp stringify(%{} = m), do: Map.new(m, fn {k, v} -> {to_string(k), v} end)

  defp promote([], _ctx), do: {nil, [], []}

  defp promote(done, ctx) do
    name = "aps-integration-#{ctx.nonce}"
    branch = "aps-autonomic-#{ctx.nonce}"

    with {:ok, wt} <- Worktrees.provision(ctx.repo, ctx.base_sha, name),
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
              ledger(ctx, :merged, %{item: r.item, head: r.head})
              {ok ++ [r.item], bad}

            {out, _} ->
              System.cmd("git", ["-C", wt, "merge", "--abort"], stderr_to_stdout: true)
              ledger(ctx, :merge_conflict, %{item: r.item, output: String.slice(out, -300, 300)})
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

  defp canonical(nil, _ctx), do: %{"status" => "skipped", "reason" => "no integration branch"}

  defp canonical(%{worktree: wt, head: head}, ctx) do
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

  defp standing(items, merged, canonical) do
    cond do
      items != [] and length(merged) == length(items) and canonical["status"] == "pass" -> "ALIVE"
      merged != [] and canonical["status"] == "pass" -> "PARTIAL_ALIVE"
      true -> "BLOCKED"
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
