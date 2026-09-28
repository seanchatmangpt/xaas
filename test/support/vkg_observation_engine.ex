defmodule Xaas.Test.VKGObservationEngine do
  @moduledoc false

  alias AshR2RML.OBDA.Observation

  def execute(stage, opts) do
    rows_by_contract = Keyword.get(opts, :rows_by_contract, %{})

    rows =
      Map.get_lazy(rows_by_contract, stage.contract_id, fn ->
        [
          %{
            "subject" => "urn:xaas:test:" <> stage.contract_id <> ":1",
            "name" => String.capitalize(stage.contract_id)
          }
        ]
      end)

    digest =
      {stage.contract_id, stage.source_sha256, stage.mapping_sha256, stage.query_sha256, rows}
      |> :erlang.term_to_binary([:deterministic])
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    {:ok,
     %Observation{
       status: :PARTIAL_ALIVE,
       standing: :test_double_only,
       system: :xaas_vkg_observation_fixture,
       system_version: "1",
       evidence_kind: :injected_runner,
       exit_status: 0,
       command_sha256: digest,
       query_sha256: stage.query_sha256,
       mapping_sha256: stage.mapping_sha256,
       session_sha256: nil,
       observation_sha256: digest,
       output_sha256: digest,
       output_bytes: byte_size(:erlang.term_to_binary(rows)),
       row_count: length(rows),
       duration_ms: 1,
       bounded?: true,
       rows: rows
     }}
  end
end
