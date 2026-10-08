defmodule Xaas.Deepening.Art265OperationMonitoringEgressTest do
  @moduledoc """
  Lane W984be — corpus evidenced-line deepening wave 6, corpus line **26.5**
  (Art. 26(5), deployer duty: operation monitoring via the log).

  The corpus evidence entry for 26.5 (W503/W524b) cites "operation
  monitoring via OCEL event log + capability receipts → audit chain" over
  `lib/xaas/telemetry/ocel_ndjson.ex` +
  `lib/xaas/witness/audit_chain.ex`. The deepening_map entry for 26.5 is
  `[:audit_chain]`; `audit_chain_test.exs` (w503) courts the chain over
  synthetic receipts, and the telemetry suite courts the emitter and the
  ndjson assembler in isolation. The uncovered composition is the REAL
  monitoring pipeline: a real governed DO (real `Xaas.Actuation.run/4`
  receipt) becomes a real OCEL 2.0 egress line on disk (the emitter's
  exact per-line document law: one complete OCEL 2.0 log per line, every
  relationship's objectId resolved in-document), the real
  `Xaas.Telemetry.OcelNdjson.validate_ndjson_file/1` court admits the
  aggregated egress, and the real `Xaas.Witness.AuditChain` built from
  the digests READ BACK OFF DISK verifies clean — and detects a real
  byte tamper of the file.

  Mutation rationale: if the egress stops being individually conformant
  (a line drops a required OCEL 2.0 key, or a relationship dangles), or
  `read_document/1` stops returning the events in append order with
  their attributes intact, the conformance and tamper-evidence courts
  fail while `audit_chain_test.exs`'s synthetic courts and the
  emitter's own shape tests still pass.

  Chicago discipline: real actuation DOs over real sandboxed Postgres,
  a real file in the real tmp dir, the real assembler/validator court,
  the real hash chain — no mocks.
  """

  use Xaas.DataCase, async: false

  # 26.5 is an evidenced corpus line (W503/W524b) — eu_ai_act census.
  @moduletag :eu_ai_act

  alias Xaas.Marketplace.Provider
  alias Xaas.Telemetry.OcelNdjson
  alias Xaas.Witness.AuditChain

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Xaas.Repo, {:shared, self()})
    :ok
  end

  defp unique_key(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"

  defp actuate(provider, key, status) do
    Xaas.Actuation.run(
      Provider,
      :actuate_status,
      %{status: status},
      subject_id: provider.id,
      idempotency_key: key,
      authorize?: false,
      authority: %{kind: "test_authority", source: "w984be_art_26_5"}
    )
  end

  # The emitter's per-line OCEL 2.0 document law, applied to a REAL
  # actuation receipt: one complete log per line, one event, the object
  # the event's relationship references, only types actually used
  # declared. Event attributes carry the receipt's REAL digests — this
  # is what makes the egress a monitoring witness of governed use.
  defp egress_line(provider, envelope, event_type) do
    event = %{
      "id" => Ash.UUIDv7.generate(),
      "type" => event_type,
      "time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "attributes" => %{
        "action" => "actuate_status",
        "outcome" => "succeeded",
        "actuation_id" => "#{provider.id}:#{envelope.intent.idempotency_key}",
        "receipt_input_hash" => envelope.receipt.input_hash,
        "receipt_result_hash" => envelope.receipt.result_hash
      },
      "relationships" => [
        %{"objectId" => "provider", "qualifier" => "provider"}
      ]
    }

    objects = [
      %{"id" => "provider", "type" => "provider", "attributes" => %{}, "relationships" => []}
    ]

    %{
      "ocel:objectTypes" => [%{"name" => "provider"}],
      "ocel:eventTypes" => [%{"name" => event_type}],
      "ocel:events" => [event],
      "ocel:objects" => objects
    }
    |> JSON.encode!()
  end

  defp write_log(path, lines), do: File.write!(path, Enum.join(lines, "\n") <> "\n")

  defp digests_from_doc(doc) do
    Enum.map(doc["ocel:events"], & &1["attributes"]["receipt_input_hash"])
  end

  test "operation monitoring egress: a real governed DO's receipt becomes a conformant OCEL 2.0 line on disk, admitted by the real court" do
    provider =
      Xaas.Generator.create_provider!(%{name: "W984be 26.5 Provider", org_id: "org-w984be-26-5"})

    assert {:ok, %{status: :succeeded, receipt: receipt} = envelope} =
             actuate(provider, unique_key("w984be-265-use"), :active)

    assert is_binary(receipt.input_hash) and receipt.input_hash != ""
    assert is_binary(receipt.result_hash) and receipt.result_hash != ""

    path = Path.join(System.tmp_dir(), "w984be-265-#{System.unique_integer([:positive])}.ndjson")
    on_exit(fn -> File.rm(path) end)

    write_log(path, [egress_line(provider, envelope, "provider.actuate_status")])

    assert {:ok, report} = OcelNdjson.validate_ndjson_file(path)
    assert report["event_count"] == 1
    assert report["object_count"] == 1

    # The real receipt digests survive the real file round-trip — the
    # egress carries the monitoring content, not a copy of a shape.
    assert {:ok, doc} = OcelNdjson.read_document(path)
    assert [%{"attributes" => attrs}] = doc["ocel:events"]
    assert attrs["receipt_input_hash"] == receipt.input_hash
    assert attrs["receipt_result_hash"] == receipt.result_hash
  end

  test "aggregated monitoring log: two governed DOs aggregate in append order, objects deduplicated, declarations unioned" do
    provider =
      Xaas.Generator.create_provider!(%{name: "W984be 26.5 Aggregated", org_id: "org-w984be-26-5"})

    assert {:ok, use_env} = actuate(provider, unique_key("w984be-265-agg-use"), :active)
    assert {:ok, stop_env} = actuate(provider, unique_key("w984be-265-agg-suspend"), :suspended)

    path = Path.join(System.tmp_dir(), "w984be-265-agg-#{System.unique_integer([:positive])}.ndjson")
    on_exit(fn -> File.rm(path) end)

    write_log(path, [
      egress_line(provider, use_env, "provider.actuate_status"),
      egress_line(provider, stop_env, "provider.actuate_status")
    ])

    assert {:ok, report} = OcelNdjson.validate_ndjson_file(path)
    assert report["event_count"] == 2
    assert report["object_count"] == 1

    assert {:ok, doc} = OcelNdjson.read_document(path)
    assert [%{"attributes" => first}, %{"attributes" => second}] = doc["ocel:events"]

    # Append order == chronological order: the use DO's input hash leads.
    assert first["receipt_input_hash"] == use_env.receipt.input_hash
    assert second["receipt_input_hash"] == stop_env.receipt.input_hash

    # The class-level provider object is stated once in the aggregate.
    assert [%{"id" => "provider"}] = doc["ocel:objects"]
  end

  test "tamper-evident egress: the audit chain over the digests read back off disk detects a real byte tamper of the file" do
    provider =
      Xaas.Generator.create_provider!(%{name: "W984be 26.5 Chain", org_id: "org-w984be-26-5"})

    assert {:ok, env_a} = actuate(provider, unique_key("w984be-265-chain-a"), :active)
    assert {:ok, env_b} = actuate(provider, unique_key("w984be-265-chain-b"), :suspended)

    path = Path.join(System.tmp_dir(), "w984be-265-chain-#{System.unique_integer([:positive])}.ndjson")
    on_exit(fn -> File.rm(path) end)

    write_log(path, [
      egress_line(provider, env_a, "provider.actuate_status"),
      egress_line(provider, env_b, "provider.actuate_status")
    ])

    # The chain is built from the file's OWN content: digests read back
    # off disk, in append order.
    assert {:ok, doc} = OcelNdjson.read_document(path)
    digests = digests_from_doc(doc)

    {chain, original_head} =
      Enum.reduce(digests, {[], nil}, fn d, {chain, _} ->
        {:ok, chain, head} = AuditChain.append(chain, %{actuation_id: "w984be-265", payload_digest: d})
        {chain, head}
      end)

    # The clean chain verifies against its own real head, and the tamper
    # below is judged against THAT head — not a recomputed lookalike.
    assert AuditChain.verify_chain(chain, expected_head: original_head) == :ok

    # Real byte tamper of the file: corrupt the first line's recorded
    # receipt digest, re-read the real file, rebuild the chain from the
    # tampered content — the exact tampered link is named.
    lines = path |> File.read!() |> String.split("\n", trim: true)
    # W984al compile-freeze SLA fix (disclosed): Enum.split/2 returns a
    # {prefix, suffix} TUPLE, not a list — the original `[first, rest] =`
    # pattern failed deterministically every census run.
    {[first_line], rest} = Enum.split(lines, 1)

    tampered_first =
      String.replace(first_line, env_a.receipt.input_hash, String.duplicate("f", 64))

    assert tampered_first != first_line, "tamper must actually change the line bytes"
    File.write!(path, Enum.join([tampered_first | rest], "\n") <> "\n")

    assert {:ok, tampered_doc} = OcelNdjson.read_document(path)
    tampered_digests = digests_from_doc(tampered_doc)
    assert tampered_digests != digests

    {tampered_chain, _} =
      Enum.reduce(tampered_digests, {[], nil}, fn d, {chain, _} ->
        {:ok, chain, head} = AuditChain.append(chain, %{actuation_id: "w984be-265", payload_digest: d})
        {chain, head}
      end)

    # W984al compile-freeze SLA fix part 2, W984be tightening (disclosed):
    # a chain REBUILT from tampered content is internally self-consistent
    # (every link recomputes), so plain verify_chain/1 is :ok by the
    # module's documented contract. Tamper evidence against the REAL
    # pre-tamper head rides the documented expected_head last-link check.
    assert AuditChain.verify_chain(tampered_chain, expected_head: original_head) ==
             {:error, {:tampered, :head}}
  end
end
