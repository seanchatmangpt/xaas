defmodule Xaas.Operations.ApprovalCausalAnatomy do
  @moduledoc """
  Operator authorization surface for causal anatomy of approval decisions
  (WP-1, OS-15 / EU AI Act Art. 14(4)(b)).

  Read-only enrichment over the real, already-landed lane machinery — zero
  new actuation authority (the approval mutation path itself is untouched;
  this only decorates the operator-visible response):

    * `Xaas.Semantics.AdmissionAttribution` (W505, Art. 13) — exact Shapley
      blame per admission check over the discrete check lattice.
    * `Xaas.Semantics.Counterfactual` (W506, Art. 86) — deterministic
      counterfactual replay over the recorded decision.
    * `Xaas.Semantics.AutomationBiasCountermeasure` (W984p, Art. 14(4)(b)) —
      the operator briefing composition.

  The decision under approval is modeled as the real check battery this
  resource's own `:approve` action enforces (presence of a second approver,
  no self-approval, not-already-approved, positive amount, bound org). Each
  check is a real predicate over the decision input; the admission outcome
  is the first refusal in check order (the W506 first-refusal pipeline), and
  every downstream verdict is still witnessed.
  """

  alias Xaas.Semantics.AdmissionAttribution
  alias Xaas.Semantics.AutomationBiasCountermeasure
  alias Xaas.Semantics.Counterfactual

  @typedoc """
  Decision input under approval. All five keys are required; a missing key
  is a typed `{:missing_intent, keys}` refusal, never a silent nil-default.
  """
  @type intent :: %{
          required(:requested_by) => term(),
          required(:approved_by) => term(),
          required(:already_approved?) => boolean(),
          required(:credit_amount_cents) => term(),
          required(:org_id) => term()
        }

  @typedoc "Counterfactual replay result (W506 `result`)."
  @type counterfactual :: Counterfactual.result()

  @typedoc "Operator briefing (W984p `briefing`)."
  @type briefing :: AutomationBiasCountermeasure.briefing()

  @type anatomy :: %{
          required(:briefing) => briefing(),
          required(:counterfactual) => counterfactual() | nil
        }

  @typedoc "Typed anatomy refusal."
  @type anatomy_error ::
          {:missing_intent, [atom()]}
          | {:record_outcome_mismatch, term()}
          | {:admit_with_refusal, atom()}
          | {:refusal_missing_reason, term()}
          | {:refusal_without_failing_check, atom()}
          | {:refusal_mismatch, atom()}

  @required_keys [:requested_by, :approved_by, :already_approved?, :credit_amount_cents, :org_id]

  @doc """
  The ordered approval check battery, in W506 `{name, fun}` shape where each
  fun maps the intent to `:ok | {:refused, reason}`. These are the REAL
  predicates `:approve` enforces (see
  `Xaas.Billing.Validations.ApprovalSlaCreditApplyRequiresApprover` and the
  `filter(expr(is_nil(approved_by)))` idempotency guard on the action):
  presence of a second approver, no self-approval, not-already-approved,
  positive credit amount, bound org.
  """
  @spec checks() :: [
          {atom(), (intent() -> :ok | {:refused, atom()})}
        ]
  def checks do
    [
      approver_present: fn i ->
        if i.approved_by in [nil, ""], do: {:refused, :approver_missing}, else: :ok
      end,
      approver_differs: fn i ->
        if i.approved_by == i.requested_by, do: {:refused, :self_approval}, else: :ok
      end,
      not_already_approved: fn i ->
        if i.already_approved?, do: {:refused, :already_approved}, else: :ok
      end,
      credit_amount_positive: fn i ->
        if is_integer(i.credit_amount_cents) and i.credit_amount_cents >= 1,
          do: :ok,
          else: {:refused, :amount_not_positive}
      end,
      org_bound: fn i ->
        if i.org_id in [nil, ""], do: {:refused, :org_missing}, else: :ok
      end
    ]
  end

  @doc """
  Compute the causal anatomy for a decision under approval.

  Returns `{:ok, %{briefing: briefing, counterfactual: cf | nil}}` where
  `briefing` carries the W984p operator briefing (verdict, per-check causes
  with exact Shapley blame, refusal anatomy, counterfactual availability)
  and `counterfactual` is the W506 replay on a repaired approver input —
  the "what single-check flip would have changed this" receipt — populated
  for refusals, `nil` for admits (nothing to repair).

  Missing intent keys refuse typed `{:error, {:missing_intent, keys}}`;
  briefing-level contract violations refuse typed per the W984p module
  contract (see `AutomationBiasCountermeasure.briefing/2`). No silent
  degradation at the module level; the HTTP metadata adapter (below) is the
  disclosed degrade point.
  """
  @spec anatomy(intent()) :: {:ok, anatomy()} | {:error, anatomy_error()}
  def anatomy(intent) when is_map(intent) do
    missing = for k <- @required_keys, not Map.has_key?(intent, k), do: k

    if missing != [] do
      {:error, {:missing_intent, missing}}
    else
      case compute_briefing(intent) do
        {:ok, {record, checks, briefing}} ->
          counterfactual =
            case record.refusal do
              nil ->
                nil

              _refusal ->
                repaired = Map.put(intent, :approved_by, repaired_approver(intent))

                case Counterfactual.evaluate(record, repaired, checks) do
                  {:ok, cf} -> cf
                  {:error, reason} -> {:error, reason}
                end
            end

          {:ok, %{briefing: briefing, counterfactual: counterfactual}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def anatomy(_intent), do: {:error, {:missing_intent, [:not_a_map]}}

  defp compute_briefing(intent) do
    checks = checks()
    shapley_checks = to_shapley_checks(checks)

    # W505: exact Shapley over the real check battery (5 checks << 20; the
    # COALITION_LIMIT refusal is unreachable for this battery by construction).
    attributions = AdmissionAttribution.shapley(intent, shapley_checks)

    # W506: the deterministic pipeline run over the recorded intent; the
    # per-check verdict log IS the decision record's check log.
    run = Counterfactual.run(intent, checks)

    {admitted?, refusal} =
      case run.outcome do
        :admitted -> {true, nil}
        {:refused, reason} -> {false, reason}
      end

    record = %{
      input: intent,
      admitted?: admitted?,
      refusal: refusal,
      checks: run.checks
    }

    with {:ok, briefing} <- AutomationBiasCountermeasure.briefing(record, attributions) do
      {:ok, {record, checks, briefing}}
    end
  end

  @doc """
  HTTP metadata adapter for the JSON:API `:approve` route (AshJsonApi
  per-route `metadata` fn, top-level `meta` member of the response document).

  Takes the POST-approval record. The real `filter(expr(is_nil(approved_by)))`
  idempotency guard on `:approve` guarantees `approved_by` was nil before the
  mutation, so the recorded decision is exactly "this approver approved this
  pending request". Returns a Jason-encodable `meta` payload:

      %{"causal_anatomy" => %{"available" => true, "briefing" => ..., "counterfactual" => ...}}

  The disclosed degrade point: if the anatomy computation refuses typed
  (missing intent, briefing contract violation), the metadata block degrades
  to `{"available" => false, "error" => <typed reason>}` — the approval
  itself is unaffected (this surface is visibility, not authority), and the
  typed reason is carried verbatim for the operator.
  """
  def metadata(record) do
    intent = %{
      requested_by: Map.get(record, :requested_by),
      approved_by: Map.get(record, :approved_by),
      already_approved?: false,
      credit_amount_cents: Map.get(record, :credit_amount_cents),
      org_id: Map.get(record, :org_id)
    }

    case anatomy(intent) do
      {:ok, %{briefing: briefing, counterfactual: counterfactual}} ->
        %{
          "causal_anatomy" => %{
            "available" => true,
            "briefing" => briefing,
            "counterfactual" => encodeable_counterfactual(counterfactual)
          }
        }

      {:error, reason} ->
        %{"causal_anatomy" => %{"available" => false, "error" => reason}}
    end
  end

  # Jason cannot encode 2-tuples; a counterfactual replay-error tuple is
  # carried as a map with the typed reason (unreachable in practice — the
  # record is built from the same check-list the replay uses — but never a
  # serialization crash).
  defp encodeable_counterfactual({:error, reason}), do: %{"error" => reason}
  defp encodeable_counterfactual(other), do: other

  # The repair substitution for the Art. 86 counterfactual: a syntactically
  # valid second approver distinct from the requester. If the decision was
  # refused for self-approval or a missing approver, this flips exactly the
  # approver-shaped checks; if it was refused for already-approved, the
  # counterfactual honestly stays refused (no single-approver repair exists).
  defp repaired_approver(intent) do
    requester = intent.requested_by
    base = if is_binary(requester), do: requester, else: ""
    base <> "-second-approver"
  end

  # W505 shapley fun shape: :pass | {:refuse, atom}.
  defp to_shapley_checks(checks) do
    Enum.map(checks, fn {name, fun} ->
      {name, fn i ->
         case fun.(i) do
           :ok -> :pass
           {:refused, reason} -> {:refuse, reason}
         end
       end}
    end)
  end
end
