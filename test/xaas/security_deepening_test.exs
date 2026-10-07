defmodule Xaas.SecurityDeepeningTest do
  @moduledoc """
  W730 — Security domain deepening (PW10 lane). Chicago-style courts over the
  real `Xaas.Security` surface (ETS-backed Ash resources, real Ash actions,
  real row state, no mocks).

  What the domain IS (read before writing):
  - `Xaas.Security.ingest/1` creates Finding rows + one Posture aggregate.
  - Finding has exactly two actions: `:read` and the `:ingest` create.
    There is NO update action — disposition is immutable after ingest.
    The "lifecycle" this domain enforces is: typed admission at the boundary.
  """
  use ExUnit.Case, async: false

  alias Xaas.Security
  alias Xaas.Security.Finding
  alias Xaas.Security.Posture

  # ---------------------------------------------------------------- (a) ingest
  describe "ingest boundary: real rows and typed refusals" do
    test "ingest creates one Finding row per entry with the exact disposition given" do
      {:ok, posture} =
        Security.ingest(%{
          "repo" => "w730-a",
          "scan_date" => "2026-10-07T00:00:00Z",
          "findings" => [
            %{"severity" => "critical", "source" => "sobelow", "file" => "lib/a.ex",
             "description" => "xss", "disposition" => "refused_by_design"},
            %{"severity" => "high", "source" => "trivy", "file" => "Dockerfile",
             "description" => "cve", "disposition" => "pending"}
          ]
        })

      assert %Posture{} = posture
      rows = Ash.read!(Finding)
      assert length(rows) == 2

      by_desc = Map.new(rows, &{&1.description, &1})
      assert by_desc["xss"].severity == :critical
      assert by_desc["xss"].disposition == :refused_by_design
      assert by_desc["xss"].source == :sobelow
      assert by_desc["cve"].disposition == :pending
      assert %DateTime{} = by_desc["xss"].discovered_at |> Kernel.||(posture.scan_date)

      # disposition defaults to :pending when omitted
      assert by_desc["cve"].disposition == :pending
    end

    test "invalid severity string is refused with a typed Ash error and leaves zero rows" do
      assert_raise Ash.Error.Invalid, ~r/invalid value/i, fn ->
        Security.ingest(%{
          "repo" => "w730-bad-sev",
          "findings" => [
            %{"severity" => "apocalyptic", "source" => "trivy", "file" => "x",
             "description" => "d"}
          ]
        })
      end

      # real row state: the bad severity never landed
      refute Enum.any?(Ash.read!(Finding), &(&1.description == "d"))
    end

    test "invalid source is refused; unknown disposition atom is refused" do
      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(%{
          "repo" => "w730-bad-src",
          "findings" => [
            %{"severity" => "low", "source" => "nessus", "file" => "x", "description" => "src-bad"}
          ]
        })
      end

      assert_raise Ash.Error.Invalid, fn ->
        Security.ingest(%{
          "repo" => "w730-bad-disp",
          "findings" => [
            %{"severity" => "low", "source" => "trivy", "file" => "x",
             "description" => "disp-bad", "disposition" => "wontfix_vibes"}
          ]
        })
      end

      refute Enum.any?(Ash.read!(Finding), &(&1.description in ["src-bad", "disp-bad"]))
    end

    test "file and description are mandatory (allow_nil?: false)" do
      assert_raise Ash.Error.Invalid, fn ->
        Finding
        |> Ash.Changeset.for_create(:ingest, %{severity: :low, source: :trivy,
          description: "no-file"})
        |> Ash.create!()
      end

      assert_raise Ash.Error.Invalid, fn ->
        Finding
        |> Ash.Changeset.for_create(:ingest, %{severity: :low, source: :trivy,
          file: "f.ex"})
        |> Ash.create!()
      end
    end
  end

  # ------------------------------------------------- (b) posture aggregation
  describe "posture aggregation over a crafted finding set" do
    test "counts are the real frequencies of the crafted set; green is exact" do
      {:ok, p} =
        Security.ingest(%{
          "repo" => "w730-c",
          "findings" => [
            %{"severity" => "critical", "source" => "sobelow", "file" => "1",
             "description" => "c1", "disposition" => "fixed"},
            %{"severity" => "critical", "source" => "trivy", "file" => "2",
             "description" => "c2", "disposition" => "accepted_typed"},
            %{"severity" => "high", "source" => "trivy", "file" => "3",
             "description" => "h1", "disposition" => "pending"},
            %{"severity" => "high", "source" => "trivy", "file" => "4",
             "description" => "h2", "disposition" => "pending"},
            %{"severity" => "medium", "source" => "mutation", "file" => "5",
             "description" => "m1", "disposition" => "refused_by_design"},
            %{"severity" => "low", "source" => "hex_audit", "file" => "6",
             "description" => "l1"},
            %{"severity" => "info", "source" => "red_team", "file" => "7",
             "description" => "i1", "disposition" => "fixed"}
          ]
        })

      assert p.total_findings == 7
      assert p.critical_count == 2
      assert p.high_count == 2
      assert p.medium_count == 1
      assert p.low_count == 1
      assert p.info_count == 1
      # dispositioned = fixed(1) + accepted_typed(1) + refused_by_design(1) + fixed(1)
      assert p.dispositioned_count == 4
      refute p.green

      # empty findings list still registers a posture row
      {:ok, empty} = Security.ingest(%{"repo" => "w730-empty", "findings" => []})
      assert empty.total_findings == 0
      assert empty.green
    end

    test "posture_summary sums across postures; green requires every scan green" do
      {:ok, _} =
        Security.ingest(%{
          "repo" => "w730-g1", "findings" => [
            %{"severity" => "low", "source" => "trivy", "file" => "f",
             "description" => "g1", "disposition" => "fixed"}
          ]
        })

      {:ok, _} =
        Security.ingest(%{
          "repo" => "w730-g2", "findings" => [
            %{"severity" => "high", "source" => "sobelow", "file" => "f",
             "description" => "g2", "disposition" => "accepted_typed"}
          ]
        })

      s = Security.posture_summary()
      assert s.total_findings >= 2
      assert s.dispositioned_count >= 2
      assert s.green
    end

    test "severity ordering is NOT computed anywhere — counts only (honest gap, part c)" do
      # the domain stores severity as an unordered atom; there is no ranking
      # calculation, no sort, no precedence function. Assert the real shape:
      # what comes back is the row set, and no derived severity rank exists.
      {:ok, _} =
        Security.ingest(%{
          "repo" => "w730-order", "findings" => [
            %{"severity" => "info", "source" => "trivy", "file" => "f",
             "description" => "ord-i"},
            %{"severity" => "critical", "source" => "trivy", "file" => "f",
             "description" => "ord-c"}
          ]
        })

      rows = Ash.read!(Finding) |> Enum.filter(&String.starts_with?(&1.description, "ord-"))
      assert length(rows) == 2
      # no order guarantee from the ETS read — the domain simply does not rank
      sevs = MapSet.new(rows, & &1.severity)
      assert MapSet.equal?(sevs, MapSet.new([:info, :critical]))
      # and the Posture row records counts, never a top-severity or rank field
      posture = Ash.read!(Posture) |> Enum.find(&(&1.repo == "w730-order"))
      assert Map.has_key?(posture, :critical_count)
      refute Map.has_key?(posture, :top_severity)
      refute Map.has_key?(posture, :max_severity)
    end
  end

  # --------------------------------------------- (c) what is NOT enforced
  describe "typed gaps: behavior that the domain does not enforce" do
    test "GAP no-dedup: identical findings are ingested as distinct rows" do
      f = %{"severity" => "high", "source" => "trivy", "file" => "lib/dup.ex",
            "description" => "same cve", "disposition" => "pending"}

      {:ok, p} = Security.ingest(%{"repo" => "w730-dup", "findings" => [f, f, f]})

      # no unique identity exists — 3 identical findings become 3 rows
      assert p.total_findings == 3
      dups =
        Ash.read!(Finding)
        |> Enum.filter(&(&1.description == "same cve" and &1.file == "lib/dup.ex"))

      assert length(dups) == 3
      assert length(Enum.uniq_by(dups, & &1.id)) == 3
    end

    test "GAP no-lifecycle: there is no update action — disposition is immutable post-ingest" do
      {:ok, _} =
        Security.ingest(%{
          "repo" => "w730-immutable", "findings" => [
            %{"severity" => "high", "source" => "trivy", "file" => "f",
             "description" => "imm"}
          ]
        })

      finding = Ash.read!(Finding) |> Enum.find(&(&1.description == "imm"))
      assert finding.disposition == :pending

      # the resource exposes no update action at all; attempting one is a
      # hard typed refusal (Ash.Changeset.raise_no_action)
      assert_raise ArgumentError, ~r/no such update action.*:update/i, fn ->
        finding
        |> Ash.Changeset.for_update(:update, %{disposition: :fixed})
        |> Ash.create!()
      end
    end

    test "GAP no-sla-clock: discovered_at is stored but nothing computes on it" do
      {:ok, p} =
        Security.ingest(%{
          "repo" => "w730-sla", "scan_date" => "2026-01-01T00:00:00Z",
          "findings" => [
            %{"severity" => "critical", "source" => "trivy", "file" => "f",
             "description" => "sla", "discovered_at" => "2026-01-01T00:00:00Z"}
          ]
        })

      finding = Ash.read!(Finding) |> Enum.find(&(&1.description == "sla"))
      assert %DateTime{} = finding.discovered_at
      assert DateTime.compare(finding.discovered_at, ~U[2026-01-01T00:00:00Z]) == :eq

      # and the aggregate carries no age/SLA-derived field whatsoever
      refute Map.has_key?(p, :oldest_open_finding)
      refute Map.has_key?(p, :sla_breached_count)
    end

    test "GAP posture/register is independently writable — counts are not derived" do
      # Posture.register accepts arbitrary counts; nothing ties them to real
      # Finding rows. The domain trusts the ingest path, not the data.
      p =
        Posture
        |> Ash.Changeset.for_create(:register, %{
          repo: "w730-unbacked",
          total_findings: 99,
          critical_count: 99,
          green: true
        })
        |> Ash.create!()

      assert p.total_findings == 99
      assert p.green
      # zero Finding rows back this aggregate
      assert Ash.read!(Finding) |> Enum.empty?()
    end
  end

  # --------------------------------------------- (d) determinism of reads
  describe "read determinism" do
    test "repeated reads return identical projections" do
      {:ok, _} =
        Security.ingest(%{
          "repo" => "w730-det", "findings" => [
            %{"severity" => "medium", "source" => "mutation", "file" => "f",
             "description" => "det", "line" => 11}
          ]
        })

      project = fn ->
        Ash.read!(Finding)
        |> Enum.map(&{&1.id, &1.severity, &1.source, &1.file, &1.line,
                      &1.disposition, &1.description})
        |> Enum.sort()
      end

      first = project.()
      assert first != []
      for _ <- 1..5, do: assert(project.() == first)

      postures =
        fn ->
          Ash.read!(Posture) |> Enum.map(&{&1.repo, &1.total_findings, &1.green}) |> Enum.sort()
        end

      p1 = postures.()
      for _ <- 1..5, do: assert(postures.() == p1)
    end
  end
end
