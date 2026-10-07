defmodule Xaas.Chicago.NegativeCourts.EvidenceCourtsTest do
  @moduledoc """
  Lane L8 runtime evidence courts (wave-1 design, file 4) over the real
  `Xaas.Chicago.Court` (RESOLUTIONS.md R4), inside the REAL Postgres sandbox:

    * CHI-CASE-007 missing evidence — a claimed dispatch without evidence
      cannot promote standing (`:missing_evidence`, never ALIVE); with the
      required evidence present the court admits (positive control);
    * CHI-CASE-008 stale subject — evidence bound to a foreign subject is
      refused, never generalized (`:stale_subject`, binding :evidence); a
      request bound to a foreign subject is refused at law 2 (binding
      :request); exact-subject evidence admits (exact-subject positive
      control);
    * no verdict anywhere in the matrix promotes standing (R8): refusals
      never ALIVE, admissions stay UNKNOWN;
    * persistence court over REAL rows: running all ten case decisions plus
      reconcile creates ZERO new `Xaas.Ultracode.Run`/`Epoch` rows in the
      sandbox — the deterministic in-memory court owns no runtime rows
      (runtime state folding is L5's seam, not the projection's).
  """

  use Xaas.DataCase, async: true

  Code.require_file("support/mutants.ex", __DIR__)
  alias Xaas.Chicago.Court
  alias Xaas.Chicago.NegativeCourts.Mutants, as: M

  # Xaas.DataCase checks out Xaas.LegacyRepo; the Xaas.* Ash resources
  # (Xaas.Ultracode.*) live on Xaas.Repo — check out the real sandbox for it
  # (same pattern as XaasWeb.ExecutionFabricControllerTest).
  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  ## CHI-CASE-007: missing evidence cannot promote standing ####################

  test "CHI-CASE-007: a claimed dispatch without evidence is refused :missing_evidence and never promotes standing" do
    refused = M.decide_case("CHI-CASE-007")

    M.assert_refusal(refused, :missing_evidence)
    assert %{missing: [:evidence]} = elem(refused, 2)
    M.assert_no_standing_promotion(refused)

    # positive control: with the required exact-subject evidence present the
    # court admits — the evidence law can actually pass
    M.assert_admitted(M.decide_case("CHI-CASE-001"))

    M.assert_deterministic(fn -> M.decide_case("CHI-CASE-007") end)
  end

  ## CHI-CASE-008: stale or mismatched subject #################################

  test "CHI-CASE-008: foreign-subject EVIDENCE is refused :stale_subject (binding :evidence)" do
    refused = M.decide_case("CHI-CASE-008")

    M.assert_refusal(refused, :stale_subject)
    assert %{binding: :evidence, expected: expected, got: got} = elem(refused, 2)
    assert expected == M.subject()
    assert got == M.foreign_subject()
    M.assert_no_standing_promotion(refused)
  end

  test "CHI-CASE-008: a REQUEST bound to a foreign subject is refused :stale_subject (binding :request)" do
    refused =
      Court.decide(
        Court.bounded_purchase(%{subject: M.foreign_subject()}),
        Court.baseline_policy()
      )

    M.assert_refusal(refused, :stale_subject)
    assert %{binding: :request, got: got} = elem(refused, 2)
    assert got == M.foreign_subject()
    M.assert_no_standing_promotion(refused)
  end

  test "CHI-CASE-008 exact-subject positive control: evidence bound to THE exact Chicago subject admits" do
    exact =
      Court.decide(
        Court.bounded_purchase(%{
          evidence: %{subject: M.subject(), kind: :exact_subject_observation}
        }),
        Court.baseline_policy()
      )

    M.assert_admitted(exact)
    M.assert_standing_unknown(exact)
  end

  ## Standing law over the whole matrix (R8) ###################################

  test "no verdict anywhere in the matrix promotes standing: refusals never ALIVE, admissions stay UNKNOWN" do
    for id <- tl(M.case_identifiers()) do
      verdict = M.decide_case(id)
      M.assert_refusal(verdict, M.case_refusal_atom(id))
      M.assert_no_standing_promotion(verdict)
    end

    M.assert_standing_unknown(M.decide_case("CHI-CASE-001"))
    M.assert_standing_unknown(M.decide_provider_unavailable_alternative_preserved())
  end

  ## Persistence court over REAL sandbox rows ##################################

  test "court activity owns zero runtime rows: no new Xaas.Ultracode Run/Epoch rows in the real sandbox" do
    runs_before = run_count()
    epochs_before = epoch_count()

    for id <- M.case_identifiers() do
      M.decide_case(id)
    end

    M.reconcile_unknown_after_dispatch()

    assert run_count() == runs_before, "decide/reconcile must not create Xaas.Ultracode.Run rows"

    assert epoch_count() == epochs_before,
           "decide/reconcile must not create Xaas.Ultracode.Epoch rows"
  end

  # Run/Epoch are tenant-:enforced by default; the row-count invariant needs
  # the unscoped allow_global read (same seam the resource documents for
  # crown/roller internals), no tenant — counting across all tenants.
  defp run_count do
    Xaas.Ultracode.Run
    |> Ash.Query.select([])
    |> Ash.read!(action: :read_unscoped, authorize?: false)
    |> length()
  end

  defp epoch_count do
    Xaas.Ultracode.Epoch
    |> Ash.Query.select([])
    |> Ash.read!(action: :read_unscoped, authorize?: false)
    |> length()
  end
end
