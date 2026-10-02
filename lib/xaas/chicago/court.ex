defmodule Xaas.Chicago.Court do
  @moduledoc """
  In-memory, deterministic court for the 10 Chicago case laws (resolution R4).

  The court decides a purchase request against a delegation policy. It is pure:
  no I/O, no side effects, no standing promotion — on the positive path the
  standing is still `"UNKNOWN"` because only a real runtime court with an
  exact-subject receipt can promote standing (R8). The refusal atoms of the
  case laws are exactly:

      :above_delegated_limit | :wrong_principal | :delegation_expired |
      :provider_unavailable | :unknown_after_dispatch | :missing_evidence |
      :stale_subject | :policy_drift | :authority_none

  Provider unavailability BEFORE dispatch is intentionally not a goal failure
  while an admitted alternative remains: it returns an alternative-preserving
  `{:ok, ...}` result — bounded replanning may proceed without changing
  authority. When NO admitted alternative remains, it refuses
  `:provider_unavailable` with authority unchanged.

  Deterministic precedence (each earlier law shadows later ones):

  1. `:authority_none`        — the request tries to mint authority
  2. `:stale_subject`         — request bound to another subject
  3. `:wrong_principal`       — principal does not match the delegation
  4. `:delegation_expired`    — delegation expired (never implicitly refreshed)
  5. `:policy_drift`          — plan premised on a stale policy digest
  6. `:above_delegated_limit` — amount exceeds the delegated limit
  7. provider unavailable, pre-dispatch — `{:ok, :alternative_preserved}` or
     `:provider_unavailable` when no admitted alternative remains
  8. `:unknown_after_dispatch`— reconcile/1 the original consequence, never blind replay
  9. `:missing_evidence`      — claimed consequence without exact-subject evidence/receipt
  10. bounded authorized purchase — `{:ok, consequence, standing: "UNKNOWN"}`

  Evidence and receipt bindings are judged only on a claimed successful
  dispatch (laws 9/10); a request missing them post-claim is refused
  `:missing_evidence`, and one bound to another subject is `:stale_subject`.

  Every verdict is anti-vacuity-testable: flipping exactly one input flips the
  verdict (see `test/xaas/chicago/consumer/chicago_court_test.exs`).
  """

  alias Xaas.Chicago.Subject

  defmodule Policy do
    @moduledoc """
    Delegation policy under test. `delegated_limit`, `principal` and
    `delegation_expires_at` are test parameters, not ambient authority: this
    struct never actuates anything.

    `now` is injected for determinism (defaults to `DateTime.utc_now/0`).
    A delegation is expired when `now >= delegation_expires_at` (conservative
    at the boundary; never implicitly refreshed).
    """

    defstruct [:delegated_limit, :principal, :delegation_expires_at, :policy_digest, :now]

    @type t :: %__MODULE__{
            delegated_limit: number,
            principal: String.t(),
            delegation_expires_at: DateTime.t(),
            policy_digest: String.t(),
            now: DateTime.t() | nil
          }
  end

  @doc "Positive-path baseline request for a bounded authorized purchase."
  @spec bounded_purchase(map) :: map
  def bounded_purchase(overrides \\ %{}) do
    Map.merge(
      %{
        case_id: "CHI-CASE-001",
        subject: Subject.literal(),
        authority_claim: "NONE",
        principal: "principal-001",
        amount: 50,
        plan_policy_digest: "policy-digest-001",
        provider_available: true,
        dispatch: {:ok, %{consequence_id: "consequence-001", amount: 50}},
        consequence: %{consequence_id: "consequence-001", amount: 50},
        evidence: %{subject: Subject.literal(), kind: :exact_subject_observation},
        receipt: %{subject: Subject.literal(), id: "receipt-001"}
      },
      Map.new(overrides)
    )
  end

  @doc "Baseline delegation policy matching `bounded_purchase/1`."
  @spec baseline_policy(map) :: Policy.t()
  def baseline_policy(overrides \\ %{}) do
    struct!(
      Policy,
      Map.merge(
        %{
          delegated_limit: 100,
          principal: "principal-001",
          delegation_expires_at: ~U[2030-01-01 00:00:00Z],
          policy_digest: "policy-digest-001",
          now: ~U[2026-10-01 00:00:00Z]
        },
        Map.new(overrides)
      )
    )
  end

  @doc "Decide a request against a policy. Pure; see the module precedence table."
  @spec decide(map, Policy.t()) :: {:ok, map} | {:refused, atom, map}
  def decide(request, %Policy{} = policy) do
    now = policy.now || DateTime.utc_now()

    with :ok <- authority_law(request),
         :ok <- subject_law(request),
         :ok <- principal_law(request, policy),
         :ok <- expiry_law(policy, now),
         :ok <- drift_law(request, policy),
         :ok <- limit_law(request, policy) do
      dispatch_law(request)
    end
  end

  @doc """
  Reconcile an `{:refused, :unknown_after_dispatch, details}` verdict: returns
  the ORIGINAL consequence identity — never a blind replay, never a fabricated
  success, never a standing promotion. Any other input is refused.
  """
  @spec reconcile(term) :: {:ok, map} | {:refused, atom, map}
  def reconcile({:refused, :unknown_after_dispatch, %{consequence: consequence} = details}) do
    {:ok,
     %{
       consequence: consequence,
       consequence_identity: details[:consequence_id] || consequence,
       replay: :original_identity,
       standing: "UNKNOWN",
       note:
         "reconciliation returns the original consequence identity; no blind replay, no promotion"
     }}
  end

  def reconcile(other) do
    {:refused, :reconcile_requires_unknown_after_dispatch, %{input: other}}
  end

  # -- laws (precedence = clause order in decide/2 and here) ------------------

  defp authority_law(%{authority_claim: "NONE"}), do: :ok

  defp authority_law(%{authority_claim: claim}),
    do:
      {:refused, :authority_none, %{claim: claim, law: "a surface request cannot mint authority"}}

  defp subject_law(%{subject: subject}) do
    if Subject.matches?(subject),
      do: :ok,
      else:
        {:refused, :stale_subject,
         %{expected: Subject.literal(), got: subject, binding: :request}}
  end

  defp principal_law(%{principal: principal}, %Policy{principal: expected}) do
    if principal == expected,
      do: :ok,
      else: {:refused, :wrong_principal, %{expected: expected, got: principal}}
  end

  defp expiry_law(%Policy{delegation_expires_at: expires}, now) do
    case DateTime.compare(now, expires) do
      :lt -> :ok
      _ -> {:refused, :delegation_expired, %{expires_at: expires, now: now}}
    end
  end

  defp drift_law(%{plan_policy_digest: plan_digest}, %Policy{policy_digest: policy_digest}) do
    if plan_digest == policy_digest,
      do: :ok,
      else: {:refused, :policy_drift, %{plan_digest: plan_digest, policy_digest: policy_digest}}
  end

  defp limit_law(%{amount: amount}, %Policy{delegated_limit: limit}) do
    if amount <= limit,
      do: :ok,
      else: {:refused, :above_delegated_limit, %{amount: amount, delegated_limit: limit}}
  end

  # 7 — provider unavailable before any dispatch: alternatives stay admitted.
  # With NO admitted alternative left it IS a goal failure (:provider_unavailable).
  defp dispatch_law(%{provider_available: false, dispatch: nil} = request) do
    if Map.get(request, :alternative_available, true) do
      {:ok,
       %{
         outcome: :alternative_preserved,
         standing: "UNKNOWN",
         consequence: nil,
         note:
           "pre-dispatch provider unavailability preserves other admitted realizations; " <>
             "bounded replanning may proceed without changing authority"
       }}
    else
      {:refused, :provider_unavailable,
       %{
         note: "provider unavailable pre-dispatch and no admitted alternative remains",
         authority_unchanged: true
       }}
    end
  end

  # 8 — dispatched but outcome unknown: original consequence identity only
  defp dispatch_law(%{dispatch: :unknown} = request) do
    consequence = Map.get(request, :consequence, %{consequence_id: "unknown-after-dispatch"})

    consequence_id =
      if is_map(consequence) and Map.has_key?(consequence, :consequence_id),
        do: Map.get(consequence, :consequence_id),
        else: "unknown-after-dispatch"

    {:refused, :unknown_after_dispatch,
     %{
       consequence: consequence,
       consequence_id: consequence_id,
       note: "reconcile/1 the original consequence; never blind replay"
     }}
  end

  # 9/10 — claimed successful dispatch: evidence and receipt must bind the subject
  defp dispatch_law(%{dispatch: {:ok, consequence}} = request) do
    with :ok <- bound_subject?(Map.get(request, :evidence), :evidence),
         :ok <- bound_subject?(Map.get(request, :receipt), :receipt) do
      {:ok,
       %{
         outcome: :bounded_authorized_purchase,
         consequence: consequence,
         standing: "UNKNOWN",
         note:
           "authority admitted within the delegated limit; standing remains UNKNOWN until " <>
             "the runtime court binds an exact-subject receipt"
       }}
    end
  end

  defp dispatch_law(_request) do
    {:refused, :missing_evidence, %{missing: [:dispatch, :evidence, :receipt]}}
  end

  defp bound_subject?(%{subject: subject}, binding) do
    if Subject.matches?(subject),
      do: :ok,
      else:
        {:refused, :stale_subject, %{expected: Subject.literal(), got: subject, binding: binding}}
  end

  defp bound_subject?(nil, binding), do: {:refused, :missing_evidence, %{missing: [binding]}}

  defp bound_subject?(other, binding),
    do: {:refused, :missing_evidence, %{missing: [binding], got: other}}
end
