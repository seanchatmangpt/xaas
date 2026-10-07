defmodule Mix.Tasks.Xaas.ExportRefusalLedger do
  @shortdoc "Emit the canonical anti-vacuity refusal ledger (v26.10.7 WP-6, W616)"

  @moduledoc """
  Emits `docs/cro/artifacts/refusal-ledger-v26.10.7.jcs.json` — the canonical
  anti-vacuity refusal ledger over the four grounded vocabulary sources
  (v26.10.6 ledger variants, eyerun EU-gate codes, typed-gap register atoms,
  `Xaas.Semantics.Vkg` atoms).

  Fail-closed: an entry whose pinning court does not exist on disk refuses
  the emit (`{:error, {:unpinned_variant, _}}`); nothing is written.

  ## Usage

      mix xaas.export_refusal_ledger            # emit + digest + replay check
      mix xaas.export_refusal_ledger --court    # also run the anti-vacuity court (incl. fake-variant mutation leg)

  Reuses the w603 canonicalization idiom (`Xaas.Semantics.Jcs`, SHA-256;
  BLAKE3 absent from mix.lock — disclosed).
  """

  use Mix.Task

  alias Xaas.Operations.RefusalLedgerExport

  @impl Mix.Task
  def run(args) do
    court? = "--court" in args

    case RefusalLedgerExport.emit() do
      {:ok, %{path: path, digest: digest}} ->
        Mix.shell().info("emitted: #{path}")
        Mix.shell().info("sha256:  #{digest}")

        {:ok, rebuilt} = RefusalLedgerExport.rebuild_digest()

        Mix.shell().info(
          "replay:  #{if rebuilt == digest, do: "MATCH", else: "MISMATCH"} (#{rebuilt})"
        )

        if rebuilt != digest, do: exit({:shutdown, 1})

        if court? do
          case RefusalLedgerExport.court() do
            {:ok, report} ->
              Mix.shell().info("court:   OK (fake-variant mutation refused: " <>
                 "#{report.fake_injection_refused |> inspect()}")

            {:error, reason} ->
              Mix.shell().error("court:   REFUSED #{inspect(reason)}")
              exit({:shutdown, 1})
          end
        end

      {:error, {:unpinned_variant, detail}} ->
        Mix.shell().error("FAIL-CLOSED unpinned_variant: #{inspect(detail)}")
        exit({:shutdown, 1})
    end
  end
end
