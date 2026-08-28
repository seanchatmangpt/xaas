defmodule Xaas.Semantics.DeterministicProjectionHashTest do
  @moduledoc """
  Chicago-style adversarial qualification of `Xaas.Semantics.Registry.hash/1`'s
  claimed determinism.

  Modeled on `ash_r2rml`'s `adversarial/deterministic_replay_test.exs` pattern:
  reconstruct the same real projection under two independently-shuffled attribute/
  relationship orderings and assert the resulting SHA-256 hashes are identical --
  proving `canonical_projection/1`'s `Enum.sort_by`/`Enum.sort` calls actually
  normalize order rather than merely appearing to via unshuffled Ash introspection
  output. This invariant is load-bearing: `Xaas.Actuation` binds
  `ontology_projection_hash` into every sealed `ActuationReceipt`
  (`test/xaas/actuation_test.exs`), so a hash that silently depended on
  introspection order would make receipts non-reproducible.
  """

  use ExUnit.Case, async: true

  alias Xaas.Marketplace.Provider
  alias Xaas.Semantics.Registry

  test "hash/1 is invariant under shuffled attribute and relationship ordering" do
    projection = Provider.ontology_projection!()

    shuffled = %{
      projection
      | attributes: Enum.shuffle(projection.attributes),
        relationships: Enum.shuffle(projection.relationships),
        classes: Enum.shuffle(projection.classes)
    }

    assert Registry.hash(projection) == Registry.hash(shuffled)
  end

  test "hash/1 is invariant across 10 independent shuffles of the same real projection" do
    projection = Provider.ontology_projection!()
    reference_hash = Registry.hash(projection)

    hashes =
      for _ <- 1..10 do
        shuffled = %{
          projection
          | attributes: Enum.shuffle(projection.attributes),
            relationships: Enum.shuffle(projection.relationships)
        }

        Registry.hash(shuffled)
      end

    assert Enum.all?(hashes, &(&1 == reference_hash))
  end

  test "hash/1 changes when a real predicate actually changes" do
    projection = Provider.ontology_projection!()
    [first | rest] = projection.attributes
    mutated_first = %{first | predicate: first.predicate <> "-mutated"}

    mutated_projection = %{projection | attributes: [mutated_first | rest]}

    refute Registry.hash(projection) == Registry.hash(mutated_projection)
  end
end
