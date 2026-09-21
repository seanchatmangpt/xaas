defmodule Xaas.Ultracode.SemanticJiraBridgeFixtures do
  @moduledoc """
  Shared real-data fixtures for the `Xaas.Ultracode.SemanticJiraBridge` suites:
  WorkOrders in the kernel's own shape, the SHACL shapes the candidate is
  admitted against, and the graph digest of the pack's real ontology.

  Nothing here is a test double: work orders go through the real kernel
  (`GgenIgniter.SemanticJira.admit_work_order/1`), the shapes through the real
  `GgenIgniter.SemanticJira.Shacl` court, and the graph digest is the digest of
  the real `semantic-jira-pack` ontology file.
  """

  alias GgenIgniter.{Digest, SemanticA2A, SemanticJira}
  alias Xaas.Ultracode.SemanticReceipt

  @sj "https://ggen-igniter.dev/ontology/semantic-jira#"

  @shapes """
  @prefix sh: <http://www.w3.org/ns/shacl#> .
  @prefix dcterms: <http://purl.org/dc/terms/> .
  @prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
  @prefix sj: <#{@sj}> .

  sj:CandidateShape a sh:NodeShape ;
      sh:targetClass sj:WorkOrder ;
      sh:property [ sh:path dcterms:identifier ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ; sh:pattern "^[A-Z][A-Z0-9-]{1,63}$" ] ;
      sh:property [ sh:path sj:repository ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ; sh:pattern "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$" ] ;
      sh:property [ sh:path sj:baseSha ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ; sh:pattern "^[0-9a-f]{40}$" ] ;
      sh:property [ sh:path sj:standing ; sh:minCount 1 ; sh:maxCount 1 ; sh:datatype xsd:string ; sh:pattern "^UNKNOWN$" ] .
  """

  @doc "The fabric court IRI every fixture work order requires."
  def court_iri, do: @sj <> "court-xaas-fabric"

  @doc "The evidence requirement a witnessed fabric court elevates to."
  def evidence_iri, do: @sj <> "xaas-fabric-court-receipt"

  @doc "Acceptance criterion IRI minted for `identity`."
  def acceptance_iri(identity), do: @sj <> String.downcase(identity) <> "-acceptance"

  @doc "Falsifier IRI minted for `identity`."
  def falsifier_iri(identity), do: @sj <> String.downcase(identity) <> "-falsifier"

  @doc "The candidate SHACL shapes (an inline subset of the pack's WorkOrder shape)."
  def shapes, do: RDF.Turtle.read_string!(@shapes)

  @doc "Digest of the real semantic-jira-pack ontology file (the canonical graph)."
  def graph_digest, do: Digest.sha256(File.read!(SemanticA2A.ontology_path()))

  @doc "A 40-hex string derived from `seed` (an exact-SHA stand-in for pure suites)."
  def sha(seed) do
    :crypto.hash(:sha, to_string(seed)) |> Base.encode16(case: :lower)
  end

  @doc """
  A WorkOrder in the kernel's shape. `deps` are upstream identities, each a
  `requiresReceipt` edge needing ALIVE.
  """
  def work_order(identity, base_sha, deps \\ [], overrides \\ %{}) do
    %{
      "identity" => identity,
      "title" => "Bridge fixture #{identity}",
      "description" => "Repair the bounded failing condition for #{identity}.",
      "subject" => "semantic-jira:bridge:#{identity}",
      "repository" => "seanchatmangpt/demo",
      "base_sha" => base_sha,
      "standing" => "UNKNOWN",
      "evidence_ceiling" => "repository-local",
      "promotion_rule" => "fabric court receipt at the exact candidate head",
      "replay_identity" => "semantic-jira:bridge:replay:#{identity}",
      "required_courts" => [court_iri()],
      "required_evidence" => [evidence_iri()],
      "acceptance" => [acceptance_iri(identity)],
      "falsifiers" => [falsifier_iri(identity)],
      "projections" => ["jira", "receipt"],
      "required_receipt_classes" => ["verification"],
      "path_scope" => ["src/#{String.downcase(identity)}"],
      "dependencies" =>
        Enum.map(
          deps,
          &%{"upstream" => &1, "type" => "requiresReceipt", "required_standing" => "ALIVE"}
        )
    }
    |> Map.merge(overrides)
  end

  @doc """
  A court map binding the work order's minted IRIs to the suite tests whose
  outcomes decide them (the shape `Xaas.Ultracode.CourtReceipt` admits).
  """
  def court_map(identity, acceptance_test, falsifier_test) do
    %{
      "acceptance" => %{acceptance_iri(identity) => %{"test" => acceptance_test}},
      "falsifiers" => %{falsifier_iri(identity) => %{"test" => falsifier_test}},
      "courts" => [court_iri()]
    }
  end

  @doc """
  A sealed-export-shaped map for `work_order` under `bridge` (the `"bridge"` of
  a real `SemanticJiraBridge.descriptor/4` execution), with the receipt digest
  computed by `SemanticReceipt.receipt_digest/1`. It has the exact key set of
  `SemanticReceipt.export/1`; used ONLY by pure mapping suites -- the crown
  suite exports from a real sealed Epoch.

  Options: `:head`, `:outcome` (default `"alive"`), `:status` (fabric verifier,
  default `"pass"`), `:head_verified` (default `true`), `:court_head` (the head
  the court receipt binds; default `:head`), `:acceptance` / `:falsifier`
  verdicts, `:epoch_id`.
  """
  def export(work_order, bridge, opts \\ []) do
    {:ok, admitted} = SemanticJira.admit_work_order(work_order)
    head = Keyword.get(opts, :head, sha("head:" <> admitted["identity"]))
    status = Keyword.get(opts, :status, "pass")
    court_head = Keyword.get(opts, :court_head, head)
    binding = court_binding(court_head)

    court = %{
      "binding" => binding,
      "acceptance_results" => %{
        hd(admitted["acceptance"]) => Keyword.get(opts, :acceptance, true)
      },
      "falsifier_results" => %{
        hd(admitted["falsifiers"]) => Keyword.get(opts, :falsifier, "survived")
      },
      "court_results" => %{
        court_iri() => Map.merge(binding, %{"passed" => status == "pass"})
      }
    }

    export = %{
      "epoch_id" => Keyword.get(opts, :epoch_id, Ecto.UUID.generate()),
      "run_id" => Ecto.UUID.generate(),
      "receipt_id" => Ecto.UUID.generate(),
      "outcome" => Keyword.get(opts, :outcome, "alive"),
      "final_head" => head,
      "head_verified" => Keyword.get(opts, :head_verified, true),
      "fabric_verifier" => %{
        "status" => status,
        "steps" => [%{"id" => "court", "status" => status}],
        "court_receipt" => court
      },
      "bridge" => bridge
    }

    Map.put(export, "receipt_digest", SemanticReceipt.receipt_digest(export))
  end

  @doc "Re-seals `export` after `fun` edits it (a forger who recomputes the digest)."
  def reseal(export, fun) do
    edited = export |> Map.delete("receipt_digest") |> fun.()
    Map.put(edited, "receipt_digest", SemanticReceipt.receipt_digest(edited))
  end

  defp court_binding(head) do
    %{
      "suite" => "bridge-suite",
      "step_id" => "court",
      "head" => head,
      "argv_sha256" => Digest.sha256("argv")
    }
  end

  @doc "A unique temp directory, removed on exit by the calling test."
  def tmp_dir(label) do
    dir = Path.join(System.tmp_dir!(), "xaas-sjb-#{label}-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    {out, 0} = System.cmd("sh", ["-c", ~s(cd "$1" && pwd -P), "sh", dir])
    String.trim(out)
  end
end
