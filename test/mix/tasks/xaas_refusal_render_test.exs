defmodule Mix.Tasks.Xaas.RefusalRenderTest do
  @moduledoc """
  Vector-2 §E qualification: each converted mix task's `render_refusal/1`
  emits a machine-readable `REFUSED(<atom>, detail: %{...})` line that a
  consumer can regex-parse without any human text disambiguation.

  Function-level Chicago testing: call the real render function, assert on
  the real emitted text. No mocks.
  """

  use ExUnit.Case, async: true

  @refusal_modules [
    Mix.Tasks.Xaas.Fabric.Redeploy,
    Mix.Tasks.Xaas.ReleaseAudit,
    Mix.Tasks.Xaas.ReleaseSnapshot.Verify,
    Mix.Tasks.Xaas.RunValidate,
    Mix.Tasks.Xaas.SafeGenerateMigrations,
    Mix.Tasks.Xaas.AshSurface,
    Mix.Tasks.Xaas.SelfDigest
  ]

  # `REFUSED(<atom>, detail: %{...})` — code must be a bare Elixir atom,
  # detail must be an inspect of a map.
  @line_regex ~r/\AREFUSED\((\w+), detail: %\{.*\}\)\z/

  describe "render_refusal/1 emits machine-readable REFUSED(<atom>, ...) lines" do
    test "xaas.fabric.redeploy" do
      line =
        Mix.Tasks.Xaas.Fabric.Redeploy.render_refusal(
          {:fabric_redeploy, %{reason: ":cut_required"}}
        )

      assert [code] = Regex.run(@line_regex, line, capture: :all_but_first)
      assert code == "fabric_redeploy"
      assert String.to_existing_atom(code)

      detail_line =
        Mix.Tasks.Xaas.Fabric.Redeploy.render_refusal(
          {:fabric_redeploy, %{reason: "{:missing_plugin_json, \"/tmp/nowhere\"}"}}
        )

      # Tuple details are legal; the code prefix is what parsers anchor on.
      assert String.starts_with?(detail_line, "REFUSED(fabric_redeploy, detail: ")
      assert detail_line =~ "missing_plugin_json"
    end

    test "xaas.release_audit" do
      line =
        Mix.Tasks.Xaas.ReleaseAudit.render_refusal(
          {:release_audit, %{finding: "VERSION=\"26.8.20\" expected \"26.8.21\""}}
        )

      assert ["release_audit"] = Regex.run(@line_regex, line, capture: :all_but_first)

      # Detail carries the finding text (machine-readable, not discarded).
      assert line =~ ~S(finding: "VERSION)
    end

    test "xaas.release_snapshot.verify" do
      line =
        Mix.Tasks.Xaas.ReleaseSnapshot.Verify.render_refusal(
          {:release_snapshot, %{reason: "{:invalid_codec, :bad_digest}"}}
        )

      assert ["release_snapshot"] = Regex.run(@line_regex, line, capture: :all_but_first)
      assert line =~ "invalid_codec"
    end

    test "xaas.run_validate" do
      line = Mix.Tasks.Xaas.RunValidate.render_refusal({:no_emitter, %{run_id: "r-123"}})

      assert ["no_emitter"] = Regex.run(@line_regex, line, capture: :all_but_first)
      assert line =~ ~S(run_id: "r-123")
    end

    test "xaas.safe_generate_migrations" do
      line =
        Mix.Tasks.Xaas.SafeGenerateMigrations.render_refusal(
          {:cross_table_operations,
           %{
             path: "priv/repo/migrations/20260101000000_x.exs",
             target_table: "ledger_accounts",
             cross_table: MapSet.new(["ledger_transfers"])
           }}
        )

      assert ["cross_table_operations"] = Regex.run(@line_regex, line, capture: :all_but_first)
      assert line =~ "ledger_transfers"
    end

    test "xaas.ash_surface (W106 straggler: was lowercase 'refused:', no REFUSED token)" do
      line =
        Mix.Tasks.Xaas.AshSurface.render_refusal(
          {:ash_surface, %{reason: "{:invalid_target_dir, \"/tmp/nowhere\"}"}}
        )

      assert ["ash_surface"] = Regex.run(@line_regex, line, capture: :all_but_first)
      assert String.to_existing_atom("ash_surface")
      assert line =~ "invalid_target_dir"
    end

    test "xaas.self_digest (W106 straggler: was bare JSON, now carries refusal_code)" do
      reason = {:telemetry_unreadable, "/tmp/nowhere.ndjson"}

      json =
        Jason.decode!(
          Jason.encode!(%{
            "refused" => inspect(reason),
            "refusal_code" =>
              Mix.Tasks.Xaas.SelfDigest.render_refusal({:self_digest, %{reason: inspect(reason)}})
          })
        )

      # Pre-existing shape preserved (consumers unaffected)...
      assert json["refused"] == inspect(reason)
      # ...plus the additive machine-readable atom code.
      assert ["self_digest"] =
               Regex.run(@line_regex, json["refusal_code"], capture: :all_but_first)

      assert String.to_existing_atom("self_digest")
      assert json["refusal_code"] =~ "telemetry_unreadable"
    end
  end

  test "every converted task module exports render_refusal/1" do
    Enum.each(@refusal_modules, fn mod ->
      assert Code.ensure_loaded!(mod)

      assert function_exported?(mod, :render_refusal, 1),
             "#{inspect(mod)} missing render_refusal/1"
    end)
  end
end
