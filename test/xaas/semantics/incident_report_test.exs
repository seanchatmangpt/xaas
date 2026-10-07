defmodule Xaas.Semantics.IncidentReportTest do
  use ExUnit.Case, async: true

  alias Xaas.Semantics.IncidentReport

  @t1 ~U[2026-10-06 10:00:00Z]
  @t2 ~U[2026-10-06 12:00:00Z]

  describe "build/2" do
    test "builds a complete Art 73-shaped report from witnessed refusals" do
      receipts = [
        %{
          digest: "sha256:aaa",
          refusal_atom: :REFUSED_EUAIA_SOCIAL_SCORING,
          observed_at: @t2
        },
        %{
          digest: "sha256:bbb",
          refusal_atom: :REFUSED_PROJECTION_DRIFT,
          status: :refused,
          rights_harm: true,
          observed_at: @t1
        }
      ]

      assert {:ok, report} = IncidentReport.build(receipts)

      assert report.originating_receipt_digests == ["sha256:aaa", "sha256:bbb"]

      assert report.classification == [:HARM_TO_RIGHTS, :INFRINGES_UNION_LAW, :MALFUNCTION]

      assert report.description =~ "classification [:HARM_TO_RIGHTS, :INFRINGES_UNION_LAW, :MALFUNCTION]"
      assert report.temporal.first_observed == @t1
      assert report.temporal.last_observed == @t2
      assert String.starts_with?(report.incident_id, "INC-")
    end

    test "empty receipts are typed-refused" do
      assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} = IncidentReport.build([])
      assert {:error, :REFUSED_NO_INCIDENT_EVIDENCE} = IncidentReport.build(nil)
    end

    test "classification is deterministic and order-independent" do
      a = %{digest: "d1", refusal_atom: :REFUSED_EUAIA_EMOTION_RECOGNITION, observed_at: @t1}
      b = %{digest: "d2", status: :error, observed_at: @t2}

      {:ok, r1} = IncidentReport.build([a, b])
      {:ok, r2} = IncidentReport.build([b, a])

      assert r1.classification == r2.classification
      assert r1.classification == [:INFRINGES_UNION_LAW, :MALFUNCTION]
    end

    test "digests fall back to a deterministic hash when absent" do
      receipt = %{refusal_atom: :REFUSED_EUAIA_REALTIME_RBI, observed_at: @t1}

      assert {:ok, r1} = IncidentReport.build([receipt])
      assert {:ok, r2} = IncidentReport.build([receipt])

      assert r1.originating_receipt_digests == r2.originating_receipt_digests
      assert [digest] = r1.originating_receipt_digests
      assert String.starts_with?(digest, "sha256:")
    end

    test "same receipts yield the same incident_id (deterministic)" do
      receipts = [%{digest: "x", refusal_atom: :REFUSED_EUAIA_MANIPULATIVE, observed_at: @t1}]
      {:ok, r1} = IncidentReport.build(receipts)
      {:ok, r2} = IncidentReport.build(receipts)
      assert r1.incident_id == r2.incident_id
    end
  end

  describe "EUAIA admission refusals are not MALFUNCTION (W679 regression)" do
    test "a REFUSED_EUAIA_* refused receipt classifies without :MALFUNCTION" do
      for atom <- Xaas.Semantics.EuAiActAdmission.refusal_atoms() do
        receipt = %{
          digest: "sha256:" <> Atom.to_string(atom),
          refusal_atom: atom,
          status: :refused,
          observed_at: @t1
        }

        assert {:ok, report} = IncidentReport.build([receipt])

        assert report.classification == [:INFRINGES_UNION_LAW],
               "#{inspect(atom)} must not classify :MALFUNCTION"
      end
    end

    test "a genuine non-EUAIA refusal is still :MALFUNCTION" do
      receipt = %{
        digest: "sha256:infra",
        refusal_atom: :REFUSED_INFRASTRUCTURE_FAULT,
        status: :refused,
        observed_at: @t1
      }

      assert {:ok, report} = IncidentReport.build([receipt])

      assert report.classification == [:MALFUNCTION]
    end

    test "an :error status alone is still :MALFUNCTION" do
      receipt = %{digest: "d", status: :error, observed_at: @t1}

      assert {:ok, report} = IncidentReport.build([receipt])
      assert report.classification == [:MALFUNCTION]
    end
  end

  describe "transmit/1" do
    test "honestly reports PREPARED_NOT_TRANSMITTED (typed OPEN, corpus 73.4-73.5)" do
      {:ok, report} =
        IncidentReport.build([%{digest: "d", refusal_atom: :REFUSED_EUAIA_MANIPULATIVE}])

      assert {:ok, %{status: :PREPARED_NOT_TRANSMITTED, reason: reason}} =
               IncidentReport.transmit(report)

      assert reason =~ "typed OPEN"
      assert reason =~ "73.4-73.5"
    end
  end
end
