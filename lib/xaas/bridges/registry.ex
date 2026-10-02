defmodule Xaas.Bridges.Registry do
  @moduledoc """
  Registry of Chicago layer bridge capability: real bridges and truthful absences.

  Ten layer ids. Four carry real bridges (`Xaas.Bridges.PPlan`, `Graphlaw`,
  `Ex4Pm`, and the `Sa2a` evidence reader). The rest carry `{:unsupported,
  reason}` — typed, truthful absences naming exactly what is missing. No entry
  claims evidence it does not hold: static registry entries have `nil` evidence
  and receipt refs, `authority_ceiling: :none`, and standing `"UNKNOWN"`
  (bridges) or `"UNSUPPORTED"` (absences). Standing becomes non-UNKNOWN only
  from real receipts bound to observed execution (R8).
  """

  @absences %{
    beam4pm: "no ash membrane exists for beam4pm in this repository; the BEAM-native " <>
               "process engine surface is projected only as a Chicago layer id",
    ferroplan: "ferroplan (FOND/HTN planner) is a separate sibling repository; xaas has " <>
                 "no bridge module and no vendored dep at this pin",
    graphlaw_rust: "the graphlaw rust CLI is reached only through the pinned WASM engine " <>
                     "via Xaas.Bridges.Graphlaw; no direct rust-process bridge exists",
    affidavit_cli: "the affidavit CLI has no xaas bridge; ash_affidavit is a dev/test " <>
                     "path dep consumed elsewhere, not wrapped here",
    ash_r2rml: "no R2RML mapping bridge exists in xaas; RDF mapping remains owned by " <>
                 "ggen/ontology tooling outside this repository",
    wasm4pm: "wasm4pm is the named successor engine; it is reachable only inside ex4pm's " <>
               "own :cmca_wasm engine path, not as an independent xaas bridge"
  }

  @doc "The truthful absence reasons, for audit."
  @spec absences() :: %{atom() => String.t()}
  def absences, do: @absences

  @doc """
  All ten layer entries as envelopes.

  Bridges: `capability: {:bridge, module}`. Absences: `capability:
  {:unsupported, reason}`. Every envelope carries the exact Chicago subject,
  `authority_ceiling: :none`, and no synthesized evidence.
  """
  @spec all() :: [map()]
  def all do
    subject = Xaas.Bridges.subject()

    for {id, entry} <- entries() do
      base = Xaas.Bridges.envelope(subject, entry[:claim], entry[:state], entry[:standing])

      base
      |> Map.put(:id, id)
      |> Map.put(:capability, entry[:capability])
    end
  end

  @doc "The ten registry layer ids."
  @spec ids() :: [atom()]
  def ids, do: Enum.map(all(), & &1.id)

  defp entries do
    [
      pplan: %{
        claim: "p-plan purchase run with await-human-release park",
        state: :bridge,
        standing: "UNKNOWN",
        capability: {:bridge, Xaas.Bridges.PPlan}
      },
      graphlaw: %{
        claim: "graphlaw purchase policy assessment (n3 derivation + shacl gate)",
        state: :bridge,
        standing: "UNKNOWN",
        capability: {:bridge, Xaas.Bridges.Graphlaw}
      },
      ex4pm: %{
        claim: "ex4pm purchase OCEL conformance",
        state: :bridge,
        standing: "UNKNOWN",
        capability: {:bridge, Xaas.Bridges.Ex4Pm}
      },
      sa2a: %{
        claim: "sa2a court receipt evidence reader (evidence only, never authority)",
        state: :bridge,
        standing: "UNKNOWN",
        capability: {:bridge, Xaas.Bridges.Sa2a}
      }
    ] ++
      Enum.map(@absences, fn {id, reason} ->
        {id,
         %{
           claim: reason,
           state: :unsupported,
           standing: "UNSUPPORTED",
           capability: {:unsupported, reason}
         }}
      end)
  end
end
