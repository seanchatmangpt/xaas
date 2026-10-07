defmodule Xaas.Operations.GymactSurfaceTest do
  @moduledoc """
  Chicago-style court for the xaas -> gymact bridge (`Xaas.Operations.GymactSurface`).

  The real gymact FastAPI surface runs as a real uvicorn subprocess from the
  canonical checkout `/Users/sac/gymact` (real collaborator, no mocks). If
  the pinned venv is absent, the refusal-path court still runs and the
  real-HTTP court is skipped with a visible documented skip.
  """

  use ExUnit.Case, async: false

  alias Xaas.Operations.GymactSurface

  # Refusal tests below delete the VM-global INTERNAL_API_TOKEN System env
  # and do not restore it per-test. This module is async:false (runs
  # exclusively), so restoring once after the module is sufficient — without
  # this, every later module's System.fetch_env!("INTERNAL_API_TOKEN")
  # crashes (W280 / W158 async-env-isolation).
  setup_all do
    previous = System.get_env("INTERNAL_API_TOKEN")

    on_exit(fn ->
      if previous,
        do: System.put_env("INTERNAL_API_TOKEN", previous),
        else: System.delete_env("INTERNAL_API_TOKEN")
    end)

    :ok
  end

  @venv_uvicorn Path.expand("~/gymact/.venv/bin/uvicorn")
  @venv_src Path.expand("~/gymact/src")
  @tag_token "gymact-surface-test-token"

  setup context do
    # Refusal tests manage their own env; the HTTP tests need the server.
    if context[:http] do
      unless File.regular?(@venv_uvicorn) do
        IO.puts("""
        [gymact_surface_test] skipping real-HTTP court: #{@venv_uvicorn} missing. \
        Mint it with `cd /Users/sac/gymact && uv sync`; refusal paths still ran.\
        """)
      end

      port = free_port()

      on_exit(fn ->
        Application.delete_env(:xaas, :gymact_surface)
        System.delete_env("INTERNAL_API_TOKEN")
      end)

      venv_present? = File.regular?(@venv_uvicorn)

      if venv_present? do
        start_uvicorn(port)

        # The port wrapper gives no reliable os pid; kill by the unique port
        # number this test minted (free_port race window is acceptable).
        on_exit(fn ->
          System.cmd("pkill", ["-f", Integer.to_string(port)])
          Application.delete_env(:xaas, :gymact_surface)
          System.delete_env("INTERNAL_API_TOKEN")
        end)

        case wait_for_health(port, 90) do
          :ok ->
            Application.put_env(:xaas, :gymact_surface,
              base_url: "http://127.0.0.1:#{port}",
              token: @tag_token
            )

            :ok

          :error ->
            {:error, "uvicorn did not come healthy on port #{port}"}
        end
      else
        {:skip, :venv_missing}
      end
    else
      Application.delete_env(:xaas, :gymact_surface)
      :ok
    end
  end

  # ------------------------------------------------------------------
  # Refusal paths
  # ------------------------------------------------------------------

  describe "fail-closed config gate" do
    test "unconfigured app env yields typed GYMACT_NOT_CONFIGURED refusal" do
      System.delete_env("INTERNAL_API_TOKEN")

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured} = refusal} =
               GymactSurface.config()

      assert %Xaas.Actuation.Refusal{} = refusal

      # Same typed code on every gated entry point (fresh refusal instances
      # are compared by code, not struct identity — Splode captures a live
      # stacktrace per instance).
      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.health()

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.providers()

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.prepare_candidate(%{})

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.open_episode(%{})

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.submit_action("e1", %{})

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.verify("e1", %{})
    end

    @tag http: false
    test "base_url without any token (config or env) is refused" do
      System.delete_env("INTERNAL_API_TOKEN")
      Application.put_env(:xaas, :gymact_surface, base_url: "http://127.0.0.1:1")

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.config()
    end

    test "actuate/4 refuses typed before any ledger transition" do
      System.delete_env("INTERNAL_API_TOKEN")

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.actuate(Xaas.Operations.Incident, :create, %{"title" => "x"},
                 idempotency_key: "k1"
               )
    end

    test "actuate_local/4 refuses typed before Xaas.Actuation.run/4" do
      System.delete_env("INTERNAL_API_TOKEN")

      assert {:error, %Xaas.Actuation.Refusal{code: :gymact_not_configured}} =
               GymactSurface.actuate_local(Xaas.Operations.Incident, :create, %{"title" => "x"},
                 idempotency_key: "k2"
               )
    end
  end

  # ------------------------------------------------------------------
  # Real HTTP court against the real uvicorn subprocess
  # ------------------------------------------------------------------

  describe "real gymact FastAPI surface" do
    @tag :http
    @tag http: true
    test "health reads status ALIVE and a contract digest over real HTTP" do
      assert {:ok, %{"status" => "ALIVE", "version" => version, "contract_digest" => digest}} =
               GymactSurface.health()

      assert is_binary(version) and version != ""
      assert is_binary(digest) and digest != ""
    end

    @tag :http
    @tag http: true
    test "providers read lists the registered memory provider" do
      assert {:ok, %{"providers" => names}} = GymactSurface.providers()
      assert "memory" in names
    end

    @tag :http
    @tag http: true
    test "candidates normalizes a REST envelope to a semantic key" do
      payload = %{
        "episode_id" => "ep-test",
        "action_ref" => "urn:gymact:capability:test",
        "subject" => %{"semantic_id" => "urn:example:subject:1", "provider_ref" => "memory"},
        "payload" => %{},
        "admission_digest" => "sha256:" <> String.duplicate("0", 64),
        "idempotency_key" => "gymact-surface-test-candidate"
      }

      assert {:ok, %{"semantic_key" => key, "prepared" => prepared}} =
               GymactSurface.prepare_candidate(payload)

      assert is_binary(key) and key != ""
      assert prepared["idempotency_key"] == "gymact-surface-test-candidate"
    end

    @tag :http
    @tag http: true
    test "open_episode materializes a real memory episode" do
      params = %{
        "provider" => "memory",
        "config" => %{"initial" => %{"lamp" => "off"}, "requires_authority" => false}
      }

      assert {:ok,
              %{
                "accepted" => true,
                "standing" => "ALIVE",
                "episode" => %{"episode_id" => episode_id, "provider" => "memory"}
              }} =
               GymactSurface.open_episode(params)

      assert is_binary(episode_id) and episode_id != ""
    end

    @tag :http
    @tag http: true
    test "capabilities read for a real episode" do
      assert {:ok, episode} =
               GymactSurface.open_episode(%{
                 "provider" => "memory",
                 "config" => %{"initial" => %{"lamp" => "off"}, "requires_authority" => false}
               })

      episode_id = episode["episode"]["episode_id"]

      assert {:ok, %{"capabilities" => caps}} = GymactSurface.capabilities(episode_id)
      assert is_list(caps)

      assert {:ok, verdict} = GymactSurface.verify(episode_id, %{"lamp" => "off"})
      assert verdict["passed"] == true
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp free_port do
    {:ok, socket} =
      :gen_tcp.listen(0, ip: {127, 0, 0, 1}, port: 0, active: false, reuseaddr: true)

    {:ok, port} = :inet.port(socket)
    :gen_tcp.close(socket)
    port
  end

  defp start_uvicorn(port) do
    _port_ref =
      Port.open(
        {:spawn_executable, @venv_uvicorn},
        [
          :binary,
          :exit_status,
          args: [
            "--factory",
            "gymact.surfaces.fastapi:create_app",
            "--host",
            "127.0.0.1",
            "--port",
            Integer.to_string(port)
          ],
          env: [{~c"PYTHONPATH", String.to_charlist(@venv_src)}]
        ]
      )

    :ok
  end

  defp wait_for_health(port, attempts) do
    url = "http://127.0.0.1:#{port}/health"

    case Req.get(url,
           retry: false,
           receive_timeout: 1_500,
           connect_options: [timeout: 1_000]
         ) do
      {:ok, %Req.Response{status: 200}} ->
        :ok

      _ when attempts <= 1 ->
        :error

      _ ->
        Process.sleep(250)
        wait_for_health(port, attempts - 1)
    end
  end
end
