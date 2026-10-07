defmodule Xaas.Chicago.Bridges.RegistryTest do
  @moduledoc """
  Registry law: ten layer ids, truthful typed absences, no synthesized evidence.

  Anti-vacuity: every absence names a real missing capability in its reason;
  every bridge names a module that actually loads; nothing claims a receipt it
  does not hold.
  """

  use ExUnit.Case, async: true

  alias Xaas.Bridges
  alias Xaas.Bridges.Registry

  @bridge_ids [:pplan, :graphlaw, :ex4pm, :sa2a, :ferroplan]
  @absence_ids [:beam4pm, :graphlaw_rust, :affidavit_cli, :ash_r2rml, :wasm4pm]

  test "registry carries exactly ten layer ids, all unique" do
    entries = Registry.all()

    assert length(entries) == 10
    assert Enum.uniq(Enum.map(entries, & &1.id)) |> length() == 10
  end

  test "the expected bridges and absences are present" do
    ids = Registry.ids()

    for id <- @bridge_ids, do: assert(id in ids, "missing bridge #{id}")
    for id <- @absence_ids, do: assert(id in ids, "missing absence #{id}")
  end

  test "every envelope carries the R2/R8 law: exact subject, :none ceiling, no fake evidence" do
    for entry <- Registry.all() do
      assert entry.subject == Bridges.subject()
      assert entry.authority_ceiling == :none
      assert entry.evidence_ref == nil
      assert entry.receipt_ref == nil
      assert entry.standing in ["UNKNOWN", "UNSUPPORTED"]
      assert is_binary(entry.claim) and entry.claim != ""
    end
  end

  test "bridge entries name modules that actually load" do
    for entry <- Registry.all(), {:bridge, module} <- [entry.capability] do
      assert Code.ensure_loaded?(module), "#{module} does not load"
    end
  end

  test "absence entries are typed with a non-empty truthful reason" do
    for entry <- Registry.all(), {:unsupported, reason} <- [entry.capability] do
      assert entry.state == :unsupported
      assert entry.standing == "UNSUPPORTED"
      assert is_binary(reason) and byte_size(reason) > 20
      assert entry.claim == reason
    end

    absence_count =
      Registry.all()
      |> Enum.count(&match?(%{capability: {:unsupported, _}}, &1))

    assert absence_count == 5
  end

  test "absences map is auditable and covers the named missing capabilities" do
    absences = Registry.absences()

    assert map_size(absences) == 5
    for {id, reason} <- absences, do: assert(is_atom(id) and is_binary(reason))
  end
end
