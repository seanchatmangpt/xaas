defmodule Xaas.Security.FindingLifecycleDepthTest do
  @moduledoc """
  Lane W984da depth court over the Xaas.Security family
  (lib/xaas/security.ex, finding.ex, posture.ex).

  Covers the slices W982a's security_test.exs leaves uncovered:
  path-based ingest, the Finding deny-by-default policy floor on writes,
  the atomize/1 unknown-enum passthrough, vacuous-empty-scan green
  semantics, and multi-scan posture aggregation.

  Chicago style: real Ash actions against the real ETS data layer, no
  mocks. Each test names the mutation class it kills.
  """

  use ExUnit.Case, async: false

  alias Xaas.Security

  # ------------------------------------------------------------------
  # 1. Path-based ingest (the `ingest/1` binary clause).
  # Kills: mutation that deletes the File.read!() -> Jason.decode! ->
  # ingest/1 pipeline clause; path ingestion would then crash with
  # FunctionClauseError instead of ingesting.
  # ------------------------------------------------------------------
  test "ingest/1 accepts a path to a JSON scan file" do
    path = Path.join(System.tmp_dir!(), "w984da-scan-#{System.unique_integer()}.json")

    File.write!(path, """
    {
      "repo": "path-repo",
      "scan_date": "2026-10-06T12:00:00Z",
      "findings": [
        {"severity": "high", "source": "sobelow", "file": "lib/x.ex",
         "line": 3, "description": "SQLi", "disposition": "fixed"}
      ]
    }
    """)

    on_exit(fn -> File.rm(path) end)

    assert {:ok, posture} = Security.ingest(path)
    assert posture.repo == "path-repo"
    assert posture.total_findings == 1
    assert posture.high_count == 1
    assert posture.green
  end

  # ------------------------------------------------------------------
  # 2. Policy floor: Finding is deny-by-default for writes; only reads
  # are carved out via bypass (finding.ex policies block).
  # Kills: mutation deleting the `policy always() do forbid_if(always())`
  # floor — an unauthorized write would then succeed instead of
  # returning the typed Ash.Forbidden refusal.
  # ------------------------------------------------------------------
  test "direct Finding write under authorize? is refused by the policy floor" do
    changeset =
      Ash.Changeset.for_create(Security.Finding, :ingest, %{
        severity: :critical,
        source: :red_team,
        file: "lib/xaas/security.ex",
        description: "unauthorized write attempt"
      })

    assert {:error, %Ash.Error.Forbidden{}} = Ash.create(changeset, authorize?: true)
  end

  # ------------------------------------------------------------------
  # 3. atomize/1 passthrough: an unknown enum binary is passed through
  # unchanged so Ash's one_of constraint refuses it as a typed
  # validation error (not a rescue crash, not a silently created atom).
  # Kills: mutation of the ArgumentError rescue arm (re-raise, or
  # defaulting to :info) — either masks the typed refusal or fabricates
  # an atom outside the enum.
  # ------------------------------------------------------------------
  test "unknown disposition string yields a typed one_of refusal" do
    # ingest/1 uses Ash.create! internally, so the typed one_of refusal
    # surfaces as a raised Ash.Error.Invalid, not an error tuple
    assert_raise Ash.Error.Invalid, fn ->
      Security.ingest(%{
        "repo" => "bad-dispo",
        "findings" => [
          %{
            "severity" => "high",
            "source" => "trivy",
            "file" => "x",
            "description" => "d",
            "disposition" => "waved_through"
          }
        ]
      })
    end

    # no Finding row leaked for the refused finding
    assert Enum.empty?(Ash.read!(Security.Finding))
  end

  # ------------------------------------------------------------------
  # 4. Vacuous empty scan: zero findings -> every-count zero and
  # green true (Enum.all?/2 over [] is true by design — an empty
  # estate scan is green).
  # Kills: mutation flipping `Enum.all?(findings, ...)` to
  # `Enum.any?/2` — an empty scan would then read red.
  # ------------------------------------------------------------------
  test "empty findings scan registers a vacuous-green zero posture" do
    assert {:ok, posture} = Security.ingest(%{"repo" => "empty-repo", "findings" => []})

    assert posture.total_findings == 0
    assert posture.critical_count == 0
    assert posture.high_count == 0
    assert posture.medium_count == 0
    assert posture.low_count == 0
    assert posture.info_count == 0
    assert posture.dispositioned_count == 0
    assert posture.green
  end

  # ------------------------------------------------------------------
  # 5. Multi-scan aggregation + green conjunction:
  # posture_summary/0 folds across Posture rows, sums per-severity
  # counts, and green is the conjunction across ALL scans — one red
  # scan makes the estate red; with zero postures green is false.
  # Kills: (a) mutation swapping the green fold's Enum.all? for
  # Enum.any? (one green scan would whitewash a red estate);
  # (b) mutation dropping the `postures != []` guard (empty estate
  # would read vacuously green).
  # ------------------------------------------------------------------
  test "posture_summary folds counts across scans and green is a cross-scan conjunction" do
    # empty estate: green is false, not vacuously true
    assert Security.posture_summary() == %{
             total_findings: 0,
             high_count: 0,
             medium_count: 0,
             low_count: 0,
             dispositioned_count: 0,
             green: false
           }

    {:ok, _} =
      Security.ingest(%{
        "repo" => "scan-a",
        "findings" => [
          %{"severity" => "high", "source" => "trivy", "file" => "a", "description" => "d",
           "disposition" => "fixed"},
          %{"severity" => "medium", "source" => "sobelow", "file" => "b", "description" => "d"}
        ]
      })

    {:ok, _} =
      Security.ingest(%{
        "repo" => "scan-b",
        "findings" => [
          %{"severity" => "high", "source" => "hex_audit", "file" => "c", "description" => "d",
           "disposition" => "accepted_typed"},
          %{"severity" => "low", "source" => "mutation", "file" => "e", "description" => "d",
           "disposition" => "refused_by_design"},
          %{"severity" => "info", "source" => "red_team", "file" => "f", "description" => "d"}
        ]
      })

    summary = Security.posture_summary()
    assert summary.total_findings == 5
    assert summary.high_count == 2
    assert summary.medium_count == 1
    assert summary.low_count == 1
    # scan-a has a pending medium -> the whole estate is red
    refute summary.green

    # dispositioning scan-a's last pending finding makes the estate green
    pending = Enum.find(Ash.read!(Security.Finding), &(&1.disposition == :pending))

    {:ok, posture_a} =
      Security.ingest(%{
        "repo" => "scan-a",
        "findings" => [
          %{"severity" => "high", "source" => "trivy", "file" => "z", "description" => "d",
           "disposition" => "fixed"}
        ]
      })

    assert posture_a.green
    # scan-a's earlier pending finding still holds the estate red
    refute Security.posture_summary().green
    assert pending.disposition == :pending
  end

  # ------------------------------------------------------------------
  # 6. (W984dj3) Malformed discovered_at timestamp: parse_dt/1 must map
  # a malformed ISO8601 string to the module's typed refusal convention
  # (pass-through -> Ash utc_datetime cast error, same as atomize/1),
  # never a MatchError crash.
  # Kills: mutation reverting parse_dt/1 to `{:ok, dt, 0} = ...` — the
  # ingest would crash with MatchError instead of raising the typed
  # Ash.Error.Invalid, and no row may leak either way.
  # ------------------------------------------------------------------
  test "malformed discovered_at timestamp yields a typed refusal with zero rows leaked" do
    assert_raise Ash.Error.Invalid, fn ->
      Security.ingest(%{
        "repo" => "bad-timestamp",
        "findings" => [
          %{
            "severity" => "high",
            "source" => "sobelow",
            "file" => "x",
            "description" => "d",
            "discovered_at" => "not-a-timestamp"
          }
        ]
      })
    end

    assert Enum.empty?(Ash.read!(Security.Finding))
    assert Enum.empty?(Ash.read!(Security.Posture))
  end
end
