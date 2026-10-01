defmodule Xaas.Sa2a.Court do
  @moduledoc """
  Machine admission court for the SA2A `sa2a_execute` DO edge -- the replacement for the
  human "may this run?" judgement.

  `admit/2` returns `{:ok, verdict}` only when ALL of these hold; otherwise a typed
  `{:error, {:refused, code, detail}}` (never a crash) or `{:error, {:blocked, why}}`
  when the port is unreachable (BLOCKED is an environment fact, not a policy refusal):

  1. the request is well-formed JSON data (`:malformed_request`);
  2. the query matches a declared class of `Xaas.Sa2a.ExecutionPolicy`
     (`:query_not_allowlisted`, `:query_too_long`, `:query_not_bound_to_work_order`);
  3. the compiled rules are `[[pattern, output], ...]` strings within the policy bound
     (`:malformed_compiled_rules`, `:too_many_compiled_rules`);
  4. when the plan carries a preimage fence (`admitted_preimage_hash` and/or `preimage`),
     the plan is fresh: the observed digest of `preimage` (via
     `Xaas.Planning.StalePlanGate.fingerprint/1`) equals the admitted preimage hash
     (`:stale_plan_refusal` with `:malformed_hash` or both hashes as detail). Plans
     without a preimage fence are unaffected -- the fence is opt-in.
  5. a prior SA2A admit receipt exists for the same candidate and work-order digest
     (`:admit_receipt_missing`, `:admit_receipt_not_admitted`,
     `:admit_receipt_digest_mismatch`) AND it is reproducible: re-running the real
     `sa2a_admit` on the receipt's own inputs yields the same `candidate_hash`
     (`:admit_receipt_not_reproducible`) -- a forged or tampered receipt cannot pass;
  6. a plan hash from `sa2a_plan` is bound and reproducible: re-running the real
     `sa2a_plan` on the plan's candidates yields that hash and an `ADMITTED` allocation
     for the work order (`:plan_hash_missing`, `:plan_missing`, `:plan_hash_mismatch`,
     `:plan_does_not_cover_work_order`).

  The verdict carries the idempotency key `sha256(work_order_digest|query|plan_hash)`.
  Verification is by recomputation against the real port, not by trusting caller-supplied
  receipts. The court runs twice on purpose -- as a pre-flight in `Xaas.Sa2a.Executor`
  (a refusal costs no ledger row and cannot burn the idempotency key) and again inside
  the `Xaas.Sa2a.Execution` `:execute` action (so a direct `Xaas.Actuation.run/4` call
  cannot skip it).
  """

  alias Xaas.Actuation.Refusal
  alias Xaas.Planning.StalePlanGate
  alias Xaas.Sa2a.{Bridge, ExecutionPolicy}

  @type refusal :: {:refused, atom(), term()}
  @type verdict :: %{
          idempotency_key: String.t(),
          class_id: String.t(),
          compiled_rules: [[String.t()]] | nil,
          admit_receipt_id: String.t() | nil,
          admit_candidate_hash: String.t(),
          plan_id: String.t(),
          plan_hash: String.t(),
          request: map()
        }

  @busy_retries 50
  @busy_backoff_ms 40

  @doc "The idempotency key binding an execution to its work order, query and plan."
  @spec idempotency_key(String.t(), String.t(), String.t()) :: String.t()
  def idempotency_key(work_order_digest, query, plan_hash) do
    :crypto.hash(:sha256, "#{work_order_digest}|#{query}|#{plan_hash}")
    |> Base.encode16(case: :lower)
  end

  @doc "Normalizes a request to JSON-shaped, string-keyed data."
  @spec normalize(term()) :: {:ok, map()} | {:error, refusal()}
  def normalize(request) when is_map(request) do
    {:ok, request |> Jason.encode!() |> Jason.decode!()}
  rescue
    error -> {:error, {:refused, :malformed_request, Exception.message(error)}}
  end

  def normalize(other), do: {:error, {:refused, :malformed_request, inspect(other)}}

  @spec admit(map(), ExecutionPolicy.t() | keyword()) ::
          {:ok, verdict()} | {:error, refusal() | {:blocked, term()}}
  def admit(request, policy \\ ExecutionPolicy.config()) do
    policy = ExecutionPolicy.normalize(policy)

    with {:ok, req} <- normalize(request),
         :ok <- required(req),
         {:ok, class} <- ExecutionPolicy.admit_query(req["query"], req["work_order_id"], policy),
         {:ok, rules} <- rules(req["compiled_rules"], policy),
         :ok <- stale_plan(req),
         {:ok, admit} <- admit_static(req, policy),
         {:ok, plan} <- plan_static(req),
         {:ok, candidate_hash} <- admit_reproduce(req, admit, policy),
         :ok <- plan_reproduce(req, plan) do
      {:ok,
       %{
         idempotency_key:
           idempotency_key(req["work_order_digest"], req["query"], plan["plan_hash"]),
         class_id: class.id,
         compiled_rules: rules,
         admit_receipt_id: admit["receipt"]["receipt_id"],
         admit_candidate_hash: candidate_hash,
         plan_id: plan["plan_id"] || "xaas_frontier_plan",
         plan_hash: plan["plan_hash"],
         request: req
       }}
    end
  end

  # -- shape ------------------------------------------------------------------------

  defp required(req) do
    missing =
      ~w(work_order_id work_order_digest query)
      |> Enum.reject(&(is_binary(req[&1]) and req[&1] != ""))

    if missing == [], do: :ok, else: {:error, {:refused, :malformed_request, missing}}
  end

  defp rules(nil, _policy), do: {:ok, nil}

  defp rules(rules, policy) when is_list(rules) do
    cond do
      length(rules) > policy.max_compiled_rules ->
        {:error, {:refused, :too_many_compiled_rules, length(rules)}}

      Enum.all?(rules, &match?([a, b] when is_binary(a) and is_binary(b), &1)) ->
        {:ok, rules}

      true ->
        {:error, {:refused, :malformed_compiled_rules, "expected [[pattern, output], ...]"}}
    end
  end

  defp rules(_other, _policy),
    do: {:error, {:refused, :malformed_compiled_rules, "expected a list"}}

  # -- stale-plan preimage fence -----------------------------------------------------

  # Preimage-fenced plans (XA-3007): when the plan carries an admitted preimage
  # digest and/or the preimage itself, freshness is checked BEFORE any port call.
  # A plan without preimage fields takes the unchanged path; a fence that is
  # present but unusable (missing/malformed digest or preimage) refuses closed.
  defp stale_plan(req) do
    plan = req["plan"]
    admitted = safe_get(plan, "admitted_preimage_hash")
    preimage = safe_get(plan, "preimage")

    if is_nil(admitted) and is_nil(preimage) do
      :ok
    else
      observed = if is_nil(preimage), do: nil, else: StalePlanGate.fingerprint(preimage)

      case StalePlanGate.check(admitted, observed) do
        {:ok, :fresh} -> :ok
        {:error, %Refusal{code: code, detail: detail}} -> {:error, {:refused, code, detail}}
      end
    end
  end

  defp safe_get(plan, key) when is_map(plan), do: plan[key]
  defp safe_get(_other, _key), do: nil

  # -- prior admit receipt ----------------------------------------------------------

  defp admit_static(req, policy) do
    id = req["work_order_id"]
    digest = req["work_order_digest"]
    admit = req["admit"]
    receipt = if is_map(admit), do: admit["receipt"]

    cond do
      not is_map(receipt) or not is_binary(receipt["candidate_hash"]) ->
        {:error, {:refused, :admit_receipt_missing, id}}

      receipt["ok"] != true or receipt["standing"] not in policy.admitted_standings ->
        {:error,
         {:refused, :admit_receipt_not_admitted,
          %{"ok" => receipt["ok"], "standing" => receipt["standing"]}}}

      (admit["candidate_id"] || id) != id ->
        {:error,
         {:refused, :admit_receipt_digest_mismatch, {:candidate_id, admit["candidate_id"]}}}

      not is_binary(admit["assertion"]) or receipt["admitted_assertion"] != admit["assertion"] or
        not String.contains?(admit["assertion"], "workorder:" <> id) or
          not String.contains?(admit["assertion"], "digest:" <> digest) ->
        {:error, {:refused, :admit_receipt_digest_mismatch, {id, digest}}}

      true ->
        {:ok, admit}
    end
  end

  defp admit_reproduce(req, admit, policy) do
    id = req["work_order_id"]
    receipt = admit["receipt"]

    opts =
      [
        query_id: admit["query_id"],
        source: admit["source"],
        evidence: admit["evidence"]
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    case bridge(fn -> Bridge.admit(id, admit["assertion"], opts) end) do
      {:ok, %{"ok" => true, "standing" => standing, "candidate_hash" => hash}} ->
        if standing in policy.admitted_standings and hash == receipt["candidate_hash"] do
          {:ok, hash}
        else
          {:error,
           {:refused, :admit_receipt_not_reproducible,
            %{"expected" => receipt["candidate_hash"], "recomputed" => hash}}}
        end

      {:error, {:blocked, _} = blocked} ->
        {:error, blocked}

      {:error, %{"candidate_hash" => _} = resp} ->
        {:error,
         {:refused, :admit_receipt_not_reproducible, Map.take(resp, ["standing", "reasons"])}}

      other ->
        {:error, {:blocked, {:admit_unexpected_reply, other}}}
    end
  end

  # -- bound plan hash --------------------------------------------------------------

  defp plan_static(req) do
    plan = req["plan"]

    cond do
      not is_map(plan) or not is_binary(plan["plan_hash"]) or plan["plan_hash"] == "" ->
        {:error, {:refused, :plan_hash_missing, req["work_order_id"]}}

      not is_list(plan["candidates"]) or plan["candidates"] == [] ->
        {:error, {:refused, :plan_missing, req["work_order_id"]}}

      true ->
        {:ok, plan}
    end
  end

  defp plan_reproduce(req, plan) do
    opts =
      [
        plan_id: plan["plan_id"],
        ticks: plan["ticks"],
        tokens: plan["tokens"],
        experiments: plan["experiments"]
      ]
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)

    case bridge(fn -> Bridge.plan(plan["candidates"], opts) end) do
      {:ok, %{"plan_hash" => hash, "allocations" => allocations}} ->
        cond do
          hash != plan["plan_hash"] ->
            {:error,
             {:refused, :plan_hash_mismatch,
              %{"bound" => plan["plan_hash"], "recomputed" => hash}}}

          not Enum.any?(allocations, fn a ->
            a["item_id"] == req["work_order_id"] and a["standing"] == "ADMITTED"
          end) ->
            {:error, {:refused, :plan_does_not_cover_work_order, req["work_order_id"]}}

          true ->
            :ok
        end

      {:error, {:blocked, _} = blocked} ->
        {:error, blocked}

      other ->
        {:error, {:blocked, {:plan_unexpected_reply, other}}}
    end
  end

  # -- port access ------------------------------------------------------------------

  @doc false
  # Calls the (single-slot) bridge, retrying `:bridge_busy` and turning an absent or
  # dead port into a typed BLOCKED instead of an exit.
  @spec bridge((-> term())) :: term()
  def bridge(fun, retries \\ @busy_retries) do
    case fun.() do
      {:error, :bridge_busy} when retries > 0 ->
        Process.sleep(@busy_backoff_ms)
        bridge(fun, retries - 1)

      {:error, :bridge_busy} ->
        {:error, {:blocked, :bridge_busy}}

      {:error, {:port_exited, status}} ->
        {:error, {:blocked, {:port_exited, status}}}

      other ->
        other
    end
  catch
    :exit, {:noproc, _} -> {:error, {:blocked, :bridge_not_running}}
    :exit, {reason, _} -> {:error, {:blocked, {:bridge_exit, reason}}}
  end
end
