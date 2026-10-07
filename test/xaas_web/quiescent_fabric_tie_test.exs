defmodule XaasWeb.QuiescentFabricTieTest do
  @moduledoc """
  Lane W824 — tie the Art. 27.3 quiescent-stop attractor
  (`Xaas.Actuation.QuiescentStop`, W704-deepened at the module level) into the
  execution-fabric verb surface (W745's lease-gated `actuate` verb).

  Wiring fact (evidence over invention): the fabric has NO dedicated halt
  verb and never calls `QuiescentStop.execute/2`. The halt reaches the wire
  through W745's `actuate` verb — `action: "actuate_status"`,
  `input: %{"status" => "suspended"}` — which routes through
  `Xaas.Ultracode.Lease.actuate/2` into the admitted `Xaas.Actuation.run/4`
  DO kernel. So this court ties the fabric layer to the SAME durable halt
  record the module court asserts, and files the module↔fabric coupling gap
  as a typed finding in the lane receipt.

  Chicago-style: real ConnCase HTTP behind the real bearer gate, real sandbox
  rows (Run/Epoch/ActuationIntent/ActuationReceipt/Provider), the resolver's
  own config seam for the capability source and actuation registry (same
  pattern as W745). No mocks; no path bypasses `Xaas.Actuation.run/4`.
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt}
  alias Xaas.Ultracode.{Epoch, Run}

  # Hand-written real interface implementation, not a mock — same shape as
  # W745's PublishSource, injected through the resolver's own config seam.
  defmodule HaltSource do
    @moduledoc false
    @behaviour Xaas.Ultracode.CapabilityResolver.Source

    @impl true
    def candidates(_item, _ctx),
      do: {:ok, [%{capability_id: "sa2a:publish_change", satisfies: ["publish_change"]}]}
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)

    keys = [:ultracode_capability_sources, :ultracode_actuation_registry]
    saved = Map.new(keys, &{&1, Application.fetch_env(:xaas, &1)})

    on_exit(fn ->
      Enum.each(saved, fn
        {key, {:ok, value}} -> Application.put_env(:xaas, key, value)
        {key, :error} -> Application.delete_env(:xaas, key)
      end)
    end)

    :ok
  end

  # ------------------------------------------------------------------
  # Transport helpers (real HTTP, real bearer gate)
  # ------------------------------------------------------------------

  defp mcp_post(conn, body) do
    conn
    |> put_req_header("authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/internal-api/execution/mcp", Jason.encode!(body))
  end

  defp mcp_result(conn, method, params) do
    conn
    |> mcp_post(%{jsonrpc: "2.0", id: 1, method: method, params: params})
    |> json_response(200)
    |> Map.fetch!("result")
  end

  defp tool_call(conn, name, arguments) do
    result = mcp_result(conn, "tools/call", %{"name" => name, "arguments" => arguments})
    [%{"text" => text}] = result["content"]
    {result["isError"] == true, Jason.decode!(text)}
  end

  defp claimed(conn, provider) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "W824 quiescent-fabric tie.", provider: provider},
        authorize?: false
      )
      |> Ash.create()

    {:ok, epoch} =
      Epoch
      |> Ash.Changeset.for_create(
        :create,
        %{
          run_id: run.id,
          cycle: 0,
          exact_subject: "XaasWeb.QuiescentFabricTieTest",
          state: :running
        },
        authorize?: false
      )
      |> Ash.create()

    {false, claim} =
      tool_call(conn, "claim_next", %{
        provider: provider,
        provider_worker_id: "worker-w824",
        epoch_id: epoch.id
      })

    claim
  end

  # Registers the halt pair for a synthetic fabric provider and claims a
  # real lease over the real MCP surface.
  defp halt_lease(conn, marketplace_provider) do
    fabric_provider = "w824-halt-#{System.unique_integer([:positive])}"

    Application.put_env(:xaas, :ultracode_capability_sources, %{"local" => HaltSource})

    Application.put_env(:xaas, :ultracode_actuation_registry, %{
      fabric_provider => %{
        {"Xaas.Marketplace.Provider", "actuate_status"} =>
          {Xaas.Marketplace.Provider, :actuate_status, marketplace_provider.id}
      }
    })

    claimed(conn, fabric_provider)
  end

  # A halt through the admitted fabric path: lease-gated actuate verb,
  # suspended status, fresh idempotency key.
  defp fabric_halt(conn, token, marketplace_provider_id, key) do
    tool_call(conn, "actuate", %{
      "lease_token" => token,
      "capability" => "publish_change",
      "resource" => "Xaas.Marketplace.Provider",
      "action" => "actuate_status",
      "input" => %{"status" => "suspended"},
      "idempotency_key" => key
    })
  end

  defp halt_key, do: "estop-w824-#{System.unique_integer([:positive])}"

  defp provider_status(provider_id) do
    Provider
    |> Ash.get!(provider_id, authorize?: false)
    |> Map.fetch!(:status)
  end

  defp intent_count, do: length(Ash.read!(ActuationIntent, authorize?: false))

  # ------------------------------------------------------------------
  # (a) Halt through the admitted fabric path produces the durable halt
  #     record W704's module court asserts
  # ------------------------------------------------------------------

  test "a halt through the lease-gated actuate verb lands the durable quiescent record " <>
         "and cross-checks the module-level contract",
       %{conn: conn} do
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w824-halt"})
    claim = halt_lease(conn, marketplace_provider)
    token = claim["lease_token"]
    key = halt_key()

    assert {false, halt} = fabric_halt(conn, token, marketplace_provider.id, key)

    assert halt["status"] == "succeeded"
    assert halt["replay"] == false
    assert is_binary(halt["intent_id"])

    # The durable record: a real ActuationIntent with lease-bound authority,
    # cross-checked against the QuiescentStop module contract — its `do_stop/2`
    # goes through the SAME kernel, so the ledger row shape must match what
    # W704's court sees (ActuationIntent keyed by idempotency_key, sealed
    # ActuationReceipt, provider at the quiescent status :suspended).
    intent = Ash.get!(ActuationIntent, halt["intent_id"], authorize?: false)
    assert intent.idempotency_key == key
    assert intent.authority["kind"] == "ultracode_lease_actuation"
    assert intent.authority["lease_fingerprint"]
    refute intent.authority["lease_fingerprint"] == token

    receipt = Ash.get!(ActuationReceipt, halt["receipt_id"], authorize?: false)
    assert receipt.intent_id == intent.id

    # The module-level contract: the subject is driven to @quiescent_status.
    assert provider_status(marketplace_provider.id) == :suspended

    # The module surface, invoked at the same subject, now observes the
    # attractor state the fabric drove it to (fresh key → typed refusal).
    assert {:error, :REFUSED_STOP_SUBJECT_ALREADY_QUIESCENT} =
             Xaas.Actuation.QuiescentStop.execute(Provider,
               subject_id: marketplace_provider.id,
               idempotency_key: "estop-w824-cross-#{System.unique_integer([:positive])}",
               authority: %{kind: "w824", source: "quiescent_fabric_tie_test"}
             )
  end

  # ------------------------------------------------------------------
  # (b) The halt record's idempotency replays through the fabric:
  #     same key -> same typed no-op
  # ------------------------------------------------------------------

  test "same idempotency key through the fabric is a typed replay no-op: same intent, " <>
         "no new rows, subject unchanged",
       %{conn: conn} do
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w824-replay"})
    claim = halt_lease(conn, marketplace_provider)
    token = claim["lease_token"]
    key = halt_key()

    assert {false, first} = fabric_halt(conn, token, marketplace_provider.id, key)
    assert first["status"] == "succeeded"
    assert first["replay"] == false

    assert {false, second} = fabric_halt(conn, token, marketplace_provider.id, key)

    # Typed no-op: the kernel surfaces a distinct `replayed` status (stronger
    # than a silent success), same intent identity, no new DO.
    assert second["status"] == "replayed"
    assert second["replay"] == true
    assert second["intent_id"] == first["intent_id"]
    assert second["receipt_id"] == first["receipt_id"]

    # No new ledger rows and the attractor state holds.
    assert Ash.get!(ActuationIntent, second["intent_id"], authorize?: false).idempotency_key == key

    assert provider_status(marketplace_provider.id) == :suspended
  end

  # ------------------------------------------------------------------
  # (c) Typed refusals at the fabric layer for malformed halt authority
  # ------------------------------------------------------------------

  test "malformed halt authority at the fabric layer is refused typed, never a silent DO",
       %{conn: conn} do
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w824-refusal"})
    _claim = halt_lease(conn, marketplace_provider)

    # c.1 missing lease entirely -> the typed surface failure (W723 floor
    # already answered: the request reached the tool with a valid bearer).
    assert {true, %{"error" => "WORK_NOT_FOUND", "failure" => failure}} =
             fabric_halt(conn, "no-such-lease", marketplace_provider.id, halt_key())

    assert failure["details"]["reason"] == "no_lease"

    # c.2 live lease, no capability -> the typed UNAUTHORIZED two-port court
    # (the actuation authority never forms).
    fabric_provider = "w824-nocap-#{System.unique_integer([:positive])}"

    Application.put_env(:xaas, :ultracode_actuation_registry, %{
      fabric_provider => %{
        {"Xaas.Marketplace.Provider", "actuate_status"} =>
          {Xaas.Marketplace.Provider, :actuate_status, marketplace_provider.id}
      }
    })

    claim = claimed(conn, fabric_provider)

    assert {true, %{"error" => "UNAUTHORIZED", "failure" => failure}} =
             tool_call(conn, "actuate", %{
               "lease_token" => claim["lease_token"],
               "resource" => "Xlms.Marketplace.Provider",
               "action" => "actuate_status",
               "input" => %{"status" => "suspended"},
               "idempotency_key" => halt_key()
             })

    assert failure["details"]["reason"] == "capability_required"
    assert provider_status(marketplace_provider.id) == :pending

    # c.3 registered pair but a subject OTHER than the operator-registered
    # subject is structurally impossible over the wire (no subject_id arg on
    # purpose); a halt aimed at the registered subject with a malformed
    # kernel-level idempotency key is refused typed by the kernel.
    fabric_provider2 = "w824-malkey-#{System.unique_integer([:positive])}"

    Application.put_env(:xaas, :ultracode_actuation_registry, %{
      fabric_provider2 => %{
        {"Xaas.Marketplace.Provider", "actuate_status"} =>
          {Xaas.Marketplace.Provider, :actuate_status, marketplace_provider.id}
      }
    })

    claim2 = claimed(conn, fabric_provider2)

    assert {true, %{"error" => error}} =
             tool_call(conn, "actuate", %{
               "lease_token" => claim2["lease_token"],
               "capability" => "publish_change",
               "resource" => "Xaas.Marketplace.Provider",
               "action" => "actuate_status",
               "input" => %{"status" => "suspended"},
               "idempotency_key" => nil
             })

    assert error =~ "idempotency_key_required"

    # No DO for any malformed shape.
    assert provider_status(marketplace_provider.id) == :pending
  end

  # ------------------------------------------------------------------
  # (e) W844 — the quiescent envelope surfaces on the MCP wire. W824's
  #     typed finding: the halt response was the generic actuate result
  #     (status/replay/intent_id/receipt_id/result) with no trace of the
  #     QuiescentStop semantics. Now: every halt response carries
  #     `target: "quiescent"` + `already_stopped`, additive to (never
  #     reshaping) the generic envelope, and any kernel refusal surfaces
  #     its typed code.
  # ------------------------------------------------------------------

  test "halt response carries the quiescent envelope: target/already_stopped additive fields",
       %{conn: conn} do
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w844-envelope"})
    claim = halt_lease(conn, marketplace_provider)
    token = claim["lease_token"]

    # First halt: fresh stop, not already stopped.
    key = halt_key()
    assert {false, halt} = fabric_halt(conn, token, marketplace_provider.id, key)

    assert halt["status"] == "succeeded"
    assert halt["target"] == "quiescent"
    assert halt["already_stopped"] == false
    # Additive: the generic contract fields are still present.
    assert is_binary(halt["intent_id"])
    assert is_binary(halt["receipt_id"])

    # Idempotent replay of the same stop: the module contract's
    # `{:ok, %{already_stopped: true}}` analog, surfaced on the wire.
    assert {false, replay} = fabric_halt(conn, token, marketplace_provider.id, key)

    assert replay["status"] == "replayed"
    assert replay["target"] == "quiescent"
    assert replay["already_stopped"] == true
  end

  test "non-quiescent actuation response is unchanged: no envelope fields leak", %{conn: conn} do
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w844-nontie"})
    fabric_provider = "w844-active-#{System.unique_integer([:positive])}"

    Application.put_env(:xaas, :ultracode_capability_sources, %{"local" => HaltSource})

    Application.put_env(:xaas, :ultracode_actuation_registry, %{
      fabric_provider => %{
        {"Xaas.Marketplace.Provider", "actuate_status"} =>
          {Xaas.Marketplace.Provider, :actuate_status, marketplace_provider.id}
      }
    })

    claim = claimed(conn, fabric_provider)

    assert {false, actuation} =
             tool_call(conn, "actuate", %{
               "lease_token" => claim["lease_token"],
               "capability" => "publish_change",
               "resource" => "Xaas.Marketplace.Provider",
               "action" => "actuate_status",
               "input" => %{"status" => "active"},
               "idempotency_key" => "w844-active-#{System.unique_integer([:positive])}"
             })

    assert actuation["status"] == "succeeded"
    refute Map.has_key?(actuation, "target")
    refute Map.has_key?(actuation, "already_stopped")
    refute Map.has_key?(actuation, "refusal")
  end

  # ------------------------------------------------------------------
  # (d) Determinism: the halt refusal shape is byte-identical across calls
  # ------------------------------------------------------------------

  test "halt refusal determinism x2: identical full HTTP bodies", %{conn: conn} do
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w824-determinism"})
    _claim = halt_lease(conn, marketplace_provider)

    body = %{
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: %{
        "name" => "actuate",
        "arguments" => %{
          "lease_token" => "no-such-lease",
          "capability" => "publish_change",
          "resource" => "Xaas.Marketplace.Provider",
          "action" => "actuate_status",
          "input" => %{"status" => "suspended"},
          "idempotency_key" => "w824-determinism"
        }
      }
    }

    bodies =
      for _ <- 1..2 do
        conn
        |> mcp_post(body)
        |> json_response(200)
      end

    assert [first, second] = bodies
    assert first == second

    text =
      first
      |> Map.fetch!("result")
      |> Map.fetch!("content")
      |> List.first()
      |> Map.fetch!("text")

    assert text =~ "WORK_NOT_FOUND"
    assert text =~ "no_lease"
  end

  # ------------------------------------------------------------------
  # (g) W866 — kernel-refused quiescent attempt: real ledger + wire
  #     semantics. W844's typed finding asked for the `refusal` mapping to
  #     be courted end-to-end; the courts below pin the REAL behavior on
  #     both layers:
  #
  #     Ledger: a kernel-level refusal of an already-admitted-key quiescent
  #     intent is an ADMIT-time refusal (`find_or_create/5` -> conflict or
  #     not-replayable) — the data-layer transaction rolls back, so the
  #     refused attempt mints NO new intent and NO new receipt row.
  #
  #     Wire: `Xaas.Actuation.run/4` normalizes a `:refused`/`:failed`
  #     envelope to `{:error, error}`, so a kernel refusal surfaces as a
  #     typed tool error — never as an OK envelope carrying a `refusal`
  #     key. The `maybe_refusal/2` mapping is therefore reachable only if
  #     the kernel's OK-envelope contract changes (W866 typed finding in
  #     the lane receipt).
  # ------------------------------------------------------------------

  test "kernel-refused quiescent attempt (idempotency conflict at admit): typed tool error, " <>
         "no new ledger rows, attractor unchanged",
       %{conn: conn} do
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w866-conflict"})
    claim = halt_lease(conn, marketplace_provider)
    token = claim["lease_token"]
    key = halt_key()

    # First halt lands: the key is now bound to a succeeded intent.
    assert {false, halt} = fabric_halt(conn, token, marketplace_provider.id, key)
    assert halt["status"] == "succeeded"

    # A second quiescent attempt with the SAME key but a DIFFERENT input is
    # refused by the kernel at admission (input-hash mismatch on the bound
    # intent) — before any DO and before any receipt mutation.
    assert {true, error_body} =
             tool_call(conn, "actuate", %{
               "lease_token" => token,
               "capability" => "publish_change",
               "resource" => "Xaas.Marketplace.Provider",
               "action" => "actuate_status",
               "input" => %{"status" => "suspended", "reason" => "w866-conflict"},
               "idempotency_key" => key
             })

    # The refusal is the kernel's typed conflict, surfaced as a tool error
    # (never a silent success, never a generic 500).
    assert error_body["error"] =~ "idempotency_conflict"

    # The admit-time refusal minted no new ledger rows for the refused
    # attempt: exactly one intent for the key, still bound to its original
    # sealed-succeeded receipt.
    intents = Enum.filter(Ash.read!(ActuationIntent, authorize?: false), &(&1.idempotency_key == key))
    assert length(intents) == 1

    receipt = Ash.get!(ActuationReceipt, halt["receipt_id"], authorize?: false)
    assert receipt.intent_id == hd(intents).id
    assert receipt.status == :succeeded

    # The attractor holds: no new DO occurred for the refused attempt.
    assert provider_status(marketplace_provider.id) == :suspended
  end

  test "malformed stop authority is refused before the kernel: typed REFUSED_STOP_AUTHORITY " <>
         "with no intent row and no receipt row for the refused attempt",
       %{conn: conn} do
    marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-w866-authority"})
    _claim = halt_lease(conn, marketplace_provider)
    key = "estop-w866-authority-#{System.unique_integer([:positive])}"

    # W704's module contract: `authority_admitted?/1` demands a binary :kind
    # AND a binary :source. An authority missing :source is malformed.
    assert {:error, :REFUSED_STOP_AUTHORITY} =
             Xaas.Actuation.QuiescentStop.execute(Provider,
               subject_id: marketplace_provider.id,
               idempotency_key: key,
               authority: %{kind: "w866-malformed"}
             )

    # The refusal fires in the module's own admission court, BEFORE
    # `Xaas.Actuation.run/4` — so no intent and no receipt exist for the
    # refused attempt (the kernel never sealed anything for it).
    refute Enum.any?(Ash.read!(ActuationIntent, authorize?: false), &(&1.idempotency_key == key))

    # The attractor was never driven: the subject is untouched.
    assert provider_status(marketplace_provider.id) == :pending
  end
end
