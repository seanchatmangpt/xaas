defmodule Xaas.Gall.Turtle do
  @moduledoc """
  Turtle ingestion for GALL semantic checkpoints (v26.9.18 GALL Semantic
  Work Fabric, PRD section 43.1, requirement 6).

  Parses the canonical TTL form (namespace
  `https://semantic-a2a.dev/gall#`, prefix `gall:`) into the canonical
  JSON map form admitted by `Xaas.Gall.Checkpoint.new/1`, then delegates
  admission to it -- so the TTL and JSON surfaces share ONE validation
  path and an identical `Xaas.Gall.Checkpoint.graph_digest/1`. The field
  mapping is the one tabulated in `Xaas.Gall.Checkpoint`'s moduledoc.

  ## Parser availability (checked, real constraint)

  The repo's only Turtle parser is `RDF.Turtle` (the `rdf` hex package),
  which is present in the dependency lock ONLY as a transitive dependency
  of `ggen_igniter` -- and `ggen_igniter` is declared `only: [:dev, :test]`
  in mix.exs. A static, compile-time reference to `RDF.*` from `lib/`
  would therefore break `MIX_ENV=prod` compilation (the Docker release
  path). This module accordingly references `RDF` only dynamically
  (`Code.ensure_loaded?/1` + `apply/3`):

    * where `:rdf` is loadable (dev/test -- including this module's own
      tests), a REAL `RDF.Turtle` parse happens;
    * where it is not (prod), `from_turtle/1` returns
      `{:error, :ttl_parser_unavailable}` instead of pretending.

  No Turtle library was added to the dependency graph (zero new
  dependencies). Promoting `{:rdf, "~> 3.0"}` to a direct dependency is
  the follow-up that would make TTL ingestion prod-available; that is a
  dependency-graph decision above this slice's authority.

  ## Admitted TTL shape

  Exactly one `gall:CodingCheckpoint` subject per document (the PRD
  canonical reference form):

      @prefix gall: <https://semantic-a2a.dev/gall#> .
      <urn:gall:checkpoint:xaas:semantic-worker-001>
        a gall:CodingCheckpoint ;
        gall:repository <urn:repo:seanchatmangpt:xaas> ;
        gall:baseSha "6d5fca8cff223eb30ef19e237574d54f21cbfc15" ;
        gall:goal gall:SemanticWorkerIntegration ;
        gall:requiresCapability gall:Read, gall:Edit, gall:Commit ;
        gall:forbidsCapability gall:Push, gall:Publish ;
        gall:requiresVerifier gall:XaasChicagoCourt ;
        gall:standing gall:UNKNOWN .

  Zero checkpoint subjects -> `{:error, :no_checkpoint_subject}`;
  more than one -> `{:error, {:multiple_checkpoint_subjects, n}}`;
  unparseable Turtle -> `{:error, {:ttl_decode_failed, reason}}`. Those
  are PARSE-shape errors; vocabulary/identity validation refusal tuples
  come from `Xaas.Gall.Checkpoint.new/1` and are returned unchanged.
  """

  @gall_ns "https://semantic-a2a.dev/gall#"

  @checkpoint_class_iri @gall_ns <> "CodingCheckpoint"

  # gall:predicate local name -> canonical JSON map key
  @predicate_mapping %{
    "repository" => :repository,
    "baseSha" => :base_sha,
    "dependency" => :dependencies,
    "goal" => :goal,
    "allowedPath" => :allowed_paths,
    "requiresCapability" => :requires_capabilities,
    "forbidsCapability" => :forbids_capabilities,
    "acceptance" => :acceptance,
    "falsifier" => :falsifiers,
    "requiresVerifier" => :verifier,
    "requiredEvidence" => :required_evidence,
    "executionPolicy" => :execution_policy,
    "standing" => :standing
  }

  @spec gall_namespace() :: String.t()
  def gall_namespace, do: @gall_ns

  @doc """
  Parse canonical checkpoint Turtle text and admit it.

  Returns `{:ok, %Xaas.Gall.Checkpoint{}}`, a `{:refused, reason}` tuple
  from `Xaas.Gall.Checkpoint.new/1` (admission), or an `{:error, term}`
  tuple (parser unavailability / decode failure / document shape).
  """
  @spec from_turtle(String.t()) ::
          {:ok, Xaas.Gall.Checkpoint.t()}
          | {:refused, Xaas.Gall.Checkpoint.refusal_reason()}
          | {:error, term()}
  def from_turtle(text) when is_binary(text) do
    case Code.ensure_loaded?(RDF.Turtle) do
      true ->
        text
        |> decode()
        |> to_checkpoint()

      false ->
        {:error, :ttl_parser_unavailable}
    end
  end

  def from_turtle(_other), do: {:error, :ttl_parser_unavailable}

  ## -- parse --

  defp decode(text) do
    case apply(RDF.Turtle, :read_string, [text]) do
      {:ok, graph} -> {:ok, graph}
      {:error, reason} -> {:error, {:ttl_decode_failed, reason}}
    end
  end

  defp to_checkpoint({:error, reason}), do: {:error, reason}

  defp to_checkpoint({:ok, graph}) do
    triples = apply(RDF.Graph, :triples, [graph])

    {checkpoint_subjects, grouped} = group_by_subject(triples)

    case checkpoint_subjects do
      [] ->
        {:error, :no_checkpoint_subject}

      [subject] ->
        build_map(subject, Map.fetch!(grouped, subject))
        |> Xaas.Gall.Checkpoint.new()

      subjects ->
        {:error, {:multiple_checkpoint_subjects, length(subjects)}}
    end
  end

  defp group_by_subject(triples) do
    grouped =
      Enum.reduce(triples, %{}, fn {subject, predicate, object}, acc ->
        subject_iri = term_to_iri(subject)
        entry = {term_to_iri(predicate), term_to_object(object)}
        Map.update(acc, subject_iri, [entry], &(&1 ++ [entry]))
      end)

    checkpoint_subjects =
      grouped
      |> Enum.filter(fn {_subject, pos} ->
        # entries are {predicate_iri_string, {:iri | :literal, value}}
        Enum.any?(pos, fn {predicate, object} ->
          predicate == "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" and
            object == {:iri, @checkpoint_class_iri}
        end)
      end)
      |> Enum.map(&elem(&1, 0))

    {checkpoint_subjects, grouped}
  end

  defp build_map(subject, pos) do
    base = %{identity: subject, class: Xaas.Gall.Checkpoint.checkpoint_class()}

    Enum.reduce(pos, base, fn {predicate, object}, acc ->
      case classify_predicate(predicate) do
        nil ->
          acc

        key
        when key in [:dependencies, :allowed_paths, :acceptance, :falsifiers, :required_evidence] ->
          value = object_value(object)
          Map.update(acc, key, [value], &(&1 ++ [value]))

        # Vocabulary fields carry namespace-LOCAL names (gall:Read -> "Read").
        key when key in [:requires_capabilities, :forbids_capabilities] ->
          value = object_value(object) |> local_or_iri()
          Map.update(acc, key, [value], &(&1 ++ [value]))

        :standing ->
          Map.put(acc, :standing, object_value(object) |> local_or_iri())

        :execution_policy ->
          Map.put(acc, :execution_policy, decode_execution_policy(object_value(object)))

        key ->
          # goal / verifier keep their FULL IRI strings (verifier is
          # validated against the absolute-IRI known-verifier registry;
          # see Xaas.Gall.Checkpoint's TTL<->JSON mapping table), as do
          # repository and dependency IRIs -- object_value collapses only
          # where the vocabulary wants local names (handled above).
          Map.put(acc, key, object_value(object))
      end
    end)
  end

  defp decode_execution_policy(value) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, map} when is_map(map) -> map
      _ -> value
    end
  end

  defp decode_execution_policy(value), do: value

  # NOTE: group_by_subject/1 stores entries as {predicate_iri_string,
  # {:iri | :literal, object_value}} -- the predicate arrives here as a
  # plain string, not a tagged tuple.
  defp classify_predicate(iri) when is_binary(iri) do
    if String.starts_with?(iri, @gall_ns) do
      Map.get(@predicate_mapping, String.slice(iri, byte_size(@gall_ns)..-1//1))
    end
  end

  defp classify_predicate(_), do: nil

  # NOTE: object_value does NOT collapse gall-namespace IRIs by itself;
  # local-name collapse happens only for the vocabulary fields listed in
  # build_map/2 (via local_or_iri/1). Everything else keeps the full IRI.
  defp object_value({:iri, iri}), do: iri
  defp object_value({:literal, value}), do: value

  defp local_or_iri(iri) do
    if String.starts_with?(iri, @gall_ns) do
      String.slice(iri, byte_size(@gall_ns)..-1//1)
    else
      iri
    end
  end

  defp term_to_iri(term) do
    if is_struct(term, RDF.IRI) do
      apply(RDF.IRI, :to_string, [term])
    else
      apply(Kernel, :to_string, [term])
    end
  end

  defp term_to_object(object) do
    cond do
      is_struct(object, RDF.IRI) -> {:iri, apply(RDF.IRI, :to_string, [object])}
      is_struct(object, RDF.Literal) -> {:literal, apply(RDF.Term, :value, [object])}
      true -> {:literal, to_string(object)}
    end
  end
end
