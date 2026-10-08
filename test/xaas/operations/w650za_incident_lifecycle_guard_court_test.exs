defmodule Xaas.Operations.W650zaIncidentLifecycleGuardCourtTest do
  @moduledoc """
  W650za depth court: `Xaas.Operations.Validations.IncidentResolvedAtRequiresResolved`
  (best-of-pair pick) and its complement
  `Xaas.Operations.Validations.IncidentPostmortemFinalRequiresResolved`, both wired as
  `validate/1` on the real `Xaas.Operations.Incident` `:update` action (W902 batch 3,
  closing W793 gaps). W650z8 re-census: 0 direct prior tests; fresh grep over `test/`
  (this lane) confirms zero references before this file.

  Chicago: real sandboxed Postgres, real Ash actions, `authorize?: false` (the action
  layer is the subject, not the policy layer). No mocks. Typed refusals asserted
  as-real: we assert the actual error shape the validation returns, not just "it raised".
  """

  use ExUnit.Case, async: true

  alias Xaas.Operations.Incident

  require Ash.Query

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp org_id, do: "org-w650za-#{System.unique_integer([:positive])}"

  defp opened_at, do: DateTime.utc_now() |> DateTime.truncate(:second)

  defp create_open!(attrs \\ %{}) do
    Incident
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          org_id: org_id(),
          title: "w650za court incident",
          region: "us-east-1",
          severity: :critical,
          opened_at: opened_at()
        },
        attrs
      )
    )
    |> Ash.create!(authorize?: false)
  end

  defp update!(incident, attrs) do
    incident
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update!(authorize?: false)
  end

  defp update_error(incident, attrs) do
    incident
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update(authorize?: false)
  end

  test "1. resolved_at while status :open is a typed refusal naming :resolved_at" do
    incident = create_open!()

    {:error, error} = update_error(incident, %{resolved_at: opened_at()})

    # As-real typed refusal: the validation's exact field/message shape surfaces
    # through Ash's real error stack.
    messages =
      error.errors
      |> Enum.map(fn e -> {Map.get(e, :field), Map.get(e, :message)} end)

    assert {:resolved_at, msg} = Enum.find(messages, fn {f, _} -> f == :resolved_at end)
    assert msg =~ "status :open"
    assert msg =~ ":resolved"

    # Refused means no state change: the row is still open with no timestamp.
    still = Ash.get!(Incident, incident.id, authorize?: false)
    assert still.status == :open
    assert is_nil(still.resolved_at)

    # Mutation rationale: kills deletion of the
    # IncidentResolvedAtRequiresResolved validate line (the timestamp lands
    # silently on an open incident -- the exact W793-observed state), and
    # kills a mutate-to-:ok of validate/4's refusal branch.
  end

  test "2. the guard predicate is == :open on a real changeset: refuses open+timestamp, :ok on resolved-data annotation" do
    incident = create_open!()

    # Direct-function witness on a REAL changeset (built by the resource's real
    # :update action builder) -- the Incident status enum is exactly
    # [:open, :resolved] (lib/xaas/operations/types/incident_status.ex), so the
    # `== :open` vs `!= :resolved` distinction is only witnessable here, at the
    # predicate itself.
    changeset =
      incident
      |> Ash.Changeset.for_update(:update, %{resolved_at: opened_at(), status: :open})

    # The predicate is `resolved_at != nil and new_status == :open` on the
    # NEW status argument.
    assert {:error, opts} =
             Xaas.Operations.Validations.IncidentResolvedAtRequiresResolved.validate(
               changeset,
               [],
               %{}
             )

    assert opts[:field] == :resolved_at
    assert opts[:message] =~ "status :open"

    # Non-open branch: the same real changeset with status :resolved (the data
    # carried by the changeset from the prior resolve) is :ok -- annotation of a
    # resolved incident keeps its timestamp legally.
    resolved = update!(incident, %{status: :resolved, resolved_at: opened_at()})

    title_changeset =
      resolved
      |> Ash.Changeset.for_update(:update, %{title: "annotated after resolve"})

    assert :ok =
             Xaas.Operations.Validations.IncidentResolvedAtRequiresResolved.validate(
               title_changeset,
               [],
               %{}
             )

    # Mutation rationale: kills `== :open` -> `!= :resolved` is unreachable
    # (enum has no third value -- documented equivalence), kills the
    # data-fallback drop in final_status/1 and resolved_at fallback (a
    # status-only annotation update on a resolved row would mis-gate), and
    # kills `== :open` -> `true` (the legal annotation path would refuse).
  end

  test "3. status :resolved without resolved_at is refused by the complement guard -- the <=> invariant holds as a pair" do
    incident = create_open!()

    {:error, error} = update_error(incident, %{status: :resolved})

    messages =
      error.errors
      |> Enum.map(fn e -> {Map.get(e, :field), Map.get(e, :message)} end)

    assert {f, _} = Enum.find(messages, fn {f, _} -> f == :resolved_at end)
    assert f == :resolved_at
    assert Enum.any?(messages, fn {_, m} -> m =~ "is required when marking an incident resolved" end)

    # And the pair direction is not symmetric-sloppy: the reverse (resolved_at
    # present, status :resolved) is exactly the legal resolve in test 4.

    # Mutation rationale: kills deletion of IncidentResolvedRequiresResolvedAt
    # (a :resolved status with no timestamp -- the other half of the W793
    # <=> invariant). Deleting either half of the pair breaks this test.
  end

  test "4. real resolve passes and persists; the resolved state is terminal through :update" do
    incident = create_open!()

    resolved = update!(incident, %{status: :resolved, resolved_at: opened_at()})
    assert resolved.status == :resolved
    assert resolved.resolved_at != nil

    # Persisted for real: re-read from Postgres.
    reread = Ash.get!(Incident, incident.id, authorize?: false)
    assert reread.status == :resolved
    assert reread.resolved_at != nil

    # :resolved is terminal (IncidentResolvedIsTerminal): no silent reopen that
    # would leave resolved_at stranded on a non-resolved row.
    {:error, reopen_error} = update_error(reread, %{status: :open})
    assert reopen_error.errors != []

    # Mutation rationale: kills a wire-order swap where the resolve succeeds but
    # the timestamp is dropped before persistence, and kills deletion of
    # IncidentResolvedIsTerminal (reopen would strand the timestamp on an :open
    # row, re-creating the W793 state through the terminal guard's absence).
  end

  test "5. postmortem guard: :draft on :open is legal, :final on :open is a typed refusal, :final on :resolved passes" do
    incident = create_open!()

    # Annotation while open stays legal (the guard gates only the close-out).
    annotated = update!(incident, %{postmortem_status: :draft})
    assert annotated.postmortem_status == :draft

    {:error, error} = update_error(annotated, %{postmortem_status: :final})

    messages =
      error.errors
      |> Enum.map(fn e -> {Map.get(e, :field), Map.get(e, :message)} end)

    assert {:postmortem_status, msg} =
             Enum.find(messages, fn {f, _} -> f == :postmortem_status end)

    assert msg =~ ":final"
    assert msg =~ ":resolved"

    # Once resolved, the close-out is legal.
    resolved = update!(annotated, %{status: :resolved, resolved_at: opened_at()})
    finalized = update!(resolved, %{postmortem_status: :final})
    assert finalized.postmortem_status == :final

    # Mutation rationale: kills deletion of IncidentPostmortemFinalRequiresResolved
    # (:final lands on an :open incident -- the closed-out-postmortem-for-an-
    # unresolved-incident state W793 observed), kills broadening the guard to all
    # postmortem statuses (`:draft` on :open would refuse), and kills the
    # `final_status/1` data-fallback (a status-only update would read nil status
    # and mis-gate).
  end
end
