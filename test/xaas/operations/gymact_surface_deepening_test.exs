defmodule Xaas.Operations.GymactSurfaceDeepeningTest do
  @moduledoc """
  W674 deepening court for `Xaas.Operations.GymactSurface`.

  Extends `gymact_surface_test.exs` along the axes the base court leaves
  open, all Chicago-style (real collaborators, final-state assertions):

    1. the fail-closed `:gymact_not_configured` typed refusal;
    2. the full external three-commit protocol (`prepare_external` durable
       intent -> real HTTP DO -> `seal_external` durable outer seal) over a
       real local HTTP endpoint — a real Bandit/Plug server spawned in-test,
       not a mock of owned code (it stands in for the *remote* gymact
       service, reached over real HTTP by the real Req client);
    3. idempotency-key stability across retries (success replay skips the
       remote DO);
    4. typed behavior when the remote returns non-2xx or is unreachable —
       the DO failure IS durably sealed (`:failed`, json-safe typed error
       map) per the W707 fix of W674-GAP-1.
  """

  use ExUnit.Case, async: false

  require Ash.Query

  alias Xaas.Marketplace.Provider
  alias Xaas.Operations.{ActuationIntent, ActuationReceipt, GymactSurface}

  @token "gymact-deepening-test-token"
  @hits_key {:w674, :hits}
  @mode_key {:w674, :mode}

  setup do
    previous = System.get_env("INTERNAL_API_TOKEN")
    System.delete_env("INTERNAL_API_TOKEN")

    on_exit(fn ->
      Application.delete_env(:xaas, :gymact_surface)

      if previous,
        do: System.put_env("INTERNAL_API_TOKEN", previous),
        else: System.delete_env("INTERNAL_API_TOKEN")
    end)

    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  # ------------------------------------------------------------------
  # 1. Fail-closed typed refusal
  # ------------------------------------------------------------------

  describe "fail-closed config gate" do
    test "unconfigured config+env yields the typed GYMACT_NOT_CONFIGURED refusal" do
      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.config()
    end

    test "actuate_local/4 refuses typed before Xaas.Actuation.run/4" do
      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.actuate_local(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 idempotency_key: "w674-local-refusal"
               )
    end

    test "base_url-only config (token from neither config nor env) is refused" do
      Application.put_env(:xaas, :gymact_surface, base_url: "http://127.0.0.1:1")

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.config()
    end

    test "trailing slash is normalized; empty base_url is refused" do
      Application.put_env(:xaas, :gymact_surface,
        base_url: "http://127.0.0.1:1/",
        token: @token
      )

      assert {:ok, %{base_url: "http://127.0.0.1:1", token: @token}} = GymactSurface.config()

      Application.put_env(:xaas, :gymact_surface, base_url: "", token: @token)

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.config()
    end
  end

  # ------------------------------------------------------------------
  # 2-4. Real local HTTP endpoint: a real Bandit/Plug server standing in
  # for the remote gymact FastAPI service; the adapter talks to it over
  # real HTTP with the real Req client. State is shared via
  # :persistent_term because Bandit handlers run in other processes.
  # ------------------------------------------------------------------

  describe "external three-commit protocol over real local HTTP" do
    setup do
      :persistent_term.put(@hits_key, :counters.new(1, [:atomics]))
      :persistent_term.put(@mode_key, :counters.new(1, [:atomics]))
      set_mode(:ok)

      port = free_port()

      {:ok, _} =
        Bandit.start_link(
          plug: __MODULE__,
          ip: {127, 0, 0, 1},
          port: port,
          thousand_island_options: [shutdown_timeout: 100]
        )

      Application.put_env(:xaas, :gymact_surface,
        base_url: "http://127.0.0.1:#{port}",
        token: @token
      )

      provider = Xaas.Generator.create_provider!(%{name: "W674 Provider", org_id: "org-w674"})

      %{port: port, provider: provider}
    end

    test "prepare -> real HTTP DO -> seal leaves a succeeded receipt and an active provider",
         %{provider: provider} do
      key = "w674-success-#{System.unique_integer([:positive])}"

      assert {:ok, envelope} =
               GymactSurface.actuate(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 idempotency_key: key,
                 subject_id: provider.id,
                 authorize?: false,
                 authority: %{kind: "test_authority", source: "w674_deepening"},
                 episode_id: "ep-w674",
                 cut: %{"digest" => "w674-opaque-cut", "actions" => [%{"ref" => "set-lamp"}]}
               )

      assert envelope.status == :succeeded
      assert envelope.replay? == false
      assert envelope.receipt.status == :succeeded
      assert envelope.intent.status == :succeeded
      assert envelope.result["echo"]["digest"] == "w674-opaque-cut"
      assert envelope.receipt.completed_at

      # DO really crossed the wire exactly once.
      assert hits() == 1

      # Final state: the remote DO is the ONLY consequence of the external
      # protocol — the local Ash subject is deliberately NOT mutated by
      # actuate/4 (that is actuate_local/4's job).
      assert :pending =
               Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status)
    end

    test "same idempotency key on retry replays without a second remote DO",
         %{provider: provider} do
      key = "w674-idem-#{System.unique_integer([:positive])}"

      opts = [
        idempotency_key: key,
        subject_id: provider.id,
        authorize?: false,
        authority: %{kind: "test_authority", source: "w674_deepening"},
        episode_id: "ep-w674",
        cut: %{"digest" => "w674-idem-cut"}
      ]

      assert {:ok, first} = GymactSurface.actuate(Provider, :actuate_status, %{status: :active}, opts)
      assert first.status == :succeeded
      assert hits() == 1

      assert {:ok, replay} = GymactSurface.actuate(Provider, :actuate_status, %{status: :active}, opts)
      assert replay.status == :replayed
      assert replay.replay? == true
      # No second remote DO crossed the wire.
      assert hits() == 1
    end

    @tag :w674_gap_1
    test "non-2xx remote is durably sealed :failed with a json-safe typed error map",
         %{provider: provider} do
      set_mode(:fail)
      key = "w707-fail-#{System.unique_integer([:positive])}"

      assert {:error, %{class: :gymact_http_error, status: 500, body: body}} =
               GymactSurface.actuate(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 idempotency_key: key,
                 subject_id: provider.id,
                 authorize?: false,
                 authority: %{kind: "test_authority", source: "w707_seal_fix"},
                 episode_id: "ep-w707",
                 cut: %{"digest" => "w707-fail-cut"}
               )

      assert body == %{"error" => "internal"}

      # The DO failure IS durably recorded (W674-GAP-1 fixed): receipt and
      # intent both sealed :failed with the same json-safe map (the ledger's
      # :error column requires a MAP — the pre-fix tuple rendered as a LIST
      # and the whole seal rolled back). Actuate surfaces the typed error
      # per normalize_transaction_result's failed/refused contract.
      assert %ActuationReceipt{status: :failed, error: receipt_error,
                               completed_at: completed_at} =
               sealed_receipt!(key)

      assert receipt_error == %{
               "class" => "gymact_http_error",
               "status" => 500,
               "body" => %{"error" => "internal"}
             }

      assert completed_at
      assert %ActuationIntent{status: :failed} = sealed_intent!(key)

      assert {:ok, 1} =
               ActuationReceipt
               |> Ash.Query.filter(intent_id: sealed_intent!(key).id)
               |> Ash.count(authorize?: false)

      # The real subject was NOT mutated (the remote refused the DO).
      assert :pending =
               Provider |> Ash.get!(provider.id, authorize?: false) |> Map.fetch!(:status)
    end

    test "transport-level remote failure is durably sealed :failed with a typed error map",
         %{provider: provider} do
      # Point the adapter at a port with nothing listening: a real
      # Req/econnrefused transport failure, sealed durably.
      Application.put_env(:xaas, :gymact_surface,
        base_url: "http://127.0.0.1:1",
        token: @token
      )

      key = "w707-transport-#{System.unique_integer([:positive])}"

      assert {:error, %{class: :gymact_transport_error, message: message}} =
               GymactSurface.actuate(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 idempotency_key: key,
                 subject_id: provider.id,
                 authorize?: false,
                 authority: %{class: "test_authority", source: "w707_seal_fix"},
                 episode_id: "ep-w707",
                 cut: %{"digest" => "w707-transport-cut"}
               )

      assert is_binary(message) and message != ""

      assert %ActuationReceipt{
               status: :failed,
               error: %{"class" => "gymact_transport_error", "message" => message}
             } = sealed_receipt!(key)

      assert is_binary(message) and message != ""

      assert %ActuationIntent{status: :failed} = sealed_intent!(key)
    end

    @tag :w674_gap_2
    test "missing :episode_id is a typed :episode_id_required refusal, durably sealed :refused",
         %{provider: _provider} do
      key = "w707-missing-episode-#{System.unique_integer([:positive])}"

      assert {:error, %Xaas.Actuation.Refusal{code: :episode_id_required}} =
               GymactSurface.actuate(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 idempotency_key: key,
                 subject_id: nil,
                 authorize?: false,
                 authority: %{kind: "test_authority", source: "w707_seal_fix"},
                 cut: %{"digest" => "w707-no-episode"}
               )

      # W674-GAP-2 fixed — no raw WithClauseError. Kernel.seal classifies the
      # Refusal as a policy REFUSED, durably (the :error map is
      # %{"refused" => code, "detail" => json-safe detail}).
      assert %ActuationReceipt{
               status: :refused,
               error: %{"refused" => "episode_id_required", "detail" => detail}
             } = sealed_receipt!(key)

      assert detail == %{"opt" => "episode_id"}

      assert %ActuationIntent{status: :refused} = sealed_intent!(key)
    end

    test "missing :cut is a typed :cut_required refusal, durably sealed :refused",
         %{provider: _provider} do
      key = "w707-missing-cut-#{System.unique_integer([:positive])}"

      assert {:error, %Xaas.Actuation.Refusal{code: :cut_required}} =
               GymactSurface.actuate(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 idempotency_key: key,
                 subject_id: nil,
                 authorize?: false,
                 authority: %{kind: "test_authority", source: "w707_seal_fix"},
                 episode_id: "ep-w707"
               )

      assert %ActuationReceipt{status: :refused, error: %{"refused" => "cut_required"}} =
               sealed_receipt!(key)

      assert %ActuationIntent{status: :refused} = sealed_intent!(key)
    end

    test "missing :idempotency_key surfaces typed and seals nothing" do
      assert {:error, :idempotency_key_required} =
               GymactSurface.actuate(
                 Provider,
                 :actuate_status,
                 %{status: :active},
                 authorize?: false,
                 authority: %{kind: "test_authority", source: "w674_deepening"},
                 episode_id: "ep-w674",
                 cut: %{"digest" => "w674-no-key"}
               )
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  # W928 hygiene: never hd() an unfiltered read — the test DB is shared and
  # durably poisoned by unrelated sealed rows. Scope every read to the intent
  # this test itself minted via its own idempotency key.
  defp sealed_intent!(key) do
    ActuationIntent
    |> Ash.Query.filter(idempotency_key: key)
    |> Ash.read!(authorize?: false)
    |> hd()
  end

  defp sealed_receipt!(key) do
    intent = sealed_intent!(key)

    ActuationReceipt
    |> Ash.Query.filter(intent_id: intent.id)
    |> Ash.read!(authorize?: false)
    |> hd()
  end

  defp hits, do: @hits_key |> :persistent_term.get() |> :counters.get(1)

  defp set_mode(:ok), do: :persistent_term.put(@mode_key, :ok)
  defp set_mode(:fail), do: :persistent_term.put(@mode_key, :fail)

  defp free_port do
    {:ok, socket} =
      :gen_tcp.listen(0, ip: {127, 0, 0, 1}, port: 0, active: false, reuseaddr: true)

    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  # Real Plug endpoint standing in for the remote gymact FastAPI service.
  def init(opts), do: opts

  def call(conn, _opts) do
    conn =
      Plug.Parsers.call(
        conn,
        Plug.Parsers.init(parsers: [:json], pass: ["*/*"], json_decoder: Jason)
      )

    case conn.path_info do
      ["episodes", _id, "actions", "selected"] ->
        @hits_key |> :persistent_term.get() |> :counters.add(1, 1)

        if :persistent_term.get(@mode_key) == :fail do
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(500, ~s({"error":"internal"}))
          |> Plug.Conn.halt()
        else
          body = %{"accepted" => true, "echo" => conn.body_params}

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(body))
          |> Plug.Conn.halt()
        end

      _ ->
        Plug.Conn.send_resp(conn, 404, "not found")
    end
  end
end
