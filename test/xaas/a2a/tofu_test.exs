defmodule Xaas.A2a.TofuTest do
  @moduledoc """
  Chicago court for W784 (TOFU pinning on the agent-card trust surface):
  the court drives the REAL `Xaas.A2a.Tofu` module with the REAL ash_a2a v1
  spec-corpus card (the served `agent-card.json` surface), asserts on real
  ETS pin state and real catalog projection state. No mocks, no stubs.
  """

  use ExUnit.Case, async: false

  alias Xaas.A2a.Catalog
  alias Xaas.A2a.Tofu

  @ash_a2a_corpus "/Users/sac/ash_a2a/priv/a2a_v1_spec_corpus/v1_spec_examples.json"

  setup do
    Tofu.reset()
    on_exit(fn -> Tofu.reset() end)
    :ok
  end

  defp real_card do
    corpus = Jason.decode!(File.read!(@ash_a2a_corpus))

    corpus["examples"]
    |> Enum.find(&(&1["id"] == "agent-card-research-assistant"))
    |> Map.fetch!("wire")
    |> Map.put("url", "https://research.example.com/a2a")
  end

  test "first sighting pins the card fingerprint" do
    card = real_card()
    assert {:ok, :pinned} = Tofu.verify(card)

    expected = :crypto.hash(:sha256, Jason.encode!(card)) |> Base.encode16(case: :lower)
    assert Tofu.pin_for(card["name"]) == expected
  end

  test "subsequent identical sighting is accepted as unchanged" do
    card = real_card()
    {:ok, :pinned} = Tofu.verify(card)
    assert {:ok, :unchanged} = Tofu.verify(card)
    # strict fingerprint: even a version-only bump under the same name is a
    # pin mismatch — tamper-evident, not field-selective
    assert {:error, %Tofu.Error{reason: :pin_mismatch}} =
             Tofu.verify(Map.put(card, "version", "2.0.0"))
  end

  test "changed card under unchanged name refuses with typed pin_mismatch" do
    card = real_card()
    {:ok, :pinned} = Tofu.verify(card)

    tampered = Map.put(card, "url", "https://evil.example.com/a2a")
    assert {:error, %Tofu.Error{reason: :pin_mismatch} = err} = Tofu.verify(tampered)
    msg = Exception.message(err)
    assert msg =~ "pin_mismatch"
    assert msg =~ card["name"]

    # the pin itself is untouched by the refusal — still the first-use fingerprint
    assert Tofu.pin_for(card["name"]) ==
             :crypto.hash(:sha256, Jason.encode!(card)) |> Base.encode16(case: :lower)
  end

  test "repin is the only rotation path and then the new card passes" do
    card = real_card()
    {:ok, :pinned} = Tofu.verify(card)

    rotated = Map.put(card, "url", "https://research.example.com/v2/a2a")
    assert {:error, %Tofu.Error{reason: :pin_mismatch}} = Tofu.verify(rotated)

    {:ok, fp} = Tofu.repin(rotated)
    assert fp == :crypto.hash(:sha256, Jason.encode!(rotated)) |> Base.encode16(case: :lower)
    assert {:ok, :unchanged} = Tofu.verify(rotated)
  end

  test "malformed card refuses with typed invalid_card and never pins" do
    assert {:error, %Tofu.Error{reason: :invalid_card}} = Tofu.verify(%{"name" => "x"})
    assert Tofu.pin_for("x") == nil
  end

  test "verify_and_ingest gates the real catalog: pins first, ingests ok cards, refuses tampered ones" do
    card = real_card()
    assert {:ok, _count} = Tofu.verify_and_ingest(card)
    assert Catalog.get_agent!(card["name"]).url == "https://research.example.com/a2a"

    tampered = Map.put(card, "url", "https://evil.example.com/a2a")
    assert {:error, %Tofu.Error{reason: :pin_mismatch}} = Tofu.verify_and_ingest(tampered)

    # tampered card never reached the catalog projection
    reloaded = Catalog.get_agent!(card["name"])
    assert reloaded.url == "https://research.example.com/a2a"
  end
end
