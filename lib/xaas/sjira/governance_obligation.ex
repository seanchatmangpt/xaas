defmodule Xaas.Sjira.GovernanceObligation do
  @moduledoc """
  Deterministic sJira projection of governance-gate findings.

  A gate finding becomes a powerless obligation first. The obligation may be
  admitted, bound to explicit authority, and finally bound to a prepared
  receipt, but none of those transitions actuates anything. Consequential DO
  remains outside this module.

  The state separation is load-bearing:

      PROPOSED != ADMITTED != AUTHORIZED != PREPARED

  In particular, an approval request or proposed work item never manufactures
  authority, and authority alone never means a consequence is prepared.
  """

  @enforce_keys [
    :obligation_id,
    :subject_ref,
    :gate,
    :phase,
    :finding_id,
    :required_action,
    :action_owner,
    :evidence_required,
    :disposition,
    :standing,
    :ready_for_do,
    :digest
  ]
  defstruct [
    :obligation_id,
    :subject_ref,
    :gate,
    :phase,
    :finding_id,
    :required_action,
    :action_owner,
    :evidence_required,
    :disposition,
    :standing,
    :admission_digest,
    :authority_ref,
    :prepared_receipt_ref,
    :ready_for_do,
    :digest
  ]

  @type standing :: :proposed | :admitted | :authorized | :prepared

  @type t :: %__MODULE__{
          obligation_id: String.t(),
          subject_ref: String.t(),
          gate: String.t(),
          phase: String.t(),
          finding_id: String.t(),
          required_action: String.t(),
          action_owner: String.t(),
          evidence_required: String.t(),
          disposition: String.t(),
          standing: standing(),
          admission_digest: String.t() | nil,
          authority_ref: String.t() | nil,
          prepared_receipt_ref: String.t() | nil,
          ready_for_do: boolean(),
          digest: String.t()
        }

  @required_finding ~w(id required_action action_owner evidence_required disposition)
  @key_atoms %{
    "gate" => :gate,
    "phase" => :phase,
    "findings" => :findings,
    "id" => :id,
    "required_action" => :required_action,
    "action_owner" => :action_owner,
    "evidence_required" => :evidence_required,
    "disposition" => :disposition
  }

  @spec compile_gate(map(), keyword()) :: {:ok, [t()]} | {:refused, map()}
  def compile_gate(%{} = gate_result, opts) when is_list(opts) do
    subject_ref = Keyword.get(opts, :subject_ref)
    gate = value(gate_result, "gate")
    phase = value(gate_result, "phase")
    findings = value(gate_result, "findings")

    cond do
      not nonempty?(subject_ref) ->
        {:refused, refusal("SUBJECT_REF_REQUIRED", %{subject_ref: subject_ref})}

      not nonempty?(gate) ->
        {:refused, refusal("GATE_REQUIRED", %{gate: gate})}

      not nonempty?(phase) ->
        {:refused, refusal("PHASE_REQUIRED", %{phase: phase})}

      not is_list(findings) ->
        {:refused, refusal("FINDINGS_MUST_BE_LIST", %{findings: findings})}

      true ->
        compile_findings(findings, subject_ref, gate, phase)
    end
  end

  @spec admit(t(), String.t()) :: {:ok, t()} | {:refused, map()}
  def admit(%__MODULE__{standing: :proposed} = obligation, admission_digest)
      when is_binary(admission_digest) and byte_size(admission_digest) > 0 do
    {:ok,
     transition(obligation, :admitted,
       admission_digest: admission_digest,
       authority_ref: nil,
       prepared_receipt_ref: nil,
       ready_for_do: false
     )}
  end

  def admit(%__MODULE__{} = obligation, _admission_digest),
    do: {:refused, transition_refusal(obligation, "ADMISSION_TRANSITION_REFUSED")}

  @spec authorize(t(), String.t()) :: {:ok, t()} | {:refused, map()}
  def authorize(%__MODULE__{standing: :admitted} = obligation, authority_ref)
      when is_binary(authority_ref) and byte_size(authority_ref) > 0 do
    {:ok,
     transition(obligation, :authorized,
       authority_ref: authority_ref,
       prepared_receipt_ref: nil,
       ready_for_do: false
     )}
  end

  def authorize(%__MODULE__{} = obligation, _authority_ref),
    do: {:refused, transition_refusal(obligation, "AUTHORITY_TRANSITION_REFUSED")}

  @spec prepare(t(), String.t()) :: {:ok, t()} | {:refused, map()}
  def prepare(%__MODULE__{standing: :authorized, authority_ref: authority_ref} = obligation, receipt_ref)
      when is_binary(authority_ref) and byte_size(authority_ref) > 0 and
             is_binary(receipt_ref) and byte_size(receipt_ref) > 0 do
    {:ok,
     transition(obligation, :prepared,
       prepared_receipt_ref: receipt_ref,
       ready_for_do: true
     )}
  end

  def prepare(%__MODULE__{} = obligation, _receipt_ref),
    do: {:refused, transition_refusal(obligation, "PREPARED_RECEIPT_TRANSITION_REFUSED")}

  @doc "Recompute the content identity and refuse a mutated obligation."
  @spec replay(t()) :: {:ok, t()} | {:refused, map()}
  def replay(%__MODULE__{} = obligation) do
    expected = digest_body(obligation)

    if expected == obligation.digest do
      {:ok, obligation}
    else
      {:refused,
       refusal("OBLIGATION_DIGEST_MISMATCH", %{
         obligation_id: obligation.obligation_id,
         expected: expected,
         observed: obligation.digest
       })}
    end
  end

  @doc "Powerless sJira work-item projection. It carries no execution grant."
  @spec work_item(t()) :: map()
  def work_item(%__MODULE__{} = obligation) do
    %{
      "identity" => obligation.obligation_id,
      "classification" => "GovernanceObligation",
      "subject_ref" => obligation.subject_ref,
      "gate" => obligation.gate,
      "phase" => obligation.phase,
      "finding_id" => obligation.finding_id,
      "required_action" => obligation.required_action,
      "action_owner" => obligation.action_owner,
      "evidence_required" => obligation.evidence_required,
      "disposition" => obligation.disposition,
      "standing" => obligation.standing |> Atom.to_string() |> String.upcase(),
      "authority_ref" => obligation.authority_ref,
      "prepared_receipt_ref" => obligation.prepared_receipt_ref,
      "ready_for_do" => obligation.ready_for_do,
      "digest" => obligation.digest
    }
  end

  @doc """
  Complete OCEL-shaped fragment containing the governed work-order object,
  the obligation object, and one transition event.

  The fragment is compatible with Xaas.Ocel.Projection.import/1's map shape;
  persistence remains a separate explicit call.
  """
  @spec ocel_fragment(t(), atom(), DateTime.t()) :: map()
  def ocel_fragment(%__MODULE__{} = obligation, transition, %DateTime{} = occurred_at) do
    event = ocel_event(obligation, transition, occurred_at)

    %{
      "objectTypes" => ["governance_obligation", "sjira_work_order"],
      "eventTypes" => [event["type"]],
      "objects" => [
        %{"id" => obligation.subject_ref, "type" => "sjira_work_order"},
        %{"id" => obligation.obligation_id, "type" => "governance_obligation"}
      ],
      "events" => [event]
    }
  end

  @doc """
  OCEL-shaped transition evidence for process conformance.

  The event is a projection only. Recording it through Xaas.Ocel remains a
  separate operation.
  """
  @spec ocel_event(t(), atom(), DateTime.t()) :: map()
  def ocel_event(%__MODULE__{} = obligation, transition, %DateTime{} = occurred_at) do
    %{
      "id" => "sjira-governance:#{obligation.digest}:#{transition}",
      "type" => "sjira.governance.#{transition}",
      "time" => DateTime.to_iso8601(occurred_at),
      "attributes" => %{
        "obligation_id" => obligation.obligation_id,
        "gate" => obligation.gate,
        "phase" => obligation.phase,
        "finding_id" => obligation.finding_id,
        "standing" => obligation.standing |> Atom.to_string() |> String.upcase(),
        "disposition" => obligation.disposition,
        "admission_digest" => obligation.admission_digest,
        "authority_ref" => obligation.authority_ref,
        "prepared_receipt_ref" => obligation.prepared_receipt_ref,
        "ready_for_do" => obligation.ready_for_do,
        "obligation_digest" => obligation.digest
      },
      "relationships" => [
        %{"objectId" => obligation.subject_ref, "qualifier" => "governs"},
        %{"objectId" => obligation.obligation_id, "qualifier" => "obligation"}
      ]
    }
  end

  defp compile_findings(findings, subject_ref, gate, phase) do
    findings
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {finding, index}, {:ok, acc} ->
      case compile_finding(finding, subject_ref, gate, phase, index) do
        {:ok, obligation} -> {:cont, {:ok, [obligation | acc]}}
        {:refused, reason} -> {:halt, {:refused, reason}}
      end
    end)
    |> case do
      {:ok, obligations} -> {:ok, Enum.reverse(obligations)}
      {:refused, reason} -> {:refused, reason}
    end
  end

  defp compile_finding(%{} = finding, subject_ref, gate, phase, index) do
    missing = Enum.reject(@required_finding, &nonempty?(value(finding, &1)))

    if missing == [] do
      finding_id = value(finding, "id")
      obligation_id = "#{subject_ref}:#{gate}:#{phase}:#{finding_id}"

      obligation = %__MODULE__{
        obligation_id: obligation_id,
        subject_ref: subject_ref,
        gate: gate,
        phase: phase,
        finding_id: finding_id,
        required_action: value(finding, "required_action"),
        action_owner: value(finding, "action_owner"),
        evidence_required: value(finding, "evidence_required"),
        disposition: value(finding, "disposition"),
        standing: :proposed,
        admission_digest: nil,
        authority_ref: nil,
        prepared_receipt_ref: nil,
        ready_for_do: false,
        digest: ""
      }

      {:ok, %{obligation | digest: digest_body(obligation)}}
    else
      {:refused,
       refusal("MALFORMED_FINDING", %{
         index: index,
         finding_id: value(finding, "id"),
         missing: missing
       })}
    end
  end

  defp compile_finding(other, _subject_ref, _gate, _phase, index),
    do: {:refused, refusal("FINDING_MUST_BE_MAP", %{index: index, finding: inspect(other)})}

  defp transition(%__MODULE__{} = obligation, standing, updates) do
    changed =
      obligation
      |> Map.merge(Map.new(updates))
      |> Map.put(:standing, standing)
      |> Map.put(:digest, "")

    %{changed | digest: digest_body(changed)}
  end

  defp digest_body(%__MODULE__{} = obligation) do
    {
      obligation.obligation_id,
      obligation.subject_ref,
      obligation.gate,
      obligation.phase,
      obligation.finding_id,
      obligation.required_action,
      obligation.action_owner,
      obligation.evidence_required,
      obligation.disposition,
      obligation.standing,
      obligation.admission_digest,
      obligation.authority_ref,
      obligation.prepared_receipt_ref,
      obligation.ready_for_do
    }
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp transition_refusal(obligation, code) do
    refusal(code, %{
      obligation_id: obligation.obligation_id,
      standing: obligation.standing,
      ready_for_do: obligation.ready_for_do
    })
  end

  defp refusal(code, detail) do
    %{
      "standing" => "REFUSED(#{code})",
      "reason" => code,
      "detail" => detail
    }
  end

  defp value(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> Map.get(map, Map.fetch!(@key_atoms, key))
    end
  end

  defp nonempty?(value), do: is_binary(value) and byte_size(value) > 0
end
