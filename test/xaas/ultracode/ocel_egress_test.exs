defmodule Xaas.Ultracode.OcelEgressTest do
  @moduledoc """
  Qualification for `Xaas.Ultracode.OcelEgress` -- the OCEL 2.0 egress
  derivation over the persisted Ultracode state.

  Two layers, per this repo's Chicago-style discipline:

    * a pure golden-structure test: one fabricated Run/Epoch/Receipt set
      produces the EXACT expected OCEL 2.0 document (full map equality --
      the skeleton is pinned, not sampled);
    * real end-to-end derivations over sandboxed Postgres rows written
      through real Ash actions (`Run :create`/`:start`, `Epoch :start`/
      `:lease`/`:complete`, `Receipt :seal`), asserting the spec shape
      the enforcing court (W3-A6) will check: every event/object type
      declared, every relationship objectId closed over the object set,
      ISO8601-UTC times, unique ids, byte-identical re-derivations, and
      a real JSON round-trip through Elixir's built-in `JSON`.
  """

  use ExUnit.Case, async: true

  require Ash.Query

  @moduletag :ultracode

  alias Xaas.Ultracode.{Epoch, OcelEgress, Receipt, Run}

  @run_id "0a000000-0000-4000-8000-00000000000a"
  @epoch_id "0b000000-0000-4000-8000-00000000000b"
  @receipt_id "0c000000-0000-4000-8000-00000000000c"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # ------------------------------------------------------------------
  # Golden structure (pure core, fabricated rows -- no DB)
  # ------------------------------------------------------------------

  test "golden: a fabricated run derives the exact OCEL 2.0 skeleton" do
    doc =
      OcelEgress.build_document(golden_run(), [golden_epoch()], %{
        @epoch_id => [golden_receipt()]
      })

    assert doc == %{
             "ocel:objectTypes" => [
               %{"name" => "Run"},
               %{"name" => "Epoch"},
               %{"name" => "Worker"},
               %{"name" => "Receipt"},
               %{"name" => "Worktree"}
             ],
             "ocel:eventTypes" => [
               %{"name" => "run_started"},
               %{"name" => "epoch_scheduled"},
               %{"name" => "epoch_started"},
               %{"name" => "epoch_claimed"},
               %{"name" => "worker_heartbeat"},
               %{"name" => "epoch_completed"},
               %{"name" => "epoch_missed"},
               %{"name" => "epoch_failed"},
               %{"name" => "receipt_closed"},
               %{"name" => "heartbeat_recorded"},
               %{"name" => "verification_passed"},
               %{"name" => "verification_failed"},
               %{"name" => "refused"},
               %{"name" => "run_completed"},
               %{"name" => "run_failed"},
               %{"name" => "run_abandoned"}
             ],
             "ocel:events" => [
               %{
                 "id" => "run_started:#{@run_id}",
                 "type" => "run_started",
                 "time" => "2026-09-19T08:00:00.000000Z",
                 "attributes" => %{},
                 "relationships" => [%{"objectId" => @run_id, "qualifier" => "run"}]
               },
               %{
                 "id" => "epoch_scheduled:#{@epoch_id}",
                 "type" => "epoch_scheduled",
                 "time" => "2026-09-19T08:05:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"}
                 ]
               },
               %{
                 "id" => "epoch_started:#{@epoch_id}",
                 "type" => "epoch_started",
                 "time" => "2026-09-19T08:06:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"}
                 ]
               },
               %{
                 "id" => "epoch_claimed:#{@epoch_id}",
                 "type" => "epoch_claimed",
                 "time" => "2026-09-19T08:10:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"}
                 ]
               },
               %{
                 "id" => "worker_heartbeat:#{@epoch_id}",
                 "type" => "worker_heartbeat",
                 "time" => "2026-09-19T08:20:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"}
                 ]
               },
               %{
                 "id" => "epoch_completed:#{@epoch_id}",
                 "type" => "epoch_completed",
                 "time" => "2026-09-19T08:55:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"}
                 ]
               },
               %{
                 "id" => "receipt_closed:#{@receipt_id}",
                 "type" => "receipt_closed",
                 "time" => "2026-09-19T08:55:30.000000Z",
                 "attributes" => %{
                   "outcome" => "alive",
                   "subject" => "subject-1",
                   "head_verified" => true,
                   "verifier_status" => "pass"
                 },
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => @receipt_id, "qualifier" => "receipt"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"}
                 ]
               },
               %{
                 "id" => "verification_passed:#{@receipt_id}",
                 "type" => "verification_passed",
                 "time" => "2026-09-19T08:55:30.000000Z",
                 "attributes" => %{"verifier_suite" => "aps-dod", "verifier_status" => "pass"},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => @receipt_id, "qualifier" => "receipt"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"}
                 ]
               },
               %{
                 "id" => "run_completed:#{@run_id}",
                 "type" => "run_completed",
                 "time" => "2026-09-19T09:00:00.000000Z",
                 "attributes" => %{},
                 "relationships" => [%{"objectId" => @run_id, "qualifier" => "run"}]
               }
             ],
             "ocel:objects" => [
               %{
                 "id" => @run_id,
                 "type" => "Run",
                 "attributes" => %{
                   "goal" => "Ship the OCEL egress.",
                   "provider" => "zcode",
                   "verifier_suite" => "aps-dod",
                   "org_id" => "org-alpha",
                   "state" => "completed",
                   "standing" => "admitted",
                   "cycle" => 1,
                   "max_cycles" => 1,
                   "epoch_timeout_seconds" => 900,
                   "started_at" => "2026-09-19T08:00:00.000000Z",
                   "deadline_at" => "2026-09-19T18:00:00.000000Z",
                   "terminal_at" => "2026-09-19T09:00:00.000000Z"
                 },
                 "relationships" => []
               },
               %{
                 "id" => @epoch_id,
                 "type" => "Epoch",
                 "attributes" => %{
                   "cycle" => 0,
                   "exact_subject" => "subject-1",
                   "state" => "completed",
                   "expected_at" => "2026-09-19T08:05:00.000000Z",
                   "started_at" => "2026-09-19T08:06:00.000000Z",
                   "completed_at" => "2026-09-19T08:55:00.000000Z",
                   "lease_expires_at" => "2026-09-19T08:36:00.000000Z",
                   "claimed_at" => "2026-09-19T08:10:00.000000Z",
                   "last_heartbeat_at" => "2026-09-19T08:20:00.000000Z",
                   "leased_to" => "zcode/agent-1",
                   "worktree" => "/tmp/wt-1",
                   "final_head" => "abc123"
                 },
                 "relationships" => [%{"objectId" => @run_id, "qualifier" => "run"}]
               },
               %{
                 "id" => "zcode/agent-1",
                 "type" => "Worker",
                 "attributes" => %{},
                 "relationships" => [%{"objectId" => @epoch_id, "qualifier" => "epoch"}]
               },
               %{
                 "id" => @receipt_id,
                 "type" => "Receipt",
                 "attributes" => %{"subject" => "subject-1", "outcome" => "alive"},
                 "relationships" => [%{"objectId" => @epoch_id, "qualifier" => "epoch"}]
               },
               %{
                 "id" => "/tmp/wt-1",
                 "type" => "Worktree",
                 "attributes" => %{},
                 "relationships" => []
               }
             ]
           }
  end

  test "golden: the lease_token capability never enters the log" do
    doc =
      OcelEgress.build_document(golden_run(), [golden_epoch()], %{@epoch_id => [golden_receipt()]})

    refute JSON.encode!(doc) =~ "secret-capability-token"
  end

  test "determinism: two derivations encode byte-identically, regardless of input list order" do
    receipt_b = %{golden_receipt() | id: "0d000000-0000-4000-8000-00000000000d"}

    doc_a =
      OcelEgress.build_document(golden_run(), [golden_epoch()], %{
        @epoch_id => [golden_receipt(), receipt_b]
      })

    doc_b =
      OcelEgress.build_document(golden_run(), [golden_epoch()], %{
        @epoch_id => [receipt_b, golden_receipt()]
      })

    assert JSON.encode!(doc_a) == JSON.encode!(doc_b)

    doc_again =
      OcelEgress.build_document(golden_run(), [golden_epoch()], %{
        @epoch_id => [golden_receipt(), receipt_b]
      })

    assert JSON.encode!(doc_again) == JSON.encode!(doc_a)
  end

  test "no fabricated times: events without a persisted moment column are not emitted" do
    # A :missed epoch whose transition never persisted a `terminal_at`
    # (and was never claimed or heartbeated), and a :completed Run with no
    # persisted `terminal_at`: the declared event types stay unemitted --
    # `updated_at` is deliberately IGNORED here (it carries a real value on
    # both fixtures) to prove the dedicated columns are the only source.
    missed_epoch = %{
      golden_epoch()
      | state: :missed,
        terminal_at: nil,
        completed_at: nil,
        claimed_at: nil,
        last_heartbeat_at: nil
    }

    run = %{golden_run() | state: :completed, terminal_at: nil}

    doc = OcelEgress.build_document(run, [missed_epoch], %{@epoch_id => []})

    event_ids = Enum.map(doc["ocel:events"], & &1["id"])

    refute "epoch_missed:#{@epoch_id}" in event_ids,
           "a :missed epoch with no persisted transition moment must not emit a fabricated time"

    refute "run_completed:#{@run_id}" in event_ids,
           "a :completed run with no persisted transition moment must not emit a fabricated time"

    refute "epoch_claimed:#{@epoch_id}" in event_ids,
           "an unclaimed epoch must not emit a fabricated claim moment"

    refute "worker_heartbeat:#{@epoch_id}" in event_ids,
           "an epoch with no persisted heartbeat must not emit a fabricated heartbeat"

    assert "epoch_scheduled:#{@epoch_id}" in event_ids
    assert "epoch_started:#{@epoch_id}" in event_ids
    assert "run_started:#{@run_id}" in event_ids
  end

  test "golden: an aliased run derives the multi-repo skeleton (Repo object, declared + emitted)" do
    doc =
      OcelEgress.build_document(
        %{golden_run() | execution_repo_alias: "zoela_phx"},
        [golden_epoch()],
        %{@epoch_id => [golden_receipt()]}
      )

    assert doc == %{
             "ocel:objectTypes" => [
               %{"name" => "Run"},
               %{"name" => "Epoch"},
               %{"name" => "Worker"},
               %{"name" => "Receipt"},
               %{"name" => "Worktree"},
               %{"name" => "Repo"}
             ],
             "ocel:eventTypes" => [
               %{"name" => "run_started"},
               %{"name" => "epoch_scheduled"},
               %{"name" => "epoch_started"},
               %{"name" => "epoch_claimed"},
               %{"name" => "worker_heartbeat"},
               %{"name" => "epoch_completed"},
               %{"name" => "epoch_missed"},
               %{"name" => "epoch_failed"},
               %{"name" => "receipt_closed"},
               %{"name" => "heartbeat_recorded"},
               %{"name" => "verification_passed"},
               %{"name" => "verification_failed"},
               %{"name" => "refused"},
               %{"name" => "run_completed"},
               %{"name" => "run_failed"},
               %{"name" => "run_abandoned"}
             ],
             "ocel:events" => [
               %{
                 "id" => "run_started:#{@run_id}",
                 "type" => "run_started",
                 "time" => "2026-09-19T08:00:00.000000Z",
                 "attributes" => %{},
                 "relationships" => [
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "epoch_scheduled:#{@epoch_id}",
                 "type" => "epoch_scheduled",
                 "time" => "2026-09-19T08:05:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "epoch_started:#{@epoch_id}",
                 "type" => "epoch_started",
                 "time" => "2026-09-19T08:06:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "epoch_claimed:#{@epoch_id}",
                 "type" => "epoch_claimed",
                 "time" => "2026-09-19T08:10:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "worker_heartbeat:#{@epoch_id}",
                 "type" => "worker_heartbeat",
                 "time" => "2026-09-19T08:20:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "epoch_completed:#{@epoch_id}",
                 "type" => "epoch_completed",
                 "time" => "2026-09-19T08:55:00.000000Z",
                 "attributes" => %{"cycle" => 0},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "receipt_closed:#{@receipt_id}",
                 "type" => "receipt_closed",
                 "time" => "2026-09-19T08:55:30.000000Z",
                 "attributes" => %{
                   "outcome" => "alive",
                   "subject" => "subject-1",
                   "head_verified" => true,
                   "verifier_status" => "pass"
                 },
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => @receipt_id, "qualifier" => "receipt"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "verification_passed:#{@receipt_id}",
                 "type" => "verification_passed",
                 "time" => "2026-09-19T08:55:30.000000Z",
                 "attributes" => %{"verifier_suite" => "aps-dod", "verifier_status" => "pass"},
                 "relationships" => [
                   %{"objectId" => "/tmp/wt-1", "qualifier" => "worktree"},
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => @epoch_id, "qualifier" => "epoch"},
                   %{"objectId" => @receipt_id, "qualifier" => "receipt"},
                   %{"objectId" => "zcode/agent-1", "qualifier" => "worker"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "run_completed:#{@run_id}",
                 "type" => "run_completed",
                 "time" => "2026-09-19T09:00:00.000000Z",
                 "attributes" => %{},
                 "relationships" => [
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               }
             ],
             "ocel:objects" => [
               %{
                 "id" => @run_id,
                 "type" => "Run",
                 "attributes" => %{
                   "goal" => "Ship the OCEL egress.",
                   "provider" => "zcode",
                   "verifier_suite" => "aps-dod",
                   "org_id" => "org-alpha",
                   "execution_repo_alias" => "zoela_phx",
                   "state" => "completed",
                   "standing" => "admitted",
                   "cycle" => 1,
                   "max_cycles" => 1,
                   "epoch_timeout_seconds" => 900,
                   "started_at" => "2026-09-19T08:00:00.000000Z",
                   "deadline_at" => "2026-09-19T18:00:00.000000Z",
                   "terminal_at" => "2026-09-19T09:00:00.000000Z"
                 },
                 "relationships" => []
               },
               %{
                 "id" => @epoch_id,
                 "type" => "Epoch",
                 "attributes" => %{
                   "cycle" => 0,
                   "exact_subject" => "subject-1",
                   "state" => "completed",
                   "expected_at" => "2026-09-19T08:05:00.000000Z",
                   "started_at" => "2026-09-19T08:06:00.000000Z",
                   "completed_at" => "2026-09-19T08:55:00.000000Z",
                   "lease_expires_at" => "2026-09-19T08:36:00.000000Z",
                   "claimed_at" => "2026-09-19T08:10:00.000000Z",
                   "last_heartbeat_at" => "2026-09-19T08:20:00.000000Z",
                   "leased_to" => "zcode/agent-1",
                   "worktree" => "/tmp/wt-1",
                   "final_head" => "abc123"
                 },
                 "relationships" => [
                   %{"objectId" => @run_id, "qualifier" => "run"},
                   %{"objectId" => "zoela_phx", "qualifier" => "repo"}
                 ]
               },
               %{
                 "id" => "zcode/agent-1",
                 "type" => "Worker",
                 "attributes" => %{},
                 "relationships" => [%{"objectId" => @epoch_id, "qualifier" => "epoch"}]
               },
               %{
                 "id" => @receipt_id,
                 "type" => "Receipt",
                 "attributes" => %{"subject" => "subject-1", "outcome" => "alive"},
                 "relationships" => [%{"objectId" => @epoch_id, "qualifier" => "epoch"}]
               },
               %{
                 "id" => "/tmp/wt-1",
                 "type" => "Worktree",
                 "attributes" => %{},
                 "relationships" => []
               },
               %{
                 "id" => "zoela_phx",
                 "type" => "Repo",
                 "attributes" => %{},
                 "relationships" => [%{"objectId" => @run_id, "qualifier" => "run"}]
               }
             ]
           }
  end

  # The mandatory legacy-shape-unchanged law: a run whose rows carry NO
  # alias derives byte-for-byte today's single-repo shape -- no Repo
  # object, no Repo declaration, no repo qualifier, no alias attribute.
  test "legacy single-repo shape is unchanged: no alias -> no Repo anything" do
    doc =
      OcelEgress.build_document(golden_run(), [golden_epoch()], %{
        @epoch_id => [golden_receipt()]
      })

    assert Enum.map(doc["ocel:objectTypes"], & &1["name"]) ==
             ["Run", "Epoch", "Worker", "Receipt", "Worktree"]

    assert Enum.map(doc["ocel:objects"], & &1["type"]) ==
             ["Run", "Epoch", "Worker", "Receipt", "Worktree"]

    refute Enum.any?(doc["ocel:events"], fn event ->
             Enum.any?(event["relationships"], &(&1["qualifier"] == "repo"))
           end)

    encoded = JSON.encode!(doc)
    refute encoded =~ "Repo"
    refute encoded =~ "repo"

    # The registered BASE vocabulary is untouched; the alias variant only
    # appends the conditional type.
    assert OcelEgress.object_types() == ["Run", "Epoch", "Worker", "Receipt", "Worktree"]

    assert OcelEgress.object_types(true) == [
             "Run",
             "Epoch",
             "Worker",
             "Receipt",
             "Worktree",
             "Repo"
           ]

    # And the legacy shape still passes the conformance court unchanged.
    assert {:ok, _report} = Xaas.Ultracode.Ocel.Validator.validate(doc)
  end

  test "the conformance court accepts the multi-repo shape (Repo declared iff emitted)" do
    alias_doc =
      OcelEgress.build_document(
        %{golden_run() | execution_repo_alias: "zoela_phx"},
        [golden_epoch()],
        %{@epoch_id => [golden_receipt()]}
      )

    assert {:ok, report} = Xaas.Ultracode.Ocel.Validator.validate(alias_doc)
    assert "Repo" in report["object_types"]

    # Undeclared Repo would be a court violation: a repo qualifier without
    # the Repo object/type must never happen (emitted implies declared).
    stripped = %{alias_doc | "ocel:objectTypes" => Enum.drop(alias_doc["ocel:objectTypes"], -1)}

    assert {:error, violations} = Xaas.Ultracode.Ocel.Validator.validate(stripped)
    assert Enum.any?(violations, &(&1.reason =~ "'Repo' not declared"))
  end

  test "an epoch with its OWN alias binds its repo, not the run's (sibling-wave seam)" do
    # Simulates the sibling waves' future Epoch shape (a per-Epoch alias
    # attribute on the struct): a plain map carrying the atom key is
    # exactly what `own_alias/1` will see then -- today's real Epoch
    # struct lacks the key and resolves to nil (proven by the golden
    # tests above, where the epoch inherits the run's alias).
    aliased_epoch = Map.put(golden_epoch(), :execution_repo_alias, "client_x")

    doc =
      OcelEgress.build_document(
        %{golden_run() | execution_repo_alias: "zoela_phx"},
        [aliased_epoch],
        %{@epoch_id => [golden_receipt()]}
      )

    repo_objects =
      doc["ocel:objects"] |> Enum.filter(&(&1["type"] == "Repo")) |> Enum.map(& &1["id"])

    assert repo_objects == ["client_x", "zoela_phx"], "one Repo object per distinct alias"

    for repo_object <- doc["ocel:objects"], repo_object["type"] == "Repo" do
      assert repo_object["relationships"] == [
               %{"objectId" => @run_id, "qualifier" => "run"}
             ]
    end

    # The epoch's OWN alias (not the run's) rides its epoch-bound events.
    for event <- doc["ocel:events"], event["id"] =~ @epoch_id do
      assert %{"objectId" => "client_x", "qualifier" => "repo"} in event["relationships"]
      refute %{"objectId" => "zoela_phx", "qualifier" => "repo"} in event["relationships"]
    end

    # Run-level events still bind the run's own alias.
    for event <- doc["ocel:events"], event["id"] =~ @run_id do
      assert %{"objectId" => "zoela_phx", "qualifier" => "repo"} in event["relationships"]
    end

    # The Epoch object carries its own alias as an attribute.
    epoch_object = Enum.find(doc["ocel:objects"], &(&1["id"] == @epoch_id))
    assert epoch_object["attributes"]["execution_repo_alias"] == "client_x"

    assert {:ok, _report} = Xaas.Ultracode.Ocel.Validator.validate(doc)
  end

  test "determinism holds with Repo objects: two derivations encode byte-identically" do
    aliased_epoch = Map.put(golden_epoch(), :execution_repo_alias, "client_x")
    receipt_b = %{golden_receipt() | id: "0d000000-0000-4000-8000-00000000000d"}
    run = %{golden_run() | execution_repo_alias: "zoela_phx"}

    doc_a =
      OcelEgress.build_document(run, [aliased_epoch], %{
        @epoch_id => [golden_receipt(), receipt_b]
      })

    doc_b =
      OcelEgress.build_document(run, [aliased_epoch], %{
        @epoch_id => [receipt_b, golden_receipt()]
      })

    assert JSON.encode!(doc_a) == JSON.encode!(doc_b)

    doc_again =
      OcelEgress.build_document(run, [aliased_epoch], %{
        @epoch_id => [golden_receipt(), receipt_b]
      })

    assert JSON.encode!(doc_again) == JSON.encode!(doc_a)
  end

  # ------------------------------------------------------------------
  # Real end-to-end derivations over sandboxed Postgres rows
  # ------------------------------------------------------------------

  test "end-to-end: a real provider-pull cycle derives a closed, registered, decodable log" do
    {run, epoch} = real_completed_run!()

    {:ok, doc} = OcelEgress.derive_run(run.id)

    event_ids = Enum.map(doc["ocel:events"], & &1["id"])
    event_types = Enum.map(doc["ocel:events"], & &1["type"])

    assert Enum.sort(event_types) ==
             Enum.sort([
               "run_started",
               "epoch_scheduled",
               "epoch_started",
               "epoch_claimed",
               "epoch_completed",
               "receipt_closed",
               "verification_passed"
             ])

    assert Enum.count(event_ids) == Enum.count(Enum.uniq(event_ids)), "event ids must be unique"

    object_ids = MapSet.new(doc["ocel:objects"], & &1["id"])
    object_types = Enum.map(doc["ocel:objects"], & &1["type"])

    assert MapSet.member?(object_ids, run.id)
    assert MapSet.member?(object_ids, epoch.id)
    assert "zcode/ocel-e2e-worker" in MapSet.to_list(object_ids), "the leased worker is an object"

    # Relationship closure (the W3-A6 court's core invariant): every
    # objectId referenced by an event OR an object resolves.
    for event <- doc["ocel:events"],
        relationship <- event["relationships"] do
      assert MapSet.member?(object_ids, relationship["objectId"]),
             "dangling event relationship: #{inspect(event["id"])} -> #{inspect(relationship)}"
    end

    for object <- doc["ocel:objects"],
        relationship <- object["relationships"] do
      assert MapSet.member?(object_ids, relationship["objectId"]),
             "dangling object relationship: #{inspect(object["id"])} -> #{inspect(relationship)}"
    end

    # Type registration completeness.
    registered_event_types = MapSet.new(doc["ocel:eventTypes"], & &1["name"])
    registered_object_types = MapSet.new(doc["ocel:objectTypes"], & &1["name"])

    assert MapSet.new(event_types) |> MapSet.subset?(registered_event_types)
    assert MapSet.new(object_types) |> MapSet.subset?(registered_object_types)

    assert Enum.sort(MapSet.to_list(registered_object_types)) ==
             Enum.sort(OcelEgress.object_types())

    assert Enum.sort(MapSet.to_list(registered_event_types)) ==
             Enum.sort(OcelEgress.event_types())

    # Declared vocabulary stays declared; both formerly-declared-unemitted
    # types are now really emitted from persisted columns in the dedicated
    # claim/heartbeat cycle test below.
    assert "epoch_claimed" in OcelEgress.event_types()
    assert "worker_heartbeat" in OcelEgress.event_types()

    # ISO8601 UTC times.
    for event <- doc["ocel:events"] do
      assert Regex.match?(~r/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/, event["time"]),
             "non-ISO8601-UTC time: #{inspect(event["time"])} on #{inspect(event["id"])}"
    end

    # Real JSON round-trip through the built-in JSON module.
    assert {:ok, ^doc} = JSON.decode(JSON.encode!(doc))

    # Byte determinism across two independent real derivations.
    {:ok, doc_again} = OcelEgress.derive_run(run.id)
    assert JSON.encode!(doc) == JSON.encode!(doc_again)
  end

  test "end-to-end: a real claim/renew cycle emits epoch_claimed and worker_heartbeat from the persisted columns" do
    {run, epoch, token} = real_claimed_run!()

    # Renew through the REAL production path (`Lease.renew/1`'s atomic
    # write), then re-read the persisted moments from the row.
    assert :ok = Xaas.Ultracode.Lease.renew(token)

    {:ok, [leased]} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(id == ^epoch.id)
      |> Ash.read(authorize?: false)

    assert %DateTime{} = leased.claimed_at, "the claim must persist its bind moment"
    assert %DateTime{} = leased.last_heartbeat_at, "the renewal must persist its heartbeat moment"

    {:ok, doc} = OcelEgress.derive_run(run.id)

    events = Map.new(doc["ocel:events"], fn e -> {e["id"], e} end)

    claimed = Map.get(events, "epoch_claimed:#{epoch.id}")
    assert %{"type" => "epoch_claimed"} = claimed

    assert claimed["time"] == DateTime.to_iso8601(leased.claimed_at),
           "the emitted claim time must be the persisted claimed_at column"

    assert %{"objectId" => "zcode/ocel-e2e-worker", "qualifier" => "worker"} in claimed[
             "relationships"
           ],
           "the claim event must bind the leasing worker"

    heartbeat = Map.get(events, "worker_heartbeat:#{epoch.id}")
    assert %{"type" => "worker_heartbeat"} = heartbeat

    assert heartbeat["time"] == DateTime.to_iso8601(leased.last_heartbeat_at),
           "the emitted heartbeat time must be the persisted last_heartbeat_at column"

    assert %{"objectId" => "zcode/ocel-e2e-worker", "qualifier" => "worker"} in heartbeat[
             "relationships"
           ]

    # The emitted shape (new event types included) still passes the OCEL
    # conformance court.
    assert {:ok, _report} = Xaas.Ultracode.Ocel.Validator.validate(doc)
  end

  test "end-to-end: an aliased run emits the Repo object and repo bindings, court-valid" do
    {run, _epoch} = real_completed_run!(execution_repo_alias: "zoela_phx")
    run_id = run.id

    {:ok, doc} = OcelEgress.derive_run(run.id)

    # Declared-iff-emitted: the six-type declaration, exactly.
    assert Enum.map(doc["ocel:objectTypes"], & &1["name"]) == OcelEgress.object_types(true)

    repo_objects = Enum.filter(doc["ocel:objects"], &(&1["type"] == "Repo"))

    assert [
             %{
               "id" => "zoela_phx",
               "relationships" => [%{"objectId" => ^run_id, "qualifier" => "run"}]
             }
           ] =
             repo_objects

    # Every event binds the repo: run events by the run's alias,
    # epoch/receipt events by the epoch's effective alias (inherited).
    for event <- doc["ocel:events"] do
      assert %{"objectId" => "zoela_phx", "qualifier" => "repo"} in event["relationships"],
             "event #{inspect(event["id"])} binds no repo"
    end

    # The Run object carries the alias attribute.
    run_object = Enum.find(doc["ocel:objects"], &(&1["id"] == run.id))
    assert run_object["attributes"]["execution_repo_alias"] == "zoela_phx"

    # Relationship closure over the Repo object too (court re-run here).
    object_ids = MapSet.new(doc["ocel:objects"], & &1["id"])

    for event <- doc["ocel:events"],
        relationship <- event["relationships"] do
      assert MapSet.member?(object_ids, relationship["objectId"])
    end

    # Byte determinism across two independent real derivations.
    {:ok, doc_again} = OcelEgress.derive_run(run.id)
    assert JSON.encode!(doc) == JSON.encode!(doc_again)

    assert {:ok, _report} = Xaas.Ultracode.Ocel.Validator.validate(doc)
  end

  test "end-to-end: a refused receipt emits the refused event, without inventing a verification verdict" do
    {run, epoch} = real_completed_run!()

    receipt =
      Receipt
      |> Ash.Changeset.for_create(
        :seal,
        %{
          epoch_id: epoch.id,
          subject: epoch.exact_subject,
          outcome: :refused,
          evidence: %{"refusal_reason" => "no_authority"},
          sealed_at: DateTime.utc_now()
        },
        authorize?: false
      )
      |> Ash.create!()

    {:ok, doc} = OcelEgress.derive_run(run.id)

    events = Map.new(doc["ocel:events"], fn e -> {e["id"], e} end)
    assert Map.has_key?(events, "refused:#{receipt.id}")
    assert events["refused:#{receipt.id}"]["attributes"]["refusal_reason"] == "no_authority"
    assert events["refused:#{receipt.id}"]["attributes"]["outcome"] == "refused"

    assert Map.has_key?(events, "receipt_closed:#{receipt.id}")
    assert events["receipt_closed:#{receipt.id}"]["attributes"]["outcome"] == "refused"

    refute Map.has_key?(events, "verification_passed:#{receipt.id}")
    refute Map.has_key?(events, "verification_failed:#{receipt.id}")
  end

  test "end-to-end: a build_broken receipt maps fabric_verifier fail to verification_failed" do
    {run, _epoch} = real_completed_run!(receipt_outcome: :build_broken, verifier_status: "fail")

    {:ok, doc} = OcelEgress.derive_run(run.id)

    failed = Enum.find(doc["ocel:events"], &(&1["type"] == "verification_failed"))
    assert %{"type" => "verification_failed"} = failed
    assert failed["attributes"]["verifier_status"] == "fail"
  end

  test "end-to-end: a heartbeat receipt emits its own heartbeat_recorded event, NEVER a receipt_closed" do
    # The typed NON-STANDING tick class, sealed as a real row through the
    # real `:seal` action with real tick evidence (no court verdict).
    {run, epoch, _token} = real_claimed_run!()

    epoch =
      epoch
      |> Ash.Changeset.for_update(:complete, %{final_head: "e2e-final-head"}, authorize?: false)
      |> Ash.update!()

    {:ok, receipt} =
      Receipt
      |> Ash.Changeset.for_create(
        :seal,
        %{
          epoch_id: epoch.id,
          subject: epoch.exact_subject,
          outcome: :heartbeat,
          evidence: %{
            "expected_state" => "running",
            "observed_state" => "running",
            "action_taken" => "await_provider"
          },
          sealed_at: ~U[2026-09-20 10:00:00.000000Z]
        },
        authorize?: false
      )
      |> Ash.create()

    {:ok, doc} = OcelEgress.derive_run(run.id)

    events = Map.new(doc["ocel:events"], &{&1["id"], &1})
    heartbeat = events["heartbeat_recorded:#{receipt.id}"]

    assert %{"type" => "heartbeat_recorded"} = heartbeat
    assert heartbeat["time"] == "2026-09-20T10:00:00.000000Z"
    assert heartbeat["attributes"]["outcome"] == "heartbeat"
    assert heartbeat["attributes"]["action_taken"] == "await_provider"

    # No standing events are fabricated from the heartbeat: not a terminal,
    # not a verification, not a refusal.
    refute Map.has_key?(events, "receipt_closed:#{receipt.id}")
    refute Map.has_key?(events, "verification_passed:#{receipt.id}")
    refute Map.has_key?(events, "verification_failed:#{receipt.id}")
    refute Map.has_key?(events, "refused:#{receipt.id}")

    # The Receipt OBJECT (a persisted-row fact, not an event) is still
    # emitted, carrying its honest typed outcome.
    receipt_objects =
      doc["ocel:objects"]
      |> Enum.filter(&(&1["type"] == "Receipt" and &1["id"] == receipt.id))

    assert [%{"attributes" => %{"outcome" => "heartbeat"}}] = receipt_objects

    # The event type is declared in the skeleton and the whole document
    # still passes the real OCEL conformance court.
    assert Enum.any?(doc["ocel:eventTypes"], &(&1["name"] == "heartbeat_recorded"))
    assert {:ok, _report} = Xaas.Ultracode.Ocel.Validator.validate(doc)
  end

  test "end-to-end: a pending run with no epochs derives an empty, still-valid document" do
    run =
      Run
      |> Ash.Changeset.for_create(:create, %{goal: "pending, never started"}, authorize?: false)
      |> Ash.create!()

    {:ok, doc} = OcelEgress.derive_run(run.id)

    assert doc["ocel:events"] == []

    run_id = run.id
    run_objects = Enum.filter(doc["ocel:objects"], &(&1["type"] == "Run"))
    assert [%{"id" => ^run_id, "type" => "Run"}] = run_objects

    assert length(doc["ocel:eventTypes"]) == length(OcelEgress.event_types())
    assert {:ok, ^doc} = JSON.decode(JSON.encode!(doc))
  end

  test "derive_run/1 on an unknown run id returns a typed error" do
    assert {:error, :run_not_found} =
             OcelEgress.derive_run("11111111-1111-4111-8111-111111111111")
  end

  test "write_document/2 + export_run/2 write real files that decode back to the same document" do
    {run, _epoch} = real_completed_run!()

    out_dir =
      Path.join(System.tmp_dir!(), "xaas-ocel-egress-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(out_dir) end)

    assert {:ok, path} = OcelEgress.export_run(run.id, out_dir)
    assert path == Path.join(out_dir, "#{run.id}.ocel.json")
    assert File.exists?(path)

    {:ok, decoded} = path |> File.read!() |> JSON.decode()
    {:ok, doc} = OcelEgress.derive_run(run.id)
    assert decoded == doc
    assert String.ends_with?(File.read!(path), "\n")
  end

  test "mix xaas.ultracode.export_ocel writes the run's document to the requested dir" do
    {run, _epoch} = real_completed_run!()
    out_dir = Path.join(System.tmp_dir!(), "xaas-ocel-mix-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(out_dir) end)

    Mix.Tasks.Xaas.Ultracode.ExportOcel.run([run.id, "--out", out_dir])

    path = Path.join(out_dir, "#{run.id}.ocel.json")
    assert File.exists?(path)
    assert {:ok, %{"ocel:events" => events}} = JSON.decode(File.read!(path))
    assert Enum.any?(events, &(&1["type"] == "receipt_closed"))
  end

  # ------------------------------------------------------------------
  # Fixtures
  # ------------------------------------------------------------------

  defp golden_run do
    struct(Run, %{
      id: @run_id,
      goal: "Ship the OCEL egress.",
      provider: "zcode",
      verifier_suite: "aps-dod",
      org_id: "org-alpha",
      state: :completed,
      standing: :admitted,
      started_at: ~U[2026-09-19 08:00:00.000000Z],
      deadline_at: ~U[2026-09-19 18:00:00.000000Z],
      terminal_at: ~U[2026-09-19 09:00:00.000000Z],
      cycle: 1,
      max_cycles: 1,
      epoch_timeout_seconds: 900,
      updated_at: ~U[2026-09-19 09:00:00.000000Z]
    })
  end

  defp golden_epoch do
    struct(Epoch, %{
      id: @epoch_id,
      run_id: @run_id,
      cycle: 0,
      exact_subject: "subject-1",
      state: :completed,
      expected_at: ~U[2026-09-19 08:05:00.000000Z],
      started_at: ~U[2026-09-19 08:06:00.000000Z],
      completed_at: ~U[2026-09-19 08:55:00.000000Z],
      lease_token: "secret-capability-token",
      lease_expires_at: ~U[2026-09-19 08:36:00.000000Z],
      claimed_at: ~U[2026-09-19 08:10:00.000000Z],
      last_heartbeat_at: ~U[2026-09-19 08:20:00.000000Z],
      leased_to: "zcode/agent-1",
      worktree: "/tmp/wt-1",
      final_head: "abc123",
      inserted_at: ~U[2026-09-19 08:04:59.000000Z],
      updated_at: ~U[2026-09-19 08:55:00.000000Z]
    })
  end

  defp golden_receipt do
    struct(Receipt, %{
      id: @receipt_id,
      epoch_id: @epoch_id,
      subject: "subject-1",
      outcome: :alive,
      evidence: %{"head_verified" => true, "fabric_verifier" => %{"status" => "pass"}},
      sealed_at: ~U[2026-09-19 08:55:30.000000Z],
      inserted_at: ~U[2026-09-19 08:55:30.000000Z],
      updated_at: ~U[2026-09-19 08:55:30.000000Z]
    })
  end

  # Real Chicago-style claim path: pending Run -> :start (real first
  # Epoch) -> Epoch :start -> `Lease.claim_next/3`'s atomic bind -- every
  # write through a real production entry point. Returns the leased epoch
  # (carrying the persisted `claimed_at`) and the live lease token.
  defp real_claimed_run!(opts \\ []) do
    {sha, 0} = System.cmd("git", ["rev-parse", "HEAD"], cd: File.cwd!())
    subject = String.trim(sha)

    create_params =
      %{goal: "OcelEgress e2e qualification.", provider: "zcode-ocel-e2e"}
      |> Map.merge(Map.take(Enum.into(opts, %{}), [:execution_repo_alias]))

    run =
      Run
      |> Ash.Changeset.for_create(:create, create_params, authorize?: false)
      |> Ash.create!()

    run =
      run
      |> Ash.Changeset.for_update(:start, %{exact_subject: subject}, authorize?: false)
      |> Ash.update!()

    {:ok, [epoch]} =
      Epoch
      |> Ash.Query.for_read(:read_unscoped)
      |> Ash.Query.filter(run_id == ^run.id)
      |> Ash.read(authorize?: false)

    epoch =
      epoch
      |> Ash.Changeset.for_update(:start, %{}, authorize?: false)
      |> Ash.update!()

    # The lease bind goes through the REAL production claim path
    # (`Lease.claim_next/3`'s atomic bind) -- NOT a hand-rolled `:lease`
    # changeset. The `:lease` action is deliberately `multitenancy
    # :allow_global` for `Ash.bulk_update`'s write side (see Epoch's own
    # moduledoc): a plain single-row `Ash.update` of it hits Ash 3.33.1's
    # second update-pipeline tenant checkpoint and raises, exactly as the
    # resource's own moduledoc records. `claim_next/3`'s directed-claim
    # `:epoch_id` opt binds this worker to exactly this epoch.
    {:ok, epoch, token, _run} =
      Xaas.Ultracode.Lease.claim_next(run.provider, "zcode/ocel-e2e-worker", epoch_id: epoch.id)

    {run, epoch, token}
  end

  # Continues the claimed cycle to closure: Epoch :complete -> Receipt
  # :seal -- every write through a real Ash action, exactly the production
  # write surface.
  defp real_completed_run!(opts \\ []) do
    outcome = Keyword.get(opts, :receipt_outcome, :alive)
    verifier_status = Keyword.get(opts, :verifier_status, "pass")
    {run, epoch, _token} = real_claimed_run!(opts)

    epoch =
      epoch
      |> Ash.Changeset.for_update(:complete, %{final_head: "e2e-final-head"}, authorize?: false)
      |> Ash.update!()

    _receipt =
      Receipt
      |> Ash.Changeset.for_create(
        :seal,
        %{
          epoch_id: epoch.id,
          subject: epoch.exact_subject,
          outcome: outcome,
          evidence: %{
            "head_verified" => true,
            "fabric_verifier" => %{"status" => verifier_status}
          },
          sealed_at: DateTime.utc_now()
        },
        authorize?: false
      )
      |> Ash.create!()

    {run, epoch}
  end
end
