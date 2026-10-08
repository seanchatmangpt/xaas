defmodule Xaas.Semantics.CanonicalCourtW984jjTest do
  @moduledoc """
  Lane W984jj — unclaimed-family probe court.

  Primary target `Xaas.Semantics.Jcs` (the canonicalization module; there is
  no `canonical.ex`) is typed COVERED: W984hr already dispositioned it and
  three dedicated suites exist (jcs_test, jcs_property_test,
  jcs_doctest_test) covering key ordering, escapes, number serialization,
  determinism, round-trips, digest form, and the subset boundary. No filler
  tests re-court it here.

  Neighboring semantics helper excluded from W984hr's census:
  `Xaas.Semantics.IncidentReport` (Art 73). Census of every
  `IncidentReport.build/2` call site in the tree shows these branches were
  never exercised:

    - `Keyword.get(opts, :description) || default_description(...)` — the
      override branch was dead at every call site.
    - `Keyword.get(opts, :incident_id) || ("INC-" <> ...)` — same.
    - temporal `Enum.min/max` over receipts where some lack `observed_at`
      (the ~U[1970] fallback clause interacting with min/max).

  Chicago discipline: real module, real structs, no mocks, no interaction
  assertions. Each test names its mutation rationale: reverting the branch
  under court (hardcoding the default description / derived incident_id,
  or removing the epoch fallback) makes the test fail.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.IncidentReport

  @t1 ~U[2026-10-07 09:00:00Z]
  @t2 ~U[2026-10-07 15:00:00Z]

  describe "build/2 opts overrides (uncovered branches)" do
    # Mutation: hardcode default_description(receipts, classification),
    # dropping the `Keyword.get(opts, :description) ||` fallback.
    test "explicit :description overrides the derived default" do
      receipts = [%{digest: "jj-1", refusal_atom: :REFUSED_EUAIA_MANIPULATIVE, observed_at: @t1}]

      assert {:ok, report} =
               IncidentReport.build(receipts, description: "operator-supplied narrative")

      assert report.description == "operator-supplied narrative"
    end

    # Mutation: hardcode the derived "INC-" <> hash, dropping the
    # `Keyword.get(opts, :incident_id) ||` fallback.
    test "explicit :incident_id overrides the derived INC- hash" do
      receipts = [%{digest: "jj-2", refusal_atom: :REFUSED_INFRASTRUCTURE_FAULT, observed_at: @t1}]

      assert {:ok, report} = IncidentReport.build(receipts, incident_id: "INC-OPERATOR-77")

      assert report.incident_id == "INC-OPERATOR-77"
    end

    # Mutation: replace Keyword.get/2 with direct opts access that breaks the
    # nil-fallback, or invert the override priority.
    test "absent opts still derive defaults (override does not leak)" do
      receipts = [%{digest: "jj-3", refusal_atom: :REFUSED_PLAIN, observed_at: @t1}]

      assert {:ok, report} = IncidentReport.build(receipts)

      assert String.starts_with?(report.incident_id, "INC-")
      assert report.description =~ "Art 73(1) serious-incident report"
    end
  end

  describe "temporal bounds with epoch fallback (uncovered branch combination)" do
    # Mutation: change observed_at/1's ~U[1970-01-01 00:00:00Z] fallback value
    # or break Enum.min/max — first_observed/last_observed drift.
    test "receipt missing observed_at clamps temporal window via epoch fallback" do
      receipts = [
        %{digest: "jj-4", refusal_atom: :REFUSED_EUAIA_SOCIAL_SCORING, observed_at: @t2},
        %{digest: "jj-5", refusal_atom: :REFUSED_PLAIN, status: :refused}
      ]

      assert {:ok, report} = IncidentReport.build(receipts)

      assert report.temporal.first_observed == ~U[1970-01-01 00:00:00Z]
      assert report.temporal.last_observed == @t2
    end

    # Mutation: remove the observed_at/1 fallback clause entirely
    # (FunctionClauseError on receipts without observed_at).
    test "all-epoch receipts yield a stable epoch-window report" do
      receipts = [%{digest: "jj-6", refusal_atom: :REFUSED_PLAIN}]

      assert {:ok, report} = IncidentReport.build(receipts)

      assert report.temporal.first_observed == ~U[1970-01-01 00:00:00Z]
      assert report.temporal.last_observed == ~U[1970-01-01 00:00:00Z]
    end
  end
end
