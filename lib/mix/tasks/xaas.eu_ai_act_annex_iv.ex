defmodule Mix.Tasks.Xaas.EuAiActAnnexIv do
  @moduledoc """
  Emits Annex-IV-style (EU AI Act) technical documentation as JSON from the
  REAL capability surface of the repository.

  Definition 4.1 functor `D: Ont -> Doc`: the generator reads the live
  capability surface at run time (surface contract, router, witness catalog,
  coverage map, refusal corpus) and projects it into an Annex IV-shaped
  document. Every emitted claim carries a `sources` array whose entries are
  `%{path, line}` pairs that are (a) required to exist on disk and (b)
  anchored to a required content substring at the cited line. A source that
  drifts (file removed, anchor moved) breaks generation loudly with
  `Mix.raise`; it is never silently omitted.

  Usage:

      mix xaas.eu_ai_act_annex_iv --out /tmp/annex_iv.json
  """

  use Mix.Task

  @shortdoc "Generate Annex-IV-style technical documentation from the real capability surface"

  @coverage_rel "docs/sjira/v26.10.6/eu-ai-act-nist-coverage-map.md"
  @contract_rel "priv/ash_surface/surface_contract.json"
  @repo_markers ["mix.exs", "lib", "priv/ash_surface/surface_contract.json"]

  @impl Mix.Task
  def run(args) do
    {opts, _argv, invalid} = OptionParser.parse(args, strict: [out: :string])

    if invalid != [] do
      Mix.raise("xaas.eu_ai_act_annex_iv: unknown arguments: #{inspect(invalid)}")
    end

    out_path = opts[:out] || Mix.raise("xaas.eu_ai_act_annex_iv: --out <path> is required")

    json = Jason.encode!(build(), pretty: true) <> "\n"
    File.write!(out_path, json)

    Mix.shell().info("wrote Annex-IV documentation to #{out_path}")
  end

  @doc """
  Builds the Annex-IV document map. Every claim contains `claim` and
  `sources` (list of `%{"path" => .., "line" => ..}`); every cited path must
  exist and the cited line must contain its anchor substring. Raises on
  drift.
  """
  def build do
    repo = find_repo_root!()

    %{
      "artifact" => "Annex IV technical documentation (EU AI Act), generated",
      "functor" => "D: Ont -> Doc",
      "identity" => identity(repo),
      "capabilities" => capabilities(repo),
      "human_oversight" => %{
        "claims" =>
          claims(repo, [
            {"Fail-closed authentication floor: /api and /internal-api are gated by " <>
               "XaasWeb.Plugs.RequireInternalApiToken, which fails closed when " <>
               "INTERNAL_API_TOKEN configuration is absent.",
             [
               {"lib/xaas_web/plugs/require_internal_api_token.ex", "defmodule XaasWeb.Plugs.RequireInternalApiToken"},
               {"lib/xaas_web/router.ex", "RequireInternalApiToken"},
               {"test/xaas_web/plugs/require_internal_api_token_test.exs", "defmodule"}
             ]},
            {"Consequential DO is admitted through the BRCE actuation path; every " <>
               "external-mismatch branch returns a typed refusal tuple and there is " <>
               "no silent-proceed fallback.",
             [
               {"lib/xaas/actuation.ex", ":external_receipt_intent_mismatch"},
               {"lib/xaas/actuation.ex", ":subject_id_required"},
               {"test/xaas/actuation_refusal_negative_test.exs", "defmodule"}
             ]},
            {"Authority gate: actuation outside the admitted authority set is refused " <>
               "with REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED.",
             [
               {"lib/xaas/castle.ex", "REFUSED_CASTLE_AUTHORITY_NOT_ALLOWED"}
             ]},
            {"Projection drift is refused, not repaired: REFUSED_XAAS_PROJECTION_DRIFT.",
             [
               {"lib/xaas/castle.ex", "REFUSED_XAAS_PROJECTION_DRIFT"}
             ]},
            {"Witness catalog records verification outcomes of certified receipts so a " <>
               "human reviewer can audit which claims were verified and when.",
             [
               {"lib/xaas/witness/catalog.ex", "defmodule Xaas.Witness.Catalog"},
               {"config/config.exs", "Xaas.Witness"}
             ]}
          ])
      },
      "logging" => %{
        "claims" =>
          claims(repo, [
            {"Automatic event recording: OCEL NDJSON telemetry emits object-centric " <>
               "event logs for agent activity.",
             [
               {"lib/xaas/telemetry/ocel_ndjson.ex", "defmodule"}
             ]},
            {"Castle checkpoint gates bind every actuation checkpoint to a digest and an " <>
               "absolute evidence path; both mismatches are typed refusals.",
             [
               {"lib/xaas/castle.ex", "REFUSED_CASTLE_CHECKPOINT_DIGEST"},
               {"lib/xaas/castle.ex", "REFUSED_CASTLE_CHECKPOINT_EVIDENCE_PATH"}
             ]},
            {"Witness / audit chain: certified receipts and their verification records are " <>
               "retained through Xaas.Witness.Catalog and the witness audit chain.",
             [
               {"lib/xaas/witness/audit_chain.ex", "defmodule"},
               {"lib/xaas/witness/certified_receipt.ex", "defmodule"}
             ]},
            {"Machine-readable refusal ledger export (62 typed refusal variants with " <>
               "mutant-kill evidence, subject-pinned HEAD).",
             [
               {"docs/cro/artifacts/refusal-ledger-v26.10.6.jcs.json", "REFUSED"}
             ]}
          ])
      },
      "accuracy_robustness" => %{
        "claims" =>
          claims(repo, [
            {"Refusal-coverage corpus: typed refusal tokens each carry exact-token " <>
               "negative fixtures; the v26.10.6 closure plan records 62/62 refusal " <>
               "tokens covered.",
             [
               {"docs/sjira/v26.10.6/_CLOSURE_PLAN.md", "refusal"},
               {"test/xaas/actuation_refusal_negative_test.exs", "defmodule"},
               {"test/xaas/castle_refusal_negative_test.exs", "defmodule"}
             ]},
            {"A2A v1 wire conformance is exercised in-repo via protocol and SSE courts " <>
               "against real router dispatch.",
             [
               {"test/xaas_web/a2a/v1_protocol_test.exs", "defmodule"},
               {"test/xaas_web/a2a/v1_sse_test.exs", "defmodule"}
             ]},
            {"Plug court: 7/7 fail-closed auth floor cases in the real plug test suite.",
             [
               {"test/xaas_web/plugs/require_internal_api_token_test.exs", "defmodule"}
             ]},
            {"Bias-awareness measures artifact with typed limitations is on disk.",
             [
               {"docs/cro/artifacts/bias-awareness-measures-v26.10.6.md", "LIMITATION"}
             ]}
          ])
      },
      "coverage_map_rows" => coverage_rows(repo)
    }
  end

  ## ------------------------------------------------------------------
  ## Identity (a): read from real files
  ## ------------------------------------------------------------------

  defp identity(repo) do
    version = repo |> path("VERSION") |> read_required!() |> String.trim()

    contract = contract(repo)

    %{
      "system_name" => "xaas",
      "version" => version,
      "version_source" => source(repo, "VERSION", version),
      "generator_identity" => contract["generatorIdentity"],
      "marketplace_identity" => contract["marketplaceIdentity"],
      "surface_schema_version" => contract["surfaceSchemaVersion"],
      "ash_manifest_schema_version" => contract["ashManifestSchemaVersion"],
      "surface_digest" => contract["surfaceDigest"],
      "manifest_digest" => contract["manifestDigest"],
      "capability_surface_source" => source(repo, @contract_rel, "generatorIdentity"),
      "compliance_coverage_map" => source(repo, @coverage_rel, "Coverage Map")
    }
  end

  ## ------------------------------------------------------------------
  ## Capabilities (b): projected from the real surface contract
  ## ------------------------------------------------------------------

  defp capabilities(repo) do
    contract = contract(repo)
    entrypoints = contract["manifest"]["entrypoints"]

    by_resource =
      entrypoints
      |> Enum.group_by(fn e -> e["resource"] end)
      |> Enum.map(fn {resource, eps} ->
        {resource, length(eps)}
      end)
      |> Enum.sort()
      |> Map.new()

    action_types =
      entrypoints
      |> Enum.frequencies_by(fn e -> e["action"]["type"] end)
      |> Enum.sort()
      |> Map.new()

    %{
      "total_entrypoints" => length(entrypoints),
      "resources" => by_resource,
      "resource_count" => map_size(by_resource),
      "action_types" => action_types,
      "source" => source(repo, @contract_rel, "generatorIdentity")
    }
  end

  ## ------------------------------------------------------------------
  ## Claims machinery: source resolution + loud drift verification
  ## ------------------------------------------------------------------

  defp claims(repo, claim_specs) do
    Enum.map(claim_specs, fn {text, source_specs} ->
      %{"claim" => text, "sources" => Enum.map(source_specs, fn {rel, anchor} -> source(repo, rel, anchor) end)}
    end)
  end

  defp source(repo, rel, anchor) do
    abs = Path.join(repo, rel)

    lines = String.split(read_required!(abs), "\n")

    case Enum.find_index(lines, fn l -> String.contains?(l, anchor) end) do
      nil ->
        Mix.raise(
          "xaas.eu_ai_act_annex_iv: anchor #{inspect(anchor)} not found in #{rel} " <>
            "(drift detected; regenerate the document or update the anchor)"
        )

      idx0 ->
        %{"path" => rel, "line" => idx0 + 1}
    end
  end

  defp contract(repo) do
    repo |> path(@contract_rel) |> read_required!() |> Jason.decode!()
  end

  defp path(repo, rel), do: Path.join(repo, rel)

  defp coverage_rows(repo) do
    lines = repo |> path(@coverage_rel) |> read_required!() |> String.split("\n")

    lines
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {line, i} ->
      case Regex.run(~r/^\| (1[245]|50)\(/, line) do
        [_, _article] ->
          cells = line |> String.split("|") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
          first_cell = Enum.at(cells, 0)
          verdict = List.last(cells)

          clause =
            case Regex.run(~r/^\d+(?:\([^)]*\))+/, first_cell) do
              [c] -> c
              nil -> first_cell
            end

          [%{
            "clause" => clause,
            "line" => i,
            "verdict" => verdict,
            "source" => %{"path" => @coverage_rel, "line" => i}
          }]

        nil ->
          []
      end
    end)
  end

  defp read_required!(path) do
    case File.read(path) do
      {:ok, content} ->
        content

      {:error, reason} ->
        Mix.raise("xaas.eu_ai_act_annex_iv: required source file missing: #{path} (#{reason})")
    end
  end

  defp find_repo_root! do
    candidate = File.cwd!()

    if Enum.all?(@repo_markers, fn m -> File.exists?(Path.join(candidate, m)) end) do
      candidate
    else
      Mix.raise("xaas.eu_ai_act_annex_iv: not a xaas repo root: #{candidate}")
    end
  end
end
