defmodule Xaas.Ultracode.SemanticCrown do
  @moduledoc """
  The autonomics crown: receipts are the clock.

  One bounded, real repository condition is taken through the whole
  Semantic-Jira -> XaaS -> Semantic-Jira loop with no ticket edited by hand:

      observation (aps_backlog: a contract with < 3 negative fixtures)
        -> candidate WorkOrder, kernel-admitted and SHACL-admitted   [graph side]
        -> frontier -> execution descriptor                          [graph side]
        -> Run/Epoch/worktree (SemanticWork.materialize)
        -> worker leases the exact Epoch and commits                 [worker]
        -> Lease.close seals it under the aps-dod court              [fabric]
        -> receipt export (SemanticReceipt)
        -> reconciler transition appended to the ledger              [graph side]
        -> a dependent WorkOrder becomes eligible; repeat

  Every graph-side step is a real `mix semantic_jira.*` OS process run in the
  ggen_igniter checkout; the graph side never sees XaaS internals and XaaS
  never interprets the descriptor `bridge`. When the loop ends the state is
  replayed from the ledger and work orders alone, in a fresh OS process, in a
  fresh directory.

  `:controls` closes a crafted bad candidate (vacuous tests) through the same
  fabric and asserts that the reconciler REFUSES it, the ledger is unchanged
  and the work order stays on the frontier.

  Options: `:ggen_igniter_dir` (required), `:mix_env` ("test"), `:repo`
  ("aps"), `:provider`, `:suite`, `:items` (two APS backlog item ids: the first
  is observed, the second is seeded and depends on the first), `:base_sha`,
  `:work_dir`, `:mix_bin`, `:ggen_timeout_s`, `:worker` (2-arity, same protocol as `Autonomic`), `:max_attempts`,
  `:rate_retries`, `:rate_backoff_ms`, `:controls` (`%{transport: :local}` or
  `%{transport: :http, endpoint: url, token: token}`), `:project_root`.
  """

  alias Xaas.Ultracode.{Autonomic, Epoch, Lease, Receipt, SemanticReceipt, SemanticWork}
  alias Xaas.Ultracode.SemanticReceipt.ApsDod
  alias Xaas.Ultracode.Worktrees

  @repository "seanchatmangpt/agile-protocol-specification"
  @court_step "court"
  @court_iri ApsDod.court_iri()
  @evidence_iri ApsDod.evidence_iri()
  @ontology_nodes """
  @prefix sj: <https://ggen-igniter.dev/ontology/semantic-jira#> .
  @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
  @prefix dcterms: <http://purl.org/dc/terms/> .

  sj:court-aps-dod a sj:Court ;
      rdfs:label "APS Chicago definition-of-done court" ;
      dcterms:description "The aps-dod fabric suite: exact-head, independence, scope, no-mock, non-vacuity, canonical-gate and mutation-kill gates over the candidate head, run by XaaS, never by the worker." .

  sj:aps-dod-court-receipt-evidence a sj:EvidenceRequirement ;
      rdfs:label "aps-dod court receipt" ;
      dcterms:description "An ALIVE receipt of the aps-dod court, produced by the fabric verifier for the exact candidate head." .
  """

  @acceptance_gates ~w(CHI-EXACT-HEAD CHI-INDEPENDENT CHI-SCOPE CHI-MOCK CHI-ASSERT CHI-CANONICAL)
  @a_identity "SJ-CROWN-A"
  @b_identity "SJ-CROWN-B"
  @test_file "tests/test_contract_standing.py"

  @vacuous_test """
  import unittest


  class StandingContract(unittest.TestCase):
      def test_alive(self):
          pass

      def test_blocked(self):
          pass

      def test_refused(self):
          pass

      def test_unknown(self):
          pass
  """

  @spec run(keyword()) :: {:ok, map()} | {:error, term()}
  def run(opts) do
    with {:ok, ctx} <- context(opts),
         {:ok, items} <- sense(ctx),
         {:ok, seeded} <- seed(ctx, items),
         {:ok, cycles, halted} <- loop(ctx, seeded, []),
         {:ok, live} <- frontier(ctx, ctx.ledger_path),
         {:ok, replay} <- replay(ctx, live),
         {:ok, controls} <- controls(ctx, seeded) do
      report(ctx, seeded, cycles, halted, live, replay, controls)
    end
  end

  # -- context -------------------------------------------------------------------

  defp context(opts) do
    dir = Keyword.fetch!(opts, :ggen_igniter_dir)
    ticket_dir = Application.fetch_env!(:xaas, :ultracode_ticket_dir)
    nonce = :crypto.strong_rand_bytes(3) |> Base.encode16(case: :lower)
    work_dir = Keyword.get(opts, :work_dir) || Path.join(ticket_dir, "crown-#{nonce}")
    items = Keyword.get(opts, :items, ["contract-standing", "contract-evidence-receipt"])

    cond do
      not File.regular?(Path.join(dir, "mix.exs")) ->
        {:error, {:ggen_igniter_missing, dir}}

      length(items) != 2 ->
        {:error, {:items_must_be_two, items}}

      true ->
        File.mkdir_p!(work_dir)

        base =
          Autonomic.new_ctx(
            repo: Keyword.get(opts, :repo, "aps"),
            provider: Keyword.get(opts, :provider, "zcode"),
            suite: Keyword.get(opts, :suite, "aps-dod"),
            capacity: 1,
            max_attempts: Keyword.get(opts, :max_attempts, 2),
            rate_retries: Keyword.get(opts, :rate_retries, 3),
            rate_backoff_ms: Keyword.get(opts, :rate_backoff_ms, 60_000),
            base_sha: opts[:base_sha],
            only: items,
            ledger: Path.join(work_dir, "crown-events.ndjson"),
            state_dir: Path.join(work_dir, "dispatch"),
            project_root: Keyword.get(opts, :project_root, File.cwd!()),
            worker: Keyword.get(opts, :worker, &dispatch_worker/2)
          )

        {:ok,
         Map.merge(base, %{
           ggen_dir: dir,
           mix_env: Keyword.get(opts, :mix_env, "test"),
           mix_bin: Keyword.get(opts, :mix_bin) || mix_bin(),
           ggen_timeout_s: Keyword.get(opts, :ggen_timeout_s, 900),
           work_dir: work_dir,
           item_ids: items,
           controls: Keyword.get(opts, :controls),
           work_orders_path: Path.join(work_dir, "work-orders.json"),
           ledger_path: Path.join(work_dir, "standing-ledger.ndjson")
         })}
    end
  end

  defp sense(ctx) do
    with {:ok, found} <- Autonomic.sense(ctx) do
      by_id = Map.new(found, &{&1["id"], &1})

      case Enum.map(ctx.item_ids, &Map.get(by_id, &1)) do
        [a, b] when is_map(a) and is_map(b) ->
          log(ctx, :sensed, %{items: ctx.item_ids, base_sha: ctx.base_sha})
          {:ok, %{a: a, b: b, all: found}}

        _ ->
          {:error, {:items_not_in_backlog, ctx.item_ids}}
      end
    end
  end

  # -- observation and seeding ---------------------------------------------------

  defp seed(ctx, %{a: a, b: b, all: all}) do
    dir = Path.join(ctx.work_dir, "seed")
    File.mkdir_p!(dir)

    schema = String.replace_prefix(a["id"], "contract-", "") <> ".schema.json"

    normative =
      "sha256:" <>
        (ctx.repo_path
         |> git_raw(["show", "#{ctx.base_sha}:contracts/#{schema}"])
         |> then(&:crypto.hash(:sha256, &1))
         |> Base.encode16(case: :lower))

    finding = %{
      "normative_model_digest" => normative,
      "observed_model_digest" => SemanticReceipt.digest(a),
      "observation_receipt_digest" => SemanticReceipt.digest(all),
      "delta" => a["goal"]
    }

    # The candidate's court and evidence requirement must already be typed
    # nodes in the canonical graph (SHACL sh:class). The aps-dod court and its
    # evidence node are not in the repository ontology yet, so the admission
    # graph is a work copy of the canonical ontology plus those two nodes.
    ontology_path = Path.join(dir, "ontology.ttl")

    File.write!(
      ontology_path,
      File.read!(Path.join(ctx.ggen_dir, "priv/ggen/semantic-jira-pack/ontology.ttl")) <>
        "\n" <> @ontology_nodes
    )

    base = base_work_order(ctx, a)
    write_json(Path.join(dir, "finding.json"), finding)
    write_json(Path.join(dir, "base-work-order.json"), base)
    candidate_path = Path.join(dir, "candidate.json")

    case ggen(ctx, "semantic_jira.observe", [
           "--finding",
           Path.join(dir, "finding.json"),
           "--base-work-order",
           Path.join(dir, "base-work-order.json"),
           "--identity",
           @a_identity,
           "--ontology",
           ontology_path,
           "--out",
           candidate_path
         ]) do
      {0, %{"work_order" => wo_a, "shacl" => shacl}, _} ->
        wo_b = dependent_work_order(ctx, base, b)
        write_json(ctx.work_orders_path, [wo_a, wo_b])
        log(ctx, :observed, %{candidate: @a_identity, shacl: shacl, seeded: @b_identity})

        {:ok,
         %{
           items: %{@a_identity => a, @b_identity => b},
           shacl: shacl,
           candidate_digest: wo_a["work_order_digest"]
         }}

      {code, json, out} ->
        {:error, {:observation_refused, code, json || excerpt(out)}}
    end
  end

  defp base_work_order(ctx, item) do
    %{
      "identity" => "SJ-CROWN-BASE",
      "title" => "APS contract test hardening",
      "description" => "Chicago-school test hardening of one APS contract schema.",
      "subject" => "semantic-jira:crown:base",
      "repository" => @repository,
      "base_sha" => ctx.base_sha,
      "standing" => "UNKNOWN",
      "evidence_ceiling" => "repository-local",
      "promotion_rule" => "exact-head fabric court receipt",
      "replay_identity" => "semantic-jira:crown:base",
      "dependencies" => [],
      "required_courts" => [@court_iri],
      "required_evidence" => [@evidence_iri],
      "acceptance" => ["CHI-ASSERT"],
      "falsifiers" => ["CHI-MUTATION"],
      "projections" => ["jira", "receipt"],
      "required_receipt_classes" => ["verification"],
      "path_scope" => item["allowed_paths"],
      "authority_requirement" => "NONE",
      "replay_required" => false
    }
  end

  defp dependent_work_order(ctx, base, item) do
    Map.merge(base, %{
      "identity" => @b_identity,
      "title" => "APS contract test hardening: #{item["id"]}",
      "description" => item["goal"],
      "subject" => "semantic-jira:crown:#{item["id"]}",
      "replay_identity" => "semantic-jira:crown:#{item["id"]}",
      "base_sha" => ctx.base_sha,
      "acceptance" => @acceptance_gates,
      "falsifiers" => ["CHI-MUTATION"],
      "path_scope" => item["allowed_paths"],
      "dependencies" => [
        %{"upstream" => @a_identity, "type" => "requiresReceipt", "required_standing" => "ALIVE"}
      ]
    })
  end

  # -- the loop ---------------------------------------------------------------------

  defp loop(ctx, seeded, cycles) do
    with {:ok, %{"eligible" => eligible}} <- frontier(ctx, ctx.ledger_path) do
      case Enum.map(eligible, & &1["identity"]) do
        [] ->
          {:ok, Enum.reverse(cycles), nil}

        [identity | _] when length(cycles) < 4 ->
          case execute(ctx, seeded, identity, 1, [], 0) do
            {:ok, cycle} -> loop(ctx, seeded, [cycle | cycles])
            {:blocked, cycle} -> {:ok, Enum.reverse([cycle | cycles]), identity}
          end

        [identity | _] ->
          {:ok, Enum.reverse(cycles), identity}
      end
    end
  end

  defp execute(ctx, _seeded, identity, attempt, history, _rate_used)
       when attempt > ctx.max_attempts do
    log(ctx, :blocked, %{identity: identity, history: history})
    {:blocked, %{"identity" => identity, "status" => "blocked", "history" => history}}
  end

  defp execute(ctx, seeded, identity, attempt, history, rate_used) do
    dir = Path.join(ctx.work_dir, "#{identity}-#{attempt}-#{rate_used}")
    File.mkdir_p!(dir)
    descriptor_path = Path.join(dir, "descriptor.json")

    with {0, _, _} <-
           ggen(ctx, "semantic_jira.descriptor", [
             "--work-orders",
             ctx.work_orders_path,
             "--ledger",
             ctx.ledger_path,
             "--identity",
             identity,
             "--alias",
             "#{@repository}=#{ctx.repo}",
             "--verifier-suite",
             ctx.suite,
             "--out",
             descriptor_path
           ]),
         descriptor = descriptor_path |> File.read!() |> Jason.decode!(),
         {:ok, %{run: run, epoch: epoch, worktree: worktree}} <-
           SemanticWork.materialize(descriptor) do
      write_ticket(ctx, run, Map.fetch!(seeded.items, identity), attempt, history)
      log(ctx, :materialized, %{identity: identity, run_id: run.id, epoch_id: epoch.id})
      worker_result = ctx.worker.(epoch, ctx)

      log(ctx, :worker_returned, %{
        identity: identity,
        epoch_id: epoch.id,
        result: inspect(worker_result)
      })

      settled = Autonomic.settle(epoch, ctx)

      case worker_result do
        :rate_limited ->
          Worktrees.cleanup(ctx.repo, worktree)

          if rate_used < ctx.rate_retries do
            Process.sleep(ctx.rate_backoff_ms)
            execute(ctx, seeded, identity, attempt, history, rate_used + 1)
          else
            execute(ctx, seeded, identity, attempt + 1, history ++ ["rate_limited"], 0)
          end

        _ ->
          case finish(ctx, dir, descriptor, epoch, run) do
            {:ok, cycle} ->
              {:ok, Map.merge(cycle, %{"attempts" => attempt, "worktree" => worktree})}

            {:failed, reason} ->
              Worktrees.cleanup(ctx.repo, worktree)
              note = "attempt #{attempt}: #{reason} (settle=#{inspect(elem(settled, 0))})"
              log(ctx, :attempt_failed, %{identity: identity, note: note})
              execute(ctx, seeded, identity, attempt + 1, history ++ [note], 0)
          end
      end
    else
      {code, json, out} when is_integer(code) ->
        {:blocked,
         %{
           "identity" => identity,
           "status" => "blocked",
           "history" =>
             history ++ ["descriptor refused: #{inspect(json || String.slice(out, -300, 300))}"]
         }}

      {:error, reason} ->
        {:blocked,
         %{
           "identity" => identity,
           "status" => "blocked",
           "history" => history ++ ["materialize refused: #{inspect(reason)}"]
         }}
    end
  end

  # Exports the sealed receipt, maps it onto the reconciler contract and appends
  # the transition. A refusal at any step is a failed attempt, never a promotion.
  defp finish(ctx, dir, descriptor, epoch, run) do
    receipt_path = Path.join(dir, "xaas-receipt.json")
    reconciler_path = Path.join(dir, "reconciler-receipt.json")

    with {:export, {:ok, export}} <- {:export, SemanticReceipt.export(epoch.id)},
         :ok <- File.write(receipt_path, Jason.encode!(export)),
         {:map, {0, _mapped, _}} <-
           {:map,
            ggen(ctx, "semantic_jira.xaas_receipt", [
              "--bridge",
              Path.join(dir, "descriptor.json"),
              "--xaas-receipt",
              receipt_path,
              "--out",
              reconciler_path
            ])},
         {:reconcile, {0, event, _}} <-
           {:reconcile,
            ggen(ctx, "semantic_jira.reconcile", [
              "--work-orders",
              ctx.work_orders_path,
              "--ledger",
              ctx.ledger_path,
              "--receipt",
              reconciler_path
            ])} do
      fresh = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
      identity = descriptor["bridge"]["identity"]
      log(ctx, :transition, %{identity: identity, epoch_id: epoch.id, event: event})

      {:ok,
       %{
         "identity" => identity,
         "status" => "done",
         "run_id" => run.id,
         "epoch_id" => epoch.id,
         "executor" => fresh.leased_to,
         "receipt_id" => export["receipt_id"],
         "receipt_digest" => export["receipt_digest"],
         "outcome" => export["outcome"],
         "fabric_verifier" => export["fabric_verifier"]["status"],
         "transition" => event
       }}
    else
      {:export, {:error, reason}} ->
        {:failed, "no exportable receipt: #{inspect(reason)}"}

      {:map, {code, json, out}} ->
        {:failed, "receipt refused (exit #{code}): #{brief(json, out)}"}

      {:reconcile, {code, json, out}} ->
        {:failed, "reconcile refused (exit #{code}): #{brief(json, out)}"}

      {:error, reason} ->
        {:failed, "receipt file: #{inspect(reason)}"}
    end
  end

  defp write_ticket(ctx, run, item, attempt, history) do
    File.mkdir_p!(ctx.ticket_dir)

    File.write!(
      Path.join(ctx.ticket_dir, "#{run.id}.json"),
      Jason.encode!(%{
        schemaVersion: "aps-ticket/1",
        item: item["id"],
        attempt: attempt,
        base_sha: ctx.base_sha,
        allowed_paths: item["allowed_paths"],
        min_new_tests: item["min_new_tests"],
        min_kill_ratio: item["min_kill_ratio"],
        mutants: item["mutants"],
        history: history
      })
    )
  end

  # -- replay ---------------------------------------------------------------------

  defp frontier(ctx, ledger) do
    case ggen(ctx, "semantic_jira.frontier", [
           "--work-orders",
           ctx.work_orders_path,
           "--ledger",
           ledger
         ]) do
      {0, json, _} -> {:ok, json}
      {code, json, out} -> {:error, {:frontier_failed, code, brief(json, out)}}
    end
  end

  defp replay(ctx, live) do
    dir = Path.join(ctx.work_dir, "replay")
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    File.cp!(ctx.work_orders_path, Path.join(dir, "work-orders.json"))

    if File.exists?(ctx.ledger_path),
      do: File.cp!(ctx.ledger_path, Path.join(dir, "standing-ledger.ndjson"))

    replay_ctx = %{ctx | work_orders_path: Path.join(dir, "work-orders.json")}

    with {:ok, replayed} <- frontier(replay_ctx, Path.join(dir, "standing-ledger.ndjson")) do
      keys = ~w(eligible blocked standings events ledger_tail)

      {:ok,
       %{
         "equal" => Map.take(live, keys) == Map.take(replayed, keys),
         "standings" => replayed["standings"],
         "ledger_tail" => replayed["ledger_tail"]
       }}
    end
  end

  # -- negative control -------------------------------------------------------------

  defp controls(%{controls: nil}, _seeded), do: {:ok, nil}

  defp controls(ctx, seeded) do
    dir = Path.join(ctx.work_dir, "control")
    File.mkdir_p!(dir)
    ledger = Path.join(dir, "standing-ledger.ndjson")
    control_ctx = %{ctx | ledger_path: ledger}
    descriptor_path = Path.join(dir, "descriptor.json")

    with {0, _, _} <-
           ggen(control_ctx, "semantic_jira.descriptor", [
             "--work-orders",
             ctx.work_orders_path,
             "--ledger",
             ledger,
             "--identity",
             @a_identity,
             "--alias",
             "#{@repository}=#{ctx.repo}",
             "--verifier-suite",
             ctx.suite,
             "--out",
             descriptor_path
           ]),
         descriptor = descriptor_path |> File.read!() |> Jason.decode!(),
         # Same work, fresh ledger: the control needs its own exact-SHA worktree
         # (its name derives from work order + checkpoint + graph digest), so
         # its checkpoint IRI carries a control marker.
         descriptor = Map.update!(descriptor, "checkpoint_iri", &(&1 <> ":control")),
         {:ok, %{run: run, epoch: epoch, worktree: worktree}} <-
           SemanticWork.materialize(descriptor) do
      write_ticket(ctx, run, seeded.items[@a_identity], 1, [])
      close_bad_candidate(ctx.controls, ctx, epoch, worktree)

      sealed = closing(epoch.id)
      reconciler_path = Path.join(dir, "reconciler-receipt.json")
      xaas_path = Path.join(dir, "xaas-receipt.json")
      {:ok, export} = SemanticReceipt.export(epoch.id)
      File.write!(xaas_path, Jason.encode!(export))

      mapped =
        ggen(control_ctx, "semantic_jira.xaas_receipt", [
          "--bridge",
          descriptor_path,
          "--xaas-receipt",
          xaas_path,
          "--out",
          reconciler_path
        ])

      reconcile =
        case mapped do
          {0, _, _} ->
            ggen(control_ctx, "semantic_jira.reconcile", [
              "--work-orders",
              ctx.work_orders_path,
              "--ledger",
              ledger,
              "--receipt",
              reconciler_path
            ])

          other ->
            other
        end

      {:ok, after_frontier} = frontier(control_ctx, ledger)
      Worktrees.cleanup(ctx.repo, worktree)

      failures =
        get_in(sealed.evidence, ["fabric_verifier", "court_receipt", "observation", "failures"]) ||
          []

      result = %{
        "control" => "vacuous-tests",
        "claimed" => "alive",
        "sealed_outcome" => to_string(sealed.outcome),
        "failed_gates" => Enum.map(failures, & &1["id"]),
        "mapped_exit" => elem(mapped, 0),
        "reconcile_exit" => elem(reconcile, 0),
        "reconcile_refusal" => elem(reconcile, 1),
        "ledger_events" => event_count(after_frontier["events"]),
        "still_eligible" => Enum.map(after_frontier["eligible"], & &1["identity"]),
        "epoch_id" => epoch.id
      }

      pass =
        result["sealed_outcome"] == "build_broken" and result["mapped_exit"] == 0 and
          result["reconcile_exit"] == 1 and result["ledger_events"] == 0 and
          @a_identity in result["still_eligible"]

      {:ok, Map.put(result, "pass", pass)}
    else
      {code, json, out} when is_integer(code) ->
        {:error, {:control_descriptor_refused, code, brief(json, out)}}

      {:error, reason} ->
        {:error, {:control_materialize_refused, reason}}
    end
  end

  defp close_bad_candidate(%{transport: :local}, ctx, epoch, worktree) do
    {:ok, claimed, token, _run} =
      Lease.claim_next(ctx.provider, "crown-control", epoch_id: epoch.id)

    commit_candidate(claimed.worktree || worktree)
    head = git(worktree, ["rev-parse", "HEAD"])
    Lease.close(token, head, :alive, %{"note" => "control claims ALIVE"})
    :ok
  end

  defp close_bad_candidate(%{transport: :http} = http, ctx, epoch, worktree) do
    claim =
      mcp(http, "claim_next", %{
        provider: ctx.provider,
        provider_worker_id: "crown-control",
        epoch_id: epoch.id
      })

    commit_candidate(worktree)

    mcp(http, "close_candidate", %{
      lease_token: claim["lease_token"],
      final_head: git(worktree, ["rev-parse", "HEAD"]),
      outcome: "alive",
      evidence: %{"note" => "control claims ALIVE"}
    })

    :ok
  end

  defp commit_candidate(worktree) do
    full = Path.join(worktree, @test_file)
    File.mkdir_p!(Path.dirname(full))
    File.write!(full, @vacuous_test)

    env = [
      {"GIT_AUTHOR_NAME", "crown-control"},
      {"GIT_AUTHOR_EMAIL", "c@c"},
      {"GIT_COMMITTER_NAME", "crown-control"},
      {"GIT_COMMITTER_EMAIL", "c@c"}
    ]

    {_, 0} = System.cmd("git", ["-C", worktree, "add", "-A"], env: env, stderr_to_stdout: true)

    {_, 0} =
      System.cmd("git", ["-C", worktree, "commit", "-q", "-m", "control candidate"],
        env: env,
        stderr_to_stdout: true
      )
  end

  defp closing(epoch_id) do
    Receipt
    |> Ash.Query.for_read(:for_epoch, %{epoch_id: epoch_id})
    |> Ash.read!(authorize?: false)
    |> Enum.find(&Map.has_key?(&1.evidence, "head_verified"))
  end

  defp mcp(http, tool, args) do
    {:ok, _} = Application.ensure_all_started(:inets)

    body =
      Jason.encode!(%{
        jsonrpc: "2.0",
        id: 1,
        method: "tools/call",
        params: %{name: tool, arguments: args}
      })

    {:ok, {{_, 200, _}, _headers, resp}} =
      :httpc.request(
        :post,
        {String.to_charlist(http.endpoint),
         [{~c"authorization", String.to_charlist("Bearer " <> http.token)}], ~c"application/json",
         body},
        [{:timeout, 300_000}],
        body_format: :binary
      )

    %{"result" => %{"content" => [%{"text" => text}]}} = Jason.decode!(resp)
    Jason.decode!(text)
  end

  # -- report -----------------------------------------------------------------------

  defp report(ctx, seeded, cycles, halted, live, replay, controls) do
    done = Enum.filter(cycles, &(&1["status"] == "done"))

    standing =
      cond do
        halted != nil or Enum.any?(cycles, &(&1["status"] == "blocked")) -> "PARTIAL_ALIVE"
        length(done) != 2 -> "PARTIAL_ALIVE"
        not replay["equal"] -> "BUILD_BROKEN"
        controls && not controls["pass"] -> "BUILD_BROKEN"
        true -> "ALIVE"
      end

    report = %{
      "schemaVersion" => "semantic-autonomics-crown/1",
      "standing" => standing,
      "repository" => @repository,
      "base_sha" => ctx.base_sha,
      "work_dir" => ctx.work_dir,
      "shacl" => seeded.shacl,
      "cycles" => cycles,
      "final_standings" => live["standings"],
      "final_eligible" => Enum.map(live["eligible"], & &1["identity"]),
      "ledger_tail" => live["ledger_tail"],
      "replay" => replay,
      "controls" => controls,
      "human_inputs" => 0
    }

    path = Path.join(ctx.work_dir, "crown-report.json")
    File.write!(path, Jason.encode!(report, pretty: true))
    log(ctx, :report, %{standing: standing, path: path})
    {:ok, Map.put(report, "report_path", path)}
  end

  # -- default worker: the hardened dispatcher in directed --epoch mode -------------

  @doc false
  def dispatch_worker(%Epoch{id: id}, ctx) do
    script = Path.join(ctx.project_root, "scripts/xaas-glm-failover-dispatcher.sh")
    File.mkdir_p!(ctx.state_dir)

    case System.cmd("bash", [script, "--epoch", id],
           env: [{"STATE_DIR", ctx.state_dir}],
           stderr_to_stdout: true
         ) do
      {_out, 0} -> :ok
      {_out, 75} -> :rate_limited
      {_out, 3} -> await(id, 900_000)
      {out, code} -> {:error, {:dispatcher_exit, code, String.slice(out, -300, 300)}}
    end
  end

  # Exit 3 = the epoch is not running/unleased: another dispatcher (the
  # scheduled wave) took it. Wait for that worker to finish it.
  defp await(id, remaining) when remaining <= 0, do: {:error, {:await_timeout, id}}

  defp await(id, remaining) do
    case Ash.get!(Epoch, id, action: :read_unscoped, authorize?: false).state do
      state when state in [:completed, :failed] ->
        :ok

      _ ->
        Process.sleep(5_000)
        await(id, remaining - 5_000)
    end
  end

  # -- helpers ----------------------------------------------------------------------

  # The graph side is a separate project with its own toolchain pin
  # (.tool-versions): run it through the asdf shim from its own directory, with
  # no inherited version override, never through this VM's Elixir.
  defp mix_bin do
    shim = Path.join(System.user_home!(), ".asdf/shims/mix")
    if File.regular?(shim), do: shim, else: System.find_executable("mix")
  end

  # Output goes to a file and stdin is /dev/null: a daemonised grandchild
  # (epmd, a node) cannot hold a pipe open and block the caller, and the task
  # has a hard deadline (perl alarm, exit 142).
  defp ggen(ctx, task, args) do
    out_file = Path.join(ctx.work_dir, "ggen-#{System.unique_integer([:positive])}.out")
    script = ~S(out="$1"; shift; exec "$@" >"$out" 2>&1 </dev/null)

    {_, code} =
      System.cmd(
        "/bin/sh",
        [
          "-c",
          script,
          "sh",
          out_file,
          "perl",
          "-e",
          "alarm shift; exec @ARGV or exit 127",
          Integer.to_string(ctx.ggen_timeout_s),
          ctx.mix_bin,
          task | args
        ],
        cd: ctx.ggen_dir,
        env: [
          {"MIX_ENV", ctx.mix_env},
          {"ASDF_ELIXIR_VERSION", nil},
          {"ASDF_ERLANG_VERSION", nil}
        ]
      )

    out = File.read!(out_file)
    File.rm(out_file)
    {code, last_json(out), out}
  end

  defp last_json(out) do
    out
    |> String.split("\n", trim: true)
    |> Enum.reverse()
    |> Enum.find_value(fn line ->
      line = String.trim(line)

      if String.starts_with?(line, "{") do
        case Jason.decode(line) do
          {:ok, %{} = decoded} -> decoded
          _ -> nil
        end
      end
    end)
  end

  defp event_count(events) when is_list(events), do: length(events)
  defp event_count(events) when is_integer(events), do: events

  defp excerpt(out), do: String.slice(out, 0, 700) <> " ... " <> String.slice(out, -300, 300)

  defp brief(nil, out), do: String.slice(out, -300, 300)
  defp brief(json, _out), do: inspect(json["reason"] || json)

  defp write_json(path, value) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Jason.encode!(value, pretty: true))
  end

  defp log(ctx, event, data) do
    line =
      Jason.encode!(%{ts: DateTime.to_iso8601(DateTime.utc_now()), event: event, data: data}) <>
        "\n"

    File.write!(ctx.ledger, line, [:append])
  end

  defp git(dir, args), do: dir |> git_raw(args) |> String.trim()

  defp git_raw(dir, args) do
    {out, 0} = System.cmd("git", ["-C", dir | args], stderr_to_stdout: true)
    out
  end

  @doc false
  def a_identity, do: @a_identity
  @doc false
  def b_identity, do: @b_identity
  @doc false
  def court_step, do: @court_step
end
