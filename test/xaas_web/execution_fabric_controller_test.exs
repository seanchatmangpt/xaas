defmodule XaasWeb.ExecutionFabricControllerTest do
  @moduledoc """
  Real Chicago-style test for the execution-fabric HTTP surface
  (lib/xaas_web/controllers/execution_fabric_controller.ex, mounted under
  /internal-api/execution in XaasWeb.Router behind
  RequireInternalApiToken). Real ConnCase HTTP requests, real sandboxed
  Postgres rows (Xaas.Ultracode Run/Epoch/Receipt via real Ash actions),
  real git worktrees for head verification — asserting the decoded JSON
  responses over the wire, not the controller functions in isolation.

  Proves the load-bearing transport invariants:

    * fail-closed gate: unset token => 503, wrong bearer => 401;
    * hook surface: session_start acknowledged, pre_tool_use refusal is a
      typed 403 deny, unknown events 404, stop without a lease is
      not_closeable (never silent closure);
    * MCP JSON-RPC surface: initialize/tools list, and the full
      provider-pull loop over real rows — claim_next returns the lease
      token + work payload, admit_tool allows construction / refuses
      consequence, close_candidate seals a head-verified Receipt with the
      exact reported outcome, and refuse lands a typed refusal receipt.
  """

  use XaasWeb.ConnCase

  require Ash.Query

  alias Xaas.Accounts.Org
  alias Xaas.Governance.InternalApiTokenAuth
  alias Xaas.Ultracode.{Epoch, Run}

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    :ok
  end

  defp with_internal_api_token(conn) do
    put_req_header(conn, "authorization", "Bearer " <> System.fetch_env!("INTERNAL_API_TOKEN"))
  end

  defp create_org!(slug) do
    {:ok, org} =
      Org
      |> Ash.Changeset.for_create(:create, %{name: slug, slug: slug}, authorize?: false)
      |> Ash.create()

    org
  end

  defp org_token!(created_by, %Org{} = org) do
    {:ok, raw_token, _token} = InternalApiTokenAuth.issue(created_by, nil, org)
    raw_token
  end

  defp with_org_token(conn, raw_token) do
    put_req_header(conn, "authorization", "Bearer " <> raw_token)
  end

  defp hook_post(conn, event, body) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/internal-api/execution/hooks/#{event}", Jason.encode!(body))
  end

  defp mcp_post(conn, body) do
    conn
    |> with_internal_api_token()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post("/internal-api/execution/mcp", Jason.encode!(body))
  end

  defp mcp_result(conn, id, method, params \\ %{}) do
    conn
    |> mcp_post(%{jsonrpc: "2.0", id: id, method: method, params: params})
    |> json_response(200)
    |> Map.fetch!("result")
  end

  defp tool_call(conn, name, arguments) do
    conn
    |> mcp_result(1, "tools/call", %{"name" => name, "arguments" => arguments})
    |> Map.fetch!("content")
    |> List.first()
    |> Map.fetch!("text")
    |> Jason.decode!()
  end

  defp provider_run_and_epoch(provider, worktree \\ nil, verifier_suite \\ nil) do
    {:ok, run} =
      Run
      |> Ash.Changeset.for_create(
        :create,
        %{goal: "Chicago qualification over real HTTP.", provider: provider}
        |> then(&if(verifier_suite, do: Map.put(&1, :verifier_suite, verifier_suite), else: &1)),
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
          exact_subject: "XaasWeb.ExecutionFabricControllerTest",
          state: :running,
          worktree: worktree
        },
        authorize?: false
      )
      |> Ash.create()

    {run, epoch}
  end

  # The real fabric court, end to end: a registered verifier suite plus a
  # containment root, with the worktree created INSIDE the root (the
  # verifier refuses worktrees outside it). Restores both env keys on exit.
  defp with_court(suite_name, fun) do
    original_root = Application.get_env(:xaas, :ultracode_worktree_root)
    original_suites = Application.get_env(:xaas, :ultracode_verifier_suites)

    # run_uid convention (wave-8 flake hunt): System.unique_integer() is only
    # per-VM unique; $TMPDIR is shared by every concurrent `mix test` VM, so
    # qualify with wall clock too -- cross-VM collision becomes impossible.
    root =
      Path.join(
        System.tmp_dir(),
        "xaas-fabric-court-#{System.system_time(:millisecond)}-#{System.unique_integer()}"
      )

    File.mkdir_p!(root)

    Application.put_env(:xaas, :ultracode_worktree_root, root)

    Application.put_env(:xaas, :ultracode_verifier_suites, %{
      suite_name => %{
        env: %{"PATH" => "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin"},
        steps: [%{id: "ok", argv: ["/bin/sh", "-c", "true"], timeout_ms: 10_000}]
      }
    })

    on_exit(fn ->
      File.rm_rf!(root)

      if is_nil(original_root),
        do: Application.delete_env(:xaas, :ultracode_worktree_root),
        else: Application.put_env(:xaas, :ultracode_worktree_root, original_root)

      if is_nil(original_suites),
        do: Application.delete_env(:xaas, :ultracode_verifier_suites),
        else: Application.put_env(:xaas, :ultracode_verifier_suites, original_suites)
    end)

    worktree = Path.join(root, "wt-#{System.unique_integer()}")
    File.mkdir_p!(worktree)

    {_, 0} = System.cmd("git", ["-C", worktree, "init", "--quiet"])

    {_, 0} =
      System.cmd("git", ["-C", worktree, "commit", "--allow-empty", "-m", "init", "--quiet"],
        env: [
          {"GIT_AUTHOR_NAME", "test"},
          {"GIT_AUTHOR_EMAIL", "test@test"},
          {"GIT_COMMITTER_NAME", "test"},
          {"GIT_COMMITTER_EMAIL", "test@test"}
        ]
      )

    fun.(root, worktree)
  end

  describe "fail-closed token gate" do
    test "unset INTERNAL_API_TOKEN rejects every request with 503", %{conn: conn} do
      previous = System.fetch_env!("INTERNAL_API_TOKEN")
      System.delete_env("INTERNAL_API_TOKEN")

      try do
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/internal-api/execution/hooks/session_start", "{}")
        |> json_response(503)
      after
        System.put_env("INTERNAL_API_TOKEN", previous)
      end
    end

    test "wrong bearer is 401", %{conn: conn} do
      conn
      |> put_req_header("authorization", "Bearer not-the-token")
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/execution/hooks/session_start", "{}")
      |> json_response(401)
    end

    test "an active, rotated InternalApiToken is accepted (real rotation path, not just the env var)",
         %{conn: conn} do
      {:ok, raw_token, _token} = Xaas.Governance.InternalApiTokenAuth.issue("rotation-test")

      body =
        conn
        |> put_req_header("authorization", "Bearer " <> raw_token)
        |> put_req_header("content-type", "application/json")
        |> post("/internal-api/execution/hooks/session_start", "{}")
        |> json_response(200)

      assert body["status"] == "acknowledged"
    end

    test "a revoked InternalApiToken is rejected with the same fail-closed 401 as a wrong bearer",
         %{conn: conn} do
      {:ok, raw_token, token} = Xaas.Governance.InternalApiTokenAuth.issue("revoke-test")
      {:ok, _revoked} = Xaas.Governance.InternalApiTokenAuth.revoke(token)

      # Real state check: the row really is revoked, not just assumed.
      reloaded = Ash.get!(Xaas.Governance.InternalApiToken, token.id, authorize?: false)
      assert reloaded.revoked_at

      conn
      |> put_req_header("authorization", "Bearer " <> raw_token)
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/execution/hooks/session_start", "{}")
      |> json_response(401)
    end

    test "an expired InternalApiToken is rejected with the same fail-closed 401 as a wrong bearer",
         %{conn: conn} do
      already_expired = DateTime.add(DateTime.utc_now(), -60, :second)

      {:ok, raw_token, token} =
        Xaas.Governance.InternalApiTokenAuth.issue("expiry-test", already_expired)

      # Real state check: the row really is persisted as expired, not just assumed.
      reloaded = Ash.get!(Xaas.Governance.InternalApiToken, token.id, authorize?: false)
      assert DateTime.compare(reloaded.expires_at, DateTime.utc_now()) == :lt

      conn
      |> put_req_header("authorization", "Bearer " <> raw_token)
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/execution/hooks/session_start", "{}")
      |> json_response(401)
    end
  end

  describe "hook surface" do
    test "session_start is acknowledged", %{conn: conn} do
      body =
        conn
        |> hook_post("session_start", %{session_id: "sess-1", cwd: "/tmp/wt"})
        |> json_response(200)

      assert body["status"] == "acknowledged"
    end

    test "pre_tool_use without a lease is a typed 403 deny", %{conn: conn} do
      body =
        conn
        |> hook_post("pre_tool_use", %{tool: "Edit", cwd: "/tmp/wt"})
        |> json_response(403)

      assert body["decision"] == "deny"
      assert is_binary(body["reason"])
    end

    test "stop without a lease is not_closeable, never closure", %{conn: conn} do
      body =
        conn
        |> hook_post("stop", %{final_head: "abc123", standing: "ALIVE"})
        |> json_response(200)

      assert body["status"] == "not_closeable"
    end

    test "unknown hook event is 404", %{conn: conn} do
      conn
      |> hook_post("time_travel", %{})
      |> json_response(404)
    end
  end

  describe "MCP JSON-RPC surface" do
    test "initialize advertises the lease server", %{conn: conn} do
      result = conn |> mcp_result(1, "initialize")
      assert result["serverInfo"]["name"] == "xaas-ultracode-lease"
      assert result["capabilities"]["tools"]
    end

    test "tools/list exposes exactly the fabric tools", %{conn: conn} do
      tools = conn |> mcp_result(2, "tools/list") |> Map.fetch!("tools")

      assert Enum.map(tools, & &1["name"]) |> Enum.sort() == [
               "actuate",
               "admit_tool",
               "claim_next",
               "close_candidate",
               "heartbeat",
               "record_provider_event",
               "refuse"
             ]
    end

    test "claim_next with an epoch_id binds that epoch; a malformed epoch_id is a typed refusal, not oldest-first",
         %{conn: conn} do
      provider = "zcode-directed-http-#{System.unique_integer([:positive])}"
      {_run_a, older} = provider_run_and_epoch(provider, nil)
      {_run_b, younger} = provider_run_and_epoch(provider, nil)

      assert %{"error" => error} =
               tool_call(conn, "claim_next", %{provider: provider, epoch_id: "not-a-uuid"})

      assert error =~ "invalid_epoch_id"

      claim =
        tool_call(conn, "claim_next", %{
          provider: provider,
          provider_worker_id: "w-directed",
          epoch_id: younger.id
        })

      assert claim["epoch_id"] == younger.id

      free = Ash.get!(Epoch, older.id, action: :read_unscoped, authorize?: false)
      assert is_nil(free.lease_token)
    end

    test "claim_next with no ready work is a typed tool error, not silence", %{conn: conn} do
      assert tool_call(conn, "claim_next", %{provider: "zcode-chicago"}) ==
               %{"error" => ":no_ready_work"}
    end
  end

  describe "full provider-pull loop over real rows" do
    test "claim -> admit -> court-passed close seals an alive Receipt (alive is court-manufactured only)",
         %{conn: conn} do
      with_court("fabric-court-pass", fn _root, worktree ->
        provider = "zcode-chicago-court-#{System.unique_integer([:positive])}"
        {run, epoch} = provider_run_and_epoch(provider, worktree, "fabric-court-pass")

        claim =
          tool_call(conn, "claim_next", %{provider: provider, provider_worker_id: "worker-1"})

        assert claim["lease_token"]
        assert claim["epoch_id"] == epoch.id
        assert claim["exact_subject"] == epoch.exact_subject
        assert claim["goal"] == run.goal
        assert claim["worktree"] == worktree

        # Admission court over the wire.
        assert tool_call(conn, "admit_tool", %{
                 lease_token: claim["lease_token"],
                 tool: "Edit"
               }) == %{"decision" => "allow"}

        assert tool_call(conn, "admit_tool", %{
                 lease_token: claim["lease_token"],
                 tool: "git_push"
               }) == %{"error" => "refused_no_authority:\"git_push\""}

        # Head-verified closure THROUGH THE REAL VERIFIER COURT over the wire.
        closed =
          tool_call(conn, "close_candidate", %{
            lease_token: claim["lease_token"],
            final_head: git_head(worktree),
            outcome: "alive",
            evidence: %{"verifier" => "mix test"}
          })

        assert closed["status"] == "closed"
        assert closed["outcome"] == "alive"

        # The DB row really landed: epoch completed, receipt sealed.
        reloaded = Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false)
        assert reloaded.state == :completed
        assert reloaded.final_head == git_head(worktree)
      end)
    end

    test "an ALIVE claim with NO registered verifier suite is honestly downgraded to partial_alive over the wire",
         %{conn: conn} do
      # No court configured for this run: head verification passes but no
      # verifier suite exists, so the receipt law refuses `:alive` and
      # `Lease.close/4` lands the honest downgrade.
      worktree = make_git_worktree()

      {run, epoch} =
        provider_run_and_epoch(
          "zcode-chicago-nocourt-#{System.unique_integer([:positive])}",
          worktree
        )

      claim =
        tool_call(conn, "claim_next", %{
          provider: run.provider,
          provider_worker_id: "worker-nc"
        })

      closed =
        tool_call(conn, "close_candidate", %{
          lease_token: claim["lease_token"],
          final_head: git_head(worktree),
          outcome: "alive",
          evidence: %{"verifier" => "mix test"}
        })

      assert closed["status"] == "closed"
      assert closed["outcome"] == "partial_alive"

      assert Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false).state ==
               :completed
    end

    test "standing reported in natural casing ('ALIVE') is not silently downgraded", %{
      conn: conn
    } do
      with_court("fabric-court-casing", fn _root, worktree ->
        provider = "zcode-chicago-casing-#{System.unique_integer([:positive])}"
        {_run, epoch} = provider_run_and_epoch(provider, worktree, "fabric-court-casing")

        claim =
          tool_call(conn, "claim_next", %{provider: provider, provider_worker_id: "worker-3"})

        # Live regression guard: the stop hook and worker command report
        # "ALIVE" in natural casing; the transport must normalize, never
        # silently downgrade an honest ALIVE before the court sees it.
        closed =
          tool_call(conn, "close_candidate", %{
            lease_token: claim["lease_token"],
            final_head: git_head(worktree),
            outcome: "ALIVE"
          })

        assert closed["outcome"] == "alive"

        assert Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false).state ==
                 :completed
      end)
    end

    test "an outcome outside the valid vocabulary (e.g. 'UNKNOWN') is silently normalized to partial_alive, not fenced or rejected",
         %{conn: conn} do
      worktree = make_git_worktree()
      {_run, epoch} = provider_run_and_epoch("zcode-chicago", worktree)

      claim =
        tool_call(conn, "claim_next", %{provider: "zcode-chicago", provider_worker_id: "worker-4"})

      # Doctrine regression guard: agents/xaas-worker.md.eex and
      # skills/xaas-worker/SKILL.md.eex's "Standing vocabulary" lists
      # `UNKNOWN` alongside ALIVE/PARTIAL_ALIVE/BLOCKED/BUILD_BROKEN/
      # UNSUPPORTED/REFUSED_*, and commands/xaas.md.eex's own invariants say
      # "Unknown is a fence... stop and report, never guess" -- but
      # close_candidate's outcome vocabulary (@valid_outcomes) has no
      # `unknown` member, so this is NOT actually fenced: it degrades
      # silently to partial_alive, same as any other unrecognized string.
      # This test locks in that real, documented (post-fix) behavior.
      closed =
        tool_call(conn, "close_candidate", %{
          lease_token: claim["lease_token"],
          final_head: git_head(worktree),
          outcome: "UNKNOWN"
        })

      assert closed["status"] == "closed"
      assert closed["outcome"] == "partial_alive"

      assert Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false).state ==
               :completed
    end

    test "refuse always seals the receipt's outcome as the generic 'refused' -- a typed reason (e.g. BLOCKED, BUILD_BROKEN) is preserved only in evidence, never as outcome",
         %{conn: conn} do
      {_run, epoch} = provider_run_and_epoch("zcode-chicago-refuse-outcome")

      claim =
        tool_call(conn, "claim_next", %{
          provider: "zcode-chicago-refuse-outcome",
          provider_worker_id: "worker-5"
        })

      # Doctrine regression guard: commands/xaas.md.eex step 6 lists
      # `refuse` reasons as if they were distinctly-recorded standings
      # (`BLOCKED`, `BUILD_BROKEN`, `REFUSED_NO_AUTHORITY`, ...), but
      # Lease.refuse/3 always seals `outcome: :refused` regardless of the
      # reason passed -- the finer distinction survives only as a string in
      # evidence.refusal_reason. A worker that needs BLOCKED/BUILD_BROKEN to
      # stay queryable as `outcome` must call close_candidate directly with
      # that outcome instead.
      refused =
        tool_call(conn, "refuse", %{lease_token: claim["lease_token"], reason: "blocked"})

      assert refused["status"] == "refused"
      assert refused["outcome"] == "refused"

      receipt =
        Xaas.Ultracode.Receipt
        |> Ash.read!(authorize?: false)
        |> Enum.find(&(&1.epoch_id == epoch.id))

      assert receipt.outcome == :refused
      assert receipt.evidence["refusal_reason"] == "blocked"
    end

    test "refuse lands a typed refusal receipt", %{conn: conn} do
      {_run, epoch} = provider_run_and_epoch("zcode-chicago")

      claim =
        tool_call(conn, "claim_next", %{provider: "zcode-chicago", provider_worker_id: "worker-2"})

      refused =
        tool_call(conn, "refuse", %{lease_token: claim["lease_token"], reason: "blocked"})

      assert refused["status"] == "refused"
      assert refused["outcome"] == "refused"
      assert Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false).state == :failed
    end

    test "refuse with an arbitrary attacker-chosen reason string never crashes or interns a new atom",
         %{conn: conn} do
      {_run, epoch} = provider_run_and_epoch("zcode-chicago-atom-safety")

      claim =
        tool_call(conn, "claim_next", %{
          provider: "zcode-chicago-atom-safety",
          provider_worker_id: "worker-3"
        })

      # A reason string guaranteed to never already exist as a BEAM atom.
      # String.to_atom/1 on attacker-controlled input is an atom-table
      # exhaustion DoS (atoms are never garbage collected); the controller
      # must fall back to a bounded, already-existing atom instead of
      # interning this one.
      novel_reason =
        "attacker_reason_#{System.unique_integer([:positive])}_#{:erlang.monotonic_time()}"

      assert_raise ArgumentError, fn ->
        novel_reason |> String.to_charlist() |> :erlang.list_to_existing_atom()
      end

      refused =
        tool_call(conn, "refuse", %{lease_token: claim["lease_token"], reason: novel_reason})

      assert refused["status"] == "refused"
      assert refused["outcome"] == "refused"
      assert Ash.get!(Epoch, epoch.id, action: :read_unscoped, authorize?: false).state == :failed

      # The unresolvable reason must not have been silently dropped either:
      # it lands as a real, inspectable string in the sealed receipt's
      # evidence (the fallback substitutes a bounded atom, not empty data).
      receipt =
        Xaas.Ultracode.Receipt
        |> Ash.read!(authorize?: false)
        |> Enum.find(&(&1.epoch_id == epoch.id))

      assert receipt.evidence["refusal_reason"] == "unknown"

      assert_raise ArgumentError, fn ->
        novel_reason |> String.to_charlist() |> :erlang.list_to_existing_atom()
      end
    end
  end

  describe "actuate tool (ZCode-UI-as-actuator seam) over real HTTP" do
    defp with_actuation_registry(registry, fun) do
      previous = Application.get_env(:xaas, :ultracode_actuation_registry)
      Application.put_env(:xaas, :ultracode_actuation_registry, registry)

      try do
        fun.()
      after
        if previous do
          Application.put_env(:xaas, :ultracode_actuation_registry, previous)
        else
          Application.delete_env(:xaas, :ultracode_actuation_registry)
        end
      end
    end

    test "a registered pair reaches the real Xaas.Actuation.run/4 DO kernel over the wire", %{
      conn: conn
    } do
      provider = "zcode-chicago-actuate-#{System.unique_integer([:positive])}"
      marketplace_provider = Xaas.Generator.create_provider!(%{org_id: "org-actuate-http"})

      with_actuation_registry(
        %{
          provider => %{
            {"Xaas.Marketplace.Provider", "actuate_status"} =>
              {Xaas.Marketplace.Provider, :actuate_status, marketplace_provider.id}
          }
        },
        fn ->
          {_run, _epoch} = provider_run_and_epoch(provider)

          claim =
            tool_call(conn, "claim_next", %{provider: provider, provider_worker_id: "worker-1"})

          result =
            tool_call(conn, "actuate", %{
              lease_token: claim["lease_token"],
              resource: "Xaas.Marketplace.Provider",
              action: "actuate_status",
              input: %{"status" => "active"},
              idempotency_key: "http-actuate-#{System.unique_integer([:positive])}"
            })

          assert result["status"] == "succeeded"
          assert result["replay"] == false
          assert result["receipt_id"]

          assert Xaas.Marketplace.Provider
                 |> Ash.get!(marketplace_provider.id, authorize?: false)
                 |> Map.fetch!(:status) == :active

          # actuate grants no admit_tool allowance on the same lease.
          assert tool_call(conn, "admit_tool", %{lease_token: claim["lease_token"], tool: "Bash"}) ==
                   %{"error" => "refused_no_authority:\"Bash\""}
        end
      )
    end

    test "a wire-supplied subject_id cannot redirect the actuation onto an unrelated row", %{
      conn: conn
    } do
      provider = "zcode-chicago-actuate-idor-#{System.unique_integer([:positive])}"
      bound_provider = Xaas.Generator.create_provider!(%{org_id: "org-actuate-http-bound"})
      other_provider = Xaas.Generator.create_provider!(%{org_id: "org-actuate-http-other"})

      with_actuation_registry(
        %{
          provider => %{
            {"Xaas.Marketplace.Provider", "actuate_status"} =>
              {Xaas.Marketplace.Provider, :actuate_status, bound_provider.id}
          }
        },
        fn ->
          {_run, _epoch} = provider_run_and_epoch(provider)

          claim =
            tool_call(conn, "claim_next", %{provider: provider, provider_worker_id: "worker-1"})

          # The wire protocol has no subject_id field on "actuate" -- an
          # attacker-style client sending one anyway must have it ignored.
          result =
            tool_call(conn, "actuate", %{
              lease_token: claim["lease_token"],
              resource: "Xaas.Marketplace.Provider",
              action: "actuate_status",
              subject_id: other_provider.id,
              input: %{"status" => "active"},
              idempotency_key: "http-actuate-idor-#{System.unique_integer([:positive])}"
            })

          assert result["status"] == "succeeded"

          assert Xaas.Marketplace.Provider
                 |> Ash.get!(bound_provider.id, authorize?: false)
                 |> Map.fetch!(:status) == :active

          assert Xaas.Marketplace.Provider
                 |> Ash.get!(other_provider.id, authorize?: false)
                 |> Map.fetch!(:status) != :active
        end
      )
    end

    test "an unregistered pair is a typed tool error, never a silent DO", %{conn: conn} do
      provider = "zcode-chicago-actuate-unregistered-#{System.unique_integer([:positive])}"
      {_run, _epoch} = provider_run_and_epoch(provider)

      claim =
        tool_call(conn, "claim_next", %{provider: provider, provider_worker_id: "worker-1"})

      assert tool_call(conn, "actuate", %{
               lease_token: claim["lease_token"],
               resource: "Xaas.Marketplace.Provider",
               action: "actuate_status",
               idempotency_key: "http-actuate-unregistered"
             }) == %{
               "error" =>
                 "unregistered_actuation:{\"Xaas.Marketplace.Provider\", \"actuate_status\"}"
             }
    end

    test "a non-string lease_token is a typed tool error, never a crash", %{conn: conn} do
      assert tool_call(conn, "actuate", %{
               lease_token: 123,
               resource: "Xaas.Marketplace.Provider",
               action: "actuate_status",
               idempotency_key: "http-actuate-bad-token-type"
             }) == %{"error" => ":lease_token_required"}
    end
  end

  describe "receipt read surface (real lawful read path)" do
    test "GET .../receipts returns the real sealed receipt through the lawful HTTP path", %{
      conn: conn
    } do
      worktree = make_git_worktree()
      {_run, epoch} = provider_run_and_epoch("zcode-chicago-receipts", worktree)

      claim =
        tool_call(conn, "claim_next", %{
          provider: "zcode-chicago-receipts",
          provider_worker_id: "worker-1"
        })

      tool_call(conn, "close_candidate", %{
        lease_token: claim["lease_token"],
        final_head: git_head(worktree),
        outcome: "alive",
        evidence: %{"verifier" => "mix test"}
      })

      body =
        conn
        |> with_internal_api_token()
        |> get("/internal-api/execution/epochs/#{epoch.id}/receipts")
        |> json_response(200)

      assert body["epoch_id"] == epoch.id
      assert [receipt] = body["receipts"]
      # No verifier suite is registered for this run, so the receipt law
      # (alive is court-manufactured only) seals the honest downgrade.
      assert receipt["outcome"] == "partial_alive"
      assert receipt["epoch_id"] == epoch.id
      assert receipt["evidence"]["verifier"] == "mix test"
    end

    test "is scoped: a different epoch's receipts are never returned", %{conn: conn} do
      {_run_a, epoch_a} = provider_run_and_epoch("zcode-chicago-receipts-a")
      {_run_b, epoch_b} = provider_run_and_epoch("zcode-chicago-receipts-b")

      claim_a =
        tool_call(conn, "claim_next", %{
          provider: "zcode-chicago-receipts-a",
          provider_worker_id: "worker-a"
        })

      assert claim_a["epoch_id"] == epoch_a.id

      tool_call(conn, "refuse", %{lease_token: claim_a["lease_token"], reason: "blocked"})

      body =
        conn
        |> with_internal_api_token()
        |> get("/internal-api/execution/epochs/#{epoch_b.id}/receipts")
        |> json_response(200)

      assert body["epoch_id"] == epoch_b.id
      assert body["receipts"] == []
    end

    test "fails closed: missing bearer token is 401, never the real receipt", %{conn: conn} do
      {_run, epoch} = provider_run_and_epoch("zcode-chicago-receipts-noauth")

      conn
      |> get("/internal-api/execution/epochs/#{epoch.id}/receipts")
      |> json_response(401)
    end

    test "fails closed: wrong bearer token is 401, never the real receipt", %{conn: conn} do
      {_run, epoch} = provider_run_and_epoch("zcode-chicago-receipts-wrongauth")

      conn
      |> put_req_header("authorization", "Bearer not-the-token")
      |> get("/internal-api/execution/epochs/#{epoch.id}/receipts")
      |> json_response(401)
    end

    test "fails closed: a syntactically invalid epoch id is a real 400, never all receipts", %{
      conn: conn
    } do
      body =
        conn
        |> with_internal_api_token()
        |> get("/internal-api/execution/epochs/not-a-real-uuid/receipts")
        |> json_response(400)

      assert body["error"] == "invalid_epoch_id"
    end
  end

  describe "org-scoped customer submission surface (real per-org InternalApiToken)" do
    test "org A's token can POST .../runs and the created Run's real org_id matches org A",
         %{conn: conn} do
      org_a = create_org!("acme-test-org-a")
      token_a = org_token!("acme-token-a", org_a)
      # Real git worktree (2026-09 fs-safety hardening pass): the
      # controller now real-validates `worktree` server-side (see
      # `Xaas.Ultracode.Validations.WorktreeIsSafe`) -- a bare non-git
      # tmp path like the old `/tmp/wt-org-a` no longer clears the
      # create-run path, matching the same real behavior a production
      # submission now gets.
      worktree = make_git_worktree()

      body =
        conn
        |> with_org_token(token_a)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{
            goal: "Chicago org-scoped submission over real HTTP.",
            worktree: worktree,
            provider: "zcode-org-a-submit"
          })
        )
        |> json_response(201)

      assert body["run_id"]
      assert body["epoch_id"]

      # Real state check: read the created rows back from the DB, don't
      # trust the response body alone.
      reloaded_run = Ash.get!(Run, body["run_id"], action: :read_unscoped, authorize?: false)
      assert reloaded_run.org_id == org_a.id
      assert reloaded_run.provider == "zcode-org-a-submit"
      assert reloaded_run.goal == "Chicago org-scoped submission over real HTTP."

      reloaded_epoch =
        Ash.get!(Epoch, body["epoch_id"], action: :read_unscoped, authorize?: false)

      assert reloaded_epoch.run_id == reloaded_run.id
      assert reloaded_epoch.cycle == 0
      assert reloaded_epoch.state == :running
      assert reloaded_epoch.worktree == worktree
    end

    test "an org-less submission defaults provider to zcode and generates an exact_subject",
         %{conn: conn} do
      org_a = create_org!("acme-test-org-defaults")
      token_a = org_token!("acme-token-defaults", org_a)

      body =
        conn
        |> with_org_token(token_a)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{goal: "no provider or exact_subject supplied"})
        )
        |> json_response(201)

      reloaded_run = Ash.get!(Run, body["run_id"], action: :read_unscoped, authorize?: false)
      assert reloaded_run.provider == "zcode"

      reloaded_epoch =
        Ash.get!(Epoch, body["epoch_id"], action: :read_unscoped, authorize?: false)

      assert is_binary(reloaded_epoch.exact_subject)
      assert reloaded_epoch.exact_subject != ""
    end

    test "the legacy shared token gets a real typed 403 from POST .../runs -- org-less callers cannot submit",
         %{conn: conn} do
      body =
        conn
        |> with_internal_api_token()
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{goal: "should be refused: no org on this token"})
        )
        |> json_response(403)

      assert body["error"] == "org_scoped_token_required"
    end

    test "an org-less DB-backed InternalApiToken also gets the real typed 403 from POST .../runs",
         %{conn: conn} do
      {:ok, raw_token, _token} = InternalApiTokenAuth.issue("org-less-db-token")

      body =
        conn
        |> with_org_token(raw_token)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{goal: "should be refused: org-less DB token"})
        )
        |> json_response(403)

      assert body["error"] == "org_scoped_token_required"
    end

    test "a request with no Authorization header still gets the existing real fail-closed 401",
         %{conn: conn} do
      conn
      |> put_req_header("content-type", "application/json")
      |> post("/internal-api/execution/runs", Jason.encode!(%{goal: "no auth header"}))
      |> json_response(401)
    end

    test "org A's token hitting GET .../receipts for an epoch under org B's own real run gets a real 404, proven with a receipt that genuinely exists",
         %{conn: conn} do
      org_a = create_org!("acme-test-org-b-scope-a")
      org_b = create_org!("acme-test-org-b-scope-b")
      token_a = org_token!("acme-token-scope-a", org_a)
      token_b = org_token!("acme-token-scope-b", org_b)

      worktree = make_git_worktree()

      # Org B submits its own real Run/Epoch via the real HTTP submission
      # surface (not the test's own provider_run_and_epoch/2 shortcut).
      submit_body =
        conn
        |> with_org_token(token_b)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{
            goal: "org B's real submitted work",
            worktree: worktree,
            provider: "zcode-org-b-scope"
          })
        )
        |> json_response(201)

      epoch_id = submit_body["epoch_id"]

      # Real claim/admit/close cycle over the shared worker-pull path (the
      # worker pool is intentionally NOT org-restricted -- see the
      # controller/router comments -- so this uses the ordinary shared
      # internal token, same as every other worker-loop test in this file)
      # to seal a REAL Receipt for org B's epoch, not an empty list.
      claim =
        tool_call(conn, "claim_next", %{
          provider: "zcode-org-b-scope",
          provider_worker_id: "worker-scope"
        })

      assert claim["epoch_id"] == epoch_id

      closed =
        tool_call(conn, "close_candidate", %{
          lease_token: claim["lease_token"],
          final_head: git_head(worktree),
          outcome: "alive",
          evidence: %{"verifier" => "mix test (org scope)"}
        })

      assert closed["status"] == "closed"

      # Prove the receipt genuinely exists via the admin/legacy read path.
      admin_receipts =
        conn
        |> with_internal_api_token()
        |> get("/internal-api/execution/epochs/#{epoch_id}/receipts")
        |> json_response(200)

      assert [admin_receipt] = admin_receipts["receipts"]
      # Suite-less close: the receipt law seals partial_alive, not alive.
      assert admin_receipt["outcome"] == "partial_alive"

      # Org B's own token CAN read its own epoch's receipt (positive path).
      own_body =
        conn
        |> with_org_token(token_b)
        |> get("/internal-api/execution/epochs/#{epoch_id}/receipts")
        |> json_response(200)

      assert [own_receipt] = own_body["receipts"]
      assert own_receipt["outcome"] == "partial_alive"

      # Org A's own token cannot see it: a real 404, never the empty
      # `receipts: []` false negative the legacy/unscoped path would give.
      not_found_body =
        conn
        |> with_org_token(token_a)
        |> get("/internal-api/execution/epochs/#{epoch_id}/receipts")
        |> json_response(404)

      assert not_found_body["error"] == "epoch_not_found"
    end

    test "an org token reading receipts for an org-less (admin-tier) epoch gets a real 404, not the org-less data",
         %{conn: conn} do
      org_a = create_org!("acme-test-org-orgless-epoch")
      token_a = org_token!("acme-token-orgless-epoch", org_a)

      # An org-less Run/Epoch, created the same way the pre-existing
      # admin/internal-tier test suite already does (no org_id at all).
      {_run, epoch} = provider_run_and_epoch("zcode-chicago-orgless-epoch")

      conn
      |> with_org_token(token_a)
      |> get("/internal-api/execution/epochs/#{epoch.id}/receipts")
      |> json_response(404)
    end

    test "an org token reading receipts for a well-formed but nonexistent epoch_id gets a real 404, not a 200 empty-list existence oracle",
         %{conn: conn} do
      # Real, adversarial-review-found regression coverage: Ash.get/3 wraps
      # BOTH a genuinely malformed primary key AND a well-formed-but-absent
      # UUID in the same outer `%Ash.Error.Invalid{}` struct. A prior
      # version of receipts_for_org/3 matched that outer struct alone and
      # routed a syntactically valid, merely nonexistent epoch_id to the
      # unscoped read path, which happily returns a real HTTP 200
      # `{"receipts": []}` (Receipt.for_epoch has nothing to reject) instead
      # of the intended 404 -- a distinguishable response that would let an
      # org-scoped caller tell "this id exists nowhere" apart from "exists,
      # but isn't mine" (a weak cross-org existence oracle). Real-reproduced
      # live against the dev server before this test/fix existed, then
      # fixed by only treating a genuine Ash.Error.Query.NotFound inside
      # that wrapper as "not found"; every other Invalid shape keeps the
      # original 400 contract (covered by the sibling test below).
      org_a = create_org!("acme-test-org-nonexistent-epoch")
      token_a = org_token!("acme-token-nonexistent-epoch", org_a)

      nonexistent_but_well_formed_epoch_id = Ash.UUID.generate()

      body =
        conn
        |> with_org_token(token_a)
        |> get("/internal-api/execution/epochs/#{nonexistent_but_well_formed_epoch_id}/receipts")
        |> json_response(404)

      assert body["error"] == "epoch_not_found"
    end

    test "an org token given a malformed/injection-shaped epoch_id still gets a clean 400, never a 500 or the existence-oracle 200",
         %{conn: conn} do
      org_a = create_org!("acme-test-org-malformed-epoch")
      token_a = org_token!("acme-token-malformed-epoch", org_a)

      for malformed <- [
            "'; DROP TABLE ultracode_epochs;--",
            "../../../etc/passwd",
            "not-a-uuid-at-all"
          ] do
        body =
          conn
          |> with_org_token(token_a)
          |> get(
            "/internal-api/execution/epochs/#{URI.encode(malformed, &URI.char_unreserved?/1)}/receipts"
          )
          |> json_response(400)

        assert body["error"] == "invalid_epoch_id"
      end
    end

    test "the legacy shared token's receipt reads stay exactly as before this change (regression)",
         %{conn: conn} do
      worktree = make_git_worktree()
      {_run, epoch} = provider_run_and_epoch("zcode-chicago-legacy-regression", worktree)

      claim =
        tool_call(conn, "claim_next", %{
          provider: "zcode-chicago-legacy-regression",
          provider_worker_id: "worker-legacy"
        })

      tool_call(conn, "close_candidate", %{
        lease_token: claim["lease_token"],
        final_head: git_head(worktree),
        outcome: "alive"
      })

      body =
        conn
        |> with_internal_api_token()
        |> get("/internal-api/execution/epochs/#{epoch.id}/receipts")
        |> json_response(200)

      assert [receipt] = body["receipts"]
      # Suite-less close: the receipt law seals the honest downgrade
      # (partial_alive); the read path itself is the regression surface here.
      assert receipt["outcome"] == "partial_alive"
    end

    # ------------------------------------------------------------------
    # fs-safety hardening pass (2026-09) -- real, adversarial worktree
    # shapes, an unbounded goal, and a per-org submission rate limit, all
    # over the real HTTP surface, not the controller function in
    # isolation. See Xaas.Ultracode.Validations.WorktreeIsSafe,
    # Run.goal's max_length constraint, and Run's `rate_limit do` block.
    # ------------------------------------------------------------------

    test "a submission with a traversal/suspicious worktree shape gets a real typed 400, never silently accepted",
         %{conn: conn} do
      org = create_org!("acme-test-org-worktree-fence")
      token = org_token!("acme-token-worktree-fence", org)

      for {label, bad_worktree} <- [
            {"root", "/"},
            {"etc", "/etc"},
            {"relative", "relative/path"},
            {"traversal", "/Users/sac/xaas-harden-fs-safety/../../etc"}
          ] do
        body =
          conn
          |> with_org_token(token)
          |> put_req_header("content-type", "application/json")
          |> post(
            "/internal-api/execution/runs",
            Jason.encode!(%{
              goal: "adversarial worktree probe (#{label})",
              worktree: bad_worktree,
              provider: "zcode-worktree-fence-#{label}"
            })
          )
          |> json_response(400)

        assert body["error"] == "invalid_request"
        assert body["detail"] =~ "worktree"

        # Real, load-bearing negative assertion: no Run/Epoch pair was
        # actually created for this rejected submission -- the fence
        # refuses the whole create-run path, not just the HTTP response.
        rejected_provider = "zcode-worktree-fence-#{label}"

        refute Run
               |> Ash.Query.for_read(:read_unscoped)
               |> Ash.Query.filter(provider == ^rejected_provider)
               |> Ash.exists?(authorize?: false)
      end
    end

    test "a submission with no worktree at all is unaffected (worktree stays optional)",
         %{conn: conn} do
      org = create_org!("acme-test-org-worktree-optional")
      token = org_token!("acme-token-worktree-optional", org)

      conn
      |> with_org_token(token)
      |> put_req_header("content-type", "application/json")
      |> post(
        "/internal-api/execution/runs",
        Jason.encode!(%{goal: "no worktree supplied", provider: "zcode-worktree-optional"})
      )
      |> json_response(201)
    end

    test "a submission naming an unregistered verifier suite gets a typed 400 and creates nothing",
         %{conn: conn} do
      org = create_org!("acme-test-org-suite-unknown")
      token = org_token!("acme-token-suite-unknown", org)

      body =
        conn
        |> with_org_token(token)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{
            goal: "names a suite nobody registered",
            provider: "zcode-suite-unknown",
            verifier_suite: "not-a-registered-suite"
          })
        )
        |> json_response(400)

      assert body["error"] == "invalid_request"
      assert body["detail"] =~ "verifier_suite"

      refute Run
             |> Ash.Query.for_read(:read_unscoped)
             |> Ash.Query.filter(provider == "zcode-suite-unknown")
             |> Ash.exists?(authorize?: false)
    end

    test "a registered verifier suite name is stored on the Run and handed to the claiming worker",
         %{conn: conn} do
      original = Application.get_env(:xaas, :ultracode_verifier_suites)
      Application.put_env(:xaas, :ultracode_verifier_suites, %{"ctl-suite" => %{steps: []}})

      # nil = unset before: DELETE, never put_env(key, nil) -- a literal nil
      # poisons later `get_env(key, %{})` readers (the seed-dependent
      # TargetSuitesTest flake class).
      on_exit(fn ->
        if is_nil(original),
          do: Application.delete_env(:xaas, :ultracode_verifier_suites),
          else: Application.put_env(:xaas, :ultracode_verifier_suites, original)
      end)

      org = create_org!("acme-test-org-suite-known")
      token = org_token!("acme-token-suite-known", org)

      body =
        conn
        |> with_org_token(token)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{
            goal: "names a registered suite",
            provider: "zcode-suite-known",
            verifier_suite: "ctl-suite"
          })
        )
        |> json_response(201)

      run = Ash.get!(Run, body["run_id"], action: :read_unscoped, authorize?: false)
      assert run.verifier_suite == "ctl-suite"

      claim =
        tool_call(conn, "claim_next", %{
          provider: "zcode-suite-known",
          provider_worker_id: "w-suite"
        })

      assert claim["epoch_id"] == body["epoch_id"]
      assert claim["verifier_suite"] == "ctl-suite"
    end

    test "a genuinely oversized goal gets a real typed 400, never silently stored", %{conn: conn} do
      org = create_org!("acme-test-org-goal-bound")
      token = org_token!("acme-token-goal-bound", org)

      huge_goal = String.duplicate("x", 100_000)

      body =
        conn
        |> with_org_token(token)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{goal: huge_goal, provider: "zcode-goal-bound"})
        )
        |> json_response(400)

      assert body["error"] == "invalid_request"
      assert body["detail"] =~ "goal"

      refute Run
             |> Ash.Query.for_read(:read_unscoped)
             |> Ash.Query.filter(provider == "zcode-goal-bound")
             |> Ash.exists?(authorize?: false)
    end

    test "a real, bounded goal at the limit is unaffected", %{conn: conn} do
      org = create_org!("acme-test-org-goal-ok")
      token = org_token!("acme-token-goal-ok", org)

      at_limit_goal = String.duplicate("x", 50_000)

      conn
      |> with_org_token(token)
      |> put_req_header("content-type", "application/json")
      |> post(
        "/internal-api/execution/runs",
        Jason.encode!(%{goal: at_limit_goal, provider: "zcode-goal-ok"})
      )
      |> json_response(201)
    end

    # Real per-org quota, exercised over real HTTP against the real
    # Xaas.Hammer ETS backend -- the 31st submission inside the same
    # 1-minute window for this one org gets a real 429, distinct from the
    # 400s above (malformed vs. too many are different failure classes a
    # real caller must be able to tell apart).
    test "a 31st submission within a minute for the same org gets a real 429, not a 5xx or a silent 201",
         %{conn: conn} do
      org = create_org!("acme-test-org-rate-limit")
      token = org_token!("acme-token-rate-limit", org)
      provider = "zcode-rate-limit-#{System.unique_integer([:positive])}"

      submit = fn n ->
        conn
        |> with_org_token(token)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{goal: "rate-limit probe #{n}", provider: provider})
        )
      end

      for n <- 1..30 do
        submit.(n) |> json_response(201)
      end

      body = submit.(31) |> json_response(429)
      assert body["error"] == "rate_limited"
    end

    # Falsifier for key scoping: a DIFFERENT org's 1st submission, made
    # immediately after the org above exhausted its own quota, must not
    # be caught in the same bucket -- the rate limit key is real and
    # per-org, not a single shared/global counter.
    test "a different org's submission is unaffected by another org's exhausted quota",
         %{conn: conn} do
      org_a = create_org!("acme-test-org-rate-limit-a")
      token_a = org_token!("acme-token-rate-limit-a", org_a)
      org_b = create_org!("acme-test-org-rate-limit-b")
      token_b = org_token!("acme-token-rate-limit-b", org_b)
      provider_a = "zcode-rate-limit-a-#{System.unique_integer([:positive])}"

      for n <- 1..30 do
        conn
        |> with_org_token(token_a)
        |> put_req_header("content-type", "application/json")
        |> post(
          "/internal-api/execution/runs",
          Jason.encode!(%{goal: "org A quota probe #{n}", provider: provider_a})
        )
        |> json_response(201)
      end

      conn
      |> with_org_token(token_a)
      |> put_req_header("content-type", "application/json")
      |> post(
        "/internal-api/execution/runs",
        Jason.encode!(%{goal: "org A over quota", provider: provider_a})
      )
      |> json_response(429)

      # Org B, a fresh org that has never submitted, still gets a real 201.
      conn
      |> with_org_token(token_b)
      |> put_req_header("content-type", "application/json")
      |> post(
        "/internal-api/execution/runs",
        Jason.encode!(%{goal: "org B first submission", provider: "zcode-rate-limit-b"})
      )
      |> json_response(201)
    end
  end

  # ------------------------------------------------------------------
  # Helpers
  # ------------------------------------------------------------------

  defp make_git_worktree do
    # run_uid convention: wall clock + unique_integer so two concurrent BEAM
    # VMs sharing $TMPDIR can never mint the same path; removed on exit.
    dir =
      Path.join(
        System.tmp_dir(),
        "xaas-fabric-http-#{System.system_time(:millisecond)}-#{System.unique_integer()}"
      )

    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    System.cmd("git", ["-C", dir, "init", "--quiet"], stderr_to_stdout: true)

    System.cmd(
      "git",
      ["-C", dir, "commit", "--allow-empty", "-m", "init", "--quiet"],
      stderr_to_stdout: true,
      env: [
        {"GIT_AUTHOR_NAME", "test"},
        {"GIT_AUTHOR_EMAIL", "test@test"},
        {"GIT_COMMITTER_NAME", "test"},
        {"GIT_COMMITTER_EMAIL", "test@test"}
      ]
    )

    dir
  end

  defp git_head(worktree) do
    {out, 0} = System.cmd("git", ["-C", worktree, "rev-parse", "HEAD"])
    String.trim(out)
  end
end
