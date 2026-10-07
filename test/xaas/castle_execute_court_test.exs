defmodule Xaas.CastleExecuteCourtTest do
  @moduledoc """
  W828 — qualification court for the XaaS -> CASTLE Execute admission surface
  (`Xaas.Castle.Actions.Execute` via `Xaas.Operations.RouteCastleRun :execute`,
  the BRCE_ONLY from-node traced by W793 in
  `Xaas.Castle.Generated.EdgeCatalog`).

  Chicago discipline: no mocks. The CASTLE binary is a real /bin/sh subprocess
  emitting canned construct/DO JSON (same disclosed pattern as
  `Xaas.CastleRefusalNegativeTest` — the real admitted binary is a build
  artifact of a separate repo covered by the :castle_kernel court). All other
  collaborators are real: real Postgres via the sandbox, real durable
  `Xaas.Actuation.prepare_external/4` / `checkpoint_external/2` admissions,
  real Ash actions on `Xaas.Operations.RouteCastleRun`, real kernel CLI
  subprocess, real /tmp file-lock serialization (W297d).

  W828 defect, fixed at the compare side in W863: `Xaas.Castle.Contract.identity().protocol`
  is the ATOM `:CASTLE_PAAS_XAAS_BRIDGE_V2` (the GGEN override redefines `@protocol`
  from the original string), but `Xaas.Actuation` persists checkpoints through
  `json_safe/1` (`lib/xaas/actuation.ex` ~line 892), which stringifies atoms.
  The compare in `Xaas.Castle.Admission.verify_checkpoint/2` and
  `Xaas.Castle.Kernel.CLI.verify_runtime_checkpoint/4` now normalizes both sides
  (`to_string/1`), so the full lawful Execute traversal
  (`Xaas.Castle.run/2`: prepare -> witness -> manufacture -> durable checkpoint ->
  private execute -> seal) reaches `:succeeded` with a sealed durable receipt.
  The jsonb round-trip proof below documents why the normalization must live at
  the compare: the atom cannot survive the durable write.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt, RouteCastleRun}

  @authority %{kind: "xaas_reactor", source: "castle_execute_court_test", scope: "castle.run"}
  @protocol_atom :CASTLE_PAAS_XAAS_BRIDGE_V2
  @protocol_string "CASTLE_PAAS_XAAS_BRIDGE_V2"

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    setup_fake_castle!()
    :ok
  end

  # ---------------------------------------------------------------------------
  # (a) the generated edge catalog: real structure assertions
  # ---------------------------------------------------------------------------

  test "edge catalog: 8 ordered edges, exactly one DO boundary, BRCE_ONLY" do
    edges = Xaas.Castle.Generated.EdgeCatalog.all()

    assert length(edges) == 8
    assert Enum.map(edges, & &1.sequence) == [10, 20, 30, 40, 50, 60, 70, 80]
    assert Enum.map(edges, & &1.name) == [
             "public-semantic-projection",
             "outer-admission",
             "castle-construct",
             "outer-construct-checkpoint",
             "nested-brce-do",
             "nested-receipt-seal",
             "crash-recovery-verification",
             "deterministic-replay"
           ]

    # every edge is fully qualified: endpoints and an authority marker
    for edge <- edges do
      assert is_binary(edge.from) and edge.from != ""
      assert is_binary(edge.to) and edge.to != ""
      assert is_binary(edge.authority) and edge.authority != ""
      assert is_boolean(edge.do_boundary?)
      assert is_boolean(edge.receipt_before?)
      assert is_boolean(edge.receipt_after?)
      assert is_boolean(edge.replayable?)
    end

    # W793: RouteCastleRun :execute is the single BRCE_ONLY from-node
    assert [do_edge] = Xaas.Castle.Generated.EdgeCatalog.do_edges()
    assert do_edge.sequence == 50
    assert do_edge.name == "nested-brce-do"
    assert do_edge.from == "Xaas.Operations.RouteCastleRun.execute"
    assert do_edge.to == "CASTLE BRCE"
    assert do_edge.authority == "BRCE_ONLY"
    assert do_edge.do_boundary?
    assert do_edge.receipt_before?
    assert do_edge.receipt_after?
    assert do_edge.replayable?

    # the outer-admission edge is receipt-after-bound and non-DO
    assert %{authority: "ADMIT_ONLY", receipt_after?: true, do_boundary?: false} =
             Enum.find(edges, &(&1.sequence == 20))

    # the head edge is the only edge without a receipt-after obligation
    assert %{receipt_after?: false} = Enum.find(edges, &(&1.sequence == 10))

    for edge <- edges, edge.sequence not in [10, 50] do
      assert edge.receipt_after?
      refute edge.do_boundary?
    end

    # deterministic replay law holds across the whole catalog
    assert Enum.all?(edges, & &1.replayable?)

    # authority vocabulary on the real catalog
    assert Enum.uniq(Enum.map(edges, & &1.authority)) |> Enum.sort() == [
             "ADMIT_ONLY",
             "BRCE_ONLY",
             "CONSTRUCT_ONLY",
             "RECEIPT_ONLY",
             "VERIFY_ONLY"
           ]
  end

  # ---------------------------------------------------------------------------
  # (b1) non-admitted transition: Execute refuses typed without Reactor context
  # ---------------------------------------------------------------------------

  test "private :execute refuses REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED with zero state yield" do
    before = db_snapshot()

    input =
      Ash.ActionInput.for_action(RouteCastleRun, :execute, %{
        intent: castle_intent()
      })

    assert {:error, error} = Ash.run_action(input, authorize?: false)
    assert inspect(error) =~ "REFUSED_XAAS_REACTOR_CONTEXT_REQUIRED"

    assert db_snapshot() == before
  end

  # ---------------------------------------------------------------------------
  # (b2) non-admitted transitions through the admission layer refuse typed
  # ---------------------------------------------------------------------------

  test "expired envelope refuses REFUSED_XAAS_ADMISSION_EXPIRED" do
    intent =
      castle_intent()
      |> put_in([:envelope, :expires_at_epoch_ms], now_ms() - 1_000)

    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:error, :REFUSED_XAAS_ADMISSION_EXPIRED} =
             Xaas.Castle.Admission.witness(input, intent, now_ms())
  end

  test "checkpoint bound to a foreign witness refuses REFUSED_XAAS_CHECKPOINT_WITNESS_MISMATCH" do
    intent = castle_intent()
    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:ok, witness} = Xaas.Castle.Admission.witness(input, intent, now_ms())
    checkpoint = base_checkpoint(witness)

    # a witness whose digest no longer matches the checkpoint is refused typed
    # at the kernel boundary (before W863 the Ash-action reload path refused
    # earlier with REFUSED_CASTLE_CHECKPOINT_PROTOCOL_MISMATCH — the W828
    # atom/string skew — shadowing this check there; the kernel-direct call
    # here exercises the boundary check itself)
    foreign = Map.put(witness, "witness_digest", hex())

    assert {:error, :REFUSED_CASTLE_CHECKPOINT_WITNESS_MISMATCH} =
             with_castle_lock(fn ->
               Xaas.Castle.Kernel.CLI.execute(intent, foreign, checkpoint, now_ms())
             end)
  end

  # ---------------------------------------------------------------------------
  # (b3) kernel-level lawful traversal: real witness -> hand-bound checkpoint
  #      -> real DO subprocess -> the real durable result
  # ---------------------------------------------------------------------------

  test "lawful kernel traversal yields the real receipted DO result" do
    intent = castle_intent()
    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:ok, witness} = Xaas.Castle.Admission.witness(input, intent, now_ms())
    assert witness["admitted"] == true
    assert witness["standing"] == "ALIVE"
    assert byte_size(witness["witness_digest"]) == 64
    assert witness["xaas_intent_id"] == to_string(admission.intent.id)
    assert witness["xaas_receipt_id"] == to_string(admission.receipt.id)

    checkpoint = base_checkpoint(witness)

    stub_do!(%{
      "standing" => "ALIVE",
      "ocel_receipt_digest" => hex(),
      "event_count" => 1,
      "brce_prepare_receipt_digests" => [hex()],
      "brce_outcome_receipt_digests" => [hex()],
      "evidence_commit" => %{
        "standing" => "ALIVE",
        "record_identity" => %{},
        "path" => Path.join(checkpoint["evidence_dir"], "do.json")
      }
    })

    assert {:ok, result} =
             with_castle_lock(fn ->
               Xaas.Castle.Kernel.CLI.execute(intent, witness, checkpoint, now_ms())
             end)

    assert result["standing"] == "ALIVE"
    assert result["recovered_from_evidence"] == false
    assert byte_size(result["construct_digest"]) == 64
    assert byte_size(result["construct_receipt_digest"]) == 64
    assert byte_size(result["process_digest"]) == 64
    assert byte_size(result["replay_identity_digest"]) == 64
    assert length(result["brce_prepare_receipt_digests"]) == 1
    assert length(result["brce_outcome_receipt_digests"]) == 1
    assert result["evidence_commit"]["standing"] == "ALIVE"
    assert result["kernel_binary_sha256"] == checkpoint["kernel_binary_sha256"]
  end

  # ---------------------------------------------------------------------------
  # (b4) W828 defect -> W863 regression court: the FULL lawful Execute
  #      traversal (Xaas.Castle.run/2 Reactor) reaches :succeeded with real
  #      sealed durable receipts, and deterministic replay consumes zero new rows
  # ---------------------------------------------------------------------------

  test "full lawful Execute traversal reaches :succeeded with a sealed durable receipt (W828 regression, W863 fix)" do
    intent = castle_intent()

    # the stub serves ONE payload for both kernel subcommands (construct and
    # do); it carries the construct identity AND the receipted-DO shape so the
    # Reactor's manufacture and private-execute steps both accept it
    stub_raw!(
      Jason.encode!(%{
        "standing" => "ALIVE",
        "construct_digest" => hex(),
        "construct_receipt_digest" => hex(),
        "process_digest" => hex(),
        "replay_identity_digest" => hex(),
        "ocel_receipt_digest" => hex(),
        "event_count" => 1,
        "brce_prepare_receipt_digests" => [hex()],
        "brce_outcome_receipt_digests" => [hex()],
        "evidence_commit" => %{"standing" => "ALIVE", "record_identity" => %{}, "path" => "/x"}
      })
    )

    key = "xaas-castle-court-w863-#{System.unique_integer([:positive])}"

    assert {:ok, envelope} =
             Xaas.Castle.run(intent,
               idempotency_key: key,
               authority: @authority
             )

    # the Reactor seal: real durable row, real :succeeded
    assert envelope.status == :succeeded
    assert envelope.result["standing"] == "ALIVE"
    assert envelope.result["recovered_from_evidence"] == false
    assert envelope.result["contract"]["protocol"] == @protocol_string
    assert length(envelope.result["brce_prepare_receipt_digests"]) == 1
    assert length(envelope.result["brce_outcome_receipt_digests"]) == 1
    assert envelope.result["evidence_commit"]["standing"] == "ALIVE"

    [receipt] = sealed_receipts()
    assert receipt.status == :succeeded
    assert receipt.resource_module == inspect(RouteCastleRun)
    assert receipt.action == "execute"
    # sealed result carries the DO outcome + the stringified contract identity
    assert receipt.result["standing"] == "ALIVE"
    assert receipt.result["contract"]["protocol"] == @protocol_string
    assert byte_size(receipt.result_hash) == 64
    assert is_binary(receipt.replay_token) and byte_size(receipt.replay_token) == 64

    # deterministic replay: same key -> :replayed, same receipt, zero new rows
    assert {:ok, replay} =
             Xaas.Castle.run(intent,
               idempotency_key: key,
               authority: @authority
             )

    assert replay.status == :replayed
    assert replay.replay?
    assert replay.receipt.id == receipt.id
    assert replay.result == receipt.result
    assert length(sealed_receipts()) == 1
  end

  test "contract protocol atom cannot survive the checkpoint jsonb round trip (why W863 normalizes at the compare)" do
    identity = Xaas.Castle.Contract.identity()
    assert identity.protocol == @protocol_atom

    round_tripped =
      %{"castle_construct" => %{"protocol" => identity.protocol}}
      |> Jason.encode!()
      |> Jason.decode!()

    assert round_tripped["castle_construct"]["protocol"] == @protocol_string
    refute round_tripped["castle_construct"]["protocol"] == identity.protocol
  end

  # ---------------------------------------------------------------------------
  # (c) RouteCastleRun reflection — the route surface keeps zero rows;
  #     durable reflection lives on the outer receipt
  # ---------------------------------------------------------------------------

  test "RouteCastleRun keeps zero rows; reflection is the outer receipt (direct action unsealed, seal belongs to the Reactor)" do
    assert Ash.read!(RouteCastleRun, authorize?: false) == []

    intent = castle_intent()
    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:ok, witness} = Xaas.Castle.Admission.witness(input, intent, now_ms())
    checkpoint = base_checkpoint(witness)

    assert {:ok, _} =
             Xaas.Actuation.checkpoint_external(admission, %{"castle_construct" => checkpoint})

    stub_do!(%{
      "standing" => "ALIVE",
      "ocel_receipt_digest" => hex(),
      "event_count" => 1,
      "brce_prepare_receipt_digests" => [hex()],
      "brce_outcome_receipt_digests" => [hex()],
      "evidence_commit" => %{"standing" => "ALIVE", "record_identity" => %{}, "path" => "/x"}
    })

    assert {:ok, result} = Ash.run_action(input, authorize?: false)
    assert result["standing"] == "ALIVE"
    assert result["contract"]["protocol"] == @protocol_string

    assert Ash.read!(RouteCastleRun, authorize?: false) == []

    # a direct action invocation does not seal; the Reactor owns the seal step
    receipts = sealed_receipts()
    assert length(receipts) == 1
    assert hd(receipts).resource_module == inspect(RouteCastleRun)
    assert hd(receipts).action == "execute"
    assert hd(receipts).status == :prepared
    assert hd(receipts).result["castle_construct"]["protocol"] == @protocol_string
  end

  # ---------------------------------------------------------------------------
  # (d) determinism x2
  # ---------------------------------------------------------------------------

  test "determinism x2: identical kernel traversal yields identical results" do
    intent = castle_intent()
    admission = prepare_admission!(intent)
    input = action_input(intent, admission)

    assert {:ok, witness} = Xaas.Castle.Admission.witness(input, intent, now_ms())
    checkpoint = base_checkpoint(witness)

    stub_do!(%{
      "standing" => "ALIVE",
      "ocel_receipt_digest" => hex(),
      "event_count" => 1,
      "brce_prepare_receipt_digests" => [hex()],
      "brce_outcome_receipt_digests" => [hex()],
      "evidence_commit" => %{"standing" => "ALIVE", "record_identity" => %{}, "path" => "/x"}
    })

    assert {:ok, first} =
             with_castle_lock(fn ->
               Xaas.Castle.Kernel.CLI.execute(intent, witness, checkpoint, now_ms())
             end)

    assert {:ok, second} =
             with_castle_lock(fn ->
               Xaas.Castle.Kernel.CLI.execute(intent, witness, checkpoint, now_ms())
             end)

    assert second == first
    assert first["recovered_from_evidence"] == false
  end

  test "determinism x2: re-preparing the same admission replays the sealed receipt" do
    intent = castle_intent()
    key = "xaas-castle-court-replay-#{System.unique_integer([:positive])}"

    opts = [
      subject_id: intent.subject,
      idempotency_key: key,
      authorize?: false,
      authority: @authority
    ]

    assert {:ok, first} =
             Xaas.Actuation.prepare_external(RouteCastleRun, :execute, %{intent: intent}, opts)

    assert first.status == :prepared

    # run the lawful kernel traversal to completion and seal the outer receipt
    admission = first.admission
    input = action_input(intent, admission)
    assert {:ok, witness} = Xaas.Castle.Admission.witness(input, intent, now_ms())
    checkpoint = base_checkpoint(witness)

    assert {:ok, _} =
             Xaas.Actuation.checkpoint_external(admission, %{"castle_construct" => checkpoint})

    stub_do!(%{
      "standing" => "ALIVE",
      "ocel_receipt_digest" => hex(),
      "event_count" => 1,
      "brce_prepare_receipt_digests" => [hex()],
      "brce_outcome_receipt_digests" => [hex()],
      "evidence_commit" => %{"standing" => "ALIVE", "record_identity" => %{}, "path" => "/x"}
    })

    assert {:ok, do_result} =
             with_castle_lock(fn ->
               Xaas.Castle.Kernel.CLI.execute(intent, witness, checkpoint, now_ms())
             end)

    assert {:ok, sealed} = Xaas.Actuation.seal_external(admission, {:ok, do_result})
    assert sealed.status == :succeeded

    receipt_count = length(Ash.read!(ActuationReceipt, authorize?: false))

    assert {:ok, second} =
             Xaas.Actuation.prepare_external(RouteCastleRun, :execute, %{intent: intent}, opts)

    assert second.status == :replayed
    assert second.replay?
    assert second.receipt.id == first.receipt.id
    assert second.result == sealed.result
    assert length(Ash.read!(ActuationReceipt, authorize?: false)) == receipt_count
    assert second.intent.id == first.intent.id
  end

  # ---------------------------------------------------------------------------
  # helpers
  # ---------------------------------------------------------------------------

  defp sealed_receipts do
    Ash.read!(ActuationReceipt, authorize?: false)
    |> Enum.filter(&(&1.resource_module == inspect(RouteCastleRun) and &1.action == "execute"))
  end

  defp castle_lock_path do
    System.get_env("XAAS_CASTLE_TEST_LOCK") ||
      Path.join(System.tmp_dir!(), "xaas-castle-test-cli.lock")
  end

  defp with_castle_lock(fun) do
    {:ok, lock} = acquire_castle_lock(castle_lock_path())

    try do
      fun.()
    after
      File.close(lock)
      File.rm(castle_lock_path())
    end
  end

  @castle_lock_stale_ms 30_000

  defp acquire_castle_lock(path, waited_ms \\ 0)

  defp acquire_castle_lock(path, waited_ms) when waited_ms >= @castle_lock_stale_ms do
    File.rm(path)
    acquire_castle_lock(path, -1)
  end

  defp acquire_castle_lock(path, waited_ms) do
    case File.open(path, [:read, :write, :exclusive]) do
      {:ok, fd} ->
        {:ok, fd}

      {:error, :eexist} ->
        Process.sleep(50)
        acquire_castle_lock(path, waited_ms + 50)

      {:error, :enoent} ->
        File.mkdir_p!(Path.dirname(path))
        acquire_castle_lock(path, waited_ms)
    end
  end

  defp setup_fake_castle! do
    n = System.unique_integer([:positive, :monotonic])

    script =
      System.tmp_dir!()
      |> Path.join("xaas-castle-court-bin-#{n}.sh")
      |> Path.expand()

    File.write!(script, """
    #!/bin/sh
    : "${CASTLE_FAKE_EXIT:=0}"
    cat "$CASTLE_FAKE_OUTPUT"
    exit "$CASTLE_FAKE_EXIT"
    """)

    File.chmod!(script, 0o755)

    output_path =
      System.tmp_dir!()
      |> Path.join("xaas-castle-court-output-#{n}.json")

    key =
      System.tmp_dir!()
      |> Path.join("xaas-castle-court-key-#{n}.hex")

    File.write!(key, String.duplicate("09", 32))

    root =
      System.tmp_dir!()
      |> Path.join("xaas-castle-court-evidence-#{n}")
      |> Path.expand()

    File.mkdir_p!(root)

    System.put_env("CASTLE_BIN", script)
    System.put_env("CASTLE_BIN_SHA256", sha256_file(script))
    System.put_env("CASTLE_SIGNING_KEY_PATH", key)
    System.put_env("CASTLE_KEY_ID", "xaas-castle-court-key")
    System.put_env("CASTLE_EVIDENCE_ROOT", root)
    System.put_env("CASTLE_FAKE_OUTPUT", output_path)
    System.delete_env("CASTLE_FAKE_EXIT")

    Process.put({__MODULE__, :evidence_root}, root)
    Process.put({__MODULE__, :output_path}, output_path)
    Process.put({__MODULE__, :profile_digest}, nil)

    stub_construct!(%{
      "standing" => "ALIVE",
      "construct_digest" => hex(),
      "construct_receipt_digest" => hex(),
      "process_digest" => hex(),
      "replay_identity_digest" => hex()
    })

    profile = %{
      allowed_authorities: ["bounded-do"],
      adapter_policy: %{
        adapter_id: "xaas-local-proof",
        provider: "local",
        workload_identity: "workload:xaas-castle-proof",
        commands: %{
          "echo" => %{
            transition_id: "echo",
            program: "/bin/echo",
            args: ["castle-execute-court"],
            allowed_exit_codes: [0],
            max_output_bytes: 4096,
            timeout_ms: 2_000
          }
        }
      }
    }

    Process.put({__MODULE__, :profile}, profile)

    previous = Application.get_env(:xaas, :castle_adapter_profiles)
    Application.put_env(:xaas, :castle_adapter_profiles, %{"xaas-local-proof" => profile})

    on_exit(fn ->
      File.rm(script)
      File.rm(output_path)
      File.rm(key)
      File.rm_rf(root)

      for k <-
            ~w(CASTLE_BIN CASTLE_BIN_SHA256 CASTLE_SIGNING_KEY_PATH CASTLE_KEY_ID CASTLE_EVIDENCE_ROOT CASTLE_FAKE_OUTPUT CASTLE_FAKE_EXIT) do
        System.delete_env(k)
      end

      if is_nil(previous),
        do: Application.delete_env(:xaas, :castle_adapter_profiles),
        else: Application.put_env(:xaas, :castle_adapter_profiles, previous)
    end)

    :ok
  end

  defp stub_construct!(construct), do: stub_raw!(Jason.encode!(construct))
  defp stub_do!(do_output), do: stub_raw!(Jason.encode!(do_output))

  defp stub_raw!(body), do: File.write!(output_path(), body)

  defp output_path do
    Process.get({__MODULE__, :output_path}) || raise "castle court output path not initialized"
  end

  defp evidence_root do
    Process.get({__MODULE__, :evidence_root}) || raise "castle court evidence root not initialized"
  end

  defp db_snapshot do
    %{
      intents: length(Ash.read!(ActuationIntent, authorize?: false)),
      receipts: length(Ash.read!(ActuationReceipt, authorize?: false))
    }
  end

  defp prepare_admission!(intent) do
    {:ok, prepared} =
      Xaas.Actuation.prepare_external(RouteCastleRun, :execute, %{intent: intent},
        subject_id: intent.subject,
        idempotency_key: "xaas-castle-court-#{System.unique_integer([:positive])}",
        authorize?: false,
        authority: @authority
      )

    assert prepared.status == :prepared
    prepared.admission
  end

  defp action_input(intent, admission) do
    Ash.ActionInput.for_action(RouteCastleRun, :execute, %{intent: intent},
      context: Xaas.Actuation.context(admission)
    )
  end

  defp castle_intent do
    now = System.system_time(:millisecond)

    %{
      adapter_profile_id: "xaas-local-proof",
      subject: "system:xaas-castle-proof",
      authority: "bounded-do",
      config_graph: %{"zeroUnreceiptedActuation" => true},
      ontology: %{"version" => "26.8.18"},
      process: %{
        id: "powl:xaas-castle-court",
        goal_id: "goal:xaas-castle-court",
        activities: [%{id: "activity:echo", transition_id: "echo", predecessors: []}]
      },
      envelope: %{
        system_id: "system:xaas-castle-proof",
        allowed_transition_ids: ["echo"],
        max_steps: 1,
        expires_at_epoch_ms: now + 60_000
      }
    }
  end

  defp base_checkpoint(witness) do
    identity = Xaas.Castle.Contract.identity()
    profile = Process.get({__MODULE__, :profile})

    %{
      "protocol" => identity.protocol,
      "castle_paas_source_sha" => identity.castle_paas_source_sha,
      "witness_digest" => witness["witness_digest"],
      "construct_digest" => hex(),
      "construct_receipt_digest" => hex(),
      "process_digest" => hex(),
      "replay_identity_digest" => hex(),
      "kernel_binary_sha256" => sha256_file(System.fetch_env!("CASTLE_BIN")),
      "signing_key_sha256" => sha256_file(System.fetch_env!("CASTLE_SIGNING_KEY_PATH")),
      "adapter_profile_digest" =>
        fingerprint(%{
          adapter_policy: profile.adapter_policy,
          allowed_authorities: profile.allowed_authorities
        }),
      "evidence_dir" => Path.join(Path.expand(evidence_root()), witness["witness_digest"])
    }
  end

  # Replicates the kernel's private profile fingerprint so the hand-bound
  # checkpoint carries the real configured adapter profile identity.
  defp fingerprint(term) do
    term
    |> canonical_term()
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp canonical_term(%_{} = struct), do: struct |> Map.from_struct() |> canonical_term()

  defp canonical_term(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {to_string(key), canonical_term(value)} end)
    |> Enum.sort()
  end

  defp canonical_term(list) when is_list(list), do: Enum.map(list, &canonical_term/1)

  defp canonical_term(tuple) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&canonical_term/1)

  defp canonical_term(atom) when is_atom(atom), do: Atom.to_string(atom)
  defp canonical_term(other), do: other

  defp sha256_file(path) do
    path
    |> File.read!()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp hex do
    :crypto.strong_rand_bytes(32)
    |> Base.encode16(case: :lower)
  end

  defp now_ms, do: System.system_time(:millisecond)
end
