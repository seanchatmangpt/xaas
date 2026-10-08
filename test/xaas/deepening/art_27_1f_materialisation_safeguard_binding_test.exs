defmodule Xaas.Deepening.Art271fMaterialisationSafeguardBindingTest do
  @moduledoc """
  Lane W984by — evidenced-line deepening wave 7, corpus line **27.1.f**
  (Art. 27(1)(f): measures foreseen in case of risk materialisation —
  evidence row W537/W648b "materialisation measures = the typed
  materialisation inventory: fria/0's per-right safeguards + the
  honestly-typed OPEN_GAP authority channel recorded in the FRIA
  itself"; cited paths: oversight_governance.ex, incident_report.ex,
  w537 receipt).

  Existing coverage is structural only: fria/0 returns typed structure
  with existing paths, deterministic, open-gap present
  (`test/xaas/semantics/oversight_governance_test.exs`); W704 deepened
  27.3 by composing fria/0 with a real halt record. Uncovered property
  class: BINDING LIVENESS — the FRIA's materialisation inventory, when
  its claimed safeguards are EXECUTED over a real materialised risk,
  actually delivers the claimed protection chain: real Art. 5 refusal →
  real typed incident classification derived from the real refusal →
  honest typed-OPEN authority channel (prepared, never silently sent) →
  real halt-to-safe-state safeguard executing on a real subject.

  Mutation rationale:
    1. if the FRIA's cited safeguard symbols drift from what the cited
       modules actually refuse (bias gate stops returning
       REFUSED_BIAS_THRESHOLD, admission gate stops refusing the
       manipulative candidate), court 1 fails while structural
       path-existence courts pass (they never execute the symbols);
    2. if the incident seam stops deriving classification from executed
       evidence (hardcoded classification, refusal-atom mapping lost) or
       the authority channel silently "transmits", court 2 fails while
       shape courts over hand-built reports still pass;
    3. if incident identity stops being content-derived (e.g. a
       timestamped id), court 3's causality leg fails while
       determinism-of-fria courts still pass.

  Disclosed finding (not a lane defect, not fixed — outside this lane's
  contract): fria/0's authority-channel entry prose still reads "No
  incident-reporting seam exists", written pre-W538. The TRANSMISSION
  gap the entry points at is still real (AuthorityChannel authority
  transmit is typed OPEN, PREPARED_NOT_TRANSMITTED), so the entry's
  status is honest at the gap level; the prose is stale relative to the
  landed builder seam. Flagged for the corpus/FRIA owner.

  Chicago discipline: real gate executions over real data, real Ash
  policy denial over real sandboxed Postgres, real QuiescentStop over a
  real Provider row; assertions on final returned state only. No mocks.
  """

  use ExUnit.Case, async: true

  # 27.1.f is an evidenced corpus line (W537/W648b) — eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Actuation.QuiescentStop
  alias Xaas.Marketplace.Provider
  alias Xaas.Semantics.{AuthorityChannel, DatasetAdmission, EuAiActAdmission, IncidentReport,
                       OversightGovernance}

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # -- real materialised-risk drives -------------------------------------------

  defp manipulative_candidate do
    %{id: :w984by_manipulative, techniques: [:manipulate_behavior]}
  end

  # A real executed Art. 5 refusal — the materialised-risk evidence.
  defp real_refusal_receipt do
    {:error, atom} = EuAiActAdmission.admit(manipulative_candidate())
    atom_str = Atom.to_string(atom)

    # Structural receipt over the executed evidence: the real refusal atom,
    # content-derived digest over the exact candidate that refused.
    %{
      id: "sha256:" <> Base.encode16(:crypto.hash(:sha256, :erlang.term_to_iovec(manipulative_candidate())), padding: false),
      refusal_atom: atom,
      observed_at: ~U[2026-10-07 00:00:00Z]
    }
  end

  # A real governed denial: Book create with a resolved actor SUCCEEDS (the
  # witnessed transition), then the SAME create with NO actor is denied by
  # the real Ash.Policy.Authorizer. The receipt records the executed denial
  # (status :error) with a digest over the real error term.
  defp real_denial_receipt do
    alias Xaas.Library.Book
    alias Xaas.Accounts.User

    actor =
      Ash.Seed.seed!(User, %{email: "w984by-271f-#{System.unique_integer([:positive])}@example.com"})

    attrs = %{
      title: "W984by Materialisation Fixture",
      author: "Test Author",
      isbn: "W984BY-#{System.unique_integer([:positive])}",
      grade_level: Decimal.new("3"),
      genres: ["Fiction"],
      formats: ["hardcover"],
      available_copies: 0,
      total_copies: 1
    }

    {:ok, _book} =
      Book
      |> Ash.Changeset.for_create(:create, attrs, actor: actor)
      |> Ash.create()

    {:error, %Ash.Error.Forbidden{} = denial} =
      Book
      |> Ash.Changeset.for_create(:create, attrs, actor: nil)
      |> Ash.create()

    %{
      id:
        "sha256:" <>
          Base.encode16(:crypto.hash(:sha256, :erlang.term_to_iovec(denial)), padding: false),
      status: :error,
      observed_at: ~U[2026-10-07 00:01:00Z]
    }
  end

  # -- court 1: executed safeguards equal the FRIA's claimed bases -------------

  test "court 1 — the FRIA's cited safeguards, executed over real inputs, deliver exactly the claimed typed protections" do
    {:ok, fria} = OversightGovernance.fria()
    by_right = Map.new(fria.rights, fn r -> {r.right, r} end)

    # non_discrimination: basis REFUSED_BIAS_THRESHOLD — execute the cited
    # symbol (DatasetAdmission.admit/2) on a real biased population.
    nd = by_right.non_discrimination
    assert nd.status == :EVIDENCED
    assert [%{symbol: "Xaas.Semantics.DatasetAdmission.admit/2", basis: basis_nd} | _] =
             nd.evidence

    assert basis_nd == "REFUSED_BIAS_THRESHOLD"

    biased =
      for k <- 1..10, s <- [0, 1] do
        a = if s == 0, do: k * 1.0, else: k * 1.0 + 5.0

        %{features: %{a: a, b: :math.fmod(k * 1.0, 3.0)}, label: :ok, sensitive: s}
      end

    assert {:error, {:REFUSED_BIAS_THRESHOLD, _}} =
             DatasetAdmission.admit(biased, seed: 42, epsilon_bias: 0.1, eta: 0.1)

    # due_process: the cited admission surface refuses a real Art. 5(1)
    # violating candidate with a typed atom.
    assert by_right.due_process.status == :EVIDENCED
    assert {:error, :REFUSED_EUAIA_MANIPULATIVE} = EuAiActAdmission.admit(manipulative_candidate())
    due_process = by_right.due_process

    assert Enum.any?(due_process.evidence, fn e ->
             e.symbol == "Xaas.Semantics.EuAiActAdmission" and
               String.contains?(e.basis, "refusal atoms")
           end)

    # privacy: zero-PII claim holds on executed behavior — the gate refuses
    # on declared intent-schema fields only; injecting an undeclared field
    # into the candidate never changes the verdict (real zero-PII witness).
    assert by_right.privacy.status == :EVIDENCED

    clean = %{id: :w984by_privacy, techniques: [:recommendation], purpose: :rank_content}

    assert {:ok, :admitted} = EuAiActAdmission.admit(clean)
    assert {:ok, :admitted} = EuAiActAdmission.admit(Map.put(clean, :free_text_pii, "ssn=123-45-6789"))

    # The halt-to-safe-state safeguard cited for risk materialisation
    # during use (the 27.3 surface the FRIA's materialisation inventory
    # rides on) actually executes on a real subject: a real Provider row
    # is driven quiescent, deterministically, and a repeated halt is a
    # no-op that never un-halts the subject (the attractor holds).
    provider = Xaas.Generator.create_provider!(%{name: "W984by Materialisation Provider", org_id: "org-w984by-271f"})

    opts = [
      subject_id: provider.id,
      idempotency_key: "estop-w984by-271f-#{System.unique_integer([:positive])}",
      authority: %{kind: "test_authority", source: "art_27_1f_materialisation_binding_test"}
    ]

    assert {:ok, receipt} = QuiescentStop.execute(Provider, opts)
    assert receipt.target == :quiescent
    assert %DateTime{} = receipt.stopped_at

    assert {:ok, _receipt2} = QuiescentStop.execute(Provider, opts)
    # The subject's safe state for a Provider is :suspended (the attractor's
    # quiescent target realized on the resource).
    assert provider_status(provider.id) == :suspended
  end

  defp provider_status(provider_id) do
    Provider
    |> Ash.get!(provider_id, authorize?: false)
    |> Map.fetch!(:status)
  end

  # -- court 2: real materialisation → typed report → honest channel -----------

  test "court 2 — a real materialised risk derives a typed incident classification and the authority channel stays honestly OPEN (prepared, never silently sent)" do
    refusal_receipt = real_refusal_receipt()
    denial_receipt = real_denial_receipt()

    {:ok, report} = IncidentReport.build([refusal_receipt, denial_receipt])

    # Classification DERIVED from executed evidence, per the module map:
    # the real EUAIA refusal atom -> INFRINGES_UNION_LAW (never MALFUNCTION
    # — the Art. 5 refusal is the admission layer working as designed); the
    # real policy denial (status :error, no EUAIA atom) -> MALFUNCTION.
    assert :INFRINGES_UNION_LAW in report.classification
    assert :MALFUNCTION in report.classification
    refute :HARM_TO_RIGHTS in report.classification

    # The authority channels are honestly OPEN: prepared, never transmitted.
    for id <- [:art73_market_surveillance, :art27_1f_fria_notification] do
      assert {:ok, %{status: :PREPARED_NOT_TRANSMITTED, channel_id: ^id,
                     incident_id: incident_id, classification: classification}} =
               AuthorityChannel.transmit(report, id)

      assert incident_id == report.incident_id
      assert classification == report.classification
    end

    # The internal channel records for real (contrast leg).
    assert {:ok, %{status: :RECORDED, incident_id: incident_id}} =
             AuthorityChannel.transmit(report, :internal_escalation_receipt_corpus)

    assert incident_id == report.incident_id
  end

  # -- court 3: incident identity is content-derived (causality) ---------------

  test "court 3 — incident identity is derived from the executed evidence, deterministically, and tracks its inputs" do
    r1 = real_refusal_receipt()
    r2 = real_denial_receipt()

    {:ok, report_a} = IncidentReport.build([r1, r2])
    {:ok, report_b} = IncidentReport.build([r1, r2])

    # Deterministic: same executed evidence -> same identity.
    assert report_a.incident_id == report_b.incident_id

    # Causality: change the evidence -> the identity tracks it.
    {:ok, report_c} = IncidentReport.build([r1])

    assert report_c.incident_id != report_a.incident_id

    # The report carries the real digests of the executed evidence.
    assert r1.id in report_a.originating_receipt_digests
    assert r2.id in report_a.originating_receipt_digests

    # The FRIA's open-gap authority entry is present and typed honest.
    {:ok, fria} = OversightGovernance.fria()
    gap_entries = Enum.filter(fria.rights, &(&1.status == :OPEN_GAP))
    assert Enum.any?(gap_entries, fn e -> String.contains?(e.article, "26.5") end)
  end
end
