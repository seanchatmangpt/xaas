defmodule Xaas.EUAIAct.Art11_1Art12xAuditChainDeepeningTest do
  @moduledoc """
  Lane W984ev — corpus evidenced-line deepening, Art. 11(1) + Art. 12(1)/(2)(a-c)
  (record-keeping and logging / audit chain: automatic event recording,
  traceability of the whole lifecycle).

  Statute (Regulation (EU) 2024/1689):

    * Art. 11(1): automatically created logs and technical documentation shall
      be kept "up-to-date" — the record surface must be a faithful, replayable
      record of the events it claims to document.
    * Art. 12(1): the system shall permit "automatic recording of events
      (logs)" at the level of the AI system.
    * Art. 12(2)(a): logging shall ensure traceability "of the AI system's
      functioning ... put into service" — for the risk situation, via the
      digest chain.
    * Art. 12(2)(b): post-market monitoring traceability through a real event
      log (OCEL 2.0 ndjson egress + the real conformance court).
    * Art. 12(2)(c): operation monitoring via audit receipts keyed to real
      actuation identifiers.

  Prior coverage: the generated EVIDENCED tests in `title_iii_test.exs`
  (`deepen_kind(:audit_chain)`) assert append/verify/tamper at one index;
  `test/xaas/witness/audit_chain_test.exs` courts the link-law mechanics
  (truncation, signature mode, martingale monotonicity); the Art 99 lane
  courts the refusal envelope (truncated / tampered head / invalid attrs).
  The statutory legs courted here were not bound to the statute anywhere:
  documentation REPLAYABILITY (11.1/12.1), EXACT mid-chain attribution of a
  tampered record by field class (12.2.a), post-market monitoring events
  traceable to the deployed object through the REAL OCEL court (12.2.b), and
  operation monitoring receipts whose actuation ids are the very ids the
  monitoring log records (12.2.c).

  Chicago discipline: real `Xaas.Witness.AuditChain` hash-chain executions,
  real `Xaas.Telemetry.OcelNdjson` + `Xaas.Ultracode.Ocel.Validator` runs
  over a real file in a real per-test sandbox dir; assertions on final
  returned state; zero mocks, zero application env.
  """

  use ExUnit.Case, async: true

  alias Xaas.Telemetry.OcelNdjson
  alias Xaas.Ultracode.Ocel.Validator
  alias Xaas.Witness.AuditChain

  @moduletag :eu_ai_act

  # -- fixtures --------------------------------------------------------------

  defp digest(i), do: :crypto.hash(:sha256, "risk-situation-#{i}") |> Base.encode16(case: :lower)

  defp attrs(i, extra \\ %{}) do
    Map.merge(
      %{
        actuation_id: "act-#{i}",
        payload_digest: digest(i)
      },
      extra
    )
  end

  defp build_chain(n, extra \\ %{}) do
    Enum.reduce(0..(n - 1), {:ok, [], nil}, fn i, {:ok, ch, h} ->
      AuditChain.append(ch, attrs(i, extra))
    end)
  end

  # -- Court 1 — 11.1 + 12.1: automatic recording, replayable documentation ---

  test "11.1 + 12.1 - recording is automatic and the chain head is byte-replayable documentation" do
    # Automatic recording: appending needs no external bookkeeping — each
    # receipt automatically carries its sequential position t and links to
    # the previous chain hash, with the head returned in the same call.
    {:ok, chain, head} = build_chain(6)

    assert length(chain) == 6
    assert Enum.map(chain, & &1.t) == Enum.to_list(0..5)
    assert is_binary(head) and Regex.match?(~r/^[0-9a-f]{64}$/, head)

    # Art 11(1) "up-to-date documentation" as replayability: replaying the
    # SAME event sequence produces a byte-identical head hash, and the
    # recorded chain re-verifies with the recorded head — the documentation
    # is a deterministic function of the recorded events.
    assert {:ok, replay, ^head} = build_chain(6)
    assert replay == chain

    assert :ok = AuditChain.verify_chain(chain, expected_head: head, expected_length: 6)

    # Independent recomputation of the head over the recorded prefix: the
    # final hash is exactly SHA256(JCS(R_last) <> H_{t-1}) — real crypto, not
    # an assertion of an opaque returned value.
    last = List.last(chain)
    # the receipt's OWN stored prev_hash is H_{t-1} — the chain hash it links to
    prev = last.prev_hash

    recomputed =
      :crypto.hash(
        :sha256,
        Jcs.encode(%{
          "actuation_id" => last.actuation_id,
          "payload_digest" => last.payload_digest,
          "prev_hash" => last.prev_hash,
          "sig_slot" => last.sig_slot,
          "t" => last.t
        }) <> prev
      )
      |> Base.encode16(case: :lower)

    assert head == recomputed
  end

  # -- Court 2 — 12.2.a: risk-situation traceability via the digest chain -----

  test "12.2.a - a tampered record is attributed to its EXACT index by field class, and traceability of the intact prefix survives" do
    {:ok, chain, head} = build_chain(5)

    # (a) content tamper of the risk-situation digest at index 2 is
    # attributed at EXACTLY index 2 (successor-consistency), mid-chain,
    # without needing a known head.
    tampered_digest = List.update_at(chain, 2, fn r -> %{r | payload_digest: String.duplicate("a", 64)} end)

    assert {:error, {:tampered, 2}} = AuditChain.verify_chain(tampered_digest)

    # (b) tamper of a DIFFERENT field (sig_slot) is likewise attributed
    # exactly — the link law does not care which recorded field changed.
    tampered_slot =
      List.update_at(chain, 3, fn r -> %{r | sig_slot: "slot-9"} end)

    assert {:error, {:tampered, 3}} = AuditChain.verify_chain(tampered_slot)

    # (c) a tamper of the recorded position t is attributed at its own index.
    tampered_t = List.update_at(chain, 1, fn r -> %{r | t: 9} end)
    assert {:error, {:tampered, 1}} = AuditChain.verify_chain(tampered_t)

    # (d) traceability of the INTACT prefix survives: the chain up to (not
    # including) the tampered index verifies :ok with the recorded prefix
    # head — the deployer can always prove the prefix before the break.
    prefix = Enum.take(chain, 2)
    {:ok, _, prefix_head} = build_chain(2)

    assert :ok = AuditChain.verify_chain(prefix, expected_head: prefix_head)

    # (e) the full tampered chain also fails the head check under the
    # recorded head — the break is never launderable into a clean record.
    assert {:error, {:tampered, 2}} = AuditChain.verify_chain(tampered_digest, expected_head: head)
  end

  # -- Court 3 — 12.2.b: post-market monitoring through the real OCEL court ---

  test "12.2.b - post-market monitoring events are traceable to the deployed object through the real OCEL 2.0 conformance court" do
    sandbox = Path.join(System.tmp_dir!(), "w984ev-ocel-#{System.unique_integer()}")
    File.mkdir_p!(sandbox)
    on_exit(fn -> File.rm_rf(sandbox) end)

    # Real post-market monitoring ndjson lines in the exact shape the
    # reshaped emitter appends: one complete OCEL 2.0 document per line,
    # events bound to the deployed-system object.
    line = fn event_id ->
      JSON.encode!(%{
        "ocel:objectTypes" => [%{"name" => "ai_system"}],
        "ocel:eventTypes" => [%{"name" => "post_market.observation"}],
        "ocel:events" => [
          %{
            "id" => event_id,
            "type" => "post_market.observation",
            "time" => "2026-10-07T00:00:00.000000Z",
            "attributes" => %{"outcome" => "ok"},
            "relationships" => [%{"objectId" => "deployed-system-1", "qualifier" => "ai_system"}]
          }
        ],
        "ocel:objects" => [
          %{
            "id" => "deployed-system-1",
            "type" => "ai_system",
            "attributes" => %{},
            "relationships" => []
          }
        ]
      })
    end

    path = Path.join(sandbox, "post_market.ndjson")

    File.write!(
      path,
      Enum.map_join(["pme-1", "pme-2", "pme-3"], "\n", line) <> "\n"
    )

    # The REAL conformance court adjudicates the assembled REAL file.
    assert {:ok, report} = OcelNdjson.validate_ndjson_file(path)
    assert report["status"] == "valid"
    assert report["event_count"] == 3
    assert report["object_count"] == 1
    assert report["event_types"] == ["post_market.observation"]
    assert report["object_types"] == ["ai_system"]

    # Traceability: every monitoring event is bound to the SAME deployed
    # object in the assembled document — file order preserved.
    {:ok, document} = OcelNdjson.read_document(path)

    assert Enum.all?(document["ocel:events"], fn e ->
             e["relationships"]
             |> Enum.any?(&(&1["objectId"] == "deployed-system-1"))
           end)

    # Fail-closed leg: a corrupt monitoring record (a single non-JSON line)
    # refuses assembly with a typed violation at that line — post-market
    # monitoring never silently drops or launders a bad record.
    bad_path = Path.join(sandbox, "corrupt.ndjson")
    File.write!(bad_path, line.("pme-ok") <> "\n{not json\n")

    assert {:error, [%{path: "line 2", reason: reason} | _]} =
             OcelNdjson.assemble_document(File.stream!(bad_path))

    assert reason =~ "JSON" or reason =~ "json"
             OcelNdjson.assemble_document(File.stream!(bad_path))
  end

  # -- Court 4 — 12.2.c: operation monitoring via receipts over actuation ids -

  test "12.2.c - audit receipts key operation monitoring to the actuation ids the monitoring log records" do
    # The operation ids under monitoring.
    operation_ids = for i <- 1..4, do: "op-2026-10-07-#{String.pad_leading(Integer.to_string(i), 3, "0")}"

    # Each operation leaves an audit receipt keyed by its actuation id.
    {:ok, chain, head} =
      Enum.reduce(operation_ids, {:ok, [], nil}, fn op_id, {:ok, ch, h} ->
        AuditChain.append(ch, %{
          actuation_id: op_id,
          payload_digest: :crypto.hash(:sha256, "receipt:" <> op_id) |> Base.encode16(case: :lower)
        })
      end)

    assert :ok = AuditChain.verify_chain(chain, expected_head: head)

    # The receipts' actuation ids ARE the operation ids, in operation order —
    # the audit chain is a faithful monitor of exactly those operations.
    assert Enum.map(chain, & &1.actuation_id) == operation_ids

    # The chain head is a function of the operation sequence: replaying the
    # same operation order reproduces the head, and changing the ORDER of the
    # same operations changes the head (order-sensitive monitoring) — the
    # recorded sequence, not a set, is what the record attests.
    {:ok, _, replayed_head} = build_head_from(operation_ids)
    assert replayed_head == head

    reordered =
      Enum.reduce(Enum.reverse(operation_ids), {:ok, [], nil}, fn op_id, {:ok, ch, h} ->
        AuditChain.append(ch, %{
          actuation_id: op_id,
          payload_digest: :crypto.hash(:sha256, "receipt:" <> op_id) |> Base.encode16(case: :lower)
        })
      end)

    {:ok, _, reordered_head} = reordered
    assert reordered_head != head

    # Removing one operation from the record is detectable: the shortened
    # chain fails the recorded length and head.
    assert {:error, {:truncated, 4}} =
             AuditChain.verify_chain(Enum.drop(chain, -1), expected_head: head, expected_length: 4)
  end

  defp build_head_from(operation_ids) do
    Enum.reduce(operation_ids, {:ok, [], nil}, fn op_id, {:ok, ch, h} ->
      AuditChain.append(ch, %{
        actuation_id: op_id,
        payload_digest: :crypto.hash(:sha256, "receipt:" <> op_id) |> Base.encode16(case: :lower)
      })
    end)
  end
end
