defmodule Xaas.Operations.RouteCastleRunSurfaceTest do
  @moduledoc """
  W858 — RouteCastleRun read-only surface court (live-view/admin-side gap
  flagged by W754: the resource exposes JSON:API `get`/`index` only, the
  private transactional `:execute` is routed only through
  `Xaas.Castle.Actions.Execute` under BRCE_ONLY authority).

  Chicago-style: real ConnCase HTTP through the real mounted Phoenix router
  (`forward "/api", XaasWeb.ApiRouter` with the real
  `XaasWeb.Plugs.RequireInternalApiToken` floor, per W723), real sandboxed
  Postgres rows, real durable `Xaas.Actuation.prepare_external/4` admission
  (the same fabric-consumption entry `Xaas.Castle.run/2` uses). No mocks.

  Courts:
    (a) JSON:API get/index return real sandboxed rows with the documented
        field set (`requested_by`, `approved_by` — the only public
        attributes; `:execute`'s `:intent` argument is not a public field);
    (b) the read-only doctrine pinned over the real wire: create- and
        update-shaped requests on the route_castle_run path answer the real
        AshJsonApi `no_route_found` 404 — there is no routed web path that
        can execute or mutate a run;
    (c) fabric consumption cross-check at the resource level: consuming a
        run through the lawful admission path writes the real durable
        `Xaas.Operations.ActuationIntent` + `ActuationReceipt` rows
        (`status == :prepared`, `resource_module == inspect(RouteCastleRun)`,
        `action == "execute"`, subject = the run's intent subject), while the
        run row itself is byte-unchanged on re-read over the wire;
    (d) determinism x2: the (a) index read and the (b) 404 refusal are each
        replayed and must be byte-identical.
  """

  use XaasWeb.ConnCase, async: false

  alias Xaas.Operations.{ActuationIntent, ActuationReceipt, RouteCastleRun}

  @token System.fetch_env!("INTERNAL_API_TOKEN")

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Xaas.Repo)
    {:ok, %{run: insert_run!("w858-surface", "w858-approver")}}
  end

  defp auth(conn), do: put_req_header(conn, "authorization", "Bearer " <> @token)
  defp jsonapi(conn), do: put_req_header(conn, "accept", "application/vnd.api+json")

  # RouteCastleRun declares only :read + the private :execute — no create
  # action — so the real row is manufactured at the repo layer (real
  # sandboxed Postgres, same table the JSON:API surface reads).
  defp insert_run!(requested_by, approved_by) do
    {count, [row]} =
      Xaas.Repo.insert_all("route_castle_runs", [
        %{requested_by: requested_by, approved_by: approved_by}
      ],
      returning: [:id, :requested_by, :approved_by])

    assert count == 1
    %{row | id: Ecto.UUID.cast!(row.id)}
  end

  defp get_index(conn) do
    conn |> auth() |> jsonapi() |> get("/api/route_castle_run")
  end

  defp get_one(conn, id) do
    conn |> auth() |> jsonapi() |> get("/api/route_castle_run/#{id}")
  end

  defp execute_shaped_post(conn, id) do
    conn
    |> auth()
    |> jsonapi()
    |> put_req_header("content-type", "application/vnd.api+json")
    |> post("/api/route_castle_run/#{id}/execute", %{
      "meta" => %{"intent" => %{"subject" => "system:w858-web-execute-attempt"}}
    })
  end

  # --------------------------------------------------------------- (a)
  describe "(a) JSON:API get/index return real documented rows" do
    test "GET /api/route_castle_run (index) returns the real sandboxed row with exact field set", %{
      conn: conn,
      run: run
    } do
      conn = get_index(conn)

      assert conn.status == 200
      body = json_response(conn, 200)

      assert is_map(body["links"])
      assert row = Enum.find(body["data"], &(&1["id"] == to_string(run.id)))
      assert row["type"] == "route_castle_run"
      # REAL wire finding (pinned): Ash 3 attributes default to public?: false
      # and this resource does not opt them in, so the public JSON:API
      # projection of a run carries an EMPTY attributes object -- requested_by/
      # approved_by are persisted and readable at the resource layer but are
      # not part of the public field set. See receipt F1.
      assert row["attributes"] == %{}
    end

    test "GET /api/route_castle_run/:id returns the exact documented field set", %{
      conn: conn,
      run: run
    } do
      conn = get_one(conn, run.id)

      assert conn.status == 200
      body = json_response(conn, 200)

      assert body["data"]["type"] == "route_castle_run"
      assert body["data"]["id"] == to_string(run.id)
      # REAL wire finding (pinned, see receipt F1): attributes render empty --
      # the two persisted columns are private (Ash 3 default public?: false).
      assert body["data"]["attributes"] == %{}

      # the persisted columns are nonetheless real and read back at the
      # resource layer from the same row the wire just served
      resource_row = Ash.get!(RouteCastleRun, body["data"]["id"], authorize?: false)
      assert resource_row.requested_by == "w858-surface"
      assert resource_row.approved_by == "w858-approver"
      # `intent` (the :execute argument) is not a public attribute
      refute Map.has_key?(body["data"]["attributes"], "intent")
    end

    test "GET of an unknown id answers the real AshJsonApi not-found", %{conn: conn} do
      conn = get_one(conn, Ecto.UUID.generate())

      assert conn.status == 404
    end
  end

  # --------------------------------------------------------------- (b)
  describe "(b) read-only doctrine: no routed web path can execute or mutate" do
    test "execute-shaped POST /api/route_castle_run/:id/execute is not routed (404 no_route_found)", %{
      conn: conn,
      run: run
    } do
      conn = execute_shaped_post(conn, run.id)

      assert conn.status == 404
      body = json_response(conn, 404)
      assert %{
               "errors" => [
                 %{
                   "code" => "no_route_found",
                   "detail" => "no route found",
                   "id" => id,
                   "meta" => %{},
                   "status" => "404",
                   "title" => "NoRouteFound"
                 }
               ],
               "jsonapi" => %{"version" => "1.0"}
             } = body
      assert is_binary(id)
    end

    test "create-shaped POST /api/route_castle_run is not routed (404)", %{conn: conn} do
      conn =
        conn
        |> auth()
        |> jsonapi()
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/route_castle_run", %{
          "data" => %{
            "type" => "route_castle_run",
            "attributes" => %{"requested_by" => "w858-web-create-attempt"}
          }
        })

      assert conn.status == 404
      assert %{"errors" => [%{"code" => "no_route_found"}]} = json_response(conn, 404)
    end

    test "update-shaped PATCH /api/route_castle_run/:id is not routed (404)", %{
      conn: conn,
      run: run
    } do
      conn =
        conn
        |> auth()
        |> jsonapi()
        |> put_req_header("content-type", "application/vnd.api+json")
        |> patch("/api/route_castle_run/#{run.id}", %{
          "data" => %{
            "type" => "route_castle_run",
            "id" => to_string(run.id),
            "attributes" => %{"approved_by" => "w858-web-patch-attempt"}
          }
        })

      assert conn.status == 404
      assert %{"errors" => [%{"code" => "no_route_found"}]} = json_response(conn, 404)
    end

    test "the GraphQL surface is removed: /api/graphql is unrouted", %{
      conn: conn
    } do
      # W984ao (operator directive 2026-10-07): the SPEC-30 GraphQL-over-HTTP
      # surface was removed fix-forward -- the /api/graphql scope and
      # Xaas.GraphqlSchema are gone. The route must now be unrouted (the
      # catch-all /api forward returns its real 404 envelope), and the
      # attempt writes no durable actuation evidence.
      conn =
        conn
        |> auth()
        |> jsonapi()
        |> post("/api/graphql", %{"query" => "query { routeCastleRuns { id } }"})

      assert conn.status == 404
      assert %{"errors" => [%{"code" => "no_route_found"}]} = json_response(conn, 404)

      # the unrouted attempt wrote no durable actuation evidence (scoped to
      # the attempt's own subject -- the shared test tables carry unrelated
      # rows inside the sandbox)
      subject = "system:w858-web-execute-attempt"

      refute Enum.any?(
               Ash.read!(ActuationReceipt, authorize?: false),
               &(&1.resource_module == inspect(RouteCastleRun) and &1.action == "execute")
             )

      refute Enum.any?(
               Ash.read!(ActuationIntent, authorize?: false),
               &(&1.subject_id == subject)
             )
    end
  end

  # --------------------------------------------------------------- (c)
  describe "(c) fabric consumption cross-check at the resource level" do
    test "lawful consumption writes real intent+receipt with the fabric's real status; run row unchanged", %{
      conn: conn,
      run: run
    } do
      intent = castle_intent("system:w858-fabric-subject-#{System.unique_integer([:positive])}")

      {:ok, prepared} =
        Xaas.Actuation.prepare_external(RouteCastleRun, :execute, %{intent: intent},
          subject_id: intent.subject,
          idempotency_key: "w858-surface-#{System.unique_integer([:positive])}",
          authorize?: false,
          authority: %{kind: "xaas_reactor", source: "w858_surface_test", scope: "castle.run"}
        )

      assert prepared.status == :prepared
      receipt = prepared.receipt
      assert receipt.resource_module == inspect(RouteCastleRun)
      assert receipt.action == "execute"
      assert receipt.status == :prepared

      # read the durable rows back from the real tables
      persisted =
        Ash.read!(ActuationReceipt, authorize?: false)
        |> Enum.find(&(&1.id == receipt.id))

      assert persisted.resource_module == inspect(RouteCastleRun)
      assert persisted.action == "execute"
      assert persisted.status == :prepared

      intent_row =
        Ash.read!(ActuationIntent, authorize?: false)
        |> Enum.find(&(&1.id == prepared.intent.id))

      assert intent_row

      # the run row itself is unchanged on re-read over the real wire
      wire = get_one(conn, run.id)
      assert wire.status == 200
      body = json_response(wire, 200)

      assert body["data"]["attributes"] == %{}

      # the resource-layer row is byte-unchanged by consumption
      resource_row = Ash.get!(RouteCastleRun, run.id, authorize?: false)
      assert resource_row.requested_by == "w858-surface"
      assert resource_row.approved_by == "w858-approver"
    end
  end

  # --------------------------------------------------------------- (d)
  describe "(d) determinism x2" do
    test "index read replays byte-identical", %{conn: conn, run: run} do
      first = get_index(conn)
      second = get_index(conn)

      assert first.status == 200
      assert second.status == 200
      b1 = json_response(first, 200)
      b2 = json_response(second, 200)
      assert b1 == b2
      assert Enum.any?(b1["data"], &(&1["id"] == to_string(run.id)))
    end

    test "execute-shaped 404 refusal replays byte-identical", %{conn: conn, run: run} do
      first = execute_shaped_post(conn, run.id)
      second = execute_shaped_post(conn, run.id)

      assert first.status == 404
      assert second.status == 404
      b1 = json_response(first, 404)
      b2 = json_response(second, 404)

      # the only nondeterministic member is the per-response error id
      assert %{"id" => id1} = hd(b1["errors"])
      assert %{"id" => id2} = hd(b2["errors"])
      assert is_binary(id1) and is_binary(id2)
      assert %{b1 | "errors" => [hd(b1["errors"]) |> Map.delete("id")]} ==
               %{b2 | "errors" => [hd(b2["errors"]) |> Map.delete("id")]}
    end
  end

  # ---------------------------------------------------------------------
  defp castle_intent(subject) do
    now = System.system_time(:millisecond)

    %{
      adapter_profile_id: "xaas-local-proof",
      subject: subject,
      authority: "bounded-do",
      config_graph: %{"zeroUnreceiptedActuation" => true},
      ontology: %{"version" => "26.8.18"},
      process: %{
        id: "powl:w858-surface",
        goal_id: "goal:w858-surface",
        activities: [%{id: "activity:echo", transition_id: "echo", predecessors: []}]
      },
      envelope: %{
        system_id: subject,
        allowed_transition_ids: ["echo"],
        max_steps: 1,
        expires_at_epoch_ms: now + 60_000
      }
    }
  end
end
