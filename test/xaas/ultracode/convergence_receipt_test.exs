defmodule Xaas.Ultracode.ConvergenceReceiptTest do
  @moduledoc """
  Chicago qualification of the L4 epistemic-horizon machinery
  (`Xaas.Ultracode.ConvergenceReceipt`, `Xaas.Ultracode.Andon`, the OCEL
  `ConvergenceFailed` declaration). Real collaborators only: the pure mint,
  the real Andon GenServer + ETS, the real OCEL validator. The crown's
  end-to-end horizon exhaustion over real subprocesses lives in
  semantic_crown_test.exs ("a never-converging order exhausts..."); the
  drive's halt is falsified at the source level (the repo's established
  grep-level falsifier pattern for a branch only a subprocess harness can
  reach).

  The fleet R standing pattern is asserted from the REAL fleet schema
  (`~/.claude/dfcm/receipt.schema.json`) when this machine carries it, and
  from the embedded copy of the same pattern otherwise (named, never
  silent).
  """

  use ExUnit.Case, async: false

  alias Xaas.Ultracode.Andon
  alias Xaas.Ultracode.ConvergenceReceipt
  alias Xaas.Ultracode.Ocel.Validator
  alias Xaas.Ultracode.SemanticDrive.Ocel

  @fleet_schema Path.expand("~/.claude/dfcm/receipt.schema.json")

  # Verbatim from ~/.claude/dfcm/receipt.schema.json ("standing".value
  # pattern), embedded so the standing law holds where the fleet file does
  # not exist (a bare CI runner). When the real file is present the test
  # asserts the two agree.
  @standing_pattern ~r/^(UNKNOWN|PARTIAL_ALIVE|ALIVE|BLOCKED(:.+)?|BUILD_BROKEN|UNSUPPORTED(\(.+\))?|REFUSED\(.+\))$/

  @ctx %{
    identity: "EP-A",
    k_max: 3,
    attempts: [
      %{"cycle" => 1, "non_advancing" => true, "standing" => "UNKNOWN"},
      %{"cycle" => 2, "non_advancing" => true, "standing" => "UNKNOWN"}
    ],
    source: "semantic_drive"
  }

  describe "mint/1 -- the FAILED_CONVERGENCE receipt" do
    test "carries exactly the receipt shape at the exhausted horizon" do
      receipt = ConvergenceReceipt.mint(@ctx)

      assert %{
               "receipt_class" => "FAILED_CONVERGENCE",
               "identity" => "EP-A",
               "k_max" => 3,
               "attempts" => attempts,
               "horizon_witness" => witness,
               "standing" => "BLOCKED:epistemic_horizon_exceeded",
               "source" => "semantic_drive"
             } = receipt

      assert length(attempts) == 2
      assert is_binary(witness) and witness != ""

      # self-check: the witness recomputes over the receipt's own attempts
      assert ConvergenceReceipt.valid?(receipt)

      # and the witness is a sha256:hex over the canonical JSON
      assert String.starts_with?(witness, "sha256:")
      assert String.length(witness) == 71
    end

    test "the witness is the no-drift fingerprint: same attempts -> same witness, any change moves it" do
      %{"horizon_witness" => witness} = ConvergenceReceipt.mint(@ctx)
      assert %{"horizon_witness" => witness} = ConvergenceReceipt.mint(@ctx)

      moved =
        ConvergenceReceipt.mint(%{@ctx | attempts: tl(@ctx.attempts)})["horizon_witness"]

      refute moved == witness

      # key ORDER inside an attempt map does not move the canon-JSON witness
      first = %{"standing" => "UNKNOWN", "non_advancing" => true, "cycle" => 1}

      reordered =
        ConvergenceReceipt.mint(%{
          @ctx
          | attempts: [first | tl(@ctx.attempts)]
        })["horizon_witness"]

      assert reordered == witness
    end

    test "valid?/1 refuses a tampered witness (the receipt proves itself)" do
      receipt = ConvergenceReceipt.mint(@ctx)
      assert ConvergenceReceipt.valid?(receipt)

      tampered = Map.put(receipt, "horizon_witness", "sha256:" <> String.duplicate("0", 64))
      refute ConvergenceReceipt.valid?(tampered)

      # and the class/standing guards
      refute ConvergenceReceipt.valid?(Map.put(receipt, "receipt_class", "ALIVE"))
      refute ConvergenceReceipt.valid?(Map.put(receipt, "standing", "ALIVE"))
      refute ConvergenceReceipt.valid?(Map.put(receipt, "k_max", 0))
      refute ConvergenceReceipt.valid?(Map.put(receipt, "attempts", "not-a-list"))
      refute ConvergenceReceipt.valid?(nil)
      refute ConvergenceReceipt.valid?(%{})
    end

    test "the standing rides the EXISTING R standing enum (BLOCKED(:reason) -- no new value)" do
      assert ConvergenceReceipt.standing() == "BLOCKED:epistemic_horizon_exceeded"
      assert ConvergenceReceipt.standing() =~ @standing_pattern

      # When the real fleet schema is on this machine it must still declare
      # the same pattern (no drift between this test and the fleet gate).
      if File.regular?(@fleet_schema) do
        schema = @fleet_schema |> File.read!() |> Jason.decode!()

        fleet_pattern = schema["properties"]["standing"]["properties"]["value"]["pattern"]

        assert ConvergenceReceipt.standing() =~ Regex.compile!(fleet_pattern)

        # the embedded copy is the real pattern (the same source text)
        assert fleet_pattern ==
                 "^(UNKNOWN|PARTIAL_ALIVE|ALIVE|BLOCKED(:.+)?|BUILD_BROKEN|UNSUPPORTED(\\(.+\\))?|REFUSED\\(.+\\))$"
      else
        raise("fleet schema absent at #{@fleet_schema}; the standing law cannot be witnessed")
      end
    end

    test "pplan horizon mapping: {:horizon_exceeded, k, witness} -> source ash_pplan_horizon" do
      receipt =
        ConvergenceReceipt.mint(%{
          identity: "EP-A",
          k_max: 9,
          attempts: [%{"cycle" => 10, "non_advancing" => true}],
          pplan_failure: {:horizon_exceeded, 9, "witnesshex"}
        })

      assert %{
               "source" => %{"kind" => "ash_pplan_horizon", "k" => 9, "witness" => "witnesshex"}
             } = receipt
    end

    test "Replan AttemptBudget mapping: :replan_exhausted -> FAILED_CONVERGENCE (replan_attempt_budget)" do
      receipt =
        ConvergenceReceipt.mint(%{
          identity: "EP-A",
          k_max: 3,
          attempts: [%{"note" => "provider refused"}],
          pplan_failure: :replan_exhausted
        })

      assert receipt["source"] == %{
               "kind" => "replan_attempt_budget",
               "reason" => "replan_exhausted"
             }
    end

    test "no source, no pplan failure: the source key is absent, never defaulted" do
      receipt =
        ConvergenceReceipt.mint(%{identity: "EP-A", k_max: 2, attempts: [%{"note" => "x"}]})

      refute Map.has_key?(receipt, "source")
    end
  end

  describe "ocel_event/1 -- the ConvergenceFailed extension class" do
    test "declared, validating in the court form, refused undeclared" do
      assert "ConvergenceFailed" in Ocel.extension_classes()

      receipt = ConvergenceReceipt.mint(@ctx)
      event = ConvergenceReceipt.ocel_event(receipt)

      assert event.type == "ConvergenceFailed"
      assert event.relationships == [{"workorder:EP-A", "work-order"}]
      assert event.attributes["k_max"] == 3
      assert event.attributes["standing"] == "BLOCKED:epistemic_horizon_exceeded"

      observations =
        {[event],
         %{
           "workorder:EP-A" => %{type: "WorkOrder", attributes: %{}, relationships: []}
         }}

      declared = Ocel.event_classes() ++ ["ConvergenceFailed"]
      court = Ocel.court_form(observations, declared)
      standard = Ocel.standard_form(observations, declared)

      assert {:ok, %{"status" => "valid"}} = Validator.validate(court)
      assert Ocel.equivalent?(court, standard)

      # fail-closed: the same event over the undeclared default is refused
      undeclared = Ocel.court_form(observations)
      assert {:error, violations} = Validator.validate(undeclared)
      assert Enum.any?(violations, &String.contains?(&1.reason, "ConvergenceFailed"))
    end

    test "the drive halt branch mints via ConvergenceReceipt, trips Andon and records the artifact (grep-level falsifier)" do
      source = File.read!("lib/xaas/ultracode/semantic_drive.ex")

      assert source =~ "defp horizon_halts?"

      # the helper has two clauses; take everything after the LAST one
      halt = String.split(source, "defp horizon_halts?") |> Enum.at(-1)

      assert halt =~ "ConvergenceReceipt.mint"
      assert halt =~ "Andon.trip"
      assert halt =~ "convergence-failed.json"
      assert halt =~ "ConvergenceFailed"
      assert halt =~ "epistemic_horizon_exceeded"
    end
  end

  describe "Andon -- the cord" do
    test "trips record, tripped? reads true, the record carries the receipt digest" do
      start_supervised!(Andon)

      :ok =
        Andon.trip("drive:EP-A", %{
          "reason" => "BLOCKED:epistemic_horizon_exceeded",
          "receipt_digest" => "sha256:" <> String.duplicate("a", 64)
        })

      assert Andon.tripped?("drive:EP-A")
      assert refute_cord("drive:EP-B")

      assert {:ok, trip} = Andon.trip_record("drive:EP-A")
      assert trip.cord_id == "drive:EP-A"
      assert trip.reason == "BLOCKED:epistemic_horizon_exceeded"
      assert trip.receipt_digest == "sha256:" <> String.duplicate("a", 64)
      assert %DateTime{} = trip.tripped_at

      assert [%{cord_id: "drive:EP-A"}] = Andon.trips()
    end

    test "a bare reason binary trips too" do
      start_supervised!(Andon)

      :ok = Andon.trip("crown:SJ-CROWN-A", "manual")

      assert {:ok, trip} = Andon.trip_record("crown:SJ-CROWN-A")
      assert trip.reason == "manual"
      assert trip.receipt_digest == nil
    end

    test "disabled path: no Andon running -> trip/2 is a no-op :ok and tripped?/1 reads false" do
      # no start_supervised! -- the default boot (andon_enabled unset or
      # false) has no Andon process and no table
      assert :ets.info(Andon, :name) == :undefined

      assert Andon.trip("crown:none", "should not record") == :ok
      assert Andon.tripped?("crown:none") == false
      assert Andon.trip_record("crown:none") == :error
      assert Andon.trips() == []
    end

    test "the supervised opt-in: AndonSupervisor starts a working cord" do
      start_supervised!(Xaas.Ultracode.AndonSupervisor)

      :ok = Andon.trip("supervised:1", "cord up")

      assert Andon.tripped?("supervised:1")
      assert Process.whereis(Xaas.Ultracode.AndonSupervisor)
      assert Process.alive?(Process.whereis(Andon))
    end

    test "application opt-in default: :andon_enabled is unset/false so default boots are unchanged" do
      refute Application.get_env(:xaas, :andon_enabled, false)
    end
  end

  defp refute_cord(cord_id), do: not Andon.tripped?(cord_id)
end
