defmodule Xaas.Semantics.VKG.QueryDepthTest do
  @moduledoc """
  Lane W984de depth court for `Xaas.Semantics.VKG.Query` (lib/xaas/semantics/vkg/query.ex)
  — the uncovered remainder after W984cy confirmed Runtime.query/catalog are already
  driven through the `Xaas.Semantics.VKG` facade tests (observe/observe_all/integration).

  Chicago style: real `Query` structs, real `AshR2RML.Refusal` values, no mocks and
  no stubs. Every refusal is asserted at its exact typed code, and every invariant
  names the mutation it kills.

  Falsifier: any single-field mutation of an admitted query that does NOT change
  its digest, or any admission-edge mutation that still yields {:ok, _}.
  """

  use ExUnit.Case, async: true

  alias Xaas.Semantics.VKG.Query

  @base_attrs %{
    id: "w984de-depth",
    contract_ids: ["customer", "order"],
    purpose: :engineering_read
  }

  defp admitted_query do
    assert {:ok, query} = Query.new(@base_attrs)
    query
  end

  test "digest is field-discriminative: every single-field mutation changes it" do
    # Mutation rationale: kills the mutation that widens digest's tuple to drop
    # any field (e.g. removing :timeout_ms or :merge from the term) — a dropped
    # field would let two structurally different admitted queries share one
    # digest and alias each other in receipts/replay.
    base = admitted_query()

    # NOTE: authority is NOT mutated — admit/1 only ever admits :NONE, so every
    # authority mutant is refused rather than digest-comparable.
    mutants = [
      %{base | id: "other-id"},
      %{base | contract_ids: ["customer"]},
      %{base | contract_ids: ["customer", "order", "payment"]},
      %{base | purpose: :failure_analysis},
      %{base | max_rows: base.max_rows + 1},
      %{base | timeout_ms: base.timeout_ms + 1},
      %{base | merge: :by_subject},
      %{base | capability: :explain}
    ]

    digests = Enum.map(mutants, &Query.digest/1)

    assert length(Enum.uniq(digests)) == length(mutants),
           "digest collision among single-field mutants: #{inspect(digests)}"

    assert Enum.all?(digests, &(&1 != Query.digest(base)))
  end

  test "with_contracts re-admits a valid replacement and re-refuses an invalid one" do
    # Mutation rationale: kills the mutation that makes with_contracts/2 return
    # the raw struct without re-running admit/1 — under that mutation a query
    # could carry duplicate or blank contract ids past the admission boundary.
    query = admitted_query()

    assert {:ok, narrowed} = Query.with_contracts(query, ["customer"])
    assert narrowed.contract_ids == ["customer"]
    # re-admission preserved every other field
    assert narrowed.id == query.id
    assert narrowed.purpose == query.purpose
    assert narrowed.max_rows == query.max_rows

    for bad <- [[], ["customer", "customer"], [""], ["  "], "customer"] do
      assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :contract_ids}} =
               Query.with_contracts(query, bad)
    end
  end

  test "string-keyed attribute maps are admitted identically to atom-keyed maps" do
    # Mutation rationale: kills the mutation that removes the Atom.to_string
    # fallback in fetch/2 — string-keyed maps (wire-shaped payloads) would then
    # fall back to defaults silently instead of carrying caller intent.
    # Real surface: `fetch/2` falls back on string KEYS only — string VALUES
    # (e.g. "process_intelligence") are admitted verbatim and refused at their
    # own subjects, asserted below.
    string_keyed = %{
      "id" => "wire-shaped",
      "contract_ids" => ["customer"],
      "purpose" => :process_intelligence,
      "max_rows" => 25,
      "timeout_ms" => 1_500,
      "merge" => :by_subject
    }

    assert {:ok, from_strings} = Query.new(string_keyed)
    assert {:ok, from_atoms} = Query.new(%{id: "wire-shaped", contract_ids: ["customer"], purpose: :process_intelligence, max_rows: 25, timeout_ms: 1_500, merge: :by_subject})

    assert from_strings.max_rows == from_atoms.max_rows
    assert from_strings.timeout_ms == from_atoms.timeout_ms
    assert from_strings.merge == from_atoms.merge
    assert Query.digest(from_strings) == Query.digest(from_atoms)

    # string VALUES are not atomized: a wire-shaped "purpose" string is
    # refused at its own subject rather than silently coerced.
    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :purpose}} =
             Query.new(%{string_keyed | "purpose" => "process_intelligence"})
  end

  test "non-map input and whitespace/blank identity are refused at the typed boundary" do
    # Mutation rationale: kills two admission-gap mutations: (a) accepting any
    # non-map input struct (new/1 clause deleted), and (b) treating a
    # whitespace-only id as a "stable non-empty id".
    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY}} =
             Query.new("not-a-map")

    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :id}} =
             Query.new(%{@base_attrs | id: "   "})

    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :id}} =
             Query.new(%{@base_attrs | id: nil})
  end

  test "each resource bound refuses at its own subject with a positive-interval invariant" do
    # Mutation rationale: kills the mutation that collapses per-field bounds
    # (max_rows / timeout_ms / merge / capability) into one catch-all refusal —
    # callers could then not diagnose WHICH bound was violated. Also kills any
    # mutation that flips a bound to accept 0, negatives, or non-integers.
    for bad_max_rows <- [0, -1, "500", 5.0] do
      assert {:error,
              %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :max_rows} = refusal} =
               Query.new(Map.put(@base_attrs, :max_rows, bad_max_rows))

      assert refusal.detail =~ "positive integer"
    end

    # nil is silently defaulted to the field default by `fetch/2 || default`
    # (real surface), not refused — asserted here so the defaulting is a
    # witnessed contract, not an accident.
    assert {:ok, defaulted} = Query.new(Map.put(@base_attrs, :max_rows, nil))
    assert defaulted.max_rows == 5_000

    for bad_timeout <- [0, -10, "1000"] do
      assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :timeout_ms}} =
               Query.new(Map.put(@base_attrs, :timeout_ms, bad_timeout))
    end

    assert {:ok, defaulted_timeout} = Query.new(Map.put(@base_attrs, :timeout_ms, nil))
    assert defaulted_timeout.timeout_ms == 10_000

    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :merge}} =
             Query.new(Map.put(@base_attrs, :merge, :overwrite))

    assert {:error, %AshR2RML.Refusal{code: :REFUSED_XAAS_VKG_QUERY, subject: :capability}} =
             Query.new(Map.put(@base_attrs, :capability, "select"))

    # the admitted sibling always passes right beside the refusals (non-vacuity:
    # the same base attrs minus the offending field still admit)
    assert {:ok, _} = Query.new(@base_attrs)
  end
end
