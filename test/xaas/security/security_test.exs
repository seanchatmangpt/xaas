defmodule Xaas.SecurityTest do
  use ExUnit.Case, async: false

  alias Xaas.Security

  @fixture """
  {
    "repo": "xaas",
    "scan_date": "2026-10-05T00:00:00Z",
    "findings": [
      {"severity": "critical", "source": "sobelow", "file": "lib/xaas_web/router.ex",
       "line": 42, "description": "XSS in conn resp", "disposition": "refused_by_design",
       "court_ref": "court-1"},
      {"severity": "high", "source": "hex_audit", "file": "mix.lock",
       "description": "CVE-2026-1234 in dep", "disposition": "fixed"},
      {"severity": "medium", "source": "trivy", "file": "Dockerfile",
       "line": 7, "description": "base image CVE", "disposition": "accepted_typed"},
      {"severity": "low", "source": "mutation", "file": "lib/xaas/security.ex",
       "description": "surviving mutant", "disposition": "pending"},
      {"severity": "info", "source": "red_team", "file": "docs/threat-model.md",
       "description": "informational note"}
    ]
  }
  """

  test "ingest creates findings and a posture with matching counts" do
    {:ok, posture} = Security.ingest(Jason.decode!(@fixture))

    assert posture.total_findings == 5
    assert posture.critical_count == 1
    assert posture.high_count == 1
    assert posture.medium_count == 1
    assert posture.low_count == 1
    assert posture.info_count == 1
    assert posture.dispositioned_count == 3
    assert posture.repo == "xaas"
    assert %DateTime{} = posture.scan_date

    findings = Ash.read!(Security.Finding)
    assert length(findings) == 5
    assert Enum.any?(findings, &(&1.severity == :critical and &1.source == :sobelow))
    assert Enum.any?(findings, &(&1.court_ref == "court-1"))
  end

  test "posture_summary aggregates and green requires all dispositions" do
    {:ok, _} = Security.ingest(Jason.decode!(@fixture))

    summary = Security.posture_summary()
    assert summary.total_findings == 5
    assert summary.dispositioned_count == 3
    # one finding is still pending, so the estate is not green
    refute summary.green
  end

  test "a fully dispositioned scan is green" do
    fully_dispositioned = %{
      "repo" => "green-repo",
      "findings" => [
        %{"severity" => "high", "source" => "trivy", "file" => "a.txt",
         "description" => "d", "disposition" => "fixed"},
        %{"severity" => "low", "source" => "mutation", "file" => "b.txt",
         "description" => "d2", "disposition" => "refused_by_design"}
      ]
    }

    {:ok, posture} = Security.ingest(fully_dispositioned)
    assert posture.green
    assert Security.posture_summary().green
  end

  test "invalid severity is refused" do
    assert_raise Ash.Error.Invalid, fn ->
      Security.ingest(%{
        "repo" => "bad",
        "findings" => [
          %{"severity" => "apocalyptic", "source" => "trivy", "file" => "x",
           "description" => "d"}
        ]
      })
    end
  end
end
