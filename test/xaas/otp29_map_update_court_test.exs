defmodule Xaas.Otp29MapUpdateCourtTest do
  @moduledoc """
  W606 / WP-4 / OS-20 court: `Map.update/4` absent-key behavior under the
  OTP-29 prospective deviation. Probe evidence (2026-10-07, Elixir 1.20.2,
  OTP 28): absent key seeds the default WITHOUT calling the fun; present
  key applies the fun. No skip observed on the pinned runtime — hazard is
  prospective, so this court pins the defensive-hardened contract:
  deterministic key insertion across populated and empty baselines for
  every patched site's module.
  """

  use ExUnit.Case, async: true

  alias Xaas.Ultracode.RunValidation

  describe "runtime probe (recorded)" do
    test "otp-28 Map.update/4 seeds default on absent key, fun not called" do
      fun = fn v -> v + 1 end

      assert Map.update(%{}, :k, 0, fun) == %{k: 0}
      # fun observed? seed path must not apply it
      assert Map.update(%{}, :k, 7, fn v -> v * 100 end) == %{k: 7}
      assert Map.update(%{k: 5}, :k, 0, fun) == %{k: 6}
      # arity is 4 in Elixir (directive's "/4" confirmed); :maps.update/3 is the BEAM one
      assert {:module, Map} == Code.ensure_loaded(Map)
      assert function_exported?(Map, :update, 4)
      refute function_exported?(Map, :update, 3)
    end
  end

  describe "patched site: RunValidation.court_event/1 (run_validation.ex:658)" do
    test "empty map baseline — 'relationships' inserted deterministically as []" do
      out = RunValidation.court_event(%{})
      assert %{} = out["attributes"]
      assert out["relationships"] == []
      refute Map.has_key?(out, "ocel:events")
    end

    test "populated baseline — list rels are courted, key value deterministic" do
      event = %{
        "type" => "run",
        "relationships" => [%{"objectId" => "o1"}, %{"qualifier" => "x"}]
      }

      out = RunValidation.court_event(event)

      assert out["relationships"] == [
               %{"objectId" => "o1", "qualifier" => "related"},
               %{"qualifier" => "x"}
             ]
    end

    test "populated baseline with non-list relationships passes through unchanged" do
      event = %{"relationships" => "scalar"}
      assert RunValidation.court_event(event)["relationships"] == "scalar"
    end

    test "absent relationships among other keys — still seeded []" do
      out = RunValidation.court_event(%{"type" => "e", "id" => "1"})
      assert out["relationships"] == []
      assert out["id"] == "1"
    end

    test "non-map input returned as-is" do
      assert RunValidation.court_event("nope") == "nope"
      assert RunValidation.court_event(nil) == nil
    end

    test "parameterized: both baselines yield the same 'relationships' key/value class" do
      for baseline <- [%{}, %{"relationships" => []}, %{"relationships" => [%{"objectId" => "o"}]}] do
        out = RunValidation.court_event(baseline)
        assert Map.has_key?(out, "relationships")
        assert is_list(out["relationships"])
      end
    end
  end

  describe "integration through the real validate/2 path" do
    test "conformance normalizes an event with no relationships key" do
      log = %{
        "ocel:events" => [%{"type" => "t", "attributes" => %{"outcome" => "ok"}}]
      }

      # must not raise and must not depend on update/4 deviation behavior;
      # the event survives to the court stage (malformed only for missing
      # id/time — its "relationships" normalization is not the failure).
      {violations, _, _} = RunValidation.conformance(log)
      assert is_list(violations)

      refute Enum.any?(violations, fn v ->
               String.contains?(v.message, "relationships")
             end)
    end
  end
end
